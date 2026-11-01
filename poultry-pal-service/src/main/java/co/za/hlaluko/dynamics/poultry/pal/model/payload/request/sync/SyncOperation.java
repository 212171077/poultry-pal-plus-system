package co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncEntityType;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** A single queued offline change. Ids are generated on the client so retries are safe. */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class SyncOperation {
  public static final String ID_PATTERN = "^[A-Za-z0-9_-]{1,64}$";

  @NotBlank
  @Pattern(regexp = ID_PATTERN, message = "must be 1-64 characters: letters, digits, '-' or '_'")
  private String opId;

  @NotNull private SyncEntityType entityType;
  @NotNull private SyncOperationType operation;

  @Size(max = 64)
  private String entityId;

  @Size(max = 64)
  private String coopId;

  /** Record version the client last saw; null when creating a new record. */
  private Long baseVersion;

  private JsonNode payload;
}
