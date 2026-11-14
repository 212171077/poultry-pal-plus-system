package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.exception.ErrorCodes;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import jakarta.validation.ConstraintViolationException;
import java.util.List;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestCookieException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

/**
 * Centralised error handling for the v1 API. Scoped to the v1 controller package so the legacy
 * {@code /api/farm} and {@code /api/auth} response formats used by the mobile app are unchanged.
 */
@RestControllerAdvice(basePackageClasses = V1ExceptionHandler.class)
public class V1ExceptionHandler {
  private static final Logger logger = LogManager.getLogger(V1ExceptionHandler.class);

  @ExceptionHandler(ApiException.class)
  public ResponseEntity<ApiResponse<Void>> handleApi(ApiException e) {
    return ResponseEntity.status(e.getStatus())
        .body(
            ApiResponse.<Void>error(e.getErrorCode(), e.getMessage()).toBuilder()
                .details(e.getDetails())
                .build());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException e) {
    List<ApiResponse.FieldError> errors =
        e.getBindingResult().getFieldErrors().stream()
            .map(f -> new ApiResponse.FieldError(f.getField(), f.getDefaultMessage()))
            .toList();
    return ResponseEntity.badRequest()
        .body(ApiResponse.error(ErrorCodes.VALIDATION_ERROR, "Validation failed", errors));
  }

  @ExceptionHandler(ConstraintViolationException.class)
  public ResponseEntity<ApiResponse<Void>> handleConstraint(ConstraintViolationException e) {
    List<ApiResponse.FieldError> errors =
        e.getConstraintViolations().stream()
            .map(v -> new ApiResponse.FieldError(v.getPropertyPath().toString(), v.getMessage()))
            .toList();
    return ResponseEntity.badRequest()
        .body(ApiResponse.error(ErrorCodes.VALIDATION_ERROR, "Validation failed", errors));
  }

  @ExceptionHandler({
    HttpMessageNotReadableException.class,
    MethodArgumentTypeMismatchException.class,
    MissingRequestCookieException.class
  })
  public ResponseEntity<ApiResponse<Void>> handleBadRequest(Exception e) {
    return ResponseEntity.badRequest()
        .body(ApiResponse.error(ErrorCodes.BAD_REQUEST, "Malformed request"));
  }

  @ExceptionHandler(DisabledException.class)
  public ResponseEntity<ApiResponse<Void>> handleDisabled(DisabledException e) {
    return ResponseEntity.status(HttpStatus.FORBIDDEN)
        .body(
            ApiResponse.error(
                ErrorCodes.FORBIDDEN,
                "Your account is awaiting approval or has been disabled. Please contact support."));
  }

  @ExceptionHandler(AuthenticationException.class)
  public ResponseEntity<ApiResponse<Void>> handleAuthentication(AuthenticationException e) {
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
        .body(ApiResponse.error(ErrorCodes.INVALID_CREDENTIALS, "Invalid username or password"));
  }

  @ExceptionHandler(AccessDeniedException.class)
  public ResponseEntity<ApiResponse<Void>> handleAccessDenied(AccessDeniedException e) {
    return ResponseEntity.status(HttpStatus.FORBIDDEN)
        .body(ApiResponse.error(ErrorCodes.FORBIDDEN, "Access denied"));
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception e) {
    logger.error("Unexpected v1 API error", e);
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(ApiResponse.error(ErrorCodes.INTERNAL_ERROR, "An unexpected error occurred"));
  }
}
