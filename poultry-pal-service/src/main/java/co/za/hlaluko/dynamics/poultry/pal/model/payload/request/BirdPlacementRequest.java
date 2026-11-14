package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlacementSource;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import lombok.Data;

@Data
public class BirdPlacementRequest {
  @NotNull private PlacementSource source;
  /** Required for OWN_HATCH: a hatcher cycle with a recorded result. */
  private String sourceCycleId;
  /** Supplier or lot description for PURCHASED_DAY_OLD. */
  @Size(max = 100) private String sourceReference;
  @NotBlank private String houseId;
  @NotNull @Min(1) @Max(1_000_000) private Integer quantity;
  private LocalDate arrivalDate;
  @NotNull private LocalDate placementDate;
  @Min(0) @Max(365) private Integer ageDaysAtArrival;
  @Size(max = 500) private String notes;
}
