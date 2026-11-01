package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/** Server-side record of an issued refresh token, keyed by the token's {@code jti}. */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
@Document(collection = "refresh_tokens")
public class RefreshToken {
  @Id private String id;
  private String userId;
  private Date createdAt;
  private Date expiresAt;
  private boolean revoked;
  private Date revokedAt;
  private String replacedBy;

  /** {@code false} for "don't remember me" sessions (session cookie); {@code null} means true. */
  private Boolean persistent;

  public boolean isPersistentSession() {
    return !Boolean.FALSE.equals(persistent);
  }
}
