package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.Date;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class Coop {
  private String id;
  private String coopName;
  private CoopType coopType;
  private GrowingPhase growthPhase;
  private int numberOfChickens;
  private Date createdDate;
  private Date chickenArrivalDate;
  private String chickenAge;
  private List<Mortality> mortalities;
  private List<Sale> sales;
  private List<Expense> expenses;
  private List<EggPackagingRecord> eggPackagingRecords;
  private Reminder reminder;
  private PhaseTransition phaseTransition;
  private List<String> responsibleUserIds;
  private boolean active;
}
