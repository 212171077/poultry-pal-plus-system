package co.za.hlaluko.dynamics.poultry.pal.mail;

import java.util.List;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Attachment;
import lombok.Data;

@Data
public class Email {
  private Integer id;
  private String from;
  private String[] to;
  private String[] cc;
  private String subject;
  private String content;
  private List<Attachment> attachments;

  public Email() {
    content = "text/plain";
  }
}