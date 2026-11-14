package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.BatchStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.IncubationBatch;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface IncubationBatchRepository extends MongoRepository<IncubationBatch, String> {
  Optional<IncubationBatch> findByIdAndFarmId(String id, String farmId);

  List<IncubationBatch> findByFarmIdOrderByPlannedStartDateDesc(String farmId, Pageable pageable);

  List<IncubationBatch> findByFarmIdAndStatusOrderByPlannedStartDateDesc(
      String farmId, BatchStatus status, Pageable pageable);

  List<IncubationBatch> findByFarmIdAndEquipmentIdAndStatusIn(
      String farmId, String equipmentId, Collection<BatchStatus> statuses);

  List<IncubationBatch> findByFarmIdAndStatusIn(String farmId, Collection<BatchStatus> statuses);

  boolean existsByFarmIdAndReferenceIgnoreCase(String farmId, String reference);

  long countByFarmId(String farmId);
}
