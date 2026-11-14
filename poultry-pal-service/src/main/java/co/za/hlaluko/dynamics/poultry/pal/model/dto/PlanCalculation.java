package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Inputs, assumptions and results of one target-date calculation; a snapshot, never live. */
@Data
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
public class PlanCalculation {
  private SourceMethod sourceMethod;
  private LocalDate targetReadyDate;
  private int targetQuantity;
  private int targetAgeDays;
  private BigDecimal hatchRate;
  private BigDecimal mortalityRate;
  private String houseId;

  private LocalDate housePlacementDate;
  /** Hatch date for own eggs, or the recommended arrival date for purchased chicks. */
  private LocalDate hatchOrArrivalDate;
  private LocalDate incubationStartDate;
  private LocalDate transferDate;
  /** Null until the farm configures a supplier lead time. */
  private LocalDate latestOrderDate;
  /** Null for purchased chicks. */
  private Integer eggsRequired;
  private int chicksRequired;
  private boolean feasible;
  private List<String> constraints;
  private List<String> assumptions;
  private Instant calculatedAt;

  /** True when the dates or quantities differ from another calculation of the same plan. */
  public boolean differsFrom(PlanCalculation other) {
    return feasible != other.feasible
        || chicksRequired != other.chicksRequired
        || !java.util.Objects.equals(eggsRequired, other.eggsRequired)
        || !java.util.Objects.equals(incubationStartDate, other.incubationStartDate)
        || !java.util.Objects.equals(hatchOrArrivalDate, other.hatchOrArrivalDate)
        || !java.util.Objects.equals(latestOrderDate, other.latestOrderDate);
  }
}
