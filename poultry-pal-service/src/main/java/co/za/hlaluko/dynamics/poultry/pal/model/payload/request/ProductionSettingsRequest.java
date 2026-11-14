package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderRule;
import jakarta.validation.Valid;
import java.util.List;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import lombok.Data;

@Data
public class ProductionSettingsRequest {
  @NotBlank private String timeZone;
  @NotNull @Min(1) @Max(60) private Integer incubationDays;
  @NotNull @Min(1) @Max(59) private Integer transferDay;
  @NotNull @Min(0) @Max(60) private Integer broodingDays;
  @NotNull @DecimalMin("0.0") @DecimalMax("1.0") @Digits(integer = 1, fraction = 4)
  private BigDecimal expectedHatchRate;
  @NotNull @DecimalMin("0.0") @DecimalMax("1.0") @Digits(integer = 1, fraction = 4)
  private BigDecimal expectedMortalityRate;
  @NotNull @Min(1) @Max(365) private Integer defaultGrowOutDays;
  @Min(0) @Max(365) private Integer supplierLeadTimeDays;
  /** When null the existing reminder rules are kept. */
  @Valid @Size(max = 20) private List<ReminderRule> reminderRules;
  /** The version the client last read; a stale value is rejected with 409. */
  @NotNull private Long version;
}
