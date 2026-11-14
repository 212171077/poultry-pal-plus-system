package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.CycleStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.MovementType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlacementSource;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.BirdMovement;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.BirdPlacement;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.HatchResult;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.HatcherCycle;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionEquipment;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.BirdMovementRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.BirdPlacementRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.BirdMovementResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.BirdPlacementResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.HouseOccupancyResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.BirdMovementRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.BirdPlacementRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.HatchResultRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.HatcherCycleRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionEquipmentRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionSettingsRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;

/**
 * Chicken-house placements and the append-only movement ledger. Occupancy is always derived from
 * placements plus movements, never stored.
 */
@Service
@RequiredArgsConstructor
public class PlacementService implements EquipmentUsageChecker {
  private final ProductionAccessService accessService;
  private final IncubationService incubationService;
  private final ProductionEquipmentRepository equipmentRepository;
  private final ProductionSettingsRepository settingsRepository;
  private final HatcherCycleRepository cycleRepository;
  private final HatchResultRepository resultRepository;
  private final BirdPlacementRepository placementRepository;
  private final BirdMovementRepository movementRepository;

  public List<BirdPlacementResponse> list(UserDetailsImpl actor, String houseId, boolean activeOnly) {
    String farmId = accessService.requireManage(actor);
    List<BirdPlacement> placements =
        houseId == null || houseId.isBlank()
            ? placementRepository.findByFarmIdOrderByPlacementDateDesc(farmId)
            : placementRepository.findByFarmIdAndHouseId(farmId, houseId);
    Map<String, List<BirdMovement>> ledger = ledger(farmId, placements);
    return placements.stream()
        .sorted((a, b) -> b.getPlacementDate().compareTo(a.getPlacementDate()))
        .map(p -> toResponse(p, ledger.getOrDefault(p.getId(), List.of()), false))
        .filter(r -> !activeOnly || r.getRemaining() > 0)
        .toList();
  }

  public BirdPlacementResponse get(UserDetailsImpl actor, String id) {
    String farmId = accessService.requireManage(actor);
    BirdPlacement placement = requirePlacement(farmId, id);
    return toResponse(
        placement,
        movementRepository.findByFarmIdAndPlacementIdOrderByDateAscCreatedAtAsc(farmId, id),
        true);
  }

  public List<HouseOccupancyResponse> occupancy(UserDetailsImpl actor) {
    String farmId = accessService.requireManage(actor);
    List<ProductionEquipment> houses =
        equipmentRepository.findByFarmIdAndArchivedFalseOrderByTypeAscNameAsc(farmId).stream()
            .filter(e -> e.getType() == EquipmentType.CHICKEN_HOUSE)
            .toList();
    return houses.stream()
        .map(
            h -> {
              int occupied = occupied(farmId, h.getId());
              return HouseOccupancyResponse.builder()
                  .houseId(h.getId())
                  .name(h.getName())
                  .enabled(h.isEnabled())
                  .capacity(h.getCapacity())
                  .occupied(occupied)
                  .available(Math.max(h.getCapacity() - occupied, 0))
                  .build();
            })
        .toList();
  }

  public BirdPlacementResponse place(UserDetailsImpl actor, BirdPlacementRequest request) {
    String farmId = accessService.requireManage(actor);
    synchronized (incubationService.lock(farmId)) {
      LocalDate today = today(farmId);
      ProductionEquipment house =
          equipmentRepository
              .findByIdAndFarmIdAndArchivedFalse(request.getHouseId(), farmId)
              .orElseThrow(() -> ApiException.notFound("Chicken house not found"));
      if (house.getType() != EquipmentType.CHICKEN_HOUSE) {
        throw ApiException.badRequest("Equipment must be a chicken house");
      }
      if (!house.isEnabled()) throw ApiException.badRequest(house.getName() + " is disabled");
      if (request.getPlacementDate().isAfter(today)) {
        throw ApiException.badRequest("Placement date cannot be in the future; only actual placements are recorded");
      }
      LocalDate arrival = request.getArrivalDate() == null ? request.getPlacementDate() : request.getArrivalDate();
      if (arrival.isAfter(request.getPlacementDate())) {
        throw ApiException.badRequest("Arrival cannot be after the house placement date");
      }

      String sourceReference = blankToNull(request.getSourceReference());
      String cycleId = null;
      if (request.getSource() == PlacementSource.OWN_HATCH) {
        cycleId = requireHatchedStock(farmId, request);
        sourceReference = cycleRepository.findByIdAndFarmId(cycleId, farmId).map(HatcherCycle::getReference).orElse(null);
      } else if (request.getSourceCycleId() != null) {
        throw ApiException.badRequest("sourceCycleId applies only to OWN_HATCH placements");
      }

      int occupied = occupied(farmId, house.getId());
      if (occupied + request.getQuantity() > house.getCapacity()) {
        throw ApiException.capacityConflict(
            house.getName() + " would hold " + (occupied + request.getQuantity()) + " birds but its capacity is " + house.getCapacity(),
            Map.of(
                "resource", house.getId(),
                "requested", occupied + request.getQuantity(),
                "available", house.getCapacity(),
                "conflictingReferences", activeReferences(farmId, house.getId())));
      }

      Instant now = Instant.now();
      BirdPlacement placement =
          BirdPlacement.builder()
              .farmId(farmId)
              .reference(
                  "PL-" + request.getPlacementDate().format(DateTimeFormatter.BASIC_ISO_DATE) + "-"
                      + (placementRepository.countByFarmId(farmId) + 1))
              .source(request.getSource())
              .sourceCycleId(cycleId)
              .sourceReference(sourceReference)
              .houseId(house.getId())
              .quantity(request.getQuantity())
              .arrivalDate(arrival)
              .placementDate(request.getPlacementDate())
              .ageDaysAtArrival(request.getAgeDaysAtArrival() == null ? 0 : request.getAgeDaysAtArrival())
              .notes(blankToNull(request.getNotes()))
              .createdAt(now)
              .updatedAt(now)
              .createdBy(actor.getId())
              .updatedBy(actor.getId())
              .build();
      return toResponse(placementRepository.save(placement), List.of(), true);
    }
  }

  /** Appends a movement. A repeated idempotency key returns the original event unchanged. */
  public BirdMovementResponse addMovement(
      UserDetailsImpl actor, String placementId, BirdMovementRequest request, String idempotencyKey) {
    String farmId = accessService.requireManage(actor);
    String key = blankToNull(idempotencyKey);
    if (key != null && key.length() > 100) throw ApiException.badRequest("Idempotency-Key is too long");
    synchronized (incubationService.lock(farmId)) {
      if (key != null) {
        BirdMovement existing = movementRepository.findByFarmIdAndIdempotencyKey(farmId, key).orElse(null);
        if (existing != null) {
          if (!existing.getPlacementId().equals(placementId)) {
            throw ApiException.conflict("This Idempotency-Key was already used for a different placement");
          }
          return toResponse(existing);
        }
      }
      BirdPlacement placement = requirePlacement(farmId, placementId);
      if (request.getType() != MovementType.CORRECTION && request.isIncrease()) {
        throw ApiException.badRequest("Only a correction can add birds");
      }
      if (request.getDate().isAfter(today(farmId))) {
        throw ApiException.badRequest("Movement date cannot be in the future");
      }
      if (request.getDate().isBefore(placement.getPlacementDate())) {
        throw ApiException.badRequest("Movement cannot be before the placement date");
      }
      if (request.getType() == MovementType.CORRECTION && blankToNull(request.getReason()) == null) {
        throw ApiException.badRequest("A correction needs a reason");
      }

      BirdMovement movement =
          BirdMovement.builder()
              .farmId(farmId)
              .placementId(placementId)
              .type(request.getType())
              .count(request.getCount())
              .increase(request.getType() == MovementType.CORRECTION && request.isIncrease())
              .date(request.getDate())
              .reason(blankToNull(request.getReason()))
              .relatedRecordType(blankToNull(request.getRelatedRecordType()))
              .relatedRecordId(blankToNull(request.getRelatedRecordId()))
              .idempotencyKey(key)
              .createdAt(Instant.now())
              .createdBy(actor.getId())
              .build();

      int remaining = remaining(placement, movementRepository.findByFarmIdAndPlacementIdOrderByDateAscCreatedAtAsc(farmId, placementId));
      if (remaining + movement.delta() < 0) {
        throw ApiException.badRequest(
            "Only " + remaining + " birds remain in this placement, so " + request.getCount() + " cannot be removed");
      }
      if (movement.delta() > 0) {
        ProductionEquipment house =
            equipmentRepository
                .findByIdAndFarmIdAndArchivedFalse(placement.getHouseId(), farmId)
                .orElseThrow(() -> ApiException.notFound("Chicken house not found"));
        int occupied = occupied(farmId, house.getId());
        if (occupied + movement.delta() > house.getCapacity()) {
          throw ApiException.capacityConflict(
              house.getName() + " would hold " + (occupied + movement.delta()) + " birds but its capacity is " + house.getCapacity(),
              Map.of(
                  "resource", house.getId(),
                  "requested", occupied + movement.delta(),
                  "available", house.getCapacity(),
                  "conflictingReferences", activeReferences(farmId, house.getId())));
        }
      }
      try {
        return toResponse(movementRepository.save(movement));
      } catch (DuplicateKeyException e) {
        return toResponse(movementRepository.findByFarmIdAndIdempotencyKey(farmId, key).orElseThrow());
      } catch (OptimisticLockingFailureException e) {
        throw ApiException.conflict("Please retry");
      }
    }
  }

  @Override
  public Usage peakUsage(String farmId, String equipmentId) {
    ProductionEquipment e = equipmentRepository.findByIdAndFarmIdAndArchivedFalse(equipmentId, farmId).orElse(null);
    if (e == null || e.getType() != EquipmentType.CHICKEN_HOUSE) return null;
    int occupied = occupied(farmId, equipmentId);
    if (occupied == 0) return null;
    return new Usage(occupied, activeReferences(farmId, equipmentId));
  }

  int occupied(String farmId, String houseId) {
    List<BirdPlacement> placements = placementRepository.findByFarmIdAndHouseId(farmId, houseId);
    Map<String, List<BirdMovement>> ledger = ledger(farmId, placements);
    return placements.stream().mapToInt(p -> remaining(p, ledger.getOrDefault(p.getId(), List.of()))).sum();
  }

  /**
   * Birds expected in the house on {@code date}. Today or earlier is the actual headcount; for a
   * future date, placements that will have reached the grow-out age by then are treated as gone.
   */
  int occupiedOn(String farmId, String houseId, LocalDate date, int growOutDays) {
    if (!date.isAfter(today(farmId))) return occupied(farmId, houseId);
    List<BirdPlacement> placements = placementRepository.findByFarmIdAndHouseId(farmId, houseId);
    Map<String, List<BirdMovement>> ledger = ledger(farmId, placements);
    return placements.stream()
        .filter(p -> p.getPlacementDate().plusDays(Math.max(growOutDays - p.getAgeDaysAtArrival(), 0)).isAfter(date))
        .mapToInt(p -> remaining(p, ledger.getOrDefault(p.getId(), List.of())))
        .sum();
  }

  private List<String> activeReferences(String farmId, String houseId) {
    List<BirdPlacement> placements = placementRepository.findByFarmIdAndHouseId(farmId, houseId);
    Map<String, List<BirdMovement>> ledger = ledger(farmId, placements);
    return placements.stream()
        .filter(p -> remaining(p, ledger.getOrDefault(p.getId(), List.of())) > 0)
        .map(BirdPlacement::getReference)
        .toList();
  }

  private String requireHatchedStock(String farmId, BirdPlacementRequest request) {
    if (request.getSourceCycleId() == null || request.getSourceCycleId().isBlank()) {
      throw ApiException.badRequest("sourceCycleId is required for OWN_HATCH placements");
    }
    HatcherCycle cycle =
        cycleRepository
            .findByIdAndFarmId(request.getSourceCycleId(), farmId)
            .orElseThrow(() -> ApiException.notFound("Hatcher cycle not found"));
    HatchResult result =
        resultRepository
            .findByFarmIdAndHatcherCycleId(farmId, cycle.getId())
            .filter(r -> cycle.getStatus() == CycleStatus.COMPLETED)
            .orElseThrow(() -> ApiException.conflict("Record the hatch result before placing these chicks"));
    int alreadyPlaced = placementRepository.findByFarmIdAndSourceCycleId(farmId, cycle.getId()).stream().mapToInt(BirdPlacement::getQuantity).sum();
    int available = result.getHatchedChicks() - alreadyPlaced;
    if (request.getQuantity() > available) {
      throw ApiException.badRequest(
          "Only " + Math.max(available, 0) + " hatched chicks from this cycle are not yet placed");
    }
    return cycle.getId();
  }

  private Map<String, List<BirdMovement>> ledger(String farmId, List<BirdPlacement> placements) {
    if (placements.isEmpty()) return new HashMap<>();
    return movementRepository
        .findByFarmIdAndPlacementIdIn(farmId, placements.stream().map(BirdPlacement::getId).toList())
        .stream()
        .collect(Collectors.groupingBy(BirdMovement::getPlacementId));
  }

  private int remaining(BirdPlacement placement, List<BirdMovement> movements) {
    return placement.getQuantity() + movements.stream().mapToInt(BirdMovement::delta).sum();
  }

  private LocalDate today(String farmId) {
    return LocalDate.now(
        settingsRepository
            .findByFarmId(farmId)
            .map(s -> ZoneId.of(s.getTimeZone()))
            .orElse(ZoneId.of(ProductionSettingsService.DEFAULT_TIME_ZONE)));
  }

  private BirdPlacement requirePlacement(String farmId, String id) {
    return placementRepository
        .findByIdAndFarmId(id, farmId)
        .orElseThrow(() -> ApiException.notFound("Placement not found"));
  }

  private String blankToNull(String value) {
    return value == null || value.isBlank() ? null : value.trim();
  }

  private BirdPlacementResponse toResponse(BirdPlacement p, List<BirdMovement> movements, boolean detail) {
    int remaining = remaining(p, movements);
    return BirdPlacementResponse.builder()
        .id(p.getId())
        .reference(p.getReference())
        .source(p.getSource())
        .sourceCycleId(p.getSourceCycleId())
        .sourceReference(p.getSourceReference())
        .houseId(p.getHouseId())
        .quantity(p.getQuantity())
        .arrivalDate(p.getArrivalDate())
        .placementDate(p.getPlacementDate())
        .ageDaysAtArrival(p.getAgeDaysAtArrival())
        .notes(p.getNotes())
        .remaining(remaining)
        .mortality(sum(movements, MovementType.MORTALITY))
        .sold(sum(movements, MovementType.SALE))
        .otherRemovals(sum(movements, MovementType.TRANSFER) + sum(movements, MovementType.OTHER_REMOVAL))
        .status(remaining > 0 ? "ACTIVE" : "CLOSED")
        .movements(detail ? movements.stream().map(this::toResponse).toList() : null)
        .version(p.getVersion())
        .build();
  }

  private int sum(List<BirdMovement> movements, MovementType type) {
    return movements.stream().filter(m -> m.getType() == type).mapToInt(BirdMovement::getCount).sum();
  }

  private BirdMovementResponse toResponse(BirdMovement m) {
    return BirdMovementResponse.builder()
        .id(m.getId())
        .placementId(m.getPlacementId())
        .type(m.getType())
        .count(m.getCount())
        .increase(m.isIncrease())
        .date(m.getDate())
        .reason(m.getReason())
        .relatedRecordType(m.getRelatedRecordType())
        .relatedRecordId(m.getRelatedRecordId())
        .createdAt(m.getCreatedAt())
        .createdBy(m.getCreatedBy())
        .build();
  }
}
