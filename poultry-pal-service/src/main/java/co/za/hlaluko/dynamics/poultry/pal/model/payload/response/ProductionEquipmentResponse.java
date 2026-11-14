package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import java.time.Instant;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ProductionEquipmentResponse {
  private String id;
  private String farmId;
  private EquipmentType type;
  private String name;
  private int capacity;
  private boolean enabled;
  private Integer hatcherOccupancyDays;
  private String notes;
  private Instant updatedAt;
  private Long version;
}
