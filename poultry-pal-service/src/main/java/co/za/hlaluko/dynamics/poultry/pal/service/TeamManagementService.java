package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ProductionPermission;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Role;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.CoopAssignmentRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ProductionAccessRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.TeamMemberRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.TeamRoleRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.RoleRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import co.za.hlaluko.dynamics.poultry.pal.sync.UserInfoMapper;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class TeamManagementService {
  private final FarmRepository farmRepository;
  private final UserRepository userRepository;
  private final RoleRepository roleRepository;
  private final PasswordEncoder passwordEncoder;
  private final AsyncService asyncService;
  private final ProductionAccessService productionAccessService;

  public List<UserInfoResponse> list(UserDetailsImpl actor) {
    Farm farm = requireManagerFarm(actor);
    List<Coop> coops = farm.getCoops() == null ? List.of() : farm.getCoops();
    return userRepository.findByFarmId(farm.getId()).stream()
        .filter(user -> !user.isRemoved())
        .map(user -> UserInfoMapper.toResponse(user, coops))
        .toList();
  }

  public List<UserInfoResponse> add(
      UserDetailsImpl actor, TeamMemberRequest request) {
    Farm farm = requireManagerFarm(actor);
    ERole requestedRole = requireTeamRole(request.getRole());
    if (requestedRole == ERole.ROLE_FARM_MANAGER && !actor.isFarmOwner()) {
      throw ApiException.forbidden("Only the farm owner can add a farm manager");
    }
    if (Boolean.TRUE.equals(userRepository.existsByEmailAndRemoved(request.getEmail(), false))) {
      throw ApiException.conflict("Email is already in use");
    }
    Set<Role> roles = new HashSet<>();
    roles.add(requireRole(ERole.ROLE_USER));
    roles.add(requireRole(requestedRole));
    User member =
        User.builder()
            .name(request.getName().trim())
            .surname(request.getSurname().trim())
            .phoneNumber(request.getPhoneNumber().trim())
            .farmId(farm.getId())
            .active(true)
            .email(request.getEmail().trim())
            .password(passwordEncoder.encode(request.getPhoneNumber().trim()))
            .createdDate(new Date())
            .roles(roles)
            .addedByUserId(actor.getId())
            .farmOwner(false)
            .build();
    userRepository.save(member);
    asyncService.registrationNotification(member, request.getPhoneNumber().trim());
    return list(actor);
  }

  public List<UserInfoResponse> changeRole(
      UserDetailsImpl actor, String memberId, TeamRoleRequest request) {
    Farm farm = requireManagerFarm(actor);
    User member = requireMember(farm, memberId);
    ERole requestedRole = requireTeamRole(request.getRole());
    if (requestedRole == ERole.ROLE_FARM_MANAGER && !actor.isFarmOwner()) {
      throw ApiException.forbidden("Only the farm owner can assign the farm manager role");
    }
    member.setRoles(new HashSet<>(Set.of(requireRole(ERole.ROLE_USER), requireRole(requestedRole))));
    member.setRolesUpdatedByUserId(actor.getId());
    userRepository.save(member);
    return list(actor);
  }

  public List<UserInfoResponse> setProductionAccess(
      UserDetailsImpl actor, String memberId, ProductionAccessRequest request) {
    Farm farm = requireManagerFarm(actor);
    if (!productionAccessService.canGrant(actor)) {
      throw ApiException.forbidden("Only the farm owner or an administrator can grant production access");
    }
    User member = requireMember(farm, memberId);
    if (member.isFarmOwner()) {
      throw ApiException.badRequest("The farm owner always has production access");
    }
    Set<ProductionPermission> permissions =
        member.getPermissions() == null
            ? new HashSet<>()
            : new HashSet<>(member.getPermissions());
    boolean changed =
        Boolean.TRUE.equals(request.getGranted())
            ? permissions.add(ProductionPermission.PRODUCTION_MANAGE)
            : permissions.remove(ProductionPermission.PRODUCTION_MANAGE);
    if (changed) {
      member.setPermissions(permissions);
      member.setPermissionsUpdatedByUserId(actor.getId());
      member.setPermissionsUpdatedAt(new Date());
      userRepository.save(member);
    }
    return list(actor);
  }

  public List<UserInfoResponse> assignCoops(
      UserDetailsImpl actor, String memberId, CoopAssignmentRequest request) {
    Farm farm = requireManagerFarm(actor);
    User member = requireMember(farm, memberId);
    List<Coop> coops =
        farm.getCoops() == null ? new ArrayList<>() : new ArrayList<>(farm.getCoops());
    if (coops == null) {
      if (!request.getCoopIds().isEmpty()) {
        throw ApiException.badRequest("No coops are available in this farm");
      }
      return list(actor);
    }
    Set<String> selected = new HashSet<>(request.getCoopIds());
    Set<String> existing = new HashSet<>();
    coops.forEach(coop -> existing.add(coop.getId()));
    if (!existing.containsAll(selected)) {
      throw ApiException.badRequest("A selected coop does not belong to this farm");
    }
    for (Coop coop : coops) {
      List<String> assigned = new ArrayList<>(coop.getResponsibleUserIds() == null
          ? List.of()
          : coop.getResponsibleUserIds());
      assigned.removeIf(member.getId()::equals);
      if (selected.contains(coop.getId())) assigned.add(member.getId());
      coop.setResponsibleUserIds(assigned);
    }
    farm.setCoops(coops);
    farmRepository.save(farm);
    return list(actor);
  }

  public List<UserInfoResponse> setActive(UserDetailsImpl actor, String memberId, boolean active) {
    Farm farm = requireManagerFarm(actor);
    User member = requireMember(farm, memberId);
    if (!active && member.getId().equals(actor.getId())) {
      throw ApiException.badRequest("You cannot deactivate your own account");
    }
    member.setActive(active);
    userRepository.save(member);
    return list(actor);
  }

  public List<UserInfoResponse> remove(UserDetailsImpl actor, String memberId) {
    Farm farm = requireManagerFarm(actor);
    User member = requireMember(farm, memberId);
    if (member.isFarmOwner() || member.getId().equals(actor.getId())) {
      throw ApiException.badRequest("The farm owner or your own account cannot be removed here");
    }
    member.setRemoved(true);
    member.setRemovedByUserId(actor.getId());
    userRepository.save(member);
    if (farm.getCoops() != null) {
      List<Coop> coops = new ArrayList<>(farm.getCoops());
      for (Coop coop : coops) {
        List<String> assigned =
            new ArrayList<>(
                coop.getResponsibleUserIds() == null ? List.of() : coop.getResponsibleUserIds());
        assigned.removeIf(member.getId()::equals);
        coop.setResponsibleUserIds(assigned);
      }
      farm.setCoops(coops);
      farmRepository.save(farm);
    }
    return list(actor);
  }

  private Farm requireManagerFarm(UserDetailsImpl actor) {
    if (actor == null || actor.getFarmId() == null || actor.getFarmId().isBlank()) {
      throw ApiException.forbidden("User is not linked to a farm");
    }
    boolean manager =
        actor.isFarmOwner()
            || actor.getAuthorities().stream()
                .anyMatch(
                    authority ->
                        authority.getAuthority().equals(ERole.ROLE_FARM_MANAGER.name())
                            || authority.getAuthority().equals(ERole.ROLE_ADMIN.name()));
    if (!manager) throw ApiException.forbidden("Farm manager permission required");
    return farmRepository
        .findById(actor.getFarmId())
        .orElseThrow(() -> ApiException.notFound("Farm not found"));
  }

  private User requireMember(Farm farm, String memberId) {
    User member =
        userRepository
            .findById(memberId)
            .orElseThrow(() -> ApiException.notFound("Team member not found"));
    if (!farm.getId().equals(member.getFarmId()) || member.isRemoved()) {
      throw ApiException.notFound("Team member not found");
    }
    return member;
  }

  private ERole requireTeamRole(ERole role) {
    if (role != ERole.ROLE_FARM_WORKER && role != ERole.ROLE_FARM_MANAGER) {
      throw ApiException.badRequest("Role must be farm worker or farm manager");
    }
    return role;
  }

  private Role requireRole(ERole name) {
    return roleRepository
        .findByName(name)
        .orElseThrow(() -> ApiException.badRequest("Role is not configured"));
  }
}
