package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import lombok.Getter;

@Getter
public enum GrowingPhase {
  BROODING_PHASE("Brooding Phase"),
  GROWING_REARING_PHASE("Growing Phase"),
  PRODUCTION_FINISHING_PHASE("Production or Finishing Phase");

  private final String value;

  GrowingPhase(String value) {
    this.value = value;
  }

    public static GrowingPhase fromValue(String value) {
    for (GrowingPhase coopType : GrowingPhase.values()) {
      if (coopType.value.equalsIgnoreCase(value) || coopType.name().equalsIgnoreCase(value)) {
        return coopType;
      }
    }
    throw new IllegalArgumentException("Invalid growing phase value: " + value);
  }
}
