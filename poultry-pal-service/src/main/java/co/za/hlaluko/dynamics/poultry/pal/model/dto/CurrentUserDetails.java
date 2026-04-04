package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.Collection;
import java.util.Date;
import lombok.Builder;
import lombok.Data;
import org.springframework.security.core.GrantedAuthority;

@Data
@Builder
public class CurrentUserDetails {

  private String id;
  private String name;
  private String surname;
  private String phoneNumber;
  private String farmId;
  private boolean isFarmOwner;
  private boolean isActive;
  private Date createdDate;
  private String email;
  private Collection<? extends GrantedAuthority> authorities;
}
