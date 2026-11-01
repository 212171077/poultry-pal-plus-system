package co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.util.Date;
import lombok.Data;

@Data
public class ExpensePayload {
  @NotNull private Date expenseDate;

  @NotBlank
  @Size(max = 100)
  private String expenseType;

  @NotNull @PositiveOrZero private Double amount;

  @Size(max = 500)
  private String additionalInfo;

  @Size(max = 100)
  private String recordedBy;
}
