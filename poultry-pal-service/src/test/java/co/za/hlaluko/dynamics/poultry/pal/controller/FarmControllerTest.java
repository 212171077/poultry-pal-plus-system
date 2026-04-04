package co.za.hlaluko.dynamics.poultry.pal.controller;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assertions.assertTrue;

import co.za.hlaluko.dynamics.poultry.pal.containers.ContainerBase;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.*;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.CoopType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.*;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.FarmResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.MessageResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.UserRepository;
import co.za.hlaluko.dynamics.poultry.pal.utils.exception.PoultryPalException;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.*;
import java.util.ArrayList;
import java.util.Date;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.junit.jupiter.Testcontainers;

@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class FarmControllerTest extends ContainerBase {

  @Autowired AuthController authController;
  @Autowired FarmController farmController;
  @Autowired UserRepository userRepository;

  @BeforeEach
  void setUp() {
    getSignupRequests()
        .forEach(
            request -> {
              try {
                authController.signup(request);
              } catch (PoultryPalException e) {
                throw new RuntimeException(e);
              }
            });
  }

  @Test
  @Order(1)
  @DisplayName(
      "updateUser - Should successfully update user information when valid request is provided")
  void testUpdateUser_Success() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("useremai@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    assertNotNull(loginResponse);
    assertEquals(200, loginResponse.getStatusCode().value());
    UserInfoResponse userInfoResponse = (UserInfoResponse) loginResponse.getBody();
    assertNotNull(userInfoResponse);

    UpdateUserRequest updateRequest = new UpdateUserRequest();
    updateRequest.setId(userInfoResponse.getId());
    updateRequest.setName("UpdatedName");
    updateRequest.setSurname("UpdatedSurname");
    updateRequest.setEmail("UpdatedEmail");
    updateRequest.setPhoneNumber("UpdatedPhoneNumber");

    ResponseEntity<Object> response = farmController.updateUser(updateRequest);
    UserInfoResponse newUserInfo = (UserInfoResponse) response.getBody();

    assertNotNull(newUserInfo);
    assertEquals(updateRequest.getName(), newUserInfo.getName());
    assertEquals(updateRequest.getSurname(), newUserInfo.getSurname());
    assertEquals(updateRequest.getEmail(), newUserInfo.getEmail());
    assertEquals(updateRequest.getPhoneNumber(), newUserInfo.getPhoneNumber());
    assertEquals(userInfoResponse.getFarmId(), newUserInfo.getFarmId());
    assertEquals(userInfoResponse.getId(), newUserInfo.getId());
  }

  @Test
  @Order(2)
  @DisplayName(
      "updateUser - Should return Farm Id cannot be null error response when new user is created without farm ID")
  void testUpdateUserWithInvalidRequest() {

    UpdateUserRequest updateRequest = new UpdateUserRequest();

    updateRequest.setName("NoFarmIdNewName");
    updateRequest.setSurname("NoFarmIdNewSurname");
    updateRequest.setEmail("NoFarmIdNewEmail");
    updateRequest.setPhoneNumber("NoFarmIdNewPhoneNumber");

    ResponseEntity<Object> response = farmController.updateUser(updateRequest);
    assertNotNull(response);
    assertEquals(400, response.getStatusCode().value());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm Id cannot be null", messageResponse.getMessage());
  }

  @Test
  @Order(3)
  @DisplayName(
      "updateUser - Should return Invalid Farm Id error response when new user is created with invalid farm ID")
  void testUpdateUserWithInvalidFarmIDRequest() {

    UpdateUserRequest updateRequest = new UpdateUserRequest();

    updateRequest.setFarmId("InvalidFarmID");
    updateRequest.setName("InvFarmIdNewName");
    updateRequest.setSurname("InvFarmIdNewSurname");
    updateRequest.setEmail("InvFarmIdNewEmail");
    updateRequest.setPhoneNumber("InvFarmIdNewPhoneNumber");

    ResponseEntity<Object> response = farmController.updateUser(updateRequest);
    assertNotNull(response);
    assertEquals(400, response.getStatusCode().value());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Invalid Farm Id", messageResponse.getMessage());
  }

  @Test
  @Order(4)
  @DisplayName(
      "updateUser - Should successfully create a new user and link the user with associated farm id")
  void testCreateUserWithValidRequest() {

    UpdateUserRequest updateRequest = new UpdateUserRequest();
    UserInfoResponse userInfoResponse = getLoggedUser();

    updateRequest.setFarmId(Objects.requireNonNull(userInfoResponse).getFarmId());
    updateRequest.setName("NewFarmUserName");
    updateRequest.setSurname("NewFarmUserSurname");
    updateRequest.setEmail("NewEmail");
    updateRequest.setPhoneNumber("NewPhoneNumber");

    ResponseEntity<Object> response = farmController.updateUser(updateRequest);
    assertNotNull(response);
    UserInfoResponse updatedUserInfo = (UserInfoResponse) response.getBody();
    assertEquals(200, response.getStatusCode().value());
    assertEquals("NewFarmUserName", Objects.requireNonNull(updatedUserInfo).getName());
    assertEquals(updatedUserInfo.getFarmId(), Objects.requireNonNull(userInfoResponse).getFarmId());
  }

  @Test
  @Order(5)
  @DisplayName("activateUser - Should activate a user when a valid user ID is provided")
  void testActivateUser() {
    UserInfoResponse user = getLoggedUser();
    assertFalse(Objects.requireNonNull(user).isActive());
    ResponseEntity<MessageResponse> response = farmController.activateUser(user.getId());
    assertTrue(Objects.requireNonNull(response.getBody()).isSuccess());
    assertEquals("User activated successfully", response.getBody().getMessage());
    UserInfoResponse activatedUser = getLoggedUser();
    assertTrue(Objects.requireNonNull(activatedUser).isActive());
  }

  @Test
  @Order(6)
  @DisplayName(
      "activateUser - Should return User not found error when attempting to activate a non-existent user")
  void testActivateUser_NonExistentUser() {
    ResponseEntity<MessageResponse> response = farmController.activateUser("InvalidUserID");
    assertFalse(Objects.requireNonNull(response.getBody()).isSuccess());
    assertEquals("User not found", response.getBody().getMessage());
  }

  @Test
  @Order(7)
  @DisplayName("findAllUsers - Should retrieve a list of all users when requested")
  void testFindAllUser() {
    ResponseEntity<List<UserInfoResponse>> response = farmController.findAllUsers();
    assertNotNull(response);
    assertEquals(200, response.getStatusCode().value());
    assertFalse(Objects.requireNonNull(response.getBody()).isEmpty());
  }

  @Test
  @Order(8)
  @DisplayName("findFarmById - Should return farm details when a valid farm ID is provided")
  void testFindFarmById_ValidId_ReturnsFarmDetails() {
    UserInfoResponse user = getLoggedUser();
    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(user).getFarmId());

    assertNotNull(response);
    assertEquals(200, response.getStatusCode().value());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    assertEquals(user.getFarmId(), farmResponse.getId());
    assertEquals("Farm Name 1", farmResponse.getFarmName());
    assertEquals("Address Line 1", farmResponse.getAddress().getAddressLine1());
    assertEquals("Address Line 2", farmResponse.getAddress().getAddressLine2());
    assertEquals("State", farmResponse.getAddress().getState());
    assertEquals("City", farmResponse.getAddress().getCity());
    assertEquals("0000", farmResponse.getAddress().getPostalCode());
    assertEquals("South Africa", farmResponse.getAddress().getCountry());
  }

  @Test
  @Order(9)
  @DisplayName("findFarmById - Should return an error when attempting to find a non-existent farm")
  void testFindFarmById_InValidId_ReturnsFarmDetails() {
    ResponseEntity<Object> response = farmController.findFarmById("InvalidFarId");
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(10)
  @DisplayName("findInactiveUsers - Should retrieve a list of all inactive users when requested")
  void testFindInactiveUser() {
    ResponseEntity<List<UserInfoResponse>> response = farmController.findInactiveUsers();
    assertNotNull(response);
    assertEquals(200, response.getStatusCode().value());
    assertTrue(Objects.requireNonNull(response.getBody()).size() > 1);
  }

  @Test
  @Order(11)
  @DisplayName(
      "updateFarmDetails - Should successfully update farm details when valid request is provided")
  void testUpdateFarmDetails() {
    UserInfoResponse loggedUser = getLoggedUser();
    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateFarmRequest updateRequest = new UpdateFarmRequest();
    updateRequest.setFarmId(farmResponse.getId());
    updateRequest.setUpdatedByUserId(loggedUser.getId());
    updateRequest.setFarmName("Updated Farm Name");
    updateRequest.setFarmAddressLine1("Updated Farm Address 1");
    updateRequest.setFarmAddressLine2("Updated Farm Address 2");
    updateRequest.setFarmState("Updated Farm State");
    updateRequest.setFarmCity("Updated Farm City");
    updateRequest.setFarmPostalCode("1111");
    updateRequest.setFarmCountry("Updated Farm Country");

    ResponseEntity<Object> updatedFarmResponse = farmController.updateFarmDetails(updateRequest);
    assertNotNull(updatedFarmResponse);
    assertEquals(200, updatedFarmResponse.getStatusCode().value());

    FarmResponse updatedFarm = (FarmResponse) Objects.requireNonNull(updatedFarmResponse.getBody());
    assertEquals("Updated Farm Name", updatedFarm.getFarmName());
    assertEquals("Updated Farm Address 1", updatedFarm.getAddress().getAddressLine1());
    assertEquals("Updated Farm Address 2", updatedFarm.getAddress().getAddressLine2());
    assertEquals("Updated Farm State", updatedFarm.getAddress().getState());
    assertEquals("Updated Farm City", updatedFarm.getAddress().getCity());
    assertEquals("1111", updatedFarm.getAddress().getPostalCode());
    assertEquals("Updated Farm Country", updatedFarm.getAddress().getCountry());
  }

  @Test
  @Order(12)
  @DisplayName(
      "updateFarmDetails - Should return Farm not found error when attempting to update a non-existent farm")
  void testUpdateFarmDetails_withInvalidFarmID() {

    UpdateFarmRequest updateRequest = new UpdateFarmRequest();
    updateRequest.setFarmId("InvalidFarmId");
    updateRequest.setFarmName("Updated Farm Name");
    updateRequest.setFarmAddressLine1("Updated Farm Address 1");
    updateRequest.setFarmAddressLine2("Updated Farm Address 2");
    updateRequest.setFarmState("Updated Farm State");
    updateRequest.setFarmCity("Updated Farm City");
    updateRequest.setFarmPostalCode("1111");
    updateRequest.setFarmCountry("Updated Farm Country");

    ResponseEntity<Object> response = farmController.updateFarmDetails(updateRequest);
    assertNotNull(response);
    assertEquals(400, response.getStatusCode().value());

    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(13)
  @DisplayName("updateFarmCoop - Should add a coop to a farm when valid request is provided")
  void testUpdateFarmCoopValidRequest() {
    UserInfoResponse loggedUser = getLoggedUser();
    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateFarmCoopRequest request = new UpdateFarmCoopRequest();
    request.setGrowthPhase(GrowingPhase.BROODING_PHASE);
    request.setFarmId(farmResponse.getId());
    request.setCoopName("CoopName");
    request.setCoopType(CoopType.BROILER);
    request.setNumberOfChickens(1000);
    request.setChickenArrivalDate(new Date());

    ResponseEntity<Object> updateResponse = farmController.updateFarmCoop(request);
    FarmResponse updatedFarmResponse = (FarmResponse) updateResponse.getBody();

    assertEquals(200, updateResponse.getStatusCode().value());
    Coop coop = Objects.requireNonNull(updatedFarmResponse).getCoops().getFirst();

    assertEquals("CoopName", coop.getCoopName());
    assertEquals(CoopType.BROILER, coop.getCoopType());
    assertEquals(1000, coop.getNumberOfChickens());
    assertEquals(
        LocalDate.now(),
        coop.getChickenArrivalDate().toInstant().atZone(ZoneId.systemDefault()).toLocalDate());
    assertNotNull(coop.getCreatedDate());

    assertNotNull(coop.getReminder());
    assertNotNull(coop.getReminder().getId());
    if (coop.getCoopType() == CoopType.LAYERS) {
      assertEquals(7, coop.getReminder().getFeeds().size());
      assertEquals(6, coop.getReminder().getMedicines().size());
      assertEquals(7, coop.getReminder().getVaccines().size());
    } else {
      assertEquals(1, coop.getReminder().getFeeds().size());
      assertEquals(2, coop.getReminder().getMedicines().size());
      assertEquals(1, coop.getReminder().getVaccines().size());
    }
  }

  @Test
  @Order(14)
  @DisplayName(
      "updateFarmCoop - Should return an Farm not found error when invalid farm coop update request is submitted with invalid farm ID")
  void testUpdateFarmCoopInvalidFarmID() {

    UpdateFarmCoopRequest request = new UpdateFarmCoopRequest();
    request.setGrowthPhase(GrowingPhase.BROODING_PHASE);
    request.setFarmId("InvalidFarmId");
    request.setCoopName("CoopName");
    request.setCoopType(CoopType.BROILER);
    request.setNumberOfChickens(1000);
    request.setChickenArrivalDate(new Date());

    ResponseEntity<Object> response = farmController.updateFarmCoop(request);
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(15)
  @DisplayName(
      "updateFarmCoop - Should return  Coop not found error when invalid farm coop update request is submitted with invalid coop ID")
  void testUpdateFarmCoopInvalidCoopID() {
    UserInfoResponse loggedUser = getLoggedUser();
    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateFarmCoopRequest request = new UpdateFarmCoopRequest();
    request.setGrowthPhase(GrowingPhase.BROODING_PHASE);
    request.setFarmId(farmResponse.getId());
    request.setCoopId("InvalidCoopId");
    request.setCoopName("Coop Name 1");
    request.setCoopType(CoopType.BROILER);
    request.setNumberOfChickens(1000);
    request.setChickenArrivalDate(new Date());

    ResponseEntity<Object> updateResponse = farmController.updateFarmCoop(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Coop not found", messageResponse.getMessage());
  }

  @Test
  @Order(16)
  @DisplayName(
      "deleteFarmCoop - Should return Farm not found error when invalid farm ID is provided")
  void testDeleteFarmCoopInvalidFarmIdRequest() {
    ResponseEntity<Object> updateResponse =
        farmController.deleteFarmCoop("invalidFarmId", "coopId");
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(17)
  @DisplayName(
      "deleteFarmCoop - Should return a Coop not found error when invalid coop ID is provided")
  void testDeleteFarmCoopInvalidCoopIdRequest() {
    UserInfoResponse loggedUser = getLoggedUser();
    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    ResponseEntity<Object> updateResponse =
        farmController.deleteFarmCoop(farmResponse.getId(), "invalid_coopId");
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Coop not found", messageResponse.getMessage());
  }

  @Test
  @Order(18)
  @DisplayName(
      "deleteFarmCoop - Should delete coop from the farm when valida farm ID and coop ID are provided")
  void testDeleteFarmCoopValidRequest() {
    UserInfoResponse loggedUser = getLoggedUser();
    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    int tempCoopSize = farmResponse.getCoops().size();

    ResponseEntity<Object> updateResponse =
        farmController.deleteFarmCoop(
            farmResponse.getId(), farmResponse.getCoops().getFirst().getId());
    FarmResponse updatedFarmResponse = (FarmResponse) updateResponse.getBody();

    assertNotNull(updatedFarmResponse);
    assertTrue(tempCoopSize > updatedFarmResponse.getCoops().size());
  }

  @Test
  @Order(19)
  @DisplayName(
      "updateMortalities - Should return a Farm not found error when invalid farm ID is provided")
  void testUpdateMortalitiesInvalidFarmIdRequest() {
    UpdateMortalityRequest request =
        UpdateMortalityRequest.builder()
            .id("invalid_farmId")
            .farmId("test_farmId")
            .coopId("test_coopId")
            .dateOccurred(new Date())
            .numberOfDeaths(1)
            .reason("Test Reason")
            .recordedBy(UUID.randomUUID().toString())
            .build();
    ResponseEntity<Object> updateResponse = farmController.updateMortalities(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(20)
  @DisplayName(
      "updateExpense - Should return a Farm not found error when invalid farm ID is provided")
  void testUpdateExpenseInvalidFarmIdRequest() {

    UpdateExpenseRequest request = new UpdateExpenseRequest();
    request.setFarmId("invalid_farmId");
    request.setCoopId("test_farmId");
    request.setExpenseDate(new Date());
    request.setExpenseType("FEED");
    request.setAmount(100.0D);
    request.setAdditionalInfo("Chicken feeds");
    request.setRecordedBy("UUID.randomUUID().toString()");

    ResponseEntity<Object> updateResponse = farmController.updateExpense(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(21)
  @DisplayName(
      "updateSales - Should return a Copy string literal text to the clipboard error when invalid farm ID is provided")
  void testUpdateSalesInvalidFarmIdRequest() {
    UpdateSaleRequest request = new UpdateSaleRequest();
    request.setId(UUID.randomUUID().toString());
    request.setFarmId("test_farmId");
    request.setCoopId("test_coopId");
    request.setNumberOfDozensSold(10);
    request.setSalePricePerDozen(50D);
    request.setBuyerName("Chrisopher Sibiya");
    request.setRecordedBy(UUID.randomUUID().toString());
    request.setPaymentStatus(PaymentStatus.PAID);
    request.setSaleDate(new Date());

    ResponseEntity<Object> updateResponse = farmController.updateSales(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(22)
  @DisplayName(
      "UpdateMortalities - Should return a Farm does not have coops error when attempting to add mortality to farm with no coop")
  void testUpdateMortalities_noCoopOnTheFarm() {
    UserInfoResponse loggedUser = getLoggedUser();
    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateMortalityRequest request =
        UpdateMortalityRequest.builder()
            .farmId(farmResponse.getId())
            .coopId("invalid_coopId")
            .dateOccurred(new Date())
            .numberOfDeaths(1)
            .reason("Test Reason")
            .recordedBy(UUID.randomUUID().toString())
            .build();

    ResponseEntity<Object> updateResponse = farmController.updateMortalities(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm does not have coops", messageResponse.getMessage());
  }

  @Test
  @Order(23)
  @DisplayName(
      "updateExpense - Should return a Farm does not have coops error when attempting to add mortality to farm with no coop")
  void testUpdateExpense_noCoopOnTheFarm() {
    UserInfoResponse loggedUser = getLoggedUser();
    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateExpenseRequest request = new UpdateExpenseRequest();
    request.setFarmId(farmResponse.getId());
    request.setCoopId("invalid_coopId");
    request.setExpenseDate(new Date());
    request.setExpenseType("FEED");
    request.setAmount(100.0D);
    request.setAdditionalInfo("Chicken feeds");
    request.setRecordedBy(UUID.randomUUID().toString());

    ResponseEntity<Object> updateResponse = farmController.updateExpense(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm does not have coops", messageResponse.getMessage());
  }

  @Test
  @Order(24)
  @DisplayName(
      "updateSales - Should return a Farm does not have coops error when attempting to add sale to farm with no coop")
  void testUpdateSales_noCoopOnTheFarm() {
    UserInfoResponse loggedUser = getLoggedUser();
    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateSaleRequest request = new UpdateSaleRequest();
    request.setId(UUID.randomUUID().toString());
    request.setFarmId(farmResponse.getId());
    request.setCoopId("test_coopId");
    request.setNumberOfDozensSold(10);
    request.setSalePricePerDozen(50D);
    request.setBuyerName("Chrisopher Sibiya");
    request.setRecordedBy(UUID.randomUUID().toString());
    request.setPaymentStatus(PaymentStatus.PAID);
    request.setSaleDate(new Date());

    ResponseEntity<Object> updateResponse = farmController.updateSales(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Farm does not have coops", messageResponse.getMessage());
  }

  @Test
  @Order(25)
  @DisplayName(
      "updateMortalities - Should return a Invalid coop ID error when invalid coop ID is provided")
  void testUpdateMortalitiesInvalidCoopIdRequest() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateFarmCoopRequest updateFarmCoopRequest = new UpdateFarmCoopRequest();
    updateFarmCoopRequest.setGrowthPhase(GrowingPhase.BROODING_PHASE);
    updateFarmCoopRequest.setFarmId(farmResponse.getId());
    updateFarmCoopRequest.setCoopName("CoopName");
    updateFarmCoopRequest.setCoopType(CoopType.BROILER);
    updateFarmCoopRequest.setNumberOfChickens(1000);
    updateFarmCoopRequest.setChickenArrivalDate(new Date());

    ResponseEntity<Object> updatedFarmCoopRes =
        farmController.updateFarmCoop(updateFarmCoopRequest);
    assertEquals(200, updatedFarmCoopRes.getStatusCode().value());

    UpdateMortalityRequest request =
        UpdateMortalityRequest.builder()
            .farmId(farmResponse.getId())
            .coopId("invalid_coopId")
            .dateOccurred(new Date())
            .numberOfDeaths(1)
            .reason("Test Reason")
            .recordedBy(UUID.randomUUID().toString())
            .build();

    ResponseEntity<Object> updateResponse = farmController.updateMortalities(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Invalid coop ID", messageResponse.getMessage());
  }

  @Test
  @Order(26)
  @DisplayName(
      "updateExpense - Should return a Invalid coop ID error when invalid coop ID is provided")
  void testUpdateExpenseInvalidCoopIdRequest() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateExpenseRequest request = new UpdateExpenseRequest();
    request.setFarmId(farmResponse.getId());
    request.setCoopId("invalid_coopId");
    request.setExpenseDate(new Date());
    request.setExpenseType("FEED");
    request.setAmount(100.0D);
    request.setAdditionalInfo("Chicken feeds");
    request.setRecordedBy(UUID.randomUUID().toString());

    UpdateFarmCoopRequest updateFarmCoopRequest = new UpdateFarmCoopRequest();
    updateFarmCoopRequest.setGrowthPhase(GrowingPhase.BROODING_PHASE);
    updateFarmCoopRequest.setFarmId(farmResponse.getId());
    updateFarmCoopRequest.setCoopName("Broiler Coop");
    updateFarmCoopRequest.setCoopType(CoopType.BROILER);
    updateFarmCoopRequest.setNumberOfChickens(1000);
    updateFarmCoopRequest.setChickenArrivalDate(new Date());

    ResponseEntity<Object> updatedFarmCoopRes =
        farmController.updateFarmCoop(updateFarmCoopRequest);
    assertEquals(200, updatedFarmCoopRes.getStatusCode().value());

    ResponseEntity<Object> updateResponse = farmController.updateExpense(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Invalid coop ID", messageResponse.getMessage());
  }

  @Test
  @Order(27)
  @DisplayName(
      "updateSales - Should return a Invalid coop ID error when invalid coop ID is provided")
  void testUpdateSalesInvalidCoopIdRequest() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateSaleRequest request = new UpdateSaleRequest();
    request.setId(UUID.randomUUID().toString());
    request.setFarmId(farmResponse.getId());
    request.setCoopId("test_coopId");
    request.setNumberOfDozensSold(10);
    request.setSalePricePerDozen(50D);
    request.setBuyerName("Chrisopher Sibiya");
    request.setRecordedBy(UUID.randomUUID().toString());
    request.setPaymentStatus(PaymentStatus.PAID);
    request.setSaleDate(new Date());

    ResponseEntity<Object> updateResponse = farmController.updateSales(request);
    MessageResponse messageResponse = (MessageResponse) updateResponse.getBody();
    assertFalse(Objects.requireNonNull(messageResponse).isSuccess());
    assertEquals("Invalid coop ID", messageResponse.getMessage());
  }

  @Test
  @Order(28)
  @DisplayName("updateMortalities - Should add mortality when valid request is provided")
  void testUpdateMortalitiesValidaRequest() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    Coop coop = Objects.requireNonNull(farmResponse).getCoops().getFirst();

    UpdateMortalityRequest request =
        UpdateMortalityRequest.builder()
            .farmId(farmResponse.getId())
            .coopId(coop.getId())
            .dateOccurred(new Date())
            .numberOfDeaths(1)
            .reason("Test Reason")
            .recordedBy(UUID.randomUUID().toString())
            .build();

    ResponseEntity<Object> updateResponse = farmController.updateMortalities(request);
    FarmResponse updatedFarmRes = (FarmResponse) updateResponse.getBody();
    Coop updatedCoop =
        Objects.requireNonNull(updatedFarmRes).getCoops().stream()
            .filter(c -> c.getId().equals(coop.getId()))
            .findFirst()
            .orElse(null);
    assert updatedCoop != null;
    assertNotNull(updatedFarmRes);
    assertEquals(2, updatedFarmRes.getCoops().size());
    assertEquals(1, updatedCoop.getMortalities().size());
    Mortality mortality = updatedCoop.getMortalities().getFirst();

    assertNotNull(mortality.getId());
    assertNotNull(mortality.getCreatedDate());
    assertEquals(request.getDateOccurred(), mortality.getDateOccurred());
    assertEquals(request.getNumberOfDeaths(), mortality.getNumberOfDeaths());
    assertEquals(request.getReason(), mortality.getReason());
    assertEquals(request.getRecordedBy(), mortality.getRecordedBy());
  }

  @Test
  @Order(29)
  @DisplayName("updateExpense - Should add expense when valid request is provided")
  void testUpdateExpenseValidaRequest() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    Coop coop = Objects.requireNonNull(farmResponse).getCoops().getFirst();

    UpdateExpenseRequest request = new UpdateExpenseRequest();
    request.setFarmId(farmResponse.getId());
    request.setCoopId(coop.getId());
    request.setExpenseDate(new Date());
    request.setExpenseType("FEED");
    request.setAmount(380.0D);
    request.setAdditionalInfo("Chicken feeds");
    request.setRecordedBy(UUID.randomUUID().toString());

    ResponseEntity<Object> updateResponse = farmController.updateExpense(request);
    FarmResponse updatedFarmRes = (FarmResponse) updateResponse.getBody();
    Coop updatedCoop =
        Objects.requireNonNull(updatedFarmRes).getCoops().stream()
            .filter(c -> c.getId().equals(coop.getId()))
            .findFirst()
            .orElse(null);
    assertNotNull(updatedFarmRes);
    assertEquals(2, updatedFarmRes.getCoops().size());
    assertEquals(1, updatedCoop.getExpenses().size());
    Expense expense = updatedCoop.getExpenses().getFirst();

    assertNotNull(expense.getId());
    assertNotNull(expense.getCreatedDate());
    assertEquals(request.getExpenseType(), expense.getExpenseType());
    assertEquals(request.getAmount(), expense.getAmount());
    assertEquals(request.getAdditionalInfo(), expense.getAdditionalInfo());
    assertEquals(request.getRecordedBy(), expense.getRecordedBy());
  }

  @Test
  @Order(30)
  @DisplayName("updateMortalities - Should update mortality when valid request is provided")
  void testUpdateMortalities_updateExistingMortality() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    Coop coop = Objects.requireNonNull(farmResponse).getCoops().getFirst();
    Mortality mortality = coop.getMortalities().getFirst();
    UpdateMortalityRequest request =
        UpdateMortalityRequest.builder()
            .id(mortality.getId())
            .farmId(farmResponse.getId())
            .coopId(coop.getId())
            .dateOccurred(new Date())
            .numberOfDeaths(10)
            .reason("Gomboro")
            .recordedBy(UUID.randomUUID().toString())
            .build();

    ResponseEntity<Object> updateResponse = farmController.updateMortalities(request);
    FarmResponse updatedFarmRes = (FarmResponse) updateResponse.getBody();
    Coop updatedCoop =
        Objects.requireNonNull(updatedFarmRes).getCoops().stream()
            .filter(c -> c.getId().equals(coop.getId()))
            .findFirst()
            .orElse(null);
    assertNotNull(updatedFarmRes);
    assertEquals(2, updatedFarmRes.getCoops().size());
    assertEquals(1, updatedCoop.getMortalities().size());
    Mortality updatedMortality = updatedCoop.getMortalities().getFirst();

    assertEquals(mortality.getId(), updatedMortality.getId());
    assertEquals(mortality.getCreatedDate(), updatedMortality.getCreatedDate());
    assertEquals(request.getDateOccurred(), updatedMortality.getDateOccurred());
    assertEquals(request.getNumberOfDeaths(), updatedMortality.getNumberOfDeaths());
    assertEquals(request.getReason(), updatedMortality.getReason());
    assertEquals(request.getRecordedBy(), updatedMortality.getRecordedBy());
  }

  @Test
  @Order(31)
  @DisplayName("updateExpense - Should update expense when valid request is provided")
  void testUpdateExpense_updateExistingMortality() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    Coop coop = Objects.requireNonNull(farmResponse).getCoops().getFirst();
    Expense expense = coop.getExpenses().getFirst();

    UpdateExpenseRequest request = new UpdateExpenseRequest();
    request.setId(expense.getId());
    request.setFarmId(farmResponse.getId());
    request.setCoopId(coop.getId());
    request.setExpenseDate(new Date());
    request.setExpenseType("MEDICAL_SUPPLIES");
    request.setAmount(1000D);
    request.setAdditionalInfo("Medical expense");
    request.setRecordedBy(UUID.randomUUID().toString());

    ResponseEntity<Object> updateResponse = farmController.updateExpense(request);
    FarmResponse updatedFarmRes = (FarmResponse) updateResponse.getBody();
    Coop updatedCoop =
        Objects.requireNonNull(updatedFarmRes).getCoops().stream()
            .filter(c -> c.getId().equals(coop.getId()))
            .findFirst()
            .orElse(null);
    assertNotNull(updatedFarmRes);
    assertEquals(2, updatedFarmRes.getCoops().size());
    assertEquals(1, updatedCoop.getExpenses().size());
    Expense updatedExpense = updatedCoop.getExpenses().getFirst();

    assertEquals(expense.getId(), updatedExpense.getId());
    assertEquals(expense.getCreatedDate(), updatedExpense.getCreatedDate());
    assertEquals(request.getExpenseType(), updatedExpense.getExpenseType());
    assertEquals(request.getAmount(), updatedExpense.getAmount());
    assertEquals(request.getAdditionalInfo(), updatedExpense.getAdditionalInfo());
    assertEquals(request.getRecordedBy(), updatedExpense.getRecordedBy());
  }

  @Test
  @Order(32)
  @DisplayName("updateSales - Should add sale when valid request is provided")
  void testUpdateSalesToBroilerCoop() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    Coop coop = Objects.requireNonNull(farmResponse).getCoops().getFirst();

    UpdateSaleRequest request = new UpdateSaleRequest();
    request.setFarmId(farmResponse.getId());
    request.setCoopId(coop.getId());
    request.setNumberOfChickensSold(10);
    request.setSalePricePerChicken(85D);
    request.setBuyerName("Chrisopher Sibiya");
    request.setRecordedBy(UUID.randomUUID().toString());
    request.setPaymentStatus(PaymentStatus.PAID);
    request.setSaleDate(new Date());

    ResponseEntity<Object> updateResponse = farmController.updateSales(request);
    FarmResponse updatedFarmRes = (FarmResponse) updateResponse.getBody();
    Coop updatedCoop =
        Objects.requireNonNull(updatedFarmRes).getCoops().stream()
            .filter(c -> c.getId().equals(coop.getId()))
            .findFirst()
            .orElse(null);
    assertNotNull(updatedFarmRes);
    assertEquals(2, updatedFarmRes.getCoops().size());
    assertEquals(1, updatedCoop.getMortalities().size());
    Sale sale = updatedCoop.getSales().getFirst();

    assertNotNull(sale.getId());
    assertNotNull(sale.getCreatedDate());
    assertEquals(request.getNumberOfChickensSold(), sale.getNumberOfChickensSold());
    assertEquals(request.getSalePricePerChicken(), sale.getSalePricePerChicken());
    assertEquals(request.getBuyerName(), sale.getBuyerName());
    assertEquals(request.getPaymentStatus(), sale.getPaymentStatus());
    assertEquals(request.getSaleDate(), sale.getSaleDate());
    assertEquals(850, sale.getTotalSaleAmount());
  }

  @Test
  @Order(33)
  @DisplayName("updateSales - Should add sale when valid request is provided")
  void testUpdateSalesToLayerCoop() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    UpdateFarmCoopRequest updateFarmCoopRequest = new UpdateFarmCoopRequest();
    updateFarmCoopRequest.setGrowthPhase(GrowingPhase.BROODING_PHASE);
    updateFarmCoopRequest.setFarmId(farmResponse.getId());
    updateFarmCoopRequest.setCoopName("CoopName 2");
    updateFarmCoopRequest.setCoopType(CoopType.LAYERS);
    updateFarmCoopRequest.setNumberOfChickens(1000);
    updateFarmCoopRequest.setChickenArrivalDate(new Date());

    ResponseEntity<Object> updatedFarmCoopRes =
        farmController.updateFarmCoop(updateFarmCoopRequest);
    FarmResponse updatedFarmResponse =
        (FarmResponse) Objects.requireNonNull(updatedFarmCoopRes.getBody());
    assertEquals(200, updatedFarmCoopRes.getStatusCode().value());

    Coop coop =
        Objects.requireNonNull(updatedFarmResponse).getCoops().stream()
            .filter(c -> c.getCoopType().equals(CoopType.LAYERS))
            .findFirst()
            .orElse(null);

    UpdateSaleRequest request = new UpdateSaleRequest();
    request.setFarmId(farmResponse.getId());
    request.setCoopId(coop.getId());
    request.setNumberOfDozensSold(10);
    request.setSalePricePerDozen(85D);
    request.setBuyerName("Chrisopher Sibiya");
    request.setRecordedBy(UUID.randomUUID().toString());
    request.setPaymentStatus(PaymentStatus.PAID);
    request.setSaleDate(new Date());

    ResponseEntity<Object> updateResponse = farmController.updateSales(request);
    FarmResponse updatedFarmRes = (FarmResponse) updateResponse.getBody();
    Coop updatedCoop =
        Objects.requireNonNull(updatedFarmRes).getCoops().stream()
            .filter(c -> c.getCoopType().equals(CoopType.LAYERS))
            .findFirst()
            .orElse(null);
    assertNotNull(updatedFarmRes);
    assertEquals(3, updatedFarmRes.getCoops().size());
    assert updatedCoop != null;
    assertEquals(1, updatedCoop.getSales().size());
    Sale sale = updatedCoop.getSales().getFirst();

    assertNotNull(sale.getId());
    assertNotNull(sale.getCreatedDate());
    assertEquals(request.getNumberOfDozensSold(), sale.getNumberOfDozensSold());
    assertEquals(request.getSalePricePerDozen(), sale.getSalePricePerDozen());
    assertEquals(request.getBuyerName(), sale.getBuyerName());
    assertEquals(request.getPaymentStatus(), sale.getPaymentStatus());
    assertEquals(request.getSaleDate(), sale.getSaleDate());
    assertEquals(850, sale.getTotalSaleAmount());
  }

  @Test
  @Order(34)
  @DisplayName("updateSales - Should update sale when valid request is provided")
  void testUpdateSalesToLayerCoop_updatingExistingSale() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    Coop coop =
        Objects.requireNonNull(farmResponse).getCoops().stream()
            .filter(c -> c.getCoopType().equals(CoopType.LAYERS))
            .findFirst()
            .orElse(null);

    Sale sale = coop.getSales().getFirst();
    UpdateSaleRequest request = new UpdateSaleRequest();
    request.setId(sale.getId());
    request.setFarmId(farmResponse.getId());
    request.setCoopId(coop.getId());
    request.setNumberOfDozensSold(100);
    request.setSalePricePerDozen(80D);
    request.setBuyerName("Chrisoph Sibiya");
    request.setRecordedBy(UUID.randomUUID().toString());
    request.setPaymentStatus(PaymentStatus.PENDING);
    request.setSaleDate(new Date());

    ResponseEntity<Object> updateResponse = farmController.updateSales(request);
    FarmResponse updatedFarmRes = (FarmResponse) updateResponse.getBody();
    Coop updatedCoop =
        Objects.requireNonNull(updatedFarmRes).getCoops().stream()
            .filter(c -> c.getCoopType().equals(CoopType.LAYERS))
            .findFirst()
            .orElse(null);
    assertNotNull(updatedFarmRes);
    assertEquals(3, updatedFarmRes.getCoops().size());
    assert updatedCoop != null;
    assertEquals(1, updatedCoop.getSales().size());
    Sale updatedSale = updatedCoop.getSales().getFirst();

    assertEquals(sale.getId(), updatedSale.getId());
    assertEquals(sale.getCreatedDate(), updatedSale.getCreatedDate());
    assertEquals(request.getNumberOfDozensSold(), updatedSale.getNumberOfDozensSold());
    assertEquals(request.getSalePricePerDozen(), updatedSale.getSalePricePerDozen());
    assertEquals(request.getBuyerName(), updatedSale.getBuyerName());
    assertEquals(request.getPaymentStatus(), updatedSale.getPaymentStatus());
    assertEquals(request.getSaleDate(), updatedSale.getSaleDate());
    assertEquals(8000, updatedSale.getTotalSaleAmount());
  }

  @Test
  @Order(35)
  @DisplayName("addNewBatch - Should clear coop and add new coop details")
  void testAddNewBatch() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> response =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());

    Coop coop =
        Objects.requireNonNull(farmResponse).getCoops().stream()
            .filter(c -> c.getCoopType().equals(CoopType.LAYERS))
            .findFirst()
            .orElse(null);

    UpdateFarmCoopRequest request = new UpdateFarmCoopRequest();
    request.setFarmId(farmResponse.getId());
    assert coop != null;
    request.setGrowthPhase(GrowingPhase.BROODING_PHASE);
    request.setCoopId(coop.getId());
    request.setCoopName("Clean Coop");
    request.setCoopType(CoopType.BROILER);
    request.setNumberOfChickens(10000);
    request.setChickenArrivalDate(new Date());

    ResponseEntity<Object> updateResponse = farmController.addNewBatch(request);
    FarmResponse updatedFarmRes = (FarmResponse) updateResponse.getBody();
    Coop updatedCoop =
        Objects.requireNonNull(updatedFarmRes).getCoops().stream()
            .filter(c -> c.getId().equals(coop.getId()))
            .findFirst()
            .orElse(null);

    assertNotNull(updatedFarmRes);
    assertEquals(3, updatedFarmRes.getCoops().size());
    assert updatedCoop != null;

    assertNull(updatedCoop.getSales());
    assertNull(updatedCoop.getExpenses());
    assertNull(updatedCoop.getMortalities());

    assertEquals(coop.getId(), updatedCoop.getId());
    assertEquals("Clean Coop", updatedCoop.getCoopName());
    assertEquals(10000, updatedCoop.getNumberOfChickens());
    assertEquals(CoopType.BROILER, updatedCoop.getCoopType());

    assertNotNull(updatedCoop.getReminder());
    assertNotEquals(coop.getReminder().getId(), updatedCoop.getReminder().getId());
    if (updatedCoop.getCoopType() == CoopType.LAYERS) {
      assertEquals(7, updatedCoop.getReminder().getFeeds().size());
      assertEquals(6, updatedCoop.getReminder().getMedicines().size());
      assertEquals(7, updatedCoop.getReminder().getVaccines().size());
    } else {
      assertEquals(1, updatedCoop.getReminder().getFeeds().size());
      assertEquals(2, updatedCoop.getReminder().getMedicines().size());
      assertEquals(1, updatedCoop.getReminder().getVaccines().size());
    }
  }

  @Test
  @Order(36)
  @DisplayName("updateLoginDetails - Should successfully update password when all inputs are valid")
  void shouldSuccessfullyUpdatePasswordWhenAllInputsAreValid() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("Password");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    UpdateLoginDetailsRequest request = new UpdateLoginDetailsRequest();
    assert loggedUser != null;
    request.setUserId(loggedUser.getId());
    request.setCurrentPassword("Password");
    request.setNewPassword("NewValidPassword123!");

    ResponseEntity<Object> response = farmController.updateLoginDetails(request);

    assertEquals(HttpStatus.OK, response.getStatusCode());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertNotNull(messageResponse);
    assertTrue(messageResponse.isSuccess());
    assertEquals("Password updated successfully", messageResponse.getMessage());

    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    loginResponse = authController.authenticateUser(loginRequest);
    assertEquals(HttpStatus.OK, loginResponse.getStatusCode());
  }

  @Test
  @Order(37)
  @DisplayName("updateLoginDetails - Should return bad request when user ID is invalid")
  void shouldReturnBadRequestWhenUserIdIsInvalid() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    UpdateLoginDetailsRequest request = new UpdateLoginDetailsRequest();
    assert loggedUser != null;
    request.setUserId(loggedUser.getId());
    request.setCurrentPassword("InvalidPassword");
    request.setNewPassword("NewPassword");

    ResponseEntity<Object> response = farmController.updateLoginDetails(request);

    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals(
        "We are unable to update your password, please verify that your current password is correct and try again",
        messageResponse.getMessage());
  }

  @Test
  @Order(38)
  @DisplayName("updateLoginDetails - Should return bad request when new password is invalid")
  void shouldReturnBadRequestWhenNewPasswordIsInvalid() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    UpdateLoginDetailsRequest request = new UpdateLoginDetailsRequest();
    assert loggedUser != null;
    request.setUserId(loggedUser.getId());
    request.setCurrentPassword("NewValidPassword123!");
    request.setNewPassword("InValidaNewPassword");

    ResponseEntity<Object> response = farmController.updateLoginDetails(request);

    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals(
        "Invalid password, please provide a strong password", messageResponse.getMessage());
  }

  @Test
  @Order(39)
  @DisplayName("updateLoginDetails - Should return bad request when current password is incorrect")
  void shouldReturnBadRequestWhenCurrentPasswordIsIncorrect() {

    UpdateLoginDetailsRequest request = new UpdateLoginDetailsRequest();
    request.setUserId("invalidUserId");

    ResponseEntity<Object> response = farmController.updateLoginDetails(request);

    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals("Invalid user ID", messageResponse.getMessage());
  }

  @Test
  @Order(40)
  @DisplayName(
      "addFarmUser - Should successfully add a farm user when all required fields are provided and valid")
  void shouldSuccessfullyAddFarmUserWhenAllFieldsAreValidAndProvided() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();
    assert loggedUser != null;

    List<ERole> roles = new ArrayList<>();
    roles.add(ERole.ROLE_FARM_WORKER);
    AddFarmUserRequest request = new AddFarmUserRequest();
    request.setFarmId(loggedUser.getFarmId());
    request.setName("Hlaluko");
    request.setSurname("Sibiya");
    request.setPhoneNumber("0729255658");
    request.setEmail("hlaluko.sibiya@gmail.com");
    request.setRoles(roles);
    request.setAddedByUserId(loggedUser.getId());

    ResponseEntity<Object> response = farmController.addFarmUser(request);

    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertInstanceOf(FarmResponse.class, response.getBody());
    FarmResponse farmResponse = (FarmResponse) response.getBody();

    UserInfoResponse userInfoResponse =
        farmResponse.getUsers().stream()
            .filter(user -> user.getEmail().equals(request.getEmail()))
            .findFirst()
            .orElse(null);

    assertNotNull(userInfoResponse);
    assertEquals(request.getName(), userInfoResponse.getName());
    assertEquals(request.getSurname(), userInfoResponse.getSurname());
    assertEquals(request.getPhoneNumber(), userInfoResponse.getPhoneNumber());
    assertEquals(request.getEmail(), userInfoResponse.getEmail());
    assertNotNull(userInfoResponse.getRoles());
    assertTrue(userInfoResponse.getRoles().contains(ERole.ROLE_USER.name()));
    assertTrue(userInfoResponse.getRoles().contains(ERole.ROLE_FARM_WORKER.name()));

    loginRequest.setUsername("hlaluko.sibiya@gmail.com");
    loginRequest.setPassword("0729255658");
    loginResponse = authController.authenticateUser(loginRequest);
    assertEquals(HttpStatus.OK, loginResponse.getStatusCode());
  }

  @Test
  @Order(40)
  @DisplayName("addFarmUser - Should return a bad request response when the farm ID does not exist")
  void shouldReturnBadRequestWhenFarmNotFound() {

    List<ERole> roles = new ArrayList<>();
    roles.add(ERole.ROLE_FARM_WORKER);
    AddFarmUserRequest request = new AddFarmUserRequest();
    request.setFarmId("InvalidFarmId");
    request.setName("Hlaluko");
    request.setSurname("Sibiya");
    request.setPhoneNumber("0729255658");
    request.setEmail("hlaluko.sibiya@gmail.com");
    request.setRoles(roles);
    request.setAddedByUserId(UUID.randomUUID().toString());

    ResponseEntity<Object> response = farmController.addFarmUser(request);

    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(41)
  @DisplayName(
      "addFarmUser - Should return a bad request response when the email is already in use")
  void shouldReturnBadRequestWhenEmailAlreadyInUse() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();
    assert loggedUser != null;

    List<ERole> roles = new ArrayList<>();
    roles.add(ERole.ROLE_FARM_WORKER);
    AddFarmUserRequest request = new AddFarmUserRequest();
    request.setFarmId(loggedUser.getFarmId());
    request.setName("Hlaluko");
    request.setSurname("Sibiya");
    request.setPhoneNumber("0729255658");
    request.setEmail("useremai2@gmail.com");
    request.setRoles(roles);
    request.setAddedByUserId(loggedUser.getId());

    ResponseEntity<Object> response = farmController.addFarmUser(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals("Error: Email is already in use!", messageResponse.getMessage());
  }

  @Test
  @Order(42)
  @DisplayName("updateUserRoles - Should return 'Farm not found' error when farm ID is invalid")
  void shouldReturnFarmNotFoundError_whenFarmIdIsInvalid() {
    UserRolesRequest request = new UserRolesRequest();
    request.setFarmId("invalidFarmId");

    ResponseEntity<Object> response = farmController.updateUserRoles(request);

    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(43)
  @DisplayName(
      "updateUserRoles - Should return 'User not authorized' error when updator is not a farm owner")
  void shouldReturnUserNotAuthorizedErrorWhenUpdatorIsNotFarmOwner() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("hlaluko.sibiya@gmail.com");
    loginRequest.setPassword("0729255658");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    UserInfoResponse userToUpdate =
        farmResponse.getUsers().stream()
            .filter(user -> !user.getId().equals(loggedUser.getId()))
            .findFirst()
            .orElse(null);

    UserRolesRequest request = new UserRolesRequest();
    request.setUpdatedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    assert userToUpdate != null;
    request.setUserId(userToUpdate.getId());
    request.setRoles(Collections.singletonList(ERole.ROLE_FARM_MANAGER));

    ResponseEntity<Object> response = farmController.updateUserRoles(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals(
        "User not authorized to update roles, please contact administrator",
        messageResponse.getMessage());
  }

  @Test
  @Order(44)
  @DisplayName("updateUserRoles - Should return 'User not found' error when user ID is invalid")
  void shouldReturnUserNotFoundError_whenUserIdIsInvalid() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    UserInfoResponse userToUpdate =
        farmResponse.getUsers().stream()
            .filter(user -> !user.getId().equals(loggedUser.getId()))
            .findFirst()
            .orElse(null);

    UserRolesRequest request = new UserRolesRequest();
    request.setUpdatedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    assert userToUpdate != null;
    request.setUserId("InvalidUserID");
    request.setRoles(Collections.singletonList(ERole.ROLE_FARM_MANAGER));

    ResponseEntity<Object> response = farmController.updateUserRoles(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals("User not found", messageResponse.getMessage());
  }

  @Test
  @Order(45)
  @DisplayName("updateUserRoles - Should successfully update roles for a non-farm owner user")
  void shouldSuccessfullyUpdateRolesForNonFarmOwnerUser() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    UserInfoResponse userToUpdate =
        farmResponse.getUsers().stream()
            .filter(user -> !user.getId().equals(loggedUser.getId()))
            .findFirst()
            .orElse(null);

    UserRolesRequest request = new UserRolesRequest();
    request.setUpdatedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    assert userToUpdate != null;
    request.setUserId(userToUpdate.getId());
    request.setRoles(Collections.singletonList(ERole.ROLE_FARM_MANAGER));

    ResponseEntity<Object> response = farmController.updateUserRoles(request);
    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertInstanceOf(FarmResponse.class, response.getBody());
    FarmResponse updatedFarmResponse = (FarmResponse) response.getBody();

    Optional<User> userOptional = userRepository.findById(userToUpdate.getId());
    User updatedUser = null;
    if (userOptional.isPresent()) {
      updatedUser = userOptional.get();
    }
    assert updatedUser != null;

    UserInfoResponse updatedUserInfo =
        updatedFarmResponse.getUsers().stream()
            .filter(user -> user.getId().equals(userToUpdate.getId()))
            .findFirst()
            .orElse(null);

    assert updatedUserInfo != null;
    assertEquals(2, updatedUserInfo.getRoles().size());
    assertTrue(updatedUserInfo.getRoles().contains(ERole.ROLE_FARM_MANAGER.name()));
    assertTrue(updatedUserInfo.getRoles().contains(ERole.ROLE_USER.name()));
    assertEquals(updatedUser.getRolesUpdatedByUserId(), loggedUser.getId());
  }

  @Test
  @Order(46)
  @DisplayName(
      "updateUserRoles - Should return 'Farm owner roles can not be updated' error when trying to update farm owner's roles")
  void shouldReturnErrorWhenUpdatingFarmOwnerRoles() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    UserInfoResponse userToUpdate =
        farmResponse.getUsers().stream()
            .filter(user -> !user.getId().equals(loggedUser.getId()))
            .findFirst()
            .orElse(null);

    UserRolesRequest request = new UserRolesRequest();
    request.setUpdatedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    assert userToUpdate != null;
    request.setUserId(loggedUser.getId());
    request.setRoles(Collections.singletonList(ERole.ROLE_FARM_MANAGER));

    ResponseEntity<Object> response = farmController.updateUserRoles(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals(
        "Farm owner roles can not be updated, please contact administrator",
        messageResponse.getMessage());
  }

  @Test
  @Order(47)
  @DisplayName("removeUser - Should return 'Farm not found' error when the farm ID is invalid")
  void removeUserShouldReturnFarmNotFoundError_whenFarmIdIsInvalid() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    UserInfoResponse userToUpdate =
        farmResponse.getUsers().stream()
            .filter(user -> !user.getId().equals(loggedUser.getId()))
            .findFirst()
            .orElse(null);
    assert userToUpdate != null;
    RemoveUserRequest request = new RemoveUserRequest();
    request.setDeletedByUserId(loggedUser.getId());
    request.setFarmId("InvalidaFarmID");
    request.setUserId(userToUpdate.getId());

    ResponseEntity<Object> response = farmController.removeUser(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(48)
  @DisplayName(
      "removeUser - Should return 'User not found' error when the user ID to be removed is invalid")
  void removeUserShouldReturnUserNotFoundError_whenUserIdIsInvalid() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    UserInfoResponse userToUpdate =
        farmResponse.getUsers().stream()
            .filter(user -> !user.getId().equals(loggedUser.getId()))
            .findFirst()
            .orElse(null);
    assert userToUpdate != null;
    RemoveUserRequest request = new RemoveUserRequest();
    request.setDeletedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    request.setUserId("InvalidaUserID");

    ResponseEntity<Object> response = farmController.removeUser(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals("User not found", messageResponse.getMessage());
  }

  @Test
  @Order(49)
  @DisplayName(
      "removeUser - Should return 'User not authorized' error when the requesting user is not a farm owner")
  void removeUserShouldReturnUnauthorizedError_whenRequestingUserIsNotFarmOwner()
      throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    UserInfoResponse userToUpdate =
        farmResponse.getUsers().stream()
            .filter(user -> !user.getId().equals(loggedUser.getId()))
            .findFirst()
            .orElse(null);
    assert userToUpdate != null;
    RemoveUserRequest request = new RemoveUserRequest();
    request.setDeletedByUserId(userToUpdate.getId());
    request.setFarmId(loggedUser.getFarmId());
    request.setUserId(userToUpdate.getId());

    ResponseEntity<Object> response = farmController.removeUser(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals(
        "User not authorized to remove user, please contact administrator",
        messageResponse.getMessage());
  }

  @Test
  @Order(50)
  @DisplayName(
      "removeUser - Should return 'Farm owner cannot be removed' error when attempting to remove a farm owner")
  void removeUserShouldReturnErrorWhenAttemptingToRemoveFarmOwner() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    UserInfoResponse userToUpdate =
        farmResponse.getUsers().stream()
            .filter(UserInfoResponse::isFarmOwner)
            .findFirst()
            .orElse(null);
    assert userToUpdate != null;
    RemoveUserRequest request = new RemoveUserRequest();
    request.setDeletedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    request.setUserId(userToUpdate.getId());

    ResponseEntity<Object> response = farmController.removeUser(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals(
        "Farm owner cannot be removed from the farm, please contact administrator",
        messageResponse.getMessage());
  }

  @Test
  @Order(51)
  @DisplayName(
      "removeUser - Should successfully remove a non-farm owner user when requested by a farm owner")
  void shouldSuccessfullyRemoveNonFarmOwnerUser() throws PoultryPalException {

    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    UserInfoResponse userToUpdate =
        farmResponse.getUsers().stream()
            .filter(user -> !user.getId().equals(loggedUser.getId()))
            .findFirst()
            .orElse(null);

    RemoveUserRequest request = new RemoveUserRequest();
    request.setDeletedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    assert userToUpdate != null;
    request.setUserId(userToUpdate.getId());

    ResponseEntity<Object> response = farmController.removeUser(request);
    assertEquals(HttpStatus.OK, response.getStatusCode());
    FarmResponse updatedFarmResponse = (FarmResponse) response.getBody();
    assert updatedFarmResponse != null;
    UserInfoResponse updatedUserRes =
        updatedFarmResponse.getUsers().stream()
            .filter(user -> user.getId().equals(request.getUserId()))
            .findFirst()
            .orElse(null);
    assertNull(updatedUserRes);

    Optional<User> userOptional = userRepository.findById(request.getUserId());
    User updatedUser = null;
    if (userOptional.isPresent()) {
      updatedUser = userOptional.get();
    }
    assert updatedUser != null;
    assertTrue(updatedUser.isRemoved());
  }

  @Test
  @Order(52)
  @DisplayName("deleteCoopItem - Should return a bad request response when the farm is not found")
  void deleteCoopItemWhenFarmNotFound_shouldReturnBadRequest() {
    RemoveCoopIteamRequest request = new RemoveCoopIteamRequest();
    request.setFarmId("invalidFarmId");

    ResponseEntity<Object> response = farmController.deleteCoopItem(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals("Farm not found", messageResponse.getMessage());
  }

  @Test
  @Order(53)
  @DisplayName("deleteCoopItem - Should return a bad request response when the coop is not found")
  void deleteCoopItemWhenCoopNotFound_shouldReturnBadRequest() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();
    assert loggedUser != null;

    RemoveCoopIteamRequest request = new RemoveCoopIteamRequest();
    request.setFarmId(loggedUser.getFarmId());
    request.setCoopId("invalidCoop");

    ResponseEntity<Object> response = farmController.deleteCoopItem(request);
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
    assertInstanceOf(MessageResponse.class, response.getBody());
    MessageResponse messageResponse = (MessageResponse) response.getBody();
    assertFalse(messageResponse.isSuccess());
    assertEquals("Coop not found", messageResponse.getMessage());
  }

  @Test
  @Order(54)
  @DisplayName("deleteCoopItem - Should successfully remove a sale item from the coop")
  void deleteCoopItemShouldSuccessfullyRemoveSaleItem() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();
    assert loggedUser != null;

    ResponseEntity<Object> responseObj =
        farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    Coop coop =
        farmResponse.getCoops().stream()
            .filter(c -> c.getSales() != null && !c.getSales().isEmpty())
            .findFirst()
            .orElse(null);
      assert coop != null;

      Sale saleToDelete = coop.getSales().getFirst();

    RemoveCoopIteamRequest request = new RemoveCoopIteamRequest();
    request.setDeletedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    request.setCoopId(coop.getId());
    request.setItemId(saleToDelete.getId());
    request.setItemType("SALE");

    ResponseEntity<Object> response = farmController.deleteCoopItem(request);
    assertEquals(HttpStatus.OK, response.getStatusCode());
    FarmResponse updatedFarmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());
    assertTrue(updatedFarmResponse.getCoops().stream().anyMatch(c -> c.getId().equals(coop.getId())));
    assertFalse(updatedFarmResponse.getCoops().stream()
       .anyMatch(c -> c.getId().equals(coop.getId()) && c.getSales().contains(saleToDelete)));
  }

  @Test
  @Order(55)
  @DisplayName("deleteCoopItem - Should successfully remove a mortality item from the coop")
  void deleteCoopItemShouldSuccessfullyRemoveMortalityItem() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();
    assert loggedUser != null;

    ResponseEntity<Object> responseObj =
            farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    Coop coop =
            farmResponse.getCoops().stream()
                    .filter(c -> c.getMortalities() != null && !c.getMortalities().isEmpty())
                    .findFirst()
                    .orElse(null);
    assert coop != null;

    Mortality mortalityToDelete = coop.getMortalities().getFirst();

    RemoveCoopIteamRequest request = new RemoveCoopIteamRequest();
    request.setDeletedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    request.setCoopId(coop.getId());
    request.setItemId(mortalityToDelete.getId());
    request.setItemType("Mortality");

    ResponseEntity<Object> response = farmController.deleteCoopItem(request);
    assertEquals(HttpStatus.OK, response.getStatusCode());
    FarmResponse updatedFarmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());
    assertTrue(updatedFarmResponse.getCoops().stream().anyMatch(c -> c.getId().equals(coop.getId())));
    assertFalse(updatedFarmResponse.getCoops().stream()
            .anyMatch(c -> c.getId().equals(coop.getId()) && c.getMortalities().contains(mortalityToDelete)));
  }


  @Test
  @Order(55)
  @DisplayName("deleteCoopItem - Should successfully remove an expense item from the coop")
  void deleteCoopItemShouldSuccessfullyRemoveExpenseItem() throws PoultryPalException {
    LoginRequest loginRequest = new LoginRequest();
    loginRequest.setUsername("chrissibiya@gmail.com");
    loginRequest.setPassword("NewValidPassword123!");
    ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
    UserInfoResponse loggedUser = (UserInfoResponse) loginResponse.getBody();
    assert loggedUser != null;

    ResponseEntity<Object> responseObj =
            farmController.findFarmById(Objects.requireNonNull(loggedUser).getFarmId());
    FarmResponse farmResponse = (FarmResponse) Objects.requireNonNull(responseObj.getBody());

    Coop coop =
            farmResponse.getCoops().stream()
                    .filter(c -> c.getExpenses() != null && !c.getExpenses().isEmpty())
                    .findFirst()
                    .orElse(null);
    assert coop != null;

    Expense expenseToDelete = coop.getExpenses().getFirst();

    RemoveCoopIteamRequest request = new RemoveCoopIteamRequest();
    request.setDeletedByUserId(loggedUser.getId());
    request.setFarmId(loggedUser.getFarmId());
    request.setCoopId(coop.getId());
    request.setItemId(expenseToDelete.getId());
    request.setItemType("Expense");

    ResponseEntity<Object> response = farmController.deleteCoopItem(request);
    assertEquals(HttpStatus.OK, response.getStatusCode());
    FarmResponse updatedFarmResponse = (FarmResponse) Objects.requireNonNull(response.getBody());
    assertTrue(updatedFarmResponse.getCoops().stream().anyMatch(c -> c.getId().equals(coop.getId())));
    assertFalse(updatedFarmResponse.getCoops().stream()
            .anyMatch(c -> c.getId().equals(coop.getId()) && c.getExpenses().contains(expenseToDelete)));
  }

  private static @NotNull List<SignupRequest> getSignupRequests() {
    SignupRequest request1 = new SignupRequest();
    request1.setName("Init-Name");
    request1.setSurname("Init-Surname");
    request1.setEmail("useremai@gmail.com");
    request1.setPhoneNumber("0729566589");
    request1.setPassword("Password");
    request1.setFarmName("Farm Name 1");
    request1.setFarmAddressLine1("Address Line 1");
    request1.setFarmAddressLine2("Address Line 2");
    request1.setFarmState("State");
    request1.setFarmCity("City");
    request1.setFarmPostalCode("0000");
    request1.setFarmCountry("South Africa");

    SignupRequest request2 = new SignupRequest();
    request2.setName("Init-UserName");
    request2.setSurname("Init-UserSurname");
    request2.setEmail("useremai2@gmail.com");
    request2.setPhoneNumber("0729566589");
    request2.setPassword("Password");
    request2.setFarmName("Farm Name 2");
    request2.setFarmAddressLine1("Address Line 1");
    request2.setFarmAddressLine2("Address Line 2");
    request2.setFarmState("State");
    request2.setFarmCity("City");
    request2.setFarmPostalCode("0000");
    request2.setFarmCountry("South Africa");

    SignupRequest request3 = new SignupRequest();
    request3.setName("Chris");
    request3.setSurname("Sibiya");
    request3.setEmail("chrissibiya@gmail.com");
    request3.setPhoneNumber("0729566589");
    request3.setPassword("Password");
    request3.setFarmName("KGF");
    request3.setFarmAddressLine1("Address Line 1");
    request3.setFarmAddressLine2("Address Line 2");
    request3.setFarmState("State");
    request3.setFarmCity("City");
    request3.setFarmPostalCode("0000");
    request3.setFarmCountry("South Africa");

    List<SignupRequest> signupRequests = new ArrayList<>();
    signupRequests.add(request1);
    signupRequests.add(request2);
    signupRequests.add(request3);

    return signupRequests;
  }

  private @Nullable UserInfoResponse getLoggedUser() {
    try {
      LoginRequest loginRequest = new LoginRequest();
      loginRequest.setUsername("useremai@gmail.com");
      loginRequest.setPassword("Password");
      ResponseEntity<Object> loginResponse = authController.authenticateUser(loginRequest);
      return (UserInfoResponse) loginResponse.getBody();
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }
}
