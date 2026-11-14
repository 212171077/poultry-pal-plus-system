package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.BatchStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class IncubationBatchResponse {
  private String id;
  private String farmId;
  private String reference;
  private String equipmentId;
  private int eggsSet;
  /** Eggs assigned to non-cancelled hatcher cycles. */
  private int eggsReserved;
  private int eggsUnassigned;
  private LocalDate plannedStartDate;
  private LocalDate plannedTransferDate;
  private LocalDate plannedHatchDate;
  private LocalDate actualStartDate;
  private BatchStatus status;
  private String eggSource;
  private String notes;
  private String cancelReason;
  private BigDecimal expectedHatchRateSnapshot;
  private List<HatcherCycleResponse> hatcherCycles;
  private Instant updatedAt;
  private Long version;
}
