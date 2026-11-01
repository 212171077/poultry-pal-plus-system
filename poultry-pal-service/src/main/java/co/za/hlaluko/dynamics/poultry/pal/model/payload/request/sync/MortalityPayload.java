package co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.Date;
import lombok.Data;

@Data
public class MortalityPayload {
  @NotNull private Date dateOccurred;

  @Min(1)
  private int numberOfDeaths;

  @NotBlank
  @Size(max = 200)
  private String reason;

  @Size(max = 100)
  private String recordedBy;
}
