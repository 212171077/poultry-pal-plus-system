package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Farm;
import co.za.hlaluko.dynamics.poultry.pal.repository.CoopArchiveRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.FarmRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class SyncControllerTest extends V1TestSupport {

  @Autowired FarmRepository farmRepository;
  @Autowired CoopArchiveRepository coopArchiveRepository;

  @Test
  @DisplayName("push creates records with client ids and stamps them with the farm version")
  void pushCreatesAndStampsVersions() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    String expenseId = newId();

    JsonNode response = push(session, coopOp(coopId, "Coop A", null), expenseOp(expenseId, coopId, 250, null));

    JsonNode results = response.at("/data/results");
    assertThat(results).hasSize(2);
    assertThat(results.get(0).get("status").asText()).isEqualTo("APPLIED");
    assertThat(results.get(1).get("status").asText()).isEqualTo("APPLIED");
    assertThat(results.get(0).get("entityId").asText()).isEqualTo(coopId);
    assertThat(results.get(1).at("/serverRecord/amount").asDouble()).isEqualTo(250);

    Farm farm = farmRepository.findById(session.farmId()).orElseThrow();
    Coop coop = farm.getCoops().stream().filter(c -> c.getId().equals(coopId)).findFirst().orElseThrow();
    assertThat(coop.getVersion()).isEqualTo(farm.getVersion());
    assertThat(coop.getUpdatedBy()).isEqualTo(session.userId());
    assertThat(coop.getExpenses().get(0).getVersion()).isEqualTo(farm.getVersion());
    assertThat(results.get(0).get("version").asLong()).isEqualTo(farm.getVersion());
    assertThat(response.at("/data/serverVersion").asLong()).isEqualTo(farm.getVersion());
  }

  @Test
  @DisplayName("replaying the same opId is idempotent and flagged as duplicate")
  void pushIsIdempotent() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    ObjectNode coop = coopOp(coopId, "Coop A", null);
    ObjectNode expense = expenseOp(newId(), coopId, 100, null);

    JsonNode first = push(session, coop, expense);
    JsonNode replay = push(session, coop, expense);

    for (int i = 0; i < 2; i++) {
      JsonNode result = replay.at("/data/results").get(i);
      assertThat(result.get("status").asText()).isEqualTo("APPLIED");
      assertThat(result.get("duplicate").asBoolean()).isTrue();
      assertThat(result.get("version").asLong())
          .isEqualTo(first.at("/data/results").get(i).get("version").asLong());
    }
    Farm farm = farmRepository.findById(session.farmId()).orElseThrow();
    assertThat(farm.getCoops()).hasSize(1);
    assertThat(farm.getCoops().get(0).getExpenses()).hasSize(1);
  }

  @Test
  @DisplayName("an update with a stale baseVersion is a CONFLICT that returns the server record")
  void staleUpdateConflicts() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    String expenseId = newId();
    push(session, coopOp(coopId, "Coop A", null));
    long created =
        push(session, expenseOp(expenseId, coopId, 100, null)).at("/data/results/0/version").asLong();

    JsonNode update = push(session, expenseOp(expenseId, coopId, 150, created));
    assertThat(update.at("/data/results/0/status").asText()).isEqualTo("APPLIED");
    long updated = update.at("/data/results/0/version").asLong();
    assertThat(updated).isGreaterThan(created);

    JsonNode stale = push(session, expenseOp(expenseId, coopId, 999, created));
    JsonNode result = stale.at("/data/results/0");
    assertThat(result.get("status").asText()).isEqualTo("CONFLICT");
    assertThat(result.get("errorCode").asText()).isEqualTo("CONFLICT");
    assertThat(result.at("/serverRecord/amount").asDouble()).isEqualTo(150);
    assertThat(result.at("/serverRecord/version").asLong()).isEqualTo(updated);
  }

  @Test
  @DisplayName("invalid operations are REJECTED without failing the rest of the batch")
  void invalidOperationRejected() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    ObjectNode badExpense = expenseOp(newId(), coopId, 10, null);
    ((ObjectNode) badExpense.get("payload")).remove("expenseType");

    JsonNode response = push(session, coopOp(coopId, "Coop A", null), badExpense);

    assertThat(response.at("/data/results/0/status").asText()).isEqualTo("APPLIED");
    assertThat(response.at("/data/results/1/status").asText()).isEqualTo("REJECTED");
    assertThat(response.at("/data/results/1/errorCode").asText()).isEqualTo("VALIDATION_ERROR");
  }

  @Test
  @DisplayName("a malformed push request returns a 400 envelope")
  void malformedPushRequest() throws Exception {
    Session session = newOwnerSession();
    ObjectNode op = coopOp(newId(), "Coop", null);
    op.put("opId", "has spaces!");
    JsonNode body = push(session, 400, op);
    assertThat(body.get("success").asBoolean()).isFalse();
    assertThat(body.get("errorCode").asText()).isEqualTo("VALIDATION_ERROR");
  }

  @Test
  @DisplayName("changes returns only records after the cursor, and deletes as tombstones")
  void changesSinceCursorWithTombstones() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    String expenseA = newId();
    String expenseB = newId();
    push(session, coopOp(coopId, "Coop A", null), expenseOp(expenseA, coopId, 10, null));

    JsonNode full = changes(session, null, null);
    assertThat(full.get("resetRequired").asBoolean()).isFalse();
    assertThat(full.get("hasMore").asBoolean()).isFalse();
    assertThat(ids(full.get("coops"))).containsExactly(coopId);
    assertThat(ids(full.get("expenses"))).containsExactly(expenseA);
    assertThat(full.at("/expenses/0/coopId").asText()).isEqualTo(coopId);
    assertThat(full.get("farm")).isNotNull();
    long cursor = full.get("cursor").asLong();

    JsonNode none = changes(session, cursor, null);
    assertThat(none.get("expenses")).isEmpty();
    assertThat(none.get("tombstones")).isEmpty();
    assertThat(none.get("cursor").asLong()).isEqualTo(cursor);

    long baseA = full.at("/expenses/0/version").asLong();
    push(
        session,
        expenseOp(expenseB, coopId, 20, null),
        op("EXPENSE", "DELETE", expenseA, coopId, baseA));

    JsonNode delta = changes(session, cursor, null);
    assertThat(ids(delta.get("expenses"))).contains(expenseB).doesNotContain(expenseA);
    assertThat(delta.get("tombstones")).anySatisfy(
        t -> {
          assertThat(t.get("entityType").asText()).isEqualTo("EXPENSE");
          assertThat(t.get("entityId").asText()).isEqualTo(expenseA);
        });
    assertThat(delta.get("cursor").asLong()).isGreaterThan(cursor);
  }

  @Test
  @DisplayName("writes made through the legacy API are tracked (versions and tombstones)")
  void legacyWritesAreTracked() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    String expenseId = newId();
    push(session, coopOp(coopId, "Coop A", null), expenseOp(expenseId, coopId, 10, null));
    long cursor = changes(session, null, null).get("cursor").asLong();

    // Simulate a legacy (mobile) write that saves the whole farm document.
    Farm farm = farmRepository.findById(session.farmId()).orElseThrow();
    Coop coop = farm.getCoops().get(0);
    coop.setNumberOfChickens(80);
    coop.setExpenses(new ArrayList<>());
    farmRepository.save(farm);

    JsonNode delta = changes(session, cursor, null);
    assertThat(ids(delta.get("coops"))).containsExactly(coopId);
    assertThat(delta.at("/coops/0/numberOfChickens").asInt()).isEqualTo(80);
    assertThat(ids(delta.get("tombstones"))).contains(expenseId);
  }

  @Test
  @DisplayName("changes paginates with hasMore and a resumable cursor")
  void changesPagination() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    push(session, coopOp(coopId, "Coop A", null));
    for (int i = 0; i < 4; i++) {
      push(session, expenseOp(newId(), coopId, i, null));
    }

    List<String> seen = new ArrayList<>();
    Long since = null;
    int pages = 0;
    JsonNode page;
    do {
      page = changes(session, since, 2);
      page.get("expenses").forEach(e -> seen.add(e.get("id").asText()));
      since = page.get("cursor").asLong();
      pages++;
    } while (page.get("hasMore").asBoolean() && pages < 20);

    assertThat(pages).isGreaterThan(1);
    assertThat(seen).hasSize(4).doesNotHaveDuplicates();
  }

  @Test
  @DisplayName("a cursor ahead of the server requires a reset")
  void cursorAheadRequiresReset() throws Exception {
    Session session = newOwnerSession();
    JsonNode response = changes(session, 1_000_000L, null);
    assertThat(response.get("resetRequired").asBoolean()).isTrue();
  }

  @Test
  @DisplayName("workers only see and modify coops they are responsible for")
  void workerVisibility() throws Exception {
    Session owner = newOwnerSession();
    String coopId = newId();
    push(owner, coopOp(coopId, "Owner coop", null));

    Session worker = signin(createWorker(owner.farmId()));

    JsonNode visible = changes(worker, null, null);
    assertThat(visible.get("coops")).isEmpty();

    JsonNode denied = push(worker, expenseOp(newId(), coopId, 5, null));
    assertThat(denied.at("/data/results/0/status").asText()).isEqualTo("REJECTED");
    assertThat(denied.at("/data/results/0/errorCode").asText()).isEqualTo("FORBIDDEN");

    JsonNode cannotCreateCoop = push(worker, coopOp(newId(), "Worker coop", null));
    assertThat(cannotCreateCoop.at("/data/results/0/status").asText()).isEqualTo("REJECTED");
  }

  @Test
  @DisplayName("bootstrap returns the user, farm snapshot, team and settings")
  void bootstrap() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    push(session, coopOp(coopId, "Coop A", null));

    mvc.perform(get("/api/v1/sync/bootstrap").cookie(accessCookie(session)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.success").value(true))
        .andExpect(jsonPath("$.data.user.id").value(session.userId()))
        .andExpect(jsonPath("$.data.snapshot.coops[0].id").value(coopId))
        .andExpect(jsonPath("$.data.team[0].password").doesNotExist());
  }

  @Test
  @DisplayName("NEW_BATCH archives the old batch, clears its records and tombstones them")
  void newBatchArchivesRecords() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    String expenseId = newId();
    push(session, coopOp(coopId, "Coop A", null), expenseOp(expenseId, coopId, 40, null));
    long cursor = changes(session, null, null).get("cursor").asLong();
    long archivesBefore = coopArchiveRepository.count();

    ObjectNode action = op("COOP", "ACTION", coopId, coopId, null);
    ObjectNode payload = action.putObject("payload");
    payload.put("action", "NEW_BATCH");
    ObjectNode batch = payload.putObject("batch");
    batch.put("coopName", "Coop A batch 2");
    batch.put("coopType", "BROILER");
    batch.put("growthPhase", "BROODING_PHASE");
    batch.put("numberOfChickens", 300);
    batch.put("chickenArrivalDate", "2025-03-01T00:00:00.000Z");

    JsonNode result = push(session, action).at("/data/results/0");
    assertThat(result.get("status").asText()).isEqualTo("APPLIED");
    assertThat(result.at("/serverRecord/coopName").asText()).isEqualTo("Coop A batch 2");
    assertThat(result.at("/serverRecord/numberOfChickens").asInt()).isEqualTo(300);

    Coop coop = farmRepository.findById(session.farmId()).orElseThrow().getCoops().get(0);
    assertThat(coop.getExpenses()).isEmpty();
    assertThat(coopArchiveRepository.count()).isEqualTo(archivesBefore + 1);

    JsonNode delta = changes(session, cursor, null);
    assertThat(ids(delta.get("coops"))).containsExactly(coopId);
    assertThat(ids(delta.get("tombstones"))).contains(expenseId);
  }

  @Test
  @DisplayName("archived batches are listed with totals for managers only")
  void archivedBatchesAreListed() throws Exception {
    Session session = newOwnerSession();
    String coopId = newId();
    push(session, coopOp(coopId, "Coop A", null), expenseOp(newId(), coopId, 40, null));
    ObjectNode action = op("COOP", "ACTION", coopId, coopId, null);
    ObjectNode payload = action.putObject("payload");
    payload.put("action", "NEW_BATCH");
    ObjectNode batch = payload.putObject("batch");
    batch.put("coopName", "Coop A batch 2");
    batch.put("coopType", "BROILER");
    batch.put("growthPhase", "BROODING_PHASE");
    batch.put("numberOfChickens", 300);
    batch.put("chickenArrivalDate", "2025-03-01T00:00:00.000Z");
    push(session, action);

    mvc.perform(get("/api/v1/farm/archived-batches").cookie(accessCookie(session)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data[0].coopName").value("Coop A"))
        .andExpect(jsonPath("$.data[0].totalExpenses").value(40.0))
        .andExpect(jsonPath("$.data[0].expensesCount").value(1));

    Session worker = signin(createWorker(session.farmId()));
    mvc.perform(get("/api/v1/farm/archived-batches").cookie(accessCookie(worker)))
        .andExpect(status().isForbidden());
  }

  @Test
  @DisplayName("PHASE_TRANSITION moves the flock and its records into an empty coop")
  void phaseTransitionIntoAnotherCoop() throws Exception {
    Session session = newOwnerSession();
    String from = newId();
    String to = newId();
    String expenseId = newId();
    ObjectNode empty = coopOp(to, "Grower house", null);
    ((ObjectNode) empty.get("payload")).put("numberOfChickens", 0);
    ((ObjectNode) empty.get("payload")).put("growthPhase", "GROWING_REARING_PHASE");
    push(session, coopOp(from, "Brooder", null), empty, expenseOp(expenseId, from, 15, null));
    long cursor = changes(session, null, null).get("cursor").asLong();

    JsonNode result = push(session, transitionOp(from, to)).at("/data/results/0");
    assertThat(result.get("status").asText()).isEqualTo("APPLIED");
    assertThat(result.at("/serverRecord/numberOfChickens").asInt()).isZero();

    List<Coop> coops = farmRepository.findById(session.farmId()).orElseThrow().getCoops();
    Coop source = coops.stream().filter(c -> c.getId().equals(from)).findFirst().orElseThrow();
    Coop target = coops.stream().filter(c -> c.getId().equals(to)).findFirst().orElseThrow();
    assertThat(target.getNumberOfChickens()).isEqualTo(100);
    assertThat(target.getGrowthPhase().name()).isEqualTo("GROWING_REARING_PHASE");
    assertThat(target.getExpenses()).extracting(e -> e.getId()).containsExactly(expenseId);
    assertThat(source.getExpenses()).isEmpty();
    assertThat(source.getGrowthPhase().name()).isEqualTo("BROODING_PHASE");

    JsonNode delta = changes(session, cursor, null);
    assertThat(ids(delta.get("coops"))).containsExactlyInAnyOrder(from, to);
    assertThat(delta.at("/expenses/0/coopId").asText()).isEqualTo(to);

    JsonNode occupied = push(session, transitionOp(to, from));
    assertThat(occupied.at("/data/results/0/status").asText()).isEqualTo("APPLIED");
    JsonNode notEmpty = push(session, transitionOp(newCoop(session), from));
    assertThat(notEmpty.at("/data/results/0/status").asText()).isEqualTo("REJECTED");
  }

  @Test
  @DisplayName("workers cannot start a new batch")
  void workerCannotStartNewBatch() throws Exception {
    Session owner = newOwnerSession();
    String coopId = newId();
    push(owner, coopOp(coopId, "Coop A", null));
    Session worker = signin(createWorker(owner.farmId()));

    ObjectNode action = op("COOP", "ACTION", coopId, coopId, null);
    action.putObject("payload").put("action", "NEW_BATCH");
    JsonNode result = push(worker, action).at("/data/results/0");
    assertThat(result.get("status").asText()).isEqualTo("REJECTED");
    assertThat(result.get("errorCode").asText()).isEqualTo("FORBIDDEN");
  }

  private ObjectNode transitionOp(String from, String to) {
    ObjectNode action = op("COOP", "ACTION", from, from, null);
    ObjectNode payload = action.putObject("payload");
    payload.put("action", "PHASE_TRANSITION");
    payload.put("newGrowthPhase", "GROWING_REARING_PHASE");
    payload.put("targetCoopId", to);
    return action;
  }

  private String newCoop(Session session) throws Exception {
    String id = newId();
    push(session, coopOp(id, "Extra " + id.substring(0, 6), null));
    return id;
  }
}
