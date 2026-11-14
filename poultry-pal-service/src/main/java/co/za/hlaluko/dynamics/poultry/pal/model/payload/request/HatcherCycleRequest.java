package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class HatcherCycleRequest {
  @NotBlank private String hatcherId;
  @NotNull @Min(1) @Max(1_000_000) private Integer quantity;
  @Size(max = 500) private String notes;
}
