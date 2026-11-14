package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionEquipment;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionSettings;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ScheduleSearchRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ScheduleOptionsResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionEquipmentRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Read-only search for incubation start dates that fit the incubator, hatcher and chicken house.
 * It reserves nothing: the capacity checks at batch creation remain the authority.
 */
@Service
@RequiredArgsConstructor
public class SchedulingService {
  static final int MAX_SEARCH_DAYS = 180;
  private static final int DEFAULT_HATCHER_OCCUPANCY_DAYS = 3;

  private final ProductionAccessService accessService;
  private final ProductionSettingsService settingsService;
  private final ProductionEquipmentRepository equipmentRepository;
  private final IncubationService incubationService;
  private final PlacementService placementService;

  public ScheduleOptionsResponse search(UserDetailsImpl actor, ScheduleSearchRequest request) {
    String farmId = accessService.requireManage(actor);
    if (request.getLatestStart().isBefore(request.getEarliestStart())) {
      throw ApiException.badRequest("The latest start date cannot be before the earliest");
    }
    long span = ChronoUnit.DAYS.between(request.getEarliestStart(), request.getLatestStart()) + 1;
    if (span > MAX_SEARCH_DAYS) {
      throw ApiException.badRequest("Search at most " + MAX_SEARCH_DAYS + " days at a time");
    }

    ProductionSettings settings = settingsService.ensureInitialised(farmId, actor.getId());
    ProductionEquipment incubator = pick(farmId, request.getIncubatorId(), EquipmentType.INCUBATOR);
    ProductionEquipment hatcher = pick(farmId, request.getHatcherId(), EquipmentType.HATCHER);
    ProductionEquipment house =
        request.getHouseId() == null && firstEnabled(farmId, EquipmentType.CHICKEN_HOUSE) == null
            ? null
            : pick(farmId, request.getHouseId(), EquipmentType.CHICKEN_HOUSE);

    int eggs = request.getEggs();
    int chicks = java.math.BigDecimal.valueOf(eggs).multiply(settings.getExpectedHatchRate()).setScale(0, java.math.RoundingMode.FLOOR).intValue();
    int hatcherDays =
        hatcher.getHatcherOccupancyDays() == null
            ? DEFAULT_HATCHER_OCCUPANCY_DAYS
            : hatcher.getHatcherOccupancyDays();
    List<ProductionCapacity.Interval> incubatorLoad =
        incubationService.incubatorIntervals(farmId, incubator.getId(), null);
    List<ProductionCapacity.Interval> hatcherLoad =
        incubationService.hatcherIntervals(farmId, hatcher.getId(), List.of());

    List<ScheduleOptionsResponse.Candidate> candidates = new ArrayList<>();
    for (LocalDate start = request.getEarliestStart();
        !start.isAfter(request.getLatestStart());
        start = start.plusDays(1)) {
      LocalDate transfer = start.plusDays(settings.getTransferDay());
      LocalDate hatch = start.plusDays(settings.getIncubationDays());
      LocalDate arrival = hatch.plusDays(settings.getBroodingDays());
      List<String> reasons = new ArrayList<>();

      ProductionCapacity.Interval inc = new ProductionCapacity.Interval(start, transfer, eggs, "new batch");
      reasons.addAll(overload(incubator, incubatorLoad, inc, "eggs"));
      ProductionCapacity.Interval hat =
          new ProductionCapacity.Interval(transfer, transfer.plusDays(hatcherDays), eggs, "new batch");
      reasons.addAll(overload(hatcher, hatcherLoad, hat, "eggs"));
      if (house != null) {
        if (!house.isEnabled()) {
          reasons.add(house.getName() + " is disabled");
        } else {
          reasons.addAll(houseReasons(farmId, house, arrival, chicks, settings.getDefaultGrowOutDays()));
        }
      }
      candidates.add(
          ScheduleOptionsResponse.Candidate.builder()
              .start(start)
              .transferDate(transfer)
              .hatchDate(hatch)
              .houseArrivalDate(arrival)
              .feasible(reasons.isEmpty())
              .reasons(reasons)
              .build());
    }

    List<ScheduleOptionsResponse.Window> windows = windows(candidates);
    LocalDate recommended = windows.isEmpty() ? null : windows.get(0).getFrom();
    return ScheduleOptionsResponse.builder()
        .eggs(eggs)
        .expectedChicks(chicks)
        .recommendedStart(recommended)
        .windows(windows)
        .candidates(candidates)
        .explanation(explain(candidates, windows))
        .assumptions(assumptions(settings, hatcherDays, house != null))
        .calculatedAt(Instant.now())
        .build();
  }

  /** Incubator and hatcher reasons a batch of {@code eggs} cannot start on {@code start}. */
  List<String> equipmentConstraints(String farmId, ProductionSettings settings, int eggs, LocalDate start) {
    ProductionEquipment incubator = pick(farmId, null, EquipmentType.INCUBATOR);
    ProductionEquipment hatcher = pick(farmId, null, EquipmentType.HATCHER);
    int hatcherDays =
        hatcher.getHatcherOccupancyDays() == null
            ? DEFAULT_HATCHER_OCCUPANCY_DAYS
            : hatcher.getHatcherOccupancyDays();
    LocalDate transfer = start.plusDays(settings.getTransferDay());
    List<String> reasons = new ArrayList<>();
    reasons.addAll(
        overload(
            incubator,
            incubationService.incubatorIntervals(farmId, incubator.getId(), null),
            new ProductionCapacity.Interval(start, transfer, eggs, "new batch"),
            "eggs"));
    reasons.addAll(
        overload(
            hatcher,
            incubationService.hatcherIntervals(farmId, hatcher.getId(), List.of()),
            new ProductionCapacity.Interval(transfer, transfer.plusDays(hatcherDays), eggs, "new batch"),
            "eggs"));
    return reasons;
  }

  /** Reasons {@code birds} more birds cannot go into the house (the first enabled one by default). */
  List<String> houseConstraints(
      String farmId, String houseId, int birds, LocalDate placementDate, int growOutDays) {
    ProductionEquipment house =
        houseId == null && firstEnabled(farmId, EquipmentType.CHICKEN_HOUSE) == null
            ? null
            : pick(farmId, houseId, EquipmentType.CHICKEN_HOUSE);
    if (house == null) return List.of();
    if (!house.isEnabled()) return List.of(house.getName() + " is disabled");
    return houseReasons(farmId, house, placementDate, birds, growOutDays);
  }

  private List<String> houseReasons(
      String farmId, ProductionEquipment house, LocalDate date, int birds, int growOutDays) {
    int occupied = placementService.occupiedOn(farmId, house.getId(), date, growOutDays);
    if (occupied + birds <= house.getCapacity()) return List.of();
    return List.of(
        house.getName() + " is expected to hold " + occupied + " birds on " + date + ", so " + birds
            + " more would exceed its capacity of " + house.getCapacity());
  }

  private List<String> overload(
      ProductionEquipment unit,
      List<ProductionCapacity.Interval> existing,
      ProductionCapacity.Interval candidate,
      String noun) {
    List<ProductionCapacity.Interval> all = new ArrayList<>(existing);
    all.add(candidate);
    int peak = ProductionCapacity.peak(all);
    if (peak <= unit.getCapacity()) return List.of();
    List<String> conflicts =
        existing.stream().filter(e -> e.overlaps(candidate)).map(ProductionCapacity.Interval::reference).distinct().toList();
    String with = conflicts.isEmpty() ? "" : " alongside " + String.join(", ", conflicts);
    return List.of(
        unit.getName() + " would hold " + peak + " " + noun + " (capacity " + unit.getCapacity() + ")" + with);
  }

  private List<ScheduleOptionsResponse.Window> windows(List<ScheduleOptionsResponse.Candidate> candidates) {
    List<ScheduleOptionsResponse.Window> windows = new ArrayList<>();
    LocalDate from = null;
    LocalDate last = null;
    for (ScheduleOptionsResponse.Candidate c : candidates) {
      if (c.isFeasible()) {
        if (from == null) from = c.getStart();
        last = c.getStart();
      } else if (from != null) {
        windows.add(ScheduleOptionsResponse.Window.builder().from(from).to(last).build());
        from = null;
      }
    }
    if (from != null) windows.add(ScheduleOptionsResponse.Window.builder().from(from).to(last).build());
    return windows;
  }

  private String explain(
      List<ScheduleOptionsResponse.Candidate> candidates, List<ScheduleOptionsResponse.Window> windows) {
    if (!windows.isEmpty()) {
      return windows.size() + (windows.size() == 1 ? " start window fits" : " start windows fit")
          + ". The earliest start is " + windows.get(0).getFrom() + ".";
    }
    String reason = candidates.get(0).getReasons().get(0);
    return "No start date between " + candidates.get(0).getStart() + " and "
        + candidates.get(candidates.size() - 1).getStart() + " fits. For example on "
        + candidates.get(0).getStart() + ": " + reason + ".";
  }

  private List<String> assumptions(ProductionSettings s, int hatcherDays, boolean house) {
    List<String> list = new ArrayList<>();
    list.add("Estimate: " + s.getExpectedHatchRate().movePointRight(2).stripTrailingZeros().toPlainString() + "% of eggs hatch");
    list.add("Eggs move to the hatcher on day " + s.getTransferDay() + " and hatch on day " + s.getIncubationDays());
    list.add("A lot occupies the hatcher for " + hatcherDays + " days");
    if (house) {
      list.add("Chicks reach the house " + s.getBroodingDays() + " days after hatching");
      list.add("House space assumes current birds leave after the grow-out period; extra sales and removals are not forecast");
    } else {
      list.add("No chicken house was checked");
    }
    return list;
  }

  private ProductionEquipment pick(String farmId, String id, EquipmentType type) {
    if (id != null) {
      return equipmentRepository
          .findByIdAndFarmIdAndArchivedFalse(id, farmId)
          .filter(e -> e.getType() == type)
          .orElseThrow(() -> ApiException.notFound(type + " not found"));
    }
    ProductionEquipment unit = firstEnabled(farmId, type);
    if (unit == null) throw ApiException.badRequest("Add an enabled " + type + " in production settings first");
    return unit;
  }

  private ProductionEquipment firstEnabled(String farmId, EquipmentType type) {
    return equipmentRepository.findByFarmIdAndArchivedFalseOrderByTypeAscNameAsc(farmId).stream()
        .filter(e -> e.getType() == type && e.isEnabled())
        .findFirst()
        .orElse(null);
  }
}
