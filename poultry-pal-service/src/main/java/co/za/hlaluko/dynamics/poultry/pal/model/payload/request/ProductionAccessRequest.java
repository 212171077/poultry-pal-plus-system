package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class ProductionAccessRequest {
  @NotNull private Boolean granted;
}
