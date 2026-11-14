package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.CycleStatus;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class HatcherCycleResponse {
  private String id;
  private String farmId;
  private String incubationBatchId;
  private String hatcherId;
  private String reference;
  private int quantity;
  private LocalDate plannedTransferDate;
  private LocalDate actualTransferDate;
  private LocalDate expectedHatchDate;
  private int occupancyDays;
  private CycleStatus status;
  private String notes;
  private Instant updatedAt;
  private Long version;
}
