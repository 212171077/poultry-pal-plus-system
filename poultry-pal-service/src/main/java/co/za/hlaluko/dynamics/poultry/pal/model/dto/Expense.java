package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class Expense {
  private String id;
  private Date expenseDate;
  private String expenseType;
  private Double amount;
  private String additionalInfo;
  private String recordedBy;
  private Date createdDate;
}
