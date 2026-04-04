package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.excption.NotFoundException;
import co.za.hlaluko.dynamics.poultry.pal.mail.Email;
import co.za.hlaluko.dynamics.poultry.pal.mail.EmailSender;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.*;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.CoopType;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.PhaseTransition;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Reminder;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.*;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.*;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.FarmResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.MessageResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserInfoResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.UserSettingsResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.*;
import co.za.hlaluko.dynamics.poultry.pal.security.SecurityUtils;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import co.za.hlaluko.dynamics.poultry.pal.utils.ConstantUtil;
import co.za.hlaluko.dynamics.poultry.pal.utils.PoultryPalUtil;
import co.za.hlaluko.dynamics.poultry.pal.utils.ValidationUtil;
import co.za.hlaluko.dynamics.poultry.pal.utils.exception.PoultryPalException;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.oned.Code128Writer;
import com.openhtmltopdf.pdfboxout.PdfRendererBuilder;
import java.io.ByteArrayOutputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.text.MessageFormat;
import java.text.SimpleDateFormat;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.ArrayList;
import java.util.Date;
import java.util.stream.Collectors;
import lombok.AllArgsConstructor;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

@Service
@AllArgsConstructor
public class FarmServiceImpl implements FarmService {
  private static final Logger logger = LogManager.getLogger(FarmServiceImpl.class);
  private final FarmRepository farmRepository;
  private final CoopArchiveRepository coopArchiveRepository;
  private final UserRepository userRepository;
  private final PasswordEncoder encoder;
  private final FeedScheduleService feedScheduleService;
  private final MedicineScheduleService medicineScheduleService;
  private final VaccineScheduleService vaccineScheduleService;
  private final AuthControllerService authControllerService;
  private final RoleRepository roleRepository;
  private final ReminderProcessor reminderProcessor;
  private final TemplateEngine templateEngine;
  private final UserSettingsRepository userSettingsRepository;
  private final EmailSender emailSender;
  private final AsyncService asyncService;

  @Override
  public ResponseEntity<Object> updateUser(UpdateUserRequest request) {

    User user;
    try {

      Optional<User> userByEmail = userRepository.findByEmail(request.getEmail());

      if (userByEmail.isPresent() && !Objects.equals(userByEmail.get().getId(), request.getId())) {
        return ResponseEntity.badRequest()
            .body(new MessageResponse(false, "Error: Email is already in use!"));
      }

      user = userRepository.save(getUser(request));
      UserInfoResponse userInfoResponse =
          UserInfoResponse.builder()
              .id(user.getId())
              .name(user.getName())
              .surname(user.getSurname())
              .email(user.getEmail())
              .phoneNumber(user.getPhoneNumber())
              .farmId(user.getFarmId())
              .isFarmOwner(user.isFarmOwner())
              .isActive(user.isActive())
              .createdDate(user.getCreatedDate())
              .roles(user.getRoles().stream().map(Role::getName).map(Enum::name).toList())
              .roleFriendlyNames(
                  user.getRoles().stream().map(Role::getName).map(ERole::getValue).toList())
              .build();
      logger.info("User update successful");
      return ResponseEntity.ok(userInfoResponse);
    } catch (PoultryPalException e) {
      logger.error("Update user Error: ", e);
      return ResponseEntity.badRequest().body(new MessageResponse(false, e.getMessage()));
    }
  }

  @Override
  public ResponseEntity<Object> updateLoginDetails(UpdateLoginDetailsRequest request) {
    try {

      Optional<User> optionalUser = getUserOptional(request.getUserId());
      User user;
      if (optionalUser.isPresent()) {
        user = optionalUser.get();
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsername(user.getEmail());
        loginRequest.setPassword(request.getCurrentPassword());

        // Will throw exception if login details are invalid
        authControllerService.authenticateUser(loginRequest);

        boolean isPasswordValidation = ValidationUtil.isValidPassword(request.getNewPassword());

        if (isPasswordValidation) {
          user.setPassword(encoder.encode(request.getNewPassword()));
          userRepository.save(user);
          return ResponseEntity.ok(new MessageResponse(true, "Password updated successfully"));
        } else {
          logger.info("Invalid password, please provide a strong password");
          return ResponseEntity.badRequest()
              .body(
                  new MessageResponse(false, "Invalid password, please provide a strong password"));
        }

      } else {
        logger.info("Invalid user ID: {}", request.getUserId());
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Invalid user ID"));
      }

    } catch (PoultryPalException e) {
      logger.error("Error while updating login details: ", e);
      return ResponseEntity.badRequest()
          .body(
              new MessageResponse(
                  false,
                  "We are unable to update your password, please verify that your current password is correct and try again"));
    }
  }

  private User getUser(UpdateUserRequest request) throws PoultryPalException {
    Optional<User> optionalUser = getUserOptional(request.getId());
    User user;
    if (optionalUser.isPresent()) {
      user = optionalUser.get();
      user.setName(request.getName());
      user.setSurname(request.getSurname());
      user.setEmail(request.getEmail());
      user.setPhoneNumber(request.getPhoneNumber());
    } else {
      if (request.getFarmId() == null) {
        logger.error("Farm Id cannot be null. Request: {}", request);
        throw new PoultryPalException("Farm Id cannot be null");
      } else if (farmRepository.findById(request.getFarmId()).isEmpty()) {
        logger.error("Invalid Farm Id: {}", request);
        throw new PoultryPalException("Invalid Farm Id");
      }
      user = new User();
      user.setName(request.getName());
      user.setSurname(request.getSurname());
      user.setEmail(request.getEmail());
      user.setPhoneNumber(request.getPhoneNumber());
      user.setPassword(encoder.encode(PoultryPalUtil.generatePassword()));
      user.setFarmId(request.getFarmId());
    }
    return user;
  }

  @Override
  public ResponseEntity<MessageResponse> activateUser(String userId) {
    Optional<User> optionalUser = getUserOptional(userId);
    if (optionalUser.isPresent()) {
      User user = optionalUser.get();
      user.setActive(true);
      userRepository.save(user);
      logger.info("User activated successfully");
      return ResponseEntity.ok(new MessageResponse(true, "User activated successfully"));
    } else {
      logger.error("User not found with id: {}", userId);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "User not found"));
    }
  }

  @Override
  public ResponseEntity<List<UserInfoResponse>> findAllUser() {
    List<User> userList = userRepository.findAll();
    return ResponseEntity.ok(getUserInfoResponseList(userList, null, "Finding all users"));
  }

  @Override
  public ResponseEntity<List<UserInfoResponse>> findInactiveUser() {
    List<User> userList = userRepository.findByActive(false);
    return ResponseEntity.ok(getUserInfoResponseList(userList, null, "Finding all inactive users"));
  }

  @Override
  public ResponseEntity<Object> findFarmById(String farmId) {
    Optional<Farm> farmOptional = farmRepository.findById(farmId);

    if (farmOptional.isPresent()) {
      Farm farm = farmOptional.get();
      logger.info("Farm found with id: {}", farm.getId());
      return ResponseEntity.ok(buildFarm(farm));
    } else {
      logger.error("Farm not found, Farm ID: {}", farmId);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }
  }

  @Override
  public ResponseEntity<Object> updateFarmDetails(UpdateFarmRequest request) {
    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());

    if (farmOptional.isPresent()) {
      Farm farm = farmOptional.get();
      farm.setFarmName(request.getFarmName());
      Address address = farm.getAddress();
      address.setAddressLine1(request.getFarmAddressLine1());
      address.setAddressLine2(request.getFarmAddressLine2());
      address.setCity(request.getFarmCity());
      address.setState(request.getFarmState());
      address.setPostalCode(request.getFarmPostalCode());
      address.setCountry(request.getFarmCountry());
      farm.setAddress(address);
      farm.setUpdatedByUserId(request.getUpdatedByUserId());
      farmRepository.save(farm);
      logger.info("Farm details updated");
      return ResponseEntity.ok(buildFarm(farm));

    } else {
      logger.error("Invalid Farm Id: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }
  }

  @Override
  public ResponseEntity<Object> updateExpense(UpdateExpenseRequest request) {
    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Invalid Farm Id: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    Coop coop;
    Coop tempCoop;
    if (farm.getCoops() != null && !farm.getCoops().isEmpty()) {
      coop =
          farm.getCoops().stream()
              .filter(c -> c.getId().equals(request.getCoopId()))
              .findFirst()
              .orElse(null);
      tempCoop = coop;
      if (coop == null) {
        logger.error("Invalid coop ID: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Invalid coop ID"));
      }
    } else {
      logger.error("Farm does not have coops: {}", request);
      return ResponseEntity.badRequest()
          .body(new MessageResponse(false, "Farm does not have coops"));
    }

    if (request.getId() != null) {
      Optional<Expense> expenseOptional =
          coop.getExpenses().stream().filter(e -> e.getId().equals(request.getId())).findFirst();

      if (expenseOptional.isPresent()) {
        Expense expense = expenseOptional.get();
        expense.setExpenseDate(request.getExpenseDate());
        expense.setExpenseType(request.getExpenseType());
        expense.setAmount(request.getAmount());
        expense.setAdditionalInfo(request.getAdditionalInfo());
        expense.setRecordedBy(request.getRecordedBy());
      } else {
        logger.error("Invalid expense ID: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Invalid expense ID"));
      }

    } else {

      Expense expense =
          Expense.builder()
              .id(UUID.randomUUID().toString())
              .expenseDate(request.getExpenseDate())
              .expenseType(request.getExpenseType())
              .amount(request.getAmount())
              .additionalInfo(request.getAdditionalInfo())
              .recordedBy(request.getRecordedBy())
              .createdDate(new Date())
              .build();
      if (coop.getExpenses() != null) {
        coop.getExpenses().add(expense);
      } else {
        coop.setExpenses(List.of(expense));
      }
    }

    farm.getCoops().remove(tempCoop);
    if (farm.getCoops() != null) {
      farm.getCoops().add(coop);
    } else {
      farm.setCoops(List.of(coop));
    }
    farmRepository.save(farm);
    logger.info("Expense details updated");
    return ResponseEntity.ok(buildFarm(farm));
  }

  @Override
  public ResponseEntity<Object> updateSales(UpdateSaleRequest request) {
    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Invalid Farm Id: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    Coop coop;
    Coop tempCoop;
    if (farm.getCoops() != null && !farm.getCoops().isEmpty()) {
      coop =
          farm.getCoops().stream()
              .filter(c -> c.getId().equals(request.getCoopId()))
              .findFirst()
              .orElse(null);
      tempCoop = coop;
      if (coop == null) {
        logger.error("Invalid coop ID: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Invalid coop ID"));
      }
    } else {
      logger.error("Farm does not have coops: {}", request);
      return ResponseEntity.badRequest()
          .body(new MessageResponse(false, "Farm does not have coops"));
    }
    double totalSaleAmount;
    if (coop.getCoopType() == CoopType.LAYERS) {
      totalSaleAmount = request.getNumberOfDozensSold() * request.getSalePricePerDozen();
    } else {
      totalSaleAmount = request.getNumberOfChickensSold() * request.getSalePricePerChicken();
    }

    if (request.getId() != null) {
      Sale sale =
          coop.getSales().stream()
              .filter(s -> s.getId().equals(request.getId()))
              .findFirst()
              .orElse(null);

      if (sale != null) {
        coop.getSales().remove(sale);

        sale.setNumberOfDozensSold(request.getNumberOfDozensSold());
        sale.setSalePricePerDozen(request.getSalePricePerDozen());
        sale.setNumberOfChickensSold(request.getNumberOfChickensSold());
        sale.setSalePricePerChicken(request.getSalePricePerChicken());
        sale.setBuyerName(request.getBuyerName());
        sale.setRecordedBy(request.getRecordedBy());
        sale.setPaymentStatus(request.getPaymentStatus());
        sale.setTotalSaleAmount(totalSaleAmount);
        sale.setSaleDate(request.getSaleDate());

        if (coop.getSales() == null) {
          coop.setSales(List.of(sale));
        } else {
          coop.getSales().add(sale);
        }

      } else {
        logger.error("Invalid sale ID: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Invalid sale ID"));
      }

    } else {

      Sale sale =
          Sale.builder()
              .id(UUID.randomUUID().toString())
              .numberOfDozensSold(request.getNumberOfDozensSold())
              .salePricePerDozen(request.getSalePricePerDozen())
              .numberOfChickensSold(request.getNumberOfChickensSold())
              .salePricePerChicken(request.getSalePricePerChicken())
              .buyerName(request.getBuyerName())
              .recordedBy(request.getRecordedBy())
              .paymentStatus(request.getPaymentStatus())
              .totalSaleAmount(totalSaleAmount)
              .saleDate(request.getSaleDate())
              .createdDate(new Date())
              .build();

      if (coop.getSales() != null) {
        coop.getSales().add(sale);
      } else {
        coop.setSales(List.of(sale));
      }
    }

    farm.getCoops().remove(tempCoop);
    if (farm.getCoops() != null) {
      farm.getCoops().add(coop);
    } else {
      farm.setCoops(List.of(coop));
    }
    farmRepository.save(farm);
    logger.info("Sale details updated");
    return ResponseEntity.ok(buildFarm(farm));
  }

  @Override
  public ResponseEntity<Object> updateMortalities(UpdateMortalityRequest request) {
    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Farm not found: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    Coop coop;
    Coop tempCoop;
    if (farm.getCoops() != null && !farm.getCoops().isEmpty()) {
      coop =
          farm.getCoops().stream()
              .filter(c -> c.getId().equals(request.getCoopId()))
              .findFirst()
              .orElse(null);
      tempCoop = coop;

      if (coop == null) {
        logger.error("Invalid coop ID: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Invalid coop ID"));
      }

    } else {
      logger.error("Farm does not have coops: {}", request);
      return ResponseEntity.badRequest()
          .body(new MessageResponse(false, "Farm does not have coops"));
    }

    if (request.getId() != null) {
      Mortality mortality =
          coop.getMortalities().stream()
              .filter(m -> m.getId().equals(request.getId()))
              .findFirst()
              .orElse(null);

      if (mortality != null) {
        coop.getMortalities().remove(mortality);

        mortality.setDateOccurred(request.getDateOccurred());
        mortality.setNumberOfDeaths(request.getNumberOfDeaths());
        mortality.setReason(request.getReason());
        mortality.setRecordedBy(request.getRecordedBy());

        if (coop.getMortalities() == null) {
          coop.setMortalities(List.of(mortality));
        } else {
          coop.getMortalities().add(mortality);
        }

      } else {
        logger.error("Invalid mortality ID: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Invalid mortality ID"));
      }

    } else {
      Mortality mortality =
          Mortality.builder()
              .id(UUID.randomUUID().toString())
              .dateOccurred(request.getDateOccurred())
              .numberOfDeaths(request.getNumberOfDeaths())
              .reason(request.getReason())
              .recordedBy(request.getRecordedBy())
              .createdDate(new Date())
              .build();

      if (coop.getMortalities() != null) {
        coop.getMortalities().add(mortality);
      } else {
        coop.setMortalities(List.of(mortality));
      }
    }

    farm.getCoops().remove(tempCoop);
    if (farm.getCoops() != null) {
      farm.getCoops().add(coop);
    } else {
      farm.setCoops(List.of(coop));
    }
    farmRepository.save(farm);
    logger.info("Mortality details updated");
    return ResponseEntity.ok(buildFarm(farm));
  }

  @Override
  public ResponseEntity<Object> updateResponsibleUser(AddResponsibleUserRequest request) {
    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    if (farmOptional.isEmpty()) {
      logger.error("Farm not found: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    Farm farm = farmOptional.get();
    List<Coop> coops = farm.getCoops();
    List<String> coopIds = request.getCoopIds();

    if (coops == null || coopIds == null) {
      logger.error("No coops or coopIds provided for farm: {}", request);
      return ResponseEntity.badRequest()
          .body(new MessageResponse(false, "No coops or coopIds provided"));
    }

    String userId = request.getUserId();
    for (Coop coop : coops) {
      updateResponsibleUserForCoop(coop, coopIds, userId);
    }

    farmRepository.save(farm);
    logger.info("Coop responsible user updated successfully");
    return ResponseEntity.ok(buildFarm(farm));
  }

  private void updateResponsibleUserForCoop(Coop coop, List<String> coopIds, String userId) {
    List<String> responsibleUserIds = coop.getResponsibleUserIds();
    if (coopIds.contains(coop.getId())) {
      if (responsibleUserIds == null) {
        responsibleUserIds = new ArrayList<>();
        coop.setResponsibleUserIds(responsibleUserIds);
      }
      if (!responsibleUserIds.contains(userId)) {
        responsibleUserIds.add(userId);
      }
    } else if (responsibleUserIds != null) {
      responsibleUserIds.remove(userId);
    }
  }

  @Override
  public ResponseEntity<Object> updateFarmCoop(UpdateFarmCoopRequest request) {

    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Farm not found: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    if (farm.getCoops() != null && !farm.getCoops().isEmpty()) {
      Coop coop =
          farm.getCoops().stream()
              .filter(
                  c ->
                      c.getCoopName().equalsIgnoreCase(request.getCoopName())
                          && c.getCoopType().equals(request.getCoopType())
                          && c.getGrowthPhase().equals(request.getGrowthPhase())
                          && !c.getId().equals(request.getCoopId()))
              .findFirst()
              .orElse(null);

      if (coop != null) {
        logger.error("Coop already exists: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Coop already exists"));
      }
    }

    if (request.getCoopId() != null) {

      Coop coop = null;
      if (farm.getCoops() != null && !farm.getCoops().isEmpty()) {
        coop =
            farm.getCoops().stream()
                .filter(c -> c.getId().equals(request.getCoopId()))
                .findFirst()
                .orElse(null);
      }

      if (coop != null) {
        farm.getCoops().remove(coop);

        coop.setCoopName(request.getCoopName());
        coop.setCoopType(request.getCoopType());
        coop.setNumberOfChickens(request.getNumberOfChickens());
        coop.setChickenArrivalDate(request.getChickenArrivalDate());
        coop.setGrowthPhase(request.getGrowthPhase());
        if (coop.getChickenArrivalDate() != null
            && coop.getNumberOfChickens() > 0
            && (coop.getReminder() == null)) {
          coop.setReminder(
              buildReminders(
                  request.getChickenArrivalDate(),
                  request.getCoopType(),
                  request.getGrowthPhase()));
        }

        farm.getCoops().add(coop);

        farmRepository.save(farm);

      } else {
        logger.error("Coop not found: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Coop not found"));
      }

      logger.info("Farm details updated");
      return ResponseEntity.ok(buildFarm(farm));

    } else {
      Coop coop =
          Coop.builder()
              .id(UUID.randomUUID().toString())
              .coopName(request.getCoopName())
              .coopType(request.getCoopType())
              .growthPhase(request.getGrowthPhase())
              .numberOfChickens(request.getNumberOfChickens())
              .chickenArrivalDate(request.getChickenArrivalDate())
              .createdDate(new Date())
              .reminder(
                  buildReminders(
                      request.getChickenArrivalDate(),
                      request.getCoopType(),
                      request.getGrowthPhase()))
              .build();

      if (farm.getCoops() != null) {
        farm.getCoops().add(coop);
      } else {
        farm.setCoops(List.of(coop));
      }
      farmRepository.save(farm);
    }
    logger.info("Farm details updated");
    return ResponseEntity.ok(buildFarm(farm));
  }

  @Override
  public ResponseEntity<Object> recordEggPackaging(EggPackagingRecordRequest request) {

    Farm farm =
        farmRepository
            .findById(request.getFarmId())
            .orElseThrow(() -> new NotFoundException("Farm not found"));

    Coop coop =
        farm.getCoops().stream()
            .filter(c -> c.getId().equals(request.getCoopId()))
            .findFirst()
            .orElseThrow(() -> new NotFoundException("Coop not found"));

    if (coop.getCoopType() != CoopType.LAYERS) {
      throw new NotFoundException("Packaging only allowed for layer coops");
    }

    EggPackagingRecord eggPackagingRecord =
        EggPackagingRecord.builder()
            .id(UUID.randomUUID().toString())
            .eggSize(request.getEggSize())
            .boxSize(request.getBoxSize())
            .numberOfBoxes(request.getNumberOfBoxes())
            .totalEggs(getBoxSize(request.getBoxSize()) * request.getNumberOfBoxes())
            .userId(request.getUserId())
            .createdDate(request.getCreatedDate() !=null ? request.getCreatedDate() : new Date())
            .additionalInfo(request.getAdditionalInfo())
            .build();

    if (coop.getEggPackagingRecords() == null) {
      coop.setEggPackagingRecords(new ArrayList<>());
    }

    coop.getEggPackagingRecords().add(eggPackagingRecord);

    farm.getCoops().remove(coop);
    farm.getCoops().add(coop);

    farmRepository.save(farm);
    logger.info("Egg packaging record added successfully. Request: {}", request);
    return ResponseEntity.ok(buildFarm(farm));
  }

  private int getBoxSize(String boxSize) {
    if (boxSize == null || boxSize.isBlank()) {
      return 0;
    }
    String normalized = boxSize.trim().toLowerCase();
    return switch (normalized) {
      case "6 eggs box" -> 6;
      case "12 eggs box" -> 12;
      case "18 eggs box" -> 18;
      case "30 eggs box" -> 30;
      default ->
          throw new IllegalArgumentException("Unable to determine eggs box size: " + boxSize);
    };
  }

  @Override
  public ResponseEntity<Object> addNewBatch(UpdateFarmCoopRequest request) {

    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Farm not found: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    if (farm.getCoops() != null && !farm.getCoops().isEmpty()) {
      Coop coop =
          farm.getCoops().stream()
              .filter(c -> c.getId().equals(request.getCoopId()))
              .findFirst()
              .orElse(null);

      if (coop != null) {
        farm.getCoops().remove(coop);

        CoopArchive coopArchive =
            CoopArchive.builder()
                .coop(coop)
                .farmId(request.getFarmId())
                .createdDate(new Date())
                .build();

        coopArchiveRepository.save(coopArchive);

        Coop newCoop = new Coop();

        newCoop.setCreatedDate(coop.getCreatedDate());
        newCoop.setId(coop.getId());
        newCoop.setCoopName(request.getCoopName());
        newCoop.setCoopType(request.getCoopType());
        newCoop.setGrowthPhase(request.getGrowthPhase());
        newCoop.setNumberOfChickens(request.getNumberOfChickens());
        newCoop.setChickenArrivalDate(request.getChickenArrivalDate());
        newCoop.setReminder(
            buildReminders(
                request.getChickenArrivalDate(), request.getCoopType(), request.getGrowthPhase()));
        farm.getCoops().add(newCoop);

        farmRepository.save(farm);
      } else {
        logger.error("Coop not found: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Coop not found"));
      }
    }

    logger.info("New batch added successfully");
    return ResponseEntity.ok(buildFarm(farm));
  }

  @Override
  public ResponseEntity<Object> addFarmUser(AddFarmUserRequest request) {

    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Farm not found: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    if (Boolean.TRUE.equals(userRepository.existsByEmailAndRemoved(request.getEmail(), false))) {
      return ResponseEntity.badRequest()
          .body(new MessageResponse(false, "Error: Email is already in use!"));
    }

    Set<Role> roles = new HashSet<>();
    Optional<Role> userRole = roleRepository.findByName(ERole.ROLE_USER);
    userRole.ifPresent(roles::add);

    request.getRoles().forEach(eRole -> roleRepository.findByName(eRole).ifPresent(roles::add));

    User user =
        User.builder()
            .name(request.getName())
            .surname(request.getSurname())
            .phoneNumber(request.getPhoneNumber())
            .farmId(farm.getId())
            .active(true)
            .email(request.getEmail())
            .password(encoder.encode(request.getPhoneNumber()))
            .createdDate(new Date())
            .roles(roles)
            .addedByUserId(request.getAddedByUserId())
            .farmOwner(false)
            .build();

    userRepository.save(user);
    asyncService.registrationNotification(user, request.getPhoneNumber());
    logger.info("Farm user added successfully");
    return ResponseEntity.ok(buildFarm(farm));
  }

  @Override
  public ResponseEntity<Object> updateUserRoles(UserRolesRequest request) {

    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Farm not found: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    Optional<User> updatorUserOptional = userRepository.findById(request.getUpdatedByUserId());
    if (updatorUserOptional.isPresent() && updatorUserOptional.get().isFarmOwner()) {
      Optional<User> userOptional = userRepository.findById(request.getUserId());

      if (userOptional.isPresent()) {
        Set<Role> roles = new HashSet<>();
        Optional<Role> userRole = roleRepository.findByName(ERole.ROLE_USER);
        userRole.ifPresent(roles::add);
        request.getRoles().forEach(eRole -> roleRepository.findByName(eRole).ifPresent(roles::add));

        User user = userOptional.get();
        if (!user.isFarmOwner()) {
          user.setRoles(roles);
          user.setRolesUpdatedByUserId(request.getUpdatedByUserId());
          userRepository.save(user);
          logger.info("User roles updated successfully");
          return ResponseEntity.ok(buildFarm(farm));
        } else {
          logger.error("Farm owner roles can not be updated: {}", request);
          return ResponseEntity.badRequest()
              .body(
                  new MessageResponse(
                      false, "Farm owner roles can not be updated, please contact administrator"));
        }

      } else {
        logger.error("User not found: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "User not found"));
      }
    } else {
      logger.error("User not authorized to update roles: {}", request);
      return ResponseEntity.badRequest()
          .body(
              new MessageResponse(
                  false, "User not authorized to update roles, please contact administrator"));
    }
  }

  @Override
  public ResponseEntity<Object> removeUser(RemoveUserRequest request) {

    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Farm not found: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    Optional<User> updatorUserOptional = userRepository.findById(request.getDeletedByUserId());
    if (updatorUserOptional.isPresent() && updatorUserOptional.get().isFarmOwner()) {
      Optional<User> userOptional = userRepository.findById(request.getUserId());

      if (userOptional.isPresent()) {

        User user = userOptional.get();
        if (!user.isFarmOwner()) {
          user.setRemoved(true);
          user.setRemovedByUserId(request.getDeletedByUserId());
          userRepository.save(user);
          logger.info("User removed successfully");
          return ResponseEntity.ok(buildFarm(farm));
        } else {
          logger.error("Farm owner cannot be removed from the farm: {}", request);
          return ResponseEntity.badRequest()
              .body(
                  new MessageResponse(
                      false,
                      "Farm owner cannot be removed from the farm, please contact administrator"));
        }

      } else {
        logger.error("User not found: {}", request);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "User not found"));
      }
    } else {
      logger.error("User not authorized to remove user: {}", request);
      return ResponseEntity.badRequest()
          .body(
              new MessageResponse(
                  false, "User not authorized to remove user, please contact administrator"));
    }
  }

  @Override
  public ResponseEntity<Object> deleteCoopItem(RemoveCoopIteamRequest request) {

    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Farm not found, Farm Id: {}", request.getFarmId());
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    if (farm.getCoops() != null && !farm.getCoops().isEmpty()) {
      Coop coop =
          farm.getCoops().stream()
              .filter(c -> c.getId().equals(request.getCoopId()))
              .findFirst()
              .orElse(null);

      if (coop != null) {

        if (request.getItemType().equalsIgnoreCase("Sale")) {
          Sale sale =
              coop.getSales().stream()
                  .filter(s -> s.getId().equals(request.getItemId()))
                  .findAny()
                  .orElse(null);
          coop.getSales().remove(sale);
          logger.info("Removing sale from the coop, ID: {}", request.getItemId());
        } else if (request.getItemType().equalsIgnoreCase("Mortality")) {
          Mortality mortality =
              coop.getMortalities().stream()
                  .filter(m -> m.getId().equals(request.getItemId()))
                  .findAny()
                  .orElse(null);
          coop.getMortalities().remove(mortality);
          logger.info("Removing mortality from the coop, ID: {}", request.getItemId());
        } else if (request.getItemType().equalsIgnoreCase("Expense")) {
          Expense expense =
              coop.getExpenses().stream()
                  .filter(e -> e.getId().equals(request.getItemId()))
                  .findAny()
                  .orElse(null);
          coop.getExpenses().remove(expense);
          logger.info("Removing expense from the coop, ID: {}", request.getItemId());
        } else if (request.getItemType().equalsIgnoreCase("Egg Packaging Record")) {
          EggPackagingRecord eggRecord =
              coop.getEggPackagingRecords().stream()
                  .filter(e -> e.getId().equals(request.getItemId()))
                  .findAny()
                  .orElse(null);
          coop.getEggPackagingRecords().remove(eggRecord);
          logger.info("Removing Egg Packaging Record from the coop, ID: {}", request.getItemId());
        } else {
          logger.info(
              "Unknown coop item, ID: {}, Item: {}", request.getItemId(), request.getItemType());
        }

        farm.getCoops().remove(coop);
        farm.getCoops().add(coop);

        farmRepository.save(farm);
      } else {
        logger.error("Coop not found, Coop ID: {}", request.getCoopId());
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Coop not found"));
      }
    }

    logger.info("Farm item deleted successfully");
    return ResponseEntity.ok(buildFarm(farm));
  }

  @Override
  public ResponseEntity<Object> updateReminder(UpdateReminderRequest request) {
    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Farm not found, Farm Id: {}", request.getFarmId());
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    if (farm.getCoops() != null && !farm.getCoops().isEmpty()) {
      Coop coop =
          farm.getCoops().stream()
              .filter(c -> c.getId().equals(request.getCoopId()))
              .findFirst()
              .orElse(null);

      if (coop != null) {

        if (request.getReminderType().equalsIgnoreCase("feed")) {
          Feed feed =
              coop.getReminder().getFeeds().stream()
                  .filter(f -> f.getId().equals(request.getId()))
                  .findAny()
                  .orElse(null);
          Objects.requireNonNull(feed).setAction(request.getAction());
          feed.setActionComment(request.getActionComment());
          feed.setDone(true);
          feed.setUpdatedByUserId(request.getUpdatedByUserId());

          coop.getReminder().getFeeds().remove(feed);
          coop.getReminder().getFeeds().add(feed);

        } else if (request.getReminderType().equalsIgnoreCase("Vaccine")) {
          Vaccine vaccine =
              coop.getReminder().getVaccines().stream()
                  .filter(v -> v.getId().equals(request.getId()))
                  .findAny()
                  .orElse(null);
          Objects.requireNonNull(vaccine).setAction(request.getAction());
          vaccine.setActionComment(request.getActionComment());
          vaccine.setDone(true);
          vaccine.setUpdatedByUserId(request.getUpdatedByUserId());

          coop.getReminder().getVaccines().remove(vaccine);
          coop.getReminder().getVaccines().add(vaccine);

        } else if (request.getReminderType().equalsIgnoreCase("Medicine")) {
          Medicine medicine =
              coop.getReminder().getMedicines().stream()
                  .filter(m -> m.getId().equals(request.getId()))
                  .findAny()
                  .orElse(null);

          Objects.requireNonNull(medicine).setAction(request.getAction());
          medicine.setActionComment(request.getActionComment());
          medicine.setDone(true);
          medicine.setUpdatedByUserId(request.getUpdatedByUserId());

          coop.getReminder().getMedicines().remove(medicine);
          coop.getReminder().getMedicines().add(medicine);

        } else {
          logger.error("Invalid reminder type: {}", request);
        }

        farm.getCoops().remove(coop);
        farm.getCoops().add(coop);

        farmRepository.save(farm);
      } else {
        logger.error("Coop not found, Coop ID: {}", request.getCoopId());
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Coop not found"));
      }
    }

    logger.info("Reminder updated successfully");
    return ResponseEntity.ok(buildFarm(farm));
  }

  @Override
  public ResponseEntity<Object> deleteFarmCoop(String farmId, String coopId) {

    Optional<Farm> farmOptional = farmRepository.findById(farmId);
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Farm not found, Farm Id: {}", farmId);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    if (farm.getCoops() != null && !farm.getCoops().isEmpty()) {
      Coop coop =
          farm.getCoops().stream().filter(c -> c.getId().equals(coopId)).findFirst().orElse(null);

      if (coop != null) {
        farm.getCoops().remove(coop);
        farmRepository.save(farm);
      } else {
        logger.error("Coop not found, Coop ID: {}", coopId);
        return ResponseEntity.badRequest().body(new MessageResponse(false, "Coop not found"));
      }
    }

    logger.info("Farm coop deleted successfully");
    return ResponseEntity.ok(buildFarm(farm));
  }

  @Override
  public ResponseEntity<byte[]> downloadReport(String farmId, String userId) {
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=report.pdf")
        .contentType(MediaType.APPLICATION_PDF)
        .body(generatePdf(farmId));
  }

  @Override
  public ResponseEntity<byte[]> downloadScheduleReport(
      String farmId, String coopId, String userId) {
    Optional<User> userOptional = userRepository.findById(userId);

    if (userOptional.isEmpty()) {
      logger.error("User not found with id: {}", userId);
      return null;
    }

    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=schedule-report.pdf")
        .contentType(MediaType.APPLICATION_PDF)
        .body(generateSchedulePdf(farmId, coopId, userOptional.get()));
  }

  @Override
  public ResponseEntity<Object> sendScheduleViaEmail(SendScheduleRequest request) {

    Optional<User> userOptional = userRepository.findById(request.getUserId());
    if (userOptional.isEmpty()) {
      logger.error("User not found with id: {}", request.getUserId());
      return ResponseEntity.badRequest().body(new MessageResponse(false, "User not found"));
    }

    User user = userOptional.get();

    byte[] pdf = generateSchedulePdf(request.getFarmId(), request.getCoopId(), user);

    String content =
        "<p>Dear #NAME#,</p>"
            + "<p>Attached is your chicken health and treatment tracking document.</p>"
            + "<p>This document serves as a guide and record sheet for your flock. "
            + "It includes important dates for vaccinations and medicines, "
            + "space to track mortality, and notes for actions taken. "
            + "It follows the recommended schedule based on your birds' age and growing phase, "
            + "ensuring you're keeping up with key health events like Marek's, Newcastle, Gumboro, and more.</p>"
            + "<p>You can use this document to:</p>"
            + "<ul>"
            + "  <li>Know exactly when to administer each vaccine or medicine</li>"
            + "  <li>Record the number of chickens treated or lost</li>"
            + "  <li>Track doses and ensure compliance with withdrawal periods</li>"
            + "</ul>"
            + "<p>We hope this helps you better manage your farm "
            + "and improve bird health and productivity.</p>";

    content = content.replace("#NAME#", user.getName() + " " + user.getSurname());

    // Build Email object
    Email email = new Email();
    email.setFrom(ConstantUtil.NO_REPLY_EMAIL);
    email.setTo(new String[] {user.getEmail()});
    email.setSubject("🐔 Chicken Health Schedule");
    email.setContent(content);
    Attachment attachment = new Attachment();
    attachment.setFileName("farm-chicken-health-schedule");
    attachment.setContentType(".pdf");
    attachment.setData(pdf);

    email.setAttachments(List.of(attachment));

    // Save email for processing
    emailSender.saveEmail(email);

    return ResponseEntity.ok(
        new MessageResponse(
            true, "Your chicken health schedule has been sent, please check your mail inbox"));
  }

  @Override
  public ResponseEntity<Object> sendReportViaEmail(String farmId, String userId) {

    Optional<User> userOptional = userRepository.findById(userId);
    if (userOptional.isEmpty()) {
      logger.error("User not found with id: {}", userId);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "User not found"));
    }

    User user = userOptional.get();

    byte[] pdf = generatePdf(farmId);

    String content =
        "<p>Dear #NAME#,</p>"
            + "<p>Attached is your requested farm report. "
            + "This report provides an overview of your farm's current status, including sales, expenses, mortalities, and chicken stock.</p>"
            + "<p>Please review the details and let us know if you have any questions or need further assistance.</p>"
            + "<p>Thank you for your continued commitment to your farm and for using our platform to manage your operations.</p>"
            + "<p>Best regards,<br/>The PoultryPal Team</p>";
    content = content.replace("#NAME#", user.getName() + " " + user.getSurname());

    // Build Email object
    Email email = new Email();
    email.setFrom(ConstantUtil.NO_REPLY_EMAIL);
    email.setTo(new String[] {user.getEmail()});
    email.setSubject("🐔 Farm Report");
    email.setContent(content);
    Attachment attachment = new Attachment();
    attachment.setFileName("farm-report");
    attachment.setContentType(".pdf");
    attachment.setData(pdf);

    email.setAttachments(List.of(attachment));

    // Save email for processing
    emailSender.saveEmail(email);

    return ResponseEntity.ok(
        new MessageResponse(true, "Your report has been sent, please check your mail inbox"));
  }

  @Override
  public ResponseEntity<Object> updateUserSetting(UserSettingsRequest request) {

    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    if (farmOptional.isEmpty()) {
      logger.error("Farm not found, Farm Id: {}", request.getFarmId());
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    Optional<User> optionalUser = getUserOptional(request.getUserId());
    if (optionalUser.isEmpty()) {
      logger.error("User not found with id: {}", request.getUserId());
      return ResponseEntity.badRequest().body(new MessageResponse(false, "User not found"));
    }

    UserSettings userSettings = null;

    if (request.getId() != null) {
      Optional<UserSettings> settingsOptional = userSettingsRepository.findById(request.getId());
      if (settingsOptional.isPresent()) {
        userSettings = settingsOptional.get();
      } else {
        logger.error("User settings not found with id: {}", request.getId());
        return ResponseEntity.badRequest()
            .body(new MessageResponse(false, "User settings not found"));
      }
    } else {
      userSettings = new UserSettings();
    }

    userSettings.setId(request.getId());
    userSettings.setUserId(request.getUserId());
    userSettings.setFarmId(request.getFarmId());
    userSettings.setCurrency(request.getCurrency());
    userSettings.setAutoCreateReminders(request.getAutoCreateReminders());
    userSettings.setSalesAlerts(request.getSalesAlerts());
    userSettings.setMortalityAlerts(request.getMortalityAlerts());
    userSettings.setExpenseAlerts(request.getExpenseAlerts());
    userSettings.setDailyReminders(request.getDailyReminders());

    userSettingsRepository.save(userSettings);
    return ResponseEntity.ok(buildUserSettingResponse(userSettings));
  }

  @Override
  public ResponseEntity<Object> findUserSetting(String userId, String farmId) {

    Optional<Farm> farmOptional = farmRepository.findById(farmId);
    if (farmOptional.isEmpty()) {
      logger.error("Farm not found, Farm Id: {}", farmId);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    Optional<User> optionalUser = getUserOptional(userId);
    if (optionalUser.isEmpty()) {
      logger.error("User not found with id: {}", userId);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "User not found"));
    }

    UserSettingsResponse settingsResponse;
    Optional<UserSettings> settingsOptional =
        userSettingsRepository.findByUserIdAndFarmId(userId, farmId);
    if (settingsOptional.isPresent()) {
      settingsResponse = buildUserSettingResponse(settingsOptional.get());
    } else {
      settingsResponse = new UserSettingsResponse();
      settingsResponse.setUserId(userId);
      settingsResponse.setFarmId(farmId);
      settingsResponse.setCurrency("");
      settingsResponse.setAutoCreateReminders(false);
      settingsResponse.setSalesAlerts(false);
      settingsResponse.setMortalityAlerts(false);
      settingsResponse.setExpenseAlerts(false);
      settingsResponse.setDailyReminders(false);
    }

    return ResponseEntity.ok(settingsResponse);
  }

  private UserSettingsResponse buildUserSettingResponse(UserSettings request) {
    UserSettingsResponse settingsResponse = new UserSettingsResponse();
    settingsResponse.setId(request.getId());
    settingsResponse.setUserId(request.getUserId());
    settingsResponse.setFarmId(request.getFarmId());
    settingsResponse.setCurrency(request.getCurrency());
    settingsResponse.setAutoCreateReminders(request.getAutoCreateReminders());
    settingsResponse.setSalesAlerts(request.getSalesAlerts());
    settingsResponse.setMortalityAlerts(request.getMortalityAlerts());
    settingsResponse.setExpenseAlerts(request.getExpenseAlerts());
    settingsResponse.setDailyReminders(request.getDailyReminders());
    return settingsResponse;
  }

  private byte[] generatePdf(String farmId) {

    Optional<Farm> farmOptional = farmRepository.findById(farmId);

    if (farmOptional.isPresent()) {

      FarmResponse farmResponse = buildFarm(farmOptional.get());
      UserInfoResponse farmOwner =
          farmResponse.getUsers().stream()
              .filter(UserInfoResponse::isFarmOwner)
              .findAny()
              .orElse(null);
      assert farmOwner != null;

      // Render the HTML content using Thymeleaf
      Context context = new Context();
      String uniqueRefNumber = generateReference();
      context.setVariable("logoBase64", getLogoAsBase64());
      context.setVariable("farmName", farmResponse.getFarmName());
      context.setVariable("ownerName", farmOwner.getName());
      context.setVariable("ownerSurname", farmOwner.getSurname());
      context.setVariable("ownerEmail", farmOwner.getEmail());
      context.setVariable("ownerPhone", farmOwner.getPhoneNumber());
      context.setVariable("uniqueRefNumber", uniqueRefNumber);
      context.setVariable("barcodeBase64", generateBarcode(uniqueRefNumber));

      context.setVariable("totalChickens", farmResponse.getFarmReport().getTotalChickens());
      context.setVariable("totalSales", "R" + farmResponse.getFarmReport().getTotalSales());
      context.setVariable("totalExpenses", "R" + farmResponse.getFarmReport().getTotalExpenses());
      context.setVariable("totalMortalities", farmResponse.getFarmReport().getTotalMortalities());

      List<Map<String, Object>> coops = new ArrayList<>();

      farmResponse
          .getFarmReport()
          .getCoopReports()
          .forEach(
              coop -> {
                Map<String, Object> coopDetails = new HashMap<>();
                coopDetails.put("name", coop.getCoopName());
                coopDetails.put("type", coop.getCoopType());
                coopDetails.put("totalChickens", coop.getTotalChickens());
                coopDetails.put("age", coop.getChickenAge());
                coopDetails.put("mortality", coop.getTotalMortality());
                coopDetails.put("availableChickens", coop.getAvailableChickens());
                coopDetails.put("sales", "R" + coop.getSales());
                coopDetails.put("profit", "R" + coop.getProfit());
                coopDetails.put("expenses", "R" + coop.getExpenses());
                coops.add(coopDetails);
              });

      context.setVariable("coops", coops);

      String htmlContent = templateEngine.process("report", context);

      try (ByteArrayOutputStream outputStream = new ByteArrayOutputStream()) {
        PdfRendererBuilder builder = new PdfRendererBuilder();
        builder.useFastMode();
        builder.withHtmlContent(htmlContent, null);
        builder.toStream(outputStream);
        builder.run();

        return outputStream.toByteArray();
      } catch (Exception e) {
        throw new RuntimeException("Failed to generate PDF", e);
      }
    } else {
      logger.error("Farm not found. FarmId: {}", farmId);
      throw new RuntimeException("Farm not found for ID provided");
    }
  }

  public byte[] generateSchedulePdf(String farmId, String coopId, User user) {

    Optional<Farm> farmOptional = farmRepository.findById(farmId);

    if (farmOptional.isPresent()) {

      Context context = new Context();
      String uniqueRefNumber = generateReference();
      context.setVariable("logoBase64", getLogoAsBase64());
      context.setVariable("farmName", farmOptional.get().getFarmName());
      context.setVariable("uniqueRefNumber", uniqueRefNumber);

      context.setVariable("barcodeBase64", generateBarcode(uniqueRefNumber));

      List<Map<String, Object>> tableRows = new ArrayList<>();
      List<Medicine> allMedicines = new ArrayList<>();

      Coop coop =
          farmOptional.get().getCoops().stream()
              .filter(c -> c.getId().equals(coopId))
              .findFirst()
              .orElse(null);

      // Collect medicines for all phases
      for (GrowingPhase phase : GrowingPhase.values()) {
        assert coop != null;
        List<Medicine> medicines =
            (coop.getCoopType() == CoopType.LAYERS)
                ? medicineScheduleService.generateLayerMedicineSchedule(
                    coop.getChickenArrivalDate(), phase)
                : medicineScheduleService.generateBroilerMedicineSchedule(
                    coop.getChickenArrivalDate(), phase);
        allMedicines.addAll(medicines);
      }

      // Find the total number of days to display
      int totalDays = allMedicines.stream().mapToInt(Medicine::getAgeEndInDays).max().orElse(0);

      for (int day = 1; day <= totalDays; day++) {
        Date date = PoultryPalUtil.addDays(coop.getChickenArrivalDate(), day);
        final int currentDay = day;

        String medication =
            allMedicines.stream()
                .filter(
                    m -> m.getAgeStartInDays() <= currentDay && m.getAgeEndInDays() >= currentDay)
                .map(m -> m.getMedicineName() + " " + (m.isMandatory() ? "*" : ""))
                .distinct()
                .collect(Collectors.joining(", "));

        String feed = getFeedTypeForDay(day, coop.getCoopType()); // Implement as needed

        Map<String, Object> row = new HashMap<>();
        row.put("day", day);
        row.put("date", new SimpleDateFormat("dd/MM/yyyy").format(date));
        row.put("mortality", "");
        row.put("feed", feed);
        row.put("medication", medication);
        tableRows.add(row);
      }

      assert coop != null;

      context.setVariable(
          "scheduleName",
          +coop.getNumberOfChickens()
              + " chickens - "
              + new SimpleDateFormat("MMMM yyyy").format(coop.getChickenArrivalDate())
              + " Schedule");

      context.setVariable("trackingRows", tableRows);

      String htmlContent = templateEngine.process("tracking_report", context);

      try (ByteArrayOutputStream outputStream = new ByteArrayOutputStream()) {
        PdfRendererBuilder builder = new PdfRendererBuilder();
        builder.useFastMode();
        builder.withHtmlContent(htmlContent, null);
        builder.toStream(outputStream);
        builder.run();
        return outputStream.toByteArray();
      } catch (Exception e) {
        throw new RuntimeException("Failed to generate tracking PDF", e);
      }
    } else {
      logger.error("farm not found for FarmId: {}", farmId);
      throw new RuntimeException("Farm not found for ID provided");
    }
  }

  private String getFeedTypeForDay(int day, CoopType coopType) {
    List<Feed> feeds;
    Date dummyDate = new Date(); // The actual date is not used for feed schedule day ranges

    if (coopType == CoopType.LAYERS) {
      feeds = new ArrayList<>();
      for (GrowingPhase phase : GrowingPhase.values()) {
        feeds.addAll(feedScheduleService.generateLayerFeedSchedule(dummyDate, phase));
      }
    } else if (coopType == CoopType.BROILER) {
      feeds = new ArrayList<>();
      for (GrowingPhase phase : GrowingPhase.values()) {
        feeds.addAll(feedScheduleService.generateBroilerFeedSchedule(dummyDate, phase));
      }
    } else {
      return "";
    }

    for (Feed feed : feeds) {
      if (day >= feed.getAgeStartInDays() && day <= feed.getAgeEndInDays()) {
        return feed.getFeedType();
      }
    }
    return "";
  }

  public static String generateReference() {

    String prefix = "PP";
    DateTimeFormatter yearFormatter = DateTimeFormatter.ofPattern("yyyy");
    int seqBased = 100000;

    String year = LocalDate.now().format(yearFormatter);

    LocalTime now = LocalTime.now();
    int sequenceNumber = now.toSecondOfDay() % seqBased;

    String formattedSequence = String.format("%05d", sequenceNumber);

    return prefix + "-" + year + "-" + formattedSequence;
  }

  public String getLogoAsBase64() {
    try (InputStream is = getClass().getClassLoader().getResourceAsStream("templates/logo.png")) {
      if (is == null) {
        throw new FileNotFoundException("logo.png not found in resources");
      }
      byte[] imageBytes = is.readAllBytes();
      return "data:image/png;base64," + Base64.getEncoder().encodeToString(imageBytes);
    } catch (Exception e) {
      throw new RuntimeException("Failed to encode logo as Base64", e);
    }
  }

  public String generateBarcode(String text) {
    try {
      Code128Writer barcodeWriter = new Code128Writer();
      BitMatrix bitMatrix =
          barcodeWriter.encode(text, BarcodeFormat.CODE_128, 260, 25); // Width and height

      try (ByteArrayOutputStream outputStream = new ByteArrayOutputStream()) {
        MatrixToImageWriter.writeToStream(bitMatrix, "PNG", outputStream);
        return "data:image/png;base64,"
            + Base64.getEncoder().encodeToString(outputStream.toByteArray());
      } catch (Exception e) {
        throw new RuntimeException("Error generating barcode image", e);
      }
    } catch (WriterException e) {
      throw new RuntimeException("Failed to generate barcode", e);
    }
  }

  private List<UserInfoResponse> getUserInfoResponseList(
      List<User> userList, Farm farm, String logMessage) {
    if (userList != null && !userList.isEmpty()) {
      List<UserInfoResponse> userInfoResponses = new ArrayList<>();

      for (User user : userList) {
        if (!user.isRemoved()) {

          if (farm == null) {
            Optional<Farm> farmOptional = farmRepository.findById(user.getFarmId());
            if (farmOptional.isPresent()) {
              farm = farmOptional.get();
            } else {
              logger.error("Farm not found for user: {}", user);
              continue;
            }
          }
          List<String> userCoopIds =
              Optional.of(farm)
                  .map(Farm::getCoops)
                  .map(
                      coops ->
                          coops.stream()
                              .filter(
                                  coop ->
                                      Optional.ofNullable(coop.getResponsibleUserIds())
                                          .map(ids -> ids.contains(user.getId()))
                                          .orElse(false))
                              .map(Coop::getId)
                              .toList())
                  .orElseGet(ArrayList::new);

          UserInfoResponse userInfoResponse =
              UserInfoResponse.builder()
                  .id(user.getId())
                  .name(user.getName())
                  .surname(user.getSurname())
                  .email(user.getEmail())
                  .phoneNumber(user.getPhoneNumber())
                  .farmId(user.getFarmId())
                  .isFarmOwner(user.isFarmOwner())
                  .isActive(user.isActive())
                  .createdDate(user.getCreatedDate())
                  .roles(user.getRoles().stream().map(Role::getName).map(Enum::name).toList())
                  .userCoopIds(userCoopIds)
                  .roleFriendlyNames(
                      user.getRoles().stream().map(Role::getName).map(ERole::getValue).toList())
                  .build();
          userInfoResponses.add(userInfoResponse);
        }
      }
      logger.info(MessageFormat.format("{0}. Size: '{}'", logMessage), userInfoResponses.size());
      return userInfoResponses;
    } else {
      return new ArrayList<>();
    }
  }

  public List<Coop> builCoopList(List<Coop> coops) {
    if (coops != null && !coops.isEmpty()) {

      UserDetailsImpl currentUser = SecurityUtils.getCurrentUser();
      String userId = Optional.ofNullable(currentUser).map(UserDetailsImpl::getId).orElse(null);
      boolean isOwner =
          Optional.ofNullable(currentUser).map(UserDetailsImpl::isFarmOwner).orElse(false);

      List<Coop> userCoops = coops;
      if (!isOwner && userId != null && !userId.isEmpty()) {
        userCoops =
            coops.stream()
                .filter(
                    coop ->
                        coop.getResponsibleUserIds() != null
                            && coop.getResponsibleUserIds().contains(userId))
                .toList();
      }

      List<Coop> mutableCoops = new ArrayList<>(userCoops);

      for (Coop coop : mutableCoops) {
        coop.setChickenAge(getChickenAge(coop.getChickenArrivalDate()));
        coop.setActive(isCoopActive(coop));
        Map<String, List<Map<String, Object>>> result =
            reminderProcessor.processReminders(coop.getReminder());
        if (coop.getReminder() != null) {
          coop.getReminder().setUpcomingReminders(result.get("upcomingReminders"));
          coop.getReminder().setOverdueTasks(result.get("overdueTasks"));
        }

        GrowingPhase chickenPhase =
            coop.getChickenArrivalDate() == null
                ? coop.getGrowthPhase()
                : PoultryPalUtil.getChickenPhase(coop.getChickenArrivalDate(), coop.getCoopType());

        if (chickenPhase != coop.getGrowthPhase()) {
          PhaseTransition transition = new PhaseTransition();
          transition.setCurrentPhase(coop.getGrowthPhase());
          transition.setNewPhase(chickenPhase);
          List<Coop> transCoopList =
              userCoops.stream()
                  .filter(
                      c ->
                          !c.getId().equals(coop.getId())
                              && c.getCoopType().equals(coop.getCoopType())
                              && c.getGrowthPhase().equals(chickenPhase))
                  .toList();
          if (!transCoopList.isEmpty()) {
            List<TransitionCoop> transitions = new ArrayList<>();

            transCoopList.forEach(
                c ->
                    transitions.add(
                        new TransitionCoop(
                            c.getId(), c.getCoopName() + " (" + c.getCoopType().getValue() + ")")));
            transition.setTransitionCoops(transitions);
          }

          coop.setPhaseTransition(transition);
        }
      }

      mutableCoops.sort(Comparator.comparing(Coop::getCoopName));

      return mutableCoops;
    } else {
      return new ArrayList<>();
    }
  }

  private boolean isCoopActive(Coop coop) {
    if (coop.getChickenArrivalDate() != null && coop.getNumberOfChickens() > 0) {
      Date now = new Date();
      return !now.before(coop.getChickenArrivalDate());
    }
    return false;
  }

  private String getChickenAge(Date createdDate) {
    String age = "Unknown";
    if (createdDate != null) {
      long diffInMillies = Math.abs(new Date().getTime() - createdDate.getTime());
      long days = diffInMillies / (24 * 60 * 60 * 1000);
      long weeks = days / 7;
      long remainingDays = days % 7;

      if (weeks == 0) {
        if (days == 1) {
          age = "1 day";
        } else if (days > 1) {
          age = days + " days";
        } else {
          age = "Less than a day";
        }
      } else {
        age = weeks + (weeks == 1 ? " week" : " weeks");
        if (remainingDays > 0) {
          age += " and " + remainingDays + (remainingDays == 1 ? " day" : " days");
        }
      }
    }
    logger.info("Determining chicken age. Created Date: {}, Age: {}", createdDate, age);
    return age;
  }

  private FarmResponse buildFarm(Farm farm) {
    List<User> users = userRepository.findByFarmId(farm.getId());
    return FarmResponse.builder()
        .id(farm.getId())
        .farmName(farm.getFarmName())
        .address(farm.getAddress())
        .coops(builCoopList(farm.getCoops()))
        .users(getUserInfoResponseList(users, farm, "Build Farm"))
        .createdDate(farm.getCreatedDate())
        .farmReport(buildFarmReport(farm))
        .build();
  }

  // TODO Unit tests
  private FarmReport buildFarmReport(Farm farm) {
    double totalSales = 0;
    double totalExpenses = 0;
    int totalMortalities = 0;
    int totalChickens = 0;
    List<CoopReport> coopReports = new ArrayList<>();

    if (farm.getCoops() != null) {
      for (Coop coop : farm.getCoops()) {
        if (coop.isActive()) {
          int coopMortality = 0;
          double coopSales = 0;
          double coopExpenses = 0;
          if (coop.getSales() != null) {
            totalSales += coop.getSales().stream().mapToDouble(Sale::getTotalSaleAmount).sum();
            coopSales = coop.getSales().stream().mapToDouble(Sale::getTotalSaleAmount).sum();
          }

          if (coop.getExpenses() != null) {
            totalExpenses += coop.getExpenses().stream().mapToDouble(Expense::getAmount).sum();
            coopExpenses = coop.getExpenses().stream().mapToDouble(Expense::getAmount).sum();
          }

          if (coop.getMortalities() != null) {
            totalMortalities +=
                coop.getMortalities().stream().mapToInt(Mortality::getNumberOfDeaths).sum();
            coopMortality =
                coop.getMortalities().stream().mapToInt(Mortality::getNumberOfDeaths).sum();
          }

          totalChickens += coop.getNumberOfChickens();

          CoopReport coopReport =
              CoopReport.builder()
                  .coopName(coop.getCoopName())
                  .coopType(coop.getCoopType().getValue())
                  .totalChickens(coop.getNumberOfChickens())
                  .chickenAge(getChickenAge(coop.getChickenArrivalDate()))
                  .totalMortality(coopMortality)
                  .availableChickens(coop.getNumberOfChickens() - coopMortality)
                  .profit(coopSales - coopExpenses)
                  .expenses(coopExpenses)
                  .sales(coopSales)
                  .build();
          coopReports.add(coopReport);
        }
      }
    }
    return FarmReport.builder()
        .totalChickens(totalChickens)
        .totalSales(totalSales)
        .totalExpenses(totalExpenses)
        .totalMortalities(totalMortalities)
        .coopReports(coopReports)
        .build();
  }

  private Optional<User> getUserOptional(String id) {
    if (id != null) {
      return userRepository.findById(id);
    } else {
      return Optional.empty();
    }
  }

  // TODO Unit tests
  @Override
  public ResponseEntity<Object> growingPhaseTransition(PhaseTransitionRequest request) {

    Optional<Farm> farmOptional = farmRepository.findById(request.getFarmId());
    Farm farm;
    if (farmOptional.isPresent()) {
      farm = farmOptional.get();
    } else {
      logger.error("Invalid Farm Id: {}", request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Farm not found"));
    }

    Coop currentCoop =
        farm.getCoops().stream()
            .filter(c -> c.getId().equals(request.getCurrentCoopId()))
            .findFirst()
            .orElse(null);

    Coop newCoop =
        farm.getCoops().stream()
            .filter(c -> c.getId().equals(request.getNewCoopId()))
            .findFirst()
            .orElse(null);

    if (currentCoop == null || newCoop == null) {
      logger.error(
          "New Coop ID or Current coop ID is invalid. [IsCurrentCoopNull: {}, IsNewCoopNull: {}, Request: {} ]",
          currentCoop == null,
          newCoop == null,
          request);
      return ResponseEntity.badRequest().body(new MessageResponse(false, "Invalid coop ID(s)"));
    }

    if (request.getCurrentCoopId().equals(request.getNewCoopId())) {
      farm.getCoops().remove(currentCoop);
      currentCoop.setGrowthPhase(GrowingPhase.fromValue(request.getNewGrowingPhase()));
      farm.getCoops().add(currentCoop);

      logger.info("Re-using the current coop for phase transition. Request: {}", request);
    } else {
      farm.getCoops().remove(newCoop);
      farm.getCoops().remove(currentCoop);

      newCoop.setGrowthPhase(GrowingPhase.fromValue(request.getNewGrowingPhase()));
      newCoop.setNumberOfChickens(currentCoop.getNumberOfChickens());
      newCoop.setChickenArrivalDate(currentCoop.getChickenArrivalDate());
      newCoop.setChickenAge(currentCoop.getChickenAge());
      newCoop.setMortalities(currentCoop.getMortalities());
      newCoop.setSales(currentCoop.getSales());
      newCoop.setExpenses(currentCoop.getExpenses());
      newCoop.setReminder(currentCoop.getReminder());
      newCoop.setPhaseTransition(currentCoop.getPhaseTransition());

      Coop newCurrentCoop = new Coop();
      newCurrentCoop.setId(currentCoop.getId());
      newCurrentCoop.setCoopName(currentCoop.getCoopName());
      newCurrentCoop.setCoopType(currentCoop.getCoopType());
      newCurrentCoop.setGrowthPhase(GrowingPhase.BROODING_PHASE);
      newCurrentCoop.setNumberOfChickens(0);
      newCurrentCoop.setCreatedDate(currentCoop.getCreatedDate());

      farm.getCoops().add(newCurrentCoop);
      farm.getCoops().add(newCoop);

      logger.info("Using the new coop for phase transition. Request: {}", request);
    }

    farmRepository.save(farm);
    logger.info("Growing phase transition completed successfully. Request: {}", request);

    return ResponseEntity.ok(buildFarm(farm));
  }

  private Reminder buildReminders(
      Date chickenArrivalDate, CoopType coopType, GrowingPhase growingPhase) {
    if (chickenArrivalDate != null) {
      Reminder reminder = new Reminder();
      reminder.setId(UUID.randomUUID().toString());
      if (coopType == CoopType.LAYERS) {
        reminder.setVaccines(
            vaccineScheduleService.generateLayerVaccineSchedule(chickenArrivalDate));
        reminder.setFeeds(
            feedScheduleService.generateLayerFeedSchedule(chickenArrivalDate, growingPhase));
        reminder.setMedicines(
            medicineScheduleService.generateLayerMedicineSchedule(
                chickenArrivalDate, growingPhase));
      } else {
        reminder.setVaccines(
            vaccineScheduleService.generateBroilerVaccineSchedule(
                chickenArrivalDate, growingPhase));
        reminder.setFeeds(
            feedScheduleService.generateBroilerFeedSchedule(chickenArrivalDate, growingPhase));
        reminder.setMedicines(
            medicineScheduleService.generateBroilerMedicineSchedule(
                chickenArrivalDate, growingPhase));
      }

      return reminder;
    } else {
      return null;
    }
  }
}
