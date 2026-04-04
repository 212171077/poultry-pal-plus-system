package co.za.hlaluko.dynamics.poultry.pal.controller;

import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.*;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.MessageResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.service.FarmService;
import co.za.hlaluko.dynamics.poultry.pal.service.ReminderNotificationService;
import jakarta.validation.Valid;
import java.util.List;
import lombok.AllArgsConstructor;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@AllArgsConstructor
@RestController
@RequestMapping("/api/farm")
@CrossOrigin(origins = "*", maxAge = 3600)
public class FarmController {

  // TODO PreAuthorize NOT working. Hint check if the role is in the database has ROLE_

  private static final Logger logger = LogManager.getLogger(FarmController.class);
  private FarmService farmService;
  private ReminderNotificationService notificationService;

  @PostMapping("/update-user")
  @PreAuthorize("hasRole('USER')")
  public ResponseEntity<Object> updateUser(@Valid @RequestBody UpdateUserRequest request) {
    logger.info("Update user, FarmID: {}, Name: {}", request.getFarmId(), request.getName());
    return farmService.updateUser(request);
  }

  @PostMapping("/activate-user/{userId}")
  @PreAuthorize("hasRole('ADMIN')")
  public ResponseEntity<MessageResponse> activateUser(@PathVariable String userId) {
    logger.info("Activating user, User ID: {}", userId);
    return farmService.activateUser(userId);
  }

  @GetMapping("find-all-users")
  @PreAuthorize("hasRole('ADMIN')")
  ResponseEntity<List<UserInfoResponse>> findAllUsers() {
    logger.info("find all users....");
    return farmService.findAllUser();
  }

  @GetMapping("find-inactive-users")
  @PreAuthorize("hasRole('ADMIN')")
  ResponseEntity<List<UserInfoResponse>> findInactiveUsers() {
    logger.info("find inactive users....");
    return farmService.findInactiveUser();
  }

  @GetMapping("find-farm-by-id/{farmId}")
  @PreAuthorize(
      "hasRole('USER') or hasRole('FARM_MANAGER') or hasRole('ADMIN') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> findFarmById(@PathVariable String farmId) {
    logger.info("Find farm by Id, FarmId: {}", farmId);
    return farmService.findFarmById(farmId);
  }

  @PostMapping("/update-farm-details")
  @PreAuthorize("hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> updateFarmDetails(@Valid @RequestBody UpdateFarmRequest request) {
    logger.info("Update farm details: {}", request);
    return farmService.updateFarmDetails(request);
  }

  @PostMapping("/update-farm-coop")
  @PreAuthorize("hasRole('USER') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> updateFarmCoop(@Valid @RequestBody UpdateFarmCoopRequest request) {
    logger.info("Update farm coop: {}", request);
    return farmService.updateFarmCoop(request);
  }

  @DeleteMapping("/delete-farm-coop/{farmId}/{coopId}")
  @PreAuthorize("hasRole('USER') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> deleteFarmCoop(@PathVariable String farmId, @PathVariable String coopId) {
    logger.info("delete farm coop, FarmId: {}", farmId);
    return farmService.deleteFarmCoop(farmId, coopId);
  }

  @PostMapping("/update-mortalities")
  @PreAuthorize("hasRole('USER') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> updateMortalities(@Valid @RequestBody UpdateMortalityRequest request) {
    logger.info("Update mortalities: {}", request);
    return farmService.updateMortalities(request);
  }

  @PostMapping("/update-sales")
  @PreAuthorize("hasRole('USER') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> updateSales(@Valid @RequestBody UpdateSaleRequest request) {
    logger.info("Update sales: {}", request);
    return farmService.updateSales(request);
  }

  @PostMapping("/update-expense")
  @PreAuthorize("hasRole('USER') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> updateExpense(@Valid @RequestBody UpdateExpenseRequest request) {
    logger.info("Update expenses: {}", request);
    return farmService.updateExpense(request);
  }

  @PostMapping("/add-new-batch")
  @PreAuthorize("hasRole('USER') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> addNewBatch(@Valid @RequestBody UpdateFarmCoopRequest request) {
    logger.info("Add new batch: {}", request);
    return farmService.addNewBatch(request);
  }

  @PostMapping("/update-login-details")
  @PreAuthorize("hasRole('USER') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> updateLoginDetails(@Valid @RequestBody UpdateLoginDetailsRequest request) {
    logger.info("Update login details: User ID: {}", request.getUserId());
    return farmService.updateLoginDetails(request);
  }

  @PostMapping("/add-farm-user")
  @PreAuthorize("hasRole('USER') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> addFarmUser(@Valid @RequestBody AddFarmUserRequest request) {
    logger.info(
        "Adding Farm User: Farm ID: {}, Name: {}, Surname: {}, Email: {}",
        request.getFarmId(),
        request.getName(),
        request.getSurname(),
        request.getEmail());
    return farmService.addFarmUser(request);
  }

  @PostMapping("/update-user-roles")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> updateUserRoles(@Valid @RequestBody UserRolesRequest request) {
    logger.info(
        "Updating user roles: Farm ID: {}, updatedByUserId: {}, userId: {}, roles: {}",
        request.getFarmId(),
        request.getUpdatedByUserId(),
        request.getUserId(),
        request.getRoles());
    return farmService.updateUserRoles(request);
  }

  @DeleteMapping("/remove-user")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> removeUser(@Valid @RequestBody RemoveUserRequest request) {
    logger.info(
        "Remove User: Farm ID: {}, deletedByUserId: {}, userId: {}",
        request.getFarmId(),
        request.getDeletedByUserId(),
        request.getUserId());

    return farmService.removeUser(request);
  }

  @DeleteMapping("/delete-coop-item")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> deleteCoopItem(@Valid @RequestBody RemoveCoopIteamRequest request) {
    logger.info(
        "Delete coop item: farmId: {}, deletedByUserId: {}, coopId: {}, itemId: {}, itemType: {}",
        request.getFarmId(),
        request.getDeletedByUserId(),
        request.getCoopId(),
        request.getItemId(),
        request.getItemType());

    return farmService.deleteCoopItem(request);
  }

  // TODO unit tests, use updatedByUserId
  @PostMapping("/update-reminder")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> updateReminder(@Valid @RequestBody UpdateReminderRequest request) {
    logger.info(
        "Updating reminder: id: {},farmId: {}, coopId: {} reminderType: {}, action: {}, actionComment: {}, updatedByUserId: {}",
        request.getId(),
        request.getFarmId(),
        request.getCoopId(),
        request.getReminderType(),
        request.getAction(),
        request.getActionComment(),
        request.getUpdatedByUserId());

    return farmService.updateReminder(request);
  }

  // TODO unit tests
  @GetMapping("/download-report/{farmId}/{userId}")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  public ResponseEntity<byte[]> downloadReport(
      @PathVariable String farmId, @PathVariable String userId) {
    logger.info("Downloading farm report, FarmId: {}, UserId: {}", farmId, userId);
    return farmService.downloadReport(farmId, userId);
  }

  // TODO unit tests
  @GetMapping("/download-schedule/{farmId}/{coopId}/{userId}")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  public ResponseEntity<byte[]> downloadScheduleReport(
          @PathVariable String farmId, @PathVariable String coopId, @PathVariable String userId) {
    logger.info("Downloading schedule report, FarmId: {}, CoopId: {}, UserId: {}", farmId, coopId,userId);
    return farmService.downloadScheduleReport(farmId,coopId, userId);
  }

  // TODO unit tests
  @PostMapping("/send-report")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  public ResponseEntity<Object> sendReportViaEmail(@Valid @RequestBody SendReportRequest request) {
    logger.info(
        "Sending farm report via email, FarmId: {}, UserId: {}",
        request.getFarmId(),
        request.getUserId());
    return farmService.sendReportViaEmail(request.getFarmId(), request.getUserId());
  }

  @PostMapping("/send-schedule")
  @PreAuthorize("hasRole('ADMIN') or hasRole('USER')  or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  public ResponseEntity<Object>  sendScheduleViaEmail(@Valid @RequestBody  SendScheduleRequest request) {
    logger.info("Sending schedule via email, FarmId: {}, CoopId: {}, UserId: {}", request.getFarmId(), request.getCoopId(),request.getUserId());
    return farmService.sendScheduleViaEmail(request);
  }

  // TODO unit tests
  @PostMapping("/update-user-setting")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> updateUserSetting(@Valid @RequestBody UserSettingsRequest request) {
    logger.info(
            "Updating user settings: id: {},farmId: {}, userId: {} currency: {}, autoCreateReminders: {}, salesAlerts: {}, mortalityAlerts: {}, dailyReminders: {}, expenseAlerts: {}",
            request.getId(),
            request.getFarmId(),
            request.getUserId(),
            request.getCurrency(),
            request.getAutoCreateReminders(),
            request.getSalesAlerts(),
            request.getMortalityAlerts(),
            request.getDailyReminders(),
            request.getExpenseAlerts());

    return farmService.updateUserSetting(request);
  }

  // TODO unit tests
  @GetMapping("/find-user-setting/{farmId}/{userId}")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  public ResponseEntity<Object> findUserSettings(
          @PathVariable String farmId, @PathVariable String userId) {
    logger.info("Find user settings, FarmId: {}, UserId: {}", farmId, userId);
    return farmService.findUserSetting(userId, farmId);
  }

  // TODO unit tests
  @PostMapping("/growing-phase-transition")
  @PreAuthorize("hasRole('ADMIN') or hasRole('FARM_MANAGER') or hasRole('FARM_WORKER')")
  ResponseEntity<Object> growingPhaseTransition(@Valid @RequestBody PhaseTransitionRequest request) {
    logger.info(
            "Growing phase transition: @NotBlank: {}, farmId: {}, currentCoopId: {} newCoopId: {}, newGrowingPhase: {}",
            request.getUserId(),
            request.getFarmId(),
            request.getCurrentCoopId(),
            request.getNewCoopId(),
            request.getNewGrowingPhase());
    return farmService.growingPhaseTransition(request);
  }

  // TODO unit tests
  @GetMapping("/send-reminders")
  @PreAuthorize("hasRole('ADMIN')")
  public ResponseEntity<Object> sendReminders() {
    notificationService.sendReminders();
    return ResponseEntity.ok().body(new MessageResponse(true, "Reminders sent"));
  }

  // TODO unit tests
  @PostMapping("/record-egg-packaging")
  public ResponseEntity<Object> recordPackaging(
          @RequestBody EggPackagingRecordRequest request) {
    return farmService.recordEggPackaging( request);
  }

  // TODO unit tests
  @PostMapping("/add-responsible-user")
  @PreAuthorize("hasRole('ADMIN')")
  public ResponseEntity<Object> updateResponsibleUser(@Valid @RequestBody AddResponsibleUserRequest request) {
    logger.info("Add responsible user, FarmId: {}, CoopId: {}, UserId: {}", request.getFarmId(), request.getCoopIds(), request.getUserId());
    return farmService.updateResponsibleUser(request);
  }


}



