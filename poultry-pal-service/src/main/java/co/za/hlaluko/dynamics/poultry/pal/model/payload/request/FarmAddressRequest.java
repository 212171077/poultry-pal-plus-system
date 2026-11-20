package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class FarmAddressRequest {
  @Size(max = 50)
  private String label;

  @NotBlank
  @Size(max = 100)
  private String addressLine1;

  @Size(max = 100)
  private String addressLine2;

  @Size(max = 60)
  private String city;

  @Size(max = 60)
  private String state;

  @Size(max = 20)
  private String postalCode;

  @Size(max = 80)
  private String country;
}
