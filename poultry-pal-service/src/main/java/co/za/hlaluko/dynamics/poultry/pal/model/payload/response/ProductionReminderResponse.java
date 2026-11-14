package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderTaskType;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ProductionReminderResponse {
  private String id;
  private String sourceType;
  private String sourceId;
  private String sourceReference;
  private ReminderTaskType taskType;
  private String title;
  private LocalDate dueDate;
  private ReminderStatus status;
  /** True for an OPEN reminder whose due date is before today in the farm's time zone. */
  private boolean overdue;
  private String completedBy;
  private Instant completedAt;
  private String completionNote;
  private String cancelReason;
  private Long version;
}
