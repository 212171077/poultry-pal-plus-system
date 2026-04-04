package co.za.hlaluko.dynamics.poultry.pal.utils;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.CoopType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.Random;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;

@NoArgsConstructor(access = AccessLevel.PRIVATE)
public class PoultryPalUtil {
  static Random random = new Random();

  public static String generatePassword() {
    String chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    int length = 10;
    StringBuilder password = new StringBuilder(length);
    for (int i = 0; i < length; i++) {
      int index = random.nextInt(chars.length());
      password.append(chars.charAt(index));
    }

    return password.toString();
  }

  public static Date addDays(Date date, int days) {
    java.util.Calendar calendar = java.util.Calendar.getInstance();
    calendar.setTime(date);
    calendar.add(java.util.Calendar.DAY_OF_YEAR, days);
    return calendar.getTime();
  }

  // Method to determine the chicken phase based on the arrival date
  public static GrowingPhase getChickenPhase(Date chickenArrivalDate, CoopType coopType) {
    // Default brooding and growing phases in weeks - for broilers
    long broodingPhaseWeeks = 3;
    long growingPhaseWeeks = 6;

    // Adjust for Layers
    if (coopType == CoopType.LAYERS) {
      broodingPhaseWeeks = 6;
      growingPhaseWeeks = 12;
    }

    LocalDate currentDate = LocalDate.now();
    LocalDate arrivalDate =
        chickenArrivalDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();

    long weeksBetween = ChronoUnit.WEEKS.between(arrivalDate, currentDate);

    if (weeksBetween < broodingPhaseWeeks) {
      return GrowingPhase.BROODING_PHASE;
    } else if (weeksBetween < growingPhaseWeeks + broodingPhaseWeeks) {
      return GrowingPhase.GROWING_REARING_PHASE;
    } else {
      return GrowingPhase.PRODUCTION_FINISHING_PHASE;
    }
  }
}
