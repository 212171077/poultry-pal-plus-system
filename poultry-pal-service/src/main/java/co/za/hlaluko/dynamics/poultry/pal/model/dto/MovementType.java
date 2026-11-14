package co.za.hlaluko.dynamics.poultry.pal.model.dto;

/** CORRECTION is an explicit compensating event that either adds or removes birds. */
public enum MovementType {
  MORTALITY,
  SALE,
  TRANSFER,
  OTHER_REMOVAL,
  CORRECTION
}
