package co.za.hlaluko.dynamics.poultry.pal.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.RefreshToken;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.SyncOperationLog;
import com.mongodb.client.result.UpdateResult;
import java.time.Duration;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Component;

/**
 * Prepares the database for sync before the web server starts accepting requests:
 *
 * <ul>
 *   <li>Initialises the optimistic-locking {@code version} on farm documents created before it
 *       existed. Without this, Spring Data would treat them as new and attempt an insert.
 *   <li>Creates the TTL indexes for the idempotency log and refresh tokens.
 * </ul>
 */
@Component
public class SyncDatabaseInitializer implements InitializingBean {
  private static final Logger logger = LogManager.getLogger(SyncDatabaseInitializer.class);
  static final Duration OPERATION_LOG_RETENTION = Duration.ofDays(30);

  private final MongoTemplate mongoTemplate;

  public SyncDatabaseInitializer(MongoTemplate mongoTemplate) {
    this.mongoTemplate = mongoTemplate;
  }

  @Override
  public void afterPropertiesSet() {
    UpdateResult result =
        mongoTemplate.updateMulti(
            Query.query(Criteria.where("version").exists(false)),
            new Update().set("version", 1L),
            Farm.class);
    if (result.getModifiedCount() > 0) {
      logger.info("Initialised sync version on {} farm document(s)", result.getModifiedCount());
    }

    mongoTemplate
        .indexOps(SyncOperationLog.class)
        .ensureIndex(
            new Index().on("createdAt", Sort.Direction.ASC).expire(OPERATION_LOG_RETENTION));
    mongoTemplate
        .indexOps(RefreshToken.class)
        .ensureIndex(new Index().on("expiresAt", Sort.Direction.ASC).expire(Duration.ZERO));
    mongoTemplate
        .indexOps(RefreshToken.class)
        .ensureIndex(new Index().on("userId", Sort.Direction.ASC));
  }
}
