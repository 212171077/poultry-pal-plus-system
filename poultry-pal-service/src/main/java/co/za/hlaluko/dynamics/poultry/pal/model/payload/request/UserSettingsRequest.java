package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UserSettingsRequest {

  private String id;
  @NotBlank
  private String userId;
  @NotBlank
  private String farmId;
  private String currency;
  private Boolean autoCreateReminders;
  private Boolean salesAlerts;
  private Boolean mortalityAlerts;
  private Boolean expenseAlerts;
  private Boolean dailyReminders;

}
