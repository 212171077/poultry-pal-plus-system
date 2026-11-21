package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.EmailLog;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.EmailLogResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.EmailLogRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

/** Read-only view of the email delivery log, restricted to system administrators. */
@Service
@RequiredArgsConstructor
public class EmailLogAdminService {
  static final int MAX_LIMIT = 100;
  static final int DEFAULT_LIMIT = 25;

  private final EmailLogRepository repository;

  public List<EmailLogResponse> latest(UserDetailsImpl actor, Integer limit, Integer page) {
    boolean admin =
        actor != null
            && actor.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals(ERole.ROLE_ADMIN.name()));
    if (!admin) throw ApiException.forbidden("System administrator permission required");
    int size = limit == null ? DEFAULT_LIMIT : Math.max(1, Math.min(limit, MAX_LIMIT));
    return repository
        .findAll(PageRequest.of(Math.max(0, page == null ? 0 : page), size, Sort.by(Sort.Direction.DESC, "createDate")))
        .stream()
        .map(this::toResponse)
        .toList();
  }

  private EmailLogResponse toResponse(EmailLog log) {
    return EmailLogResponse.builder()
        .id(log.getId())
        .sentAt(log.getCreateDate())
        .toEmail(log.getToEmail())
        .subject(log.getSubject())
        .success(!Boolean.TRUE.equals(log.getError()))
        .errorMessage(Boolean.TRUE.equals(log.getError()) ? log.getErrorMessage() : null)
        .build();
  }
}
