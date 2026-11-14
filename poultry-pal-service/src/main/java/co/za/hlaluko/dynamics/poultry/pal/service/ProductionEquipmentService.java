package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionEquipment;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ProductionEquipmentRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionEquipmentResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionEquipmentRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class ProductionEquipmentService {
  private static final int DEFAULT_HATCHER_OCCUPANCY_DAYS = 3;

  private final ProductionAccessService accessService;
  private final ProductionSettingsService settingsService;
  private final ProductionEquipmentRepository equipmentRepository;
  private final ObjectProvider<EquipmentUsageChecker> usageCheckers;

  public List<ProductionEquipmentResponse> list(UserDetailsImpl actor) {
    String farmId = accessService.requireManage(actor);
    settingsService.ensureInitialised(farmId, actor.getId());
    return equipmentRepository.findByFarmIdAndArchivedFalseOrderByTypeAscNameAsc(farmId).stream()
        .sorted(
            java.util.Comparator.comparing(ProductionEquipment::getType)
                .thenComparing(ProductionEquipment::getName, String.CASE_INSENSITIVE_ORDER))
        .map(this::toResponse)
        .toList();
  }

  public ProductionEquipmentResponse create(
      UserDetailsImpl actor, ProductionEquipmentRequest request) {
    String farmId = accessService.requireManage(actor);
    settingsService.ensureInitialised(farmId, actor.getId());
    if (request.getType() == null) throw ApiException.badRequest("Equipment type is required");
    String name = request.getName().trim();
    requireUniqueName(farmId, request.getType(), name);
    Instant now = Instant.now();
    ProductionEquipment equipment =
        ProductionEquipment.builder()
            .farmId(farmId)
            .type(request.getType())
            .name(name)
            .capacity(request.getCapacity())
            .enabled(request.getEnabled() == null || request.getEnabled())
            .hatcherOccupancyDays(occupancyDays(request.getType(), request.getHatcherOccupancyDays()))
            .notes(blankToNull(request.getNotes()))
            .createdAt(now)
            .updatedAt(now)
            .createdBy(actor.getId())
            .updatedBy(actor.getId())
            .build();
    return toResponse(equipmentRepository.save(equipment));
  }

  public ProductionEquipmentResponse update(
      UserDetailsImpl actor, String id, ProductionEquipmentRequest request) {
    String farmId = accessService.requireManage(actor);
    if (request.getVersion() == null) throw ApiException.badRequest("Version is required");
    ProductionEquipment equipment = require(farmId, id);
    String name = request.getName().trim();
    if (!name.equalsIgnoreCase(equipment.getName())) {
      requireUniqueName(farmId, equipment.getType(), name);
    }
    boolean enabled = request.getEnabled() == null ? equipment.isEnabled() : request.getEnabled();
    int available = enabled ? request.getCapacity() : 0;
    if (available < equipment.getCapacity() || (!enabled && equipment.isEnabled())) {
      requireNoCommittedOverflow(farmId, equipment, available);
    }
    equipment.setName(name);
    equipment.setCapacity(request.getCapacity());
    equipment.setEnabled(enabled);
    equipment.setHatcherOccupancyDays(
        occupancyDays(equipment.getType(), request.getHatcherOccupancyDays()));
    equipment.setNotes(blankToNull(request.getNotes()));
    equipment.setUpdatedAt(Instant.now());
    equipment.setUpdatedBy(actor.getId());
    equipment.setVersion(request.getVersion());
    return save(equipment);
  }

  /** Archives rather than deletes so records that reference the equipment stay valid. */
  public void archive(UserDetailsImpl actor, String id) {
    String farmId = accessService.requireManage(actor);
    ProductionEquipment equipment = require(farmId, id);
    requireNoCommittedOverflow(farmId, equipment, 0);
    equipment.setArchived(true);
    equipment.setEnabled(false);
    equipment.setUpdatedAt(Instant.now());
    equipment.setUpdatedBy(actor.getId());
    save(equipment);
  }

  private ProductionEquipmentResponse save(ProductionEquipment equipment) {
    try {
      return toResponse(equipmentRepository.save(equipment));
    } catch (OptimisticLockingFailureException e) {
      throw ApiException.conflict("Equipment was changed by someone else. Reload and try again.");
    }
  }

  private ProductionEquipment require(String farmId, String id) {
    return equipmentRepository
        .findByIdAndFarmIdAndArchivedFalse(id, farmId)
        .orElseThrow(() -> ApiException.notFound("Equipment not found"));
  }

  private void requireUniqueName(String farmId, EquipmentType type, String name) {
    if (equipmentRepository.existsByFarmIdAndTypeAndNameIgnoreCaseAndArchivedFalse(
        farmId, type, name)) {
      throw ApiException.conflict("Equipment with this name already exists");
    }
  }

  private void requireNoCommittedOverflow(
      String farmId, ProductionEquipment equipment, int newAvailable) {
    usageCheckers.orderedStream().forEach(checker -> {
      EquipmentUsageChecker.Usage usage = checker.peakUsage(farmId, equipment.getId());
      if (usage != null && usage.peakCommitted() > newAvailable) {
        throw ApiException.capacityConflict(
            "Committed production exceeds the new capacity. Resolve the conflicting records first.",
            Map.of(
                "resource", equipment.getId(),
                "requested", usage.peakCommitted(),
                "available", newAvailable,
                "conflictingReferences", usage.references()));
      }
    });
  }

  private Integer occupancyDays(EquipmentType type, Integer requested) {
    if (type != EquipmentType.HATCHER) return null;
    return requested == null ? DEFAULT_HATCHER_OCCUPANCY_DAYS : requested;
  }

  private String blankToNull(String value) {
    return value == null || value.isBlank() ? null : value.trim();
  }

  private ProductionEquipmentResponse toResponse(ProductionEquipment e) {
    return ProductionEquipmentResponse.builder()
        .id(e.getId())
        .farmId(e.getFarmId())
        .type(e.getType())
        .name(e.getName())
        .capacity(e.getCapacity())
        .enabled(e.isEnabled())
        .hatcherOccupancyDays(e.getHatcherOccupancyDays())
        .notes(e.getNotes())
        .updatedAt(e.getUpdatedAt())
        .version(e.getVersion())
        .build();
  }
}
