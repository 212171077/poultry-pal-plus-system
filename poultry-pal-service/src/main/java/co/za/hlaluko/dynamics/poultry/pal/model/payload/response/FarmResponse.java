package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Address;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.FarmReport;
import java.util.Date;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@AllArgsConstructor
public class FarmResponse {

  private String id;
  private String farmName;
  private Address address;
  private List<Coop> coops;
  private List<UserInfoResponse> users;
  private Date createdDate;
  private FarmReport farmReport;

}
