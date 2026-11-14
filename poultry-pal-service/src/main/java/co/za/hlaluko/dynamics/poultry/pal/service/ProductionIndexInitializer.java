package co.za.hlaluko.dynamics.poultry.pal.service;

import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.stereotype.Component;

/**
 * Creates the production collections' indexes at startup. Index creation is idempotent and scoped to
 * production collections only; a failure is logged and never stops the application.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ProductionIndexInitializer implements ApplicationRunner {

  /** Collection to the field lists of its compound indexes, always led by {@code farmId}. */
  public static final Map<String, List<List<String>>> INDEXES =
      Map.of(
          "incubation_batches",
          List.of(List.of("farmId", "status"), List.of("farmId", "plannedStartDate")),
          "hatcher_cycles",
          List.of(List.of("farmId", "incubationBatchId"), List.of("farmId", "status")),
          "hatch_results",
          List.of(List.of("farmId", "hatcherCycleId"), List.of("farmId", "resultDate")),
          "bird_placements",
          List.of(
              List.of("farmId", "houseId"),
              List.of("farmId", "sourceCycleId"),
              List.of("farmId", "placementDate")),
          "production_plans",
          List.of(List.of("farmId", "createdAt")),
          "production_reminders",
          List.of(List.of("farmId", "status", "dueDate")),
          "production_equipment",
          List.of(List.of("farmId", "archived", "type")),
          "production_settings",
          List.of(List.of("farmId")));

  private final MongoTemplate mongoTemplate;

  @Override
  public void run(ApplicationArguments args) {
    ensureIndexes();
  }

  public void ensureIndexes() {
    INDEXES.forEach(
        (collection, indexes) -> {
          for (List<String> fields : indexes) {
            Index index = new Index();
            fields.forEach(field -> index.on(field, Sort.Direction.ASC));
            try {
              mongoTemplate.indexOps(collection).ensureIndex(index);
            } catch (RuntimeException e) {
              log.warn("Could not create index {} on {}: {}", fields, collection, e.getMessage());
            }
          }
        });
  }
}
