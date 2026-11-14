package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.BatchStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderAnchor;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderRule;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderTaskType;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.IncubationBatch;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionReminder;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionSettings;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionReminderResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.IncubationBatchRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionReminderRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionSettingsRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

/**
 * Generates and manages preparation reminders from incubation batches. Reconciliation is
 * idempotent: one reminder exists per (batch, rule); date and rule changes update or cancel only
 * OPEN reminders, and completed reminders are never rewritten.
 */
@Service
@RequiredArgsConstructor
public class ProductionReminderService {
  static final String SOURCE_BATCH = "INCUBATION_BATCH";
  private static final Set<BatchStatus> LIVE_STATUSES =
      EnumSet.of(
          BatchStatus.PLANNED,
          BatchStatus.INCUBATING,
          BatchStatus.TRANSFERRED,
          BatchStatus.COMPLETED);

  private final ProductionAccessService accessService;
  private final ProductionSettingsRepository settingsRepository;
  private final IncubationBatchRepository batchRepository;
  private final ProductionReminderRepository reminderRepository;

  public static List<ReminderRule> defaultRules() {
    return List.of(
        rule("TRANSFER", ReminderTaskType.TRANSFER, ReminderAnchor.BATCH_TRANSFER, 0, "Transfer eggs to the hatcher"),
        rule("BROODER", ReminderTaskType.BROODER_PREPARATION, ReminderAnchor.BATCH_HATCH, -2, "Prepare the brooder for chicks"),
        rule("PACKAGING", ReminderTaskType.PACKAGING, ReminderAnchor.BATCH_HATCH, 0, "Prepare chick boxes and packaging"),
        rule("VACCINATION", ReminderTaskType.VACCINATION, ReminderAnchor.BATCH_HATCH, 0, "Vaccinate day-old chicks"));
  }

  private static ReminderRule rule(
      String key, ReminderTaskType type, ReminderAnchor anchor, int offset, String title) {
    return ReminderRule.builder()
        .key(key)
        .taskType(type)
        .anchor(anchor)
        .offsetDays(offset)
        .title(title)
        .enabled(true)
        .build();
  }

  public static List<ReminderRule> effectiveRules(ProductionSettings settings) {
    return settings.getReminderRules() == null ? defaultRules() : settings.getReminderRules();
  }

  public List<ProductionReminderResponse> list(
      UserDetailsImpl actor, ReminderStatus status, int page, int size) {
    String farmId = accessService.requireManage(actor);
    LocalDate today = today(farmId);
    return reminderRepository
        .findByFarmIdAndStatusOrderByDueDateAsc(
            farmId,
            status == null ? ReminderStatus.OPEN : status,
            PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100)))
        .stream()
        .map(r -> toResponse(r, today))
        .toList();
  }

  public ProductionReminderResponse complete(UserDetailsImpl actor, String id, String note) {
    String farmId = accessService.requireManage(actor);
    ProductionReminder reminder =
        reminderRepository
            .findByIdAndFarmId(id, farmId)
            .orElseThrow(() -> ApiException.notFound("Reminder not found"));
    if (reminder.getStatus() == ReminderStatus.CANCELLED) {
      throw ApiException.conflict("This reminder was cancelled");
    }
    if (reminder.getStatus() == ReminderStatus.OPEN) {
      Instant now = Instant.now();
      reminder.setStatus(ReminderStatus.COMPLETED);
      reminder.setCompletedBy(actor.getId());
      reminder.setCompletedAt(now);
      reminder.setCompletionNote(note == null || note.isBlank() ? null : note.trim());
      reminder.setUpdatedAt(now);
      reminderRepository.save(reminder);
    }
    return toResponse(reminder, today(farmId));
  }

  /** Brings one batch's reminders in line with its current dates, status and the farm's rules. */
  public void reconcile(IncubationBatch batch) {
    ProductionSettings settings = settingsRepository.findByFarmId(batch.getFarmId()).orElse(null);
    reconcile(batch, settings == null ? defaultRules() : effectiveRules(settings));
  }

  /** Re-evaluates every live batch after the farm's reminder rules change. */
  public void reconcileFarm(String farmId, List<ReminderRule> rules) {
    batchRepository.findByFarmIdAndStatusIn(farmId, LIVE_STATUSES)
        .forEach(batch -> reconcile(batch, rules));
  }

  private void reconcile(IncubationBatch batch, List<ReminderRule> rules) {
    Map<String, ProductionReminder> existing =
        reminderRepository
            .findByFarmIdAndSourceTypeAndSourceId(batch.getFarmId(), SOURCE_BATCH, batch.getId())
            .stream()
            .collect(Collectors.toMap(ProductionReminder::getRuleKey, Function.identity()));
    Instant now = Instant.now();
    boolean live = LIVE_STATUSES.contains(batch.getStatus());
    Map<String, ReminderRule> active = new HashMap<>();
    if (live) {
      rules.stream().filter(ReminderRule::isEnabled).forEach(r -> active.put(r.getKey(), r));
    }

    for (ReminderRule rule : active.values()) {
      LocalDate due = anchorDate(batch, rule.getAnchor()).plusDays(rule.getOffsetDays());
      ProductionReminder current = existing.get(rule.getKey());
      if (current == null) {
        create(batch, rule, due, now);
      } else if (current.getStatus() != ReminderStatus.COMPLETED) {
        boolean changed =
            current.getStatus() != ReminderStatus.OPEN
                || !due.equals(current.getDueDate())
                || !rule.getTitle().equals(current.getTitle());
        if (changed) {
          current.setStatus(ReminderStatus.OPEN);
          current.setCancelReason(null);
          current.setDueDate(due);
          current.setTitle(rule.getTitle());
          current.setTaskType(rule.getTaskType());
          current.setSourceReference(batch.getReference());
          current.setUpdatedAt(now);
          reminderRepository.save(current);
        }
      }
    }
    String reason = live ? "Reminder rule disabled or removed" : "Batch " + batch.getStatus().name().toLowerCase();
    for (ProductionReminder reminder : existing.values()) {
      if (reminder.getStatus() == ReminderStatus.OPEN && !active.containsKey(reminder.getRuleKey())) {
        reminder.setStatus(ReminderStatus.CANCELLED);
        reminder.setCancelReason(reason);
        reminder.setUpdatedAt(now);
        reminderRepository.save(reminder);
      }
    }
  }

  private void create(IncubationBatch batch, ReminderRule rule, LocalDate due, Instant now) {
    try {
      reminderRepository.save(
          ProductionReminder.builder()
              .farmId(batch.getFarmId())
              .sourceType(SOURCE_BATCH)
              .sourceId(batch.getId())
              .sourceReference(batch.getReference())
              .ruleKey(rule.getKey())
              .taskType(rule.getTaskType())
              .title(rule.getTitle())
              .dueDate(due)
              .status(ReminderStatus.OPEN)
              .createdAt(now)
              .updatedAt(now)
              .build());
    } catch (DuplicateKeyException ignored) {
      // A concurrent reconcile already created it.
    }
  }

  private LocalDate anchorDate(IncubationBatch batch, ReminderAnchor anchor) {
    return switch (anchor) {
      case BATCH_START -> batch.getPlannedStartDate();
      case BATCH_TRANSFER -> batch.getPlannedTransferDate();
      case BATCH_HATCH -> batch.getPlannedHatchDate();
    };
  }

  private LocalDate today(String farmId) {
    return LocalDate.now(
        settingsRepository
            .findByFarmId(farmId)
            .map(s -> ZoneId.of(s.getTimeZone()))
            .orElse(ZoneId.of(ProductionSettingsService.DEFAULT_TIME_ZONE)));
  }

  private ProductionReminderResponse toResponse(ProductionReminder r, LocalDate today) {
    return ProductionReminderResponse.builder()
        .id(r.getId())
        .sourceType(r.getSourceType())
        .sourceId(r.getSourceId())
        .sourceReference(r.getSourceReference())
        .taskType(r.getTaskType())
        .title(r.getTitle())
        .dueDate(r.getDueDate())
        .status(r.getStatus())
        .overdue(r.getStatus() == ReminderStatus.OPEN && r.getDueDate().isBefore(today))
        .completedBy(r.getCompletedBy())
        .completedAt(r.getCompletedAt())
        .completionNote(r.getCompletionNote())
        .cancelReason(r.getCancelReason())
        .version(r.getVersion())
        .build();
  }
}
