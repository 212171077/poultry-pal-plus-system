package co.za.hlaluko.dynamics.poultry.pal.mail;

public class MailSenderException extends Exception {
  public MailSenderException(String errorMessage) {
    super(errorMessage);
  }

  public MailSenderException(String errorMessage, Throwable cause) {
    super(errorMessage, cause);
  }
}
