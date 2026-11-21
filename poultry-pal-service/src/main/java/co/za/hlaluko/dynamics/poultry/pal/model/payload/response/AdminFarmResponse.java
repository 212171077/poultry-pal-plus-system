package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.util.Date;
import java.util.List;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AdminFarmResponse {
  private String id;
  private String farmName;
  private String city;
  private Date createdDate;
  private int coopCount;
  private List<AdminFarmMemberResponse> members;
}
