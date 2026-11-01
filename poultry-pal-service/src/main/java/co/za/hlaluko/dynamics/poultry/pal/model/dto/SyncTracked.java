package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.Date;

/**
 * Sync metadata carried by every record embedded in a farm document. {@code version} equals the
 * farm document version at the time the record last changed and is used both as the optimistic
 * concurrency token and as the delta-sync cursor.
 */
public interface SyncTracked {
  String getId();

  Long getVersion();

  void setVersion(Long version);

  Date getUpdatedAt();

  void setUpdatedAt(Date updatedAt);

  String getUpdatedBy();

  void setUpdatedBy(String updatedBy);
}
