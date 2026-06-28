# Step 4: Observability Stack (LGTM)

Metrics, logs, and traces on the Kind cluster. **No OpenTelemetry** — that is step 5.

**Components:** Grafana, Prometheus, Loki, Tempo, Promtail, kube-state-metrics

## Prerequisites

- Steps 1–3 complete ([../1_kind-cluster/](../1_kind-cluster/), [../2_kodekloud-voting-app/](../2_kodekloud-voting-app/), [../3_networking/ingress-nginx/](../3_networking/ingress-nginx/))

```bash
kubectl -n demo-voting-app get pods
```

## 1. Deploy stack

```bash
chmod +x deploy-observability.sh
./deploy-observability.sh
```

Deploys kube-state-metrics, `lgtm-observability-stack.yaml`, and `02-grafana-ingress.yaml`.

## 2. Validate

**Grafana:** http://grafana.localhost/ (`admin` / `admin`)

```bash
kubectl -n observability get pods
```

Loki in Grafana → Explore:

```logql
{namespace="demo-voting-app"}
```

## Next step

[../5_otel-instrumentation/](../5_otel-instrumentation/) — OpenTelemetry operator + auto-instrumentation

## Cleanup

```bash
./uninstall-observability.sh
```
