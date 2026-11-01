package co.za.hlaluko.dynamics.poultry.pal.controller;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.User;
import co.za.hlaluko.dynamics.poultry.pal.service.AccountApprovalService;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

/** Public, token-protected pages the system admin opens from the approval email. */
@RestController
@RequestMapping("/api/auth/approval")
@RequiredArgsConstructor
public class AccountApprovalController {
  private final AccountApprovalService approvalService;

  @GetMapping(produces = MediaType.TEXT_HTML_VALUE)
  public ResponseEntity<String> review(@RequestParam String token) {
    Optional<User> user = approvalService.findPending(token);
    if (user.isEmpty()) {
      return page("Link no longer valid", "<p>This registration was already reviewed or the link is invalid.</p>");
    }
    User u = user.get();
    String form =
        "<p><strong>" + esc(u.getName()) + " " + esc(u.getSurname()) + "</strong><br>"
            + esc(u.getEmail()) + "<br>" + esc(u.getPhoneNumber()) + "</p>"
            + "<form method=\"post\"><input type=\"hidden\" name=\"token\" value=\"" + esc(token) + "\">"
            + "<button name=\"decision\" value=\"approve\">Approve</button> "
            + "<button name=\"decision\" value=\"reject\">Reject</button></form>";
    return page("Review registration", form);
  }

  @PostMapping(produces = MediaType.TEXT_HTML_VALUE)
  public ResponseEntity<String> decide(@RequestParam String token, @RequestParam String decision) {
    boolean approve = "approve".equals(decision);
    if (!approve && !"reject".equals(decision)) {
      return page("Invalid request", "<p>Unknown decision.</p>");
    }
    return approvalService
        .decide(token, approve)
        .map(u -> page("Done", "<p>" + esc(u.getEmail()) + " was " + (approve ? "approved" : "rejected") + ". The user has been notified.</p>"))
        .orElseGet(() -> page("Link no longer valid", "<p>This registration was already reviewed or the link is invalid.</p>"));
  }

  private static ResponseEntity<String> page(String title, String body) {
    String html =
        "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
            + "<title>" + title + "</title></head><body style=\"font-family:sans-serif;max-width:480px;margin:2rem auto;padding:0 1rem\">"
            + "<h2>" + title + "</h2>" + body + "</body></html>";
    return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(html);
  }

  private static String esc(String value) {
    return HtmlUtils.htmlEscape(value == null ? "" : value);
  }
}
