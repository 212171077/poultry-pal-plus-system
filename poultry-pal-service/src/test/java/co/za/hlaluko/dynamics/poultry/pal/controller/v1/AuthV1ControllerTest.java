package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.RefreshToken;
import co.za.hlaluko.dynamics.poultry.pal.repository.RefreshTokenRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.jwt.JwtUtils;
import jakarta.servlet.http.Cookie;
import java.util.Date;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

class AuthV1ControllerTest extends V1TestSupport {

  @Test
  @DisplayName("signin sets HttpOnly access and refresh cookies and returns the user envelope")
  void signinSetsCookies() throws Exception {
    Session session = newOwnerSession();

    assertThat(session.user().get("farmOwner").asBoolean()).isTrue();
    assertThat(session.user().has("password")).isFalse();
    Cookie access = session.cookie("poultry-pal");
    Cookie refresh = session.cookie("poultry-pal-refresh");
    assertThat(access).isNotNull();
    assertThat(access.isHttpOnly()).isTrue();
    assertThat(access.getPath()).isEqualTo("/api");
    assertThat(refresh).isNotNull();
    assertThat(refresh.isHttpOnly()).isTrue();
    assertThat(refresh.getPath()).isEqualTo("/api/v1/auth");
  }

  @Test
  @DisplayName("signin without rememberMe issues a session-only refresh cookie that stays so on refresh")
  void signinWithoutRememberMe() throws Exception {
    String email = signupOwner();
    MvcResult result =
        mvc.perform(
                post("/api/v1/auth/signin")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        mapper.writeValueAsString(
                            Map.of("username", email, "password", PASSWORD, "rememberMe", false))))
            .andExpect(status().isOk())
            .andReturn();
    Cookie refresh = result.getResponse().getCookie("poultry-pal-refresh");
    assertThat(refresh).isNotNull();
    assertThat(refresh.getMaxAge()).isNegative();

    MvcResult rotated =
        mvc.perform(post("/api/v1/auth/refresh").cookie(refresh))
            .andExpect(status().isOk())
            .andReturn();
    assertThat(rotated.getResponse().getCookie("poultry-pal-refresh").getMaxAge()).isNegative();

    Session remembered = newOwnerSession();
    assertThat(remembered.cookie("poultry-pal-refresh").getMaxAge()).isPositive();
  }

  @Test
  @DisplayName("signin with bad credentials returns 401 INVALID_CREDENTIALS envelope")
  void signinBadCredentials() throws Exception {
    String email = signupOwner();
    mvc.perform(
            post("/api/v1/auth/signin")
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("username", email, "password", "nope"))))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.success").value(false))
        .andExpect(jsonPath("$.errorCode").value("INVALID_CREDENTIALS"));
  }

  @Test
  @DisplayName("signup with an existing email returns 409 CONFLICT")
  void signupDuplicateEmail() throws Exception {
    String email = signupOwner();
    Map<String, String> body =
        Map.of(
            "name", "Another", "surname", "Owner", "email", email, "phoneNumber", "0720000000",
            "password", PASSWORD, "farmName", "Other Farm");
    mvc.perform(
            post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(body)))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("CONFLICT"));
  }

  @Test
  @DisplayName("signup with missing fields returns 400 VALIDATION_ERROR with field errors")
  void signupValidation() throws Exception {
    mvc.perform(post("/api/v1/auth/signup").contentType(MediaType.APPLICATION_JSON).content("{}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
        .andExpect(jsonPath("$.errors").isArray());
  }

  @Test
  @DisplayName("me returns the current user; unauthenticated v1 calls get a 401 envelope")
  void meAndUnauthenticated() throws Exception {
    Session session = newOwnerSession();
    mvc.perform(get("/api/v1/auth/me").cookie(accessCookie(session)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.id").value(session.userId()));

    mvc.perform(get("/api/v1/auth/me"))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.success").value(false))
        .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));
  }

  @Test
  @DisplayName("a refresh token cannot be used as an access token")
  void refreshTokenIsNotAnAccessToken() throws Exception {
    Session session = newOwnerSession();
    Cookie forged = new Cookie("poultry-pal", session.cookie("poultry-pal-refresh").getValue());
    mvc.perform(get("/api/v1/auth/me").cookie(forged)).andExpect(status().isUnauthorized());
  }

  @Test
  @DisplayName("refresh rotates tokens; replaying an old token after the grace window revokes all")
  void refreshRotationAndReuseDetection() throws Exception {
    Session session = newOwnerSession();
    Cookie original = session.cookie("poultry-pal-refresh");

    MvcResult first =
        mvc.perform(post("/api/v1/auth/refresh").cookie(original))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.id").value(session.userId()))
            .andReturn();
    Cookie rotated = first.getResponse().getCookie("poultry-pal-refresh");
    assertThat(rotated).isNotNull();
    assertThat(rotated.getValue()).isNotEqualTo(original.getValue());

    // Within the grace window a concurrent replay still succeeds (multiple tabs).
    mvc.perform(post("/api/v1/auth/refresh").cookie(original)).andExpect(status().isOk());

    // Simulate the grace window having passed, then replay the old token.
    String originalId = jwtUtils.parseClaims(original.getValue()).getId();
    RefreshToken stored = refreshTokenRepository.findById(originalId).orElseThrow();
    stored.setRevokedAt(new Date(System.currentTimeMillis() - 120_000));
    refreshTokenRepository.save(stored);

    mvc.perform(post("/api/v1/auth/refresh").cookie(original))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

    // The whole token family is revoked, so the rotated token no longer works either.
    mvc.perform(post("/api/v1/auth/refresh").cookie(rotated)).andExpect(status().isUnauthorized());
  }

  @Test
  @DisplayName("logout revokes the refresh token and clears both cookies")
  void logout() throws Exception {
    Session session = newOwnerSession();
    Cookie refresh = session.cookie("poultry-pal-refresh");

    MvcResult result =
        mvc.perform(post("/api/v1/auth/logout").cookie(refresh))
            .andExpect(status().isOk())
            .andReturn();
    assertThat(result.getResponse().getCookie("poultry-pal").getMaxAge()).isZero();
    assertThat(result.getResponse().getCookie("poultry-pal-refresh").getMaxAge()).isZero();

    mvc.perform(post("/api/v1/auth/refresh").cookie(refresh)).andExpect(status().isUnauthorized());
  }

  @Test
  @DisplayName("CORS preflight allows the configured origin with credentials")
  void corsPreflight() throws Exception {
    mvc.perform(
            options("/api/v1/sync/push")
                .header(HttpHeaders.ORIGIN, "http://localhost:4200")
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST"))
        .andExpect(status().isOk())
        .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "http://localhost:4200"))
        .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS, "true"));

    mvc.perform(
            options("/api/v1/sync/push")
                .header(HttpHeaders.ORIGIN, "https://evil.example.com")
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST"))
        .andExpect(status().isForbidden());
  }

  @Test
  @DisplayName("legacy /api/auth/signin keeps working and its cookie is accepted by v1")
  void legacySigninStillWorks() throws Exception {
    String email = signupOwner();
    MvcResult result =
        mvc.perform(
                post("/api/auth/signin")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        mapper.writeValueAsString(Map.of("username", email, "password", PASSWORD))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.email").value(email))
            .andReturn();
    Cookie legacy = result.getResponse().getCookie("poultry-pal");
    assertThat(legacy).isNotNull();
    mvc.perform(get("/api/v1/auth/me").cookie(legacy)).andExpect(status().isOk());
  }

  @Autowired RefreshTokenRepository refreshTokenRepository;
  @Autowired JwtUtils jwtUtils;
}
