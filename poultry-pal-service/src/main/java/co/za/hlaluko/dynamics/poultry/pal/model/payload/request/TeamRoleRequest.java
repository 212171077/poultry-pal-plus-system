package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class TeamRoleRequest {
  @NotNull private ERole role;
}
