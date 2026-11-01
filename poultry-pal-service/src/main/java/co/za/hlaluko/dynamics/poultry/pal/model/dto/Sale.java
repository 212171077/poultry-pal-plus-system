package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import com.fasterxml.jackson.annotation.JsonAlias;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.mongodb.core.mapping.Field;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class Sale implements SyncTracked {
  private String id;
  // For egg sales per dozen
  private Integer numberOfDozensSold;
  private Double salePricePerDozen;
  // For egg sales by packaging (tray, box or single eggs); supersedes the dozen fields
  private String eggSize;
  private String eggPackaging;
  private Integer quantitySold;
  private Double pricePerUnit;
  private Integer totalEggsSold;
  // For chicken sales
  private Integer numberOfChickensSold;
  private Double salePricePerChicken;

  // Stored under the legacy field name so existing documents keep their value.
  @Field("buyerName")
  @JsonAlias("buyerName")
  private String additionalInfo;
  private String recordedBy;
  private PaymentStatus paymentStatus;
  private Double totalSaleAmount;
  private Date saleDate;
  private Date createdDate;

  // Sync metadata, maintained by FarmChangeTracker
  private Long version;
  private Date updatedAt;
  private String updatedBy;
}
