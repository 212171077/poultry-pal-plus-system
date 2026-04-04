package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class UpdateMortalityRequest {
  private String id;
  private String farmId;
  private String coopId;
  private Date dateOccurred;
  private int numberOfDeaths;
  private String reason;
  private String recordedBy;
}
