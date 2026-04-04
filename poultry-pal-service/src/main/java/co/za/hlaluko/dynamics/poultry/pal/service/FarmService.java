package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.*;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.MessageResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.ResponseEntity;

public interface FarmService {
  ResponseEntity<Object> updateUser(UpdateUserRequest request);
  ResponseEntity<MessageResponse> activateUser(String userId);
  ResponseEntity<List<UserInfoResponse>> findAllUser();
  ResponseEntity<List<UserInfoResponse>> findInactiveUser();
  ResponseEntity<Object> findFarmById(String farmId);
  ResponseEntity<Object> updateFarmDetails(UpdateFarmRequest request);
  ResponseEntity<Object> updateFarmCoop(UpdateFarmCoopRequest request);
  ResponseEntity<Object> deleteFarmCoop(String farmId,String coopId);
  ResponseEntity<Object> updateMortalities(UpdateMortalityRequest request);
  ResponseEntity<Object> updateSales(UpdateSaleRequest request);
  ResponseEntity<Object> updateExpense(UpdateExpenseRequest request);
  ResponseEntity<Object> addNewBatch(UpdateFarmCoopRequest request);
  ResponseEntity<Object> updateLoginDetails(UpdateLoginDetailsRequest request);
  ResponseEntity<Object> addFarmUser(AddFarmUserRequest request);
  ResponseEntity<Object> updateUserRoles(UserRolesRequest request);
  ResponseEntity<Object> removeUser(@Valid RemoveUserRequest request);
  ResponseEntity<Object> deleteCoopItem(@Valid RemoveCoopIteamRequest request);
  ResponseEntity<Object> updateReminder(@Valid UpdateReminderRequest request);
  ResponseEntity<byte[]> downloadReport(String farmId, String userId);
  ResponseEntity<byte[]> downloadScheduleReport(String farmId, String coopId, String userId);
  ResponseEntity<Object>  sendReportViaEmail(String farmId, String userId);
  ResponseEntity<Object> updateUserSetting(@Valid UserSettingsRequest request);
  ResponseEntity<Object> findUserSetting(String userId, String farmId);
  ResponseEntity<Object> growingPhaseTransition(PhaseTransitionRequest request);
  ResponseEntity<Object> sendScheduleViaEmail(@Valid SendScheduleRequest request);
  ResponseEntity<Object> recordEggPackaging(EggPackagingRecordRequest request);
  ResponseEntity<Object> updateResponsibleUser(AddResponsibleUserRequest request);
}
