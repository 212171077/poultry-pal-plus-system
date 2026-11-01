package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.CoopAssignmentRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.TeamMemberRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.TeamRoleRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.TeamActivationRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.service.TeamManagementService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/team")
@Tag(name = "Team (v1)", description = "Farm team and coop assignments")
public class TeamController {
  private final TeamManagementService teamManagementService;

  @GetMapping
  @Operation(summary = "List users in the current manager's farm")
  public ResponseEntity<ApiResponse<List<UserInfoResponse>>> list() {
    return ResponseEntity.ok(
        ApiResponse.ok("Farm team retrieved", teamManagementService.list(SecurityUtils.getCurrentUser())));
  }

  @PostMapping
  @Operation(summary = "Add a team member to the current farm")
  public ResponseEntity<ApiResponse<List<UserInfoResponse>>> add(
      @Valid @RequestBody TeamMemberRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Team member added", teamManagementService.add(SecurityUtils.getCurrentUser(), request)));
  }

  @PatchMapping("/{memberId}/role")
  @Operation(summary = "Update a team member's role")
  public ResponseEntity<ApiResponse<List<UserInfoResponse>>> changeRole(
      @PathVariable String memberId, @Valid @RequestBody TeamRoleRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Team member role updated",
            teamManagementService.changeRole(SecurityUtils.getCurrentUser(), memberId, request)));
  }

  @PutMapping("/{memberId}/coops")
  @Operation(summary = "Set the coops assigned to a team member")
  public ResponseEntity<ApiResponse<List<UserInfoResponse>>> assignCoops(
      @PathVariable String memberId, @Valid @RequestBody CoopAssignmentRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Coop assignments updated",
            teamManagementService.assignCoops(SecurityUtils.getCurrentUser(), memberId, request)));
  }

  @PatchMapping("/{memberId}/activation")
  @Operation(summary = "Activate or deactivate a team member")
  public ResponseEntity<ApiResponse<List<UserInfoResponse>>> activation(
      @PathVariable String memberId, @Valid @RequestBody TeamActivationRequest request) {
    boolean active = request.isActive();
    return ResponseEntity.ok(
        ApiResponse.ok(
            active ? "Team member activated" : "Team member deactivated",
            teamManagementService.setActive(SecurityUtils.getCurrentUser(), memberId, active)));
  }

  @DeleteMapping("/{memberId}")
  @Operation(summary = "Remove a team member from the current farm")
  public ResponseEntity<ApiResponse<List<UserInfoResponse>>> remove(@PathVariable String memberId) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Team member removed",
            teamManagementService.remove(SecurityUtils.getCurrentUser(), memberId)));
  }
}
