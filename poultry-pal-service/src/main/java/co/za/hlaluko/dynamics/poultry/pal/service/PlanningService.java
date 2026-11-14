package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlanCalculation;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlanStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.SourceMethod;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionPlan;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionSettings;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.PlanDecisionRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.PlanRequest;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionPlanRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;

/**
 * Target-date calculator and saved plans. A calculation reserves nothing; a plan is a validated
 * intention that is flagged NEEDS_REVIEW, never rewritten, when the numbers move.
 */
@Service
@RequiredArgsConstructor
public class PlanningService {
  private static final Set<PlanStatus> OPEN = EnumSet.of(PlanStatus.DRAFT, PlanStatus.COMMITTED, PlanStatus.NEEDS_REVIEW);

  private final ProductionAccessService accessService;
  private final ProductionSettingsService settingsService;
  private final SchedulingService schedulingService;
  private final IncubationService incubationService;
  private final ProductionPlanRepository planRepository;

  public PlanCalculation calculate(UserDetailsImpl actor, PlanRequest request) {
    String farmId = accessService.requireManage(actor);
    ProductionSettings settings = settingsService.ensureInitialised(farmId, actor.getId());
    return evaluate(farmId, settings, timeline(request, settings, Instant.now()));
  }

  public List<ProductionPlan> list(UserDetailsImpl actor, boolean openOnly) {
    String farmId = accessService.requireManage(actor);
    return openOnly
        ? planRepository.findByFarmIdAndStatusInOrderByCreatedAtDesc(farmId, OPEN)
        : planRepository.findByFarmIdOrderByCreatedAtDesc(farmId);
  }

  public ProductionPlan get(UserDetailsImpl actor, String id) {
    return require(accessService.requireManage(actor), id);
  }

  public ProductionPlan save(UserDetailsImpl actor, PlanRequest request) {
    String farmId = accessService.requireManage(actor);
    synchronized (incubationService.lock(farmId)) {
      ProductionSettings settings = settingsService.ensureInitialised(farmId, actor.getId());
      Instant now = Instant.now();
      return planRepository.save(
          ProductionPlan.builder()
              .farmId(farmId)
              .name(blankToNull(request.getName()))
              .notes(blankToNull(request.getNotes()))
              .status(PlanStatus.DRAFT)
              .calculation(evaluate(farmId, settings, timeline(request, settings, now)))
              .createdAt(now)
              .updatedAt(now)
              .createdBy(actor.getId())
              .updatedBy(actor.getId())
              .build());
    }
  }

  /** Revalidates the plan against current capacity in one backend operation, then commits it. */
  public ProductionPlan commit(UserDetailsImpl actor, String id, PlanDecisionRequest decision) {
    String farmId = accessService.requireManage(actor);
    synchronized (incubationService.lock(farmId)) {
      ProductionPlan plan = require(farmId, id);
      requireStatus(plan, PlanStatus.DRAFT);
      ProductionSettings settings = settingsService.ensureInitialised(farmId, actor.getId());
      PlanCalculation fresh = evaluate(farmId, settings, plan.getCalculation());
      if (!fresh.isFeasible()) {
        Map<String, Object> details = new LinkedHashMap<>();
        details.put("constraints", fresh.getConstraints());
        throw ApiException.capacityConflict("This plan no longer fits: " + fresh.getConstraints().get(0), details);
      }
      plan.setCalculation(fresh);
      plan.setStatus(PlanStatus.COMMITTED);
      return decide(plan, actor, decision);
    }
  }

  /**
   * Recomputes with today's data. A draft just takes the new numbers; a committed plan whose
   * numbers changed keeps its old ones and is flagged for review.
   */
  public ProductionPlan recalculate(UserDetailsImpl actor, String id) {
    String farmId = accessService.requireManage(actor);
    synchronized (incubationService.lock(farmId)) {
      return recalculate(farmId, actor, require(farmId, id));
    }
  }

  public List<ProductionPlan> recalculateAll(UserDetailsImpl actor) {
    String farmId = accessService.requireManage(actor);
    synchronized (incubationService.lock(farmId)) {
      return planRepository.findByFarmIdAndStatusInOrderByCreatedAtDesc(farmId, OPEN).stream()
          .map(p -> recalculate(farmId, actor, p))
          .toList();
    }
  }

  public ProductionPlan acceptRecalculation(UserDetailsImpl actor, String id, PlanDecisionRequest decision) {
    String farmId = accessService.requireManage(actor);
    synchronized (incubationService.lock(farmId)) {
      ProductionPlan plan = require(farmId, id);
      requireStatus(plan, PlanStatus.NEEDS_REVIEW);
      if (decision == null || blankToNull(decision.getReason()) == null) {
        throw ApiException.badRequest("Give a reason for accepting the new dates");
      }
      plan.setCalculation(plan.getRecalculation());
      plan.setRecalculation(null);
      plan.setStatus(plan.getCalculation().isFeasible() ? PlanStatus.COMMITTED : PlanStatus.NEEDS_REVIEW);
      return decide(plan, actor, decision);
    }
  }

  public ProductionPlan cancel(UserDetailsImpl actor, String id, PlanDecisionRequest decision) {
    String farmId = accessService.requireManage(actor);
    synchronized (incubationService.lock(farmId)) {
      ProductionPlan plan = require(farmId, id);
      if (!OPEN.contains(plan.getStatus())) {
        throw ApiException.conflict("Only an open plan can be cancelled");
      }
      plan.setStatus(PlanStatus.CANCELLED);
      plan.setRecalculation(null);
      return decide(plan, actor, decision);
    }
  }

  private ProductionPlan recalculate(String farmId, UserDetailsImpl actor, ProductionPlan plan) {
    if (!OPEN.contains(plan.getStatus())) {
      throw ApiException.conflict("Only an open plan can be recalculated");
    }
    ProductionSettings settings = settingsService.ensureInitialised(farmId, actor.getId());
    PlanCalculation fresh = evaluate(farmId, settings, timeline(plan.getCalculation(), settings));
    if (plan.getStatus() == PlanStatus.DRAFT) {
      plan.setCalculation(fresh);
    } else if (plan.getCalculation().differsFrom(fresh)) {
      plan.setRecalculation(fresh);
      plan.setStatus(PlanStatus.NEEDS_REVIEW);
    } else {
      plan.setRecalculation(null);
      plan.setStatus(PlanStatus.COMMITTED);
    }
    return write(plan, actor);
  }

  private ProductionPlan decide(ProductionPlan plan, UserDetailsImpl actor, PlanDecisionRequest decision) {
    plan.setDecisionReason(decision == null ? null : blankToNull(decision.getReason()));
    return write(plan, actor);
  }

  private ProductionPlan write(ProductionPlan plan, UserDetailsImpl actor) {
    plan.setUpdatedAt(Instant.now());
    plan.setUpdatedBy(actor.getId());
    try {
      return planRepository.save(plan);
    } catch (OptimisticLockingFailureException e) {
      throw ApiException.conflict("This plan was changed by someone else. Reload and try again.");
    }
  }

  /** Pure date and quantity arithmetic from the request; constraints are added by {@link #evaluate}. */
  static PlanCalculation timeline(PlanRequest request, ProductionSettings s, Instant now) {
    int age = request.getTargetAgeDays() != null ? request.getTargetAgeDays() : s.getDefaultGrowOutDays();
    BigDecimal hatch = request.getExpectedHatchRate() != null ? request.getExpectedHatchRate() : s.getExpectedHatchRate();
    BigDecimal mortality =
        request.getExpectedMortalityRate() != null ? request.getExpectedMortalityRate() : s.getExpectedMortalityRate();
    return build(
        request.getSourceMethod(),
        request.getTargetReadyDate(),
        request.getTargetQuantity(),
        age,
        hatch,
        mortality,
        request.getHouseId(),
        s,
        now);
  }

  private static PlanCalculation timeline(PlanCalculation previous, ProductionSettings s) {
    return build(
        previous.getSourceMethod(),
        previous.getTargetReadyDate(),
        previous.getTargetQuantity(),
        previous.getTargetAgeDays(),
        previous.getHatchRate(),
        previous.getMortalityRate(),
        previous.getHouseId(),
        s,
        Instant.now());
  }

  private static PlanCalculation build(
      SourceMethod method,
      LocalDate ready,
      int quantity,
      int age,
      BigDecimal hatch,
      BigDecimal mortality,
      String houseId,
      ProductionSettings s,
      Instant now) {
    BigDecimal survival = BigDecimal.ONE.subtract(mortality);
    int chicks = BigDecimal.valueOf(quantity).divide(survival, 0, RoundingMode.CEILING).intValueExact();
    LocalDate placement = ready.minusDays(age);
    LocalDate hatchOrArrival = placement.minusDays(s.getBroodingDays());
    PlanCalculation.PlanCalculationBuilder b =
        PlanCalculation.builder()
            .sourceMethod(method)
            .targetReadyDate(ready)
            .targetQuantity(quantity)
            .targetAgeDays(age)
            .hatchRate(hatch)
            .mortalityRate(mortality)
            .houseId(houseId)
            .housePlacementDate(placement)
            .hatchOrArrivalDate(hatchOrArrival)
            .chicksRequired(chicks)
            .calculatedAt(now);
    List<String> assumptions = new ArrayList<>();
    assumptions.add("Estimate: " + pct(mortality) + " of chicks die before sale");
    assumptions.add("Sold at " + age + " days old, so chicks go into the house " + age + " days before the target date");
    if (s.getBroodingDays() > 0) {
      assumptions.add("Chicks brood for " + s.getBroodingDays() + " days before the house");
    }
    if (method == SourceMethod.INCUBATE_EGGS) {
      LocalDate start = hatchOrArrival.minusDays(s.getIncubationDays());
      int eggs =
          BigDecimal.valueOf(quantity)
              .divide(hatch.multiply(survival), 0, RoundingMode.CEILING)
              .intValueExact();
      b.eggsRequired(eggs).incubationStartDate(start).transferDate(start.plusDays(s.getTransferDay()));
      assumptions.add("Estimate: " + pct(hatch) + " of eggs hatch");
      assumptions.add("Eggs hatch on day " + s.getIncubationDays() + " and move to the hatcher on day " + s.getTransferDay());
    } else {
      if (s.getSupplierLeadTimeDays() != null) {
        b.latestOrderDate(hatchOrArrival.minusDays(s.getSupplierLeadTimeDays()));
        assumptions.add("Supplier lead time is " + s.getSupplierLeadTimeDays() + " days");
      } else {
        assumptions.add("No supplier lead time is set, so only the arrival date is given, not an order deadline");
      }
    }
    return b.assumptions(assumptions).constraints(List.of()).feasible(true).build();
  }

  private PlanCalculation evaluate(String farmId, ProductionSettings settings, PlanCalculation calc) {
    LocalDate today = LocalDate.now(ZoneId.of(settings.getTimeZone()));
    List<String> constraints = new ArrayList<>();
    LocalDate firstDay =
        calc.getSourceMethod() == SourceMethod.INCUBATE_EGGS ? calc.getIncubationStartDate() : calc.getHatchOrArrivalDate();
    if (firstDay.isBefore(today)) {
      constraints.add(
          (calc.getSourceMethod() == SourceMethod.INCUBATE_EGGS ? "Eggs would have to be set on " : "Chicks would have to arrive on ")
              + firstDay + ", which has already passed");
    }
    if (calc.getSourceMethod() == SourceMethod.INCUBATE_EGGS) {
      constraints.addAll(
          schedulingService.equipmentConstraints(farmId, settings, calc.getEggsRequired(), calc.getIncubationStartDate()));
    } else if (calc.getLatestOrderDate() != null && calc.getLatestOrderDate().isBefore(today)) {
      constraints.add("The latest order date " + calc.getLatestOrderDate() + " has already passed");
    }
    constraints.addAll(schedulingService.houseConstraints(
            farmId, calc.getHouseId(), calc.getChicksRequired(), calc.getHousePlacementDate(), settings.getDefaultGrowOutDays()));
    List<String> assumptions = new ArrayList<>(calc.getAssumptions());
    if (assumptions.stream().noneMatch(a -> a.startsWith("House space"))) {
      assumptions.add("House space assumes current birds leave after the grow-out period; extra sales and removals are not forecast");
    }
    return calc.toBuilder().constraints(constraints).assumptions(assumptions).feasible(constraints.isEmpty()).build();
  }

  private ProductionPlan require(String farmId, String id) {
    return planRepository.findByIdAndFarmId(id, farmId).orElseThrow(() -> ApiException.notFound("Plan not found"));
  }

  private void requireStatus(ProductionPlan plan, PlanStatus expected) {
    if (plan.getStatus() != expected) {
      throw ApiException.conflict("This plan is " + plan.getStatus() + ", not " + expected);
    }
  }

  private static String pct(BigDecimal rate) {
    return rate.movePointRight(2).stripTrailingZeros().toPlainString() + "%";
  }

  private String blankToNull(String value) {
    return value == null || value.isBlank() ? null : value.trim();
  }
}
