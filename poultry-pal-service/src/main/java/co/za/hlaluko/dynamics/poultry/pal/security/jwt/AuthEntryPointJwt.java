package co.za.hlaluko.dynamics.poultry.pal.security.jwt;

import co.za.hlaluko.dynamics.poultry.pal.exception.ErrorCodes;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

@Component
public class AuthEntryPointJwt implements AuthenticationEntryPoint {

  private static final Logger logger = LoggerFactory.getLogger(AuthEntryPointJwt.class);
  private static final ObjectMapper MAPPER = new ObjectMapper();

  @Override
  public void commence(
      HttpServletRequest request,
      HttpServletResponse response,
      AuthenticationException authException)
      throws IOException, ServletException {
    logger.error("Unauthorized error: {}", authException.getMessage());

    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);

    if (isV1(request)) {
      MAPPER.writeValue(
          response.getOutputStream(),
          ApiResponse.error(ErrorCodes.UNAUTHORIZED, "Authentication required"));
      return;
    }

    final Map<String, Object> body = new HashMap<>();
    body.put("status", HttpServletResponse.SC_UNAUTHORIZED);
    body.put("error", "Unauthorized");
    body.put("message", authException.getMessage());
    body.put("path", request.getServletPath());
    MAPPER.writeValue(response.getOutputStream(), body);
  }

  public static boolean isV1(HttpServletRequest request) {
    String uri = request.getRequestURI();
    if (uri == null) {
      return false;
    }
    String contextPath = request.getContextPath();
    String path =
        contextPath != null && !contextPath.isEmpty() && uri.startsWith(contextPath)
            ? uri.substring(contextPath.length())
            : uri;
    return path.startsWith("/api/v1/");
  }
}
