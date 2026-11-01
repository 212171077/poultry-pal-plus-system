package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class TeamMemberRequest {
  @NotBlank @Size(min = 2, max = 50) private String name;
  @NotBlank @Size(min = 2, max = 50) private String surname;
  @NotBlank @Email @Size(max = 50) private String email;
  @NotBlank @Size(max = 15) private String phoneNumber;
  @NotNull private ERole role;
}
