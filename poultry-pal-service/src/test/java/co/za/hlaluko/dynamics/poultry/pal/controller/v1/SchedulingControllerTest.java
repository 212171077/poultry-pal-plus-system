package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

class SchedulingControllerTest extends V1TestSupport {
  private static final LocalDate TODAY = LocalDate.now();

  private ResultActions send(Session s, String url, Object payload) throws Exception {
    return mvc.perform(
        post(url).cookie(accessCookie(s)).contentType(MediaType.APPLICATION_JSON)
            .content(mapper.writeValueAsString(payload)));
  }

  private ObjectNode search(int eggs, int fromOffset, int toOffset) {
    ObjectNode n = mapper.createObjectNode();
    n.put("eggs", eggs);
    n.put("earliestStart", TODAY.plusDays(fromOffset).toString());
    n.put("latestStart", TODAY.plusDays(toOffset).toString());
    return n;
  }

  private String id(Session s, int index) throws Exception {
    JsonNode list = body(mvc.perform(get("/api/v1/production/equipment").cookie(accessCookie(s))).andReturn()).get("data");
    return list.get(index).get("id").asText();
  }

  @Test
  @DisplayName("an empty farm has one window covering the whole range")
  void emptyFarm() throws Exception {
    Session owner = newOwnerSession();
    send(owner, "/api/v1/production/schedule/search", search(400, 1, 5))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.expectedChicks").value(320))
        .andExpect(jsonPath("$.data.recommendedStart").value(TODAY.plusDays(1).toString()))
        .andExpect(jsonPath("$.data.windows.length()").value(1))
        .andExpect(jsonPath("$.data.windows[0].to").value(TODAY.plusDays(5).toString()))
        .andExpect(jsonPath("$.data.candidates[0].transferDate").value(TODAY.plusDays(19).toString()))
        .andExpect(jsonPath("$.data.candidates[0].hatchDate").value(TODAY.plusDays(22).toString()));
  }

  @Test
  @DisplayName("a full incubator pushes the first window past the batch's transfer day")
  void incubatorFull() throws Exception {
    Session owner = newOwnerSession();
    ObjectNode batch = mapper.createObjectNode();
    batch.put("equipmentId", id(owner, 0));
    batch.put("eggsSet", 2000);
    batch.put("plannedStartDate", TODAY.plusDays(1).toString());
    send(owner, "/api/v1/production/batches", batch).andExpect(status().isCreated());

    send(owner, "/api/v1/production/schedule/search", search(400, 1, 25))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.recommendedStart").value(TODAY.plusDays(19).toString()))
        .andExpect(jsonPath("$.data.windows.length()").value(1))
        .andExpect(jsonPath("$.data.candidates[0].feasible").value(false))
        .andExpect(jsonPath("$.data.candidates[0].reasons[0]").isNotEmpty());
  }

  @Test
  @DisplayName("a full chicken house leaves no window and explains why")
  void houseFull() throws Exception {
    Session owner = newOwnerSession();
    ObjectNode placement = mapper.createObjectNode();
    placement.put("source", "PURCHASED_DAY_OLD");
    placement.put("houseId", id(owner, 2));
    placement.put("quantity", 700);
    placement.put("placementDate", TODAY.toString());
    send(owner, "/api/v1/production/placements", placement).andExpect(status().isCreated());

    send(owner, "/api/v1/production/schedule/search", search(400, 1, 3))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.recommendedStart").doesNotExist())
        .andExpect(jsonPath("$.data.windows.length()").value(0))
        .andExpect(jsonPath("$.data.explanation").value(org.hamcrest.Matchers.containsString("No start date")));
  }

  @Test
  @DisplayName("invalid ranges are rejected")
  void validation() throws Exception {
    Session owner = newOwnerSession();
    send(owner, "/api/v1/production/schedule/search", search(400, 5, 1)).andExpect(status().isBadRequest());
    send(owner, "/api/v1/production/schedule/search", search(400, 0, 400)).andExpect(status().isBadRequest());
    send(owner, "/api/v1/production/schedule/search", search(0, 0, 1)).andExpect(status().isBadRequest());
  }
}
