package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UserSettingsResponse {

    private String id;
    private String userId;
    private String farmId;
    private String currency;
    private Boolean autoCreateReminders;
    private Boolean salesAlerts;
    private Boolean mortalityAlerts;
    private Boolean expenseAlerts;
    private Boolean dailyReminders;

}
