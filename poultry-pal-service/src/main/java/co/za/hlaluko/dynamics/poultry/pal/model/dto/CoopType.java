package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import lombok.Getter;

@Getter
public enum CoopType {
  BROILER("Broiler"),
  LAYERS("Layers"),;

  private final String value;

  CoopType(String value) {
    this.value = value;
  }

    public static CoopType fromValue(String value) {
    for (CoopType coopType : CoopType.values()) {
      if (coopType.value.equalsIgnoreCase(value)) {
        return coopType;
      }
    }
    throw new IllegalArgumentException("Invalid CoopType value: " + value);
  }
}
