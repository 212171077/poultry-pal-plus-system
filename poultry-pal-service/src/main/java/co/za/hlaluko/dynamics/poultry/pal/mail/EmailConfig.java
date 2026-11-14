package co.za.hlaluko.dynamics.poultry.pal.mail;

import jakarta.mail.internet.MimeMessage;
import java.util.Properties;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.MailException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;
import org.thymeleaf.templateresolver.ITemplateResolver;

@Configuration
public class EmailConfig {

  private final MailSettings settings;

  @Autowired
  public EmailConfig(MailSettings settings) {
    this.settings = settings;
  }

  @Bean
  public JavaMailSender getMailSender() {
    return new DatabaseMailSender(settings);
  }

  /** HTML Email config */
  @Bean
  public ITemplateResolver templateResolver() {
    ClassLoaderTemplateResolver templateResolver = new ClassLoaderTemplateResolver();
    templateResolver.setPrefix("templates/");
    templateResolver.setSuffix(".html");
    templateResolver.setTemplateMode(TemplateMode.HTML);
    return templateResolver;
  }

  /** Re-reads the SMTP settings from the database before every send, so edits apply without a restart. */
  static class DatabaseMailSender extends JavaMailSenderImpl {
    private final MailSettings settings;

    DatabaseMailSender(MailSettings settings) {
      this.settings = settings;
    }

    @Override
    protected void doSend(MimeMessage[] mimeMessages, Object[] originalMessages)
        throws MailException {
      refresh();
      super.doSend(mimeMessages, originalMessages);
    }

    private synchronized void refresh() {
      setHost(settings.get(MailSettings.HOST));
      setPort(Integer.parseInt(settings.get(MailSettings.PORT)));
      setUsername(settings.get(MailSettings.USER));
      setPassword(settings.get(MailSettings.PASS));

      Properties properties = new Properties();
      properties.put("mail.transport.protocol", "smtp");
      properties.put("mail.smtp.auth", String.valueOf(settings.flag(MailSettings.AUTH)));
      properties.put(
          "mail.smtp.starttls.enable", String.valueOf(settings.flag(MailSettings.STARTTLS)));
      properties.put("mail.debug", "true");
      setJavaMailProperties(properties);
    }
  }
}
