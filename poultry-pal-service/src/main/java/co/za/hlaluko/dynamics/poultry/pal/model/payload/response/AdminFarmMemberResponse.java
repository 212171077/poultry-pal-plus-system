package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.util.List;
import lombok.Builder;
import lombok.Data;

/** A farm user as the system administrator sees them. {@code status} is ACTIVE, PENDING or DISABLED. */
@Data
@Builder
public class AdminFarmMemberResponse {
  private String id;
  private String name;
  private String surname;
  private String email;
  private String phoneNumber;
  private boolean owner;
  private List<String> roles;
  private String status;
}
