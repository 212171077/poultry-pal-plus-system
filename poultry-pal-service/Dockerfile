# Use a base image with Java installed
FROM eclipse-temurin:21-jdk-jammy

# Set the working directory in the container
WORKDIR /app

# Copy the Spring Boot JAR file to the container
COPY target/poultry-pal-0.0.1-SNAPSHOT.jar poultry-pal.jar

# Expose the port the app runs on
EXPOSE 8090

# Command to run the app
ENTRYPOINT ["java", "-jar", "poultry-pal.jar"]
