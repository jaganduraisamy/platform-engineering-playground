# Step 6: Kafka + OpenTelemetry Tracing

Trace context propagation from a Java Kafka producer to a Python consumer via Kafka message headers.

## Prerequisites

- Steps 1–5 complete ([../4_observability-grafana-stack/](../4_observability-grafana-stack/), [../5_otel-instrumentation/](../5_otel-instrumentation/))
- Docker running (build/push to `localhost:5001`)

```bash
kubectl -n observability get deploy tempo
kubectl get crd instrumentations.opentelemetry.io
```

## 1. Deploy

```bash
chmod +x deploy-kafka.sh uninstall-kafka.sh scripts/setup-kind-registry.sh
./deploy-kafka.sh
```

## 2. Validate

```bash
kubectl -n otel-kafka-poc get pods
kubectl -n otel-kafka-poc logs deploy/kafka-producer --tail=20
kubectl -n otel-kafka-poc logs deploy/kafka-consumer --tail=20
```

Traces: http://grafana.localhost/ → **Explore** → **Tempo** (look for `producer-service`, `consumer-service`)

## Images: local vs CI

| Path | Registry | How |
| :--- | :--- | :--- |
| **Local Kind** | `localhost:5001` | `./deploy-kafka.sh` (build + push + apply) |
| **CI (GitHub Actions)** | `ghcr.io/<owner>/welcome-webapp` | Step [../8_github-actions/](../8_github-actions/) — workflow in `.github/workflows/` |

CI tags `sha-<gitsha>` (and `latest` on `main`). Those tags are what a later **ArgoCD** lab will pin — not `kubectl` from the workflow.

## Next step

[../7_kustomize-webapp/](../7_kustomize-webapp/) — Kustomize welcome webapp (env overlays), then [../8_github-actions/](../8_github-actions/) for CI

## Cleanup

```bash
./uninstall-kafka.sh
```

Remove local registry container too:

```bash
REMOVE_REGISTRY=true ./uninstall-kafka.sh
```
