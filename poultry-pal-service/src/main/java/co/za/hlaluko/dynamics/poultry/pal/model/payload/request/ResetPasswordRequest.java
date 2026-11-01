package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ResetPasswordRequest {
  @NotBlank @Email private String email;

  @NotBlank
  @Pattern(regexp = "\\d{6}", message = "Enter the 6-digit code from the email")
  private String code;

  @NotBlank @Size(min = 8, max = 100) private String newPassword;
}
