package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class ProductionSyncControllerTest extends V1TestSupport {
  private static final LocalDate TODAY = LocalDate.now();

  private ObjectNode op(String opId, String entityId, String command, ObjectNode body) {
    ObjectNode op = mapper.createObjectNode();
    op.put("opId", opId);
    op.put("entityType", "PRODUCTION");
    op.put("operation", "ACTION");
    op.put("entityId", entityId);
    ObjectNode payload = op.putObject("payload");
    payload.put("command", command);
    if (body != null) payload.set("body", body);
    return op;
  }

  private ObjectNode batch(String equipmentId, int eggs) {
    ObjectNode n = mapper.createObjectNode();
    n.put("equipmentId", equipmentId);
    n.put("eggsSet", eggs);
    n.put("plannedStartDate", TODAY.plusDays(1).toString());
    return n;
  }

  private String incubatorId(Session s) throws Exception {
    return body(mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(s))).andReturn())
        .get("data").get(0).get("id").asText();
  }

  @Test
  @DisplayName("queued production commands apply, replay idempotently and chain on server ids")
  void appliesAndReplays() throws Exception {
    Session owner = newOwnerSession();
    String incubator = incubatorId(owner);
    ObjectNode create = op("op-create", UUID.randomUUID().toString(), "BATCH_CREATE", batch(incubator, 100));

    JsonNode first = push(owner, create);
    assertThat(first.at("/data/results/0/status").asText()).isEqualTo("APPLIED");
    String batchId = first.at("/data/results/0/serverRecord/id").asText();

    JsonNode replay = push(owner, create);
    assertThat(replay.at("/data/results/0/duplicate").asBoolean()).isTrue();
    mvc.perform(get("/api/v1/production/batches").cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.length()").value(1));

    JsonNode start = push(owner, op("op-start", batchId, "BATCH_START", null));
    assertThat(start.at("/data/results/0/status").asText()).isEqualTo("APPLIED");
    assertThat(start.at("/data/results/0/serverRecord/status").asText()).isEqualTo("INCUBATING");
  }

  @Test
  @DisplayName("a capacity conflict is rejected per operation and does not block the others")
  void rejectsOverCapacity() throws Exception {
    Session owner = newOwnerSession();
    String incubator = incubatorId(owner);
    JsonNode response =
        push(
            owner,
            op("op-big", UUID.randomUUID().toString(), "BATCH_CREATE", batch(incubator, 5000)),
            op("op-ok", UUID.randomUUID().toString(), "BATCH_CREATE", batch(incubator, 100)));
    assertThat(response.at("/data/results/0/status").asText()).isEqualTo("REJECTED");
    assertThat(response.at("/data/results/0/errorCode").asText()).isEqualTo("CAPACITY_CONFLICT");
    assertThat(response.at("/data/results/1/status").asText()).isEqualTo("APPLIED");
  }

  @Test
  @DisplayName("malformed, unknown and cross-farm operations are rejected")
  void rejectsInvalid() throws Exception {
    Session owner = newOwnerSession();
    Session other = newOwnerSession();
    String incubator = incubatorId(owner);
    String batchId =
        push(owner, op("op-c", UUID.randomUUID().toString(), "BATCH_CREATE", batch(incubator, 100)))
            .at("/data/results/0/serverRecord/id").asText();

    JsonNode response =
        push(
            owner,
            op("op-bad", UUID.randomUUID().toString(), "BATCH_CREATE", mapper.createObjectNode()),
            op("op-unknown", "x1", "DROP_TABLE", null));
    assertThat(response.at("/data/results/0/status").asText()).isEqualTo("REJECTED");
    assertThat(response.at("/data/results/0/errorCode").asText()).isEqualTo("VALIDATION_ERROR");
    assertThat(response.at("/data/results/1/status").asText()).isEqualTo("REJECTED");

    JsonNode foreign = push(other, op("op-x", batchId, "BATCH_START", null));
    assertThat(foreign.at("/data/results/0/status").asText()).isEqualTo("REJECTED");
    assertThat(foreign.at("/data/results/0/errorCode").asText()).isEqualTo("NOT_FOUND");
  }

  @Test
  @DisplayName("the snapshot returns every collection the pages read")
  void snapshot() throws Exception {
    Session owner = newOwnerSession();
    push(owner, op("op-s", UUID.randomUUID().toString(), "BATCH_CREATE", batch(incubatorId(owner), 100)));
    mvc.perform(get("/api/v1/production/snapshot").cookie(accessCookie(owner)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.settings.incubationDays").value(21))
        .andExpect(jsonPath("$.data.equipment.length()").value(3))
        .andExpect(jsonPath("$.data.batches.length()").value(1))
        .andExpect(jsonPath("$.data.reminders").isArray())
        .andExpect(jsonPath("$.data.occupancy").isArray())
        .andExpect(jsonPath("$.data.plans").isArray());
  }
}
