package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class MessageResponse {
  private boolean success;
  private String message;
}
