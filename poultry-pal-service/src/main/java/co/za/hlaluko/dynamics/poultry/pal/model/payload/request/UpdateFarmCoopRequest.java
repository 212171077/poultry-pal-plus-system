package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.CoopType;
import java.util.Date;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UpdateFarmCoopRequest {
  private String farmId;
  private String coopId;
  private String coopName;
  private CoopType coopType;
  private GrowingPhase growthPhase;
  private int numberOfChickens;
  private Date chickenArrivalDate;
}
