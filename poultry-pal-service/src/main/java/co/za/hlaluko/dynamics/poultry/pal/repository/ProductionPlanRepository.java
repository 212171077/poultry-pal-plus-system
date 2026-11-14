package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.PlanStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionPlan;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ProductionPlanRepository extends MongoRepository<ProductionPlan, String> {
  Optional<ProductionPlan> findByIdAndFarmId(String id, String farmId);

  List<ProductionPlan> findByFarmIdOrderByCreatedAtDesc(String farmId);

  List<ProductionPlan> findByFarmIdAndStatusInOrderByCreatedAtDesc(
      String farmId, Collection<PlanStatus> statuses);
}
