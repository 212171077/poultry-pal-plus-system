package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.EmailLog;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface EmailLogRepository extends MongoRepository<EmailLog, String> {

}
