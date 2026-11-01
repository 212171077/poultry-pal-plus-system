package co.za.hlaluko.dynamics.poultry.pal.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.lookups.AppConfig;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.AppConfigRequest;
import co.za.hlaluko.dynamics.poultry.pal.repository.AppConfigRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

class AppConfigAdminServiceTest {
  private final AppConfigRepository repository = mock(AppConfigRepository.class);
  private final AppConfigAdminService service = new AppConfigAdminService(repository);

  private static UserDetailsImpl actor(String role) {
    UserDetailsImpl user = mock(UserDetailsImpl.class);
    when(user.getId()).thenReturn("u1");
    when(user.getAuthorities())
        .thenAnswer(i -> List.<GrantedAuthority>of(new SimpleGrantedAuthority(role)));
    return user;
  }

  @Test
  void nonAdminIsForbidden() {
    assertThrows(ApiException.class, () -> service.list(actor("ROLE_FARM_MANAGER")));
    assertThrows(ApiException.class, () -> service.list(null));
  }

  @Test
  void secretsAreMasked() {
    when(repository.findAll())
        .thenReturn(
            List.of(
                AppConfig.builder().id("1").code("MAIL_PASS").description("secret").build(),
                AppConfig.builder().id("2").code("SITE").description("x").build()));
    var result = service.list(actor("ROLE_ADMIN"));
    assertEquals("********", result.get(0).getDescription());
    assertEquals("x", result.get(1).getDescription());
  }

  @Test
  void blankSecretKeepsStoredValue() {
    AppConfig stored = AppConfig.builder().id("1").code("MAIL_PASS").description("secret").build();
    when(repository.findById("1")).thenReturn(Optional.of(stored));
    when(repository.save(any(AppConfig.class))).thenAnswer(i -> i.getArgument(0));
    AppConfigRequest request = new AppConfigRequest();
    request.setDescription("");
    service.update(actor("ROLE_ADMIN"), "1", request);
    assertEquals("secret", stored.getDescription());
  }

  @Test
  void protectedEntryCannotBeDeleted() {
    when(repository.findById("1"))
        .thenReturn(Optional.of(AppConfig.builder().id("1").code("MAIL_USER").build()));
    assertThrows(ApiException.class, () -> service.delete(actor("ROLE_ADMIN"), "1"));
    verify(repository, never()).delete(any());
  }
}
