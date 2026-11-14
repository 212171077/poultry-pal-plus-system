package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.MovementType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import lombok.Data;

@Data
public class BirdMovementRequest {
  @NotNull private MovementType type;
  @NotNull @Min(1) @Max(1_000_000) private Integer count;
  /** For CORRECTION only: true adds birds back, otherwise removes them. */
  private boolean increase;
  @NotNull private LocalDate date;
  @Size(max = 300) private String reason;
  @Size(max = 20) private String relatedRecordType;
  @Size(max = 64) private String relatedRecordId;
}
