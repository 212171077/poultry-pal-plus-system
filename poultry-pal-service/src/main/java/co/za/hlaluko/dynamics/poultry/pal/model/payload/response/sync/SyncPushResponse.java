package co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync;

import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class SyncPushResponse {
  private List<SyncOperationResult> results;
  /** Current farm version after the push. */
  private long serverVersion;
}
