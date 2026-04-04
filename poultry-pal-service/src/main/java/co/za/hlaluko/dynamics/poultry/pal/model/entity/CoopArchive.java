package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import jakarta.validation.constraints.NotBlank;
import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Data
@Builder
@AllArgsConstructor
@Document(collection = "coop_archives")
public class CoopArchive {
  @Id private String id;
  @NotBlank private String farmId;
  @NotBlank private Coop coop;
  @NotBlank private Date createdDate;
}
