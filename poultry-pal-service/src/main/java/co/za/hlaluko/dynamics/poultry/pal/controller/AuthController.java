package co.za.hlaluko.dynamics.poultry.pal.controller;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.LoginRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.SignupRequest;
import co.za.hlaluko.dynamics.poultry.pal.service.AuthControllerService;
import co.za.hlaluko.dynamics.poultry.pal.utils.exception.PoultryPalException;
import jakarta.validation.Valid;
import lombok.AllArgsConstructor;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@AllArgsConstructor
@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*", maxAge = 3600)
public class AuthController {

  private static final Logger logger = LogManager.getLogger(AuthController.class);
  private AuthControllerService authControllerService;

  @PostMapping("/signin")
  public ResponseEntity<Object> authenticateUser(@Valid @RequestBody LoginRequest loginRequest) throws PoultryPalException {
    logger.info("Authenticating user: {}", loginRequest.getUsername());
    return authControllerService.authenticateUser(loginRequest);
  }

  @PostMapping("/signup")
  public ResponseEntity<Object> signup(@Valid @RequestBody SignupRequest request) throws PoultryPalException {
    logger.info(
        "Registering user: [Name: {}, Surname: {}, Email: {}, Phone Number: {}, Farm Name: {} ]",
        request.getName(),
        request.getSurname(),
        request.getEmail(),
        request.getPhoneNumber(),
        request.getFarmName());
    return authControllerService.signup(request);
  }
}
