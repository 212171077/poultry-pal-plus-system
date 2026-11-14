package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import co.za.hlaluko.dynamics.poultry.pal.service.EquipmentUsageChecker;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

@Import(ProductionSettingsControllerTest.UsageConfig.class)
class ProductionSettingsControllerTest extends V1TestSupport {
  static final Map<String, Integer> USAGE = new ConcurrentHashMap<>();

  @TestConfiguration
  static class UsageConfig {
    @Bean
    EquipmentUsageChecker testUsageChecker() {
      return (farmId, equipmentId) ->
          USAGE.containsKey(equipmentId)
              ? new EquipmentUsageChecker.Usage(USAGE.get(equipmentId), List.of("BATCH-1"))
              : null;
    }
  }

  private JsonNode settings(Session s) throws Exception {
    return body(
            mvc.perform(get("/api/v1/production/settings").cookie(accessCookie(s)))
                .andExpect(status().isOk())
                .andReturn())
        .get("data");
  }

  private JsonNode equipment(Session s) throws Exception {
    return body(
            mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(s)))
                .andExpect(status().isOk())
                .andReturn())
        .get("data");
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

  private ResultActions putSettings(Session s, ObjectNode n) throws Exception {
    return mvc.perform(
        put("/api/v1/production/settings")
            .cookie(accessCookie(s))
            .contentType(MediaType.APPLICATION_JSON)
            .content(mapper.writeValueAsString(n)));
  }

  private ResultActions putEquipment(Session s, String id, ObjectNode n) throws Exception {
    return mvc.perform(
        put("/api/v1/production/equipment/{id}", id)
            .cookie(accessCookie(s))
            .contentType(MediaType.APPLICATION_JSON)
            .content(mapper.writeValueAsString(n)));
  }

  private ObjectNode equipmentBody(JsonNode e, int capacity) {
    ObjectNode n = mapper.createObjectNode();
    n.put("name", e.get("name").asText());
    n.put("capacity", capacity);
    n.put("enabled", true);
    n.put("version", e.get("version").asLong());
    return n;
  }

  @Test
  @DisplayName("first access seeds estimates and 2000/400/800 equipment, once")
  void seedsDefaults() throws Exception {
    Session owner = newOwnerSession();
    JsonNode s = settings(owner);
    org.junit.jupiter.api.Assertions.assertEquals(21, s.get("incubationDays").asInt());
    org.junit.jupiter.api.Assertions.assertEquals(18, s.get("transferDay").asInt());
    org.junit.jupiter.api.Assertions.assertTrue(s.get("estimatesOnly").asBoolean());

    JsonNode list = equipment(owner);
    org.junit.jupiter.api.Assertions.assertEquals(3, list.size());
    org.junit.jupiter.api.Assertions.assertEquals(2000, list.get(0).get("capacity").asInt());
    settings(owner);
    org.junit.jupiter.api.Assertions.assertEquals(3, equipment(owner).size());
  }

  @Test
  @DisplayName("settings update validates input and rejects stale versions")
  void settingsUpdate() throws Exception {
    Session owner = newOwnerSession();
    JsonNode current = settings(owner);

    ObjectNode update = settingsBody(current);
    update.put("expectedHatchRate", 0.85);
    update.put("supplierLeadTimeDays", 7);
    putSettings(owner, update)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.estimatesOnly").value(false))
        .andExpect(jsonPath("$.data.supplierLeadTimeDays").value(7));

    putSettings(owner, update).andExpect(status().isConflict());

    ObjectNode fresh = settingsBody(settings(owner));
    fresh.put("expectedHatchRate", 1.2);
    putSettings(owner, fresh).andExpect(status().isBadRequest());

    fresh = settingsBody(settings(owner));
    fresh.put("timeZone", "Mars/Olympus");
    putSettings(owner, fresh).andExpect(status().isBadRequest());

    fresh = settingsBody(settings(owner));
    fresh.put("transferDay", 21);
    putSettings(owner, fresh).andExpect(status().isBadRequest());
  }

  @Test
  @DisplayName("equipment can be added, validated, edited and archived")
  void equipmentCrud() throws Exception {
    Session owner = newOwnerSession();
    JsonNode first = equipment(owner).get(0);

    ObjectNode create = mapper.createObjectNode();
    create.put("type", "INCUBATOR");
    create.put("name", "Incubator 2");
    create.put("capacity", 1500);
    mvc.perform(
            post("/api/v1/production/equipment")
                .cookie(accessCookie(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(create)))
        .andExpect(status().isCreated());
    mvc.perform(
            post("/api/v1/production/equipment")
                .cookie(accessCookie(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(create)))
        .andExpect(status().isConflict());
    create.put("name", "Bad").put("capacity", 0);
    mvc.perform(
            post("/api/v1/production/equipment")
                .cookie(accessCookie(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(create)))
        .andExpect(status().isBadRequest());

    putEquipment(owner, first.get("id").asText(), equipmentBody(first, 2500))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.capacity").value(2500));
    putEquipment(owner, first.get("id").asText(), equipmentBody(first, 2600))
        .andExpect(status().isConflict());

    mvc.perform(delete("/api/v1/production/equipment/{id}", first.get("id").asText())
            .cookie(accessCookie(owner)))
        .andExpect(status().isOk());
    org.junit.jupiter.api.Assertions.assertEquals(3, equipment(owner).size());
  }

  @Test
  @DisplayName("lowering capacity below committed usage returns 409 CAPACITY_CONFLICT")
  void capacityConflict() throws Exception {
    Session owner = newOwnerSession();
    JsonNode hatcher = equipment(owner).get(1);
    USAGE.put(hatcher.get("id").asText(), 300);

    putEquipment(owner, hatcher.get("id").asText(), equipmentBody(hatcher, 200))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("CAPACITY_CONFLICT"))
        .andExpect(jsonPath("$.details.requested").value(300))
        .andExpect(jsonPath("$.details.available").value(200))
        .andExpect(jsonPath("$.details.conflictingReferences[0]").value("BATCH-1"));
    putEquipment(owner, hatcher.get("id").asText(), equipmentBody(hatcher, 300))
        .andExpect(status().isOk());
    mvc.perform(delete("/api/v1/production/equipment/{id}", hatcher.get("id").asText())
            .cookie(accessCookie(owner)))
        .andExpect(status().isConflict());
  }

  @Test
  @DisplayName("settings and equipment need the grant and are isolated per farm")
  void authorizationAndIsolation() throws Exception {
    Session ownerA = newOwnerSession();
    Session ownerB = newOwnerSession();
    Session worker = signin(createWorker(ownerA.farmId()));
    JsonNode equipmentA = equipment(ownerA).get(0);

    mvc.perform(get("/api/v1/production/settings").cookie(accessCookie(worker)))
        .andExpect(status().isForbidden());
    mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(worker)))
        .andExpect(status().isForbidden());
    putEquipment(ownerB, equipmentA.get("id").asText(), equipmentBody(equipmentA, 10))
        .andExpect(status().isNotFound());
    mvc.perform(delete("/api/v1/production/equipment/{id}", equipmentA.get("id").asText())
            .cookie(accessCookie(ownerB)))
        .andExpect(status().isNotFound());
    org.junit.jupiter.api.Assertions.assertEquals(
        ownerB.farmId(), settings(ownerB).get("farmId").asText());
  }
}
