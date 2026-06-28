package com.example;

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

        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            while (true) {
                String id = UUID.randomUUID().toString();
                String payload = "hello-world id=" + id + " ts=" + Instant.now();

                ProducerRecord<String, String> record = new ProducerRecord<>(topic, id, payload);
                RecordMetadata metadata = producer.send(record).get();
                System.out.printf("Produced message id=%s to %s-%d@%d%n",
                        id,
                        metadata.topic(),
                        metadata.partition(),
                        metadata.offset());

                Thread.sleep(2000);
            }
        }
    }
}
