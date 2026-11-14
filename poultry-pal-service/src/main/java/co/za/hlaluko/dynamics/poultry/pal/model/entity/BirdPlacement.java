package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlacementSource;
import java.time.Instant;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

/** Chicks placed in a chicken house. The live count is derived from this plus the movement ledger. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "bird_placements")
public class BirdPlacement {
  @Id private String id;
  private String farmId;
  private String reference;
  private PlacementSource source;
  /** Hatcher cycle for OWN_HATCH placements. */
  private String sourceCycleId;
  private String sourceReference;
  private String houseId;
  private int quantity;
  private LocalDate arrivalDate;
  private LocalDate placementDate;
  /** Age in days at arrival (0 for day-old chicks). */
  private int ageDaysAtArrival;
  private String notes;
  private Instant createdAt;
  private Instant updatedAt;
  private String createdBy;
  private String updatedBy;
  @Version private Long version;
}
