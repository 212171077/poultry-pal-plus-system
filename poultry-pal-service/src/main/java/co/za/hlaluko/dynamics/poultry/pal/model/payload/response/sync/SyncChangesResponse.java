package co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncTombstone;
import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * A page of changes. Child records (sales, mortalities, expenses, egg packaging records) include a
 * {@code coopId} property. Coops are returned without their child lists.
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class SyncChangesResponse {
  /** Pass as {@code since} on the next call. */
  private long cursor;

  private boolean hasMore;

  /** The client's cursor is older than retained tombstones; it must discard data and bootstrap. */
  private boolean resetRequired;

  private FarmSnapshot farm;
  @Builder.Default private List<Map<String, Object>> coops = new ArrayList<>();
  @Builder.Default private List<Map<String, Object>> sales = new ArrayList<>();
  @Builder.Default private List<Map<String, Object>> mortalities = new ArrayList<>();
  @Builder.Default private List<Map<String, Object>> expenses = new ArrayList<>();
  @Builder.Default private List<Map<String, Object>> eggPackagingRecords = new ArrayList<>();
  @Builder.Default private List<SyncTombstone> tombstones = new ArrayList<>();
}
