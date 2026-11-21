package co.za.hlaluko.dynamics.poultry.pal.mail;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.lookups.AppConfig;
import co.za.hlaluko.dynamics.poultry.pal.repository.AppConfigRepository;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * SMTP settings stored in the {@code app_config} collection. Missing entries are inserted at
 * startup from the {@code poultry.pal.app.mail.*} properties (Gmail by default, overridable per
 * environment, e.g. Mailpit for local testing); the stored values are what the app then uses.
 */
@Slf4j
@Component
public class MailSettings {
  public static final String HOST = "MAIL_HOST";
  public static final String PORT = "MAIL_PORT";
  public static final String AUTH = "MAIL_AUTH";
  public static final String STARTTLS = "MAIL_STARTTLS";
  public static final String USER = "MAIL_USER";
  public static final String PASS = "MAIL_PASS";

  private final AppConfigRepository repository;
  private final Map<String, String> defaults = new LinkedHashMap<>();

  public MailSettings(
      AppConfigRepository repository,
      @Value("${poultry.pal.app.mail.host:smtp.gmail.com}") String host,
      @Value("${poultry.pal.app.mail.port:587}") String port,
      @Value("${poultry.pal.app.mail.auth:true}") String auth,
      @Value("${poultry.pal.app.mail.starttls:true}") String starttls,
      @Value("${poultry.pal.app.mail.user:}") String user,
      @Value("${poultry.pal.app.mail.pass:}") String pass) {
    this.repository = repository;
    defaults.put(HOST, host);
    defaults.put(PORT, port);
    defaults.put(AUTH, auth);
    defaults.put(STARTTLS, starttls);
    defaults.put(USER, user);
    defaults.put(PASS, pass);
  }

  /** Inserts any missing mail setting; existing (possibly admin-edited) values are never touched. */
  public void seedDefaults() {
    defaults.forEach(
        (code, value) -> {
          if (repository.findByCode(code) == null) {
            Date now = new Date();
            AppConfig config = new AppConfig();
            config.setCode(code);
            config.setDescription(value);
            config.setCreateDate(now);
            config.setLastUpdateDate(now);
            repository.save(config);
          }
        });
  }

  public String get(String code) {
    AppConfig config = repository.findByCode(code);
    if (config == null || config.getDescription() == null || config.getDescription().isBlank()) {
      log.error("Mail setting {} was not found in app_config; using the configured default.", code);
      return defaults.get(code);
    }
    return config.getDescription().trim();
  }

  public boolean flag(String code) {
    return Boolean.parseBoolean(get(code));
  }
}
