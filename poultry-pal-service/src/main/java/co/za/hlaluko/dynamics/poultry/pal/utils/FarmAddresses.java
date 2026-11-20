package co.za.hlaluko.dynamics.poultry.pal.utils;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Address;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * A farm can have several addresses ({@link Farm#getAddresses()}); the first one is the primary
 * address, mirrored into {@link Farm#getAddress()} for clients that only know a single address.
 */
public final class FarmAddresses {
  /** Id given to the address of farms that were created before multiple addresses existed. */
  public static final String LEGACY_ID = "primary";

  private FarmAddresses() {}

  /** The farm's addresses, falling back to the legacy single address. Never null. */
  public static List<Address> list(Farm farm) {
    if (farm.getAddresses() != null && !farm.getAddresses().isEmpty()) {
      return farm.getAddresses();
    }
    Address legacy = farm.getAddress();
    if (legacy == null || isBlank(legacy)) {
      return List.of();
    }
    Address copy = copy(legacy);
    if (copy.getId() == null) {
      copy.setId(LEGACY_ID);
    }
    return List.of(copy);
  }

  public static Address primary(Farm farm) {
    List<Address> addresses = list(farm);
    return addresses.isEmpty() ? farm.getAddress() : addresses.get(0);
  }

  /** Replaces all addresses, giving new ones an id and refreshing the legacy primary address. */
  public static void replace(Farm farm, List<Address> addresses) {
    List<Address> normalized = new ArrayList<>();
    for (Address address : addresses) {
      Address entry = copy(address);
      if (entry.getId() == null || entry.getId().isBlank() || LEGACY_ID.equals(entry.getId())) {
        entry.setId(UUID.randomUUID().toString());
      }
      normalized.add(entry);
    }
    farm.setAddresses(normalized);
    farm.setAddress(normalized.isEmpty() ? null : normalized.get(0));
  }

  /** Applies the single-address fields used by older clients to the primary address. */
  public static void updatePrimary(
      Farm farm,
      String line1,
      String line2,
      String city,
      String state,
      String postalCode,
      String country) {
    List<Address> addresses = new ArrayList<>(list(farm));
    Address target;
    if (addresses.isEmpty()) {
      if (line1 == null && line2 == null && city == null && state == null && postalCode == null
          && country == null) {
        return;
      }
      target = new Address();
      addresses.add(target);
    } else {
      target = copy(addresses.get(0));
      addresses.set(0, target);
    }
    target.setAddressLine1(line1);
    target.setAddressLine2(line2);
    target.setCity(city);
    target.setState(state);
    target.setPostalCode(postalCode);
    target.setCountry(country);
    replace(farm, addresses);
  }

  public static Address copy(Address source) {
    return Address.builder()
        .id(source.getId())
        .label(source.getLabel())
        .addressLine1(source.getAddressLine1())
        .addressLine2(source.getAddressLine2())
        .city(source.getCity())
        .state(source.getState())
        .postalCode(source.getPostalCode())
        .country(source.getCountry())
        .build();
  }

  private static boolean isBlank(Address address) {
    return address.getAddressLine1() == null
        && address.getAddressLine2() == null
        && address.getCity() == null
        && address.getState() == null
        && address.getPostalCode() == null
        && address.getCountry() == null;
  }
}
