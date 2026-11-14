package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.BatchStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

/** Eggs set in one incubator together. Dates are calendar days in the farm's time zone. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "incubation_batches")
public class IncubationBatch {
  @Id private String id;
  private String farmId;
  /** Unique within the farm. */
  private String reference;
  private String equipmentId;
  private int eggsSet;
  /** The effective schedule; recomputed from the actual start date once the batch is started. */
  private LocalDate plannedStartDate;
  private LocalDate plannedTransferDate;
  private LocalDate plannedHatchDate;
  private LocalDate actualStartDate;
  private BatchStatus status;
  private String eggSource;
  private String notes;
  private String cancelReason;
  /** Settings in force when the batch was created, so later edits do not rewrite history. */
  private int incubationDaysSnapshot;
  private int transferDaySnapshot;
  private BigDecimal expectedHatchRateSnapshot;
  private Instant createdAt;
  private Instant updatedAt;
  private String createdBy;
  private String updatedBy;
  @Version private Long version;
}
