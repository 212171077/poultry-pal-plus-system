package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface UserRepository extends MongoRepository<User, String> {
  Optional<User> findByEmail(String email);
  Boolean existsByEmailAndRemoved(String email, boolean removed);
  List<User> findByActive(boolean active);
  List<User> findByFarmId(String farmId);
  User findByFarmIdAndFarmOwner(String farmId, boolean farmOwner);
}
