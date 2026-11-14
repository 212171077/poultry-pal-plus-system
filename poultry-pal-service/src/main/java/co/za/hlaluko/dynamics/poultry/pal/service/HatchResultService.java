package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.BatchStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.CycleStatus;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.OutcomeCount;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.HatchResult;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.HatcherCycle;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.IncubationBatch;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.request.HatchResultRequest;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.HatchResultResponse;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.HatchingReportResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.HatchResultRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.HatcherCycleRepository;
import co.za.hlaluko.dynamics.poultry.pal.repository.IncubationBatchRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;

/** Records and reports hatch outcomes. Recording completes the hatcher cycle and, when all eggs are accounted for, the batch. */
@Service
@RequiredArgsConstructor
public class HatchResultService {
  private static final DateTimeFormatter MONTH = DateTimeFormatter.ofPattern("yyyy-MM");

  private final ProductionAccessService accessService;
  private final IncubationService incubationService;
  private final HatchResultRepository resultRepository;
  private final HatcherCycleRepository cycleRepository;
  private final IncubationBatchRepository batchRepository;

  public HatchResultResponse get(UserDetailsImpl actor, String cycleId) {
    String farmId = accessService.requireManage(actor);
    return toResponse(
        resultRepository
            .findByFarmIdAndHatcherCycleId(farmId, cycleId)
            .orElseThrow(() -> ApiException.notFound("No hatch result recorded for this cycle")));
  }

  public HatchResultResponse record(
      UserDetailsImpl actor, String cycleId, HatchResultRequest request) {
    String farmId = accessService.requireManage(actor);
    synchronized (incubationService.lock(farmId)) {
      HatcherCycle cycle = requireCycle(farmId, cycleId);
      if (resultRepository.findByFarmIdAndHatcherCycleId(farmId, cycleId).isPresent()) {
        throw ApiException.conflict("A hatch result is already recorded for this cycle");
      }
      if (cycle.getStatus() != CycleStatus.IN_HATCHER) {
        throw ApiException.conflict("Eggs must be transferred to the hatcher before recording results");
      }
      IncubationBatch batch = requireBatch(farmId, cycle.getIncubationBatchId());
      List<OutcomeCount> others = validate(request, cycle.getQuantity());
      requireNotBeforeTransfer(request.getResultDate(), cycle);

      Instant now = Instant.now();
      HatchResult result =
          HatchResult.builder()
              .farmId(farmId)
              .hatcherCycleId(cycle.getId())
              .incubationBatchId(batch.getId())
              .batchReference(batch.getReference())
              .cycleReference(cycle.getReference())
              .hatcherId(cycle.getHatcherId())
              .eggsTransferred(cycle.getQuantity())
              .hatchedChicks(request.getHatchedChicks())
              .unhatchedEggs(request.getUnhatchedEggs())
              .weakChicks(weak(request))
              .otherOutcomes(others)
              .resultDate(request.getResultDate())
              .notes(blankToNull(request.getNotes()))
              .createdAt(now)
              .updatedAt(now)
              .createdBy(actor.getId())
              .updatedBy(actor.getId())
              .build();
      HatchResult saved;
      try {
        saved = resultRepository.save(result);
      } catch (DuplicateKeyException e) {
        throw ApiException.conflict("A hatch result is already recorded for this cycle");
      }

      cycle.setStatus(CycleStatus.COMPLETED);
      cycle.setUpdatedAt(now);
      cycle.setUpdatedBy(actor.getId());
      cycleRepository.save(cycle);
      completeBatchIfDone(batch, actor, now);
      return toResponse(saved);
    }
  }

  public HatchResultResponse edit(UserDetailsImpl actor, String cycleId, HatchResultRequest request) {
    String farmId = accessService.requireManage(actor);
    synchronized (incubationService.lock(farmId)) {
      HatchResult result =
          resultRepository
              .findByFarmIdAndHatcherCycleId(farmId, cycleId)
              .orElseThrow(() -> ApiException.notFound("No hatch result recorded for this cycle"));
      if (request.getVersion() == null) throw ApiException.badRequest("version is required");
      HatcherCycle cycle = requireCycle(farmId, cycleId);
      List<OutcomeCount> others = validate(request, result.getEggsTransferred());
      requireNotBeforeTransfer(request.getResultDate(), cycle);

      Instant now = Instant.now();
      result.getRevisions().add(
          HatchResult.Revision.builder()
              .revisedAt(now)
              .revisedBy(actor.getId())
              .hatchedChicks(result.getHatchedChicks())
              .unhatchedEggs(result.getUnhatchedEggs())
              .weakChicks(result.getWeakChicks())
              .otherOutcomes(result.getOtherOutcomes())
              .resultDate(result.getResultDate())
              .notes(result.getNotes())
              .build());
      result.setHatchedChicks(request.getHatchedChicks());
      result.setUnhatchedEggs(request.getUnhatchedEggs());
      result.setWeakChicks(weak(request));
      result.setOtherOutcomes(others);
      result.setResultDate(request.getResultDate());
      result.setNotes(blankToNull(request.getNotes()));
      result.setUpdatedAt(now);
      result.setUpdatedBy(actor.getId());
      result.setVersion(request.getVersion());
      try {
        return toResponse(resultRepository.save(result));
      } catch (OptimisticLockingFailureException e) {
        throw ApiException.conflict("This result was changed by someone else. Reload and try again.");
      }
    }
  }

  public HatchingReportResponse report(
      UserDetailsImpl actor,
      LocalDate from,
      LocalDate to,
      String batchId,
      String hatcherId,
      int page,
      int size) {
    List<HatchResult> filtered = filtered(actor, from, to, batchId, hatcherId);
    int pageSize = Math.min(Math.max(size, 1), 200);
    int pageNo = Math.max(page, 0);
    List<HatchResultResponse> rows =
        filtered.stream().skip((long) pageNo * pageSize).limit(pageSize).map(this::toResponse).toList();
    return HatchingReportResponse.builder()
        .summary(summarise(filtered))
        .trend(trend(filtered))
        .rows(rows)
        .page(pageNo)
        .size(pageSize)
        .totalElements(filtered.size())
        .build();
  }

  public String reportCsv(
      UserDetailsImpl actor, LocalDate from, LocalDate to, String batchId, String hatcherId) {
    StringBuilder csv =
        new StringBuilder(
            "Result date,Batch,Cycle,Eggs transferred,Hatched,Unhatched,Weak,Other outcomes,Hatch rate %,Notes\n");
    for (HatchResult r : filtered(actor, from, to, batchId, hatcherId)) {
      String other =
          r.getOtherOutcomes().stream()
              .map(o -> o.getCategory() + ": " + o.getCount())
              .reduce((a, b) -> a + "; " + b)
              .orElse("");
      csv.append(r.getResultDate()).append(',')
          .append(cell(r.getBatchReference())).append(',')
          .append(cell(r.getCycleReference())).append(',')
          .append(r.getEggsTransferred()).append(',')
          .append(r.getHatchedChicks()).append(',')
          .append(r.getUnhatchedEggs()).append(',')
          .append(r.getWeakChicks()).append(',')
          .append(cell(other)).append(',')
          .append(rate(r.getHatchedChicks(), r.getEggsTransferred()) == null
              ? ""
              : rate(r.getHatchedChicks(), r.getEggsTransferred()).toPlainString())
          .append(',')
          .append(cell(r.getNotes()))
          .append('\n');
    }
    return csv.toString();
  }

  private List<HatchResult> filtered(
      UserDetailsImpl actor, LocalDate from, LocalDate to, String batchId, String hatcherId) {
    String farmId = accessService.requireManage(actor);
    LocalDate start = from == null ? LocalDate.of(2000, 1, 1) : from;
    LocalDate end = to == null ? LocalDate.of(2999, 12, 31) : to;
    if (end.isBefore(start)) throw ApiException.badRequest("'to' must not be before 'from'");
    return resultRepository
        .findInRange(farmId, start, end)
        .stream()
        .filter(r -> batchId == null || batchId.isBlank() || batchId.equals(r.getIncubationBatchId()))
        .filter(r -> hatcherId == null || hatcherId.isBlank() || hatcherId.equals(r.getHatcherId()))
        .sorted(
            Comparator.comparing(HatchResult::getResultDate)
                .thenComparing(HatchResult::getId)
                .reversed())
        .toList();
  }

  static HatchingReportResponse.Summary summarise(List<HatchResult> results) {
    long eggs = results.stream().mapToLong(HatchResult::getEggsTransferred).sum();
    long hatched = results.stream().mapToLong(HatchResult::getHatchedChicks).sum();
    long weak = results.stream().mapToLong(HatchResult::getWeakChicks).sum();
    return HatchingReportResponse.Summary.builder()
        .results(results.size())
        .eggsTransferred(eggs)
        .hatchedChicks(hatched)
        .unhatchedEggs(results.stream().mapToLong(HatchResult::getUnhatchedEggs).sum())
        .weakChicks(weak)
        .hatchRate(rate(hatched, eggs))
        .weakRate(rate(weak, hatched))
        .build();
  }

  static List<HatchingReportResponse.TrendPoint> trend(List<HatchResult> results) {
    Map<String, List<HatchResult>> byMonth = new TreeMap<>();
    for (HatchResult r : results) {
      byMonth.computeIfAbsent(r.getResultDate().format(MONTH), k -> new ArrayList<>()).add(r);
    }
    List<HatchingReportResponse.TrendPoint> points = new ArrayList<>();
    byMonth.forEach(
        (period, list) -> {
          long eggs = list.stream().mapToLong(HatchResult::getEggsTransferred).sum();
          long hatched = list.stream().mapToLong(HatchResult::getHatchedChicks).sum();
          points.add(
              HatchingReportResponse.TrendPoint.builder()
                  .period(period)
                  .results(list.size())
                  .eggsTransferred(eggs)
                  .hatchedChicks(hatched)
                  .hatchRate(rate(hatched, eggs))
                  .build());
        });
    return points;
  }

  /** Percentage to two decimals, or null when the denominator is zero. */
  static BigDecimal rate(long numerator, long denominator) {
    if (denominator <= 0) return null;
    return BigDecimal.valueOf(numerator)
        .multiply(BigDecimal.valueOf(100))
        .divide(BigDecimal.valueOf(denominator), 2, RoundingMode.HALF_UP);
  }

  private List<OutcomeCount> validate(HatchResultRequest request, int transferred) {
    List<OutcomeCount> others = new ArrayList<>();
    if (request.getOtherOutcomes() != null) {
      for (OutcomeCount o : request.getOtherOutcomes()) {
        String category = o.getCategory().trim();
        if (others.stream().anyMatch(x -> x.getCategory().equalsIgnoreCase(category))) {
          throw ApiException.badRequest("Duplicate outcome category: " + category);
        }
        others.add(new OutcomeCount(category, o.getCount()));
      }
    }
    long otherTotal = others.stream().mapToLong(OutcomeCount::getCount).sum();
    long total = (long) request.getHatchedChicks() + request.getUnhatchedEggs() + otherTotal;
    if (total != transferred) {
      throw ApiException.badRequest(
          "Hatched, unhatched and other outcomes add up to "
              + total
              + " but "
              + transferred
              + " eggs were transferred");
    }
    if (weak(request) > request.getHatchedChicks()) {
      throw ApiException.badRequest("Weak chicks cannot exceed the number of chicks hatched");
    }
    return others;
  }

  private void requireNotBeforeTransfer(LocalDate date, HatcherCycle cycle) {
    LocalDate transfer =
        cycle.getActualTransferDate() != null
            ? cycle.getActualTransferDate()
            : cycle.getPlannedTransferDate();
    if (date.isBefore(transfer)) {
      throw ApiException.badRequest("The result date cannot be before the transfer date");
    }
  }

  private void completeBatchIfDone(IncubationBatch batch, UserDetailsImpl actor, Instant now) {
    List<HatcherCycle> active =
        cycleRepository
            .findByFarmIdAndIncubationBatchIdIn(batch.getFarmId(), List.of(batch.getId()))
            .stream()
            .filter(c -> c.getStatus() != CycleStatus.CANCELLED)
            .toList();
    boolean allEggsHatched = active.stream().mapToInt(HatcherCycle::getQuantity).sum() == batch.getEggsSet();
    if (allEggsHatched && active.stream().allMatch(c -> c.getStatus() == CycleStatus.COMPLETED)) {
      batch.setStatus(BatchStatus.COMPLETED);
      batch.setUpdatedAt(now);
      batch.setUpdatedBy(actor.getId());
      batchRepository.save(batch);
    }
  }

  private HatcherCycle requireCycle(String farmId, String id) {
    return cycleRepository
        .findByIdAndFarmId(id, farmId)
        .orElseThrow(() -> ApiException.notFound("Hatcher cycle not found"));
  }

  private IncubationBatch requireBatch(String farmId, String id) {
    return batchRepository
        .findByIdAndFarmId(id, farmId)
        .orElseThrow(() -> ApiException.notFound("Batch not found"));
  }

  private int weak(HatchResultRequest request) {
    return request.getWeakChicks() == null ? 0 : request.getWeakChicks();
  }

  private String blankToNull(String value) {
    return value == null || value.isBlank() ? null : value.trim();
  }

  private String cell(String value) {
    if (value == null) return "";
    String safe = value.replace("\"", "\"\"");
    // Neutralise spreadsheet formula injection.
    if (!safe.isEmpty() && "=+-@".indexOf(safe.charAt(0)) >= 0) safe = "'" + safe;
    return "\"" + safe + "\"";
  }

  private HatchResultResponse toResponse(HatchResult r) {
    return HatchResultResponse.builder()
        .id(r.getId())
        .hatcherCycleId(r.getHatcherCycleId())
        .incubationBatchId(r.getIncubationBatchId())
        .batchReference(r.getBatchReference())
        .cycleReference(r.getCycleReference())
        .hatcherId(r.getHatcherId())
        .eggsTransferred(r.getEggsTransferred())
        .hatchedChicks(r.getHatchedChicks())
        .unhatchedEggs(r.getUnhatchedEggs())
        .weakChicks(r.getWeakChicks())
        .otherOutcomes(r.getOtherOutcomes())
        .resultDate(r.getResultDate())
        .hatchRate(rate(r.getHatchedChicks(), r.getEggsTransferred()))
        .weakRate(rate(r.getWeakChicks(), r.getHatchedChicks()))
        .notes(r.getNotes())
        .revisionCount(r.getRevisions() == null ? 0 : r.getRevisions().size())
        .updatedAt(r.getUpdatedAt())
        .version(r.getVersion())
        .build();
  }
}
