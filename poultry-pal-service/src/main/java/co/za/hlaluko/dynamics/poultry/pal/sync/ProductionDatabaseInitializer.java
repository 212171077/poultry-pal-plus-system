package co.za.hlaluko.dynamics.poultry.pal.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.HatcherCycle;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.IncubationBatch;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionEquipment;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionReminder;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionSettings;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.HatchResult;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.BirdMovement;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.BirdPlacement;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.stereotype.Component;

/** Creates the production-module indexes (auto index creation is disabled in this project). */
@Component
public class ProductionDatabaseInitializer implements InitializingBean {
  private final MongoTemplate mongoTemplate;

  public ProductionDatabaseInitializer(MongoTemplate mongoTemplate) {
    this.mongoTemplate = mongoTemplate;
  }

  @Override
  public void afterPropertiesSet() {
    mongoTemplate
        .indexOps(co.za.hlaluko.dynamics.poultry.pal.model.entity.ProductionPlan.class)
        .ensureIndex(
            new Index().on("farmId", Sort.Direction.ASC).on("status", Sort.Direction.ASC));
    mongoTemplate
        .indexOps(ProductionSettings.class)
        .ensureIndex(new Index().on("farmId", Sort.Direction.ASC).unique());
    mongoTemplate
        .indexOps(ProductionEquipment.class)
        .ensureIndex(
            new Index().on("farmId", Sort.Direction.ASC).on("type", Sort.Direction.ASC));
    mongoTemplate
        .indexOps(IncubationBatch.class)
        .ensureIndex(
            new Index().on("farmId", Sort.Direction.ASC).on("reference", Sort.Direction.ASC).unique());
    mongoTemplate
        .indexOps(IncubationBatch.class)
        .ensureIndex(
            new Index()
                .on("farmId", Sort.Direction.ASC)
                .on("status", Sort.Direction.ASC)
                .on("plannedHatchDate", Sort.Direction.ASC));
    mongoTemplate
        .indexOps(IncubationBatch.class)
        .ensureIndex(
            new Index()
                .on("farmId", Sort.Direction.ASC)
                .on("equipmentId", Sort.Direction.ASC)
                .on("plannedStartDate", Sort.Direction.ASC));
    mongoTemplate
        .indexOps(HatcherCycle.class)
        .ensureIndex(
            new Index().on("farmId", Sort.Direction.ASC).on("incubationBatchId", Sort.Direction.ASC));
    mongoTemplate
        .indexOps(HatcherCycle.class)
        .ensureIndex(
            new Index()
                .on("farmId", Sort.Direction.ASC)
                .on("hatcherId", Sort.Direction.ASC)
                .on("plannedTransferDate", Sort.Direction.ASC));
    mongoTemplate
        .indexOps(ProductionReminder.class)
        .ensureIndex(
            new Index()
                .on("farmId", Sort.Direction.ASC)
                .on("sourceType", Sort.Direction.ASC)
                .on("sourceId", Sort.Direction.ASC)
                .on("ruleKey", Sort.Direction.ASC)
                .unique());
    mongoTemplate
        .indexOps(ProductionReminder.class)
        .ensureIndex(
            new Index()
                .on("farmId", Sort.Direction.ASC)
                .on("status", Sort.Direction.ASC)
                .on("dueDate", Sort.Direction.ASC));
    mongoTemplate
        .indexOps(HatchResult.class)
        .ensureIndex(
            new Index()
                .on("farmId", Sort.Direction.ASC)
                .on("hatcherCycleId", Sort.Direction.ASC)
                .unique());
    mongoTemplate
        .indexOps(HatchResult.class)
        .ensureIndex(
            new Index().on("farmId", Sort.Direction.ASC).on("resultDate", Sort.Direction.DESC));
    mongoTemplate
        .indexOps(BirdPlacement.class)
        .ensureIndex(
            new Index().on("farmId", Sort.Direction.ASC).on("houseId", Sort.Direction.ASC));
    mongoTemplate
        .indexOps(BirdMovement.class)
        .ensureIndex(
            new Index().on("farmId", Sort.Direction.ASC).on("placementId", Sort.Direction.ASC));
    mongoTemplate
        .indexOps(BirdMovement.class)
        .ensureIndex(
            new Index()
                .on("farmId", Sort.Direction.ASC)
                .on("idempotencyKey", Sort.Direction.ASC)
                .unique()
                .partial(
                    org.springframework.data.mongodb.core.index.PartialIndexFilter.of(
                        org.springframework.data.mongodb.core.query.Criteria.where("idempotencyKey")
                            .gt(""))));
  }
}
