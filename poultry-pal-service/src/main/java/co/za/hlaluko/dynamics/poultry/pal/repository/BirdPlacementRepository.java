package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.BirdPlacement;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface BirdPlacementRepository extends MongoRepository<BirdPlacement, String> {
  Optional<BirdPlacement> findByIdAndFarmId(String id, String farmId);

  List<BirdPlacement> findByFarmIdOrderByPlacementDateDesc(String farmId);

  List<BirdPlacement> findByFarmIdAndHouseId(String farmId, String houseId);

  List<BirdPlacement> findByFarmIdAndSourceCycleId(String farmId, String sourceCycleId);

  long countByFarmId(String farmId);
}
