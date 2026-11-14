package co.za.hlaluko.dynamics.poultry.pal.service;

import java.time.LocalDate;
import java.util.List;

/** Interval arithmetic for equipment occupancy. Intervals are half-open: [start, end). */
public final class ProductionCapacity {
  private ProductionCapacity() {}

  public record Interval(LocalDate start, LocalDate end, int quantity, String reference) {
    public boolean overlaps(Interval other) {
      return start.isBefore(other.end) && other.start.isBefore(end);
    }
  }

  /** Highest simultaneous quantity across the intervals. */
  public static int peak(List<Interval> intervals) {
    int peak = 0;
    for (Interval probe : intervals) {
      int sum = 0;
      for (Interval other : intervals) {
        if (!other.start().isAfter(probe.start()) && probe.start().isBefore(other.end())) {
          sum += other.quantity();
        }
      }
      peak = Math.max(peak, sum);
    }
    return peak;
  }
}
