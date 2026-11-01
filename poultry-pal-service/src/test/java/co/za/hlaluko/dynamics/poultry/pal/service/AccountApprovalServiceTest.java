package co.za.hlaluko.dynamics.poultry.pal.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import co.za.hlaluko.dynamics.poultry.pal.mail.Email;
import co.za.hlaluko.dynamics.poultry.pal.mail.EmailSender;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ApprovalStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class AccountApprovalServiceTest {
  private final UserRepository users = mock(UserRepository.class);
  private final EmailSender sender = mock(EmailSender.class);
  private final AppConfigValues config = mock(AppConfigValues.class);
  private final AccountApprovalService service = new AccountApprovalService(users, sender, config);

  private User farmer() {
    return User.builder()
        .name("Jane")
        .surname("<b>Doe</b>")
        .email("jane@farm.test")
        .phoneNumber("0821234567")
        .farmOwner(true)
        .roles(new java.util.HashSet<>())
        .build();
  }

  @Test
  void pendingFarmerCannotSignIn() {
    User user = farmer();
    service.markPending(user);
    assertFalse(UserDetailsImpl.build(user).isEnabled());
    user.setApprovalStatus(null);
    assertTrue(UserDetailsImpl.build(user).isEnabled());
  }

  @Test
  void registrationEmailsAdminWithLinkAndWelcomesUser() {
    when(config.adminEmail()).thenReturn("admin@test");
    when(config.appBaseUrl()).thenReturn("https://app.test");
    User user = farmer();
    String token = service.markPending(user);

    service.notifyRegistration(user, "Happy Farm", token);

    ArgumentCaptor<Email> captor = ArgumentCaptor.forClass(Email.class);
    verify(sender, org.mockito.Mockito.times(2)).saveEmail(captor.capture());
    List<Email> emails = captor.getAllValues();
    assertEquals("admin@test", emails.get(0).getTo()[0]);
    assertTrue(emails.get(0).getContent().contains("https://app.test/api/auth/approval?token=" + token));
    assertFalse(emails.get(0).getContent().contains("<b>Doe</b>"));
    assertEquals("jane@farm.test", emails.get(1).getTo()[0]);
    assertTrue(emails.get(1).getContent().contains("jane@farm.test"));
  }

  @Test
  void approveActivatesUserOnceOnly() {
    when(config.appBaseUrl()).thenReturn("https://app.test");
    User user = farmer();
    String token = service.markPending(user);
    when(users.findByApprovalTokenHash(AccountApprovalService.hash(token)))
        .thenReturn(Optional.of(user));

    assertTrue(service.decide(token, true).isPresent());
    assertEquals(ApprovalStatus.APPROVED, user.getApprovalStatus());
    assertTrue(user.isActive());
    assertTrue(UserDetailsImpl.build(user).isEnabled());
    verify(users).save(any(User.class));
    assertTrue(service.decide(token, true).isEmpty());
  }

  @Test
  void rejectKeepsUserDisabled() {
    when(config.appBaseUrl()).thenReturn("https://app.test");
    User user = farmer();
    String token = service.markPending(user);
    when(users.findByApprovalTokenHash(AccountApprovalService.hash(token)))
        .thenReturn(Optional.of(user));

    service.decide(token, false);

    assertEquals(ApprovalStatus.REJECTED, user.getApprovalStatus());
    assertFalse(UserDetailsImpl.build(user).isEnabled());
  }
}
