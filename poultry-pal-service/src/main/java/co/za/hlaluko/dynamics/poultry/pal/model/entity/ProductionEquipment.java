package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

/** A capacity resource (incubator, hatcher or chicken house) owned by one farm. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "production_equipment")
public class ProductionEquipment {
  @Id private String id;
  private String farmId;
  private EquipmentType type;
  private String name;
  private int capacity;
  private boolean enabled;
  /** Hatchers only: days an egg lot occupies the hatcher. */
  private Integer hatcherOccupancyDays;
  private String notes;
  /** Archived equipment is hidden and kept so referencing records stay valid. */
  private boolean archived;
  private Instant createdAt;
  private Instant updatedAt;
  private String createdBy;
  private String updatedBy;
  @Version private Long version;
}
