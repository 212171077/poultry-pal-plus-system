package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface UserRepository extends MongoRepository<User, String> {
  Optional<User> findByEmail(String email);
  Optional<User> findByApprovalTokenHash(String approvalTokenHash);
  Boolean existsByEmailAndRemoved(String email, boolean removed);
  List<User> findByActive(boolean active);
  List<User> findByFarmId(String farmId);
  void deleteByFarmId(String farmId);
  List<User> findByFarmIdIn(Collection<String> farmIds);
  User findByFarmIdAndFarmOwner(String farmId, boolean farmOwner);
}
