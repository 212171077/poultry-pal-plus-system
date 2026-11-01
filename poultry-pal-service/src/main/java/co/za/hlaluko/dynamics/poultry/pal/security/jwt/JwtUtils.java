package co.za.hlaluko.dynamics.poultry.pal.security.jwt;

import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import java.security.Key;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Date;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Component;
import org.springframework.web.util.WebUtils;

@Component
public class JwtUtils {
  private static final Logger logger = LoggerFactory.getLogger(JwtUtils.class);

  public static final String CLAIM_TYPE = "typ";
  public static final String TYPE_ACCESS = "access";
  public static final String TYPE_REFRESH = "refresh";
  static final String ACCESS_COOKIE_PATH = "/api";
  static final String REFRESH_COOKIE_PATH = "/api/v1/auth";

  @Value("${poultry.pal.app.jwt.secret:}")
  private String jwtSecret;

  /** Lifetime of tokens issued by the legacy /api/auth/signin endpoint (mobile app). */
  @Value("${poultry.pal.app.jwt.expiration.ms:86400000}")
  private long jwtExpirationMs;

  /** Lifetime of access tokens issued by the v1 auth endpoints (web app). */
  @Value("${poultry.pal.app.jwt.access-expiration.ms:3600000}")
  private long accessExpirationMs;

  @Value("${poultry.pal.app.jwt.refresh-expiration.ms:2592000000}")
  private long refreshExpirationMs;

  @Value("${poultry.pal.app.jwt.cookie.name}")
  private String jwtCookie;

  @Value("${poultry.pal.app.jwt.refresh-cookie.name:poultry-pal-refresh}")
  private String refreshCookie;

  @Value("${poultry.pal.app.cookie.secure:false}")
  private boolean cookieSecure;

  @Value("${poultry.pal.app.cookie.same-site:Lax}")
  private String cookieSameSite;

  private Key signingKey;

  @PostConstruct
  void initSigningKey() {
    if (jwtSecret == null || jwtSecret.isBlank()) {
      byte[] random = new byte[64];
      new SecureRandom().nextBytes(random);
      signingKey = Keys.hmacShaKeyFor(random);
      logger.warn(
          "JWT_SECRET is not set: using a random signing key. Tokens will not survive restarts"
              + " and will not work across multiple instances. Set JWT_SECRET in production.");
    } else {
      signingKey = Keys.hmacShaKeyFor(Decoders.BASE64.decode(jwtSecret));
    }
  }

  public String getJwtFromCookies(HttpServletRequest request) {
    return cookieValue(request, jwtCookie);
  }

  public String getRefreshTokenFromCookies(HttpServletRequest request) {
    return cookieValue(request, refreshCookie);
  }

  private static String cookieValue(HttpServletRequest request, String name) {
    Cookie cookie = WebUtils.getCookie(request, name);
    return cookie != null ? cookie.getValue() : null;
  }

  /** Legacy access cookie used by the mobile app. */
  public ResponseCookie generateJwtCookie(UserDetailsImpl userPrincipal) {
    String jwt = generateTokenFromUsername(userPrincipal.getUsername());
    return cookie(jwtCookie, jwt, ACCESS_COOKIE_PATH, Duration.ofMillis(jwtExpirationMs));
  }

  /** Short-lived access cookie for the v1 API. */
  public ResponseCookie generateAccessCookie(String username) {
    String jwt = buildToken(username, TYPE_ACCESS, null, accessExpirationMs);
    return cookie(jwtCookie, jwt, ACCESS_COOKIE_PATH, Duration.ofMillis(accessExpirationMs));
  }

  /** Long-lived refresh cookie, only sent to the v1 auth endpoints. */
  public ResponseCookie generateRefreshCookie(String username, String tokenId) {
    return generateRefreshCookie(username, tokenId, true);
  }

  /**
   * Refresh cookie for the v1 auth endpoints. A non-persistent cookie has no Max-Age, so the
   * browser drops it when it closes ("don't remember me").
   */
  public ResponseCookie generateRefreshCookie(String username, String tokenId, boolean persistent) {
    String jwt = buildToken(username, TYPE_REFRESH, tokenId, refreshExpirationMs);
    Duration maxAge = persistent ? Duration.ofMillis(refreshExpirationMs) : Duration.ofSeconds(-1);
    return cookie(refreshCookie, jwt, REFRESH_COOKIE_PATH, maxAge);
  }

  public ResponseCookie getCleanJwtCookie() {
    return cookie(jwtCookie, "", ACCESS_COOKIE_PATH, Duration.ZERO);
  }

  public ResponseCookie getCleanRefreshCookie() {
    return cookie(refreshCookie, "", REFRESH_COOKIE_PATH, Duration.ZERO);
  }

  public long getRefreshExpirationMs() {
    return refreshExpirationMs;
  }

  private ResponseCookie cookie(String name, String value, String path, Duration maxAge) {
    return ResponseCookie.from(name, value)
        .path(path)
        .maxAge(maxAge)
        .httpOnly(true)
        .secure(cookieSecure)
        .sameSite(cookieSameSite)
        .build();
  }

  public String getUserNameFromJwtToken(String token) {
    return Jwts.parserBuilder()
        .setSigningKey(signingKey)
        .build()
        .parseClaimsJws(token)
        .getBody()
        .getSubject();
  }

  public boolean validateJwtToken(String authToken) {
    return parseClaims(authToken) != null;
  }

  /** Returns the verified claims, or null when the token is invalid or expired. */
  public Claims parseClaims(String token) {
    if (token == null || token.isBlank()) {
      return null;
    }
    try {
      return Jwts.parserBuilder().setSigningKey(signingKey).build().parseClaimsJws(token).getBody();
    } catch (ExpiredJwtException e) {
      logger.debug("JWT token is expired: {}", e.getMessage());
    } catch (JwtException | IllegalArgumentException e) {
      logger.warn("Invalid JWT token: {}", e.getMessage());
    }
    return null;
  }

  /** Tokens without a type claim were issued before refresh tokens existed and are access tokens. */
  public static boolean isAccessToken(Claims claims) {
    Object type = claims.get(CLAIM_TYPE);
    return type == null || TYPE_ACCESS.equals(type);
  }

  public static boolean isRefreshToken(Claims claims) {
    return TYPE_REFRESH.equals(claims.get(CLAIM_TYPE));
  }

  public String generateTokenFromUsername(String username) {
    return buildToken(username, TYPE_ACCESS, null, jwtExpirationMs);
  }

  private String buildToken(String username, String type, String tokenId, long lifetimeMs) {
    Date now = new Date();
    return Jwts.builder()
        .setSubject(username)
        .setId(tokenId)
        .claim(CLAIM_TYPE, type)
        .setIssuedAt(now)
        .setExpiration(new Date(now.getTime() + lifetimeMs))
        .signWith(signingKey, SignatureAlgorithm.HS256)
        .compact();
  }
}
