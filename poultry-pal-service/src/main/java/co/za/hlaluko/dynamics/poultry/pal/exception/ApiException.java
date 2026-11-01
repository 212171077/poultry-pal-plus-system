package co.za.hlaluko.dynamics.poultry.pal.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

/** Exception carrying an HTTP status and a stable machine-readable error code. */
@Getter
public class ApiException extends RuntimeException {
  private final HttpStatus status;
  private final String errorCode;

  public ApiException(HttpStatus status, String errorCode, String message) {
    super(message);
    this.status = status;
    this.errorCode = errorCode;
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

  public static ApiException unauthorized(String message) {
    return new ApiException(HttpStatus.UNAUTHORIZED, ErrorCodes.UNAUTHORIZED, message);
  }
}
