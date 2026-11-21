package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.RefreshToken;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface RefreshTokenRepository extends MongoRepository<RefreshToken, String> {
  List<RefreshToken> findByUserIdAndRevokedFalse(String userId);

  void deleteByUserIdIn(java.util.Collection<String> userIds);
}
