package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.BatchStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.CycleStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.HatcherCycle;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.IncubationBatch;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionEquipment;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionSettings;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.BatchCommandRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.HatcherCycleRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.IncubationBatchRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.HatcherCycleResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.IncubationBatchResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.HatcherCycleRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.IncubationBatchRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionEquipmentRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

/**
 * Incubation batches and hatcher cycles. Every mutation runs under a per-farm lock so capacity
 * checks and writes are atomic within this instance; documents also carry optimistic versions.
 */
@Service
@RequiredArgsConstructor
public class IncubationService {
  private static final int DEFAULT_HATCHER_OCCUPANCY_DAYS = 3;
  private static final Set<BatchStatus> INCUBATOR_STATUSES =
      EnumSet.of(BatchStatus.PLANNED, BatchStatus.INCUBATING, BatchStatus.TRANSFERRED);
  private static final Set<CycleStatus> HATCHER_STATUSES =
      EnumSet.of(CycleStatus.RESERVED, CycleStatus.IN_HATCHER);

  private final ProductionAccessService accessService;
  private final ProductionSettingsService settingsService;
  private final ProductionEquipmentRepository equipmentRepository;
  private final IncubationBatchRepository batchRepository;
  private final HatcherCycleRepository cycleRepository;
  private final ProductionReminderService reminderService;
  private final Map<String, Object> farmLocks = new ConcurrentHashMap<>();

  public List<IncubationBatchResponse> list(
      UserDetailsImpl actor, BatchStatus status, int page, int size) {
    String farmId = accessService.requireManage(actor);
    PageRequest paging = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100));
    List<IncubationBatch> batches =
        status == null
            ? batchRepository.findByFarmIdOrderByPlannedStartDateDesc(farmId, paging)
            : batchRepository.findByFarmIdAndStatusOrderByPlannedStartDateDesc(
                farmId, status, paging);
    Map<String, List<HatcherCycle>> cycles =
        cycleRepository
            .findByFarmIdAndIncubationBatchIdIn(
                farmId, batches.stream().map(IncubationBatch::getId).toList())
            .stream()
            .collect(Collectors.groupingBy(HatcherCycle::getIncubationBatchId));
    return batches.stream().map(b -> toResponse(b, cycles.getOrDefault(b.getId(), List.of()))).toList();
  }

  public IncubationBatchResponse get(UserDetailsImpl actor, String id) {
    String farmId = accessService.requireManage(actor);
    return view(requireBatch(farmId, id));
  }

  public IncubationBatchResponse create(UserDetailsImpl actor, IncubationBatchRequest request) {
    String farmId = accessService.requireManage(actor);
    ProductionSettings settings = settingsService.ensureInitialised(farmId, actor.getId());
    synchronized (lock(farmId)) {
      ProductionEquipment incubator = requireEquipment(farmId, request.getEquipmentId(), EquipmentType.INCUBATOR);
      Instant now = Instant.now();
      IncubationBatch batch =
          IncubationBatch.builder()
              .farmId(farmId)
              .equipmentId(incubator.getId())
              .eggsSet(request.getEggsSet())
              .status(BatchStatus.PLANNED)
              .eggSource(blankToNull(request.getEggSource()))
              .notes(blankToNull(request.getNotes()))
              .incubationDaysSnapshot(settings.getIncubationDays())
              .transferDaySnapshot(settings.getTransferDay())
              .expectedHatchRateSnapshot(settings.getExpectedHatchRate())
              .createdAt(now)
              .updatedAt(now)
              .createdBy(actor.getId())
              .updatedBy(actor.getId())
              .build();
      schedule(batch, request.getPlannedStartDate());
      batch.setReference(resolveReference(farmId, request.getReference(), request.getPlannedStartDate()));
      checkIncubator(incubator, batch);
      return view(reconciled(saveBatch(batch)));
    }
  }

  public IncubationBatchResponse update(
      UserDetailsImpl actor, String id, IncubationBatchRequest request) {
    String farmId = accessService.requireManage(actor);
    if (request.getVersion() == null) throw ApiException.badRequest("Version is required");
    synchronized (lock(farmId)) {
      IncubationBatch batch = requireBatch(farmId, id);
      requireStatus(batch, BatchStatus.PLANNED);
      List<HatcherCycle> cycles = activeCycles(farmId, batch.getId());
      int reserved = cycles.stream().mapToInt(HatcherCycle::getQuantity).sum();
      if (request.getEggsSet() < reserved) {
        throw ApiException.badRequest(
            "Eggs set cannot be below the " + reserved + " eggs already reserved for hatcher cycles");
      }
      if (request.getReference() != null
          && !request.getReference().isBlank()
          && !request.getReference().trim().equalsIgnoreCase(batch.getReference())) {
        batch.setReference(resolveReference(farmId, request.getReference(), request.getPlannedStartDate()));
      }
      ProductionEquipment incubator = requireEquipment(farmId, request.getEquipmentId(), EquipmentType.INCUBATOR);
      batch.setEquipmentId(incubator.getId());
      batch.setEggsSet(request.getEggsSet());
      batch.setEggSource(blankToNull(request.getEggSource()));
      batch.setNotes(blankToNull(request.getNotes()));
      batch.setVersion(request.getVersion());
      return view(
          reconciled(rescheduleAndSave(actor, batch, cycles, incubator, request.getPlannedStartDate())));
    }
  }

  public IncubationBatchResponse start(UserDetailsImpl actor, String id, BatchCommandRequest cmd) {
    String farmId = accessService.requireManage(actor);
    synchronized (lock(farmId)) {
      IncubationBatch batch = requireBatch(farmId, id);
      requireStatus(batch, BatchStatus.PLANNED);
      LocalDate start =
          cmd != null && cmd.getActualDate() != null ? cmd.getActualDate() : batch.getPlannedStartDate();
      ProductionEquipment incubator = requireEquipment(farmId, batch.getEquipmentId(), EquipmentType.INCUBATOR);
      batch.setStatus(BatchStatus.INCUBATING);
      batch.setActualStartDate(start);
      return view(
          reconciled(rescheduleAndSave(actor, batch, activeCycles(farmId, id), incubator, start)));
    }
  }

  public IncubationBatchResponse cancel(UserDetailsImpl actor, String id, BatchCommandRequest cmd) {
    String farmId = accessService.requireManage(actor);
    synchronized (lock(farmId)) {
      IncubationBatch batch = requireBatch(farmId, id);
      if (batch.getStatus() != BatchStatus.PLANNED && batch.getStatus() != BatchStatus.INCUBATING) {
        throw ApiException.conflict("Only planned or incubating batches can be cancelled");
      }
      List<HatcherCycle> cycles = activeCycles(farmId, id);
      if (cycles.stream().anyMatch(c -> c.getStatus() != CycleStatus.RESERVED)) {
        throw ApiException.conflict("Eggs have already been transferred to a hatcher");
      }
      Instant now = Instant.now();
      for (HatcherCycle cycle : cycles) {
        cycle.setStatus(CycleStatus.CANCELLED);
        touch(cycle, actor, now);
      }
      cycleRepository.saveAll(cycles);
      batch.setStatus(BatchStatus.CANCELLED);
      batch.setCancelReason(cmd == null ? null : blankToNull(cmd.getReason()));
      touch(batch, actor, now);
      return view(reconciled(saveBatch(batch)));
    }
  }

  public List<HatcherCycleResponse> cycles(UserDetailsImpl actor, String batchId) {
    String farmId = accessService.requireManage(actor);
    requireBatch(farmId, batchId);
    return cycleRepository.findByFarmIdAndIncubationBatchIdIn(farmId, List.of(batchId)).stream()
        .sorted(Comparator.comparing(HatcherCycle::getReference))
        .map(this::toResponse)
        .toList();
  }

  public IncubationBatchResponse reserveCycle(
      UserDetailsImpl actor, String batchId, HatcherCycleRequest request) {
    String farmId = accessService.requireManage(actor);
    synchronized (lock(farmId)) {
      IncubationBatch batch = requireBatch(farmId, batchId);
      if (batch.getStatus() != BatchStatus.PLANNED && batch.getStatus() != BatchStatus.INCUBATING) {
        throw ApiException.conflict("Hatcher cycles can only be added to planned or incubating batches");
      }
      List<HatcherCycle> existing = activeCycles(farmId, batchId);
      int reserved = existing.stream().mapToInt(HatcherCycle::getQuantity).sum();
      int unassigned = batch.getEggsSet() - reserved;
      if (request.getQuantity() > unassigned) {
        throw ApiException.badRequest(
            "Only " + unassigned + " eggs of this batch are not yet assigned to a hatcher cycle");
      }
      ProductionEquipment hatcher = requireEquipment(farmId, request.getHatcherId(), EquipmentType.HATCHER);
      int occupancy =
          hatcher.getHatcherOccupancyDays() == null
              ? DEFAULT_HATCHER_OCCUPANCY_DAYS
              : hatcher.getHatcherOccupancyDays();
      Instant now = Instant.now();
      HatcherCycle cycle =
          HatcherCycle.builder()
              .farmId(farmId)
              .incubationBatchId(batchId)
              .hatcherId(hatcher.getId())
              .reference(
                  batch.getReference()
                      + "-H"
                      + (cycleRepository.countByFarmIdAndIncubationBatchId(farmId, batchId) + 1))
              .quantity(request.getQuantity())
              .plannedTransferDate(batch.getPlannedTransferDate())
              .expectedHatchDate(batch.getPlannedHatchDate())
              .occupancyDays(occupancy)
              .status(CycleStatus.RESERVED)
              .notes(blankToNull(request.getNotes()))
              .createdAt(now)
              .updatedAt(now)
              .createdBy(actor.getId())
              .updatedBy(actor.getId())
              .build();
      checkHatcher(hatcher, Set.of(), List.of(hatcherInterval(cycle)));
      cycleRepository.save(cycle);
      return view(batch);
    }
  }

  public IncubationBatchResponse transferCycle(
      UserDetailsImpl actor, String cycleId, BatchCommandRequest cmd) {
    String farmId = accessService.requireManage(actor);
    synchronized (lock(farmId)) {
      HatcherCycle cycle = requireCycle(farmId, cycleId);
      IncubationBatch batch = requireBatch(farmId, cycle.getIncubationBatchId());
      requireStatus(batch, BatchStatus.INCUBATING);
      if (cycle.getStatus() != CycleStatus.RESERVED) {
        throw ApiException.conflict("This hatcher cycle has already been transferred or cancelled");
      }
      LocalDate date =
          cmd != null && cmd.getActualDate() != null ? cmd.getActualDate() : cycle.getPlannedTransferDate();
      if (date.isBefore(batch.getActualStartDate())) {
        throw ApiException.badRequest("Transfer cannot be before the batch start date");
      }
      cycle.setActualTransferDate(date);
      cycle.setStatus(CycleStatus.IN_HATCHER);
      ProductionEquipment hatcher = requireEquipment(farmId, cycle.getHatcherId(), EquipmentType.HATCHER);
      checkHatcher(hatcher, Set.of(cycle.getId()), List.of(hatcherInterval(cycle)));
      touch(cycle, actor, Instant.now());
      cycleRepository.save(cycle);
      List<HatcherCycle> all = activeCycles(farmId, batch.getId());
      boolean fullyReserved = all.stream().mapToInt(HatcherCycle::getQuantity).sum() == batch.getEggsSet();
      if (fullyReserved && all.stream().allMatch(c -> c.getStatus() == CycleStatus.IN_HATCHER)) {
        batch.setStatus(BatchStatus.TRANSFERRED);
        touch(batch, actor, Instant.now());
        saveBatch(batch);
      }
      return view(batch);
    }
  }

  public IncubationBatchResponse cancelCycle(UserDetailsImpl actor, String cycleId) {
    String farmId = accessService.requireManage(actor);
    synchronized (lock(farmId)) {
      HatcherCycle cycle = requireCycle(farmId, cycleId);
      if (cycle.getStatus() != CycleStatus.RESERVED) {
        throw ApiException.conflict("Only reserved hatcher cycles can be cancelled");
      }
      cycle.setStatus(CycleStatus.CANCELLED);
      touch(cycle, actor, Instant.now());
      cycleRepository.save(cycle);
      return view(requireBatch(farmId, cycle.getIncubationBatchId()));
    }
  }

  List<ProductionCapacity.Interval> incubatorIntervals(
      String farmId, String equipmentId, String excludeBatchId) {
    return batchRepository.findByFarmIdAndEquipmentIdAndStatusIn(farmId, equipmentId, INCUBATOR_STATUSES).stream()
        .filter(b -> !b.getId().equals(excludeBatchId))
        .map(this::incubatorInterval)
        .toList();
  }

  List<ProductionCapacity.Interval> hatcherIntervals(
      String farmId, String hatcherId, Collection<String> excludeCycleIds) {
    return cycleRepository.findByFarmIdAndHatcherIdAndStatusIn(farmId, hatcherId, HATCHER_STATUSES).stream()
        .filter(c -> !excludeCycleIds.contains(c.getId()))
        .map(this::hatcherInterval)
        .toList();
  }

  /** Eggs leave the incubator on the transfer day, so the batch occupies [start, transfer). */
  private ProductionCapacity.Interval incubatorInterval(IncubationBatch b) {
    return new ProductionCapacity.Interval(
        b.getPlannedStartDate(), b.getPlannedTransferDate(), b.getEggsSet(), b.getReference());
  }

  private ProductionCapacity.Interval hatcherInterval(HatcherCycle c) {
    LocalDate start = c.getActualTransferDate() != null ? c.getActualTransferDate() : c.getPlannedTransferDate();
    return new ProductionCapacity.Interval(
        start, start.plusDays(c.getOccupancyDays()), c.getQuantity(), c.getReference());
  }

  private void checkIncubator(ProductionEquipment incubator, IncubationBatch candidate) {
    check(
        incubator,
        incubatorIntervals(candidate.getFarmId(), incubator.getId(), candidate.getId()),
        List.of(incubatorInterval(candidate)));
  }

  private void checkHatcher(
      ProductionEquipment hatcher, Collection<String> excludeCycleIds, List<ProductionCapacity.Interval> candidates) {
    check(hatcher, hatcherIntervals(hatcher.getFarmId(), hatcher.getId(), excludeCycleIds), candidates);
  }

  private void check(
      ProductionEquipment equipment,
      List<ProductionCapacity.Interval> existing,
      List<ProductionCapacity.Interval> candidates) {
    List<ProductionCapacity.Interval> all = new ArrayList<>(existing);
    all.addAll(candidates);
    int peak = ProductionCapacity.peak(all);
    if (peak <= equipment.getCapacity()) return;
    List<String> conflicts =
        existing.stream()
            .filter(e -> candidates.stream().anyMatch(e::overlaps))
            .map(ProductionCapacity.Interval::reference)
            .distinct()
            .toList();
    ProductionCapacity.Interval first = candidates.get(0);
    Map<String, Object> details = new LinkedHashMap<>();
    details.put("resource", equipment.getId());
    details.put("requested", peak);
    details.put("available", equipment.getCapacity());
    details.put("intervalStart", first.start().toString());
    details.put("intervalEnd", first.end().toString());
    details.put("conflictingReferences", conflicts);
    throw ApiException.capacityConflict(
        equipment.getName() + " would hold " + peak + " eggs but its capacity is " + equipment.getCapacity(),
        details);
  }

  /** Moves the batch and its reserved cycles to a new start date after re-checking both capacities. */
  private IncubationBatch rescheduleAndSave(
      UserDetailsImpl actor,
      IncubationBatch batch,
      List<HatcherCycle> cycles,
      ProductionEquipment incubator,
      LocalDate start) {
    schedule(batch, start);
    checkIncubator(incubator, batch);
    Map<String, List<HatcherCycle>> byHatcher = new HashMap<>();
    for (HatcherCycle cycle : cycles) {
      cycle.setPlannedTransferDate(batch.getPlannedTransferDate());
      cycle.setExpectedHatchDate(batch.getPlannedHatchDate());
      byHatcher.computeIfAbsent(cycle.getHatcherId(), k -> new ArrayList<>()).add(cycle);
    }
    for (Map.Entry<String, List<HatcherCycle>> entry : byHatcher.entrySet()) {
      ProductionEquipment hatcher = requireEquipment(batch.getFarmId(), entry.getKey(), EquipmentType.HATCHER);
      checkHatcher(
          hatcher,
          entry.getValue().stream().map(HatcherCycle::getId).toList(),
          entry.getValue().stream().map(this::hatcherInterval).toList());
    }
    Instant now = Instant.now();
    cycles.forEach(c -> touch(c, actor, now));
    cycleRepository.saveAll(cycles);
    touch(batch, actor, now);
    return saveBatch(batch);
  }

  private void schedule(IncubationBatch batch, LocalDate start) {
    batch.setPlannedStartDate(start);
    batch.setPlannedTransferDate(start.plusDays(batch.getTransferDaySnapshot()));
    batch.setPlannedHatchDate(start.plusDays(batch.getIncubationDaysSnapshot()));
  }

  private IncubationBatch reconciled(IncubationBatch batch) {
    reminderService.reconcile(batch);
    return batch;
  }

  private IncubationBatch saveBatch(IncubationBatch batch) {
    try {
      return batchRepository.save(batch);
    } catch (OptimisticLockingFailureException e) {
      throw ApiException.conflict("This batch was changed by someone else. Reload and try again.");
    } catch (DuplicateKeyException e) {
      throw ApiException.conflict("A batch with this reference already exists");
    }
  }

  private String resolveReference(String farmId, String requested, LocalDate start) {
    if (requested != null && !requested.isBlank()) {
      String reference = requested.trim();
      if (batchRepository.existsByFarmIdAndReferenceIgnoreCase(farmId, reference)) {
        throw ApiException.conflict("A batch with this reference already exists");
      }
      return reference;
    }
    String prefix = "IB-" + start.format(DateTimeFormatter.BASIC_ISO_DATE) + "-";
    long n = batchRepository.countByFarmId(farmId) + 1;
    while (batchRepository.existsByFarmIdAndReferenceIgnoreCase(farmId, prefix + n)) n++;
    return prefix + n;
  }

  private ProductionEquipment requireEquipment(String farmId, String id, EquipmentType type) {
    ProductionEquipment equipment =
        equipmentRepository
            .findByIdAndFarmIdAndArchivedFalse(id, farmId)
            .orElseThrow(() -> ApiException.notFound("Equipment not found"));
    if (equipment.getType() != type) {
      throw ApiException.badRequest("Equipment must be of type " + type);
    }
    if (!equipment.isEnabled()) throw ApiException.badRequest(equipment.getName() + " is disabled");
    return equipment;
  }

  private IncubationBatch requireBatch(String farmId, String id) {
    return batchRepository
        .findByIdAndFarmId(id, farmId)
        .orElseThrow(() -> ApiException.notFound("Batch not found"));
  }

  private HatcherCycle requireCycle(String farmId, String id) {
    return cycleRepository
        .findByIdAndFarmId(id, farmId)
        .orElseThrow(() -> ApiException.notFound("Hatcher cycle not found"));
  }

  private void requireStatus(IncubationBatch batch, BatchStatus expected) {
    if (batch.getStatus() != expected) {
      throw ApiException.conflict("Batch must be " + expected + " but is " + batch.getStatus());
    }
  }

  private List<HatcherCycle> activeCycles(String farmId, String batchId) {
    return cycleRepository.findByFarmIdAndIncubationBatchIdIn(farmId, List.of(batchId)).stream()
        .filter(c -> c.getStatus() != CycleStatus.CANCELLED)
        .collect(Collectors.toCollection(ArrayList::new));
  }

  private void touch(IncubationBatch batch, UserDetailsImpl actor, Instant now) {
    batch.setUpdatedAt(now);
    batch.setUpdatedBy(actor.getId());
  }

  private void touch(HatcherCycle cycle, UserDetailsImpl actor, Instant now) {
    cycle.setUpdatedAt(now);
    cycle.setUpdatedBy(actor.getId());
  }

  Object lock(String farmId) {
    return farmLocks.computeIfAbsent(farmId, k -> new Object());
  }

  private String blankToNull(String value) {
    return value == null || value.isBlank() ? null : value.trim();
  }

  private IncubationBatchResponse view(IncubationBatch batch) {
    return toResponse(
        batch,
        cycleRepository.findByFarmIdAndIncubationBatchIdIn(batch.getFarmId(), List.of(batch.getId())));
  }

  private IncubationBatchResponse toResponse(IncubationBatch b, List<HatcherCycle> cycles) {
    int reserved =
        cycles.stream()
            .filter(c -> c.getStatus() != CycleStatus.CANCELLED)
            .mapToInt(HatcherCycle::getQuantity)
            .sum();
    return IncubationBatchResponse.builder()
        .id(b.getId())
        .farmId(b.getFarmId())
        .reference(b.getReference())
        .equipmentId(b.getEquipmentId())
        .eggsSet(b.getEggsSet())
        .eggsReserved(reserved)
        .eggsUnassigned(b.getEggsSet() - reserved)
        .plannedStartDate(b.getPlannedStartDate())
        .plannedTransferDate(b.getPlannedTransferDate())
        .plannedHatchDate(b.getPlannedHatchDate())
        .actualStartDate(b.getActualStartDate())
        .status(b.getStatus())
        .eggSource(b.getEggSource())
        .notes(b.getNotes())
        .cancelReason(b.getCancelReason())
        .expectedHatchRateSnapshot(b.getExpectedHatchRateSnapshot())
        .hatcherCycles(
            cycles.stream()
                .sorted(Comparator.comparing(HatcherCycle::getReference))
                .map(this::toResponse)
                .toList())
        .updatedAt(b.getUpdatedAt())
        .version(b.getVersion())
        .build();
  }

  private HatcherCycleResponse toResponse(HatcherCycle c) {
    return HatcherCycleResponse.builder()
        .id(c.getId())
        .farmId(c.getFarmId())
        .incubationBatchId(c.getIncubationBatchId())
        .hatcherId(c.getHatcherId())
        .reference(c.getReference())
        .quantity(c.getQuantity())
        .plannedTransferDate(c.getPlannedTransferDate())
        .actualTransferDate(c.getActualTransferDate())
        .expectedHatchDate(c.getExpectedHatchDate())
        .occupancyDays(c.getOccupancyDays())
        .status(c.getStatus())
        .notes(c.getNotes())
        .updatedAt(c.getUpdatedAt())
        .version(c.getVersion())
        .build();
  }
}
