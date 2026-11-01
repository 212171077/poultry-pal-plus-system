package co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncEntityType;
import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder(toBuilder = true)
@AllArgsConstructor
@NoArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class SyncOperationResult {
  private String opId;
  private SyncOperationStatus status;
  private SyncEntityType entityType;
  private String entityId;
  private String coopId;
  /** Server version of the record after the operation (or the current version on conflict). */
  private Long version;
  /** True when the opId was already processed; the original result is returned. */
  private boolean duplicate;
  private String errorCode;
  private String message;
  private List<String> errors;
  /** Current server state of the record (after apply, or on conflict). Null when deleted. */
  private Object serverRecord;
}
