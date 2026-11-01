package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.exception.ErrorCodes;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.RefreshToken;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ApprovalStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.LoginRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.SignupRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.MessageResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.RefreshTokenRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.jwt.JwtUtils;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import co.za.hlaluko.dynamics.poultry.pal.sync.UserInfoMapper;
import co.za.hlaluko.dynamics.poultry.pal.utils.exception.PoultryPalException;
import io.jsonwebtoken.Claims;
import java.util.Date;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

/**
 * Cookie-based authentication for the web client: a short-lived access cookie plus a rotating,
 * server-tracked refresh cookie. Legacy /api/auth endpoints used by the mobile app are untouched.
 */
@Service
@RequiredArgsConstructor
public class AuthV1Service {
  private static final Logger logger = LogManager.getLogger(AuthV1Service.class);

  /** A just-rotated refresh token may be replayed briefly (e.g. two tabs refreshing at once). */
  static final long ROTATION_GRACE_MS = 30_000;

  private final AuthenticationManager authenticationManager;
  private final AuthControllerService legacyAuthService;
  private final UserRepository userRepository;
  private final FarmRepository farmRepository;
  private final RefreshTokenRepository refreshTokenRepository;
  private final JwtUtils jwtUtils;

  public record AuthResult(UserInfoResponse user, List<ResponseCookie> cookies) {}

  public AuthResult signin(LoginRequest request) {
    Authentication authentication =
        authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword()));
    UserDetailsImpl principal = (UserDetailsImpl) authentication.getPrincipal();
    User user = loadActiveUser(principal.getId());
    if (user == null) {
      throw new BadCredentialsException("Bad credentials");
    }
    return issueTokens(user, UUID.randomUUID().toString(), request.getRememberMe() != Boolean.FALSE);
  }

  public void signup(SignupRequest request) {
    ResponseEntity<Object> result;
    try {
      result = legacyAuthService.signup(request);
    } catch (PoultryPalException e) {
      throw new ApiException(
          HttpStatus.INTERNAL_SERVER_ERROR, ErrorCodes.INTERNAL_ERROR, "Unable to register user");
    }
    if (!result.getStatusCode().is2xxSuccessful()) {
      String message =
          result.getBody() instanceof MessageResponse body
              ? body.getMessage()
              : "Unable to register user";
      throw ApiException.conflict(message.replaceFirst("^Error: ", ""));
    }
  }

  public AuthResult refresh(String refreshJwt) {
    Claims claims = jwtUtils.parseClaims(refreshJwt);
    if (claims == null || !JwtUtils.isRefreshToken(claims) || claims.getId() == null) {
      throw ApiException.unauthorized("Session expired. Please sign in again.");
    }
    RefreshToken stored = refreshTokenRepository.findById(claims.getId()).orElse(null);
    if (stored == null) {
      throw ApiException.unauthorized("Session expired. Please sign in again.");
    }
    User user = loadActiveUser(stored.getUserId());
    if (user == null || !user.getEmail().equalsIgnoreCase(claims.getSubject())) {
      revokeAll(stored.getUserId());
      throw ApiException.unauthorized("Session expired. Please sign in again.");
    }
    if (stored.isRevoked()) {
      if (!withinRotationGrace(stored)) {
        logger.warn("Refresh token reuse detected for user {}; revoking all sessions", user.getId());
        revokeAll(user.getId());
        throw ApiException.unauthorized("Session expired. Please sign in again.");
      }
    }
    String newTokenId = UUID.randomUUID().toString();
    AuthResult result = issueTokens(user, newTokenId, stored.isPersistentSession());
    if (!stored.isRevoked()) {
      stored.setRevoked(true);
      stored.setRevokedAt(new Date());
      stored.setReplacedBy(newTokenId);
      refreshTokenRepository.save(stored);
    }
    return result;
  }

  public List<ResponseCookie> logout(String refreshJwt) {
    Claims claims = jwtUtils.parseClaims(refreshJwt);
    if (claims != null && JwtUtils.isRefreshToken(claims) && claims.getId() != null) {
      refreshTokenRepository
          .findById(claims.getId())
          .ifPresent(
              token -> {
                token.setRevoked(true);
                token.setRevokedAt(new Date());
                refreshTokenRepository.save(token);
              });
    }
    return List.of(jwtUtils.getCleanJwtCookie(), jwtUtils.getCleanRefreshCookie());
  }

  public void validateEmailChangeSession(UserDetailsImpl actor, String refreshJwt) {
    requireRefreshForEmailChange(actor, refreshJwt);
  }

  public List<ResponseCookie> renewAfterEmailChange(
      UserDetailsImpl actor, String refreshJwt) {
    RefreshToken current = requireRefreshForEmailChange(actor, refreshJwt);
    User user = loadActiveUser(actor.getId());
    if (user == null) {
      throw ApiException.unauthorized("Authentication required");
    }
    revokeAll(user.getId());
    return issueTokens(user, UUID.randomUUID().toString(), current.isPersistentSession()).cookies();
  }

  public UserInfoResponse me(UserDetailsImpl principal) {
    if (principal == null) {
      throw ApiException.unauthorized("Authentication required");
    }
    User user = loadActiveUser(principal.getId());
    if (user == null) {
      throw ApiException.unauthorized("Authentication required");
    }
    return toResponse(user);
  }

  private AuthResult issueTokens(User user, String tokenId, boolean persistent) {
    Date now = new Date();
    refreshTokenRepository.save(
        RefreshToken.builder()
            .id(tokenId)
            .userId(user.getId())
            .createdAt(now)
            .expiresAt(new Date(now.getTime() + jwtUtils.getRefreshExpirationMs()))
            .revoked(false)
            .persistent(persistent)
            .build());
    List<ResponseCookie> cookies =
        List.of(
            jwtUtils.generateAccessCookie(user.getEmail()),
            jwtUtils.generateRefreshCookie(user.getEmail(), tokenId, persistent));
    return new AuthResult(toResponse(user), cookies);
  }

  private static boolean withinRotationGrace(RefreshToken token) {
    return token.getReplacedBy() != null
        && token.getRevokedAt() != null
        && System.currentTimeMillis() - token.getRevokedAt().getTime() <= ROTATION_GRACE_MS;
  }

  private void revokeAll(String userId) {
    if (userId == null) {
      return;
    }
    List<RefreshToken> active = refreshTokenRepository.findByUserIdAndRevokedFalse(userId);
    Date now = new Date();
    active.forEach(
        token -> {
          token.setRevoked(true);
          token.setRevokedAt(now);
        });
    refreshTokenRepository.saveAll(active);
  }

  private RefreshToken requireRefreshForEmailChange(
      UserDetailsImpl actor, String refreshJwt) {
    Claims claims = jwtUtils.parseClaims(refreshJwt);
    if (actor == null
        || claims == null
        || !JwtUtils.isRefreshToken(claims)
        || claims.getId() == null
        || !actor.getUsername().equals(claims.getSubject())) {
      throw ApiException.unauthorized("Please sign in again before changing your email address");
    }
    RefreshToken stored = refreshTokenRepository.findById(claims.getId()).orElse(null);
    if (stored == null || stored.isRevoked() || !actor.getId().equals(stored.getUserId())) {
      throw ApiException.unauthorized("Please sign in again before changing your email address");
    }
    return stored;
  }

  private User loadActiveUser(String userId) {
    if (userId == null) {
      return null;
    }
    return userRepository.findById(userId).filter(user -> !user.isRemoved())
        .filter(
            user ->
                user.getApprovalStatus() == null
                    || user.getApprovalStatus() == ApprovalStatus.APPROVED).orElse(null);
  }

  private UserInfoResponse toResponse(User user) {
    List<Coop> coops =
        user.getFarmId() == null
            ? List.of()
            : farmRepository.findById(user.getFarmId()).map(Farm::getCoops).orElse(List.of());
    return UserInfoMapper.toResponse(user, coops);
  }
}
