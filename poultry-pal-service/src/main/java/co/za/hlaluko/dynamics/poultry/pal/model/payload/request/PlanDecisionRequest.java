package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class PlanDecisionRequest {
  @Size(max = 300) private String reason;
}
