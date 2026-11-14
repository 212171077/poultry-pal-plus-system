package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import co.za.hlaluko.dynamics.poultry.pal.containers.ContainerBase;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ApprovalStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Role;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.repository.RoleRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.servlet.http.Cookie;
import java.util.Arrays;
import java.util.Date;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
abstract class V1TestSupport extends ContainerBase {
  static final String PASSWORD = "Password1";

  @Autowired MockMvc mvc;
  @Autowired ObjectMapper mapper;
  @Autowired UserRepository userRepository;
  @Autowired RoleRepository roleRepository;
  @Autowired PasswordEncoder passwordEncoder;

  /** Signed-in session: the user info plus the cookies to send on later requests. */
  record Session(JsonNode user, Cookie[] cookies) {
    Cookie cookie(String name) {
      return Arrays.stream(cookies).filter(c -> c.getName().equals(name)).findFirst().orElse(null);
    }

    String farmId() {
      return user.get("farmId").asText();
    }

    String userId() {
      return user.get("id").asText();
    }
  }

  static String uniqueEmail() {
    return "v1-" + UUID.randomUUID().toString().substring(0, 18) + "@test.io";
  }

  String signupOwner() throws Exception {
    String email = uniqueEmail();
    ObjectNode body = mapper.createObjectNode();
    body.put("name", "Owner");
    body.put("surname", "Test");
    body.put("email", email);
    body.put("phoneNumber", "0720000000");
    body.put("password", PASSWORD);
    body.put("farmName", "Sunrise Farm");
    body.put("farmAddressLine1", "1 Farm Road");
    body.put("farmCity", "Polokwane");
    body.put("farmState", "Limpopo");
    body.put("farmPostalCode", "0700");
    body.put("farmCountry", "South Africa");
    mvc.perform(
            post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(body)))
        .andExpect(status().isCreated());
    User owner = userRepository.findByEmail(email).orElseThrow();
    owner.setApprovalStatus(ApprovalStatus.APPROVED);
    owner.setActive(true);
    userRepository.save(owner);
    return email;
  }

  String createWorker(String farmId) {
    String email = uniqueEmail();
    Role userRole = roleRepository.findByName(ERole.ROLE_USER).orElseThrow();
    userRepository.save(
        User.builder()
            .name("Worker")
            .surname("Test")
            .email(email)
            .password(passwordEncoder.encode(PASSWORD))
            .farmId(farmId)
            .active(true)
            .farmOwner(false)
            .createdDate(new Date())
            .roles(Set.of(userRole))
            .build());
    return email;
  }

  Session signin(String email) throws Exception {
    MvcResult result =
        mvc.perform(
                post("/api/v1/auth/signin")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        mapper.writeValueAsString(
                            Map.of("username", email, "password", PASSWORD))))
            .andExpect(status().isOk())
            .andReturn();
    return new Session(body(result).get("data"), result.getResponse().getCookies());
  }

  Session newOwnerSession() throws Exception {
    return signin(signupOwner());
  }

  JsonNode body(MvcResult result) throws Exception {
    return mapper.readTree(result.getResponse().getContentAsString());
  }

  Cookie accessCookie(Session session) {
    return session.cookie("poultry-pal");
  }

  ObjectNode op(String entityType, String operation, String entityId, String coopId, Long base) {
    ObjectNode op = mapper.createObjectNode();
    op.put("opId", "op-" + UUID.randomUUID());
    op.put("entityType", entityType);
    op.put("operation", operation);
    if (entityId != null) op.put("entityId", entityId);
    if (coopId != null) op.put("coopId", coopId);
    if (base != null) op.put("baseVersion", base);
    return op;
  }

  ObjectNode coopOp(String coopId, String name, Long base) {
    ObjectNode op = op("COOP", "UPSERT", coopId, null, base);
    ObjectNode payload = op.putObject("payload");
    payload.put("coopName", name);
    payload.put("coopType", "BROILER");
    payload.put("growthPhase", "BROODING_PHASE");
    payload.put("numberOfChickens", 100);
    payload.put("chickenArrivalDate", "2025-01-10T00:00:00.000Z");
    return op;
  }

  ObjectNode expenseOp(String expenseId, String coopId, double amount, Long base) {
    ObjectNode op = op("EXPENSE", "UPSERT", expenseId, coopId, base);
    ObjectNode payload = op.putObject("payload");
    payload.put("expenseDate", "2025-01-15T00:00:00.000Z");
    payload.put("expenseType", "Feed");
    payload.put("amount", amount);
    return op;
  }

  JsonNode push(Session session, ObjectNode... ops) throws Exception {
    return push(session, 200, ops);
  }

  JsonNode push(Session session, int expectedStatus, ObjectNode... ops) throws Exception {
    ObjectNode request = mapper.createObjectNode();
    ArrayNode operations = request.putArray("operations");
    Arrays.stream(ops).forEach(operations::add);
    MvcResult result =
        mvc.perform(
                post("/api/v1/sync/push")
                    .cookie(accessCookie(session))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(mapper.writeValueAsString(request)))
            .andExpect(status().is(expectedStatus))
            .andReturn();
    return body(result);
  }

  JsonNode changes(Session session, Long since, Integer limit) throws Exception {
    var request = get("/api/v1/sync/changes").cookie(accessCookie(session));
    if (since != null) request.param("since", since.toString());
    if (limit != null) request.param("limit", limit.toString());
    MvcResult result = mvc.perform(request).andExpect(status().isOk()).andReturn();
    return body(result).get("data");
  }

  static Set<String> ids(JsonNode array) {
    return java.util.stream.StreamSupport.stream(array.spliterator(), false)
        .map(node -> node.has("id") ? node.get("id").asText() : node.get("entityId").asText())
        .collect(Collectors.toSet());
  }

  static String newId() {
    return UUID.randomUUID().toString();
  }
}
