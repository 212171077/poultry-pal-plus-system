package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.mail.Email;
import co.za.hlaluko.dynamics.poultry.pal.mail.EmailSender;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Feed;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Medicine;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Reminder;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.UserSettings;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserSettingsRepository;
import co.za.hlaluko.dynamics.poultry.pal.utils.ConstantUtil;
import java.text.SimpleDateFormat;
import java.util.*;
import lombok.AllArgsConstructor;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@AllArgsConstructor
@Service
public class ReminderNotificationService {

  private static final Logger logger = LogManager.getLogger(ReminderNotificationService.class);

  private final FarmRepository farmRepository;
  private final EmailSender emailSender;
  private final FarmServiceImpl farmService;
  private final UserRepository userRepository;
  private final UserSettingsRepository userSettingsRepository;

  private static final int DAYS_BEFORE = 2;

  @Scheduled(cron = "0 0 6 * * *") // every day at 7 AM
  public void sendReminders() {
    List<Farm> farmList = farmRepository.findAll();
    Date targetDate = getFutureDate();
    Date today = truncateTime(new Date());

    farmList.forEach(
        farm -> {
          try {
            List<Coop> coops = farm.getCoops();
            if (coops == null || coops.isEmpty()) return;

            List<Coop> coopsWithReminders = farmService.builCoopList(coops);

            StringBuilder messageBody = new StringBuilder();
            boolean hasReminders = false;

            for (Coop coop : coopsWithReminders) {
              Reminder reminder = coop.getReminder();
              if (reminder == null) continue;

              List<Feed> upcomingFeeds = filterFeedsByDate(reminder.getFeeds());
              List<Feed> overdueFeeds = filterOverdueFeeds(reminder.getFeeds(), today);

              List<Medicine> upcomingMeds =
                  filterMedicinesByDate(reminder.getMedicines());
              List<Medicine> overdueMeds = filterOverdueMedicines(reminder.getMedicines(), today);

              if (!upcomingFeeds.isEmpty()
                  || !upcomingMeds.isEmpty()
                  || !overdueFeeds.isEmpty()
                  || !overdueMeds.isEmpty()) {
                hasReminders = true;
                messageBody.append(
                    "<div style='font-family: Arial, sans-serif; font-size: 12px; color: #333;'>");

                messageBody
                    .append("<p><strong>Coop Name:</strong> ")
                    .append(coop.getCoopName())
                    .append("</p>");

                if (!upcomingFeeds.isEmpty()) {
                  messageBody
                      .append("<p><strong>Upcoming Feeds (")
                      .append(formatDate(targetDate))
                      .append("):</strong></p>");
                  messageBody.append("<ul>");
                  for (Feed feed : upcomingFeeds) {
                    messageBody
                        .append("<li>")
                        .append(feed.getFeedType())
                        .append(" (")
                        .append(feed.getPurpose())
                        .append(")")
                        .append("</li>");
                  }
                  messageBody.append("</ul>");
                }

                if (!upcomingMeds.isEmpty()) {
                  messageBody
                      .append("<p><strong>Upcoming Medicines (")
                      .append(formatDate(targetDate))
                      .append("):</strong></p>");
                  messageBody.append("<ul>");
                  for (Medicine med : upcomingMeds) {
                    messageBody
                        .append("<li>")
                        .append(med.getMedicineName())
                        .append(" (")
                        .append(med.getPurpose())
                        .append(", ")
                        .append(med.getAdministrationMethod())
                        .append(")")
                        .append("</li>");
                  }
                  messageBody.append("</ul>");
                }

                if (!overdueFeeds.isEmpty()) {
                  messageBody.append("<p><strong>Overdue Feeds:</strong></p>");
                  messageBody.append("<ul>");
                  for (Feed feed : overdueFeeds) {
                    messageBody
                        .append("<li>")
                        .append(feed.getFeedType())
                        .append(" (Due: ")
                        .append(formatDate(feed.getDueDate()))
                        .append(")")
                        .append("</li>");
                  }
                  messageBody.append("</ul>");
                }

                if (!overdueMeds.isEmpty()) {
                  messageBody.append("<p><strong>Overdue Medicines:</strong></p>");
                  messageBody.append("<ul>");
                  for (Medicine med : overdueMeds) {
                    messageBody
                        .append("<li>")
                        .append(med.getMedicineName())
                        .append(" (Due: ")
                        .append(formatDate(med.getDueDate()))
                        .append(")")
                        .append("</li>");
                  }
                  messageBody.append("</ul>");
                }

                messageBody.append(
                    "<hr style='border: none; border-top: 1px solid #ddd; margin: 20px 0;'>");
                messageBody.append("</div>");
              }
            }

            if (hasReminders) {
              List<User> farmUsers = userRepository.findByFarmId(farm.getId());
              List<String> toEmails = new ArrayList<>();
              farmUsers.forEach(
                  user -> {
                    Optional<UserSettings> userSettings =
                        userSettingsRepository.findByUserIdAndFarmId(user.getId(), farm.getId());
                    if (userSettings.isPresent()
                        && Boolean.TRUE.equals(userSettings.get().getDailyReminders())) {
                      toEmails.add(user.getEmail());
                    }
                  });

              if (!toEmails.isEmpty()) {
                String content =
                    "<p>Hello Farmer,"
                        + ",</p>"
                        + "<p>Here's a quick update on your chicken feed and medicine schedule to help you stay on top of things:</p>"
                        + "<p>"
                        + messageBody
                        + "</p>"
                        + "<p>Please take a moment to prepare what's needed - your birds will thank you!</p>"
                        + "<p>And don't forget to update your coop records using the Poultry Pal mobile app to keep everything on track.</p>";

                Email email = new Email();
                email.setFrom(ConstantUtil.NO_REPLY_EMAIL);
                email.setTo(toEmails.toArray(new String[0]));
                email.setSubject("🐔 Poultry Pal Daily Reminder - " + formatDate(new Date()));
                email.setContent(content);

                emailSender.saveEmail(email);

                logger.info("Reminder email queued to: {}", toEmails);
              } else {
                logger.info(
                    "No user is enabled to receive reminder notifications for farm name: {}",
                    farm.getFarmName());
              }
            }

          } catch (Exception e) {
            logger.error("Error sending reminders for farm: {}", farm.getFarmName(), e);
          }
        });
  }

  private List<Feed> filterFeedsByDate(List<Feed> feeds) {
    if (feeds == null) return Collections.emptyList();
    Date today = truncateTime(new Date());
    Calendar calendar = Calendar.getInstance();
    calendar.setTime(today);
    calendar.add(Calendar.DAY_OF_YEAR, ReminderNotificationService.DAYS_BEFORE);
    Date targetDate = calendar.getTime();

    return feeds.stream()
            .filter(f -> f.getDueDate() != null && !f.isDone() &&
                    !truncateTime(f.getDueDate()).before(today) &&
                    !truncateTime(f.getDueDate()).after(targetDate))
            .toList();
  }

  private List<Feed> filterOverdueFeeds(List<Feed> feeds, Date today) {
    if (feeds == null) return Collections.emptyList();
    return feeds.stream()
        .filter(
            f ->
                f.getDueDate() != null && truncateTime(f.getDueDate()).before(today) && !f.isDone())
        .toList();
  }

  private List<Medicine> filterMedicinesByDate(List<Medicine> meds) {
    if (meds == null) return Collections.emptyList();

    Date today = truncateTime(new Date());
    Calendar calendar = Calendar.getInstance();
    calendar.setTime(today);
    calendar.add(Calendar.DAY_OF_YEAR, ReminderNotificationService.DAYS_BEFORE);
    Date targetDate = calendar.getTime();

    return meds.stream()
            .filter(f -> f.getDueDate() != null && !f.isDone() &&
                    !truncateTime(f.getDueDate()).before(today) &&
                    !truncateTime(f.getDueDate()).after(targetDate))
            .toList();

  }

  private List<Medicine> filterOverdueMedicines(List<Medicine> meds, Date today) {
    if (meds == null) return Collections.emptyList();
    return meds.stream()
        .filter(
            m ->
                m.getDueDate() != null && truncateTime(m.getDueDate()).before(today) && !m.isDone())
        .toList();
  }

  private Date getFutureDate() {
    Calendar calendar = Calendar.getInstance();
    calendar.add(Calendar.DAY_OF_YEAR, ReminderNotificationService.DAYS_BEFORE);
    return truncateTime(calendar.getTime());
  }

  private Date truncateTime(Date date) {
    Calendar cal = Calendar.getInstance();
    cal.setTime(date);
    cal.set(Calendar.HOUR_OF_DAY, 0);
    cal.set(Calendar.MINUTE, 0);
    cal.set(Calendar.SECOND, 0);
    cal.set(Calendar.MILLISECOND, 0);
    return cal.getTime();
  }

  private boolean isSameDay(Date d1, Date d2) {
    return truncateTime(d1).equals(truncateTime(d2));
  }

  private String formatDate(Date date) {
    return new SimpleDateFormat("dd MMM yyyy").format(date);
  }
}
