# ─── Stage 1: Build ─────────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /workspace

# Copy Gradle wrapper and dependency descriptors first (layer cache)
COPY gradlew .
COPY gradle gradle
COPY build.gradle.kts .
COPY settings.gradle.kts .

# Pre-fetch dependencies
RUN ./gradlew dependencies --no-daemon 2>/dev/null || true

# Copy source and build (skip tests — tested in CI before image build)
COPY src src
COPY config config
RUN ./gradlew bootJar -x test -x checkstyleMain -x pmdMain -x spotbugsMain --no-daemon

# ─── Stage 2: Runtime ───────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine

LABEL org.opencontainers.image.title="spring-boot-app" \
      org.opencontainers.image.description="EKS ARC Runner Platform Spring Boot API" \
      org.opencontainers.image.version="0.0.1" \
      org.opencontainers.image.vendor="eks-arc-runner-platform"

# Non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=builder /workspace/build/libs/*.jar app.jar

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
