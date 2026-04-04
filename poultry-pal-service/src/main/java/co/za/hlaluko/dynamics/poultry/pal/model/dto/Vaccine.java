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
public class Vaccine {
  private String id;
  private String vaccineName;
  private String recommendedAge;
  private String purpose;
  private String administrationMethod;
  private String notes;
  private Date dueDate;
  private Date doneDate;
  private boolean done;
  private String action;
  private String actionComment;
  private String updatedByUserId;
}
