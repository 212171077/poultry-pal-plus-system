# PoultryPal Application Documentation

## HTTPS and HTTP switching

`src/main/resources/keystore/keystore.p12` was renewed in October 2026 for
`tertiaryverify.dedicated.co.za`, expiring on 9 May 2027. It retains alias
`tomcat` and the existing configured password. Keep keystores out of commits.
HTTPS is enabled by default on port 8090. Set `TLS_KEY_STORE_PASSWORD` to the
existing keystore password; `TLS_KEY_STORE` optionally overrides the classpath
keystore location. A local ignored `.env` contains the existing password.
Do not commit that file. Spring Boot does not load `.env` automatically:

```bash
# From poultry-pal-service; requires Java 21.
set -a; . ./.env; set +a
./mvnw spring-boot:run
# HTTP instead, on the same port:
TLS_ENABLED=false ./mvnw spring-boot:run
```

For Docker Compose, set `JWT_SECRET` in the environment or local `.env`, then:

```bash
./mvnw package -DskipTests
docker compose up -d --build
# Switch both backend and Angular/Nginx to HTTP, without changing ports:
TLS_ENABLED=false docker compose up -d
# Switch both back to HTTPS:
TLS_ENABLED=true docker compose up -d
```

Compose loads `.env` automatically. The web container mounts the renewed PEM
files from `../poultry-pal-plus-web/config` read-only; private keys are not
baked into its image. Access the web app at
`https://tertiaryverify.dedicated.co.za:8080` and the API at
`https://tertiaryverify.dedicated.co.za:8090`.
The certificate does not cover `localhost` or IP addresses. For local browser
HTTPS access, map `tertiaryverify.dedicated.co.za` to `127.0.0.1` in your hosts
file (remove the mapping when accessing the remote deployment).

`COOKIE_SECURE` follows `TLS_ENABLED` unless explicitly overridden; remove any
fixed `COOKIE_SECURE=true` override before switching to HTTP. Clear existing
site cookies after changing protocols. HTTP on a non-localhost origin disables
service workers/offline PWA support. See the Angular README for dev-server commands.

## Building and pushing the combined image

From the repository root, run `./push-image.sh` (tag `latest`) or
`./push-image.sh v1.0.0`. The script prompts for **HTTPS** (Enter or `1`) or
**HTTP** (`2`), builds both Angular and Spring Boot inside Docker, then pushes
`212171077/poultry-pal:<tag>` using your existing `docker login`.
No local Node or Java installation is needed. `DOCKER_USER` and
`DOCKER_REGISTRY` optionally change the destination. Nothing is pushed until
the build succeeds. Use distinct tags when retaining both HTTP and HTTPS builds.
Builds reuse Docker layers and a BuildKit Maven dependency cache. Maven resolves
dependencies during packaging rather than running the extra `dependency:go-offline`
plugin. If a repository returns a transient 502, rerun the script; completed
downloads are retained and a failed build is never pushed.

The choice sets the image's default protocol for both ports. Runtime
`TLS_ENABLED=true` or `TLS_ENABLED=false` overrides it without rebuilding.
The combined image listens on port **8086** for the web app and **8090** for the
backend. Publish backend port **8091** to retain the hosted mobile service's port.
MongoDB remains a separate service. Unlike the standalone backend image,
the combined image excludes private keys and keystores from its build context;
HTTPS needs read-only mounts at runtime.
Both nginx and Spring Boot use the same mounted `fullchain.pem` and unencrypted
`privkey.pem`. Spring Boot uses a PEM SSL bundle: the combined image does **not**
require a PKCS12 keystore or `TLS_KEY_STORE_PASSWORD`. Standalone backend startup
still uses its existing keystore configuration.

For Let's Encrypt certificates, mount the **entire** `/etc/letsencrypt` directory
at `/etc/letsencrypt` read-only and set
`TLS_CERT_DIR=/etc/letsencrypt/live/tertiaryverify.dedicated.co.za`.
Do not also mount its `live` directory at `/etc/nginx/tls`: relative symlinks to
`../../archive` would break. `TLS_CERT_DIR` defaults to `/etc/nginx/tls` for
deployments using regular PEM files rather than Let's Encrypt symlinks.
The combined image health check verifies the web page and proxied v1 API over
HTTPS with certificate verification; `docker compose up --wait` waits for it.

The shared `deployment-dc.yml` instead mounts regular PEM files from
`./poultry-pal-tls` on the deployment server (override with `POULTRY_TLS_DIR`).
Copy the renewed full chain and matching unencrypted private key there as
`fullchain.pem` and `privkey.pem`, keeping the key readable only by the deployment
administrator. Do not copy Let’s Encrypt symlinks into this directory. The local
ignored `poultry-pal-plus-web/config` directory contains the prepared renewal
files; they are not included in the Docker image. Updating the files requires
restarting Poultry Pal so both nginx and Spring Boot reload them.
The deployment script validates expiry, hostname and key matching before its
existing cleanup sequence; other services retain their certificate configuration.

Example from the repository root, with an existing MongoDB on the Docker host:

```bash
# Set JWT_SECRET and MongoDB credentials
# through your deployment environment; do not put them in this script.
set -a; . poultry-pal-service/.env; set +a
docker run -d --name poultry-pal-combined \
  -p 8086:8086 -p 8091:8090 \
  --add-host host.docker.internal:host-gateway \
  -e TLS_ENABLED=true -e JWT_SECRET \
  -e SPRING_DATA_MONGODB_HOST=host.docker.internal \
  -e SPRING_DATA_MONGODB_PORT=27017 \
  -e SPRING_DATA_MONGODB_DATABASE=poultry-pal-db \
  -e SPRING_DATA_MONGODB_AUTHENTICATION_DATABASE=admin \
  -e SPRING_DATA_MONGODB_USERNAME -e SPRING_DATA_MONGODB_PASSWORD \
  -v "$PWD/poultry-pal-plus-web/config:/etc/nginx/tls:ro" \
  212171077/poultry-pal:latest
```

Use the existing deployment's MongoDB host, port, database, authentication database
and credentials; the values above are examples. Do not start a fresh MongoDB or
change its volume when replacing the backend. Stop the old backend container
before binding its existing host port 8091.

Open `https://tertiaryverify.dedicated.co.za:8086`. Nginx forwards `/api` to the
backend inside this container; the deployed web app does not use `proxy.hosted.json`.
The mobile app must use `https://tertiaryverify.dedicated.co.za:8091/api/auth` and
`https://tertiaryverify.dedicated.co.za:8091/api/farm` for this HTTPS deployment.
Its current `http://154.0.166.216:8091` URL cannot talk HTTP to an HTTPS listener.
Allow inbound ports 8086 and 8091 in the host firewall.

To build locally without pushing:

```bash
docker build --build-arg TLS_ENABLED=true -f Dockerfile.combined \
  -t 212171077/poultry-pal:latest .
```

Run that build command from the repository root. Push only when ready with
`docker push 212171077/poultry-pal:latest`. Certificate files,
keystores and `.env` files remain excluded from the build context.

For HTTP, recreate the container with `-e TLS_ENABLED=false`; TLS mounts
can then be omitted. Remove any fixed `COOKIE_SECURE`
override when changing protocols. Keep the same MongoDB and JWT configuration.
The existing Compose file still deploys separate backend and frontend images;
this combined image replaces those two containers, not MongoDB.

## 1. Application Overview

PoultryPal is a comprehensive poultry farm management application designed to streamline and
 simplify the daily operations of poultry farmers. It aims to provide a centralized system for managing various aspects of a poultry farm, from user and farm administration to detailed record-keeping and reporting.

**Purpose of the application**: To provide a digital
 solution for efficient poultry farm management.
**The problem it solves**: Manual and disparate record-keeping, inefficient farm oversight, and lack of integrated management tools for poultry farmers.
**Target users or stakeholders**: Poultry farmers, farm managers,
 farm workers, and administrators overseeing poultry operations.
**High-level business context**: The application supports the agricultural sector by enhancing productivity and decision-making for poultry farming businesses.

## 2. Technology Stack

The application is built on a modern Java ecosystem, leveraging Spring Boot for rapid development and a reactive approach for certain
 data operations.

*   **Java version**: Java 21
*   **Frameworks used**:
    *   **Spring Boot (v3.3.4)**: The core framework for building the application, providing auto-configuration and a robust environment.
    *   **Spring Web**: For building
 RESTful APIs.
    *   **Spring Data MongoDB**: For interacting with the MongoDB database.
    *   **Spring Data MongoDB Reactive**: Indicates potential use of reactive programming for MongoDB operations, though the primary API endpoints appear synchronous.
    *   **Spring Security**: For authentication and authorization, including JWT-based security
.
    *   **Spring Validation**: For declarative data validation.
    *   **Spring Mail**: For sending emails.
    *   **Springdoc OpenAPI (v2.6.0)**: For generating API documentation (Swagger UI).
    *   **Thymeleaf**: A server-side Java
 template engine, likely used for generating dynamic content, possibly for email templates or reports.
    *   **Thymeleaf Extras Spring Security 6**: Integration for Thymeleaf with Spring Security.
*   **Databases and storage mechanisms**:
    *   **MongoDB**: A NoSQL document database used for persistent
 data storage.
*   **External libraries and integrations**:
    *   **Project Reactor (v3.6.2)**: A reactive programming library for building non-blocking applications.
    *   **MapStruct (v1.5.3.Final)**: A code generator that simplifies the implementation
 of data object mappings.
    *   **Lombok (v1.18.30)**: A library that reduces boilerplate code for Java classes (e.g., getters, setters, constructors).
    *   **JJWT (v0.11.5)**: Java JWT (JSON Web Token
) library for implementing token-based authentication.
    *   **Flying Saucer PDF / OpenHTMLToPDF**: Libraries for generating PDF documents from HTML/CSS, likely used for reports.
    *   **ZXing (v2.0/v3.3.0)**: Barcode/QR code image
 processing library, potentially used for tracking or identification within the farm.
    *   **Testcontainers (v1.17.6)**: For providing lightweight, disposable instances of databases (like MongoDB) for integration tests.
    *   **de.flapdoodle.embed.mongo (v4.13.
1)**: An embedded MongoDB for testing purposes.

## 3. Architecture & Design

The application follows a traditional layered architecture, characteristic of a **monolith**, with clear separation of concerns.

*   **Application type**: Layered Monolith.
*   **Package and module structure**:
    *
   `co.za.hlaluko.dynamics.poultry.pal` (Root package)
        *   `controller`: Contains REST controllers responsible for handling incoming HTTP requests and returning responses.
        *   `service`: Encapsulates the business logic and orchestrates operations between controllers and repositories.
        *
   `repository`: Provides an abstraction layer for data access operations with MongoDB.
        *   `model`: Holds data structures, including:
            *   `entity`: MongoDB document definitions.
            *   `dto`: Data Transfer Objects for transferring data between layers.
            *   `payload`: Request and
 response objects for API communication.
        *   `security`: Manages authentication and authorization logic, including JWT handling.
        *   `mail`: Handles email-related functionalities.
        *   `schedule`: Contains scheduled tasks for automated processes (e.g., reminders).
        *   `utils`: Provides utility classes for
 common functions.
        *   `excption` (Note: Typo, should be `exception`): Contains custom exception classes.
*   **Key design patterns used**:
    *   **Layered Architecture**: Separation into presentation (controller), business logic (service), and data access (repository) layers.

    *   **Dependency Injection**: Managed by Spring for loose coupling.
    *   **Repository Pattern**: Abstracting data storage details.
*   **Separation of concerns**:
    *   **Controllers**: Handle HTTP requests, delegate to services, and return HTTP responses.
    *   **Services**: Implement business rules
 and orchestrate data operations.
    *   **Repositories**: Interact directly with the MongoDB database.

## 4. Core Functionalities

The PoultryPal application provides a comprehensive set of features for managing poultry farms:

*   **User Management**:
    *   User registration (`/api/auth/signup`).

    *   User authentication (`/api/auth/signin`).
    *   User activation/deactivation.
    *   Updating user profiles and login details.
    *   Role management (assigning roles like ADMIN, USER, FARM_MANAGER, FARM_WORKER).
    *   Adding and
 removing farm users.
*   **Farm Management**:
    *   Creating and updating farm details.
    *   Managing coops within a farm (add, update, delete).
    *   Adding new batches of poultry.
    *   Assigning responsible users to coops.
*   **Record
 Keeping**:
    *   Recording mortalities.
    *   Tracking sales.
    *   Managing expenses.
    *   Recording egg packaging.
*   **Schedule Management**:
    *   Managing feed schedules.
    *   Managing vaccine schedules.
    *   Managing medicine schedules.
    *   Updating
 reminders for various farm activities.
    *   Growing phase transitions for poultry batches.
*   **Reporting & Analytics**:
    *   Downloading comprehensive farm reports.
    *   Downloading schedule-specific reports.
    *   Sending reports and schedules via email.
*   **Notifications**:
    *   Sending automated
 reminders.
    *   User-configurable alerts (sales, mortality, expenses, daily reminders).
*   **User Settings**:
    *   Customizing user-specific settings such as currency, auto-creation of reminders, and alert preferences.

## 5. Data Model

The application uses MongoDB to
 store its data. Key entities and their relationships are managed through Spring Data MongoDB.

*   **Main entities**:
    *   `User`: Stores user credentials, profile information, and associated farm details.
    *   `Role`: Defines user roles (e.g., `ADMIN`, `USER`, `F
ARM_MANAGER`, `FARM_WORKER`) for access control.
    *   `Farm`: Represents a poultry farm, containing details about its coops, batches, and associated users.
    *   `CoopArchive`: Likely stores historical data for coops.
    *   `EmailLog`: Records details
 of emails sent by the application.
    *   `EmailContent`: Stores templates or content for various types of emails.
    *   `UserSettings`: Stores personalized settings for each user.
    *   `AppConfig`: Stores application-wide configuration parameters or lookup values.
    *   Other entities implied
 by services: `FeedSchedule`, `VaccineSchedule`, `MedicineSchedule`, `MortalityRecord`, `SaleRecord`, `ExpenseRecord`, `EggPackagingRecord`.
*   **Database schema overview**: MongoDB's flexible schema allows for document-based storage. Entities are typically mapped to collections. Relationships are likely handled
 through embedded documents or references.
*   **DTOs and data flow**: DTOs (Data Transfer Objects) and payload classes (`request`, `response`) are used extensively to define the structure of data exchanged between the client, controllers, and services, ensuring clear data contracts.

## 6. API & Interfaces

The application
 exposes a RESTful API for client interaction, secured using JWT.

*   **REST endpoints**:
    *   `/api/auth/**`: Authentication-related endpoints (e.g., `/signin`, `/signup`).
    *   `/api/farm/**`: Endpoints for managing farm operations, users, records
, and reports.
    *   `/v3/api-docs/**`, `/swagger-ui/**`, `/swagger-ui.html`: Endpoints for OpenAPI documentation (Swagger UI).
*   **Request/response patterns**: Standard RESTful patterns are used, with JSON payloads for requests and responses. 
`ResponseEntity` is used to control HTTP status codes and headers.
*   **Authentication and authorization mechanisms**:
    *   **Authentication**: JWT (JSON Web Token) based. Users authenticate with credentials, receive a JWT, and then include this token in subsequent requests.
    *   **Authorization**: Role-Based
 Access Control (RBAC) implemented using Spring Security's `@PreAuthorize` annotation, restricting access to endpoints based on user roles (e.g., `hasRole('ADMIN')`, `hasRole('FARM_MANAGER')`).

### 6.1 Web/offline API (`/api/v1`)

The `/api/v1` endpoints serve the offline-first web app. Legacy `/api/auth/*` and `/api/farm/*` keep their existing contract for the Flutter app.

Every v1 response uses one envelope:

```json
{ "success": true, "message": "string", "data": {}, "errorCode": "VALIDATION_ERROR", "errors": [{ "field": "x", "message": "..." }] }
```

`errorCode` and `errors` appear only on failures. The codes are `VALIDATION_ERROR`, `BAD_REQUEST`, `UNAUTHORIZED`, `INVALID_CREDENTIALS`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`, `DUPLICATE`, `UNSUPPORTED_OPERATION` and `INTERNAL_ERROR`.

**Auth (`/api/v1/auth`)**

Auth uses HttpOnly cookies only; no tokens appear in response bodies.

| Endpoint | Description |
|---|---|
| `POST /signin` | Sets the access cookie `poultry-pal` (1 h, path `/api`) and the refresh cookie `poultry-pal-refresh` (30 days, path `/api/v1/auth`). With `"rememberMe": false` the refresh cookie is a browser-session cookie; refresh keeps this choice |
| `POST /signup` | Registers a farm owner and their farm. A duplicate email returns `409 CONFLICT` |
| `POST /refresh` | Rotates the refresh token. If a revoked token is reused more than 30 s after rotation, all of that user's sessions are revoked |
| `POST /logout` | Revokes the refresh token and clears both cookies |
| `GET /me` | Returns the current user |

**Sync (`/api/v1/sync`)**

All sync data is scoped to the caller's farm. Workers only see the coops they are responsible for.

| Endpoint | Description |
|---|---|
| `POST /push` | Accepts `{operations:[{opId, entityType, operation, entityId, coopId, baseVersion, payload}]}`, with 1–200 operations per request. Each operation returns `APPLIED`, `CONFLICT` (stale `baseVersion`, includes `serverRecord`) or `REJECTED` (validation or permission). Replaying an `opId` returns the original result with `duplicate=true` |
| `GET /changes?since=&limit=` | Returns records and tombstones with `version > since`, plus `cursor`, `hasMore` and `resetRequired`. If `resetRequired` is true, the client must re-bootstrap |
| `GET /bootstrap` | Returns the user, a full farm snapshot, the team and settings |

- **Entity types:** `FARM`, `COOP`, `SALE`, `MORTALITY`, `EXPENSE`, `EGG_PACKAGING` and `REMINDER` (`ACTION` marks a reminder as done).
- **Coop lifecycle actions:** a `COOP` `ACTION` operation runs one of two lifecycle changes. Its payload is `{action, batch?, newGrowthPhase?, targetCoopId?}`, and `baseVersion` is ignored.
  - `NEW_BATCH` is for farm managers only. It archives the coop and all its records to `coop_archives`, clears the coop's records (they come back as tombstones), and then applies `batch` (a full coop payload).
  - `PHASE_TRANSITION` sets `newGrowthPhase`. If `targetCoopId` names another coop, the flock (chicken count, arrival date and reminder) and all of its records move into that coop, and the source coop is reset to brooding with 0 chickens. The target coop must be the same type and must be empty.
- **Client-generated IDs:** clients create record IDs themselves, so creates are idempotent.

**Versioning model**

- **Farm version:** the `Farm` document has an optimistic-lock `@Version`.
- **Record stamping:** on every save, including legacy saves, `FarmChangeTracker` gives each changed record `version` (equal to the farm version), `updatedAt` and `updatedBy`.
- **Deletes:** deleting a record creates a tombstone. Tombstones are pruned after 90 days.
- **Migration:** on startup, `SyncDatabaseInitializer` sets `version=1` on any farm that has no version, and creates TTL indexes for `sync_operations` (30 days) and `refresh_tokens`.
- **Concurrent saves:** two concurrent saves of the same farm, including legacy saves, can no longer silently overwrite each other. The losing save fails with `OptimisticLockingFailureException`. v1 push retries up to 3 times.

## 7. Configuration & Environment

Application settings are managed through property files and environment variables.


*   **Application configuration files**:
    *   `application.properties`: Contains core application settings, including server port, database connection details, and JWT configuration.
    *   `log4j2.xml`: Configures the Log4j2 logging framework.
*   **Environment-specific settings**:
    *
   MongoDB connection details (host, port, database name, username, password).
    *   JWT secret and expiration time.
    *   Server port (default: 8090).
    *   Swagger UI paths.
    *   Mail user and password (currently hardcoded in `ConstantUtil
` and potentially overridden by `AppConfig`).
*   **Environment variables**:

    | Variable | Default | Purpose |
    |---|---|---|
    | `JWT_SECRET` | *(random per start, with a warning)* | Base64 HMAC key, at least 64 bytes. **Required in production** (`docker-compose` refuses to start without it). Generate one with `openssl rand -base64 64` |
    | `JWT_ACCESS_EXPIRATION_MS` | `3600000` | Lifetime of the v1 access cookie |
    | `JWT_REFRESH_EXPIRATION_MS` | `2592000000` | Lifetime of the v1 refresh cookie (30 days) |
    | `TLS_ENABLED` | `true` | Set to `false` to serve HTTP on the same port (also switches Angular/Nginx in Compose) |
    | `TLS_KEY_STORE_PASSWORD` | *(required for HTTPS)* | Password of the renewed PKCS12 keystore |
    | `COOKIE_SECURE` | follows `TLS_ENABLED` | Optional override for the auth cookie Secure flag |
    | `COOKIE_SAME_SITE` | `Lax` | `SameSite` attribute of the auth cookies |
    | `CORS_ALLOWED_ORIGINS` | HTTPS localhost/domain on port 4200, HTTP localhost on port 4200 | Comma-separated list of browser origins allowed to send credentials |

    The legacy token lifetime (`poultry.pal.app.jwt.expiration.ms`, 24 h) is unchanged.
*   **Security and secrets handling**:
    *   The JWT secret is supplied only through `JWT_SECRET`. Database credentials are configured in `application.properties` and are designed to be overridden by environment variables in production deployments (as seen in `docker-compose.yml`).
    *
   Mail credentials are also present in `ConstantUtil.java` and initialized via `AppConfigRepository` if not present in the database.

## 8. Error Handling & Logging

The application incorporates custom exception handling and uses a robust logging framework.

*   **Exception handling approach**:
    *   Custom
 exceptions like `PoultryPalException` and `NotFoundException` are used to convey specific error conditions.
    *   While a global `@ControllerAdvice` was not explicitly found, exceptions thrown from controllers are likely handled by Spring Boot's default error mechanisms or implicitly within service layers.
*   **Logging framework and strategy**:
    
*   **Log4j2**: Used for application logging, configured via `log4j2.xml`.
    *   Logging levels (e.g., `INFO`) are configured in `application.properties` for Spring framework classes.
    *   Controllers and services use `LogManager.getLogger()
` for logging operational information and debugging.

## 9. Build, Run & Deployment

The project uses Maven for build automation and is containerized for deployment.

*   **How to build the project**:
    *   Use Maven: `mvn clean install` to compile, test, and package the application into
 a JAR file.
*   **How to run it locally**:
    *   **From JAR**: After building, run `java -jar target/poultry-pal-0.0.1-SNAPSHOT.jar`.
    *   **With Spring Boot Maven Plugin**: `mvn spring-boot:run
`.
    *   **With Docker Compose**: `docker-compose up` (requires Docker and Docker Compose installed).
*   **Deployment considerations**:
    *   **Containerization**: A `Dockerfile` is provided to build a Docker image of the application, using `openjdk:21-jdk-slim` as the
 base image.
    *   **Orchestration**: `docker-compose.yml` defines a multi-service environment, including the application and a MongoDB instance, facilitating local development and deployment. Environment variables are used to pass configuration to the Docker containers.

## 10. Key Observations & Recommendations

###
 Code Quality Observations

*   **Lombok Usage**: Effective use of Lombok to reduce boilerplate code, improving readability and conciseness.
*   **Logging**: Consistent logging practices are observed across controllers and services, aiding in debugging and monitoring.
*   **Package Structure**: Generally well-organized into logical layers (controller, service, repository
, model, security).
*   **Security Implementation**: Spring Security with JWT and `@PreAuthorize` annotations provides a solid foundation for authentication and authorization.
*   **API Documentation**: Integration with Springdoc OpenAPI (Swagger UI) is a good practice for API discoverability.

### Architectural Strengths and Weaknesses

**
Strengths**:

*   **Clear Layered Architecture**: Promotes separation of concerns, making the codebase easier to understand, maintain, and test.
*   **Robust Security**: JWT-based authentication and role-based authorization are well-implemented.
*   **Containerization**: Docker and Docker Compose support streamline
 development and deployment workflows.
*   **Reactive Data Access**: The inclusion of `spring-boot-starter-data-mongodb-reactive` suggests an intent for high-performance, non-blocking data operations, which can be a significant advantage for scalability.

**Weaknesses**:

*   **Hardcoded Secrets**: Sensitive
 information (JWT secret, mail credentials, database credentials) is hardcoded in `application.properties` and `ConstantUtil.java`. While `docker-compose.yml` shows environment variable overrides, the presence in source code is a security risk.
*   **Typo in Package Name**: The `excption` package should
 be renamed to `exception` for clarity and consistency.
*   **Potential for Mixed Reactive/Blocking Code**: The presence of both `spring-boot-starter-data-mongodb` and `spring-boot-starter-data-mongodb-reactive`, combined with synchronous `ResponseEntity<Object>` returns in services, suggests
 a potential mix of blocking and non-blocking operations. This could lead to performance bottlenecks if not carefully managed.
*   **Incomplete Exception Handling**: The absence of a global `@ControllerAdvice` for handling custom exceptions like `PoultryPalException` might lead to inconsistent error responses or expose internal details.
*   **TODO
s in Code**: Several `TODO` comments, particularly in `FarmController`, indicate areas needing attention, such as unit tests and potential issues with `@PreAuthorize` configuration.

### Suggestions for Improvement or Refactoring

1.  **Centralize Secret Management**:
    *   Move all sensitive credentials (JWT secret, database
 passwords, mail credentials) out of `application.properties` and `ConstantUtil.java`.
    *   Utilize Spring Cloud Config Server, HashiCorp Vault, or environment variables exclusively for managing secrets in all environments.
2.  **Refactor Exception Handling**:
    *   Implement a global exception
 handler using `@ControllerAdvice` or `@RestControllerAdvice` to provide consistent and user-friendly error responses across the application.
    *   Ensure that internal exception details are not exposed to clients.
3.  **Address Package Name Typo**:
    *   Rename the `excption` package to `exception` for
 better code readability and adherence to naming conventions.
4.  **Review Reactive Implementation**:
    *   If the intention is a fully reactive application, ensure that all data access and service layers consistently use reactive types (Mono, Flux) and that controllers return reactive types (e.g., `Mono<ResponseEntity<Object
>>`).
    *   If a hybrid approach is intended, clearly document which parts are reactive and which are blocking, and ensure proper thread management.
5.  **Complete Unit and Integration Tests**:
    *   Address the `TODO` comments regarding unit tests, especially for critical business logic and new features.
    *   Lever
age Testcontainers for robust integration testing with MongoDB.
6.  **Enhance Role Management**:
    *   Investigate and resolve the `@PreAuthorize` issue mentioned in `FarmController` to ensure role-based access control is functioning as expected.
7.  **Code Consistency**:
    *   Ensure
 consistent use of logging, validation, and error handling across all modules.
8.  **Documentation**:
    *   Add Javadoc comments to classes and methods, especially for public APIs and complex business logic, to improve code maintainability.
