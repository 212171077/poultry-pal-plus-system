package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UserRolesRequest {

  @NotBlank private String updatedByUserId;
  @NotBlank private String farmId;
  @NotBlank private String userId;
  @NotEmpty private List<ERole> roles;

}
