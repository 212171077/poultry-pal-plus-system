package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.AdminFarmMemberResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.AdminFarmPage;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.service.AdminFarmService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/admin/farms")
@Tag(name = "Registered farms (v1)", description = "System administrator farm and access management")
public class AdminFarmController {
  private final AdminFarmService service;

  @GetMapping
  @Operation(summary = "Registered farms with their users, by farm name")
  public ResponseEntity<ApiResponse<AdminFarmPage>> list(
      @RequestParam(required = false) String search,
      @RequestParam(required = false) Integer page,
      @RequestParam(required = false) Integer size) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Farms retrieved", service.list(SecurityUtils.getCurrentUser(), search, page, size)));
  }

  @PostMapping("/users/{userId}/grant-access")
  @Operation(summary = "Approve a user and let them sign in")
  public ResponseEntity<ApiResponse<AdminFarmMemberResponse>> grant(@PathVariable String userId) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Access granted", service.setAccess(SecurityUtils.getCurrentUser(), userId, true)));
  }

  @PostMapping("/users/{userId}/disable-access")
  @Operation(summary = "Block a user from signing in")
  public ResponseEntity<ApiResponse<AdminFarmMemberResponse>> disable(@PathVariable String userId) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Access disabled", service.setAccess(SecurityUtils.getCurrentUser(), userId, false)));
  }

  @DeleteMapping("/{farmId}")
  @Operation(summary = "Delete a farm with its users and all linked data")
  public ResponseEntity<ApiResponse<Void>> delete(@PathVariable String farmId) {
    service.deleteFarm(SecurityUtils.getCurrentUser(), farmId);
    return ResponseEntity.ok(ApiResponse.ok("Farm deleted", null));
  }
}
