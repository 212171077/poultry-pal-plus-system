package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.time.LocalDate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

class IncubationControllerTest extends V1TestSupport {
  private static final LocalDate START = LocalDate.now().plusDays(10);

  private JsonNode equipment(Session s, int index) throws Exception {
    return body(
            mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(s)))
                .andExpect(status().isOk())
                .andReturn())
        .get("data")
        .get(index);
  }

  private ResultActions send(Session s, String method, String url, Object payload) throws Exception {
    var builder = method.equals("PUT") ? put(url) : post(url);
    builder.cookie(accessCookie(s)).contentType(MediaType.APPLICATION_JSON);
    if (payload != null) builder.content(mapper.writeValueAsString(payload));
    return mvc.perform(builder);
  }

  private ObjectNode batchBody(String equipmentId, int eggs, LocalDate start) {
    ObjectNode n = mapper.createObjectNode();
    n.put("equipmentId", equipmentId);
    n.put("eggsSet", eggs);
    n.put("plannedStartDate", start.toString());
    return n;
  }

  private ObjectNode cycleBody(String hatcherId, int quantity) {
    ObjectNode n = mapper.createObjectNode();
    n.put("hatcherId", hatcherId);
    n.put("quantity", quantity);
    return n;
  }

  private JsonNode createBatch(Session s, String incubatorId, int eggs, LocalDate start) throws Exception {
    return body(
            send(s, "POST", "/api/v1/production/batches", batchBody(incubatorId, eggs, start))
                .andExpect(status().isCreated())
                .andReturn())
        .get("data");
  }

  @Test
  @DisplayName("a batch gets a reference and day-18 / day-21 dates")
  void createsBatch() throws Exception {
    Session owner = newOwnerSession();
    JsonNode incubator = equipment(owner, 0);
    JsonNode batch = createBatch(owner, incubator.get("id").asText(), 1500, START);
    assertEquals(START.plusDays(18).toString(), batch.get("plannedTransferDate").asText());
    assertEquals(START.plusDays(21).toString(), batch.get("plannedHatchDate").asText());
    assertEquals("PLANNED", batch.get("status").asText());
    assertEquals(1500, batch.get("eggsUnassigned").asInt());

    mvc.perform(get("/api/v1/production/batches").cookie(accessCookie(owner)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.length()").value(1));

    ObjectNode duplicate = batchBody(incubator.get("id").asText(), 100, START);
    duplicate.put("reference", batch.get("reference").asText());
    send(owner, "POST", "/api/v1/production/batches", duplicate).andExpect(status().isConflict());
    send(owner, "POST", "/api/v1/production/batches", batchBody(incubator.get("id").asText(), 0, START))
        .andExpect(status().isBadRequest());
  }

  @Test
  @DisplayName("overlapping batches are limited by incubator capacity; later batches fit")
  void incubatorCapacity() throws Exception {
    Session owner = newOwnerSession();
    String incubator = equipment(owner, 0).get("id").asText();
    createBatch(owner, incubator, 1200, START);

    send(owner, "POST", "/api/v1/production/batches", batchBody(incubator, 1000, START.plusDays(5)))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("CAPACITY_CONFLICT"))
        .andExpect(jsonPath("$.details.requested").value(2200))
        .andExpect(jsonPath("$.details.available").value(2000))
        .andExpect(jsonPath("$.details.conflictingReferences.length()").value(1));
    send(owner, "POST", "/api/v1/production/batches", batchBody(incubator, 800, START.plusDays(5)))
        .andExpect(status().isCreated());
    createBatch(owner, incubator, 2000, START.plusDays(23));
  }

  @Test
  @DisplayName("hatcher cycles reconcile with the batch and respect hatcher capacity")
  void hatcherCapacity() throws Exception {
    Session owner = newOwnerSession();
    String incubator = equipment(owner, 0).get("id").asText();
    String hatcher = equipment(owner, 1).get("id").asText();
    JsonNode batch = createBatch(owner, incubator, 1000, START);
    String url = "/api/v1/production/batches/" + batch.get("id").asText() + "/hatcher-cycles";

    send(owner, "POST", url, cycleBody(hatcher, 400))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.data.eggsReserved").value(400))
        .andExpect(jsonPath("$.data.eggsUnassigned").value(600));
    send(owner, "POST", url, cycleBody(hatcher, 100))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("CAPACITY_CONFLICT"))
        .andExpect(jsonPath("$.details.available").value(400));
    send(owner, "POST", url, cycleBody(hatcher, 700)).andExpect(status().isBadRequest());
    send(owner, "POST", url, cycleBody(incubator, 100)).andExpect(status().isBadRequest());

    JsonNode second = createBatch(owner, incubator, 400, START.plusDays(3));
    send(
            owner,
            "POST",
            "/api/v1/production/batches/" + second.get("id").asText() + "/hatcher-cycles",
            cycleBody(hatcher, 400))
        .andExpect(status().isCreated());

    mvc.perform(get(url).cookie(accessCookie(owner)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.length()").value(1));
  }

  @Test
  @DisplayName("start, transfer, complete transfer and cancellation rules")
  void lifecycle() throws Exception {
    Session owner = newOwnerSession();
    String incubator = equipment(owner, 0).get("id").asText();
    String hatcher = equipment(owner, 1).get("id").asText();
    JsonNode batch = createBatch(owner, incubator, 300, START);
    String base = "/api/v1/production/batches/" + batch.get("id").asText();

    JsonNode withCycle = body(send(owner, "POST", base + "/hatcher-cycles", cycleBody(hatcher, 300))
            .andExpect(status().isCreated())
            .andReturn())
        .get("data");
    String cycleId = withCycle.get("hatcherCycles").get(0).get("id").asText();

    send(owner, "POST", "/api/v1/production/hatcher-cycles/" + cycleId + "/transfer", null)
        .andExpect(status().isConflict());

    ObjectNode shifted = mapper.createObjectNode();
    shifted.put("actualDate", START.plusDays(1).toString());
    send(owner, "POST", base + "/start", shifted)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.status").value("INCUBATING"))
        .andExpect(jsonPath("$.data.plannedHatchDate").value(START.plusDays(22).toString()))
        .andExpect(jsonPath("$.data.hatcherCycles[0].plannedTransferDate")
            .value(START.plusDays(19).toString()));
    ObjectNode edit = batchBody(incubator, 300, START);
    edit.put("version", 0);
    send(owner, "PUT", base, edit).andExpect(status().isConflict());

    send(owner, "POST", "/api/v1/production/hatcher-cycles/" + cycleId + "/transfer", null)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.status").value("TRANSFERRED"))
        .andExpect(jsonPath("$.data.hatcherCycles[0].status").value("IN_HATCHER"));
    send(owner, "POST", base + "/cancel", null).andExpect(status().isConflict());
  }

  @Test
  @DisplayName("cancelling a batch releases its reservations; planned batches can be edited")
  void cancelAndEdit() throws Exception {
    Session owner = newOwnerSession();
    String incubator = equipment(owner, 0).get("id").asText();
    String hatcher = equipment(owner, 1).get("id").asText();
    JsonNode batch = createBatch(owner, incubator, 400, START);
    String base = "/api/v1/production/batches/" + batch.get("id").asText();
    send(owner, "POST", base + "/hatcher-cycles", cycleBody(hatcher, 400)).andExpect(status().isCreated());

    ObjectNode edit = batchBody(incubator, 300, START.plusDays(2));
    edit.put("version", batch.get("version").asLong());
    send(owner, "PUT", base, edit).andExpect(status().isBadRequest());

    edit = batchBody(incubator, 400, START.plusDays(2));
    edit.put("version", batch.get("version").asLong());
    send(owner, "PUT", base, edit)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.plannedHatchDate").value(START.plusDays(23).toString()));
    send(owner, "PUT", base, edit).andExpect(status().isConflict());

    send(owner, "POST", base + "/cancel", null)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.status").value("CANCELLED"))
        .andExpect(jsonPath("$.data.eggsReserved").value(0));
    JsonNode again = createBatch(owner, incubator, 400, START.plusDays(2));
    send(owner, "POST", "/api/v1/production/batches/" + again.get("id").asText() + "/hatcher-cycles",
            cycleBody(hatcher, 400))
        .andExpect(status().isCreated());
  }

  @Test
  @DisplayName("equipment capacity cannot drop below planned batches")
  void capacityChangeConflict() throws Exception {
    Session owner = newOwnerSession();
    JsonNode incubator = equipment(owner, 0);
    createBatch(owner, incubator.get("id").asText(), 1500, START);

    ObjectNode lower = mapper.createObjectNode();
    lower.put("name", incubator.get("name").asText());
    lower.put("capacity", 1000);
    lower.put("enabled", true);
    lower.put("version", incubator.get("version").asLong());
    send(owner, "PUT", "/api/v1/production/equipment/" + incubator.get("id").asText(), lower)
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("CAPACITY_CONFLICT"))
        .andExpect(jsonPath("$.details.requested").value(1500));
  }

  @Test
  @DisplayName("another farm cannot see or use this farm's batches and equipment")
  void farmIsolation() throws Exception {
    Session owner = newOwnerSession();
    Session other = newOwnerSession();
    String incubator = equipment(owner, 0).get("id").asText();
    JsonNode batch = createBatch(owner, incubator, 500, START);
    String base = "/api/v1/production/batches/" + batch.get("id").asText();

    mvc.perform(get(base).cookie(accessCookie(other))).andExpect(status().isNotFound());
    send(other, "POST", base + "/start", null).andExpect(status().isNotFound());
    send(other, "POST", base + "/hatcher-cycles", cycleBody(equipment(other, 1).get("id").asText(), 100))
        .andExpect(status().isNotFound());
    send(other, "POST", "/api/v1/production/batches", batchBody(incubator, 100, START))
        .andExpect(status().isNotFound());
    mvc.perform(get("/api/v1/production/batches").cookie(accessCookie(other)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.length()").value(0));
  }
}
