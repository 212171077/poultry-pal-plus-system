package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionEquipment;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionSettings;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.ProductionSettingsRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ProductionSettingsResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionEquipmentRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.ProductionSettingsRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.math.BigDecimal;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class ProductionSettingsService {
  static final String DEFAULT_TIME_ZONE = "Africa/Johannesburg";

  private final ProductionAccessService accessService;
  private final ProductionSettingsRepository settingsRepository;
  private final ProductionEquipmentRepository equipmentRepository;
  private final ProductionReminderService reminderService;

  public ProductionSettingsResponse get(UserDetailsImpl actor) {
    return toResponse(ensureInitialised(accessService.requireManage(actor), actor.getId()));
  }

  public ProductionSettingsResponse update(UserDetailsImpl actor, ProductionSettingsRequest request) {
    String farmId = accessService.requireManage(actor);
    validate(request);
    ProductionSettings settings = ensureInitialised(farmId, actor.getId());
    settings.setTimeZone(request.getTimeZone().trim());
    settings.setIncubationDays(request.getIncubationDays());
    settings.setTransferDay(request.getTransferDay());
    settings.setBroodingDays(request.getBroodingDays());
    settings.setExpectedHatchRate(scale(request.getExpectedHatchRate()));
    settings.setExpectedMortalityRate(scale(request.getExpectedMortalityRate()));
    settings.setDefaultGrowOutDays(request.getDefaultGrowOutDays());
    settings.setSupplierLeadTimeDays(request.getSupplierLeadTimeDays());
    settings.setUpdatedAt(Instant.now());
    settings.setUpdatedBy(actor.getId());
    if (request.getReminderRules() != null) {
      settings.setReminderRules(normaliseRules(request.getReminderRules()));
    }
    settings.setVersion(request.getVersion());
    try {
      ProductionSettings saved = settingsRepository.save(settings);
      if (request.getReminderRules() != null) {
        reminderService.reconcileFarm(farmId, ProductionReminderService.effectiveRules(saved));
      }
      return toResponse(saved);
    } catch (OptimisticLockingFailureException e) {
      throw ApiException.conflict("Settings were changed by someone else. Reload and try again.");
    }
  }

  /** Creates the farm's settings and default equipment the first time production is opened. */
  ProductionSettings ensureInitialised(String farmId, String actorId) {
    var existing = settingsRepository.findByFarmId(farmId);
    if (existing.isPresent()) {
      return existing.get();
    }
    // Concurrent first requests must wait for the winner to finish seeding the equipment.
    synchronized (farmId.intern()) {
      return initialise(farmId, actorId);
    }
  }

  private ProductionSettings initialise(String farmId, String actorId) {
    return settingsRepository
        .findByFarmId(farmId)
        .orElseGet(
            () -> {
              Instant now = Instant.now();
              try {
                ProductionSettings created =
                    settingsRepository.save(
                        ProductionSettings.builder()
                            .farmId(farmId)
                            .timeZone(DEFAULT_TIME_ZONE)
                            .incubationDays(21)
                            .transferDay(18)
                            .broodingDays(0)
                            .expectedHatchRate(new BigDecimal("0.8000"))
                            .expectedMortalityRate(new BigDecimal("0.0500"))
                            .defaultGrowOutDays(42)
                            .createdAt(now)
                            .updatedAt(now)
                            .createdBy(actorId)
                            .build());
                seedEquipment(farmId, actorId, now);
                return created;
              } catch (DuplicateKeyException e) {
                return settingsRepository.findByFarmId(farmId).orElseThrow();
              }
            });
  }

  private void seedEquipment(String farmId, String actorId, Instant now) {
    equipmentRepository.saveAll(
        java.util.List.of(
            seed(farmId, actorId, now, EquipmentType.INCUBATOR, "Incubator", 2000, null),
            seed(farmId, actorId, now, EquipmentType.HATCHER, "Hatcher", 400, 3),
            seed(farmId, actorId, now, EquipmentType.CHICKEN_HOUSE, "Chicken house", 800, null)));
  }

  private ProductionEquipment seed(
      String farmId,
      String actorId,
      Instant now,
      EquipmentType type,
      String name,
      int capacity,
      Integer occupancyDays) {
    return ProductionEquipment.builder()
        .farmId(farmId)
        .type(type)
        .name(name)
        .capacity(capacity)
        .enabled(true)
        .hatcherOccupancyDays(occupancyDays)
        .createdAt(now)
        .updatedAt(now)
        .createdBy(actorId)
        .updatedBy(actorId)
        .build();
  }

  private java.util.List<co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderRule> normaliseRules(
      java.util.List<co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderRule> rules) {
    java.util.Set<String> keys = new java.util.HashSet<>();
    java.util.List<co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderRule> result =
        new java.util.ArrayList<>();
    int custom = 1;
    for (var rule : rules) {
      String key = rule.getKey() == null ? "" : rule.getKey().trim();
      if (key.isEmpty()) {
        do {
          key = "CUSTOM-" + custom++;
        } while (keys.contains(key));
      }
      if (!keys.add(key)) throw ApiException.badRequest("Reminder rule keys must be unique");
      result.add(
          co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderRule.builder()
              .key(key)
              .taskType(rule.getTaskType())
              .anchor(rule.getAnchor())
              .offsetDays(rule.getOffsetDays())
              .title(rule.getTitle().trim())
              .enabled(rule.isEnabled())
              .build());
    }
    return result;
  }

  private void validate(ProductionSettingsRequest request) {
    try {
      ZoneId.of(request.getTimeZone().trim());
    } catch (DateTimeException e) {
      throw ApiException.badRequest("Time zone is not a valid region ID");
    }
    if (request.getTransferDay() >= request.getIncubationDays()) {
      throw ApiException.badRequest("Transfer day must be before the hatch day");
    }
  }

  private BigDecimal scale(BigDecimal value) {
    return value.setScale(4, java.math.RoundingMode.HALF_UP);
  }

  private ProductionSettingsResponse toResponse(ProductionSettings s) {
    return ProductionSettingsResponse.builder()
        .id(s.getId())
        .farmId(s.getFarmId())
        .timeZone(s.getTimeZone())
        .incubationDays(s.getIncubationDays())
        .transferDay(s.getTransferDay())
        .broodingDays(s.getBroodingDays())
        .expectedHatchRate(s.getExpectedHatchRate())
        .expectedMortalityRate(s.getExpectedMortalityRate())
        .defaultGrowOutDays(s.getDefaultGrowOutDays())
        .supplierLeadTimeDays(s.getSupplierLeadTimeDays())
        .reminderRules(ProductionReminderService.effectiveRules(s))
        .estimatesOnly(s.getUpdatedBy() == null)
        .updatedAt(s.getUpdatedAt())
        .version(s.getVersion())
        .build();
  }
}
