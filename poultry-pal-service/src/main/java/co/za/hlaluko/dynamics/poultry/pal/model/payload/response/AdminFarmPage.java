package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.util.List;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AdminFarmPage {
  private List<AdminFarmResponse> items;
  private int page;
  private int size;
  private long total;
}
