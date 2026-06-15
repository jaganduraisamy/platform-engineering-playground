import os
import time
from kafka import KafkaConsumer


def decode_header(headers, key):
    for header_key, header_val in headers or []:
        if header_key == key:
            if isinstance(header_val, bytes):
                return header_val.decode("utf-8", errors="replace")
            return str(header_val)
    return "<missing>"


def main():
    bootstrap = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka-service:9092")
    topic = os.getenv("KAFKA_TOPIC", "telemetry-test")

    print(f"Connecting to Kafka at {bootstrap}, topic={topic}")

    while True:
        try:
            consumer = KafkaConsumer(
                topic,
                bootstrap_servers=bootstrap,
                group_id="telemetry-consumer-group",
                auto_offset_reset="earliest",
                enable_auto_commit=True,
                value_deserializer=lambda v: v.decode("utf-8", errors="replace"),
            )

            print("Consumer connected. Waiting for messages...")
            for msg in consumer:
                traceparent = decode_header(msg.headers, "traceparent")
                print(
                    "Consumed",
                    f"partition={msg.partition}",
                    f"offset={msg.offset}",
                    f"key={msg.key.decode('utf-8', errors='replace') if msg.key else None}",
                    f"value={msg.value}",
                    f"traceparent={traceparent}",
                )
        except Exception as exc:
            print(f"Consumer connection/read failed: {exc}. Retrying in 3s...")
            time.sleep(3)


if __name__ == "__main__":
    main()
