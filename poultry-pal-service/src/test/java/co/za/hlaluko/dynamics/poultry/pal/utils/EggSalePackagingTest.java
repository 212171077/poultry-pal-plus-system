package co.za.hlaluko.dynamics.poultry.pal.utils;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class EggSalePackagingTest {

  @Test
  void mapsCodesToEggsPerUnit() {
    assertEquals(60, EggSalePackaging.fromCode("TRAY_60").getEggsPerUnit());
    assertEquals(30, EggSalePackaging.fromCode("tray_30").getEggsPerUnit());
    assertEquals(360, EggSalePackaging.fromCode(" BOX_360 ").getEggsPerUnit());
    assertEquals(1, EggSalePackaging.fromCode("SINGLE").getEggsPerUnit());
  }

  @Test
  void rejectsMissingOrUnknownCodes() {
    assertThrows(IllegalArgumentException.class, () -> EggSalePackaging.fromCode(null));
    assertThrows(IllegalArgumentException.class, () -> EggSalePackaging.fromCode("PALLET"));
  }
}
