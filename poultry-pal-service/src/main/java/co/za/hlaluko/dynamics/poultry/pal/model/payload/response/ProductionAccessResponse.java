package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@AllArgsConstructor
public class ProductionAccessResponse {
  private String userId;
  private String farmId;
  private boolean canManageProduction;
  private boolean canGrantAccess;
  private List<String> permissions;
}
