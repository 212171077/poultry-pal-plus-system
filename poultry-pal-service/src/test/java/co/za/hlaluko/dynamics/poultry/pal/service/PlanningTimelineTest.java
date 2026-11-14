package co.za.hlaluko.dynamics.poultry.pal.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlanCalculation;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.SourceMethod;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionSettings;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.PlanRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class PlanningTimelineTest {
  private ProductionSettings settings(int brooding, Integer leadDays) {
    return ProductionSettings.builder()
        .incubationDays(21)
        .transferDay(18)
        .broodingDays(brooding)
        .expectedHatchRate(new BigDecimal("0.8000"))
        .expectedMortalityRate(new BigDecimal("0.0500"))
        .defaultGrowOutDays(42)
        .supplierLeadTimeDays(leadDays)
        .build();
  }

  private PlanRequest request(SourceMethod method) {
    PlanRequest r = new PlanRequest();
    r.setSourceMethod(method);
    r.setTargetReadyDate(LocalDate.of(2027, 3, 1));
    r.setTargetQuantity(1000);
    return r;
  }

  @Test
  void ownEggsRoundUpAndWorkBackwardsFromTheTargetDate() {
    PlanCalculation c = PlanningService.timeline(request(SourceMethod.INCUBATE_EGGS), settings(0, null), Instant.now());
    assertEquals(1316, c.getEggsRequired());
    assertEquals(1053, c.getChicksRequired());
    assertEquals(LocalDate.of(2027, 1, 18), c.getHousePlacementDate());
    assertEquals(LocalDate.of(2027, 1, 18), c.getHatchOrArrivalDate());
    assertEquals(LocalDate.of(2026, 12, 28), c.getIncubationStartDate());
    assertEquals(LocalDate.of(2027, 1, 15), c.getTransferDate());
  }

  @Test
  void broodingMovesHatchEarlierThanHousePlacement() {
    PlanCalculation c = PlanningService.timeline(request(SourceMethod.INCUBATE_EGGS), settings(7, null), Instant.now());
    assertEquals(LocalDate.of(2027, 1, 18), c.getHousePlacementDate());
    assertEquals(LocalDate.of(2027, 1, 11), c.getHatchOrArrivalDate());
    assertEquals(LocalDate.of(2026, 12, 21), c.getIncubationStartDate());
  }

  @Test
  void purchasedChicksGiveAnOrderDeadlineOnlyWithALeadTime() {
    PlanCalculation without = PlanningService.timeline(request(SourceMethod.PURCHASE_DAY_OLD_CHICKS), settings(0, null), Instant.now());
    assertNull(without.getEggsRequired());
    assertNull(without.getLatestOrderDate());
    assertEquals(1053, without.getChicksRequired());
    PlanCalculation with = PlanningService.timeline(request(SourceMethod.PURCHASE_DAY_OLD_CHICKS), settings(0, 10), Instant.now());
    assertEquals(LocalDate.of(2027, 1, 8), with.getLatestOrderDate());
  }

  @Test
  void overridesReplaceTheFarmEstimates() {
    PlanRequest r = request(SourceMethod.INCUBATE_EGGS);
    r.setExpectedHatchRate(new BigDecimal("0.5"));
    r.setExpectedMortalityRate(BigDecimal.ZERO);
    r.setTargetAgeDays(30);
    PlanCalculation c = PlanningService.timeline(r, settings(0, null), Instant.now());
    assertEquals(2000, c.getEggsRequired());
    assertEquals(1000, c.getChicksRequired());
    assertEquals(LocalDate.of(2027, 1, 30), c.getHousePlacementDate());
  }
}
