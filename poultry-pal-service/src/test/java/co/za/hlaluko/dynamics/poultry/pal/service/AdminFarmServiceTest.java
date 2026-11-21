package co.za.hlaluko.dynamics.poultry.pal.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ApprovalStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

class AdminFarmServiceTest {
  private final FarmRepository farms = mock(FarmRepository.class);
  private final UserRepository users = mock(UserRepository.class);
  private final AccountApprovalService approval = mock(AccountApprovalService.class);
  private final AdminFarmService service = new AdminFarmService(
          farms, users, approval, mock(co.za.hlaluko.dynamics.poultry.pal.repository.RefreshTokenRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.CoopArchiveRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.SyncOperationLogRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.UserSettingsRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.ProductionEquipmentRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.ProductionPlanRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.HatcherCycleRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.ProductionSettingsRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.HatchResultRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.ProductionReminderRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.BirdMovementRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.BirdPlacementRepository.class),
          mock(co.za.hlaluko.dynamics.poultry.pal.repository.IncubationBatchRepository.class));

  private static UserDetailsImpl actor(String role) {
    UserDetailsImpl user = mock(UserDetailsImpl.class);
    when(user.getAuthorities())
        .thenAnswer(i -> List.<GrantedAuthority>of(new SimpleGrantedAuthority(role)));
    return user;
  }

  private static User member(boolean active, ApprovalStatus status) {
    User user = new User();
    user.setId("u1");
    user.setFarmId("f1");
    user.setActive(active);
    user.setApprovalStatus(status);
    return user;
  }

  @Test
  void nonAdminIsForbidden() {
    assertThrows(ApiException.class, () -> service.list(actor("ROLE_FARM_MANAGER"), null, 0, 10));
    assertThrows(ApiException.class, () -> service.setAccess(null, "u1", true));
  }

  @Test
  void statusMirrorsSignInRule() {
    assertEquals("ACTIVE", AdminFarmService.statusOf(member(true, ApprovalStatus.APPROVED)));
    assertEquals("ACTIVE", AdminFarmService.statusOf(member(true, null)));
    assertEquals("PENDING", AdminFarmService.statusOf(member(false, ApprovalStatus.PENDING)));
    assertEquals("DISABLED", AdminFarmService.statusOf(member(false, ApprovalStatus.APPROVED)));
    assertEquals("DISABLED", AdminFarmService.statusOf(member(true, ApprovalStatus.REJECTED)));
  }

  @Test
  void grantAndDisableDelegateToApprovalService() {
    User user = member(false, ApprovalStatus.REJECTED);
    when(users.findById("u1")).thenReturn(Optional.of(user));
    service.setAccess(actor("ROLE_ADMIN"), "u1", true);
    verify(approval).applyAccess(user, true);
    service.setAccess(actor("ROLE_ADMIN"), "u1", false);
    verify(approval).applyAccess(user, false);
  }

  @Test
  void deleteFarmRemovesUsersAndTheFarm() {
    var farm = mock(co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm.class);
    when(farms.findById("f1")).thenReturn(Optional.of(farm));
    when(users.findByFarmIdIn(List.of("f1"))).thenReturn(List.of(member(true, null)));
    service.deleteFarm(actor("ROLE_ADMIN"), "f1");
    verify(users).deleteByFarmId("f1");
    verify(farms).delete(farm);
    assertThrows(ApiException.class, () -> service.deleteFarm(actor("ROLE_FARM_MANAGER"), "f1"));
  }

  @Test
  void unknownUserIsNotFound() {
    when(users.findById("x")).thenReturn(Optional.empty());
    assertThrows(ApiException.class, () -> service.setAccess(actor("ROLE_ADMIN"), "x", true));
  }
}
