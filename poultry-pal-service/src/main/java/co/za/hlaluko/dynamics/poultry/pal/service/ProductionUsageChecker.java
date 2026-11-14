package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionEquipment;
import co.za.hlaluko.dynamics.poultry.pal.repository.HatcherCycleRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.IncubationBatchRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionEquipmentRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionSettingsRepository;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/** Reports current and future incubator and hatcher commitments for capacity changes. */
@Component
@RequiredArgsConstructor
public class ProductionUsageChecker implements EquipmentUsageChecker {
  private final ProductionEquipmentRepository equipmentRepository;
  private final ProductionSettingsRepository settingsRepository;
  private final IncubationService incubationService;

  @Override
  public Usage peakUsage(String farmId, String equipmentId) {
    ProductionEquipment equipment =
        equipmentRepository.findByIdAndFarmIdAndArchivedFalse(equipmentId, farmId).orElse(null);
    if (equipment == null) return null;
    LocalDate today =
        LocalDate.now(
            settingsRepository
                .findByFarmId(farmId)
                .map(s -> ZoneId.of(s.getTimeZone()))
                .orElse(ZoneId.of(ProductionSettingsService.DEFAULT_TIME_ZONE)));
    List<ProductionCapacity.Interval> intervals =
        equipment.getType() == EquipmentType.INCUBATOR
            ? incubationService.incubatorIntervals(farmId, equipmentId, null)
            : equipment.getType() == EquipmentType.HATCHER
                ? incubationService.hatcherIntervals(farmId, equipmentId, java.util.Set.of())
                : List.of();
    List<ProductionCapacity.Interval> current =
        intervals.stream().filter(i -> i.end().isAfter(today)).toList();
    if (current.isEmpty()) return null;
    return new Usage(
        ProductionCapacity.peak(current),
        current.stream().map(ProductionCapacity.Interval::reference).distinct().toList());
  }
}
