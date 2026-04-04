package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PaymentStatus;
import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class UpdateSaleRequest {
  private String id;
  private String farmId;
  private String coopId;
  // For egg sales per dozen
  private Integer numberOfDozensSold;
  private Double salePricePerDozen;
  // For chicken sales
  private Integer numberOfChickensSold;
  private Double salePricePerChicken;

  private String buyerName;
  private String recordedBy;
  private PaymentStatus paymentStatus;
  private Date saleDate;
}
