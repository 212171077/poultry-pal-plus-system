package co.za.hlaluko.dynamics.poultry.pal.utils;

/** Packaging units eggs are sold in; the code is what the clients send as {@code eggPackaging}. */
public enum EggSalePackaging {
  TRAY_60(60),
  TRAY_30(30),
  BOX_360(360),
  SINGLE(1);

  private final int eggsPerUnit;

  EggSalePackaging(int eggsPerUnit) {
    this.eggsPerUnit = eggsPerUnit;
  }

  public int getEggsPerUnit() {
    return eggsPerUnit;
  }

  public static EggSalePackaging fromCode(String code) {
    if (code == null || code.isBlank()) {
      throw new IllegalArgumentException("Egg packaging is required");
    }
    try {
      return valueOf(code.trim().toUpperCase());
    } catch (IllegalArgumentException e) {
      throw new IllegalArgumentException("Unknown egg packaging: " + code);
    }
  }
}
