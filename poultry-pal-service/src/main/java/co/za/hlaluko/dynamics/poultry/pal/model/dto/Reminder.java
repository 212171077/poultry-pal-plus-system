package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.List;
import java.util.Map;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class Reminder {
  private String id;
  private List<Vaccine> vaccines;
  private List<Feed> feeds;
  private List<Medicine> medicines;
  private List<Map<String, Object>> overdueTasks;
  private List<Map<String, Object>> upcomingReminders;
}
