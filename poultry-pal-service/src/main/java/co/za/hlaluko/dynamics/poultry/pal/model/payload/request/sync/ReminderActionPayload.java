package co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

/** Marks a feed, vaccine or medicine reminder as done. The reminder id is the operation entityId. */
@Data
public class ReminderActionPayload {
  @NotBlank
  @Pattern(regexp = "(?i)FEED|VACCINE|MEDICINE")
  private String reminderType;

  @Size(max = 100)
  private String action;

  @Size(max = 500)
  private String actionComment;
}
