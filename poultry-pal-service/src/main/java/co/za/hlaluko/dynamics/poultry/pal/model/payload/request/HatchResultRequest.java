package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.OutcomeCount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;
import lombok.Data;

@Data
public class HatchResultRequest {
  @NotNull @Min(0) @Max(1_000_000) private Integer hatchedChicks;
  @NotNull @Min(0) @Max(1_000_000) private Integer unhatchedEggs;
  /** Hatched chicks that are weak or unhealthy; must not exceed hatchedChicks. */
  @Min(0) @Max(1_000_000) private Integer weakChicks;
  @Valid @Size(max = 10) private List<OutcomeCount> otherOutcomes;
  @NotNull private LocalDate resultDate;
  @Size(max = 500) private String notes;
  /** Required when editing an existing result. */
  private Long version;
}
