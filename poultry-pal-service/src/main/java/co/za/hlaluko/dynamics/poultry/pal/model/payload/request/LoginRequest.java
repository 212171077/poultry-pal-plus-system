package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class LoginRequest {

  @NotBlank private String username;
  @NotBlank private String password;

  /**
   * Keep the session after the browser closes (v1 only). {@code false} issues a session-only
   * refresh cookie for shared computers. Missing means {@code true}, the previous behaviour.
   */
  private Boolean rememberMe;

  public LoginRequest(String username, String password) {
    this.username = username;
    this.password = password;
  }
}
