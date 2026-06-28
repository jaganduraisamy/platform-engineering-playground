# Step 5: OpenTelemetry Instrumentation

Auto-instrument the demo voting app and export traces to Tempo (from step 4).

## Prerequisites

- LGTM stack running: [../4_observability-grafana-stack/](../4_observability-grafana-stack/)
- Demo app deployed: [../2_kodekloud-voting-app/](../2_kodekloud-voting-app/)

```bash
kubectl -n observability get deploy grafana tempo
kubectl -n demo-voting-app get deploy vote result worker
```

## 1. Deploy OTel operator + collector

```bash
chmod +x deploy-otel.sh uninstall-otel.sh
./deploy-otel.sh
```

Installs:
- OpenTelemetry Operator (Helm, `otel-helm-values.yaml`)
- OTel collector + `Instrumentation` CR (`otel-auto-instrumentation.yaml`)
- Auto-inject on `vote` (python), `result` (nodejs), `worker` (dotnet)

`redis` and `db` have no operator injectors.

## 2. Validate

1. Vote at http://demo-vote.localhost/
2. Open http://grafana.localhost/ → **Explore** → **Tempo**
3. Search for recent traces from `vote`, `result`, or `worker`

```bash
kubectl -n observability get deploy otel-gateway-collector
kubectl -n demo-voting-app get pods
```

## Next step

[../6_kafka-otel-tracing/](../6_kafka-otel-tracing/) — Kafka + trace propagation across messaging

## Cleanup

```bash
./uninstall-otel.sh
```
