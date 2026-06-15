FROM maven:3.9.8-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml ./
COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /build/target/kafka-producer-1.0.0.jar /app/producer.jar
# Agent JAR is pre-downloaded on the host (avoids SSL proxy issues in Docker build)
COPY opentelemetry-javaagent.jar /app/opentelemetry-javaagent.jar
CMD ["java", "-javaagent:/app/opentelemetry-javaagent.jar", "-jar", "/app/producer.jar"]
