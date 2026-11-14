package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import java.math.BigDecimal;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderRule;
import java.time.Instant;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

/** Farm-wide production assumptions. One document per farm (unique index on {@code farmId}). */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "production_settings")
public class ProductionSettings {
  @Id private String id;
  private String farmId;
  private String timeZone;
  private int incubationDays;
  private int transferDay;
  private int broodingDays;
  private BigDecimal expectedHatchRate;
  private BigDecimal expectedMortalityRate;
  private int defaultGrowOutDays;
  /** Null until the farm supplies a supplier lead time. */
  private Integer supplierLeadTimeDays;
  /** Null until first edited; the defaults apply in the meantime. */
  private List<ReminderRule> reminderRules;
  private Instant createdAt;
  private Instant updatedAt;
  private String createdBy;
  private String updatedBy;
  @Version private Long version;
}
