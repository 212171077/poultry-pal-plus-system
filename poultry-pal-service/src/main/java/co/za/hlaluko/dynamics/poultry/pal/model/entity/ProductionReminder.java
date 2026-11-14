package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderTaskType;
import java.time.Instant;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * A task generated from a production event. The unique key (farm, source, rule) makes generation
 * idempotent; completed reminders are never rewritten.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "production_reminders")
public class ProductionReminder {
  @Id private String id;
  private String farmId;
  private String sourceType;
  private String sourceId;
  private String sourceReference;
  private String ruleKey;
  private ReminderTaskType taskType;
  private String title;
  private LocalDate dueDate;
  private ReminderStatus status;
  private String completedBy;
  private Instant completedAt;
  private String completionNote;
  private String cancelReason;
  private Instant createdAt;
  private Instant updatedAt;
  @Version private Long version;
}
