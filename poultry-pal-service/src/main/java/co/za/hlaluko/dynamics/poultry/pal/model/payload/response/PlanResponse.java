package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlanCalculation;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlanStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionPlan;
import java.time.Instant;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class PlanResponse {
  private String id;
  private String name;
  private String notes;
  private PlanStatus status;
  private PlanCalculation calculation;
  /** Only while NEEDS_REVIEW: the numbers the plan would take if accepted. */
  private PlanCalculation recalculation;
  private String decisionReason;
  private Instant createdAt;
  private Instant updatedAt;
  private Long version;

  public static PlanResponse from(ProductionPlan p) {
    return PlanResponse.builder()
        .id(p.getId())
        .name(p.getName())
        .notes(p.getNotes())
        .status(p.getStatus())
        .calculation(p.getCalculation())
        .recalculation(p.getRecalculation())
        .decisionReason(p.getDecisionReason())
        .createdAt(p.getCreatedAt())
        .updatedAt(p.getUpdatedAt())
        .version(p.getVersion())
        .build();
  }
}
