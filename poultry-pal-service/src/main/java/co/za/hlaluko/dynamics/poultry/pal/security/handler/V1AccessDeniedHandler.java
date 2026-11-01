package co.za.hlaluko.dynamics.poultry.pal.security.handler;

import co.za.hlaluko.dynamics.poultry.pal.exception.ErrorCodes;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.jwt.AuthEntryPointJwt;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.access.AccessDeniedHandlerImpl;
import org.springframework.stereotype.Component;

/** Returns the v1 envelope for 403s on /api/v1; legacy paths keep Spring's default behaviour. */
@Component
public class V1AccessDeniedHandler implements AccessDeniedHandler {
  private static final ObjectMapper MAPPER = new ObjectMapper();
  private final AccessDeniedHandler legacy = new AccessDeniedHandlerImpl();

  @Override
  public void handle(
      HttpServletRequest request,
      HttpServletResponse response,
      AccessDeniedException accessDeniedException)
      throws IOException, ServletException {
    if (!AuthEntryPointJwt.isV1(request)) {
      legacy.handle(request, response, accessDeniedException);
      return;
    }
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.setStatus(HttpServletResponse.SC_FORBIDDEN);
    MAPPER.writeValue(
        response.getOutputStream(), ApiResponse.error(ErrorCodes.FORBIDDEN, "Access denied"));
  }
}
