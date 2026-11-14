package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Standard response envelope used by all {@code /api/v1} endpoints. */
@Data
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiResponse<T> {
  private boolean success;
  private String message;
  private T data;
  private String errorCode;
  private List<FieldError> errors;
  private Object details;

  public static <T> ApiResponse<T> ok(String message, T data) {
    return ApiResponse.<T>builder().success(true).message(message).data(data).build();
  }

  public static <T> ApiResponse<T> error(String errorCode, String message) {
    return ApiResponse.<T>builder().success(false).errorCode(errorCode).message(message).build();
  }

  public static <T> ApiResponse<T> error(
      String errorCode, String message, List<FieldError> errors) {
    return ApiResponse.<T>builder()
        .success(false)
        .errorCode(errorCode)
        .message(message)
        .errors(errors)
        .build();
  }

  @Data
  @NoArgsConstructor
  @AllArgsConstructor
  public static class FieldError {
    private String field;
    private String message;
  }
}
