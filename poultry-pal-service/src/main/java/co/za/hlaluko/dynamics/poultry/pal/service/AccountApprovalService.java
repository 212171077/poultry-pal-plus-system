package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.mail.Email;
import co.za.hlaluko.dynamics.poultry.pal.mail.EmailSender;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ApprovalStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.utils.ConstantUtil;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.stereotype.Service;
import org.springframework.web.util.HtmlUtils;

@Service
@RequiredArgsConstructor
public class AccountApprovalService {
  private static final Logger logger = LogManager.getLogger(AccountApprovalService.class);
  private static final SecureRandom RANDOM = new SecureRandom();

  private final UserRepository userRepository;
  private final EmailSender emailSender;
  private final AppConfigValues config;

  /** Marks a freshly registered farmer as pending and returns the one-time approval token. */
  public String markPending(User user) {
    byte[] bytes = new byte[32];
    RANDOM.nextBytes(bytes);
    String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    user.setApprovalStatus(ApprovalStatus.PENDING);
    user.setApprovalTokenHash(hash(token));
    return token;
  }

  public void notifyRegistration(User user, String farmName, String token) {
    sendAdminRequest(user, farmName, token);
    sendWelcome(user);
  }

  public Optional<User> findPending(String token) {
    if (token == null || token.isBlank()) {
      return Optional.empty();
    }
    return userRepository
        .findByApprovalTokenHash(hash(token))
        .filter(user -> user.getApprovalStatus() == ApprovalStatus.PENDING);
  }

  public Optional<User> decide(String token, boolean approve) {
    Optional<User> found = findPending(token);
    found.ifPresent(
        user -> {
          user.setApprovalStatus(approve ? ApprovalStatus.APPROVED : ApprovalStatus.REJECTED);
          user.setActive(approve);
          user.setApprovalTokenHash(null);
          userRepository.save(user);
          sendDecision(user, approve);
        });
    return found;
  }

  private void sendAdminRequest(User user, String farmName, String token) {
    String link = config.appBaseUrl() + "/api/auth/approval?token=" + token;
    String body =
        "<p>A new farmer has registered and is waiting for approval:</p><ul>"
            + "<li><strong>Name:</strong> " + esc(user.getName()) + " " + esc(user.getSurname()) + "</li>"
            + "<li><strong>Email:</strong> " + esc(user.getEmail()) + "</li>"
            + "<li><strong>Phone:</strong> " + esc(user.getPhoneNumber()) + "</li>"
            + "<li><strong>Farm:</strong> " + esc(farmName) + "</li></ul>"
            + "<p>The account cannot access the farm until you decide.</p>"
            + "<p><a href=\"" + link + "\">Review this registration (approve or reject)</a></p>";
    queue(config.adminEmail(), "New Poultry Pal Plus account awaiting approval", body);
  }

  private void sendWelcome(User user) {
    String body =
        "<p>Dear " + esc(user.getName()) + " " + esc(user.getSurname()) + ",</p>"
            + "<p>Welcome to Poultry Pal Plus! Your account has been created.</p>"
            + "<ul><li><strong>Username:</strong> " + esc(user.getEmail()) + "</li>"
            + "<li><strong>Password:</strong> the password you chose when registering</li>"
            + "<li><strong>Login:</strong> <a href=\"" + config.appBaseUrl() + "\">"
            + config.appBaseUrl() + "</a></li></ul>"
            + "<p>Your account must be approved by our administrator before you can sign in. "
            + "You will receive another email as soon as a decision is made.</p>";
    queue(user.getEmail(), "Welcome to Poultry Pal Plus", body);
  }

  private void sendDecision(User user, boolean approved) {
    String body =
        approved
            ? "<p>Dear " + esc(user.getName()) + ",</p><p>Your Poultry Pal Plus account has been "
                + "approved. You can now sign in with <strong>" + esc(user.getEmail())
                + "</strong> at <a href=\"" + config.appBaseUrl() + "\">" + config.appBaseUrl()
                + "</a>.</p>"
            : "<p>Dear " + esc(user.getName()) + ",</p><p>Unfortunately your Poultry Pal Plus "
                + "registration was not approved. Please contact support if you think this is a "
                + "mistake.</p>";
    queue(
        user.getEmail(),
        approved ? "Your Poultry Pal Plus account is approved" : "Poultry Pal Plus registration update",
        body);
  }

  private void queue(String to, String subject, String body) {
    try {
      Email email = new Email();
      email.setFrom(ConstantUtil.NO_REPLY_EMAIL);
      email.setTo(new String[] {to});
      email.setSubject(subject);
      email.setContent(body);
      emailSender.saveEmail(email);
    } catch (Exception e) {
      logger.error("Unable to queue email '{}' to {}", subject, to, e);
    }
  }

  private static String esc(String value) {
    return HtmlUtils.htmlEscape(value == null ? "" : value);
  }

  static String hash(String token) {
    try {
      return HexFormat.of()
          .formatHex(
              MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException(e);
    }
  }
}
