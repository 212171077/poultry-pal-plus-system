package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class TransitionCoop {
  private String id;
  private String displayName;
}
