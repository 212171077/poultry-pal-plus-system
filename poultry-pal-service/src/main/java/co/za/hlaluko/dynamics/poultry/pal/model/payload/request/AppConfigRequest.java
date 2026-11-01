package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class AppConfigRequest {
  /** Required when creating; ignored on update (a code never changes). */
  @Size(max = 50)
  private String code;

  /** The configuration value. Blank on update keeps the stored value of a sensitive entry. */
  @Size(max = 250)
  private String description;
}
