package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class PhaseTransitionRequest {

  @NotBlank
  private String userId;
  @NotBlank
  private String currentCoopId;
  @NotBlank
  private String farmId;
  @NotBlank
  private String newCoopId;
  @NotBlank
  private String newGrowingPhase;

}
