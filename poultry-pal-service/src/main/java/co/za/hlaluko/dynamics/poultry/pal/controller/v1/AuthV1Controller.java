package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ForgotPasswordRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.LoginRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ResetPasswordRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.SignupRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.security.jwt.JwtUtils;
import co.za.hlaluko.dynamics.poultry.pal.service.AuthV1Service;
import co.za.hlaluko.dynamics.poultry.pal.service.PasswordResetService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import lombok.AllArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@AllArgsConstructor
@RequestMapping("/api/v1/auth")
@Tag(name = "Auth (v1)", description = "Cookie-based authentication with refresh-token rotation")
public class AuthV1Controller {
  private final AuthV1Service authService;
  private final JwtUtils jwtUtils;
  private final PasswordResetService passwordResetService;

  @PostMapping("/signin")
  @Operation(summary = "Sign in; sets HttpOnly access and refresh cookies")
  public ResponseEntity<ApiResponse<UserInfoResponse>> signin(
      @Valid @RequestBody LoginRequest request) {
    AuthV1Service.AuthResult result = authService.signin(request);
    return withCookies(ResponseEntity.ok(), result.cookies())
        .body(ApiResponse.ok("Signed in", result.user()));
  }

  @PostMapping("/signup")
  @Operation(summary = "Register a new farm owner and farm")
  public ResponseEntity<ApiResponse<Void>> signup(@Valid @RequestBody SignupRequest request) {
    authService.signup(request);
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(ApiResponse.ok("Profile created successfully", null));
  }

  @PostMapping("/forgot-password")
  @Operation(summary = "Email a 6-digit password reset code (always succeeds)")
  public ResponseEntity<ApiResponse<Void>> forgotPassword(
      @Valid @RequestBody ForgotPasswordRequest request) {
    passwordResetService.requestReset(request.getEmail());
    return ResponseEntity.ok(
        ApiResponse.ok("If the email is registered, a reset code has been sent", null));
  }

  @PostMapping("/reset-password")
  @Operation(summary = "Set a new password using the emailed code")
  public ResponseEntity<ApiResponse<Void>> resetPassword(
      @Valid @RequestBody ResetPasswordRequest request) {
    if (!passwordResetService.reset(
        request.getEmail(), request.getCode(), request.getNewPassword())) {
      throw ApiException.badRequest("The code is invalid or has expired");
    }
    return ResponseEntity.ok(ApiResponse.ok("Password updated", null));
  }

  @PostMapping("/refresh")
  @Operation(summary = "Rotate the refresh cookie and issue a new access cookie")
  public ResponseEntity<ApiResponse<UserInfoResponse>> refresh(HttpServletRequest request) {
    AuthV1Service.AuthResult result =
        authService.refresh(jwtUtils.getRefreshTokenFromCookies(request));
    return withCookies(ResponseEntity.ok(), result.cookies())
        .body(ApiResponse.ok("Session refreshed", result.user()));
  }

  @PostMapping("/logout")
  @Operation(summary = "Revoke the refresh token and clear auth cookies")
  public ResponseEntity<ApiResponse<Void>> logout(HttpServletRequest request) {
    List<ResponseCookie> cookies =
        authService.logout(jwtUtils.getRefreshTokenFromCookies(request));
    return withCookies(ResponseEntity.ok(), cookies).body(ApiResponse.ok("Signed out", null));
  }

  @GetMapping("/me")
  @Operation(summary = "Current user profile")
  public ResponseEntity<ApiResponse<UserInfoResponse>> me() {
    return ResponseEntity.ok(
        ApiResponse.ok("Current user", authService.me(SecurityUtils.getCurrentUser())));
  }

  private static ResponseEntity.BodyBuilder withCookies(
      ResponseEntity.BodyBuilder builder, List<ResponseCookie> cookies) {
    cookies.forEach(cookie -> builder.header(HttpHeaders.SET_COOKIE, cookie.toString()));
    return builder;
  }
}
