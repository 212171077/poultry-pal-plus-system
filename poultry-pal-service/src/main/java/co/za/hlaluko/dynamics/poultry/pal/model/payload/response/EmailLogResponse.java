package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.util.Date;
import lombok.Builder;
import lombok.Data;

/** An outgoing email's delivery outcome. The body is deliberately left out (may hold codes). */
@Data
@Builder
public class EmailLogResponse {
  private String id;
  private Date sentAt;
  private String toEmail;
  private String subject;
  private boolean success;
  private String errorMessage;
}
