package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CurrencyPreferenceRequest {
  @NotBlank @Size(min = 3, max = 3) @Pattern(regexp = "[A-Za-z]{3}") private String currency;
}
