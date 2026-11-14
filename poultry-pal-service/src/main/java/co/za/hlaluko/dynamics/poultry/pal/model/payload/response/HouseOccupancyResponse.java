package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class HouseOccupancyResponse {
  private String houseId;
  private String name;
  private boolean enabled;
  private int capacity;
  private int occupied;
  private int available;
}
