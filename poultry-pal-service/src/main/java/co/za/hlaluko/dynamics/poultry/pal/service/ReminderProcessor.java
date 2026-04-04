package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Feed;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Medicine;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Reminder;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Vaccine;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import org.springframework.stereotype.Service;

@Service
public class ReminderProcessor {

  public Map<String, List<Map<String, Object>>> processReminders(Reminder reminder) {
    List<Map<String, Object>> overdueTasks = new ArrayList<>();
    List<Map<String, Object>> upcomingReminders = new ArrayList<>();
    LocalDate today = LocalDate.now();

    DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    if (reminder != null) {
      // Process vaccines
      for (Vaccine vaccine : reminder.getVaccines()) {

        if (!vaccine.isDone() && vaccine.getDueDate() != null) {
          LocalDate dueDate =
              vaccine
                  .getDueDate()
                  .toInstant()
                  .atZone(java.time.ZoneId.systemDefault())
                  .toLocalDate();

          Map<String, Object> details = new HashMap<>();
          details.put("id", vaccine.getId());
          details.put("vaccineName", vaccine.getVaccineName());
          details.put("recommendedAge", vaccine.getRecommendedAge());
          details.put("purpose", vaccine.getPurpose());
          details.put("administrationMethod", vaccine.getAdministrationMethod());
          details.put("notes", vaccine.getNotes());
          details.put("dueDate", dueDate.format(formatter));

          Map<String, Object> task = new HashMap<>();
          task.put("type", "Vaccine");
          task.put("icon", "\uD83D\uDC89");
          task.put("details", details);

          if (dueDate.isBefore(today)) {
            overdueTasks.add(task);
          } else if (dueDate.isAfter(today)) {
            upcomingReminders.add(task);
          }
        }
      }

      // Process feeds
      for (Feed feed : reminder.getFeeds()) {
        LocalDate dueDate =
            feed.getDueDate().toInstant().atZone(java.time.ZoneId.systemDefault()).toLocalDate();

        if (!feed.isDone()) {
          Map<String, Object> details = new HashMap<>();
          details.put("id", feed.getId());
          details.put("feedingStartDay", feed.getAgeStartInDays());
          details.put("feedingEndDay", feed.getAgeEndInDays());
          details.put("feedType", feed.getFeedType());
          details.put("purpose", feed.getPurpose());
          details.put("notes", feed.getNotes());
          details.put("dueDate", dueDate.format(formatter));
          details.put("TargetBodyWeight", feed.getKgBodyWeightTarget()+"Kg");

          Map<String, Object> task = new HashMap<>();
          task.put("type", "Feed");
          task.put("icon", "\uD83C\uDF3E");
          task.put("details", details);

          if (dueDate.isBefore(today)) {
            overdueTasks.add(task);
          } else if (dueDate.isAfter(today)) {
            upcomingReminders.add(task);
          }
        }
      }

      // Process medicines
      for (Medicine medicine : reminder.getMedicines()) {

        LocalDate dueDate =
            medicine
                .getDueDate()
                .toInstant()
                .atZone(java.time.ZoneId.systemDefault())
                .toLocalDate();

        if (!medicine.isDone()) {
          Map<String, Object> details = new HashMap<>();
          details.put("id", medicine.getId());
          details.put("administrationStartDay", medicine.getAgeStartInDays());
          details.put("administrationEndDay", medicine.getAgeEndInDays());
          details.put("medicineName", medicine.getMedicineName());
          details.put("purpose", medicine.getPurpose());
          details.put("dosage", medicine.getDosage());
          details.put("administrationMethod", medicine.getAdministrationMethod());
          details.put("frequency", medicine.getFrequency());
          details.put("notes", medicine.getNotes());
          details.put("dueDate", dueDate.format(formatter));

          Map<String, Object> task = new HashMap<>();
          task.put("type", "Medicine");
          task.put("icon", "\uD83D\uDC8A");
          task.put("details", details);

          if (dueDate.isBefore(today)) {
            overdueTasks.add(task);
          } else if (dueDate.isAfter(today)) {
            upcomingReminders.add(task);
          }
        }
      }
    }

    // Sort overdueTasks and upcomingReminders by due date
    Comparator<Map<String, Object>> dueDateComparator =
        Comparator.comparing(
            task -> {
              Map<String, Object> details = (Map<String, Object>) task.get("details");
              String dueDateString = (String) details.get("dueDate");
              return LocalDate.parse(dueDateString, formatter);
            });

    overdueTasks.sort(dueDateComparator);
    upcomingReminders.sort(dueDateComparator);

    Map<String, List<Map<String, Object>>> result = new HashMap<>();
    result.put("overdueTasks", overdueTasks);
    result.put("upcomingReminders", upcomingReminders);
    return result;
  }
}
