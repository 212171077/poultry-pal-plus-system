package co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync;

public enum SyncOperationStatus {
  /** Change was applied (or was already applied, see {@code duplicate}). */
  APPLIED,
  /** The record changed on the server since baseVersion; see serverRecord. */
  CONFLICT,
  /** The operation is invalid or not permitted and must not be retried unchanged. */
  REJECTED
}
