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
public class AddFarmUserRequest {

  @NotBlank private String addedByUserId;
  @NotBlank private String farmId;
  @NotBlank private String name;
  @NotBlank private String surname;
  @NotBlank private String email;
  @NotBlank private String phoneNumber;
  @NotEmpty private List<ERole> roles;

}
