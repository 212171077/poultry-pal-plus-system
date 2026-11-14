package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ScheduleOptionsResponse {
  private int eggs;
  private int expectedChicks;
  /** Earliest feasible start date, or null when no date in the range works. */
  private LocalDate recommendedStart;
  /** Consecutive feasible start dates merged into ranges. */
  private List<Window> windows;
  /** Every start date examined, with the reasons an infeasible date was rejected. */
  private List<Candidate> candidates;
  /** Plain-language summary, including why nothing fits when there is no window. */
  private String explanation;
  private List<String> assumptions;
  private Instant calculatedAt;

  @Data
  @Builder
  public static class Window {
    private LocalDate from;
    private LocalDate to;
  }

  @Data
  @Builder
  public static class Candidate {
    private LocalDate start;
    private LocalDate transferDate;
    private LocalDate hatchDate;
    private LocalDate houseArrivalDate;
    private boolean feasible;
    private List<String> reasons;
  }
}
