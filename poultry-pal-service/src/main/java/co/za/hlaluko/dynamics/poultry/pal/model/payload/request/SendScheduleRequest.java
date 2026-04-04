package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class SendScheduleRequest {
  @NotBlank private String farmId;
  @NotBlank private String userId;
  @NotBlank private String coopId;
}
