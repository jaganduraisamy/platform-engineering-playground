package com.example;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Scope;
import java.time.Instant;
import java.util.Properties;
import java.util.UUID;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;

public class ProducerApp {
    public static void main(String[] args) throws Exception {
        String bootstrap = System.getenv().getOrDefault("KAFKA_BOOTSTRAP_SERVERS", "kafka-service:9092");
        String topic = System.getenv().getOrDefault("KAFKA_TOPIC", "telemetry-test");

        Properties props = new Properties();
        props.put("bootstrap.servers", bootstrap);
        props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        props.put("acks", "all");

        Tracer tracer = GlobalOpenTelemetry.getTracer("producer-app");

        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            while (true) {
                String id = UUID.randomUUID().toString();
                String payload = "hello-world id=" + id + " ts=" + Instant.now();

                Span appSpan = tracer.spanBuilder("produce-message-loop").startSpan();
                try (Scope ignored = appSpan.makeCurrent()) {
                    ProducerRecord<String, String> record = new ProducerRecord<>(topic, id, payload);
                    RecordMetadata metadata = producer.send(record).get();
                    System.out.printf("Produced message id=%s to %s-%d@%d%n",
                            id,
                            metadata.topic(),
                            metadata.partition(),
                            metadata.offset());
                } finally {
                    appSpan.end();
                }

                Thread.sleep(2000);
            }
        }
    }
}
