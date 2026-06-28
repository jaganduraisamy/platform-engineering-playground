FROM maven:3.9.8-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml ./
COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /build/target/kafka-producer-1.0.0.jar /app/producer.jar
CMD ["java", "-jar", "/app/producer.jar"]
