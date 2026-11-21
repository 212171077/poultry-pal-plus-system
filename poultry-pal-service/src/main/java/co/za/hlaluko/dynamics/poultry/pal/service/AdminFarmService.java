package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ApprovalStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.AdminFarmMemberResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.AdminFarmPage;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.AdminFarmResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.BirdMovementRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.BirdPlacementRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.CoopArchiveRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.HatchResultRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.HatcherCycleRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.IncubationBatchRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionEquipmentRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionPlanRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionReminderRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionSettingsRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.RefreshTokenRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.SyncOperationLogRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserSettingsRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import co.za.hlaluko.dynamics.poultry.pal.utils.FarmAddresses;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

/** Lets the system administrator review registered farms and grant or disable user access. */
@Service
@RequiredArgsConstructor
public class AdminFarmService {
  static final int MAX_SIZE = 50;
  static final int DEFAULT_SIZE = 10;

  private final FarmRepository farmRepository;
  private final UserRepository userRepository;
  private final AccountApprovalService approvalService;
  private final RefreshTokenRepository refreshTokens;
  private final CoopArchiveRepository coopArchives;
  private final SyncOperationLogRepository syncOperations;
  private final UserSettingsRepository userSettings;
  private final ProductionEquipmentRepository equipment;
  private final ProductionPlanRepository plans;
  private final HatcherCycleRepository hatcherCycles;
  private final ProductionSettingsRepository productionSettings;
  private final HatchResultRepository hatchResults;
  private final ProductionReminderRepository productionReminders;
  private final BirdMovementRepository birdMovements;
  private final BirdPlacementRepository birdPlacements;
  private final IncubationBatchRepository incubationBatches;

  public AdminFarmPage list(UserDetailsImpl actor, String search, Integer page, Integer size) {
    requireAdmin(actor);
    int pageSize = size == null ? DEFAULT_SIZE : Math.max(1, Math.min(size, MAX_SIZE));
    PageRequest request =
        PageRequest.of(Math.max(0, page == null ? 0 : page), pageSize, Sort.by("farmName"));
    Page<Farm> farms =
        search == null || search.isBlank()
            ? farmRepository.findAll(request)
            : farmRepository.findByFarmNameContainingIgnoreCase(search.trim(), request);
    Map<String, List<User>> usersByFarm =
        userRepository
            .findByFarmIdIn(farms.stream().map(Farm::getId).toList())
            .stream()
            .filter(user -> !user.isRemoved())
            .collect(Collectors.groupingBy(User::getFarmId));
    return AdminFarmPage.builder()
        .items(
            farms.stream().map(farm -> toResponse(farm, usersByFarm.get(farm.getId()))).toList())
        .page(farms.getNumber())
        .size(farms.getSize())
        .total(farms.getTotalElements())
        .build();
  }

  public AdminFarmMemberResponse setAccess(UserDetailsImpl actor, String userId, boolean granted) {
    requireAdmin(actor);
    User user =
        userRepository
            .findById(userId)
            .filter(found -> !found.isRemoved())
            .orElseThrow(() -> ApiException.notFound("User not found"));
    if (isAdmin(user)) {
      throw ApiException.badRequest("System administrator access cannot be changed here");
    }
    if (user.getFarmId() == null) {
      throw ApiException.badRequest("This user does not belong to a farm");
    }
    approvalService.applyAccess(user, granted);
    return toMember(user);
  }

  /** Permanently removes the farm, its users and every record linked to it. */
  public void deleteFarm(UserDetailsImpl actor, String farmId) {
    requireAdmin(actor);
    Farm farm =
        farmRepository.findById(farmId).orElseThrow(() -> ApiException.notFound("Farm not found"));
    List<User> users = userRepository.findByFarmIdIn(List.of(farmId));
    if (users.stream().anyMatch(AdminFarmService::isAdmin)) {
      throw ApiException.badRequest("A farm with a system administrator cannot be deleted");
    }
    refreshTokens.deleteByUserIdIn(users.stream().map(User::getId).toList());
    coopArchives.deleteByFarmId(farmId);
    syncOperations.deleteByFarmId(farmId);
    userSettings.deleteByFarmId(farmId);
    equipment.deleteByFarmId(farmId);
    plans.deleteByFarmId(farmId);
    hatcherCycles.deleteByFarmId(farmId);
    productionSettings.deleteByFarmId(farmId);
    hatchResults.deleteByFarmId(farmId);
    productionReminders.deleteByFarmId(farmId);
    birdMovements.deleteByFarmId(farmId);
    birdPlacements.deleteByFarmId(farmId);
    incubationBatches.deleteByFarmId(farmId);
    userRepository.deleteByFarmId(farmId);
    farmRepository.delete(farm);
  }

  private AdminFarmResponse toResponse(Farm farm, List<User> users) {
    List<AdminFarmMemberResponse> members =
        (users == null ? List.<User>of() : users)
            .stream()
                .filter(user -> !isAdmin(user))
                .sorted(
                    Comparator.comparing(User::isFarmOwner)
                        .reversed()
                        .thenComparing(User::getName, String.CASE_INSENSITIVE_ORDER))
                .map(this::toMember)
                .toList();
    var primary = FarmAddresses.primary(farm);
    return AdminFarmResponse.builder()
        .id(farm.getId())
        .farmName(farm.getFarmName())
        .city(primary == null ? null : primary.getCity())
        .createdDate(farm.getCreatedDate())
        .coopCount(farm.getCoops() == null ? 0 : farm.getCoops().size())
        .members(members)
        .build();
  }

  private AdminFarmMemberResponse toMember(User user) {
    return AdminFarmMemberResponse.builder()
        .id(user.getId())
        .name(user.getName())
        .surname(user.getSurname())
        .email(user.getEmail())
        .phoneNumber(user.getPhoneNumber())
        .owner(user.isFarmOwner())
        .roles(
            user.getRoles() == null
                ? List.of()
                : user.getRoles().stream().map(role -> role.getName().getValue()).sorted().toList())
        .status(statusOf(user))
        .build();
  }

  /** Mirrors the sign-in rule in UserDetailsImpl#isEnabled. */
  static String statusOf(User user) {
    ApprovalStatus approval = user.getApprovalStatus();
    if (approval == ApprovalStatus.PENDING) return "PENDING";
    boolean enabled =
        (user.isActive() || user.isFarmOwner())
            && (approval == null || approval == ApprovalStatus.APPROVED);
    return enabled ? "ACTIVE" : "DISABLED";
  }

  private static boolean isAdmin(User user) {
    return user.getRoles() != null
        && user.getRoles().stream().anyMatch(role -> role.getName() == ERole.ROLE_ADMIN);
  }

  private static void requireAdmin(UserDetailsImpl actor) {
    boolean admin =
        actor != null
            && actor.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals(ERole.ROLE_ADMIN.name()));
    if (!admin) throw ApiException.forbidden("System administrator permission required");
  }
}
