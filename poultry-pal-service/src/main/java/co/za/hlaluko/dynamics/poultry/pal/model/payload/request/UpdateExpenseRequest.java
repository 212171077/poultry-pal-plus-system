package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class UpdateExpenseRequest {
  private String id;
  private String farmId;
  private String coopId;
  private Date expenseDate;
  private String expenseType;
  private Double amount;
  private String additionalInfo;
  private String recordedBy;
}
