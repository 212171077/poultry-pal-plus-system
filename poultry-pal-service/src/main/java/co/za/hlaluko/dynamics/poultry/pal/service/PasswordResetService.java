package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.mail.Email;
import co.za.hlaluko.dynamics.poultry.pal.mail.EmailSender;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.RefreshToken;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.repository.RefreshTokenRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.utils.ConstantUtil;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Date;
import java.util.HexFormat;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.util.HtmlUtils;

/** Emails a short-lived 6-digit code; the code plus the email lets the user set a new password. */
@Service
@RequiredArgsConstructor
public class PasswordResetService {
  private static final Logger logger = LogManager.getLogger(PasswordResetService.class);
  static final long CODE_TTL_MS = 15 * 60 * 1000L;
  static final long RESEND_AFTER_MS = 60 * 1000L;
  static final int MAX_ATTEMPTS = 5;
  private static final SecureRandom RANDOM = new SecureRandom();

  private final UserRepository userRepository;
  private final RefreshTokenRepository refreshTokenRepository;
  private final PasswordEncoder encoder;
  private final EmailSender emailSender;

  /** Never reveals whether the email is registered. */
  public void requestReset(String email) {
    userRepository
        .findByEmail(email.trim())
        .filter(user -> !user.isRemoved())
        .ifPresent(this::issueCode);
  }

  /** @return true when the password was changed; false for a wrong, expired or exhausted code. */
  public boolean reset(String email, String code, String newPassword) {
    User user = userRepository.findByEmail(email.trim()).filter(u -> !u.isRemoved()).orElse(null);
    if (user == null
        || user.getPasswordResetCodeHash() == null
        || user.getPasswordResetExpiry() == null
        || user.getPasswordResetExpiry().before(new Date())
        || user.getPasswordResetAttempts() >= MAX_ATTEMPTS) {
      return false;
    }
    boolean matches =
        MessageDigest.isEqual(
            hash(user, code).getBytes(StandardCharsets.UTF_8),
            user.getPasswordResetCodeHash().getBytes(StandardCharsets.UTF_8));
    if (!matches) {
      user.setPasswordResetAttempts(user.getPasswordResetAttempts() + 1);
      userRepository.save(user);
      return false;
    }
    user.setPassword(encoder.encode(newPassword));
    clear(user);
    userRepository.save(user);
    revokeSessions(user.getId());
    return true;
  }

  private void issueCode(User user) {
    Date expiry = user.getPasswordResetExpiry();
    if (expiry != null && expiry.getTime() - CODE_TTL_MS + RESEND_AFTER_MS > System.currentTimeMillis()) {
      return;
    }
    String code = String.format("%06d", RANDOM.nextInt(1_000_000));
    user.setPasswordResetCodeHash(hash(user, code));
    user.setPasswordResetExpiry(new Date(System.currentTimeMillis() + CODE_TTL_MS));
    user.setPasswordResetAttempts(0);
    userRepository.save(user);

    try {
      Email email = new Email();
      email.setFrom(ConstantUtil.NO_REPLY_EMAIL);
      email.setTo(new String[] {user.getEmail()});
      email.setSubject("Poultry Pal Plus password reset code");
      email.setContent(
          "<p>Dear " + HtmlUtils.htmlEscape(user.getName()) + ",</p>"
              + "<p>Use this code to reset your password:</p>"
              + "<p style=\"font-size:24px;letter-spacing:4px\"><strong>" + code + "</strong></p>"
              + "<p>It expires in 15 minutes. If you did not ask for this, you can ignore this email.</p>");
      emailSender.saveEmail(email);
    } catch (Exception e) {
      logger.error("Unable to queue password reset email", e);
    }
  }

  private void clear(User user) {
    user.setPasswordResetCodeHash(null);
    user.setPasswordResetExpiry(null);
    user.setPasswordResetAttempts(0);
  }

  private void revokeSessions(String userId) {
    List<RefreshToken> active = refreshTokenRepository.findByUserIdAndRevokedFalse(userId);
    Date now = new Date();
    active.forEach(
        token -> {
          token.setRevoked(true);
          token.setRevokedAt(now);
        });
    refreshTokenRepository.saveAll(active);
  }

  private static String hash(User user, String code) {
    try {
      return HexFormat.of()
          .formatHex(
              MessageDigest.getInstance("SHA-256")
                  .digest((user.getId() + ":" + code).getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException(e);
    }
  }
}
