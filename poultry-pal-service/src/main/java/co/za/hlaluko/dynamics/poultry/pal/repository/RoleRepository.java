package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Role;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface RoleRepository extends MongoRepository<Role, String> {
  Optional<Role> findByName(ERole name);

  boolean existsByName(ERole name);
}
