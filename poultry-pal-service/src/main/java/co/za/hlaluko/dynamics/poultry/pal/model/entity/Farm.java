package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Address;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncTombstone;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Date;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

@Data
@Builder
@AllArgsConstructor
@Document(collection = "farmers")
public class Farm {

  @Id private String id;
  @NotBlank
  @Size(max = 50)
  private String farmName;
  private Address address;
  private List<Coop> coops;
  @NotBlank private Date createdDate;
  @NotBlank private String updatedByUserId;

  /** Optimistic-locking version, incremented on every save. Also the farm-wide sync cursor. */
  @Version private Long version;

  private Date updatedAt;

  /** Farm version at which farm name/address last changed. */
  private Long detailsVersion;

  private List<SyncTombstone> tombstones;

  /** Tombstones with a version at or below this value have been pruned. */
  private Long tombstonesPrunedBefore;
}
