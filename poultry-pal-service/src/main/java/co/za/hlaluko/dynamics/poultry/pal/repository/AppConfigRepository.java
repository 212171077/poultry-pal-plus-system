package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.lookups.AppConfig;
import org.springframework.data.mongodb.repository.MongoRepository;

import javax.imageio.spi.IIOServiceProvider;

public interface AppConfigRepository extends MongoRepository<AppConfig, String> {
    AppConfig findByCode(String mailUser);
}
