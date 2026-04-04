package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.util.Date;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@AllArgsConstructor
public class UserInfoResponse {

  private String id;
  private String name;
  private String surname;
  private String phoneNumber;
  private String farmId;
  private boolean isFarmOwner;
  private boolean isActive;
  private Date createdDate;
  private String email;
  private List<String> roles;
  private List<String> userCoopIds;
  private List<String> roleFriendlyNames;

}
