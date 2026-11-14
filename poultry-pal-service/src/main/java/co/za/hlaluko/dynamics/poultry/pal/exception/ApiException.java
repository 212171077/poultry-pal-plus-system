package co.za.hlaluko.dynamics.poultry.pal.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

/** Exception carrying an HTTP status and a stable machine-readable error code. */
@Getter
public class ApiException extends RuntimeException {
  private final HttpStatus status;
  private final String errorCode;
  /** Optional machine-readable context, e.g. the conflicting resource for CAPACITY_CONFLICT. */
  private final Object details;

  public ApiException(HttpStatus status, String errorCode, String message) {
    this(status, errorCode, message, null);
  }

  public ApiException(HttpStatus status, String errorCode, String message, Object details) {
    super(message);
    this.status = status;
    this.errorCode = errorCode;
    this.details = details;
  }

  public static ApiException notFound(String message) {
    return new ApiException(HttpStatus.NOT_FOUND, ErrorCodes.NOT_FOUND, message);
  }

  public static ApiException badRequest(String message) {
    return new ApiException(HttpStatus.BAD_REQUEST, ErrorCodes.BAD_REQUEST, message);
  }

  public static ApiException forbidden(String message) {
    return new ApiException(HttpStatus.FORBIDDEN, ErrorCodes.FORBIDDEN, message);
  }

  public static ApiException conflict(String message) {
    return new ApiException(HttpStatus.CONFLICT, ErrorCodes.CONFLICT, message);
  }

  public static ApiException capacityConflict(String message, Object details) {
    return new ApiException(HttpStatus.CONFLICT, ErrorCodes.CAPACITY_CONFLICT, message, details);
  }

  public static ApiException unauthorized(String message) {
    return new ApiException(HttpStatus.UNAUTHORIZED, ErrorCodes.UNAUTHORIZED, message);
  }
}
