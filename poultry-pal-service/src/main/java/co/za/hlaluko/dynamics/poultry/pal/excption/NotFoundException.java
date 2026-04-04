package co.za.hlaluko.dynamics.poultry.pal.excption;

public class NotFoundException extends RuntimeException {
  public NotFoundException(String errorMessage) {
    super(errorMessage);
  }
}
