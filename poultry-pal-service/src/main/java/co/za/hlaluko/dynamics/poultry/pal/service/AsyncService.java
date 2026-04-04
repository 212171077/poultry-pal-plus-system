package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.mail.Email;
import co.za.hlaluko.dynamics.poultry.pal.mail.EmailSender;
import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.utils.ConstantUtil;
import lombok.AllArgsConstructor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@AllArgsConstructor
@Service
public class AsyncService {
  private final EmailSender emailSender;

  @Async
  public void registrationNotification(User u, String plainPass) {

    String welcome =
        "<p>Dear #NAME#,</p>"
            + "<p>We are delighted to inform you that your Poultry Pal Plus"
            + "account has been successfully created. Your account details are as follows:</p>"
            + "<ul>"
            + "<li><strong>Username: </strong> "
            + u.getEmail()
            + "</li>"
            + "<li><strong>Password:</strong> "
            + plainPass
            + "</li>"
            + "</ul>"
            + "<p>Please use these details to log in to your account. "
            + "We recommend that you change your password as soon as "
            + "you log in for security reasons.</p>"
            + "<p>If you have any questions or need assistance with "
            + "your account, please do not hesitate to contact us. "
            + "We are always happy to help you.</p>"
            + "<p>Thank you for joining Poultry Pal Plus. ";
    welcome = welcome.replace("#NAME#", u.getName() + " " + u.getSurname());

    Email mail = new Email();

    mail.setContent(welcome);
    mail.setFrom(ConstantUtil.NO_REPLY_EMAIL);
    String[] to = {u.getEmail()};
    mail.setTo(to);
    mail.setSubject("Poultry Pal Plus Account");
    mail.setCc(to);
    emailSender.saveEmail(mail);
  }
}
