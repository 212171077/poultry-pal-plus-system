package co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PaymentStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonAlias;
import lombok.Data;

/**
 * Layer coops use the packaging fields (or the legacy dozens fields); broiler coops use the chicken
 * fields.
 */
@Data
public class SalePayload {
  @PositiveOrZero private Integer numberOfDozensSold;
  @PositiveOrZero private Double salePricePerDozen;
  @Size(max = 30)
  private String eggSize;

  @Size(max = 30)
  private String eggPackaging;

  @PositiveOrZero private Integer quantitySold;
  @PositiveOrZero private Double pricePerUnit;
  @PositiveOrZero private Integer numberOfChickensSold;
  @PositiveOrZero private Double salePricePerChicken;

  @Size(max = 250)
  @JsonAlias("buyerName")
  private String additionalInfo;

  @Size(max = 100)
  private String recordedBy;

  private PaymentStatus paymentStatus;
  @NotNull private Date saleDate;
}
