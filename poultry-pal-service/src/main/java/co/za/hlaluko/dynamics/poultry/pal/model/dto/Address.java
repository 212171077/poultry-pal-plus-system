package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class Address {
  /** Stable identifier so a single address can be updated or deleted. */
  private String id;
  private String label;
  private String addressLine1;
  private String addressLine2;
  private String state;
  private String city;
  private String postalCode;
  private String country;
}
