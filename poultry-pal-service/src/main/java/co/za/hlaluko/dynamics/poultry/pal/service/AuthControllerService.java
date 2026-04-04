package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.LoginRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.SignupRequest;
import co.za.hlaluko.dynamics.poultry.pal.utils.exception.PoultryPalException;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestBody;

public interface AuthControllerService {
     ResponseEntity<Object> authenticateUser(@Valid @RequestBody LoginRequest loginRequest) throws PoultryPalException;
     ResponseEntity<Object> signup(@Valid @RequestBody SignupRequest request) throws PoultryPalException;
}
