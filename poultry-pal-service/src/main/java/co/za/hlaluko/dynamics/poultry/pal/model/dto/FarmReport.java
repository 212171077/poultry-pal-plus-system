package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class FarmReport {

  private int totalChickens;
  private double totalSales;
  private double totalExpenses;
  private int totalMortalities;
  private List<CoopReport> coopReports;

}
