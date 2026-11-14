# syntax=docker/dockerfile:1
# Builds the backend from source so no host JDK is needed (the service targets Java 21).
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -q -B dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -q -B -DskipTests package \
    && cp target/poultry-pal-*.jar /app.jar

FROM eclipse-temurin:21-jre-jammy
COPY --from=build /app.jar /app/poultry-pal.jar
EXPOSE 8090
ENTRYPOINT ["java", "-jar", "/app/poultry-pal.jar"]
