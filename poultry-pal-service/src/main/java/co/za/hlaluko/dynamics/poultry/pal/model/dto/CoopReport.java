package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class CoopReport {

  private String coopName;
  private String coopType;
  private int totalChickens;
  private String chickenAge;
  private int totalMortality;
  private int availableChickens;
  private double profit;
  private double expenses;
  private double sales;

}
