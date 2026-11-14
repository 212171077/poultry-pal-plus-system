package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ReminderStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionReminder;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ProductionReminderRepository extends MongoRepository<ProductionReminder, String> {
  Optional<ProductionReminder> findByIdAndFarmId(String id, String farmId);

  List<ProductionReminder> findByFarmIdAndSourceTypeAndSourceId(
      String farmId, String sourceType, String sourceId);

  List<ProductionReminder> findByFarmIdAndStatusOrderByDueDateAsc(
      String farmId, ReminderStatus status, Pageable pageable);
}
