package co.za.hlaluko.dynamics.poultry.pal.controller.v1;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import co.za.hlaluko.dynamics.poultry.pal.exception.ApiException;
import co.za.hlaluko.dynamics.poultry.pal.service.ProductionAccessService;
import co.za.hlaluko.dynamics.poultry.pal.service.ProductionIndexInitializer;
import co.za.hlaluko.dynamics.poultry.pal.security.services.UserDetailsImpl;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.mongodb.core.MongoTemplate;

class ProductionHardeningTest extends V1TestSupport {
  @Autowired private MongoTemplate mongoTemplate;
  @Autowired private ProductionIndexInitializer indexInitializer;

  @Test
  @DisplayName("the global kill switch denies production access before any other check")
  void killSwitchDenies() {
    ProductionAccessService disabled = new ProductionAccessService(false);

    assertThatThrownBy(() -> disabled.requireManage(mock(UserDetailsImpl.class)))
        .isInstanceOf(ApiException.class)
        .hasMessageContaining("not enabled");
  }

  @Test
  @DisplayName("production indexes are created and re-running is harmless")
  void createsIndexes() {
    indexInitializer.ensureIndexes();
    indexInitializer.ensureIndexes();

    ProductionIndexInitializer.INDEXES.forEach(
        (collection, expected) -> {
          var names =
              mongoTemplate.indexOps(collection).getIndexInfo().stream()
                  .map(i -> i.getIndexFields().stream().map(f -> f.getKey()).toList())
                  .toList();
          assertThat(names).containsAll(expected);
        });
  }
}
