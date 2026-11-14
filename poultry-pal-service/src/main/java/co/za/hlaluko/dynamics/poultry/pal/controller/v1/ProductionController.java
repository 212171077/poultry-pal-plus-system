package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.BatchStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.HatchResultRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlanCalculation;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.PlanDecisionRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.PlanRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.PlanResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ScheduleSearchRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ScheduleOptionsResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.HatchResultResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.HatchingReportResponse;
import co.za.hlaluko.dynamics.poultry.pal.service.HatchResultService;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.BirdMovementRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.BirdPlacementRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.BirdMovementResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.BirdPlacementResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.HouseOccupancyResponse;
import co.za.hlaluko.dynamics.poultry.pal.service.PlacementService;
import org.springframework.web.bind.annotation.RequestHeader;
import java.time.LocalDate;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.BatchCommandRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.HatcherCycleRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.IncubationBatchRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.HatcherCycleResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.IncubationBatchResponse;
import co.za.hlaluko.dynamics.poultry.pal.service.IncubationService;
import org.springframework.web.bind.annotation.RequestParam;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionReminderResponse;
import co.za.hlaluko.dynamics.poultry.pal.service.ProductionReminderService;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ProductionEquipmentRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ProductionSettingsRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ApiResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionEquipmentResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionSettingsResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionAccessResponse;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.service.ProductionAccessService;
import co.za.hlaluko.dynamics.poultry.pal.service.ProductionEquipmentService;
import co.za.hlaluko.dynamics.poultry.pal.service.ProductionSettingsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/production")
@Tag(name = "Production (v1)", description = "Incubation, hatching and production planning")
public class ProductionController {
  private final ProductionAccessService accessService;
  private final ProductionSettingsService settingsService;
  private final ProductionEquipmentService equipmentService;
  private final IncubationService incubationService;
  private final ProductionReminderService reminderService;
  private final HatchResultService hatchResultService;
  private final PlacementService placementService;
  private final co.za.hlaluko.dynamics.poultry.pal.service.PlanningService planningService;
  private final co.za.hlaluko.dynamics.poultry.pal.service.SchedulingService schedulingService;
  private final co.za.hlaluko.dynamics.poultry.pal.service.ProductionSyncService productionSyncService;

  @GetMapping("/snapshot")
  @Operation(summary = "Everything the production pages read, for offline caching")
  public ResponseEntity<ApiResponse<co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionSnapshotResponse>> snapshot() {
    return ResponseEntity.ok(
        ApiResponse.ok("Snapshot retrieved", productionSyncService.snapshot(SecurityUtils.getCurrentUser())));
  }

  @GetMapping("/access")
  @Operation(summary = "Confirm the caller's production access (403 without PRODUCTION_MANAGE)")
  public ResponseEntity<ApiResponse<ProductionAccessResponse>> access() {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Production access confirmed", accessService.describe(SecurityUtils.getCurrentUser())));
  }

  @GetMapping("/settings")
  @Operation(summary = "Read production assumptions (seeds estimates on first use)")
  public ResponseEntity<ApiResponse<ProductionSettingsResponse>> settings() {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Production settings retrieved",
            settingsService.get(SecurityUtils.getCurrentUser())));
  }

  @PutMapping("/settings")
  @Operation(summary = "Update production assumptions")
  public ResponseEntity<ApiResponse<ProductionSettingsResponse>> updateSettings(
      @Valid @RequestBody ProductionSettingsRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Production settings updated",
            settingsService.update(SecurityUtils.getCurrentUser(), request)));
  }

  @GetMapping("/equipment")
  @Operation(summary = "List the farm's production equipment")
  public ResponseEntity<ApiResponse<List<ProductionEquipmentResponse>>> equipment() {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Equipment retrieved", equipmentService.list(SecurityUtils.getCurrentUser())));
  }

  @PostMapping("/equipment")
  @Operation(summary = "Add production equipment")
  public ResponseEntity<ApiResponse<ProductionEquipmentResponse>> createEquipment(
      @Valid @RequestBody ProductionEquipmentRequest request) {
    return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED)
        .body(
            ApiResponse.ok(
                "Equipment created",
                equipmentService.create(SecurityUtils.getCurrentUser(), request)));
  }

  @PutMapping("/equipment/{id}")
  @Operation(summary = "Update production equipment")
  public ResponseEntity<ApiResponse<ProductionEquipmentResponse>> updateEquipment(
      @PathVariable String id, @Valid @RequestBody ProductionEquipmentRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Equipment updated",
            equipmentService.update(SecurityUtils.getCurrentUser(), id, request)));
  }

  @DeleteMapping("/equipment/{id}")
  @Operation(summary = "Archive production equipment")
  public ResponseEntity<ApiResponse<Void>> archiveEquipment(@PathVariable String id) {
    equipmentService.archive(SecurityUtils.getCurrentUser(), id);
    return ResponseEntity.ok(ApiResponse.ok("Equipment archived", null));
  }

  @GetMapping("/batches")
  @Operation(summary = "List incubation batches (newest first)")
  public ResponseEntity<ApiResponse<List<IncubationBatchResponse>>> batches(
      @RequestParam(required = false) BatchStatus status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "50") int size) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Batches retrieved",
            incubationService.list(SecurityUtils.getCurrentUser(), status, page, size)));
  }

  @PostMapping("/batches")
  @Operation(summary = "Create an incubation batch (validates incubator capacity)")
  public ResponseEntity<ApiResponse<IncubationBatchResponse>> createBatch(
      @Valid @RequestBody IncubationBatchRequest request) {
    return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED)
        .body(
            ApiResponse.ok(
                "Batch created", incubationService.create(SecurityUtils.getCurrentUser(), request)));
  }

  @GetMapping("/batches/{id}")
  @Operation(summary = "Get an incubation batch with its hatcher cycles")
  public ResponseEntity<ApiResponse<IncubationBatchResponse>> batch(@PathVariable String id) {
    return ResponseEntity.ok(
        ApiResponse.ok("Batch retrieved", incubationService.get(SecurityUtils.getCurrentUser(), id)));
  }

  @PutMapping("/batches/{id}")
  @Operation(summary = "Update a planned batch")
  public ResponseEntity<ApiResponse<IncubationBatchResponse>> updateBatch(
      @PathVariable String id, @Valid @RequestBody IncubationBatchRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Batch updated", incubationService.update(SecurityUtils.getCurrentUser(), id, request)));
  }

  @PostMapping("/batches/{id}/start")
  @Operation(summary = "Start incubation (optionally with the actual start date)")
  public ResponseEntity<ApiResponse<IncubationBatchResponse>> startBatch(
      @PathVariable String id, @Valid @RequestBody(required = false) BatchCommandRequest command) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Batch started", incubationService.start(SecurityUtils.getCurrentUser(), id, command)));
  }

  @PostMapping("/batches/{id}/cancel")
  @Operation(summary = "Cancel a batch that has no eggs in a hatcher")
  public ResponseEntity<ApiResponse<IncubationBatchResponse>> cancelBatch(
      @PathVariable String id, @Valid @RequestBody(required = false) BatchCommandRequest command) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Batch cancelled", incubationService.cancel(SecurityUtils.getCurrentUser(), id, command)));
  }

  @GetMapping("/batches/{id}/hatcher-cycles")
  @Operation(summary = "List a batch's hatcher cycles")
  public ResponseEntity<ApiResponse<List<HatcherCycleResponse>>> hatcherCycles(
      @PathVariable String id) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Hatcher cycles retrieved", incubationService.cycles(SecurityUtils.getCurrentUser(), id)));
  }

  @PostMapping("/batches/{id}/hatcher-cycles")
  @Operation(summary = "Reserve hatcher capacity for part or all of a batch")
  public ResponseEntity<ApiResponse<IncubationBatchResponse>> reserveCycle(
      @PathVariable String id, @Valid @RequestBody HatcherCycleRequest request) {
    return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED)
        .body(
            ApiResponse.ok(
                "Hatcher cycle reserved",
                incubationService.reserveCycle(SecurityUtils.getCurrentUser(), id, request)));
  }

  @PostMapping("/hatcher-cycles/{id}/transfer")
  @Operation(summary = "Transfer a reserved lot into the hatcher")
  public ResponseEntity<ApiResponse<IncubationBatchResponse>> transferCycle(
      @PathVariable String id, @Valid @RequestBody(required = false) BatchCommandRequest command) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Eggs transferred",
            incubationService.transferCycle(SecurityUtils.getCurrentUser(), id, command)));
  }

  @PostMapping("/hatcher-cycles/{id}/cancel")
  @Operation(summary = "Cancel a reserved hatcher cycle")
  public ResponseEntity<ApiResponse<IncubationBatchResponse>> cancelCycle(
      @PathVariable String id) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Hatcher cycle cancelled",
            incubationService.cancelCycle(SecurityUtils.getCurrentUser(), id)));
  }

  @GetMapping("/reminders")
  @Operation(summary = "List generated production reminders (OPEN by default, soonest first)")
  public ResponseEntity<ApiResponse<List<ProductionReminderResponse>>> reminders(
      @RequestParam(required = false) ReminderStatus status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "50") int size) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Reminders retrieved",
            reminderService.list(SecurityUtils.getCurrentUser(), status, page, size)));
  }

  @PostMapping("/reminders/{id}/complete")
  @Operation(summary = "Mark a reminder done (idempotent)")
  public ResponseEntity<ApiResponse<ProductionReminderResponse>> completeReminder(
      @PathVariable String id, @Valid @RequestBody(required = false) BatchCommandRequest command) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Reminder completed",
            reminderService.complete(
                SecurityUtils.getCurrentUser(), id, command == null ? null : command.getReason())));
  }

  @GetMapping("/hatcher-cycles/{id}/results")
  @Operation(summary = "Read the hatch result recorded for a cycle")
  public ResponseEntity<ApiResponse<HatchResultResponse>> hatchResult(@PathVariable String id) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Hatch result retrieved", hatchResultService.get(SecurityUtils.getCurrentUser(), id)));
  }

  @PostMapping("/hatcher-cycles/{id}/results")
  @Operation(summary = "Record the hatch result for a cycle (one per cycle)")
  public ResponseEntity<ApiResponse<HatchResultResponse>> recordHatchResult(
      @PathVariable String id, @Valid @RequestBody HatchResultRequest request) {
    return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED)
        .body(
            ApiResponse.ok(
                "Hatch result recorded",
                hatchResultService.record(SecurityUtils.getCurrentUser(), id, request)));
  }

  @PutMapping("/hatcher-cycles/{id}/results")
  @Operation(summary = "Correct a recorded hatch result (audited, requires version)")
  public ResponseEntity<ApiResponse<HatchResultResponse>> editHatchResult(
      @PathVariable String id, @Valid @RequestBody HatchResultRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Hatch result updated",
            hatchResultService.edit(SecurityUtils.getCurrentUser(), id, request)));
  }

  @GetMapping("/reports/hatching")
  @Operation(summary = "Historical hatch performance with summary and monthly trend")
  public ResponseEntity<ApiResponse<HatchingReportResponse>> hatchingReport(
      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
      @RequestParam(required = false) String batchId,
      @RequestParam(required = false) String hatcherId,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "50") int size) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Hatching report retrieved",
            hatchResultService.report(
                SecurityUtils.getCurrentUser(), from, to, batchId, hatcherId, page, size)));
  }

  @GetMapping("/reports/hatching.csv")
  @Operation(summary = "Download the hatching report as CSV")
  public ResponseEntity<String> hatchingReportCsv(
      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
      @RequestParam(required = false) String batchId,
      @RequestParam(required = false) String hatcherId) {
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"hatching-report.csv\"")
        .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
        .body(
            hatchResultService.reportCsv(
                SecurityUtils.getCurrentUser(), from, to, batchId, hatcherId));
  }

  @PostMapping("/plans/calculate")
  @Operation(summary = "Calculate a target-date plan without saving or reserving anything")
  public ResponseEntity<ApiResponse<PlanCalculation>> calculatePlan(@Valid @RequestBody PlanRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok("Plan calculated", planningService.calculate(SecurityUtils.getCurrentUser(), request)));
  }

  @GetMapping("/plans")
  @Operation(summary = "List saved plans")
  public ResponseEntity<ApiResponse<List<PlanResponse>>> plans(
      @RequestParam(defaultValue = "false") boolean openOnly) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Plans retrieved",
            planningService.list(SecurityUtils.getCurrentUser(), openOnly).stream().map(PlanResponse::from).toList()));
  }

  @PostMapping("/plans")
  @Operation(summary = "Save a calculated plan as a draft")
  public ResponseEntity<ApiResponse<PlanResponse>> savePlan(@Valid @RequestBody PlanRequest request) {
    return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED)
        .body(
            ApiResponse.ok(
                "Plan saved", PlanResponse.from(planningService.save(SecurityUtils.getCurrentUser(), request))));
  }

  @GetMapping("/plans/{id}")
  @Operation(summary = "Get a plan")
  public ResponseEntity<ApiResponse<PlanResponse>> plan(@PathVariable String id) {
    return ResponseEntity.ok(
        ApiResponse.ok("Plan retrieved", PlanResponse.from(planningService.get(SecurityUtils.getCurrentUser(), id))));
  }

  @PostMapping("/plans/{id}/commit")
  @Operation(summary = "Revalidate capacity and commit a draft plan")
  public ResponseEntity<ApiResponse<PlanResponse>> commitPlan(
      @PathVariable String id, @Valid @RequestBody(required = false) PlanDecisionRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Plan committed", PlanResponse.from(planningService.commit(SecurityUtils.getCurrentUser(), id, request))));
  }

  @PostMapping("/plans/{id}/recalculate")
  @Operation(summary = "Recalculate a plan; a committed plan that changed is flagged NEEDS_REVIEW")
  public ResponseEntity<ApiResponse<PlanResponse>> recalculatePlan(@PathVariable String id) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Plan recalculated", PlanResponse.from(planningService.recalculate(SecurityUtils.getCurrentUser(), id))));
  }

  @PostMapping("/plans/recalculate")
  @Operation(summary = "Recalculate every open plan")
  public ResponseEntity<ApiResponse<List<PlanResponse>>> recalculatePlans() {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Plans recalculated",
            planningService.recalculateAll(SecurityUtils.getCurrentUser()).stream().map(PlanResponse::from).toList()));
  }

  @PostMapping("/plans/{id}/accept-recalculation")
  @Operation(summary = "Accept the recalculated dates and quantities of a plan under review")
  public ResponseEntity<ApiResponse<PlanResponse>> acceptPlan(
      @PathVariable String id, @Valid @RequestBody(required = false) PlanDecisionRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Recalculation accepted",
            PlanResponse.from(planningService.acceptRecalculation(SecurityUtils.getCurrentUser(), id, request))));
  }

  @PostMapping("/plans/{id}/cancel")
  @Operation(summary = "Cancel an open plan")
  public ResponseEntity<ApiResponse<PlanResponse>> cancelPlan(
      @PathVariable String id, @Valid @RequestBody(required = false) PlanDecisionRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Plan cancelled", PlanResponse.from(planningService.cancel(SecurityUtils.getCurrentUser(), id, request))));
  }

  @PostMapping("/schedule/search")
  @Operation(summary = "Find incubation start dates that fit capacity (reserves nothing)")
  public ResponseEntity<ApiResponse<ScheduleOptionsResponse>> searchSchedule(
      @Valid @RequestBody ScheduleSearchRequest request) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Schedule options calculated",
            schedulingService.search(SecurityUtils.getCurrentUser(), request)));
  }

  @GetMapping("/placements")
  @Operation(summary = "List bird placements with derived remaining counts")
  public ResponseEntity<ApiResponse<List<BirdPlacementResponse>>> placements(
      @RequestParam(required = false) String houseId,
      @RequestParam(defaultValue = "false") boolean activeOnly) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Placements retrieved",
            placementService.list(SecurityUtils.getCurrentUser(), houseId, activeOnly)));
  }

  @PostMapping("/placements")
  @Operation(summary = "Place chicks in a chicken house (capacity checked)")
  public ResponseEntity<ApiResponse<BirdPlacementResponse>> place(
      @Valid @RequestBody BirdPlacementRequest request) {
    return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED)
        .body(
            ApiResponse.ok(
                "Chicks placed", placementService.place(SecurityUtils.getCurrentUser(), request)));
  }

  @GetMapping("/placements/{id}")
  @Operation(summary = "Read a placement with its movement ledger")
  public ResponseEntity<ApiResponse<BirdPlacementResponse>> placement(@PathVariable String id) {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Placement retrieved", placementService.get(SecurityUtils.getCurrentUser(), id)));
  }

  @PostMapping("/placements/{id}/movements")
  @Operation(summary = "Append a mortality, sale, transfer, removal or correction (idempotent with Idempotency-Key)")
  public ResponseEntity<ApiResponse<BirdMovementResponse>> addMovement(
      @PathVariable String id,
      @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
      @Valid @RequestBody BirdMovementRequest request) {
    return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED)
        .body(
            ApiResponse.ok(
                "Movement recorded",
                placementService.addMovement(
                    SecurityUtils.getCurrentUser(), id, request, idempotencyKey)));
  }

  @GetMapping("/occupancy")
  @Operation(summary = "Current occupancy of every chicken house, derived from the ledger")
  public ResponseEntity<ApiResponse<List<HouseOccupancyResponse>>> occupancy() {
    return ResponseEntity.ok(
        ApiResponse.ok(
            "Occupancy retrieved", placementService.occupancy(SecurityUtils.getCurrentUser())));
  }
}
