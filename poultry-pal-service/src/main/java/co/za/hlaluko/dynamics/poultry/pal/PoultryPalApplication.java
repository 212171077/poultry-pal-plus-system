package co.za.hlaluko.dynamics.poultry.pal;

import co.za.hlaluko.dynamics.poultry.pal.mail.MailSettings;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Role;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.lookups.AppConfig;
import co.za.hlaluko.dynamics.poultry.pal.repository.AppConfigRepository;
import co.za.hlaluko.dynamics.poultry.pal.service.AdminUserInitializer;
import co.za.hlaluko.dynamics.poultry.pal.service.AppConfigValues;
import co.za.hlaluko.dynamics.poultry.pal.repository.RoleRepository;
import java.util.Date;
import java.util.List;
import java.util.stream.Stream;
import lombok.AllArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableAsync
@EnableCaching
@EnableScheduling
@AllArgsConstructor
@SpringBootApplication
@ComponentScan({"co.za.hlaluko.dynamics.poultry.pal"})
public class PoultryPalApplication implements CommandLineRunner {

  private static final Logger LOGGER = LoggerFactory.getLogger(PoultryPalApplication.class);

  private final RoleRepository roleRepository;
  private final AppConfigRepository appConfigRepository;
  private final AdminUserInitializer adminUserInitializer;
  private final MailSettings mailSettings;

  public static void main(String[] args) {
    SpringApplication.run(PoultryPalApplication.class, args);
  }

  @Override
  public void run(String... args) throws Exception {
    initializeRoles();
    mailSettings.seedDefaults();
    ensureDefaultConfig(
        AppConfigValues.ADMIN_EMAIL,
        System.getProperty(
            "poultry.pal.app.admin.email", System.getenv().getOrDefault("POULTRY_PAL_APP_ADMIN_EMAIL", "")));
    ensureDefaultConfig(AppConfigValues.APP_BASE_URL, AppConfigValues.DEFAULT_APP_BASE_URL);
    adminUserInitializer.ensureAdminUser();
  }

  private void ensureDefaultConfig(String code, String value) {
    if (appConfigRepository.findByCode(code) == null) {
      AppConfig config = new AppConfig();
      config.setCode(code);
      config.setDescription(value);
      config.setCreateDate(new Date());
      config.setLastUpdateDate(new Date());
      appConfigRepository.save(config);
    }
  }

  private void initializeRoles() {
    List<ERole> rolesToAdd =
        Stream.of(ERole.values()).filter(role -> !roleRepository.existsByName(role)).toList();

    if (!rolesToAdd.isEmpty()) {
      List<Role> roles = rolesToAdd.stream().map(role -> new Role(null, role)).toList();

      roleRepository.saveAll(roles);
      LOGGER.info("New roles initialized: {}", roles);
    }
  }
}
