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
  private String farmAddressLine1;
  private String farmAddressLine2;
  private String farmState;
  private String farmCity;
  private String farmPostalCode;
  private String farmCountry;
}
