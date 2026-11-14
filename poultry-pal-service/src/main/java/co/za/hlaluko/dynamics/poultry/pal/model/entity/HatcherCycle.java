package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.CycleStatus;
import java.time.Instant;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

/** A lot of eggs from one incubation batch reserved for one hatcher. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "hatcher_cycles")
public class HatcherCycle {
  @Id private String id;
  private String farmId;
  private String incubationBatchId;
  private String hatcherId;
  private String reference;
  private int quantity;
  private LocalDate plannedTransferDate;
  private LocalDate actualTransferDate;
  private LocalDate expectedHatchDate;
  /** Hatcher occupancy captured at reservation time. */
  private int occupancyDays;
  private CycleStatus status;
  private String notes;
  private Instant createdAt;
  private Instant updatedAt;
  private String createdBy;
  private String updatedBy;
  @Version private Long version;
}
