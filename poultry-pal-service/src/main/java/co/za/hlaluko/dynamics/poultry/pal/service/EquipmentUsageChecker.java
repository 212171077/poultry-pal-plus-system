package co.za.hlaluko.dynamics.poultry.pal.service;

import java.util.List;

/**
 * Reports committed usage of a piece of equipment so capacity or availability reductions can be
 * rejected. Production features (batches, hatcher cycles, placements) register implementations.
 */
public interface EquipmentUsageChecker {
  record Usage(int peakCommitted, List<String> references) {}

  /** Peak simultaneous committed quantity for the equipment, or {@code null} when unused. */
  Usage peakUsage(String farmId, String equipmentId);
}
