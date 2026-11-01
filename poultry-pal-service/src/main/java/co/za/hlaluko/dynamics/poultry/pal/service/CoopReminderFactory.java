package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.CoopType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Reminder;
import java.util.Date;
import java.util.UUID;
import lombok.AllArgsConstructor;
import org.springframework.stereotype.Component;

/** Builds the vaccine, feed and medicine reminder schedules for a coop. */
@Component
@AllArgsConstructor
public class CoopReminderFactory {
  private final FeedScheduleService feedScheduleService;
  private final MedicineScheduleService medicineScheduleService;
  private final VaccineScheduleService vaccineScheduleService;

  public Reminder buildReminders(
      Date chickenArrivalDate, CoopType coopType, GrowingPhase growingPhase) {
    if (chickenArrivalDate == null) {
      return null;
    }
    Reminder reminder = new Reminder();
    reminder.setId(UUID.randomUUID().toString());
    if (coopType == CoopType.LAYERS) {
      reminder.setVaccines(vaccineScheduleService.generateLayerVaccineSchedule(chickenArrivalDate));
      reminder.setFeeds(
          feedScheduleService.generateLayerFeedSchedule(chickenArrivalDate, growingPhase));
      reminder.setMedicines(
          medicineScheduleService.generateLayerMedicineSchedule(chickenArrivalDate, growingPhase));
    } else {
      reminder.setVaccines(
          vaccineScheduleService.generateBroilerVaccineSchedule(chickenArrivalDate, growingPhase));
      reminder.setFeeds(
          feedScheduleService.generateBroilerFeedSchedule(chickenArrivalDate, growingPhase));
      reminder.setMedicines(
          medicineScheduleService.generateBroilerMedicineSchedule(
              chickenArrivalDate, growingPhase));
    }
    return reminder;
  }
}
