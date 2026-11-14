package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ProductionPermission;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionAccessResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Single authorization point for the production module. Every production service, including sync
 * handlers, must call {@link #requireManage} so a farm id is always derived from the caller.
 */
@Service
public class ProductionAccessService {

  /** Global kill switch; per-farm enablement is the {@code PRODUCTION_MANAGE} grant. */
  private final boolean enabled;

  public ProductionAccessService(
      @Value("${poultry.pal.production.enabled:true}") boolean enabled) {
    this.enabled = enabled;
  }

  /** Returns the caller's farm id after verifying the {@code PRODUCTION_MANAGE} grant. */
  public String requireManage(UserDetailsImpl actor) {
    if (!enabled) {
      throw ApiException.forbidden("Production management is not enabled");
    }
    if (actor == null || actor.getFarmId() == null || actor.getFarmId().isBlank()) {
      throw ApiException.forbidden("User is not linked to a farm");
    }
    if (!actor.canManageProduction()) {
      throw ApiException.forbidden("Production management permission required");
    }
    return actor.getFarmId();
  }

  public boolean canGrant(UserDetailsImpl actor) {
    return actor != null
        && (actor.isFarmOwner()
            || actor.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals(ERole.ROLE_ADMIN.name())));
  }

  public ProductionAccessResponse describe(UserDetailsImpl actor) {
    String farmId = requireManage(actor);
    return ProductionAccessResponse.builder()
        .userId(actor.getId())
        .farmId(farmId)
        .canManageProduction(true)
        .canGrantAccess(canGrant(actor))
        .permissions(
            actor.getPermissions() == null
                ? List.of()
                : actor.getPermissions().stream().map(Enum::name).sorted().toList())
        .build();
  }
}
