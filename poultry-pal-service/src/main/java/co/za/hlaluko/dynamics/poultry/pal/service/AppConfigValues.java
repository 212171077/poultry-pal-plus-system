package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.lookups.AppConfig;
import co.za.hlaluko.dynamics.poultry.pal.repository.AppConfigRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class AppConfigValues {
  public static final String ADMIN_EMAIL = "ADMIN_EMAIL";
  public static final String APP_BASE_URL = "APP_BASE_URL";
  public static final String DEFAULT_APP_BASE_URL = "https://tertiaryverify.dedicated.co.za:8086";

  private final AppConfigRepository repository;

  public String adminEmail() {
    return value(ADMIN_EMAIL, "");
  }

  public String appBaseUrl() {
    String url = value(APP_BASE_URL, DEFAULT_APP_BASE_URL);
    return url.endsWith("/") ? url.substring(0, url.length() - 1) : url;
  }

  private String value(String code, String fallback) {
    AppConfig config = repository.findByCode(code);
    return config == null || config.getDescription() == null || config.getDescription().isBlank()
        ? fallback
        : config.getDescription().trim();
  }
}
