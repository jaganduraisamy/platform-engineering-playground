# OpenTelemetry Kafka Tracing POC

This POC demonstrates distributed trace context propagation from a Java Kafka producer to a Python Kafka consumer through Kafka message headers.

## 1) Build local images

From this folder:

```sh
cd kafka-setup/otel-kafka-tracing

docker build -t otel-kafka-producer:local ./producer-java
docker build -t otel-kafka-consumer:local ./consumer-python
```

If you use kind:

```sh
kind load docker-image otel-kafka-producer:local
kind load docker-image otel-kafka-consumer:local
```

## 2) Deploy infra and apps

```sh
kubectl apply -f manifests/00-otel-collector.yaml
kubectl apply -f manifests/01-kafka-kraft.yaml

kubectl rollout status deployment/otel-collector
kubectl rollout status deployment/kafka

kubectl apply -f manifests/02-producer-deployment.yaml
kubectl apply -f manifests/03-consumer-deployment.yaml

kubectl rollout status deployment/kafka-producer
kubectl rollout status deployment/kafka-consumer
```

## 3) Verify messages and trace context

Producer logs:

```sh
kubectl logs -f deployment/kafka-producer
```

Consumer logs (shows traceparent header value):

```sh
kubectl logs -f deployment/kafka-consumer
```

Collector logs (shows OTLP trace spans):

```sh
kubectl logs -f deployment/otel-collector
```

## 4) Optional open-source Kafka client smoke test (kcat)

Use kcat to manually publish and consume from the same Kafka service:

```sh
kubectl run kcat-producer --rm -it --restart=Never --image=edenhill/kcat:1.7.1 -- \
  -b kafka-service:9092 -t telemetry-test -P
```

Type a few messages and press Ctrl+D.

```sh
kubectl run kcat-consumer --rm -it --restart=Never --image=edenhill/kcat:1.7.1 -- \
  -b kafka-service:9092 -t telemetry-test -C -o beginning
```

## 5) Cleanup

```sh
kubectl delete -f manifests/03-consumer-deployment.yaml
kubectl delete -f manifests/02-producer-deployment.yaml
kubectl delete -f manifests/01-kafka-kraft.yaml
kubectl delete -f manifests/00-otel-collector.yaml
```
