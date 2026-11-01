package co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * A lifecycle command on a coop (operation {@code ACTION}, the coop id is the operation entityId).
 *
 * <ul>
 *   <li>{@code NEW_BATCH}: archives the current batch (all records) and restarts the coop with
 *       {@link #batch}.
 *   <li>{@code PHASE_TRANSITION}: moves the flock to {@link #newGrowthPhase}, either in place or into
 *       the empty coop {@link #targetCoopId}, which takes over the flock and its records.
 * </ul>
 */
@Data
public class CoopActionPayload {

  public enum Action {
    NEW_BATCH,
    PHASE_TRANSITION
  }

  @NotNull private Action action;

  /** Required for {@code NEW_BATCH}. */
  @Valid private CoopPayload batch;

  /** Required for {@code PHASE_TRANSITION}. */
  private GrowingPhase newGrowthPhase;

  /** Optional for {@code PHASE_TRANSITION}; null (or the coop itself) transitions in place. */
  @Size(max = 64)
  private String targetCoopId;
}
