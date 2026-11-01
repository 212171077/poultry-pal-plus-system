package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.CoopType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Summary of a batch that was archived when a new batch was started in its coop. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ArchivedBatchResponse {
  private String id;
  private String coopId;
  private String coopName;
  private CoopType coopType;
  private GrowingPhase growthPhase;
  private int numberOfChickens;
  private Date chickenArrivalDate;
  private Date archivedDate;
  private double totalSales;
  private double totalExpenses;
  private int totalDeaths;
  private int totalEggs;
  private int salesCount;
  private int expensesCount;
  private int mortalityCount;
  private int eggRecordCount;
}
