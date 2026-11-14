package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.MovementType;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class BirdMovementResponse {
  private String id;
  private String placementId;
  private MovementType type;
  private int count;
  private boolean increase;
  private LocalDate date;
  private String reason;
  private String relatedRecordType;
  private String relatedRecordId;
  private Instant createdAt;
  private String createdBy;
}
