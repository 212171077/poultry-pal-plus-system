package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;
import lombok.Data;

@Data
public class ScheduleSearchRequest {
  @NotNull @Min(1) @Max(1_000_000) private Integer eggs;
  @NotNull private LocalDate earliestStart;
  @NotNull private LocalDate latestStart;
  /** Defaults to the first enabled unit of each type. */
  private String incubatorId;
  private String hatcherId;
  private String houseId;
}
