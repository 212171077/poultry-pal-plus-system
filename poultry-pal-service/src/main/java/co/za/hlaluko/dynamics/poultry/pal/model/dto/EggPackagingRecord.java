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
public class EggPackagingRecord {
  private String id;
  private Date createdDate;
  private String eggSize;
  private String boxSize;
  private int numberOfBoxes;
  private int totalEggs;
  private String userId;
  private String additionalInfo;
}
