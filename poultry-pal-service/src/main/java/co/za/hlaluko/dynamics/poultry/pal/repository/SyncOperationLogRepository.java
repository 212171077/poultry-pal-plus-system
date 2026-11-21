package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.SyncOperationLog;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface SyncOperationLogRepository extends MongoRepository<SyncOperationLog, String> {
  void deleteByFarmId(String farmId);
}
