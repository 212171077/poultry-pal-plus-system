package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.utils.FarmAddresses;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Role;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.LoginRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.SignupRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.MessageResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.RoleRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.jwt.JwtUtils;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import co.za.hlaluko.dynamics.poultry.pal.utils.exception.PoultryPalException;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.AllArgsConstructor;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@AllArgsConstructor
public class AuthControllerServiceImpl implements AuthControllerService {
  private static final Logger logger = LogManager.getLogger(AuthControllerServiceImpl.class);
  AuthenticationManager authenticationManager;
  UserRepository userRepository;
  RoleRepository roleRepository;
  PasswordEncoder encoder;
  JwtUtils jwtUtils;
  private FarmRepository farmRepository;
  private AccountApprovalService approvalService;

  @Override
  public ResponseEntity<Object> authenticateUser(LoginRequest loginRequest)
      throws PoultryPalException {
    try {
      Authentication authentication =
          authenticationManager.authenticate(
              new UsernamePasswordAuthenticationToken(
                  loginRequest.getUsername(), loginRequest.getPassword()));

      SecurityContextHolder.getContext().setAuthentication(authentication);

      UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();

      ResponseCookie jwtCookie = jwtUtils.generateJwtCookie(userDetails);

      List<String> roles =
          userDetails.getAuthorities().stream().map(GrantedAuthority::getAuthority).toList();

      UserInfoResponse response =
          UserInfoResponse.builder()
              .id(userDetails.getId())
              .name(userDetails.getName())
              .surname(userDetails.getSurname())
              .phoneNumber(userDetails.getPhoneNumber())
              .farmId(userDetails.getFarmId())
              .isFarmOwner(userDetails.isFarmOwner())
              .isActive(userDetails.isActive())
              .createdDate(userDetails.getCreatedDate())
              .email(userDetails.getEmail())
              .roles(roles)
              .roleFriendlyNames(getRoleFriendlyNames(roles))
              .permissions(userDetails.getPermissions().stream().map(Enum::name).sorted().toList())
              .build();

      return ResponseEntity.ok()
          .header(HttpHeaders.SET_COOKIE, jwtCookie.toString())
          .body(response);

    } catch (Exception e) {
      logger.error("Authentication failed: ", e);
      throw new PoultryPalException(e.getMessage(), e);
    }
  }

  @Override
  public ResponseEntity<Object> signup(SignupRequest request) throws PoultryPalException {
    try {
      if (Boolean.TRUE.equals(userRepository.existsByEmailAndRemoved(request.getEmail(),false))) {
        return ResponseEntity.badRequest()
            .body(new MessageResponse(false, "Error: Email is already in use!"));
      }

      Set<Role> roles = new HashSet<>();

      Role userRole =
          roleRepository
              .findByName(ERole.ROLE_USER)
              .orElseThrow(() -> new RuntimeException("Error: Role is not found."));

      Role farmManagerRole =
              roleRepository
                      .findByName(ERole.ROLE_FARM_MANAGER)
                      .orElseThrow(() -> new RuntimeException("Error: Role is not found."));

      roles.add(userRole);
      roles.add(farmManagerRole);

      Farm farm =
          Farm.builder()
              .farmName(request.getFarmName())
              .createdDate(new Date())
              .build();
      FarmAddresses.updatePrimary(
          farm,
          request.getFarmAddressLine1(),
          request.getFarmAddressLine2(),
          request.getFarmCity(),
          request.getFarmState(),
          request.getFarmPostalCode(),
          request.getFarmCountry());

      farmRepository.save(farm);

      User user =
          User.builder()
              .name(request.getName())
              .surname(request.getSurname())
              .phoneNumber(request.getPhoneNumber())
              .farmId(farm.getId())
              .active(false)
              .email(request.getEmail())
              .password(encoder.encode(request.getPassword()))
              .createdDate(new Date())
              .roles(roles)
              .farmOwner(true)
              .build();

      String approvalToken = approvalService.markPending(user);
      userRepository.save(user);
      approvalService.notifyRegistration(user, request.getFarmName(), approvalToken);

      return ResponseEntity.ok(
          new MessageResponse(
              true,
              "Profile created successfully! Your account is awaiting approval by the administrator."));

    } catch (Exception e) {
      logger.error("Unable to register user: ", e);
      throw new PoultryPalException(e.getMessage(), e);
    }
  }

  public static List<String> getRoleFriendlyNames(List<String> roleNames) {
    return roleNames.stream().map(name -> ERole.valueOf(name).getValue()).toList();
  }
}
