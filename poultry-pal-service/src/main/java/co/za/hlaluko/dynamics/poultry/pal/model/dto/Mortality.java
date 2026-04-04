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
public class Mortality {
  private String id;
  private Date dateOccurred;
  private int numberOfDeaths;
  private String reason;
  private String recordedBy;
  private Date createdDate;
}
