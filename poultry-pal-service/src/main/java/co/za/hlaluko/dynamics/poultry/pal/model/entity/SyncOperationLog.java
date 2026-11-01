package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncOperationResult;
import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/** Idempotency log of processed sync operations. Expires via a TTL index on createdAt. */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
@Document(collection = "sync_operations")
public class SyncOperationLog {
  /** {@code farmId + ":" + opId}, so operation ids are scoped to a single farm. */
  @Id private String id;

  private String farmId;
  private String userId;
  private SyncOperationResult result;
  private Date createdAt;
}
