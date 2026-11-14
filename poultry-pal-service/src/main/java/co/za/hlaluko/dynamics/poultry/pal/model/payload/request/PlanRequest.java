package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.SourceMethod;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;
import lombok.Data;

@Data
public class PlanRequest {
  @NotNull private SourceMethod sourceMethod;
  @NotNull private LocalDate targetReadyDate;
  @NotNull @Min(1) @Max(1_000_000) private Integer targetQuantity;
  /** Days in the house before sale; defaults to the farm's grow-out age. */
  @Min(1) @Max(365) private Integer targetAgeDays;
  /** Overrides of the farm's estimates, as fractions between 0 and 1. */
  @DecimalMin("0.01") @DecimalMax("1") private BigDecimal expectedHatchRate;
  @DecimalMin("0") @DecimalMax("0.99") private BigDecimal expectedMortalityRate;
  private String houseId;
  @Size(max = 100) private String name;
  @Size(max = 500) private String notes;
}
