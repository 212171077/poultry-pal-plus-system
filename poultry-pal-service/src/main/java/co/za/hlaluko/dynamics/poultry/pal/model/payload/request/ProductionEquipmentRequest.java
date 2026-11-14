package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ProductionEquipmentRequest {
  /** Required on create; ignored on update (the type cannot change). */
  private EquipmentType type;
  @NotBlank @Size(max = 60) private String name;
  @NotNull @Min(1) @Max(1_000_000) private Integer capacity;
  private Boolean enabled;
  @Min(1) @Max(30) private Integer hatcherOccupancyDays;
  @Size(max = 500) private String notes;
  /** Required on update. */
  private Long version;
}
