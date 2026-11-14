package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** A categorised hatch outcome other than hatched or unhatched, e.g. "Cracked" or "Dead in shell". */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class OutcomeCount {
  @NotBlank @Size(max = 40) private String category;
  @NotNull @Min(0) @Max(1_000_000) private Integer count;
}
