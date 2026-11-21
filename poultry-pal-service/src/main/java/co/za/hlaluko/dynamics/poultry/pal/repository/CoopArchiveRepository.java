package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.CoopArchive;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface CoopArchiveRepository extends MongoRepository<CoopArchive, String> {
  List<CoopArchive> findByFarmIdOrderByCreatedDateDesc(String farmId);

  void deleteByFarmId(String farmId);
}
