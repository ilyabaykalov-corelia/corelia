# Сборка выбранного сервиса вместе с его Maven-зависимостями.
FROM maven:3.9.11-eclipse-temurin-25 AS build
WORKDIR /workspace
COPY . .
ARG SERVICE
ARG SKIP_TESTS=true
RUN test -n "$SERVICE" \
  && if [ "$SKIP_TESTS" = "true" ]; then mvn -B -ntp -pl "$SERVICE" -am -Dmaven.test.skip=true package; else mvn -B -ntp -pl "$SERVICE" -am package; fi \
  && cp "$SERVICE/target/$SERVICE-0.1.0-exec.jar" /application.jar

FROM eclipse-temurin:25-jre
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
COPY --from=build /application.jar /app/application.jar
COPY scripts/container-health.sh /app/health.sh
# UID совпадает с владельцем локальных bind-mount файлов; задаётся скриптом запуска.
USER 1000:1000
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=70", "-jar", "/app/application.jar"]
