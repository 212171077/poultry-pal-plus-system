package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

class AccountSettingsControllerTest extends V1TestSupport {

  @Test
  @DisplayName("a signed-in user can update their profile and continue with the rotated session")
  void profileUpdateRotatesSessionWhenEmailChanges() throws Exception {
    Session owner = newOwnerSession();
    String updatedEmail = uniqueEmail();
    ObjectNode request =
        mapper
            .createObjectNode()
            .put("name", "Updated")
            .put("surname", "Owner")
            .put("email", updatedEmail)
            .put("phoneNumber", "0720000001");

    MvcResult result =
        mvc.perform(
                patch("/api/v1/auth/profile")
                    .cookie(
                        accessCookie(owner),
                        owner.cookie("poultry-pal-refresh"))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(mapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.email").value(updatedEmail))
            .andReturn();

    Cookie[] renewedCookies = result.getResponse().getCookies();
    mvc.perform(get("/api/v1/auth/me").cookie(renewedCookies))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.email").value(updatedEmail));
    mvc.perform(get("/api/v1/auth/me").cookie(accessCookie(owner)))
        .andExpect(status().isUnauthorized());
  }

  @Test
  @DisplayName("farm workers cannot change farm details")
  void workerCannotUpdateFarmDetails() throws Exception {
    Session owner = newOwnerSession();
    Session worker = signin(createWorker(owner.farmId()));
    ObjectNode request = mapper.createObjectNode().put("farmName", "Changed Farm");

    mvc.perform(
            patch("/api/v1/farm/details")
                .cookie(accessCookie(worker))
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(request)))
        .andExpect(status().isForbidden());
  }

  @Test
  @DisplayName("currency preferences are stored for the authenticated user")
  void ownerCanUpdateCurrencyPreference() throws Exception {
    Session owner = newOwnerSession();
    ObjectNode request = mapper.createObjectNode().put("currency", "usd");

    mvc.perform(
            put("/api/v1/account/settings/currency")
                .cookie(accessCookie(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(request)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.userId").value(owner.userId()))
        .andExpect(jsonPath("$.data.farmId").value(owner.farmId()))
        .andExpect(jsonPath("$.data.currency").value("USD"));
  }

  @Test
  @DisplayName("a signed-in user can change their password after confirming the current password")
  void ownerCanChangePassword() throws Exception {
    Session owner = newOwnerSession();
    ObjectNode request =
        mapper
            .createObjectNode()
            .put("currentPassword", PASSWORD)
            .put("newPassword", "NewPassword1!");

    mvc.perform(
            patch("/api/v1/account/password")
                .cookie(accessCookie(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(request)))
        .andExpect(status().isOk());

    mvc.perform(
            post("/api/v1/auth/signin")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    mapper.writeValueAsString(
                        java.util.Map.of(
                            "username", owner.user().get("email").asText(),
                            "password", "NewPassword1!"))))
        .andExpect(status().isOk());
  }

  @Test
  @DisplayName("an owner can add, update and delete several farm addresses")
  void ownerManagesFarmAddresses() throws Exception {
    Session owner = newOwnerSession();

    String firstResponse =
        mvc.perform(
                post("/api/v1/farm/addresses")
                    .cookie(accessCookie(owner))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(addressJson("Main farm", "1 Farm Road")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.addresses.length()").value(2))
            .andExpect(jsonPath("$.data.addresses[1].addressLine1").value("1 Farm Road"))
            .andReturn()
            .getResponse()
            .getContentAsString();
    String firstId = mapper.readTree(firstResponse).at("/data/addresses/1/id").asText();

    String secondResponse =
        mvc.perform(
                post("/api/v1/farm/addresses")
                    .cookie(accessCookie(owner))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(addressJson("Packing shed", "2 Shed Lane")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.addresses.length()").value(3))
            .andReturn()
            .getResponse()
            .getContentAsString();
    String secondId = mapper.readTree(secondResponse).at("/data/addresses/2/id").asText();

    mvc.perform(
            put("/api/v1/farm/addresses/" + secondId)
                .cookie(accessCookie(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content(addressJson("Cold room", "3 Cold Street")))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.addresses[2].id").value(secondId))
        .andExpect(jsonPath("$.data.addresses[2].label").value("Cold room"))
        .andExpect(jsonPath("$.data.addresses[2].addressLine1").value("3 Cold Street"));

    mvc.perform(delete("/api/v1/farm/addresses/" + firstId).cookie(accessCookie(owner)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.addresses.length()").value(2))
        .andExpect(jsonPath("$.data.addresses[1].addressLine1").value("3 Cold Street"));

    mvc.perform(delete("/api/v1/farm/addresses/" + firstId).cookie(accessCookie(owner)))
        .andExpect(status().isNotFound());
  }

  @Test
  @DisplayName("farm workers cannot manage addresses and an address needs a first line")
  void addressRulesAreEnforced() throws Exception {
    Session owner = newOwnerSession();
    Session worker = signin(createWorker(owner.farmId()));

    mvc.perform(
            post("/api/v1/farm/addresses")
                .cookie(accessCookie(worker))
                .contentType(MediaType.APPLICATION_JSON)
                .content(addressJson("Main", "1 Farm Road")))
        .andExpect(status().isForbidden());
    mvc.perform(
            post("/api/v1/farm/addresses")
                .cookie(accessCookie(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content(addressJson("Main", "")))
        .andExpect(status().isBadRequest());
  }

  private String addressJson(String label, String line1) throws Exception {
    return mapper.writeValueAsString(
        mapper.createObjectNode().put("label", label).put("addressLine1", line1).put("city", "Pretoria"));
  }
}
