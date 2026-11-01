package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;

import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.http.MediaType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class TeamControllerTest extends V1TestSupport {

  @Test
  @DisplayName("a farm owner can list only their farm's team")
  void ownerCanListFarmTeam() throws Exception {
    Session owner = newOwnerSession();

    mvc.perform(get("/api/v1/team").cookie(accessCookie(owner)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.success").value(true))
        .andExpect(jsonPath("$.data[0].farmId").value(owner.farmId()));
  }

  @Test
  @DisplayName("farm workers cannot access team management")
  void workerCannotListFarmTeam() throws Exception {
    Session owner = newOwnerSession();
    Session worker = signin(createWorker(owner.farmId()));

    mvc.perform(get("/api/v1/team").cookie(accessCookie(worker)))
        .andExpect(status().isForbidden());
  }

  @Test
  @DisplayName("deactivated workers can no longer use an existing access cookie")
  void deactivatedWorkerCannotUseExistingSession() throws Exception {
    Session owner = newOwnerSession();
    String workerEmail = createWorker(owner.farmId());
    Session worker = signin(workerEmail);
    String workerId = worker.user().get("id").asText();
    ObjectNode request = mapper.createObjectNode().put("active", false);

    mvc.perform(
            patch("/api/v1/team/{memberId}/activation", workerId)
                .cookie(accessCookie(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(request)))
        .andExpect(status().isOk());

    mvc.perform(get("/api/v1/team").cookie(accessCookie(worker))).andExpect(status().isUnauthorized());
  }
}
