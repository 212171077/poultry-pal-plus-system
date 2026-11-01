package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Marker for a deleted record so offline clients can remove it during delta sync. */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class SyncTombstone {
  private SyncEntityType entityType;
  private String entityId;
  private String coopId;
  private Long version;
  private Date deletedAt;
}
