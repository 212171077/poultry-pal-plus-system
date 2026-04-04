package co.za.hlaluko.dynamics.poultry.pal.model.dto;

import java.util.Date;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class Feed {
  private String id;
  private int ageStartInDays;
  private int ageEndInDays;
  private String feedType;
  private String purpose;
  private String notes;
  private Date dueDate;
  private Date doneDate;
  private boolean done;
  private String action;
  private String actionComment;
  private String updatedByUserId;
  private double kgBodyWeightTarget;
}
