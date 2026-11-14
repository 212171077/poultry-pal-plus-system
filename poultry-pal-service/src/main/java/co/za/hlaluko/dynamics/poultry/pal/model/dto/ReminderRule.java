package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Generates one reminder per incubation batch, due {@code offsetDays} from the anchor date. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReminderRule {
  /** Stable identity within the farm; generated when blank. */
  @Size(max = 40)
  @Pattern(regexp = "^[A-Za-z0-9_-]*$")
  private String key;

  @NotNull private ReminderTaskType taskType;
  @NotNull private ReminderAnchor anchor;
  /** Negative means before the anchor date. */
  @NotNull @Min(-60) @Max(60) private Integer offsetDays;
  @NotBlank @Size(max = 100) private String title;
  private boolean enabled;
}
