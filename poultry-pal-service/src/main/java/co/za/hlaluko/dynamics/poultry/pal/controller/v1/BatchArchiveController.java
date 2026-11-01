package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ArchivedBatchResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.service.BatchArchiveService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import lombok.AllArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@AllArgsConstructor
@RequestMapping("/api/v1/farm")
@Tag(name = "Farm (v1)", description = "Farm history for the web client")
public class BatchArchiveController {
  private final BatchArchiveService batchArchiveService;

  @GetMapping("/archived-batches")
  @Operation(summary = "Batches archived by 'new batch', newest first (owner or manager only)")
  public ResponseEntity<ApiResponse<List<ArchivedBatchResponse>>> archivedBatches() {
    List<ArchivedBatchResponse> batches =
        batchArchiveService.listArchivedBatches(SecurityUtils.getCurrentUser());
    return ResponseEntity.ok(ApiResponse.ok("Archived batches retrieved", batches));
  }
}
