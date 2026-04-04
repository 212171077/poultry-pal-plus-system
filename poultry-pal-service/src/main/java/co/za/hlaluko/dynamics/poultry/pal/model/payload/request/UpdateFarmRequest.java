package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UpdateFarmRequest {
  @NotBlank private String farmId;
  @NotBlank private String updatedByUserId;
  @NotBlank private String farmName;
  @NotBlank private String farmAddressLine1;
  @NotBlank private String farmAddressLine2;
  @NotBlank private String farmState;
  @NotBlank private String farmCity;
  @NotBlank private String farmPostalCode;
  @NotBlank private String farmCountry;
}
