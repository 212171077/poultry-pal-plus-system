package co.za.hlaluko.dynamics.poultry.pal.model.dto;

/** Lifecycle of an incubation batch. COMPLETED is set when hatch results are recorded. */
public enum BatchStatus {
  PLANNED,
  INCUBATING,
  TRANSFERRED,
  COMPLETED,
  CANCELLED
}
