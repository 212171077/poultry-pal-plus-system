package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Address;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.UserSettings;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.CurrencyPreferenceRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.FarmAddressRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.FarmDetailsUpdateV1Request;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.PasswordChangeRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ProfileUpdateRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserSettingsResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.sync.FarmSnapshot;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserSettingsRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import co.za.hlaluko.dynamics.poultry.pal.sync.UserInfoMapper;
import co.za.hlaluko.dynamics.poultry.pal.utils.FarmAddresses;
import co.za.hlaluko.dynamics.poultry.pal.utils.ValidationUtil;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AccountSettingsService {
  private static final int MAX_ADDRESSES = 10;
  private final UserRepository userRepository;
  private final FarmRepository farmRepository;
  private final UserSettingsRepository userSettingsRepository;
  private final PasswordEncoder passwordEncoder;
  private final AuthenticationManager authenticationManager;

  public AccountSettingsService(
      UserRepository userRepository,
      FarmRepository farmRepository,
      UserSettingsRepository userSettingsRepository,
      PasswordEncoder passwordEncoder,
      AuthenticationManager authenticationManager) {
    this.userRepository = userRepository;
    this.farmRepository = farmRepository;
    this.userSettingsRepository = userSettingsRepository;
    this.passwordEncoder = passwordEncoder;
    this.authenticationManager = authenticationManager;
  }

  public UserInfoResponse updateProfile(UserDetailsImpl actor, ProfileUpdateRequest request) {
    User user = requireCurrentUser(actor);
    userRepository
        .findByEmail(request.getEmail())
        .filter(existing -> !existing.getId().equals(user.getId()))
        .ifPresent(existing -> {
          throw ApiException.conflict("Email is already in use");
        });
    user.setName(request.getName().trim());
    user.setSurname(request.getSurname().trim());
    user.setEmail(request.getEmail().trim());
    user.setPhoneNumber(request.getPhoneNumber().trim());
    User saved = userRepository.save(user);
    List<Coop> coops = farmRepository.findById(user.getFarmId()).map(Farm::getCoops).orElse(List.of());
    return UserInfoMapper.toResponse(saved, coops);
  }

  public void changePassword(UserDetailsImpl actor, PasswordChangeRequest request) {
    User user = requireCurrentUser(actor);
    authenticationManager.authenticate(
        new UsernamePasswordAuthenticationToken(user.getEmail(), request.getCurrentPassword()));
    if (!ValidationUtil.isValidPassword(request.getNewPassword())) {
      throw ApiException.badRequest("New password does not meet the password requirements");
    }
    user.setPassword(passwordEncoder.encode(request.getNewPassword()));
    userRepository.save(user);
  }

  public FarmSnapshot updateFarmDetails(
      UserDetailsImpl actor, FarmDetailsUpdateV1Request request) {
    requireManager(actor);
    Farm farm = requireFarm(actor);
    farm.setFarmName(request.getFarmName().trim());
    // Address fields are optional: clients that manage addresses separately only send the name.
    if (request.getAddressLine1() != null
        || request.getAddressLine2() != null
        || request.getState() != null
        || request.getCity() != null
        || request.getPostalCode() != null
        || request.getCountry() != null) {
      FarmAddresses.updatePrimary(
          farm,
          trimToNull(request.getAddressLine1()),
          trimToNull(request.getAddressLine2()),
          trimToNull(request.getCity()),
          trimToNull(request.getState()),
          trimToNull(request.getPostalCode()),
          trimToNull(request.getCountry()));
    }
    return saveFarm(actor, farm);
  }

  public FarmSnapshot addAddress(UserDetailsImpl actor, FarmAddressRequest request) {
    requireManager(actor);
    Farm farm = requireFarm(actor);
    List<Address> addresses = new ArrayList<>(FarmAddresses.list(farm));
    if (addresses.size() >= MAX_ADDRESSES) {
      throw ApiException.badRequest("A farm can have at most " + MAX_ADDRESSES + " addresses");
    }
    addresses.add(toAddress(null, request));
    FarmAddresses.replace(farm, addresses);
    return saveFarm(actor, farm);
  }

  public FarmSnapshot updateAddress(
      UserDetailsImpl actor, String addressId, FarmAddressRequest request) {
    requireManager(actor);
    Farm farm = requireFarm(actor);
    List<Address> addresses = new ArrayList<>(FarmAddresses.list(farm));
    int index = indexOf(addresses, addressId);
    addresses.set(index, toAddress(addresses.get(index).getId(), request));
    FarmAddresses.replace(farm, addresses);
    return saveFarm(actor, farm);
  }

  public FarmSnapshot deleteAddress(UserDetailsImpl actor, String addressId) {
    requireManager(actor);
    Farm farm = requireFarm(actor);
    List<Address> addresses = new ArrayList<>(FarmAddresses.list(farm));
    addresses.remove(indexOf(addresses, addressId));
    FarmAddresses.replace(farm, addresses);
    return saveFarm(actor, farm);
  }

  private FarmSnapshot saveFarm(UserDetailsImpl actor, Farm farm) {
    farm.setUpdatedByUserId(actor.getId());
    farm.setUpdatedAt(new java.util.Date());
    Farm saved = farmRepository.save(farm);
    return FarmSnapshot.builder()
        .id(saved.getId())
        .farmName(saved.getFarmName())
        .address(FarmAddresses.primary(saved))
        .addresses(FarmAddresses.list(saved))
        .createdDate(saved.getCreatedDate())
        .updatedAt(saved.getUpdatedAt())
        .version(saved.getDetailsVersion() == null ? 0 : saved.getDetailsVersion())
        .build();
  }

  private static int indexOf(List<Address> addresses, String addressId) {
    for (int i = 0; i < addresses.size(); i++) {
      if (Objects.equals(addresses.get(i).getId(), addressId)) return i;
    }
    throw ApiException.notFound("Address not found");
  }

  private static Address toAddress(String id, FarmAddressRequest request) {
    return Address.builder()
        .id(id)
        .label(trimToNull(request.getLabel()))
        .addressLine1(trimToNull(request.getAddressLine1()))
        .addressLine2(trimToNull(request.getAddressLine2()))
        .city(trimToNull(request.getCity()))
        .state(trimToNull(request.getState()))
        .postalCode(trimToNull(request.getPostalCode()))
        .country(trimToNull(request.getCountry()))
        .build();
  }

  public UserSettingsResponse updateCurrency(
      UserDetailsImpl actor, CurrencyPreferenceRequest request) {
    User user = requireCurrentUser(actor);
    if (user.getFarmId() == null || user.getFarmId().isBlank()) {
      throw ApiException.forbidden("User is not linked to a farm");
    }
    if (!farmRepository.existsById(user.getFarmId())) {
      throw ApiException.notFound("Farm not found");
    }
    UserSettings settings =
        userSettingsRepository
            .findByUserIdAndFarmId(user.getId(), user.getFarmId())
            .orElseGet(
                () ->
                    UserSettings.builder()
                        .userId(user.getId())
                        .farmId(user.getFarmId())
                        .build());
    settings.setCurrency(request.getCurrency().trim().toUpperCase());
    UserSettings saved = userSettingsRepository.save(settings);
    return new UserSettingsResponse(
        saved.getId(),
        saved.getUserId(),
        saved.getFarmId(),
        saved.getCurrency(),
        saved.getAutoCreateReminders(),
        saved.getSalesAlerts(),
        saved.getMortalityAlerts(),
        saved.getExpenseAlerts(),
        saved.getDailyReminders());
  }

  private User requireCurrentUser(UserDetailsImpl actor) {
    if (actor == null || actor.getId() == null) {
      throw ApiException.unauthorized("Authentication required");
    }
    return userRepository
        .findById(actor.getId())
        .filter(user -> !user.isRemoved())
        .orElseThrow(() -> ApiException.unauthorized("Authentication required"));
  }

  private Farm requireFarm(UserDetailsImpl actor) {
    if (actor.getFarmId() == null || actor.getFarmId().isBlank()) {
      throw ApiException.forbidden("User is not linked to a farm");
    }
    return farmRepository
        .findById(actor.getFarmId())
        .orElseThrow(() -> ApiException.notFound("Farm not found"));
  }

  private void requireManager(UserDetailsImpl actor) {
    boolean canManage =
        actor != null
            && (actor.isFarmOwner()
                || actor.getAuthorities().stream()
                    .anyMatch(
                        authority ->
                            Objects.equals(authority.getAuthority(), ERole.ROLE_FARM_MANAGER.name())
                                || Objects.equals(
                                    authority.getAuthority(), ERole.ROLE_ADMIN.name())));
    if (!canManage) throw ApiException.forbidden("Farm manager permission required");
  }

  private static String trimToNull(String value) {
    return value == null || value.isBlank() ? null : value.trim();
  }
}
