package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.CurrencyPreferenceRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.FarmDetailsUpdateV1Request;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.PasswordChangeRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ProfileUpdateRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserSettingsResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.FarmSnapshot;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.security.jwt.JwtUtils;
import co.za.hlaluko.dynamics.poultry.pal.service.AccountSettingsService;
import co.za.hlaluko.dynamics.poultry.pal.service.AuthV1Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1")
@Tag(name = "Account settings (v1)")
public class AccountSettingsController {
  private final AccountSettingsService accountSettingsService;
  private final AuthV1Service authService;
  private final JwtUtils jwtUtils;

  @PatchMapping("/auth/profile")
  @Operation(summary = "Update the signed-in user's profile")
  public ResponseEntity<ApiResponse<UserInfoResponse>> updateProfile(
      @Valid @RequestBody ProfileUpdateRequest request, HttpServletRequest servletRequest) {
    var actor = SecurityUtils.getCurrentUser();
    String currentEmail = actor == null ? null : actor.getUsername();
    boolean emailChanged =
        currentEmail != null && !currentEmail.equals(request.getEmail().trim());
    String refreshToken = jwtUtils.getRefreshTokenFromCookies(servletRequest);
    if (emailChanged) authService.validateEmailChangeSession(actor, refreshToken);
    UserInfoResponse profile = accountSettingsService.updateProfile(actor, request);
    ResponseEntity.BodyBuilder response = ResponseEntity.ok();
    if (emailChanged) {
      response = withCookies(response, authService.renewAfterEmailChange(actor, refreshToken));
    }
    return response.body(ApiResponse.ok("Profile updated", profile));
  }

  @PatchMapping("/account/password")
  @Operation(summary = "Change the signed-in user's password")
  public ResponseEntity<ApiResponse<Void>> changePassword(
      @Valid @RequestBody PasswordChangeRequest request) {
    accountSettingsService.changePassword(SecurityUtils.getCurrentUser(), request);
    return ResponseEntity.ok(ApiResponse.ok("Password changed", null));
  }

  @PatchMapping("/farm/details")
  @Operation(summary = "Update farm details (owner or manager only)")
  public ResponseEntity<ApiResponse<FarmSnapshot>> updateFarmDetails(
      @Valid @RequestBody FarmDetailsUpdateV1Request request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Farm details updated",
            accountSettingsService.updateFarmDetails(SecurityUtils.getCurrentUser(), request)));
  }

  @PutMapping("/account/settings/currency")
  @Operation(summary = "Update the signed-in user's farm currency preference")
  public ResponseEntity<ApiResponse<UserSettingsResponse>> updateCurrency(
      @Valid @RequestBody CurrencyPreferenceRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Currency preference updated",
            accountSettingsService.updateCurrency(SecurityUtils.getCurrentUser(), request)));
  }

  private static ResponseEntity.BodyBuilder withCookies(
      ResponseEntity.BodyBuilder builder, List<ResponseCookie> cookies) {
    cookies.forEach(cookie -> builder.header(HttpHeaders.SET_COOKIE, cookie.toString()));
    return builder;
  }
}
