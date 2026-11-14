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

class PlacementControllerTest extends V1TestSupport {
  private static final LocalDate TODAY = LocalDate.now();

  private ResultActions send(Session s, String method, String url, Object payload, String key) throws Exception {
    var builder = method.equals("PUT") ? put(url) : post(url);
    builder.cookie(accessCookie(s)).contentType(MediaType.APPLICATION_JSON);
    if (key != null) builder.header("Idempotency-Key", key);
    if (payload != null) builder.content(mapper.writeValueAsString(payload));
    return mvc.perform(builder);
  }

  private ResultActions send(Session s, String method, String url, Object payload) throws Exception {
    return send(s, method, url, payload, null);
  }

  private JsonNode data(ResultActions a, int expected) throws Exception {
    return body(a.andExpect(status().is(expected)).andReturn()).get("data");
  }

  private JsonNode equipment(Session s, int index) throws Exception {
    return data(mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(s))), 200).get(index);
  }

  private ObjectNode purchased(String houseId, int quantity) {
    ObjectNode n = mapper.createObjectNode();
    n.put("source", "PURCHASED_DAY_OLD");
    n.put("sourceReference", "Supplier A");
    n.put("houseId", houseId);
    n.put("quantity", quantity);
    n.put("placementDate", TODAY.toString());
    return n;
  }

  private ObjectNode movement(String type, int count, LocalDate date) {
    ObjectNode n = mapper.createObjectNode();
    n.put("type", type);
    n.put("count", count);
    n.put("date", date.toString());
    return n;
  }

  private JsonNode place(Session s, int quantity) throws Exception {
    return data(send(s, "POST", "/api/v1/production/placements", purchased(equipment(s, 2).get("id").asText(), quantity)), 201);
  }

  @Test
  @DisplayName("placements are limited by house capacity and occupancy is derived")
  void capacity() throws Exception {
    Session owner = newOwnerSession();
    String house = equipment(owner, 2).get("id").asText();
    place(owner, 500);
    send(owner, "POST", "/api/v1/production/placements", purchased(house, 400))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("CAPACITY_CONFLICT"))
        .andExpect(jsonPath("$.details.requested").value(900))
        .andExpect(jsonPath("$.details.available").value(800));
    place(owner, 300);
    mvc.perform(get("/api/v1/production/occupancy").cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data[0].occupied").value(800))
        .andExpect(jsonPath("$.data[0].available").value(0));

    ObjectNode future = purchased(house, 1);
    future.put("placementDate", TODAY.plusDays(1).toString());
    send(owner, "POST", "/api/v1/production/placements", future).andExpect(status().isBadRequest());
    send(owner, "POST", "/api/v1/production/placements", purchased(equipment(owner, 0).get("id").asText(), 1))
        .andExpect(status().isBadRequest());
  }

  @Test
  @DisplayName("movements reduce occupancy and never push a placement below zero")
  void movements() throws Exception {
    Session owner = newOwnerSession();
    JsonNode placement = place(owner, 500);
    String url = "/api/v1/production/placements/" + placement.get("id").asText() + "/movements";

    send(owner, "POST", url, movement("MORTALITY", 10, TODAY)).andExpect(status().isCreated());
    send(owner, "POST", url, movement("SALE", 100, TODAY)).andExpect(status().isCreated());
    send(owner, "POST", url, movement("SALE", 600, TODAY)).andExpect(status().isBadRequest());
    send(owner, "POST", url, movement("MORTALITY", 1, TODAY.plusDays(1))).andExpect(status().isBadRequest());
    send(owner, "POST", url, movement("MORTALITY", 1, TODAY.minusDays(1))).andExpect(status().isBadRequest());
    ObjectNode add = movement("SALE", 1, TODAY);
    add.put("increase", true);
    send(owner, "POST", url, add).andExpect(status().isBadRequest());
    send(owner, "POST", url, movement("CORRECTION", 1, TODAY)).andExpect(status().isBadRequest());

    mvc.perform(get("/api/v1/production/placements/" + placement.get("id").asText()).cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.remaining").value(390))
        .andExpect(jsonPath("$.data.mortality").value(10))
        .andExpect(jsonPath("$.data.sold").value(100))
        .andExpect(jsonPath("$.data.movements.length()").value(2));

    send(owner, "POST", url, movement("OTHER_REMOVAL", 390, TODAY)).andExpect(status().isCreated());
    mvc.perform(get("/api/v1/production/placements?activeOnly=true").cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.length()").value(0));
    mvc.perform(get("/api/v1/production/placements").cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data[0].status").value("CLOSED"));
  }

  @Test
  @DisplayName("corrections add or remove birds explicitly and respect capacity")
  void corrections() throws Exception {
    Session owner = newOwnerSession();
    JsonNode a = place(owner, 800);
    String url = "/api/v1/production/placements/" + a.get("id").asText() + "/movements";
    ObjectNode up = movement("CORRECTION", 5, TODAY);
    up.put("increase", true);
    up.put("reason", "Miscounted");
    send(owner, "POST", url, up)
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("CAPACITY_CONFLICT"));

    send(owner, "POST", url, movement("MORTALITY", 20, TODAY)).andExpect(status().isCreated());
    send(owner, "POST", url, up).andExpect(status().isCreated());
    mvc.perform(get("/api/v1/production/placements/" + a.get("id").asText()).cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.remaining").value(785));
  }

  @Test
  @DisplayName("an Idempotency-Key makes a retried movement a no-op")
  void idempotency() throws Exception {
    Session owner = newOwnerSession();
    JsonNode a = place(owner, 100);
    String url = "/api/v1/production/placements/" + a.get("id").asText() + "/movements";
    JsonNode first = data(send(owner, "POST", url, movement("MORTALITY", 5, TODAY), "key-1"), 201);
    JsonNode second = data(send(owner, "POST", url, movement("MORTALITY", 5, TODAY), "key-1"), 201);
    assertEquals(first.get("id").asText(), second.get("id").asText());
    mvc.perform(get("/api/v1/production/placements/" + a.get("id").asText()).cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.remaining").value(95))
        .andExpect(jsonPath("$.data.movements.length()").value(1));

    JsonNode b = place(owner, 100);
    send(owner, "POST", "/api/v1/production/placements/" + b.get("id").asText() + "/movements",
            movement("MORTALITY", 5, TODAY), "key-1")
        .andExpect(status().isConflict());
  }

  @Test
  @DisplayName("own-hatch placements need a recorded result and cannot exceed hatched chicks")
  void ownHatch() throws Exception {
    Session owner = newOwnerSession();
    String house = equipment(owner, 2).get("id").asText();
    ObjectNode b = mapper.createObjectNode();
    b.put("equipmentId", equipment(owner, 0).get("id").asText());
    b.put("eggsSet", 400);
    b.put("plannedStartDate", TODAY.plusDays(5).toString());
    String batchId = data(send(owner, "POST", "/api/v1/production/batches", b), 201).get("id").asText();
    ObjectNode start = mapper.createObjectNode();
    start.put("actualDate", TODAY.minusDays(20).toString());
    send(owner, "POST", "/api/v1/production/batches/" + batchId + "/start", start).andExpect(status().isOk());
    ObjectNode cycle = mapper.createObjectNode();
    cycle.put("hatcherId", equipment(owner, 1).get("id").asText());
    cycle.put("quantity", 400);
    String cycleId = data(send(owner, "POST", "/api/v1/production/batches/" + batchId + "/hatcher-cycles", cycle), 201)
        .get("hatcherCycles").get(0).get("id").asText();
    ObjectNode transfer = mapper.createObjectNode();
    transfer.put("actualDate", TODAY.minusDays(2).toString());
    send(owner, "POST", "/api/v1/production/hatcher-cycles/" + cycleId + "/transfer", transfer).andExpect(status().isOk());

    ObjectNode own = purchased(house, 100);
    own.put("source", "OWN_HATCH");
    own.put("sourceCycleId", cycleId);
    send(owner, "POST", "/api/v1/production/placements", own).andExpect(status().isConflict());

    ObjectNode result = mapper.createObjectNode();
    result.put("hatchedChicks", 340);
    result.put("unhatchedEggs", 60);
    result.put("resultDate", TODAY.toString());
    send(owner, "POST", "/api/v1/production/hatcher-cycles/" + cycleId + "/results", result).andExpect(status().isCreated());

    own.put("quantity", 300);
    send(owner, "POST", "/api/v1/production/placements", own)
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.data.sourceReference").isNotEmpty());
    own.put("quantity", 100);
    send(owner, "POST", "/api/v1/production/placements", own).andExpect(status().isBadRequest());
    own.put("quantity", 40);
    send(owner, "POST", "/api/v1/production/placements", own).andExpect(status().isCreated());
  }

  @Test
  @DisplayName("house capacity cannot drop below current occupancy")
  void houseCapacityGuard() throws Exception {
    Session owner = newOwnerSession();
    place(owner, 500);
    JsonNode house = equipment(owner, 2);
    ObjectNode update = mapper.createObjectNode();
    update.put("name", house.get("name").asText());
    update.put("capacity", 400);
    update.put("enabled", true);
    update.put("version", house.get("version").asLong());
    send(owner, "PUT", "/api/v1/production/equipment/" + house.get("id").asText(), update)
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("CAPACITY_CONFLICT"));
    update.put("capacity", 600);
    send(owner, "PUT", "/api/v1/production/equipment/" + house.get("id").asText(), update).andExpect(status().isOk());
  }

  @Test
  @DisplayName("placements are farm scoped")
  void isolation() throws Exception {
    Session owner = newOwnerSession();
    Session other = newOwnerSession();
    JsonNode a = place(owner, 10);
    mvc.perform(get("/api/v1/production/placements/" + a.get("id").asText()).cookie(accessCookie(other)))
        .andExpect(status().isNotFound());
    send(other, "POST", "/api/v1/production/placements/" + a.get("id").asText() + "/movements",
            movement("MORTALITY", 1, TODAY))
        .andExpect(status().isNotFound());
    mvc.perform(get("/api/v1/production/placements").cookie(accessCookie(other)))
        .andExpect(jsonPath("$.data.length()").value(0));
  }
}
