package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

class ProductionReminderControllerTest extends V1TestSupport {
  private static final LocalDate START = LocalDate.now().plusDays(10);

  private ResultActions send(Session s, String method, String url, Object payload) throws Exception {
    var builder = method.equals("PUT") ? put(url) : post(url);
    builder.cookie(accessCookie(s)).contentType(MediaType.APPLICATION_JSON);
    if (payload != null) builder.content(mapper.writeValueAsString(payload));
    return mvc.perform(builder);
  }

  private JsonNode data(ResultActions actions) throws Exception {
    return body(actions.andExpect(status().isOk()).andReturn()).get("data");
  }

  private JsonNode reminders(Session s, String status) throws Exception {
    return data(
        mvc.perform(get("/api/v1/production/reminders?status=" + status).cookie(accessCookie(s))));
  }

  private Map<String, String> dueByRule(JsonNode list) {
    Map<String, String> result = new HashMap<>();
    list.forEach(r -> result.put(r.get("title").asText(), r.get("dueDate").asText()));
    return result;
  }

  private JsonNode incubator(Session s) throws Exception {
    return data(mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(s)))).get(0);
  }

  private JsonNode createBatch(Session s, LocalDate start) throws Exception {
    ObjectNode n = mapper.createObjectNode();
    n.put("equipmentId", incubator(s).get("id").asText());
    n.put("eggsSet", 500);
    n.put("plannedStartDate", start.toString());
    return body(send(s, "POST", "/api/v1/production/batches", n)
            .andExpect(status().isCreated())
            .andReturn())
        .get("data");
  }

  private ObjectNode batchUpdate(Session s, JsonNode batch, LocalDate start) throws Exception {
    ObjectNode n = mapper.createObjectNode();
    n.put("equipmentId", batch.get("equipmentId").asText());
    n.put("eggsSet", batch.get("eggsSet").asInt());
    n.put("plannedStartDate", start.toString());
    n.put("version", batch.get("version").asLong());
    return n;
  }

  @Test
  @DisplayName("creating a batch generates one reminder per default rule, without duplicates")
  void generatesReminders() throws Exception {
    Session owner = newOwnerSession();
    createBatch(owner, START);

    JsonNode open = reminders(owner, "OPEN");
    assertEquals(4, open.size());
    Map<String, String> due = dueByRule(open);
    assertEquals(START.plusDays(18).toString(), due.get("Transfer eggs to the hatcher"));
    assertEquals(START.plusDays(19).toString(), due.get("Prepare the brooder for chicks"));
    assertEquals(START.plusDays(21).toString(), due.get("Vaccinate day-old chicks"));
    assertEquals(4, reminders(owner, "OPEN").size());
  }

  @Test
  @DisplayName("date changes move open reminders and leave completed ones untouched")
  void dateChanges() throws Exception {
    Session owner = newOwnerSession();
    JsonNode batch = createBatch(owner, START);
    String id = batch.get("id").asText();
    JsonNode first = reminders(owner, "OPEN").get(0);

    send(owner, "POST", "/api/v1/production/reminders/" + first.get("id").asText() + "/complete", null)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.status").value("COMPLETED"))
        .andExpect(jsonPath("$.data.completedBy").isNotEmpty());
    send(owner, "POST", "/api/v1/production/reminders/" + first.get("id").asText() + "/complete", null)
        .andExpect(status().isOk());

    send(owner, "PUT", "/api/v1/production/batches/" + id, batchUpdate(owner, batch, START.plusDays(2)))
        .andExpect(status().isOk());

    JsonNode open = reminders(owner, "OPEN");
    JsonNode done = reminders(owner, "COMPLETED");
    assertEquals(3, open.size());
    assertEquals(1, done.size());
    assertEquals(first.get("dueDate").asText(), done.get(0).get("dueDate").asText());
    open.forEach(r -> org.junit.jupiter.api.Assertions.assertTrue(
        LocalDate.parse(r.get("dueDate").asText()).isAfter(START.plusDays(18))));
  }

  @Test
  @DisplayName("changing offsets and rules updates reminders idempotently")
  void ruleChanges() throws Exception {
    Session owner = newOwnerSession();
    createBatch(owner, START);
    JsonNode settings = data(mvc.perform(get("/api/v1/production/settings").cookie(accessCookie(owner))));

    ObjectNode update = settingsBody(settings);
    ArrayNode rules = (ArrayNode) settings.get("reminderRules").deepCopy();
    for (JsonNode rule : rules) {
      ObjectNode r = (ObjectNode) rule;
      if (r.get("key").asText().equals("PACKAGING")) r.put("enabled", false);
      if (r.get("key").asText().equals("BROODER")) r.put("offsetDays", -3);
    }
    ObjectNode custom = mapper.createObjectNode();
    custom.put("taskType", "CUSTOM");
    custom.put("anchor", "BATCH_START");
    custom.put("offsetDays", -1);
    custom.put("title", "Disinfect the incubator");
    custom.put("enabled", true);
    rules.add(custom);
    update.set("reminderRules", rules);
    JsonNode saved = data(send(owner, "PUT", "/api/v1/production/settings", update));
    assertEquals(5, saved.get("reminderRules").size());

    JsonNode open = reminders(owner, "OPEN");
    assertEquals(4, open.size());
    Map<String, String> due = dueByRule(open);
    assertEquals(START.plusDays(18).toString(), due.get("Prepare the brooder for chicks"));
    assertEquals(START.minusDays(1).toString(), due.get("Disinfect the incubator"));
    assertEquals(1, reminders(owner, "CANCELLED").size());

    ObjectNode again = settingsBody(saved);
    again.set("reminderRules", saved.get("reminderRules"));
    data(send(owner, "PUT", "/api/v1/production/settings", again));
    assertEquals(4, reminders(owner, "OPEN").size());
    assertEquals(1, reminders(owner, "CANCELLED").size());

    ObjectNode duplicateKeys = settingsBody(settings(owner));
    ArrayNode dup = mapper.createArrayNode();
    dup.add(saved.get("reminderRules").get(0));
    dup.add(saved.get("reminderRules").get(0));
    duplicateKeys.set("reminderRules", dup);
    send(owner, "PUT", "/api/v1/production/settings", duplicateKeys).andExpect(status().isBadRequest());
  }

  @Test
  @DisplayName("cancelling a batch cancels its open reminders")
  void cancelBatch() throws Exception {
    Session owner = newOwnerSession();
    JsonNode batch = createBatch(owner, START);
    send(owner, "POST", "/api/v1/production/batches/" + batch.get("id").asText() + "/cancel", null)
        .andExpect(status().isOk());
    assertEquals(0, reminders(owner, "OPEN").size());
    assertEquals(4, reminders(owner, "CANCELLED").size());
  }

  @Test
  @DisplayName("reminders are farm scoped")
  void isolation() throws Exception {
    Session owner = newOwnerSession();
    Session other = newOwnerSession();
    createBatch(owner, START);
    String id = reminders(owner, "OPEN").get(0).get("id").asText();
    send(other, "POST", "/api/v1/production/reminders/" + id + "/complete", null)
        .andExpect(status().isNotFound());
    assertEquals(0, reminders(other, "OPEN").size());
  }

  private JsonNode settings(Session s) throws Exception {
    return data(mvc.perform(get("/api/v1/production/settings").cookie(accessCookie(s))));
  }

  private ObjectNode settingsBody(JsonNode current) {
    ObjectNode n = mapper.createObjectNode();
    n.put("timeZone", current.get("timeZone").asText());
    n.put("incubationDays", current.get("incubationDays").asInt());
    n.put("transferDay", current.get("transferDay").asInt());
    n.put("broodingDays", current.get("broodingDays").asInt());
    n.put("expectedHatchRate", current.get("expectedHatchRate").asDouble());
    n.put("expectedMortalityRate", current.get("expectedMortalityRate").asDouble());
    n.put("defaultGrowOutDays", current.get("defaultGrowOutDays").asInt());
    n.put("version", current.get("version").asLong());
    return n;
  }
}
