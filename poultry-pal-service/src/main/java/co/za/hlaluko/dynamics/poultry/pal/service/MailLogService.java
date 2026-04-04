package co.za.hlaluko.dynamics.poultry.pal.service;

import java.util.Date;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.EmailLog;
import co.za.hlaluko.dynamics.poultry.pal.repository.EmailLogRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class MailLogService {
  private final EmailLogRepository repository;

  @Autowired
  public MailLogService(EmailLogRepository repository) {
    this.repository = repository;
  }

  public void saveMailLog(EmailLog emailLog) {
    if (emailLog.getId() == null) {
      emailLog.setCreateDate(new Date());
    } else {
      emailLog.setLastUpdateDate(new Date());
    }
    repository.save(emailLog);
  }

}
