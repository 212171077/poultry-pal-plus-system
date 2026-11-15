package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.EmailLogResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.service.EmailLogAdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/admin/email-logs")
@Tag(name = "Email logs (v1)", description = "System administrator email delivery log")
public class EmailLogAdminController {
  private final EmailLogAdminService service;

  @GetMapping
  @Operation(summary = "Latest outgoing emails and whether they were delivered (newest first)")
  public ResponseEntity<ApiResponse<List<EmailLogResponse>>> latest(
      @RequestParam(required = false) Integer limit) {
    return ResponseEntity.ok(
        ApiResponse.ok("Email log retrieved", service.latest(SecurityUtils.getCurrentUser(), limit)));
  }
}
