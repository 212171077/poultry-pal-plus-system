package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class AddResponsibleUserRequest {
  private List<String> coopIds;
  @NotBlank private String farmId;
  @NotBlank private String userId;

}
