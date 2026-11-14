package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.EquipmentType;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionEquipment;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ProductionEquipmentRepository
    extends MongoRepository<ProductionEquipment, String> {
  List<ProductionEquipment> findByFarmIdAndArchivedFalseOrderByTypeAscNameAsc(String farmId);

  Optional<ProductionEquipment> findByIdAndFarmIdAndArchivedFalse(String id, String farmId);

  boolean existsByFarmIdAndTypeAndNameIgnoreCaseAndArchivedFalse(
      String farmId, EquipmentType type, String name);

  long countByFarmId(String farmId);
}
