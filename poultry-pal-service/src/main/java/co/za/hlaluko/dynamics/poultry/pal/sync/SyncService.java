package co.za.hlaluko.dynamics.poultry.pal.sync;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.exception.ErrorCodes;
import co.za.hlaluko.dynamics.poultry.pal.service.ProductionSyncService;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Address;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.CoopType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.EggPackagingRecord;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Expense;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Feed;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Medicine;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Mortality;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Reminder;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Sale;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncEntityType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncTombstone;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncTracked;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Vaccine;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.CoopArchive;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.SyncOperationLog;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.CoopActionPayload;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.CoopPayload;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.EggPackagingPayload;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.ExpensePayload;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.FarmPayload;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.MortalityPayload;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.ReminderActionPayload;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.SalePayload;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.SyncOperation;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.SyncOperationType;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.SyncPushRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserSettingsResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.FarmSnapshot;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncBootstrapResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncChangesResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncOperationResult;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncOperationStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncPushResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.CoopArchiveRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.SyncOperationLogRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserSettingsRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import co.za.hlaluko.dynamics.poultry.pal.service.CoopReminderFactory;
import co.za.hlaluko.dynamics.poultry.pal.service.FarmServiceImpl;
import co.za.hlaluko.dynamics.poultry.pal.utils.EggBoxSizes;
import co.za.hlaluko.dynamics.poultry.pal.utils.EggSalePackaging;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.regex.Pattern;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Offline sync for the web client: batched idempotent writes (push), cursor-based delta reads
 * (changes) and a full snapshot (bootstrap).
 *
 * <p>The farm is always resolved from the authenticated principal, never from the request.
 */
@Service
public class SyncService {
  private static final Logger logger = LogManager.getLogger(SyncService.class);

  public static final int DEFAULT_PAGE_SIZE = 500;
  public static final int MAX_PAGE_SIZE = 2000;
  static final int MAX_SAVE_ATTEMPTS = 3;
  private static final Pattern ID_PATTERN = Pattern.compile(SyncOperation.ID_PATTERN);
  private static final List<String> COOP_CHILD_FIELDS =
      List.of("sales", "mortalities", "expenses", "eggPackagingRecords");
  private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

  private final FarmRepository farmRepository;
  private final CoopArchiveRepository coopArchiveRepository;
  private final SyncOperationLogRepository operationLogRepository;
  private final UserRepository userRepository;
  private final UserSettingsRepository userSettingsRepository;
  private final FarmServiceImpl farmService;
  private final CoopReminderFactory coopReminderFactory;
  private final ObjectMapper objectMapper;
  private final Validator validator;
  private final ProductionSyncService productionSyncService;

  public SyncService(
      FarmRepository farmRepository,
      CoopArchiveRepository coopArchiveRepository,
      SyncOperationLogRepository operationLogRepository,
      UserRepository userRepository,
      UserSettingsRepository userSettingsRepository,
      FarmServiceImpl farmService,
      CoopReminderFactory coopReminderFactory,
      ObjectMapper objectMapper,
      Validator validator,
      ProductionSyncService productionSyncService) {
    this.farmRepository = farmRepository;
    this.coopArchiveRepository = coopArchiveRepository;
    this.operationLogRepository = operationLogRepository;
    this.userRepository = userRepository;
    this.userSettingsRepository = userSettingsRepository;
    this.farmService = farmService;
    this.coopReminderFactory = coopReminderFactory;
    this.objectMapper = objectMapper;
    this.validator = validator;
    this.productionSyncService = productionSyncService;
  }

  // ---------------------------------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------------------------------

  public SyncPushResponse push(UserDetailsImpl user, SyncPushRequest request) {
    String farmId = requireFarmId(user);
    List<SyncOperation> operations = request.getOperations();
    Map<String, SyncOperationResult> processed = loadProcessed(farmId, operations);

    for (int attempt = 1; ; attempt++) {
      Farm farm = loadFarm(farmId);
      PushContext ctx = new PushContext(user, farm);
      List<Outcome> outcomes = new ArrayList<>(operations.size());
      Map<String, Outcome> firstByOpId = new HashMap<>();

      for (SyncOperation op : operations) {
        SyncOperationResult previous = processed.get(op.getOpId());
        if (previous != null) {
          outcomes.add(Outcome.duplicateOf(previous.toBuilder().duplicate(true).build()));
          continue;
        }
        Outcome first = firstByOpId.get(op.getOpId());
        if (first != null) {
          outcomes.add(Outcome.duplicateOf(first));
          continue;
        }
        Outcome outcome = apply(ctx, op);
        firstByOpId.put(op.getOpId(), outcome);
        outcomes.add(outcome);
      }

      if (ctx.mutated) {
        try {
          farm = farmRepository.save(farm);
        } catch (OptimisticLockingFailureException e) {
          if (attempt >= MAX_SAVE_ATTEMPTS) {
            throw new ApiException(
                HttpStatus.CONFLICT,
                ErrorCodes.CONFLICT,
                "The farm is being updated by someone else, please retry");
          }
          logger.info("Sync push hit a concurrent farm update, retrying (attempt {})", attempt);
          continue;
        }
      }

      // Archives are written only once the farm save succeeded, so a retried batch cannot duplicate them.
      if (!ctx.archives.isEmpty()) {
        coopArchiveRepository.saveAll(ctx.archives);
      }

      List<SyncOperationResult> results = new ArrayList<>(outcomes.size());
      List<SyncOperationLog> logs = new ArrayList<>();
      Date now = new Date();
      for (Outcome outcome : outcomes) {
        SyncOperationResult result = outcome.finish(this, farm);
        results.add(result);
        if (!result.isDuplicate()) {
          logs.add(
              SyncOperationLog.builder()
                  .id(logId(farmId, result.getOpId()))
                  .farmId(farmId)
                  .userId(user.getId())
                  .result(result.toBuilder().serverRecord(null).build())
                  .createdAt(now)
                  .build());
        }
      }
      saveLogs(logs);
      return SyncPushResponse.builder().results(results).serverVersion(nz(farm.getVersion())).build();
    }
  }

  private Map<String, SyncOperationResult> loadProcessed(
      String farmId, List<SyncOperation> operations) {
    List<String> ids =
        operations.stream().map(op -> logId(farmId, op.getOpId())).distinct().toList();
    Map<String, SyncOperationResult> processed = new HashMap<>();
    for (SyncOperationLog log : operationLogRepository.findAllById(ids)) {
      if (log.getResult() != null && farmId.equals(log.getFarmId())) {
        processed.put(log.getResult().getOpId(), log.getResult());
      }
    }
    return processed;
  }

  private void saveLogs(List<SyncOperationLog> logs) {
    for (SyncOperationLog log : logs) {
      try {
        operationLogRepository.insert(log);
      } catch (DuplicateKeyException e) {
        logger.debug("Sync operation {} already logged", log.getId());
      }
    }
  }

  private static String logId(String farmId, String opId) {
    return farmId + ":" + opId;
  }

  private Outcome apply(PushContext ctx, SyncOperation op) {
    try {
      if (op.getEntityType() != SyncEntityType.FARM && op.getEntityType() != SyncEntityType.PRODUCTION) {
        requireValidId(op.getEntityId(), "entityId");
      }
      return switch (op.getEntityType()) {
        case FARM -> applyFarm(ctx, op);
        case COOP -> applyCoop(ctx, op);
        case SALE, MORTALITY, EXPENSE, EGG_PACKAGING -> applyChild(ctx, op);
        case REMINDER -> applyReminder(ctx, op);
        case PRODUCTION -> Outcome.done(productionSyncService.apply(ctx.user, op));
      };
    } catch (OperationRejected e) {
      return Outcome.done(
          base(op)
              .status(SyncOperationStatus.REJECTED)
              .errorCode(e.code)
              .message(e.getMessage())
              .errors(e.errors)
              .build());
    }
  }

  private Outcome applyFarm(PushContext ctx, SyncOperation op) {
    requireOperation(op, SyncOperationType.UPSERT);
    if (!ctx.canManageFarm) {
      throw OperationRejected.forbidden("Only the farm owner or a farm manager can edit the farm");
    }
    Farm farm = ctx.farm;
    if (!Objects.equals(op.getBaseVersion(), nz(farm.getDetailsVersion()))) {
      return Outcome.done(
          base(op)
              .entityId(farm.getId())
              .status(SyncOperationStatus.CONFLICT)
              .errorCode(ErrorCodes.CONFLICT)
              .message("Farm details were changed on the server")
              .version(nz(farm.getDetailsVersion()))
              .serverRecord(farmSnapshot(farm))
              .build());
    }
    FarmPayload payload = payload(op, FarmPayload.class);
    farm.setFarmName(payload.getFarmName());
    Address address = farm.getAddress() == null ? new Address() : farm.getAddress();
    address.setAddressLine1(payload.getAddressLine1());
    address.setAddressLine2(payload.getAddressLine2());
    address.setCity(payload.getCity());
    address.setState(payload.getState());
    address.setPostalCode(payload.getPostalCode());
    address.setCountry(payload.getCountry());
    farm.setAddress(address);
    farm.setUpdatedByUserId(ctx.user.getId());
    ctx.mutated = true;
    return Outcome.appliedFarm(base(op).entityId(farm.getId()));
  }

  private Outcome applyCoop(PushContext ctx, SyncOperation op) {
    Coop existing = ctx.findCoop(op.getEntityId());
    String key = SyncEntityType.COOP + ":" + op.getEntityId();

    if (op.getOperation() == SyncOperationType.DELETE) {
      if (existing == null) {
        return Outcome.deleted(base(op));
      }
      if (!ctx.canManageFarm) {
        throw OperationRejected.forbidden("Only the farm owner or a farm manager can delete coops");
      }
      if (op.getBaseVersion() != null && isStale(ctx, key, existing, op)) {
        return conflict(op, existing, null);
      }
      ctx.coops().remove(existing);
      ctx.touched.add(key);
      ctx.mutated = true;
      return Outcome.deleted(base(op));
    }

    if (op.getOperation() == SyncOperationType.ACTION) {
      return applyCoopAction(ctx, op, existing);
    }
    requireOperation(op, SyncOperationType.UPSERT);
    CoopPayload payload = payload(op, CoopPayload.class);
    boolean duplicateName =
        ctx.coops().stream()
            .anyMatch(
                c ->
                    !c.getId().equals(op.getEntityId())
                        && c.getCoopName() != null
                        && c.getCoopName().equalsIgnoreCase(payload.getCoopName())
                        && c.getCoopType() == payload.getCoopType()
                        && c.getGrowthPhase() == payload.getGrowthPhase());
    if (duplicateName) {
      throw new OperationRejected(ErrorCodes.DUPLICATE, "Coop already exists", null);
    }

    if (existing != null) {
      if (!ctx.canAccess(existing)) {
        throw OperationRejected.forbidden("You are not assigned to this coop");
      }
      if (isStale(ctx, key, existing, op)) {
        return conflict(op, existing, null);
      }
      existing.setCoopName(payload.getCoopName());
      existing.setCoopType(payload.getCoopType());
      existing.setGrowthPhase(payload.getGrowthPhase());
      existing.setNumberOfChickens(payload.getNumberOfChickens());
      existing.setChickenArrivalDate(payload.getChickenArrivalDate());
      if (existing.getChickenArrivalDate() != null
          && existing.getNumberOfChickens() > 0
          && existing.getReminder() == null) {
        existing.setReminder(
            coopReminderFactory.buildReminders(
                payload.getChickenArrivalDate(),
                payload.getCoopType(),
                payload.getGrowthPhase()));
      }
      ctx.touched.add(key);
      ctx.mutated = true;
      return Outcome.applied(base(op), existing, null);
    }

    if (!ctx.canManageFarm) {
      throw OperationRejected.forbidden("Only the farm owner or a farm manager can create coops");
    }
    if (op.getBaseVersion() != null) {
      return conflict(op, null, null);
    }
    List<String> responsible = new ArrayList<>();
    if (!ctx.user.isFarmOwner()) {
      // Non-owners only see coops they are responsible for, so keep the creator's access.
      responsible.add(ctx.user.getId());
    }
    Coop coop =
        Coop.builder()
            .id(op.getEntityId())
            .coopName(payload.getCoopName())
            .coopType(payload.getCoopType())
            .growthPhase(payload.getGrowthPhase())
            .numberOfChickens(payload.getNumberOfChickens())
            .chickenArrivalDate(payload.getChickenArrivalDate())
            .createdDate(new Date())
            .reminder(
                coopReminderFactory.buildReminders(
                    payload.getChickenArrivalDate(),
                    payload.getCoopType(),
                    payload.getGrowthPhase()))
            .sales(new ArrayList<>())
            .mortalities(new ArrayList<>())
            .expenses(new ArrayList<>())
            .eggPackagingRecords(new ArrayList<>())
            .responsibleUserIds(responsible)
            .build();
    ctx.coops().add(coop);
    ctx.touched.add(key);
    ctx.mutated = true;
    return Outcome.applied(base(op), coop, null);
  }

  /**
   * New batch and phase transition. Actions are explicit commands on the coop as it is now, so they
   * are not version-checked; the records they archive or move are tracked like any other change.
   */
  private Outcome applyCoopAction(PushContext ctx, SyncOperation op, Coop coop) {
    if (coop == null) {
      throw new OperationRejected(ErrorCodes.NOT_FOUND, "Coop not found", null);
    }
    if (!ctx.canAccess(coop)) {
      throw OperationRejected.forbidden("You are not assigned to this coop");
    }
    CoopActionPayload payload = payload(op, CoopActionPayload.class);
    return switch (payload.getAction()) {
      case NEW_BATCH -> startNewBatch(ctx, op, coop, payload.getBatch());
      case PHASE_TRANSITION ->
          transitionPhase(ctx, op, coop, payload.getNewGrowthPhase(), payload.getTargetCoopId());
    };
  }

  private Outcome startNewBatch(PushContext ctx, SyncOperation op, Coop coop, CoopPayload batch) {
    if (!ctx.canManageFarm) {
      throw OperationRejected.forbidden(
          "Only the farm owner or a farm manager can start a new batch");
    }
    if (batch == null) {
      throw OperationRejected.validation("batch is required for NEW_BATCH");
    }
    ctx.archives.add(
        CoopArchive.builder()
            .coop(objectMapper.convertValue(coop, Coop.class))
            .farmId(ctx.farm.getId())
            .createdDate(new Date())
            .build());
    coop.setCoopName(batch.getCoopName());
    coop.setCoopType(batch.getCoopType());
    coop.setGrowthPhase(batch.getGrowthPhase());
    coop.setNumberOfChickens(batch.getNumberOfChickens());
    coop.setChickenArrivalDate(batch.getChickenArrivalDate());
    coop.setSales(new ArrayList<>());
    coop.setMortalities(new ArrayList<>());
    coop.setExpenses(new ArrayList<>());
    coop.setEggPackagingRecords(new ArrayList<>());
    coop.setPhaseTransition(null);
    coop.setReminder(
        coopReminderFactory.buildReminders(
            batch.getChickenArrivalDate(), batch.getCoopType(), batch.getGrowthPhase()));
    ctx.touched.add(SyncEntityType.COOP + ":" + coop.getId());
    ctx.mutated = true;
    return Outcome.applied(base(op), coop, null);
  }

  private Outcome transitionPhase(
      PushContext ctx, SyncOperation op, Coop coop, GrowingPhase newPhase, String targetId) {
    if (newPhase == null) {
      throw OperationRejected.validation("newGrowthPhase is required for PHASE_TRANSITION");
    }
    if (targetId == null || targetId.equals(coop.getId())) {
      coop.setGrowthPhase(newPhase);
      coop.setPhaseTransition(null);
      ctx.touched.add(SyncEntityType.COOP + ":" + coop.getId());
      ctx.mutated = true;
      return Outcome.applied(base(op), coop, null);
    }

    Coop target = ctx.findCoop(targetId);
    if (target == null) {
      throw new OperationRejected(ErrorCodes.NOT_FOUND, "Target coop not found", null);
    }
    if (!ctx.canAccess(target)) {
      throw OperationRejected.forbidden("You are not assigned to the target coop");
    }
    if (target.getCoopType() != coop.getCoopType()) {
      throw OperationRejected.validation("The target coop must be the same coop type");
    }
    if (target.getNumberOfChickens() > 0) {
      throw OperationRejected.validation(
          "The target coop still has chickens. Start a new batch there or move them first");
    }
    // The target takes over the flock, its schedule and its records (appended, never dropped).
    target.setGrowthPhase(newPhase);
    target.setNumberOfChickens(coop.getNumberOfChickens());
    target.setChickenArrivalDate(coop.getChickenArrivalDate());
    target.setReminder(coop.getReminder());
    target.setPhaseTransition(null);
    for (SyncEntityType type :
        List.of(
            SyncEntityType.SALE,
            SyncEntityType.MORTALITY,
            SyncEntityType.EXPENSE,
            SyncEntityType.EGG_PACKAGING)) {
      List<SyncTracked> moved = children(coop, type);
      children(target, type).addAll(moved);
      moved.clear();
    }
    // The source coop is empty and ready for the next flock.
    coop.setGrowthPhase(GrowingPhase.BROODING_PHASE);
    coop.setNumberOfChickens(0);
    coop.setChickenArrivalDate(null);
    coop.setReminder(null);
    coop.setPhaseTransition(null);
    ctx.touched.add(SyncEntityType.COOP + ":" + coop.getId());
    ctx.touched.add(SyncEntityType.COOP + ":" + target.getId());
    ctx.mutated = true;
    return Outcome.applied(base(op), coop, null);
  }

  private Outcome applyChild(PushContext ctx, SyncOperation op) {
    SyncEntityType type = op.getEntityType();
    String key = type + ":" + op.getEntityId();
    ChildRef existing = ctx.findChild(type, op.getEntityId());

    if (op.getOperation() == SyncOperationType.DELETE) {
      if (existing == null) {
        return Outcome.deleted(base(op));
      }
      if (!ctx.canAccess(existing.coop())) {
        throw OperationRejected.forbidden("You are not assigned to this coop");
      }
      if (op.getBaseVersion() != null && isStale(ctx, key, existing.record(), op)) {
        return conflict(op, existing.record(), existing.coop().getId());
      }
      children(existing.coop(), type).remove(existing.record());
      ctx.touched.add(key);
      ctx.mutated = true;
      return Outcome.deleted(base(op).coopId(existing.coop().getId()));
    }

    requireOperation(op, SyncOperationType.UPSERT);
    if (existing != null) {
      Coop coop = existing.coop();
      if (!ctx.canAccess(coop)) {
        throw OperationRejected.forbidden("You are not assigned to this coop");
      }
      if (isStale(ctx, key, existing.record(), op)) {
        return conflict(op, existing.record(), coop.getId());
      }
      populateChild(ctx, op, coop, existing.record(), false);
      ctx.touched.add(key);
      ctx.mutated = true;
      return Outcome.applied(base(op), existing.record(), coop.getId());
    }

    requireValidId(op.getCoopId(), "coopId");
    Coop coop = ctx.findCoop(op.getCoopId());
    if (coop == null) {
      throw new OperationRejected(ErrorCodes.NOT_FOUND, "Coop not found", null);
    }
    if (!ctx.canAccess(coop)) {
      throw OperationRejected.forbidden("You are not assigned to this coop");
    }
    if (op.getBaseVersion() != null) {
      return conflict(op, null, coop.getId());
    }
    SyncTracked record = newChild(type, op.getEntityId());
    populateChild(ctx, op, coop, record, true);
    children(coop, type).add(record);
    ctx.touched.add(key);
    ctx.mutated = true;
    return Outcome.applied(base(op), record, coop.getId());
  }

  private Outcome applyReminder(PushContext ctx, SyncOperation op) {
    requireOperation(op, SyncOperationType.ACTION);
    requireValidId(op.getCoopId(), "coopId");
    Coop coop = ctx.findCoop(op.getCoopId());
    if (coop == null) {
      throw new OperationRejected(ErrorCodes.NOT_FOUND, "Coop not found", null);
    }
    if (!ctx.canAccess(coop)) {
      throw OperationRejected.forbidden("You are not assigned to this coop");
    }
    ReminderActionPayload payload = payload(op, ReminderActionPayload.class);
    Reminder reminder = coop.getReminder();
    String id = op.getEntityId();
    String userId = ctx.user.getId();
    boolean found = false;
    if (reminder != null) {
      switch (payload.getReminderType().toUpperCase()) {
        case "FEED" ->
            found =
                markDone(
                    reminder.getFeeds(),
                    Feed::getId,
                    f -> {
                      f.setAction(payload.getAction());
                      f.setActionComment(payload.getActionComment());
                      f.setDone(true);
                      f.setUpdatedByUserId(userId);
                    },
                    id);
        case "VACCINE" ->
            found =
                markDone(
                    reminder.getVaccines(),
                    Vaccine::getId,
                    v -> {
                      v.setAction(payload.getAction());
                      v.setActionComment(payload.getActionComment());
                      v.setDone(true);
                      v.setUpdatedByUserId(userId);
                    },
                    id);
        default ->
            found =
                markDone(
                    reminder.getMedicines(),
                    Medicine::getId,
                    m -> {
                      m.setAction(payload.getAction());
                      m.setActionComment(payload.getActionComment());
                      m.setDone(true);
                      m.setUpdatedByUserId(userId);
                    },
                    id);
      }
    }
    if (!found) {
      throw new OperationRejected(ErrorCodes.NOT_FOUND, "Reminder not found", null);
    }
    ctx.touched.add(SyncEntityType.COOP + ":" + coop.getId());
    ctx.mutated = true;
    return Outcome.applied(base(op), coop, null);
  }

  private static <T> boolean markDone(
      List<T> items, Function<T, String> idOf, Consumer<T> update, String id) {
    if (items == null) {
      return false;
    }
    for (T item : items) {
      if (id.equals(idOf.apply(item))) {
        update.accept(item);
        return true;
      }
    }
    return false;
  }

  private void populateChild(
      PushContext ctx, SyncOperation op, Coop coop, SyncTracked record, boolean isNew) {
    switch (op.getEntityType()) {
      case SALE -> {
        SalePayload p = payload(op, SalePayload.class);
        double total;
        EggSalePackaging packaging = null;
        if (coop.getCoopType() == CoopType.LAYERS) {
          if (p.getEggPackaging() != null) {
            try {
              packaging = EggSalePackaging.fromCode(p.getEggPackaging());
            } catch (IllegalArgumentException e) {
              throw OperationRejected.validation(e.getMessage());
            }
            if (p.getQuantitySold() == null || p.getPricePerUnit() == null) {
              throw OperationRejected.validation(
                  "quantitySold and pricePerUnit are required for egg sales");
            }
            total = p.getQuantitySold() * p.getPricePerUnit();
          } else {
            if (p.getNumberOfDozensSold() == null || p.getSalePricePerDozen() == null) {
              throw OperationRejected.validation(
                  "eggPackaging, quantitySold and pricePerUnit are required for layer coops");
            }
            total = p.getNumberOfDozensSold() * p.getSalePricePerDozen();
          }
        } else {
          if (p.getNumberOfChickensSold() == null || p.getSalePricePerChicken() == null) {
            throw OperationRejected.validation(
                "numberOfChickensSold and salePricePerChicken are required for broiler coops");
          }
          total = p.getNumberOfChickensSold() * p.getSalePricePerChicken();
        }
        Sale sale = (Sale) record;
        sale.setNumberOfDozensSold(p.getNumberOfDozensSold());
        sale.setSalePricePerDozen(p.getSalePricePerDozen());
        sale.setEggSize(p.getEggSize());
        sale.setEggPackaging(packaging == null ? null : packaging.name());
        sale.setQuantitySold(p.getQuantitySold());
        sale.setPricePerUnit(p.getPricePerUnit());
        sale.setTotalEggsSold(
            packaging == null ? null : p.getQuantitySold() * packaging.getEggsPerUnit());
        sale.setNumberOfChickensSold(p.getNumberOfChickensSold());
        sale.setSalePricePerChicken(p.getSalePricePerChicken());
        sale.setAdditionalInfo(p.getAdditionalInfo());
        sale.setRecordedBy(p.getRecordedBy());
        sale.setPaymentStatus(p.getPaymentStatus());
        sale.setTotalSaleAmount(total);
        sale.setSaleDate(p.getSaleDate());
        if (isNew) {
          sale.setCreatedDate(new Date());
        }
      }
      case MORTALITY -> {
        MortalityPayload p = payload(op, MortalityPayload.class);
        Mortality mortality = (Mortality) record;
        mortality.setDateOccurred(p.getDateOccurred());
        mortality.setNumberOfDeaths(p.getNumberOfDeaths());
        mortality.setReason(p.getReason());
        mortality.setRecordedBy(p.getRecordedBy());
        if (isNew) {
          mortality.setCreatedDate(new Date());
        }
      }
      case EXPENSE -> {
        ExpensePayload p = payload(op, ExpensePayload.class);
        Expense expense = (Expense) record;
        expense.setExpenseDate(p.getExpenseDate());
        expense.setExpenseType(p.getExpenseType());
        expense.setAmount(p.getAmount());
        expense.setAdditionalInfo(p.getAdditionalInfo());
        expense.setRecordedBy(p.getRecordedBy());
        if (isNew) {
          expense.setCreatedDate(new Date());
        }
      }
      case EGG_PACKAGING -> {
        if (coop.getCoopType() != CoopType.LAYERS) {
          throw new OperationRejected(
              ErrorCodes.BAD_REQUEST, "Packaging only allowed for layer coops", null);
        }
        EggPackagingPayload p = payload(op, EggPackagingPayload.class);
        int eggsPerBox;
        try {
          eggsPerBox = EggBoxSizes.eggsPerBox(p.getBoxSize());
        } catch (IllegalArgumentException e) {
          throw OperationRejected.validation(e.getMessage());
        }
        EggPackagingRecord packaging = (EggPackagingRecord) record;
        packaging.setEggSize(p.getEggSize());
        packaging.setBoxSize(p.getBoxSize());
        packaging.setNumberOfBoxes(p.getNumberOfBoxes());
        packaging.setTotalEggs(eggsPerBox * p.getNumberOfBoxes());
        packaging.setAdditionalInfo(p.getAdditionalInfo());
        if (isNew) {
          packaging.setUserId(ctx.user.getId());
          packaging.setCreatedDate(p.getCreatedDate() != null ? p.getCreatedDate() : new Date());
        } else if (p.getCreatedDate() != null) {
          packaging.setCreatedDate(p.getCreatedDate());
        }
      }
      default -> throw unsupported();
    }
  }

  private static SyncTracked newChild(SyncEntityType type, String id) {
    return switch (type) {
      case SALE -> Sale.builder().id(id).build();
      case MORTALITY -> Mortality.builder().id(id).build();
      case EXPENSE -> Expense.builder().id(id).build();
      case EGG_PACKAGING -> EggPackagingRecord.builder().id(id).build();
      default -> throw unsupported();
    };
  }

  /** Returns the coop's mutable child list for the type, replacing null or immutable lists. */
  @SuppressWarnings("unchecked")
  static List<SyncTracked> children(Coop coop, SyncEntityType type) {
    switch (type) {
      case SALE -> {
        if (!(coop.getSales() instanceof ArrayList)) {
          coop.setSales(copy(coop.getSales()));
        }
        return (List<SyncTracked>) (List<?>) coop.getSales();
      }
      case MORTALITY -> {
        if (!(coop.getMortalities() instanceof ArrayList)) {
          coop.setMortalities(copy(coop.getMortalities()));
        }
        return (List<SyncTracked>) (List<?>) coop.getMortalities();
      }
      case EXPENSE -> {
        if (!(coop.getExpenses() instanceof ArrayList)) {
          coop.setExpenses(copy(coop.getExpenses()));
        }
        return (List<SyncTracked>) (List<?>) coop.getExpenses();
      }
      case EGG_PACKAGING -> {
        if (!(coop.getEggPackagingRecords() instanceof ArrayList)) {
          coop.setEggPackagingRecords(copy(coop.getEggPackagingRecords()));
        }
        return (List<SyncTracked>) (List<?>) coop.getEggPackagingRecords();
      }
      default -> throw unsupported();
    }
  }

  private static <T> ArrayList<T> copy(List<T> list) {
    return list == null ? new ArrayList<>() : new ArrayList<>(list);
  }

  private static boolean isStale(
      PushContext ctx, String key, SyncTracked record, SyncOperation op) {
    // Records already changed earlier in the same batch carry their pre-batch version, and the
    // client cannot know the new one yet, so later operations in the batch are not version-checked.
    if (ctx.touched.contains(key)) {
      return false;
    }
    return !Objects.equals(op.getBaseVersion(), nz(record.getVersion()));
  }

  private Outcome conflict(SyncOperation op, SyncTracked current, String coopId) {
    return Outcome.done(
        base(op)
            .status(SyncOperationStatus.CONFLICT)
            .errorCode(ErrorCodes.CONFLICT)
            .message(
                current == null
                    ? "Record no longer exists on the server"
                    : "Record was changed on the server")
            .coopId(coopId)
            .version(current == null ? null : nz(current.getVersion()))
            .serverRecord(current == null ? null : toNode(current, coopId))
            .build());
  }

  private <T> T payload(SyncOperation op, Class<T> type) {
    if (op.getPayload() == null || op.getPayload().isNull()) {
      throw OperationRejected.validation("payload is required");
    }
    T value;
    try {
      value = objectMapper.treeToValue(op.getPayload(), type);
    } catch (JsonProcessingException | IllegalArgumentException e) {
      throw OperationRejected.validation("payload is malformed");
    }
    Set<ConstraintViolation<T>> violations = validator.validate(value);
    if (!violations.isEmpty()) {
      List<String> errors =
          violations.stream()
              .map(v -> v.getPropertyPath() + ": " + v.getMessage())
              .sorted()
              .toList();
      throw new OperationRejected(ErrorCodes.VALIDATION_ERROR, "Validation failed", errors);
    }
    return value;
  }

  private static void requireValidId(String id, String field) {
    if (id == null || !ID_PATTERN.matcher(id).matches()) {
      throw OperationRejected.validation(
          field + " must be 1-64 characters: letters, digits, '-' or '_'");
    }
  }

  private static void requireOperation(SyncOperation op, SyncOperationType expected) {
    if (op.getOperation() != expected) {
      throw unsupported();
    }
  }

  private static OperationRejected unsupported() {
    return new OperationRejected(
        ErrorCodes.UNSUPPORTED_OPERATION, "Operation not supported for this entity type", null);
  }

  private static SyncOperationResult.SyncOperationResultBuilder base(SyncOperation op) {
    return SyncOperationResult.builder()
        .opId(op.getOpId())
        .entityType(op.getEntityType())
        .entityId(op.getEntityId())
        .coopId(op.getCoopId());
  }

  // ---------------------------------------------------------------------------------------------
  // Changes / bootstrap
  // ---------------------------------------------------------------------------------------------

  public SyncChangesResponse changes(UserDetailsImpl user, Long since, Integer limit) {
    int pageSize = limit == null ? DEFAULT_PAGE_SIZE : Math.max(1, Math.min(limit, MAX_PAGE_SIZE));
    return changes(user, loadFarm(requireFarmId(user)), since == null ? -1L : since, pageSize);
  }

  public SyncBootstrapResponse bootstrap(UserDetailsImpl user) {
    String farmId = requireFarmId(user);
    Farm farm = loadFarm(farmId);
    List<Coop> coops = farm.getCoops() == null ? List.of() : farm.getCoops();
    List<User> users = userRepository.findByFarmId(farmId);

    List<UserInfoResponse> team =
        users.stream()
            .filter(u -> !u.isRemoved())
            .map(u -> UserInfoMapper.toResponse(u, coops))
            .sorted(Comparator.comparing(u -> String.valueOf(u.getName())))
            .toList();
    UserInfoResponse me =
        users.stream()
            .filter(u -> u.getId().equals(user.getId()))
            .findFirst()
            .map(u -> UserInfoMapper.toResponse(u, coops))
            .orElse(null);
    UserSettingsResponse settings =
        userSettingsRepository
            .findByUserIdAndFarmId(user.getId(), farmId)
            .map(
                s ->
                    new UserSettingsResponse(
                        s.getId(),
                        s.getUserId(),
                        s.getFarmId(),
                        s.getCurrency(),
                        s.getAutoCreateReminders(),
                        s.getSalesAlerts(),
                        s.getMortalityAlerts(),
                        s.getExpenseAlerts(),
                        s.getDailyReminders()))
            .orElse(null);

    return SyncBootstrapResponse.builder()
        .user(me)
        .snapshot(changes(user, farm, -1L, Integer.MAX_VALUE))
        .team(team)
        .settings(settings)
        .build();
  }

  private SyncChangesResponse changes(UserDetailsImpl user, Farm farm, long since, int limit) {
    long farmVersion = nz(farm.getVersion());
    boolean prunedPastCursor =
        since >= 0
            && farm.getTombstonesPrunedBefore() != null
            && since < farm.getTombstonesPrunedBefore();
    if (since > farmVersion || prunedPastCursor) {
      return SyncChangesResponse.builder().cursor(farmVersion).resetRequired(true).build();
    }

    PushContext access = new PushContext(user, farm);
    List<Coop> allCoops = farm.getCoops() == null ? List.of() : farm.getCoops();
    List<Coop> visible = allCoops.stream().filter(access::canAccess).toList();
    List<Change> changes = new ArrayList<>();

    for (Coop coop : farmService.builCoopList(new ArrayList<>(visible))) {
      long coopVersion = nz(coop.getVersion());
      boolean coopChanged = coopVersion > since;
      if (coopChanged) {
        Map<String, Object> node = toNode(coop, null);
        changes.add(new Change(coopVersion, r -> r.getCoops().add(node)));
      }
      for (SyncEntityType type :
          List.of(
              SyncEntityType.SALE,
              SyncEntityType.MORTALITY,
              SyncEntityType.EXPENSE,
              SyncEntityType.EGG_PACKAGING)) {
        for (SyncTracked child : children(coop, type)) {
          long childVersion = nz(child.getVersion());
          if (coopChanged || childVersion > since) {
            long effective = coopChanged ? Math.max(childVersion, coopVersion) : childVersion;
            Map<String, Object> node = toNode(child, coop.getId());
            changes.add(new Change(effective, r -> bucket(r, type).add(node)));
          }
        }
      }
    }

    for (Coop coop : allCoops) {
      long coopVersion = nz(coop.getVersion());
      if (!access.canAccess(coop) && coopVersion > since) {
        // Coop exists but is not visible to this user (e.g. unassigned): tell the client to drop it.
        SyncTombstone hidden =
            SyncTombstone.builder()
                .entityType(SyncEntityType.COOP)
                .entityId(coop.getId())
                .version(coopVersion)
                .deletedAt(coop.getUpdatedAt())
                .build();
        changes.add(new Change(coopVersion, r -> r.getTombstones().add(hidden)));
      }
    }

    if (farm.getTombstones() != null) {
      for (SyncTombstone tombstone : farm.getTombstones()) {
        if (nz(tombstone.getVersion()) > since) {
          changes.add(new Change(nz(tombstone.getVersion()), r -> r.getTombstones().add(tombstone)));
        }
      }
    }

    if (nz(farm.getDetailsVersion()) > since) {
      FarmSnapshot snapshot = farmSnapshot(farm);
      changes.add(new Change(nz(farm.getDetailsVersion()), r -> r.setFarm(snapshot)));
    }

    changes.sort(Comparator.comparingLong(Change::version));
    SyncChangesResponse response = SyncChangesResponse.builder().cursor(farmVersion).build();
    int count = 0;
    int i = 0;
    while (i < changes.size()) {
      long groupVersion = changes.get(i).version();
      if (count >= limit) {
        response.setHasMore(true);
        response.setCursor(changes.get(i - 1).version());
        break;
      }
      // Never split a version group across pages, otherwise the cursor would skip records.
      while (i < changes.size() && changes.get(i).version() == groupVersion) {
        changes.get(i).apply().accept(response);
        count++;
        i++;
      }
    }
    return response;
  }

  private static List<Map<String, Object>> bucket(SyncChangesResponse r, SyncEntityType type) {
    return switch (type) {
      case SALE -> r.getSales();
      case MORTALITY -> r.getMortalities();
      case EXPENSE -> r.getExpenses();
      case EGG_PACKAGING -> r.getEggPackagingRecords();
      default -> throw new IllegalArgumentException("Not a coop child type: " + type);
    };
  }

  Map<String, Object> toNode(SyncTracked record, String coopId) {
    Map<String, Object> node = new LinkedHashMap<>(objectMapper.convertValue(record, MAP_TYPE));
    if (record instanceof Coop) {
      COOP_CHILD_FIELDS.forEach(node::remove);
    } else {
      node.put("coopId", coopId);
    }
    node.put("version", nz(record.getVersion()));
    return node;
  }

  static FarmSnapshot farmSnapshot(Farm farm) {
    return FarmSnapshot.builder()
        .id(farm.getId())
        .farmName(farm.getFarmName())
        .address(farm.getAddress())
        .createdDate(farm.getCreatedDate())
        .updatedAt(farm.getUpdatedAt())
        .version(nz(farm.getDetailsVersion()))
        .build();
  }

  // ---------------------------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------------------------

  private static String requireFarmId(UserDetailsImpl user) {
    if (user == null) {
      throw ApiException.unauthorized("Authentication required");
    }
    if (user.getFarmId() == null || user.getFarmId().isBlank()) {
      throw ApiException.forbidden("User is not linked to a farm");
    }
    return user.getFarmId();
  }

  private Farm loadFarm(String farmId) {
    return farmRepository
        .findById(farmId)
        .orElseThrow(() -> ApiException.notFound("Farm not found"));
  }

  static long nz(Long value) {
    return value == null ? 0L : value;
  }

  private record Change(long version, Consumer<SyncChangesResponse> apply) {}

  record ChildRef(Coop coop, SyncTracked record) {}

  /** Per-request view of the farm and the caller's permissions. */
  static final class PushContext {
    final UserDetailsImpl user;
    final Farm farm;
    final boolean canManageFarm;
    final Set<String> touched = new HashSet<>();
    final List<CoopArchive> archives = new ArrayList<>();
    boolean mutated;

    PushContext(UserDetailsImpl user, Farm farm) {
      this.user = user;
      this.farm = farm;
      Set<String> roles = new HashSet<>();
      if (user.getAuthorities() != null) {
        user.getAuthorities().forEach(a -> roles.add(a.getAuthority()));
      }
      this.canManageFarm =
          user.isFarmOwner()
              || roles.contains(ERole.ROLE_FARM_MANAGER.name())
              || roles.contains(ERole.ROLE_ADMIN.name());
    }

    /** Same visibility rule as the legacy API: owners see all coops, others assigned ones. */
    boolean canAccess(Coop coop) {
      return user.isFarmOwner()
          || (coop.getResponsibleUserIds() != null
              && coop.getResponsibleUserIds().contains(user.getId()));
    }

    List<Coop> coops() {
      if (!(farm.getCoops() instanceof ArrayList)) {
        farm.setCoops(copy(farm.getCoops()));
      }
      return farm.getCoops();
    }

    Coop findCoop(String id) {
      if (id == null) {
        return null;
      }
      return coops().stream().filter(c -> id.equals(c.getId())).findFirst().orElse(null);
    }

    ChildRef findChild(SyncEntityType type, String id) {
      for (Coop coop : coops()) {
        for (SyncTracked record : children(coop, type)) {
          if (id.equals(record.getId())) {
            return new ChildRef(coop, record);
          }
        }
      }
      return null;
    }
  }

  /** Result of applying one operation; version and server record are resolved after saving. */
  private static final class Outcome {
    private final SyncOperationResult.SyncOperationResultBuilder builder;
    private final SyncOperationResult fixed;
    private final Outcome duplicateOf;
    private final SyncTracked record;
    private final String coopId;
    private final boolean deleted;
    private final boolean farmDetails;
    private SyncOperationResult finished;

    private Outcome(
        SyncOperationResult.SyncOperationResultBuilder builder,
        SyncOperationResult fixed,
        Outcome duplicateOf,
        SyncTracked record,
        String coopId,
        boolean deleted,
        boolean farmDetails) {
      this.builder = builder;
      this.fixed = fixed;
      this.duplicateOf = duplicateOf;
      this.record = record;
      this.coopId = coopId;
      this.deleted = deleted;
      this.farmDetails = farmDetails;
    }

    static Outcome done(SyncOperationResult result) {
      return new Outcome(null, result, null, null, null, false, false);
    }

    static Outcome duplicateOf(SyncOperationResult result) {
      return done(result);
    }

    static Outcome duplicateOf(Outcome first) {
      return new Outcome(null, null, first, null, null, false, false);
    }

    static Outcome applied(
        SyncOperationResult.SyncOperationResultBuilder builder, SyncTracked record, String coopId) {
      return new Outcome(builder, null, null, record, coopId, false, false);
    }

    static Outcome deleted(SyncOperationResult.SyncOperationResultBuilder builder) {
      return new Outcome(builder, null, null, null, null, true, false);
    }

    static Outcome appliedFarm(SyncOperationResult.SyncOperationResultBuilder builder) {
      return new Outcome(builder, null, null, null, null, false, true);
    }

    SyncOperationResult finish(SyncService service, Farm farm) {
      if (finished != null) {
        return finished;
      }
      if (duplicateOf != null) {
        finished = duplicateOf.finish(service, farm).toBuilder().duplicate(true).build();
      } else if (fixed != null) {
        finished = fixed;
      } else {
        builder.status(SyncOperationStatus.APPLIED);
        if (deleted) {
          builder.version(nz(farm.getVersion()));
        } else if (farmDetails) {
          builder.version(nz(farm.getDetailsVersion())).serverRecord(farmSnapshot(farm));
        } else {
          builder
              .coopId(coopId)
              .version(nz(record.getVersion()))
              .serverRecord(service.toNode(record, coopId));
        }
        finished = builder.build();
      }
      return finished;
    }
  }

  /** Expected per-operation failure; reported in the result rather than failing the batch. */
  private static final class OperationRejected extends RuntimeException {
    private final String code;
    private final List<String> errors;

    OperationRejected(String code, String message, List<String> errors) {
      super(message, null, false, false);
      this.code = code;
      this.errors = errors;
    }

    static OperationRejected forbidden(String message) {
      return new OperationRejected(ErrorCodes.FORBIDDEN, message, null);
    }

    static OperationRejected validation(String message) {
      return new OperationRejected(ErrorCodes.VALIDATION_ERROR, message, null);
    }
  }
}
