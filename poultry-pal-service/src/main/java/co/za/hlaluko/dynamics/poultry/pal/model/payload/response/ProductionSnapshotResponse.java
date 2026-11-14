package co.za.hlaluko.dynamics.poultry.pal.model.payload.response;

import java.time.Instant;
import java.util.List;

/** Everything the production pages read, so clients can cache it for offline use. */
public record ProductionSnapshotResponse(
    Instant generatedAt,
    ProductionSettingsResponse settings,
    List<ProductionEquipmentResponse> equipment,
    List<IncubationBatchResponse> batches,
    List<ProductionReminderResponse> reminders,
    List<BirdPlacementResponse> placements,
    List<HouseOccupancyResponse> occupancy,
    List<PlanResponse> plans) {}
