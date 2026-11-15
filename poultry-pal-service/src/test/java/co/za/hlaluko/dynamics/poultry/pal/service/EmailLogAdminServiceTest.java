package co.za.hlaluko.dynamics.poultry.pal.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.EmailLog;
import co.za.hlaluko.dynamics.poultry.pal.repository.EmailLogRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

class EmailLogAdminServiceTest {
  private final EmailLogRepository repository = mock(EmailLogRepository.class);
  private final EmailLogAdminService service = new EmailLogAdminService(repository);

  private static UserDetailsImpl actor(String role) {
    UserDetailsImpl user = mock(UserDetailsImpl.class);
    when(user.getAuthorities())
        .thenAnswer(i -> List.<GrantedAuthority>of(new SimpleGrantedAuthority(role)));
    return user;
  }

  @Test
  void nonAdminIsForbidden() {
    assertThrows(ApiException.class, () -> service.latest(actor("ROLE_FARM_MANAGER"), null));
    assertThrows(ApiException.class, () -> service.latest(null, null));
  }

  @Test
  void mapsOutcomeAndHidesTheBody() {
    EmailLog ok = new EmailLog("a@x.com", "b@x.com", null, "Welcome", "secret code 123", false, "");
    EmailLog failed = new EmailLog("a@x.com", "c@x.com", null, "Reset", "body", true, "refused");
    Page<EmailLog> page = new PageImpl<>(List.of(ok, failed));
    when(repository.findAll(any(Pageable.class))).thenReturn(page);

    var result = service.latest(actor("ROLE_ADMIN"), null);

    assertTrue(result.get(0).isSuccess());
    assertNull(result.get(0).getErrorMessage());
    assertFalse(result.get(1).isSuccess());
    assertEquals("refused", result.get(1).getErrorMessage());
  }

  @Test
  void limitIsClamped() {
    when(repository.findAll(any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
    service.latest(actor("ROLE_ADMIN"), 5000);
    ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
    verify(repository).findAll(captor.capture());
    assertEquals(EmailLogAdminService.MAX_LIMIT, captor.getValue().getPageSize());
  }
}
