package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlanCalculation;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlanStatus;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

/** A saved target-date recommendation. Planning only: it does not reserve capacity. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "production_plans")
public class ProductionPlan {
  @Id private String id;
  private String farmId;
  private String name;
  private String notes;
  private PlanStatus status;
  private PlanCalculation calculation;
  /** Set while NEEDS_REVIEW: what the plan would become if accepted. */
  private PlanCalculation recalculation;
  /** Why the last commit, acceptance or cancellation was made. */
  private String decisionReason;
  private Instant createdAt;
  private Instant updatedAt;
  private String createdBy;
  private String updatedBy;
  @Version private Long version;
}
