package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.HatchResult;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

public interface HatchResultRepository extends MongoRepository<HatchResult, String> {
  Optional<HatchResult> findByFarmIdAndHatcherCycleId(String farmId, String hatcherCycleId);

  @Query("{ 'farmId': ?0, 'resultDate': { $gte: ?1, $lte: ?2 } }")
  List<HatchResult> findInRange(String farmId, LocalDate from, LocalDate to);

  void deleteByFarmId(String farmId);
}
