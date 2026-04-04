package co.za.hlaluko.dynamics.poultry.pal.model.payload.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Date;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class EggPackagingRecordRequest {
    private String userId;
    private String farmId;
    private String coopId;
    private String eggSize;
    private String boxSize;
    private int numberOfBoxes;
    private String additionalInfo;
    private Date createdDate;
}
