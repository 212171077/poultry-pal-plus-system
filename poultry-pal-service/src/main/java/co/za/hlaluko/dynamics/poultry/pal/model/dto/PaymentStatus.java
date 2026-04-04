package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import lombok.Getter;

@Getter
public enum PaymentStatus {
  PAID("Paid"),
  PENDING("Pending"),;

  private final String value;

  PaymentStatus(String value) {
    this.value = value;
  }

    public static PaymentStatus fromValue(String value) {
    for (PaymentStatus coopType : PaymentStatus.values()) {
      if (coopType.value.equalsIgnoreCase(value)) {
        return coopType;
      }
    }
    throw new IllegalArgumentException("Invalid Payment value: " + value);
  }
}
