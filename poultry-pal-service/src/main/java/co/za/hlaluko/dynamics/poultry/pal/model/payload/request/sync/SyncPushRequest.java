package co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class SyncPushRequest {
  public static final int MAX_OPERATIONS = 200;

  @NotNull
  @Size(min = 1, max = MAX_OPERATIONS)
  private List<@Valid @NotNull SyncOperation> operations;
}
