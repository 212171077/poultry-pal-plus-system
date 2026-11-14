package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.OutcomeCount;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * The finalised outcome of one hatcher cycle. Counts reconcile as
 * hatched + unhatched + other outcomes = eggs transferred; weak chicks are a subset of hatched.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "hatch_results")
public class HatchResult {
  @Id private String id;
  private String farmId;
  private String hatcherCycleId;
  private String incubationBatchId;
  private String batchReference;
  private String cycleReference;
  private String hatcherId;
  private int eggsTransferred;
  private int hatchedChicks;
  private int unhatchedEggs;
  private int weakChicks;
  @Builder.Default private List<OutcomeCount> otherOutcomes = new ArrayList<>();
  private LocalDate resultDate;
  private String notes;
  /** Previous values, appended on every edit. */
  @Builder.Default private List<Revision> revisions = new ArrayList<>();
  private Instant createdAt;
  private Instant updatedAt;
  private String createdBy;
  private String updatedBy;
  @Version private Long version;

  @Data
  @Builder
  @NoArgsConstructor
  @AllArgsConstructor
  public static class Revision {
    private Instant revisedAt;
    private String revisedBy;
    private int hatchedChicks;
    private int unhatchedEggs;
    private int weakChicks;
    private List<OutcomeCount> otherOutcomes;
    private LocalDate resultDate;
    private String notes;
  }
}
