package co.za.hlaluko.dynamics.poultry.pal.utils;

/** Maps the egg box size labels used by the clients to the number of eggs per box. */
public final class EggBoxSizes {
  private EggBoxSizes() {}

  public static int eggsPerBox(String boxSize) {
    if (boxSize == null || boxSize.isBlank()) {
      return 0;
    }
    String normalized = boxSize.trim().toLowerCase();
    return switch (normalized) {
      case "6 eggs box" -> 6;
      case "12 eggs box" -> 12;
      case "18 eggs box" -> 18;
      case "30 eggs box" -> 30;
      case "60 eggs box" -> 60;
      default -> throw new IllegalArgumentException("Unable to determine eggs box size: " + boxSize);
    };
  }
}
