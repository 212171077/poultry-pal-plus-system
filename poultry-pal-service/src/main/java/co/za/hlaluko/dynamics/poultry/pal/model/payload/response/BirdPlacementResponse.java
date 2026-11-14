package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlacementSource;
import java.time.LocalDate;
import java.util.List;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class BirdPlacementResponse {
  private String id;
  private String reference;
  private PlacementSource source;
  private String sourceCycleId;
  private String sourceReference;
  private String houseId;
  private int quantity;
  private LocalDate arrivalDate;
  private LocalDate placementDate;
  private int ageDaysAtArrival;
  private String notes;
  /** Derived: quantity plus the movement ledger. */
  private int remaining;
  private int mortality;
  private int sold;
  private int otherRemovals;
  /** ACTIVE while birds remain, otherwise CLOSED. */
  private String status;
  /** Only populated on single-placement reads. */
  private List<BirdMovementResponse> movements;
  private Long version;
}
