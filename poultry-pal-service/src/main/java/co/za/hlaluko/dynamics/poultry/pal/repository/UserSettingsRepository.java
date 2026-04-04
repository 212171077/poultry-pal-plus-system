package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.UserSettings;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.Optional;

public interface UserSettingsRepository extends MongoRepository<UserSettings, String> {
    Optional<UserSettings> findByUserIdAndFarmId(String userId, String farmId);
}
