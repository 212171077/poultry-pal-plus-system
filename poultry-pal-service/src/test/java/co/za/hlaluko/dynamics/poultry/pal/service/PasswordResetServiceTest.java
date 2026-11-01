package co.za.hlaluko.dynamics.poultry.pal.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import co.za.hlaluko.dynamics.poultry.pal.mail.Email;
import co.za.hlaluko.dynamics.poultry.pal.mail.EmailSender;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.repository.RefreshTokenRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import java.util.Date;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.password.PasswordEncoder;

class PasswordResetServiceTest {
  private final UserRepository users = mock(UserRepository.class);
  private final RefreshTokenRepository tokens = mock(RefreshTokenRepository.class);
  private final PasswordEncoder encoder = mock(PasswordEncoder.class);
  private final EmailSender sender = mock(EmailSender.class);
  private final PasswordResetService service =
      new PasswordResetService(users, tokens, encoder, sender);
  private final User user =
      User.builder().id("u1").name("Jane").email("jane@farm.test").password("old").build();

  private String requestCode() {
    when(users.findByEmail("jane@farm.test")).thenReturn(Optional.of(user));
    when(tokens.findByUserIdAndRevokedFalse("u1")).thenReturn(List.of());
    service.requestReset("jane@farm.test");
    ArgumentCaptor<Email> captor = ArgumentCaptor.forClass(Email.class);
    verify(sender).saveEmail(captor.capture());
    Matcher m = Pattern.compile("<strong>(\\d{6})</strong>").matcher(captor.getValue().getContent());
    assertTrue(m.find());
    return m.group(1);
  }

  @Test
  void unknownEmailSendsNothing() {
    when(users.findByEmail("x@y.z")).thenReturn(Optional.empty());
    service.requestReset("x@y.z");
    verify(sender, never()).saveEmail(any());
  }

  @Test
  void correctCodeChangesPasswordOnceOnly() {
    String code = requestCode();
    when(encoder.encode("NewPass123")).thenReturn("hashed");

    assertTrue(service.reset("jane@farm.test", code, "NewPass123"));
    assertEquals("hashed", user.getPassword());
    assertNull(user.getPasswordResetCodeHash());
    assertFalse(service.reset("jane@farm.test", code, "Other12345"));
  }

  @Test
  void codeIsLockedAfterTooManyWrongAttempts() {
    String code = requestCode();
    for (int i = 0; i < PasswordResetService.MAX_ATTEMPTS; i++) {
      assertFalse(service.reset("jane@farm.test", "000000".equals(code) ? "111111" : "000000", "NewPass123"));
    }
    assertFalse(service.reset("jane@farm.test", code, "NewPass123"));
    assertEquals("old", user.getPassword());
  }

  @Test
  void expiredCodeIsRejected() {
    String code = requestCode();
    user.setPasswordResetExpiry(new Date(System.currentTimeMillis() - 1000));
    assertFalse(service.reset("jane@farm.test", code, "NewPass123"));
  }
}
