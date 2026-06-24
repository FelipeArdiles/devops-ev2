# Multistage
# Stage 1: compilar JAR
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: ejecutar API como usuario no root
FROM eclipse-temurin:17-jre
WORKDIR /app

RUN groupadd -r appuser && useradd -r -g appuser appuser \
  && apt-get update && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/target/*.jar app.jar
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown -R appuser:appuser /app /entrypoint.sh

USER appuser
EXPOSE 8081
ENTRYPOINT ["/entrypoint.sh"]
