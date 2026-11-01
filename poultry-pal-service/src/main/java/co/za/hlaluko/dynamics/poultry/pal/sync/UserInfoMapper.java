package co.za.hlaluko.dynamics.poultry.pal.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Role;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.service.AuthControllerServiceImpl;
import java.util.List;
import java.util.Objects;

/** Maps users to the public {@link UserInfoResponse} (never exposes passwords). */
public final class UserInfoMapper {
  private UserInfoMapper() {}

  public static UserInfoResponse toResponse(User user, List<Coop> coops) {
    List<String> roles =
        user.getRoles() == null
            ? List.of()
            : user.getRoles().stream()
                .filter(Objects::nonNull)
                .map(Role::getName)
                .filter(Objects::nonNull)
                .map(Enum::name)
                .sorted()
                .toList();
    List<String> coopIds =
        coops == null
            ? List.of()
            : coops.stream()
                .filter(
                    c ->
                        c.getResponsibleUserIds() != null
                            && c.getResponsibleUserIds().contains(user.getId()))
                .map(Coop::getId)
                .toList();
    return UserInfoResponse.builder()
        .id(user.getId())
        .name(user.getName())
        .surname(user.getSurname())
        .phoneNumber(user.getPhoneNumber())
        .farmId(user.getFarmId())
        .isFarmOwner(user.isFarmOwner())
        .isActive(user.isActive())
        .createdDate(user.getCreatedDate())
        .email(user.getEmail())
        .roles(roles)
        .userCoopIds(coopIds)
        .roleFriendlyNames(AuthControllerServiceImpl.getRoleFriendlyNames(roles))
        .build();
  }
}
