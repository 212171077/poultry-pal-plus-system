package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.time.LocalDate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

class PlanningControllerTest extends V1TestSupport {
  private static final LocalDate TODAY = LocalDate.now();

  private ResultActions send(Session s, String url, Object payload) throws Exception {
    var b = post(url).cookie(accessCookie(s)).contentType(MediaType.APPLICATION_JSON);
    if (payload != null) b.content(mapper.writeValueAsString(payload));
    return mvc.perform(b);
  }

  private ObjectNode plan(String method, int quantity, int readyInDays) {
    ObjectNode n = mapper.createObjectNode();
    n.put("sourceMethod", method);
    n.put("targetQuantity", quantity);
    n.put("targetReadyDate", TODAY.plusDays(readyInDays).toString());
    return n;
  }

  private String saved(Session s, ObjectNode request) throws Exception {
    return body(send(s, "/api/v1/production/plans", request).andExpect(status().isCreated()).andReturn())
        .get("data").get("id").asText();
  }

  @Test
  @DisplayName("own eggs: quantities round up and dates work back from the target")
  void calculateOwnEggs() throws Exception {
    Session owner = newOwnerSession();
    send(owner, "/api/v1/production/plans/calculate", plan("INCUBATE_EGGS", 300, 100))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.eggsRequired").value(395))
        .andExpect(jsonPath("$.data.chicksRequired").value(316))
        .andExpect(jsonPath("$.data.incubationStartDate").value(TODAY.plusDays(37).toString()))
        .andExpect(jsonPath("$.data.transferDate").value(TODAY.plusDays(55).toString()))
        .andExpect(jsonPath("$.data.feasible").value(true));
  }

  @Test
  @DisplayName("purchased chicks have an arrival date but no deadline without a lead time")
  void calculatePurchased() throws Exception {
    Session owner = newOwnerSession();
    send(owner, "/api/v1/production/plans/calculate", plan("PURCHASE_DAY_OLD_CHICKS", 300, 100))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.hatchOrArrivalDate").value(TODAY.plusDays(58).toString()))
        .andExpect(jsonPath("$.data.latestOrderDate").doesNotExist())
        .andExpect(jsonPath("$.data.eggsRequired").doesNotExist());
  }

  private void growOutDays(Session owner, int days) throws Exception {
    JsonNode current = body(mvc.perform(get("/api/v1/production/settings").cookie(accessCookie(owner))).andReturn())
        .get("data");
    ObjectNode n = mapper.createObjectNode();
    for (String k : new String[] {"timeZone", "incubationDays", "transferDay", "broodingDays",
        "expectedHatchRate", "expectedMortalityRate", "version"}) {
      n.set(k, current.get(k));
    }
    n.put("defaultGrowOutDays", days);
    mvc.perform(put("/api/v1/production/settings").cookie(accessCookie(owner))
            .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
            .content(mapper.writeValueAsString(n)))
        .andExpect(status().isOk());
  }

  @Test
  @DisplayName("past start dates and too many birds are reported as constraints")
  void constraints() throws Exception {
    Session owner = newOwnerSession();
    send(owner, "/api/v1/production/plans/calculate", plan("INCUBATE_EGGS", 300, 30))
        .andExpect(jsonPath("$.data.feasible").value(false))
        .andExpect(jsonPath("$.data.constraints[0]").value(org.hamcrest.Matchers.containsString("already passed")));
    send(owner, "/api/v1/production/plans/calculate", plan("INCUBATE_EGGS", 500, 100))
        .andExpect(jsonPath("$.data.feasible").value(false))
        .andExpect(jsonPath("$.data.constraints[0]").value(org.hamcrest.Matchers.containsString("capacity")));
    ObjectNode bad = plan("INCUBATE_EGGS", 0, 100);
    send(owner, "/api/v1/production/plans/calculate", bad).andExpect(status().isBadRequest());
  }

  @Test
  @DisplayName("a changed committed plan needs review and is never silently rewritten")
  void lifecycle() throws Exception {
    Session owner = newOwnerSession();
    String id = saved(owner, plan("INCUBATE_EGGS", 300, 70));
    send(owner, "/api/v1/production/plans/" + id + "/commit", null)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.status").value("COMMITTED"));

    JsonNode house = body(mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(owner))).andReturn())
        .get("data").get(2);
    ObjectNode placement = mapper.createObjectNode();
    placement.put("source", "PURCHASED_DAY_OLD");
    placement.put("houseId", house.get("id").asText());
    placement.put("quantity", 700);
    placement.put("placementDate", TODAY.toString());
    send(owner, "/api/v1/production/placements", placement).andExpect(status().isCreated());

    send(owner, "/api/v1/production/plans/" + id + "/recalculate", null)
        .andExpect(jsonPath("$.data.status").value("NEEDS_REVIEW"))
        .andExpect(jsonPath("$.data.calculation.feasible").value(true))
        .andExpect(jsonPath("$.data.recalculation.feasible").value(false));
    send(owner, "/api/v1/production/plans/" + id + "/accept-recalculation", null)
        .andExpect(status().isBadRequest());
    ObjectNode reason = mapper.createObjectNode();
    reason.put("reason", "Accepting the new numbers");
    send(owner, "/api/v1/production/plans/" + id + "/accept-recalculation", reason)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.calculation.feasible").value(false))
        .andExpect(jsonPath("$.data.status").value("NEEDS_REVIEW"));
    send(owner, "/api/v1/production/plans/" + id + "/cancel", reason)
        .andExpect(jsonPath("$.data.status").value("CANCELLED"));
    mvc.perform(get("/api/v1/production/plans?openOnly=true").cookie(accessCookie(owner)))
        .andExpect(jsonPath("$.data.length()").value(0));
  }

  @Test
  @DisplayName("a plan that no longer fits cannot be committed")
  void commitRevalidates() throws Exception {
    Session owner = newOwnerSession();
    String id = saved(owner, plan("INCUBATE_EGGS", 300, 70));
    JsonNode house = body(mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(owner))).andReturn())
        .get("data").get(2);
    ObjectNode placement = mapper.createObjectNode();
    placement.put("source", "PURCHASED_DAY_OLD");
    placement.put("houseId", house.get("id").asText());
    placement.put("quantity", 700);
    placement.put("placementDate", TODAY.toString());
    send(owner, "/api/v1/production/placements", placement).andExpect(status().isCreated());
    send(owner, "/api/v1/production/plans/" + id + "/commit", null)
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("CAPACITY_CONFLICT"));
  }

  @Test
  @DisplayName("plans are farm scoped")
  void isolation() throws Exception {
    Session owner = newOwnerSession();
    Session other = newOwnerSession();
    String id = saved(owner, plan("INCUBATE_EGGS", 300, 100));
    mvc.perform(get("/api/v1/production/plans/" + id).cookie(accessCookie(other))).andExpect(status().isNotFound());
    send(other, "/api/v1/production/plans/" + id + "/cancel", null).andExpect(status().isNotFound());
    mvc.perform(get("/api/v1/production/plans").cookie(accessCookie(other)))
        .andExpect(jsonPath("$.data.length()").value(0));
  }

  @Test
  @DisplayName("house space is checked on the placement date, not today")
  void houseSpaceOnPlacementDate() throws Exception {
    Session owner = newOwnerSession();
    JsonNode house = body(mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(owner))).andReturn())
        .get("data").get(2);
    ObjectNode placement = mapper.createObjectNode();
    placement.put("source", "PURCHASED_DAY_OLD");
    placement.put("houseId", house.get("id").asText());
    placement.put("quantity", 700);
    placement.put("placementDate", TODAY.toString());
    send(owner, "/api/v1/production/placements", placement).andExpect(status().isCreated());

    // Placed after today's birds reach the 42-day grow-out age.
    send(owner, "/api/v1/production/plans/calculate", plan("PURCHASE_DAY_OLD_CHICKS", 667, 100))
        .andExpect(jsonPath("$.data.feasible").value(true));
    // Placed while today's birds are still in the house.
    send(owner, "/api/v1/production/plans/calculate", plan("PURCHASE_DAY_OLD_CHICKS", 667, 70))
        .andExpect(jsonPath("$.data.feasible").value(false))
        .andExpect(jsonPath("$.data.constraints[0]").value(org.hamcrest.Matchers.containsString("is expected to hold 700")));
  }
}
