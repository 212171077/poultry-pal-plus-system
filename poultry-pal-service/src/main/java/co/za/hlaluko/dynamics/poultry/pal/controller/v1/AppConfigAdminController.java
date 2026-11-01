package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.AppConfigRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.AppConfigResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.service.AppConfigAdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/admin/app-config")
@Tag(name = "App config (v1)", description = "System administrator configuration management")
public class AppConfigAdminController {
  private final AppConfigAdminService service;

  @GetMapping
  @Operation(summary = "List configuration entries (secrets are masked)")
  public ResponseEntity<ApiResponse<List<AppConfigResponse>>> list() {
    return ResponseEntity.ok(
        ApiResponse.ok("Configuration retrieved", service.list(SecurityUtils.getCurrentUser())));
  }

  @PostMapping
  @Operation(summary = "Create a configuration entry")
  public ResponseEntity<ApiResponse<AppConfigResponse>> create(
      @Valid @RequestBody AppConfigRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Configuration created", service.create(SecurityUtils.getCurrentUser(), request)));
  }

  @PutMapping("/{id}")
  @Operation(summary = "Update a configuration value")
  public ResponseEntity<ApiResponse<AppConfigResponse>> update(
      @PathVariable String id, @Valid @RequestBody AppConfigRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Configuration updated", service.update(SecurityUtils.getCurrentUser(), id, request)));
  }

  @DeleteMapping("/{id}")
  @Operation(summary = "Delete a configuration entry")
  public ResponseEntity<ApiResponse<Void>> delete(@PathVariable String id) {
    service.delete(SecurityUtils.getCurrentUser(), id);
    return ResponseEntity.ok(ApiResponse.ok("Configuration deleted", null));
  }
}
