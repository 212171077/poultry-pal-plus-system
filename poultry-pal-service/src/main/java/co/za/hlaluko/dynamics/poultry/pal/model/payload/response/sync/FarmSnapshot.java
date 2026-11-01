package co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Address;
import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Farm details for sync. {@code version} is the details version used for FARM conflicts. */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class FarmSnapshot {
  private String id;
  private String farmName;
  private Address address;
  private Date createdDate;
  private Date updatedAt;
  private long version;
}
