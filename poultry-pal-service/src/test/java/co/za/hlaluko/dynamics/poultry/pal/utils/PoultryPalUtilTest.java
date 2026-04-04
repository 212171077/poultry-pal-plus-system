package co.za.hlaluko.dynamics.poultry.pal.utils;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

class PoultryPalUtilTest {

  @Test
  void generatePassword() {
    for (int i = 0; i < 10; i++) {
      String password = PoultryPalUtil.generatePassword();
      Assertions.assertTrue(password.matches("[a-zA-Z0-9]{10}"));
    }
  }
}
