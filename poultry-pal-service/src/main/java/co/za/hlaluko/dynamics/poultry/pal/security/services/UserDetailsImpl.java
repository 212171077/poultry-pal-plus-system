package co.za.hlaluko.dynamics.poultry.pal.security.services;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import com.fasterxml.jackson.annotation.JsonIgnore;
import java.io.Serial;
import java.util.Collection;
import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;
import lombok.Builder;
import lombok.Data;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

@Data
@Builder
public class UserDetailsImpl implements UserDetails {
  @Serial private static final long serialVersionUID = 1L;

  @Getter private final String id;
  private String name;
  private String surname;
  private String phoneNumber;
  private String farmId;
  private boolean isFarmOwner;
  private boolean isActive;
  private Date createdDate;
  private final String email;
  private final Collection<? extends GrantedAuthority> authorities;
  @JsonIgnore private String password;

  public static UserDetailsImpl build(User user) {
    List<GrantedAuthority> authorities =
        user.getRoles().stream()
            .map(role -> new SimpleGrantedAuthority(role.getName().name()))
            .collect(Collectors.toList());

    return UserDetailsImpl.builder()
        .id(user.getId())
        .name(user.getName())
        .surname(user.getSurname())
        .phoneNumber(user.getPhoneNumber())
        .farmId(user.getFarmId())
        .isFarmOwner(user.isFarmOwner())
        .isActive(user.isActive())
        .createdDate(user.getCreatedDate())
        .email(user.getEmail())
        .password(user.getPassword())
        .authorities(authorities)
        .build();
  }

  @Override
  public Collection<? extends GrantedAuthority> getAuthorities() {
    return authorities;
  }

  @Override
  public String getPassword() {
    return password;
  }

  @Override
  public String getUsername() {
    return this.email;
  }

  @Override
  public boolean isAccountNonExpired() {
    return true;
  }

  @Override
  public boolean isAccountNonLocked() {
    return true;
  }

  @Override
  public boolean isCredentialsNonExpired() {
    return true;
  }

  @Override
  public boolean isEnabled() {
    return true;
  }
}
