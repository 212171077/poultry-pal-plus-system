package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Date;
import java.util.HashSet;
import java.util.Set;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.DBRef;
import org.springframework.data.mongodb.core.mapping.Document;

@Data
@Builder
@AllArgsConstructor
@Document(collection = "users")
public class User {

    @Id
    private String id;
    @NotBlank
    @Size(max = 50)
    private String name;
    @NotBlank
    @Size(max = 50)
    private String surname;
    @NotBlank
    @Size(max = 15)
    private String phoneNumber;
    private String farmId;
    private boolean farmOwner;
    private boolean active;
    @NotBlank
    @Size(max = 50)
    @Email
    private String email;
    @NotBlank
    @Size(max = 120)
    private String password;
    @DBRef
    private Set<Role> roles = new HashSet<>();
    @NotBlank
    private Date createdDate;
    private String addedByUserId;
    private String rolesUpdatedByUserId;
    private String removedByUserId;
    private boolean removed;

    public User() {
    }

    public User(String email, String password) {
        this.email = email;
        this.password = password;
    }

}
