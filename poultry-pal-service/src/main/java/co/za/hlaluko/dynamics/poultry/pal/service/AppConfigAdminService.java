package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.lookups.AppConfig;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.AppConfigRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.AppConfigResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.AppConfigRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/** CRUD over {@link AppConfig}, restricted to system administrators. */
@Service
@RequiredArgsConstructor
public class AppConfigAdminService {
  static final String MASK = "********";
  private static final Set<String> PROTECTED_CODES = Set.of(
          "MAIL_USER", "MAIL_PASS", "MAIL_HOST", "MAIL_PORT", "MAIL_AUTH", "MAIL_STARTTLS");
  private static final Pattern CODE = Pattern.compile("[A-Z0-9_]{1,50}");
  private static final Pattern SENSITIVE =
      Pattern.compile(".*(PASS|PASSWORD|SECRET|TOKEN|KEY).*");

  private final AppConfigRepository repository;

  public List<AppConfigResponse> list(UserDetailsImpl actor) {
    requireAdmin(actor);
    return repository.findAll().stream()
        .sorted(Comparator.comparing(AppConfig::getCode, String.CASE_INSENSITIVE_ORDER))
        .map(this::toResponse)
        .toList();
  }

  public AppConfigResponse create(UserDetailsImpl actor, AppConfigRequest request) {
    requireAdmin(actor);
    String code = normalizeCode(request.getCode());
    String value = requireValue(request.getDescription());
    if (repository.findByCode(code) != null) {
      throw ApiException.conflict("A configuration with code " + code + " already exists");
    }
    Date now = new Date();
    AppConfig config =
        AppConfig.builder()
            .code(code)
            .description(value)
            .createDate(now)
            .lastUpdateDate(now)
            .lastUpdateUserId(actor.getId())
            .build();
    return toResponse(repository.save(config));
  }

  public AppConfigResponse update(UserDetailsImpl actor, String id, AppConfigRequest request) {
    requireAdmin(actor);
    AppConfig config = find(id);
    String value = request.getDescription();
    boolean keepSecret = isSensitive(config.getCode()) && (value == null || value.isBlank());
    if (!keepSecret) config.setDescription(requireValue(value));
    config.setLastUpdateDate(new Date());
    config.setLastUpdateUserId(actor.getId());
    return toResponse(repository.save(config));
  }

  public void delete(UserDetailsImpl actor, String id) {
    requireAdmin(actor);
    AppConfig config = find(id);
    if (PROTECTED_CODES.contains(config.getCode())) {
      throw ApiException.badRequest(config.getCode() + " is required by the system");
    }
    repository.delete(config);
  }

  private AppConfig find(String id) {
    return repository
        .findById(id)
        .orElseThrow(() -> ApiException.notFound("Configuration not found"));
  }

  private AppConfigResponse toResponse(AppConfig config) {
    boolean sensitive = isSensitive(config.getCode());
    return AppConfigResponse.builder()
        .id(config.getId())
        .code(config.getCode())
        .description(sensitive ? MASK : config.getDescription())
        .sensitive(sensitive)
        .protectedEntry(PROTECTED_CODES.contains(config.getCode()))
        .createDate(config.getCreateDate())
        .lastUpdateDate(config.getLastUpdateDate())
        .lastUpdateUserId(config.getLastUpdateUserId())
        .build();
  }

  private static boolean isSensitive(String code) {
    return code != null && SENSITIVE.matcher(code.toUpperCase(Locale.ROOT)).matches();
  }

  private static String normalizeCode(String code) {
    String normalized = code == null ? "" : code.trim().toUpperCase(Locale.ROOT);
    if (!CODE.matcher(normalized).matches()) {
      throw ApiException.badRequest("Code must be 1-50 letters, digits or underscores");
    }
    return normalized;
  }

  private static String requireValue(String value) {
    if (value == null || value.isBlank()) throw ApiException.badRequest("Value is required");
    return value.trim();
  }

  private static void requireAdmin(UserDetailsImpl actor) {
    boolean admin =
        actor != null
            && actor.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals(ERole.ROLE_ADMIN.name()));
    if (!admin) throw ApiException.forbidden("System administrator permission required");
  }
}
