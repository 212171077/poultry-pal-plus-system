package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UpdateReminderRequest {
  @NotBlank
  private String id;
  @NotBlank
  private String updatedByUserId;
  @NotBlank
  private String farmId;
  @NotBlank
  private String coopId;
  @NotBlank
  private String reminderType;
  @NotBlank
  private String action;
  private String actionComment;

}
