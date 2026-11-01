package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.util.Date;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AppConfigResponse {
  private String id;
  private String code;
  /** Masked when {@code sensitive}; secrets are never sent to the browser. */
  private String description;
  private boolean sensitive;
  /** Required by the system; cannot be deleted. */
  private boolean protectedEntry;
  private Date createDate;
  private Date lastUpdateDate;
  private String lastUpdateUserId;
}
