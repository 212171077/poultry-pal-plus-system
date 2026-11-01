package co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.CoopType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.Date;
import lombok.Data;

@Data
public class CoopPayload {
  @NotBlank
  @Size(max = 50)
  private String coopName;

  @NotNull private CoopType coopType;
  @NotNull private GrowingPhase growthPhase;

  @Min(0)
  private int numberOfChickens;

  private Date chickenArrivalDate;
}
