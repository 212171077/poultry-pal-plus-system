package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.exception.ErrorCodes;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.SyncOperationLog;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.BatchCommandRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.BirdMovementRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.BirdPlacementRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.HatchResultRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.HatcherCycleRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.IncubationBatchRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.PlanDecisionRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.PlanRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.SyncOperation;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.PlanResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionSnapshotResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncOperationResult;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncOperationStatus;
import co.za.hlaluko.dynamics.poultry.pal.repository.SyncOperationLogRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

/**
 * Applies production commands queued offline by clients, and serves the snapshot they cache.
 *
 * <p>An operation's payload is {@code {"command": "...", "body": {...}}}. Business failures (such
 * as {@code CAPACITY_CONFLICT}) are reported per operation so one rejected change never blocks the
 * rest, and every result is logged by operation id so retries are idempotent.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProductionSyncService {
  private final ProductionAccessService accessService;
  private final ProductionSettingsService settingsService;
  private final ProductionEquipmentService equipmentService;
  private final IncubationService incubationService;
  private final ProductionReminderService reminderService;
  private final HatchResultService hatchResultService;
  private final PlacementService placementService;
  private final PlanningService planningService;
  private final SyncOperationLogRepository operationLogRepository;
  private final ObjectMapper objectMapper;
  private final Validator validator;

  public ProductionSnapshotResponse snapshot(UserDetailsImpl actor) {
    return new ProductionSnapshotResponse(
        Instant.now(),
        settingsService.get(actor),
        equipmentService.list(actor),
        incubationService.list(actor, null, 0, 100),
        reminderService.list(actor, null, 0, 100),
        placementService.list(actor, null, false),
        placementService.occupancy(actor),
        planningService.list(actor, false).stream().map(PlanResponse::from).toList());
  }

  public SyncOperationResult apply(UserDetailsImpl actor, SyncOperation op) {
    String farmId;
    try {
      farmId = accessService.requireManage(actor);
    } catch (ApiException e) {
      return rejected(op, e.getErrorCode(), e.getMessage(), null);
    }
    String logId = farmId + ":" + op.getOpId();
    SyncOperationLog previous = operationLogRepository.findById(logId).orElse(null);
    if (previous != null && previous.getResult() != null) {
      return previous.getResult().toBuilder().duplicate(true).build();
    }

    SyncOperationResult result;
    try {
      result = dispatch(actor, op);
    } catch (ApiException e) {
      result = rejected(op, e.getErrorCode(), e.getMessage(), null);
    } catch (RejectedOperation e) {
      result = rejected(op, ErrorCodes.VALIDATION_ERROR, e.getMessage(), e.errors);
    }

    if (result.getStatus() == SyncOperationStatus.REJECTED) {
      log.warn(
          "Production sync op rejected: farm={} op={} code={}",
          farmId,
          op.getOpId(),
          result.getErrorCode());
    }
    try {
      operationLogRepository.insert(
          SyncOperationLog.builder()
              .id(logId)
              .farmId(farmId)
              .userId(actor.getId())
              .result(result.toBuilder().serverRecord(null).build())
              .createdAt(new Date())
              .build());
    } catch (DuplicateKeyException ignored) {
      // A concurrent retry logged the same operation first.
    }
    return result;
  }

  private SyncOperationResult dispatch(UserDetailsImpl actor, SyncOperation op) {
    JsonNode payload = op.getPayload();
    String command = payload == null ? null : payload.path("command").asText(null);
    if (command == null) {
      throw new RejectedOperation("payload.command is required", null);
    }
    JsonNode body = payload.path("body");
    String id = op.getEntityId();
    Object record =
        switch (command) {
          case "BATCH_CREATE" ->
              incubationService.create(actor, parse(body, IncubationBatchRequest.class));
          case "BATCH_START" -> incubationService.start(actor, id, optional(body, BatchCommandRequest.class));
          case "BATCH_CANCEL" ->
              incubationService.cancel(actor, id, optional(body, BatchCommandRequest.class));
          case "CYCLE_RESERVE" ->
              incubationService.reserveCycle(actor, id, parse(body, HatcherCycleRequest.class));
          case "CYCLE_TRANSFER" ->
              incubationService.transferCycle(actor, id, optional(body, BatchCommandRequest.class));
          case "CYCLE_CANCEL" -> incubationService.cancelCycle(actor, id);
          case "REMINDER_COMPLETE" -> {
            BatchCommandRequest note = optional(body, BatchCommandRequest.class);
            yield reminderService.complete(actor, id, note == null ? null : note.getReason());
          }
          case "RESULT_RECORD" ->
              hatchResultService.record(actor, id, parse(body, HatchResultRequest.class));
          case "RESULT_EDIT" ->
              hatchResultService.edit(actor, id, parse(body, HatchResultRequest.class));
          case "PLACEMENT_CREATE" -> placementService.place(actor, parse(body, BirdPlacementRequest.class));
          case "MOVEMENT_ADD" ->
              placementService.addMovement(
                  actor, id, parse(body, BirdMovementRequest.class), op.getOpId());
          case "PLAN_SAVE" -> PlanResponse.from(planningService.save(actor, parse(body, PlanRequest.class)));
          case "PLAN_COMMIT" ->
              PlanResponse.from(
                  planningService.commit(actor, id, optional(body, PlanDecisionRequest.class)));
          case "PLAN_ACCEPT" ->
              PlanResponse.from(
                  planningService.acceptRecalculation(
                      actor, id, optional(body, PlanDecisionRequest.class)));
          case "PLAN_CANCEL" ->
              PlanResponse.from(
                  planningService.cancel(actor, id, optional(body, PlanDecisionRequest.class)));
          default -> throw new RejectedOperation("Unknown production command: " + command, null);
        };
    return SyncOperationResult.builder()
        .opId(op.getOpId())
        .entityType(op.getEntityType())
        .entityId(op.getEntityId())
        .status(SyncOperationStatus.APPLIED)
        .serverRecord(record)
        .build();
  }

  private <T> T optional(JsonNode body, Class<T> type) {
    return body == null || body.isMissingNode() || body.isNull() ? null : parse(body, type);
  }

  private <T> T parse(JsonNode body, Class<T> type) {
    if (body == null || body.isMissingNode() || body.isNull()) {
      throw new RejectedOperation("payload.body is required", null);
    }
    T value;
    try {
      value = objectMapper.treeToValue(body, type);
    } catch (JsonProcessingException | IllegalArgumentException e) {
      throw new RejectedOperation("payload.body is malformed", null);
    }
    Set<ConstraintViolation<T>> violations = validator.validate(value);
    if (!violations.isEmpty()) {
      throw new RejectedOperation(
          "Validation failed",
          violations.stream().map(v -> v.getPropertyPath() + ": " + v.getMessage()).sorted().toList());
    }
    return value;
  }

  private static SyncOperationResult rejected(
      SyncOperation op, String code, String message, List<String> errors) {
    return SyncOperationResult.builder()
        .opId(op.getOpId())
        .entityType(op.getEntityType())
        .entityId(op.getEntityId())
        .status(SyncOperationStatus.REJECTED)
        .errorCode(code)
        .message(message)
        .errors(errors)
        .build();
  }

  private static final class RejectedOperation extends RuntimeException {
    private final List<String> errors;

    RejectedOperation(String message, List<String> errors) {
      super(message, null, false, false);
      this.errors = errors;
    }
  }
}
