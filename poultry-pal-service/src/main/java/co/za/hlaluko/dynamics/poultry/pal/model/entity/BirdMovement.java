package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.MovementType;
import java.time.Instant;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/** Append-only ledger event; never edited or deleted. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "bird_movements")
public class BirdMovement {
  @Id private String id;
  private String farmId;
  private String placementId;
  private MovementType type;
  private int count;
  /** Only meaningful for CORRECTION: true adds birds, false removes them. */
  private boolean increase;
  private LocalDate date;
  private String reason;
  /** Optional link to an existing coop record, e.g. SALE or MORTALITY. */
  private String relatedRecordType;
  private String relatedRecordId;
  private String idempotencyKey;
  private Instant createdAt;
  private String createdBy;

  /** Signed effect on the live bird count. */
  public int delta() {
    boolean adds = type == MovementType.CORRECTION && increase;
    return adds ? count : -count;
  }
}
