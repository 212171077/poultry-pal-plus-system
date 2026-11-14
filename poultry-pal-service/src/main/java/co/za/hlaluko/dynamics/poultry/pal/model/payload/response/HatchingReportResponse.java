package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.math.BigDecimal;
import java.util.List;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class HatchingReportResponse {
  private Summary summary;
  /** Chronological monthly aggregates over the whole filtered range. */
  private List<TrendPoint> trend;
  /** Newest first. */
  private List<HatchResultResponse> rows;
  private int page;
  private int size;
  private long totalElements;

  @Data
  @Builder
  public static class Summary {
    private int results;
    private long eggsTransferred;
    private long hatchedChicks;
    private long unhatchedEggs;
    private long weakChicks;
    /** Weighted by eggs transferred; null when there are no eggs. */
    private BigDecimal hatchRate;
    private BigDecimal weakRate;
  }

  @Data
  @Builder
  public static class TrendPoint {
    /** yyyy-MM */
    private String period;
    private int results;
    private long eggsTransferred;
    private long hatchedChicks;
    private BigDecimal hatchRate;
  }
}
