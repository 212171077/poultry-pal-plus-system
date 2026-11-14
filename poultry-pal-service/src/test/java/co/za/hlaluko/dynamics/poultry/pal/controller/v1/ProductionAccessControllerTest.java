package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.Role;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

class ProductionAccessControllerTest extends V1TestSupport {

  private void setGrant(Session actor, String memberId, boolean granted, int expected)
      throws Exception {
    mvc.perform(
            put("/api/v1/team/{id}/production-access", memberId)
                .cookie(accessCookie(actor))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"granted\":" + granted + "}"))
        .andExpect(status().is(expected));
  }

  private void expectAccess(Session session, int expected) throws Exception {
    mvc.perform(get("/api/v1/production/access").cookie(accessCookie(session)))
        .andExpect(status().is(expected));
  }

  @Test
  @DisplayName("owner has access; workers are denied until granted and again after revocation")
  void grantAndRevoke() throws Exception {
    Session owner = newOwnerSession();
    Session worker = signin(createWorker(owner.farmId()));

    mvc.perform(get("/api/v1/production/access").cookie(accessCookie(owner)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.canGrantAccess").value(true));
    expectAccess(worker, 403);

    setGrant(owner, worker.userId(), true, 200);
    expectAccess(worker, 200);
    mvc.perform(get("/api/v1/team").cookie(accessCookie(owner)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data[?(@.id=='" + worker.userId() + "')].permissions[0]")
            .value("PRODUCTION_MANAGE"));

    setGrant(owner, worker.userId(), false, 200);
    expectAccess(worker, 403);
  }

  @Test
  @DisplayName("farm managers cannot grant production access")
  void managerCannotGrant() throws Exception {
    Session owner = newOwnerSession();
    String managerEmail = createWorker(owner.farmId());
    User manager = userRepository.findByEmail(managerEmail).orElseThrow();
    Role managerRole = roleRepository.findByName(ERole.ROLE_FARM_MANAGER).orElseThrow();
    manager.setRoles(Set.of(roleRepository.findByName(ERole.ROLE_USER).orElseThrow(), managerRole));
    userRepository.save(manager);
    Session managerSession = signin(managerEmail);
    Session worker = signin(createWorker(owner.farmId()));

    setGrant(managerSession, worker.userId(), true, 403);
    expectAccess(worker, 403);
  }

  @Test
  @DisplayName("grants cannot cross farms and the grant is not honoured for another farm")
  void crossFarmIsolation() throws Exception {
    Session ownerA = newOwnerSession();
    Session ownerB = newOwnerSession();
    Session workerB = signin(createWorker(ownerB.farmId()));

    setGrant(ownerA, workerB.userId(), true, 404);
    expectAccess(workerB, 403);
  }

  @Test
  @DisplayName("removed or deactivated members lose access on the next request")
  void deactivationRevokesAccess() throws Exception {
    Session owner = newOwnerSession();
    Session worker = signin(createWorker(owner.farmId()));
    setGrant(owner, worker.userId(), true, 200);
    expectAccess(worker, 200);

    mvc.perform(
            patch("/api/v1/team/{id}/activation", worker.userId())
                .cookie(accessCookie(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"active\":false}"))
        .andExpect(status().isOk());
    expectAccess(worker, 401);
  }

  @Test
  @DisplayName("the owner's implicit access cannot be edited")
  void ownerGrantRejected() throws Exception {
    Session owner = newOwnerSession();
    setGrant(owner, owner.userId(), true, 400);
  }
}
