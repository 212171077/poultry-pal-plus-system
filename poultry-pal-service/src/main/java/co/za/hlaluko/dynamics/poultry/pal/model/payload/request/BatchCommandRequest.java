package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import lombok.Data;

/** Optional body for start, transfer and cancel commands. */
@Data
public class BatchCommandRequest {
  /** Start or transfer date when it differs from the plan. */
  private LocalDate actualDate;
  @Size(max = 300) private String reason;
}
