package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class PhaseTransition {
  private GrowingPhase currentPhase;
  private GrowingPhase newPhase;
  private List<TransitionCoop> transitionCoops;
}
