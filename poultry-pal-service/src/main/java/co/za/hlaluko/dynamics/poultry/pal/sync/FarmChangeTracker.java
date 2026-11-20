package co.za.hlaluko.dynamics.poultry.pal.sync;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncEntityType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncTombstone;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.SyncTracked;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import co.za.hlaluko.dynamics.poultry.pal.utils.FarmAddresses;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.Ordered;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.mapping.event.BeforeConvertCallback;
import org.springframework.stereotype.Component;

/**
 * Maintains sync metadata on every save of a {@link Farm} document, regardless of whether the
 * write came from the legacy API or the v1 sync API.
 *
 * <p>Compares the farm being saved with the stored document, stamps new or changed embedded records
 * with the new farm version, and records tombstones for removed records. Tombstones are stored in the
 * farm document so they are written atomically with the change.
 */
@Component
public class FarmChangeTracker implements BeforeConvertCallback<Farm>, Ordered {

  static final Duration TOMBSTONE_RETENTION = Duration.ofDays(90);
  private static final String SYSTEM_USER = "system";
  private static final List<String> META_FIELDS = List.of("version", "updatedAt", "updatedBy");
  private static final List<String> COOP_DERIVED_FIELDS =
      List.of(
          "mortalities",
          "sales",
          "expenses",
          "eggPackagingRecords",
          "chickenAge",
          "active",
          "phaseTransition");

  private final ObjectProvider<MongoTemplate> mongoTemplateProvider;
  // Private mapper: used only to compare record content, never for API output.
  private final ObjectMapper mapper = new ObjectMapper();

  public FarmChangeTracker(ObjectProvider<MongoTemplate> mongoTemplateProvider) {
    this.mongoTemplateProvider = mongoTemplateProvider;
  }

  @Override
  public int getOrder() {
    return Ordered.LOWEST_PRECEDENCE;
  }

  @Override
  public Farm onBeforeConvert(Farm farm, String collection) {
    long version = farm.getVersion() == null ? 0L : farm.getVersion();
    Date now = new Date();
    String userId =
        Optional.ofNullable(SecurityUtils.getCurrentUser())
            .map(UserDetailsImpl::getId)
            .orElse(SYSTEM_USER);

    Farm existing =
        farm.getId() == null
            ? null
            : mongoTemplateProvider.getObject().findById(farm.getId(), Farm.class, collection);

    Map<RecordKey, TrackedRecord> before = index(existing);
    Map<RecordKey, TrackedRecord> after = index(farm);

    for (Map.Entry<RecordKey, TrackedRecord> entry : after.entrySet()) {
      TrackedRecord current = entry.getValue();
      TrackedRecord previous = before.get(entry.getKey());
      if (previous == null || !previous.content().equals(current.content())) {
        stamp(current.record(), version, now, userId);
      } else if (current.record().getVersion() == null && previous.record().getVersion() != null) {
        current.record().setVersion(previous.record().getVersion());
        current.record().setUpdatedAt(previous.record().getUpdatedAt());
        current.record().setUpdatedBy(previous.record().getUpdatedBy());
      }
    }

    updateTombstones(farm, before, after, version, now);

    if (existing == null || !detailsOf(existing).equals(detailsOf(farm))) {
      farm.setDetailsVersion(version);
    }
    farm.setUpdatedAt(now);
    return farm;
  }

  private void updateTombstones(
      Farm farm,
      Map<RecordKey, TrackedRecord> before,
      Map<RecordKey, TrackedRecord> after,
      long version,
      Date now) {
    List<SyncTombstone> tombstones =
        farm.getTombstones() == null ? new ArrayList<>() : new ArrayList<>(farm.getTombstones());

    tombstones.removeIf(t -> after.containsKey(new RecordKey(t.getEntityType(), t.getEntityId())));

    for (Map.Entry<RecordKey, TrackedRecord> entry : before.entrySet()) {
      RecordKey key = entry.getKey();
      if (!after.containsKey(key)) {
        tombstones.removeIf(t -> key.equals(new RecordKey(t.getEntityType(), t.getEntityId())));
        tombstones.add(
            SyncTombstone.builder()
                .entityType(key.type())
                .entityId(key.id())
                .coopId(entry.getValue().coopId())
                .version(version)
                .deletedAt(now)
                .build());
      }
    }

    Date cutoff = new Date(now.getTime() - TOMBSTONE_RETENTION.toMillis());
    long prunedBefore =
        farm.getTombstonesPrunedBefore() == null ? 0L : farm.getTombstonesPrunedBefore();
    List<SyncTombstone> expired =
        tombstones.stream()
            .filter(t -> t.getDeletedAt() != null && t.getDeletedAt().before(cutoff))
            .toList();
    for (SyncTombstone t : expired) {
      prunedBefore = Math.max(prunedBefore, t.getVersion() == null ? 0L : t.getVersion());
    }
    tombstones.removeAll(expired);
    if (prunedBefore > 0) {
      farm.setTombstonesPrunedBefore(prunedBefore);
    }
    farm.setTombstones(tombstones);
  }

  private static void stamp(SyncTracked record, long version, Date now, String userId) {
    record.setVersion(version);
    record.setUpdatedAt(now);
    record.setUpdatedBy(userId);
  }

  private JsonNode detailsOf(Farm farm) {
    ObjectNode node = mapper.createObjectNode();
    node.put("farmName", farm.getFarmName());
    node.set("address", mapper.valueToTree(FarmAddresses.primary(farm)));
    node.set("addresses", mapper.valueToTree(FarmAddresses.list(farm)));
    return node;
  }

  private Map<RecordKey, TrackedRecord> index(Farm farm) {
    Map<RecordKey, TrackedRecord> result = new LinkedHashMap<>();
    if (farm == null || farm.getCoops() == null) {
      return result;
    }
    for (Coop coop : farm.getCoops()) {
      if (coop == null || coop.getId() == null) {
        continue;
      }
      put(result, SyncEntityType.COOP, coop, null);
      addChildren(result, SyncEntityType.SALE, coop.getSales(), coop.getId());
      addChildren(result, SyncEntityType.MORTALITY, coop.getMortalities(), coop.getId());
      addChildren(result, SyncEntityType.EXPENSE, coop.getExpenses(), coop.getId());
      addChildren(
          result, SyncEntityType.EGG_PACKAGING, coop.getEggPackagingRecords(), coop.getId());
    }
    return result;
  }

  private void addChildren(
      Map<RecordKey, TrackedRecord> result,
      SyncEntityType type,
      List<? extends SyncTracked> records,
      String coopId) {
    if (records == null) {
      return;
    }
    for (SyncTracked record : records) {
      if (record != null && record.getId() != null) {
        put(result, type, record, coopId);
      }
    }
  }

  private void put(
      Map<RecordKey, TrackedRecord> result, SyncEntityType type, SyncTracked record, String coopId) {
    ObjectNode content = mapper.valueToTree(record);
    META_FIELDS.forEach(content::remove);
    if (type == SyncEntityType.COOP) {
      COOP_DERIVED_FIELDS.forEach(content::remove);
      JsonNode reminder = content.get("reminder");
      if (reminder instanceof ObjectNode reminderNode) {
        reminderNode.remove("overdueTasks");
        reminderNode.remove("upcomingReminders");
      }
    } else {
      content.put("_coopId", coopId);
    }
    result.put(new RecordKey(type, record.getId()), new TrackedRecord(record, coopId, content));
  }

  record RecordKey(SyncEntityType type, String id) {
    RecordKey {
      Objects.requireNonNull(type);
    }
  }

  private record TrackedRecord(SyncTracked record, String coopId, JsonNode content) {}
}
