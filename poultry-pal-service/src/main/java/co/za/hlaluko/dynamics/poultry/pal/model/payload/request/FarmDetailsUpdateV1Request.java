package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class FarmDetailsUpdateV1Request {
  @NotBlank @Size(max = 50) private String farmName;
  @Size(max = 100)
  private String addressLine1;
  @Size(max = 100)
  private String addressLine2;
  @Size(max = 50)
  private String state;
  @Size(max = 50)
  private String city;
  @Size(max = 20)
  private String postalCode;
  @Size(max = 80)
  private String country;
}
