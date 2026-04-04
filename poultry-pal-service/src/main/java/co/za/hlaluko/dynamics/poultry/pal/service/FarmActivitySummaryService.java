package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.mail.Email;
import co.za.hlaluko.dynamics.poultry.pal.mail.EmailSender;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Sale;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Mortality;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Expense;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.EggPackagingRecord;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.utils.ConstantUtil;
import lombok.AllArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.text.SimpleDateFormat;
import java.util.*;

@AllArgsConstructor
@Service
public class FarmActivitySummaryService {

    private final FarmRepository farmRepository;
    private final EmailSender emailSender;
    private final UserRepository userRepository;

    private static final String LI_END = "</li>";
    private static final String RECORDED_BY = "<br><em>Recorded by: ";
    private static final String EM_END = "</em>";

    @Scheduled(cron = "0 0 6 * * *") // every day at 6 AM
    public void sendDailyActivitySummaries() {
        Date today = truncateTime(new Date());
        List<Farm> farmList = farmRepository.findAll();

        for (Farm farm : farmList) {
            Map<String, List<Object>> coopActivities = aggregateActivitiesForFarm(farm, today);
            if (coopActivities.isEmpty()) continue;

            String emailContent = buildSummaryEmail(farm, coopActivities, today);
            User farmOwner = userRepository.findByFarmIdAndFarmOwner(farm.getId(),true);
            List<String> toEmails = new ArrayList<>();
            toEmails.add(farmOwner.getEmail());

            Email email = new Email();
            email.setFrom(ConstantUtil.NO_REPLY_EMAIL);
            email.setTo(toEmails.toArray(new String[0]));
            email.setSubject("Poultry Pal Plus – Daily Farm Activity Summary (" + formatDate(today) + ")");
            email.setContent(emailContent);
            emailSender.saveEmail(email);

        }
    }

    private Map<String, List<Object>> aggregateActivitiesForFarm(Farm farm, Date date) {
        Map<String, List<Object>> coopActivities = new HashMap<>();
        List<Coop> coops = farm.getCoops();
        if (coops == null) return coopActivities;
        for (Coop coop : coops) {
            List<Object> activities = new ArrayList<>();
            activities.addAll(getSalesForDay(coop, date));
            activities.addAll(getExpensesForDay(coop, date));
            activities.addAll(getMortalitiesForDay(coop, date));
            activities.addAll(getEggPackagingRecordsForDay(coop, date));
            // ...add more activity types as needed...
            if (!activities.isEmpty()) {
                coopActivities.put(coop.getCoopName(), activities);
            }
        }
        return coopActivities;
    }

    private List<Sale> getSalesForDay(Coop coop, Date date) {
        List<Sale> salesForDay = new ArrayList<>();
        if (coop.getSales() != null) {
            for (Sale sale : coop.getSales()) {
                if (isSameDay(sale.getCreatedDate(), date)) {
                    salesForDay.add(sale);
                }
            }
        }
        return salesForDay;
    }

    private List<Expense> getExpensesForDay(Coop coop, Date date) {
        List<Expense> expensesForDay = new ArrayList<>();
        if (coop.getExpenses() != null) {
            for (Expense expense : coop.getExpenses()) {
                if (isSameDay(expense.getCreatedDate(), date)) {
                    expensesForDay.add(expense);
                }
            }
        }
        return expensesForDay;
    }

    private List<Mortality> getMortalitiesForDay(Coop coop, Date date) {
        List<Mortality> mortalitiesForDay = new ArrayList<>();
        if (coop.getMortalities() != null) {
            for (Mortality mortality : coop.getMortalities()) {
                if (isSameDay(mortality.getDateOccurred(), date)) {
                    mortalitiesForDay.add(mortality);
                }
            }
        }
        return mortalitiesForDay;
    }

    private List<EggPackagingRecord> getEggPackagingRecordsForDay(Coop coop, Date date) {
        List<EggPackagingRecord> eggRecordsForDay = new ArrayList<>();
        if (coop.getEggPackagingRecords() != null) {
            for (EggPackagingRecord eggRecord : coop.getEggPackagingRecords()) {
                if (isSameDay(eggRecord.getCreatedDate(), date)) {
                    eggRecordsForDay.add(eggRecord);
                }
            }
        }
        return eggRecordsForDay;
    }

    private String buildSummaryEmail(Farm farm, Map<String, List<Object>> coopActivities, Date date) {
        StringBuilder sb = new StringBuilder();
        sb.append("<p>Hello, <strong>").append(farm.getFarmName()).append("</strong>!</p>");
        sb.append("<p>Activities for <strong>").append(formatDate(date)).append("</strong></p><hr>");

        SummaryTotals totals = calculateSummaryTotals(coopActivities);
        sb.append("<p><strong>Summary:</strong></p><ul>");
        sb.append("<li>Sales: R").append(String.format("%.2f", totals.salesTotal)).append(LI_END);
        sb.append("<li>Expenses: R").append(String.format("%.2f", totals.expenseTotal)).append(LI_END);
        sb.append("<li>Mortalities: ").append(totals.mortalityCount).append(LI_END);
        sb.append("<li>Eggs Packaged: ").append(totals.eggCount).append(LI_END);
        sb.append("</ul><hr>");
        sb.append("<p><strong>Detailed Breakdown:</strong></p>");
        for (Map.Entry<String, List<Object>> entry : coopActivities.entrySet()) {
            sb.append("<p><u>Coop: ").append(entry.getKey()).append("</u></p><ul>");
            for (Object activity : entry.getValue()) {
                sb.append("<li>").append(formatActivityDetail(activity)).append(LI_END);
            }
            sb.append("</ul>");
        }
        sb.append("<hr><p>Thank you for keeping your records up to date!<br>Stay productive with Poultry Pal Plus.</p>");
        return sb.toString();
    }

    private SummaryTotals calculateSummaryTotals(Map<String, List<Object>> coopActivities) {
        double salesTotal = sumSales(coopActivities);
        double expenseTotal = sumExpenses(coopActivities);
        int mortalityCount = sumMortalities(coopActivities);
        int eggCount = sumEggs(coopActivities);
        return new SummaryTotals(salesTotal, expenseTotal, mortalityCount, eggCount);
    }

    private double sumSales(Map<String, List<Object>> coopActivities) {
        double total = 0;
        for (List<Object> activities : coopActivities.values()) {
            for (Object activity : activities) {
                if (activity instanceof Sale sale && sale.getTotalSaleAmount() != null) {
                    total += sale.getTotalSaleAmount();
                }
            }
        }
        return total;
    }

    private double sumExpenses(Map<String, List<Object>> coopActivities) {
        double total = 0;
        for (List<Object> activities : coopActivities.values()) {
            for (Object activity : activities) {
                if (activity instanceof Expense expense && expense.getAmount() != null) {
                    total += expense.getAmount();
                }
            }
        }
        return total;
    }

    private int sumMortalities(Map<String, List<Object>> coopActivities) {
        int total = 0;
        for (List<Object> activities : coopActivities.values()) {
            for (Object activity : activities) {
                if (activity instanceof Mortality mortality) {
                    total += mortality.getNumberOfDeaths();
                }
            }
        }
        return total;
    }

    private int sumEggs(Map<String, List<Object>> coopActivities) {
        int total = 0;
        for (List<Object> activities : coopActivities.values()) {
            for (Object activity : activities) {
                if (activity instanceof EggPackagingRecord eggRecord) {
                    total += eggRecord.getTotalEggs();
                }
            }
        }
        return total;
    }

    private String formatActivityDetail(Object activity) {
        StringBuilder sb = new StringBuilder();
        switch (activity) {
            case Sale sale -> sb.append("<strong>Sale:</strong> Amount: R").append(String.format("%.2f", sale.getTotalSaleAmount()))
                .append(", Buyer: ").append(sale.getBuyerName())
                .append(", Dozens Sold: ").append(sale.getNumberOfDozensSold())
                .append(", Chickens Sold: ").append(sale.getNumberOfChickensSold())
                .append(", Payment Status: ").append(sale.getPaymentStatus())
                .append(RECORDED_BY).append(sale.getRecordedBy())
                .append(" at ").append(formatDateTime(sale.getSaleDate())).append(EM_END);
            case Expense expense -> sb.append("<strong>Expense:</strong> Amount: R").append(String.format("%.2f", expense.getAmount()))
                .append(", Type: ").append(expense.getExpenseType())
                .append(", Info: ").append(expense.getAdditionalInfo())
                .append(RECORDED_BY).append(expense.getRecordedBy())
                .append(" at ").append(formatDateTime(expense.getCreatedDate())).append(EM_END);
            case Mortality mortality -> sb.append("<strong>Mortality:</strong> Deaths: ").append(mortality.getNumberOfDeaths())
                .append(", Reason: ").append(mortality.getReason())
                .append(RECORDED_BY).append(mortality.getRecordedBy())
                .append(" at ").append(formatDateTime(mortality.getDateOccurred())).append(EM_END);
            case EggPackagingRecord eggRecord -> sb.append("<strong>Egg Packaging:</strong> Eggs: ").append(eggRecord.getTotalEggs())
                .append(", Size: ").append(eggRecord.getEggSize())
                .append(", Box: ").append(eggRecord.getBoxSize())
                .append(", Boxes: ").append(eggRecord.getNumberOfBoxes())
                .append(RECORDED_BY).append(eggRecord.getUserId())
                .append(" at ").append(formatDateTime(eggRecord.getCreatedDate())).append(EM_END);
            default -> sb.append(activity);
        }
        return sb.toString();
    }

    private static class SummaryTotals {
        double salesTotal;
        double expenseTotal;
        int mortalityCount;
        int eggCount;
        SummaryTotals(double salesTotal, double expenseTotal, int mortalityCount, int eggCount) {
            this.salesTotal = salesTotal;
            this.expenseTotal = expenseTotal;
            this.mortalityCount = mortalityCount;
            this.eggCount = eggCount;
        }
    }

    private String formatDateTime(Date date) {
        if (date == null) return "N/A";
        return new SimpleDateFormat("HH:mm, dd MMM yyyy").format(date);
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
