package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
@Document(collection = "user_settings")
public class UserSettings {

    @Id
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
