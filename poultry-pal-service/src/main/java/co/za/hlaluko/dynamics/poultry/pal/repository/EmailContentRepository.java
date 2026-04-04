package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.EmailContent;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.EmailLog;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface EmailContentRepository extends MongoRepository<EmailContent, String> {
    EmailContent findById(Long parseLong);
    List<EmailContent> findTop100ByOrderByIdDesc();
}
