package co.za.hlaluko.dynamics.poultry.pal.model.dto;

/** Lifecycle of a hatcher cycle. COMPLETED is set when hatch results are recorded. */
public enum CycleStatus {
  RESERVED,
  IN_HATCHER,
  COMPLETED,
  CANCELLED
}
