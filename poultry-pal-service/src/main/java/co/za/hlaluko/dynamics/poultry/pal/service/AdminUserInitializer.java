package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.mail.Email;
import co.za.hlaluko.dynamics.poultry.pal.mail.EmailSender;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ApprovalStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Role;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.repository.RoleRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.utils.ConstantUtil;
import java.security.SecureRandom;
import java.util.Date;
import java.util.HashSet;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/** Creates the system admin on startup when it does not exist and emails the random password. */
@Component
@RequiredArgsConstructor
public class AdminUserInitializer {
  private static final Logger logger = LogManager.getLogger(AdminUserInitializer.class);
  static final String ADMIN_EMAIL = "systemnotification.cs@gmail.com";
  private static final String ALPHABET =
      "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  private static final SecureRandom RANDOM = new SecureRandom();

  private final UserRepository userRepository;
  private final RoleRepository roleRepository;
  private final PasswordEncoder encoder;
  private final EmailSender emailSender;
  private final AppConfigValues config;

  public void ensureAdminUser() {
    if (userRepository.findByEmail(ADMIN_EMAIL).isPresent()) {
      return;
    }
    Set<Role> roles = new HashSet<>();
    roles.add(role(ERole.ROLE_USER));
    roles.add(role(ERole.ROLE_ADMIN));

    String password = randomPassword(16);
    userRepository.save(
        User.builder()
            .name("System")
            .surname("Admin")
            .email(ADMIN_EMAIL)
            .phoneNumber("0729266568")
            .password(encoder.encode(password))
            .active(true)
            .farmOwner(false)
            .approvalStatus(ApprovalStatus.APPROVED)
            .roles(roles)
            .createdDate(new Date())
            .build());
    logger.info("System admin user created: {}", ADMIN_EMAIL);

    Email email = new Email();
    email.setFrom(ConstantUtil.NO_REPLY_EMAIL);
    email.setTo(new String[] {ADMIN_EMAIL});
    email.setSubject("Poultry Pal Plus system admin account");
    email.setContent(
        "<p>Dear System Admin,</p><p>Your administrator account has been created.</p><ul>"
            + "<li><strong>Username:</strong> " + ADMIN_EMAIL + "</li>"
            + "<li><strong>Password:</strong> " + password + "</li>"
            + "<li><strong>Login:</strong> " + config.appBaseUrl() + "</li></ul>"
            + "<p>Please change this password after your first login.</p>");
    emailSender.saveEmail(email);
  }

  private Role role(ERole name) {
    return roleRepository
        .findByName(name)
        .orElseThrow(() -> new IllegalStateException("Role not found: " + name));
  }

  static String randomPassword(int length) {
    StringBuilder sb = new StringBuilder(length);
    for (int i = 0; i < length; i++) {
      sb.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
    }
    return sb.toString();
  }
}
