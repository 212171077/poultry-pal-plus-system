package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Coop;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.EggPackagingRecord;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ERole;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Expense;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Mortality;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Sale;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.CoopArchive;
import co.za.hlaluko.dynamics.poultry.pal.model.payload.response.ArchivedBatchResponse;
import co.za.hlaluko.dynamics.poultry.pal.repository.CoopArchiveRepository;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import java.util.Collection;
import java.util.List;
import java.util.function.ToDoubleFunction;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/** Read access to the batches archived when a new batch is started in a coop. */
@Service
@RequiredArgsConstructor
public class BatchArchiveService {
  private final CoopArchiveRepository coopArchiveRepository;

  public List<ArchivedBatchResponse> listArchivedBatches(UserDetailsImpl user) {
    if (user == null) {
      throw ApiException.unauthorized("Authentication required");
    }
    if (user.getFarmId() == null || user.getFarmId().isBlank()) {
      throw ApiException.forbidden("User is not linked to a farm");
    }
    boolean canManage =
        user.isFarmOwner()
            || user.getAuthorities().stream()
                .anyMatch(
                    a ->
                        a.getAuthority().equals(ERole.ROLE_FARM_MANAGER.name())
                            || a.getAuthority().equals(ERole.ROLE_ADMIN.name()));
    if (!canManage) {
      throw ApiException.forbidden("Only the farm owner or a farm manager can view archived batches");
    }
    return coopArchiveRepository.findByFarmIdOrderByCreatedDateDesc(user.getFarmId()).stream()
        .filter(archive -> archive.getCoop() != null)
        .map(BatchArchiveService::toResponse)
        .toList();
  }

  private static ArchivedBatchResponse toResponse(CoopArchive archive) {
    Coop coop = archive.getCoop();
    List<Sale> sales = orEmpty(coop.getSales());
    List<Expense> expenses = orEmpty(coop.getExpenses());
    List<Mortality> mortalities = orEmpty(coop.getMortalities());
    List<EggPackagingRecord> eggs = orEmpty(coop.getEggPackagingRecords());
    return ArchivedBatchResponse.builder()
        .id(archive.getId())
        .coopId(coop.getId())
        .coopName(coop.getCoopName())
        .coopType(coop.getCoopType())
        .growthPhase(coop.getGrowthPhase())
        .numberOfChickens(coop.getNumberOfChickens())
        .chickenArrivalDate(coop.getChickenArrivalDate())
        .archivedDate(archive.getCreatedDate())
        .totalSales(sum(sales, s -> s.getTotalSaleAmount() == null ? 0 : s.getTotalSaleAmount()))
        .totalExpenses(sum(expenses, e -> e.getAmount() == null ? 0 : e.getAmount()))
        .totalDeaths((int) sum(mortalities, Mortality::getNumberOfDeaths))
        .totalEggs((int) sum(eggs, EggPackagingRecord::getTotalEggs))
        .salesCount(sales.size())
        .expensesCount(expenses.size())
        .mortalityCount(mortalities.size())
        .eggRecordCount(eggs.size())
        .build();
  }

  private static <T> List<T> orEmpty(List<T> list) {
    return list == null ? List.of() : list;
  }

  private static <T> double sum(Collection<T> items, ToDoubleFunction<T> value) {
    return items.stream().mapToDouble(value).sum();
  }
}
