package co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserSettingsResponse;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Full snapshot of the caller's farm plus reference data. */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class SyncBootstrapResponse {
  private UserInfoResponse user;
  private SyncChangesResponse snapshot;
  private List<UserInfoResponse> team;
  private UserSettingsResponse settings;
}
