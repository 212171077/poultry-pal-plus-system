package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PaymentStatus;
import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import com.fasterxml.jackson.annotation.JsonAlias;
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
  // For egg sales by packaging (tray, box or single eggs); supersedes the dozen fields
  private String eggSize;
  private String eggPackaging;
  private Integer quantitySold;
  private Double pricePerUnit;
  // For chicken sales
  private Integer numberOfChickensSold;
  private Double salePricePerChicken;

  @JsonAlias("buyerName")
  private String additionalInfo;
  private String recordedBy;
  private PaymentStatus paymentStatus;
  private Date saleDate;
}
