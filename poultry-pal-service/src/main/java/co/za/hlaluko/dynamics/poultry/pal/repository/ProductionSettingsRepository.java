package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionSettings;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ProductionSettingsRepository extends MongoRepository<ProductionSettings, String> {
  Optional<ProductionSettings> findByFarmId(String farmId);
}
