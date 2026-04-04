package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class SignupRequest {

  @NotBlank
  @Size(min = 2, max = 50)
  private String name;

  @NotBlank
  @Size(min = 2, max = 50)
  private String surname;

  @NotBlank
  @Email
  @Size(max = 50)
  private String email;

  @NotBlank
  @Size(max = 15)
  private String phoneNumber;

  @NotBlank
  @Size(min = 6, max = 120)
  private String password;

  @NotBlank private String farmName;
  private String farmAddressLine1;
  private String farmAddressLine2;
  private String farmState;
  private String farmCity;
  private String farmPostalCode;
  private String farmCountry;
}
