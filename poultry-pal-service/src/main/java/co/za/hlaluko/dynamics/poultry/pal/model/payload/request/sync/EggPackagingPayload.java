package co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Date;
import lombok.Data;

@Data
public class EggPackagingPayload {
  @NotBlank
  @Size(max = 50)
  private String eggSize;

  /** One of "6 eggs box", "12 eggs box", "18 eggs box", "30 eggs box", "60 eggs box". */
  @NotBlank private String boxSize;

  @Min(1)
  private int numberOfBoxes;

  @Size(max = 500)
  private String additionalInfo;

  private Date createdDate;
}
