package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import lombok.Data;

@Data
public class IncubationBatchRequest {
  /** Generated when blank on create. */
  @Size(max = 40) private String reference;
  @NotBlank private String equipmentId;
  @NotNull @Min(1) @Max(1_000_000) private Integer eggsSet;
  @NotNull private LocalDate plannedStartDate;
  @Size(max = 100) private String eggSource;
  @Size(max = 500) private String notes;
  /** Required on update. */
  private Long version;
}
