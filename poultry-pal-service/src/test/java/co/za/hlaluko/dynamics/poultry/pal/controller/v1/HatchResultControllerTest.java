package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
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

class HatchResultControllerTest extends V1TestSupport {
  private static final LocalDate TODAY = LocalDate.now();

  private ResultActions send(Session s, String method, String url, Object payload) throws Exception {
    var builder = method.equals("PUT") ? put(url) : post(url);
    builder.cookie(accessCookie(s)).contentType(MediaType.APPLICATION_JSON);
    if (payload != null) builder.content(mapper.writeValueAsString(payload));
    return mvc.perform(builder);
  }

  private JsonNode data(ResultActions a, int expected) throws Exception {
    return body(a.andExpect(status().is(expected)).andReturn()).get("data");
  }

  private String equipmentId(Session s, int index) throws Exception {
    return data(mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(s))), 200)
        .get(index)
        .get("id")
        .asText();
  }

  /** Creates a batch, starts it and reserves + transfers the given lots; returns the batch JSON. */
  private JsonNode transferredBatch(Session s, int eggs, int... lots) throws Exception {
    ObjectNode b = mapper.createObjectNode();
    b.put("equipmentId", equipmentId(s, 0));
    b.put("eggsSet", eggs);
    b.put("plannedStartDate", TODAY.plusDays(5).toString());
    JsonNode batch = data(send(s, "POST", "/api/v1/production/batches", b), 201);
    String id = batch.get("id").asText();
    ObjectNode start = mapper.createObjectNode();
    start.put("actualDate", TODAY.minusDays(20).toString());
    send(s, "POST", "/api/v1/production/batches/" + id + "/start", start).andExpect(status().isOk());
    for (int lot : lots) {
      ObjectNode c = mapper.createObjectNode();
      c.put("hatcherId", equipmentId(s, 1));
      c.put("quantity", lot);
      data(send(s, "POST", "/api/v1/production/batches/" + id + "/hatcher-cycles", c), 201);
    }
    JsonNode current = data(mvc.perform(get("/api/v1/production/batches/" + id).cookie(accessCookie(s))), 200);
    for (JsonNode cycle : current.get("hatcherCycles")) {
      ObjectNode t = mapper.createObjectNode();
      t.put("actualDate", TODAY.minusDays(2).toString());
      send(s, "POST", "/api/v1/production/hatcher-cycles/" + cycle.get("id").asText() + "/transfer", t)
          .andExpect(status().isOk());
    }
    return data(mvc.perform(get("/api/v1/production/batches/" + id).cookie(accessCookie(s))), 200);
  }

  private ObjectNode result(int hatched, int unhatched, LocalDate date) {
    ObjectNode n = mapper.createObjectNode();
    n.put("hatchedChicks", hatched);
    n.put("unhatchedEggs", unhatched);
    n.put("resultDate", date.toString());
    return n;
  }

  @Test
  @DisplayName("results must reconcile, complete the cycle and batch, and allow one per cycle")
  void recordsResult() throws Exception {
    Session owner = newOwnerSession();
    JsonNode batch = transferredBatch(owner, 400, 400);
    String cycle = batch.get("hatcherCycles").get(0).get("id").asText();
    String url = "/api/v1/production/hatcher-cycles/" + cycle + "/results";

    send(owner, "POST", url, result(300, 50, TODAY)).andExpect(status().isBadRequest());
    ObjectNode weak = result(350, 50, TODAY);
    weak.put("weakChicks", 900);
    send(owner, "POST", url, weak).andExpect(status().isBadRequest());
    send(owner, "POST", url, result(350, 50, TODAY.minusDays(5))).andExpect(status().isBadRequest());

    ObjectNode ok = result(340, 40, TODAY);
    ok.put("weakChicks", 17);
    ObjectNode cracked = mapper.createObjectNode();
    cracked.put("category", "Cracked");
    cracked.put("count", 20);
    ok.putArray("otherOutcomes").add(cracked);
    send(owner, "POST", url, ok)
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.data.hatchRate").value(85.0))
        .andExpect(jsonPath("$.data.eggsTransferred").value(400))
        .andExpect(jsonPath("$.data.weakRate").value(5.0));

    send(owner, "POST", url, ok).andExpect(status().isConflict());
    mvc.perform(get("/api/v1/production/batches/" + batch.get("id").asText()).cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.status").value("COMPLETED"))
        .andExpect(jsonPath("$.data.hatcherCycles[0].status").value("COMPLETED"));
  }

  @Test
  @DisplayName("a split batch completes only after every lot has a result")
  void splitBatch() throws Exception {
    Session owner = newOwnerSession();
    JsonNode batch = transferredBatch(owner, 400, 200, 200);
    String id = batch.get("id").asText();
    String a = batch.get("hatcherCycles").get(0).get("id").asText();
    String b = batch.get("hatcherCycles").get(1).get("id").asText();
    int qa = batch.get("hatcherCycles").get(0).get("quantity").asInt();
    int qb = batch.get("hatcherCycles").get(1).get("quantity").asInt();

    send(owner, "POST", "/api/v1/production/hatcher-cycles/" + a + "/results", result(qa - 10, 10, TODAY))
        .andExpect(status().isCreated());
    mvc.perform(get("/api/v1/production/batches/" + id).cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.status").value("TRANSFERRED"));
    send(owner, "POST", "/api/v1/production/hatcher-cycles/" + b + "/results", result(qb - 20, 20, TODAY))
        .andExpect(status().isCreated());
    mvc.perform(get("/api/v1/production/batches/" + id).cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.status").value("COMPLETED"));
  }

  @Test
  @DisplayName("edits are versioned and audited")
  void editsResult() throws Exception {
    Session owner = newOwnerSession();
    JsonNode batch = transferredBatch(owner, 400, 400);
    String url =
        "/api/v1/production/hatcher-cycles/" + batch.get("hatcherCycles").get(0).get("id").asText() + "/results";
    JsonNode created = data(send(owner, "POST", url, result(300, 100, TODAY)), 201);

    ObjectNode edit = result(360, 40, TODAY);
    send(owner, "PUT", url, edit).andExpect(status().isBadRequest());
    edit.put("version", created.get("version").asLong());
    send(owner, "PUT", url, edit)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.hatchRate").value(90.0))
        .andExpect(jsonPath("$.data.revisionCount").value(1));
    send(owner, "PUT", url, edit).andExpect(status().isConflict());
  }

  @Test
  @DisplayName("the report summarises, trends, filters, exports CSV and handles empty ranges")
  void report() throws Exception {
    Session owner = newOwnerSession();
    mvc.perform(get("/api/v1/production/reports/hatching").cookie(accessCookie(owner)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.summary.results").value(0))
        .andExpect(jsonPath("$.data.summary.hatchRate").doesNotExist())
        .andExpect(jsonPath("$.data.rows.length()").value(0));

    JsonNode b1 = transferredBatch(owner, 300, 300);
    JsonNode b2 = transferredBatch(owner, 100, 100);
    send(owner, "POST",
            "/api/v1/production/hatcher-cycles/" + b1.get("hatcherCycles").get(0).get("id").asText() + "/results",
            result(240, 60, TODAY))
        .andExpect(status().isCreated());
    send(owner, "POST",
            "/api/v1/production/hatcher-cycles/" + b2.get("hatcherCycles").get(0).get("id").asText() + "/results",
            result(90, 10, TODAY.minusDays(1)))
        .andExpect(status().isCreated());

    mvc.perform(get("/api/v1/production/reports/hatching").cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.summary.results").value(2))
        .andExpect(jsonPath("$.data.summary.eggsTransferred").value(400))
        .andExpect(jsonPath("$.data.summary.hatchRate").value(82.5))
        .andExpect(jsonPath("$.data.rows[0].resultDate").value(TODAY.toString()))
        .andExpect(jsonPath("$.data.totalElements").value(2));
    mvc.perform(get("/api/v1/production/reports/hatching?batchId=" + b2.get("id").asText() + "&size=1")
            .cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.summary.hatchRate").value(90.0))
        .andExpect(jsonPath("$.data.rows.length()").value(1));
    mvc.perform(get("/api/v1/production/reports/hatching?from=" + TODAY.plusDays(1)).cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.summary.results").value(0));
    mvc.perform(get("/api/v1/production/reports/hatching?from=" + TODAY + "&to=" + TODAY.minusDays(3))
            .cookie(accessCookie(owner)))
        .andExpect(status().isBadRequest());

    String csv =
        mvc.perform(get("/api/v1/production/reports/hatching.csv").cookie(accessCookie(owner)))
            .andExpect(status().isOk())
            .andReturn()
            .getResponse()
            .getContentAsString();
    assertEquals(3, csv.trim().split("\n").length);
    assertTrue(csv.startsWith("Result date,Batch"));
  }

  @Test
  @DisplayName("results are farm scoped")
  void isolation() throws Exception {
    Session owner = newOwnerSession();
    Session other = newOwnerSession();
    JsonNode batch = transferredBatch(owner, 100, 100);
    String url =
        "/api/v1/production/hatcher-cycles/" + batch.get("hatcherCycles").get(0).get("id").asText() + "/results";
    send(other, "POST", url, result(90, 10, TODAY)).andExpect(status().isNotFound());
    mvc.perform(get(url).cookie(accessCookie(other))).andExpect(status().isNotFound());
  }
}
