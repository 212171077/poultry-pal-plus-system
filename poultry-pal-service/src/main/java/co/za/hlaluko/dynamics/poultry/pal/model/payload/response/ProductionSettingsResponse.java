package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderRule;
import java.math.BigDecimal;
import java.util.List;
import java.time.Instant;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ProductionSettingsResponse {
  private String id;
  private String farmId;
  private String timeZone;
  private int incubationDays;
  private int transferDay;
  private int broodingDays;
  private BigDecimal expectedHatchRate;
  private BigDecimal expectedMortalityRate;
  private int defaultGrowOutDays;
  private Integer supplierLeadTimeDays;
  private List<ReminderRule> reminderRules;
  /** True while the rates are the seeded estimates the farm has not yet reviewed. */
  private boolean estimatesOnly;
  private Instant updatedAt;
  private Long version;
}
