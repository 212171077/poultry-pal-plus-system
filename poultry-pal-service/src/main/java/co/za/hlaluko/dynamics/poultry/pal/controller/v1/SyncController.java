package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.sync.SyncPushRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncBootstrapResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncChangesResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.SyncPushResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.sync.SyncService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.AllArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@AllArgsConstructor
@RequestMapping("/api/v1/sync")
@Tag(name = "Sync (v1)", description = "Offline-first synchronisation for the web client")
public class SyncController {
  private final SyncService syncService;

  @PostMapping("/push")
  @Operation(
      summary = "Apply a batch of queued offline changes",
      description =
          "Operations are idempotent by opId. Each result is APPLIED, CONFLICT (stale baseVersion)"
              + " or REJECTED; one failing operation does not fail the batch.")
  public ResponseEntity<ApiResponse<SyncPushResponse>> push(
      @Valid @RequestBody SyncPushRequest request) {
    SyncPushResponse response = syncService.push(SecurityUtils.getCurrentUser(), request);
    return ResponseEntity.ok(ApiResponse.ok("Sync push processed", response));
  }

  @GetMapping("/changes")
  @Operation(
      summary = "Get changes since a cursor",
      description =
          "Pass the returned cursor as 'since' on the next call. Omit 'since' for a full sync."
              + " When resetRequired is true, discard local data and call /bootstrap.")
  public ResponseEntity<ApiResponse<SyncChangesResponse>> changes(
      @RequestParam(required = false) @Min(-1) Long since,
      @RequestParam(required = false) @Min(1) @Max(SyncService.MAX_PAGE_SIZE) Integer limit) {
    SyncChangesResponse response =
        syncService.changes(SecurityUtils.getCurrentUser(), since, limit);
    return ResponseEntity.ok(ApiResponse.ok("Changes retrieved", response));
  }

  @GetMapping("/bootstrap")
  @Operation(summary = "Full snapshot of the caller's farm, team and settings")
  public ResponseEntity<ApiResponse<SyncBootstrapResponse>> bootstrap() {
    SyncBootstrapResponse response = syncService.bootstrap(SecurityUtils.getCurrentUser());
    return ResponseEntity.ok(ApiResponse.ok("Bootstrap snapshot", response));
  }
}
