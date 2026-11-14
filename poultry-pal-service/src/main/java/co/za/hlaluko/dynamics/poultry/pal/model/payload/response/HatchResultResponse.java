package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.OutcomeCount;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class HatchResultResponse {
  private String id;
  private String hatcherCycleId;
  private String incubationBatchId;
  private String batchReference;
  private String cycleReference;
  private String hatcherId;
  private int eggsTransferred;
  private int hatchedChicks;
  private int unhatchedEggs;
  private int weakChicks;
  private List<OutcomeCount> otherOutcomes;
  private LocalDate resultDate;
  /** Hatched / transferred as a percentage; null when nothing was transferred. */
  private BigDecimal hatchRate;
  private BigDecimal weakRate;
  private String notes;
  private int revisionCount;
  private Instant updatedAt;
  private Long version;
}
