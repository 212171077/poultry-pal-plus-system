package co.za.hlaluko.dynamics.poultry.pal.model.entity;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.ApprovalStatus;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.ProductionPermission;
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
    /** Farm-scoped grants; null or empty means none. */
    private Set<ProductionPermission> permissions;
    private String permissionsUpdatedByUserId;
    private Date permissionsUpdatedAt;
    private boolean removed;
    /** Null means a legacy account that never needed approval. */
    private ApprovalStatus approvalStatus;
    private String approvalTokenHash;
    private String passwordResetCodeHash;
    private Date passwordResetExpiry;
    private int passwordResetAttempts;

    public User() {
    }

    public User(String email, String password) {
        this.email = email;
        this.password = password;
    }

}
