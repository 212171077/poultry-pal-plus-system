package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.BirdMovement;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface BirdMovementRepository extends MongoRepository<BirdMovement, String> {
  List<BirdMovement> findByFarmIdAndPlacementIdIn(String farmId, Collection<String> placementIds);

  List<BirdMovement> findByFarmIdAndPlacementIdOrderByDateAscCreatedAtAsc(
      String farmId, String placementId);

  Optional<BirdMovement> findByFarmIdAndIdempotencyKey(String farmId, String idempotencyKey);

  void deleteByFarmId(String farmId);
}
