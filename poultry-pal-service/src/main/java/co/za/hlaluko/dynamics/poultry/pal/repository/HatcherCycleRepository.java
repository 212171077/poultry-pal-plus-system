package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.CycleStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.HatcherCycle;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface HatcherCycleRepository extends MongoRepository<HatcherCycle, String> {
  Optional<HatcherCycle> findByIdAndFarmId(String id, String farmId);

  List<HatcherCycle> findByFarmIdAndIncubationBatchIdIn(
      String farmId, Collection<String> batchIds);

  List<HatcherCycle> findByFarmIdAndHatcherIdAndStatusIn(
      String farmId, String hatcherId, Collection<CycleStatus> statuses);

  long countByFarmIdAndIncubationBatchId(String farmId, String batchId);
}
