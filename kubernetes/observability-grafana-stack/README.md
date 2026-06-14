# Simple Observability Stack (PoC)

This folder contains a lightweight Proof of Concept observability setup for your kind cluster.

It uses one Kubernetes manifest file:
- `simple-observability.yaml`

The manifest deploys these open source components:
- Grafana
- Prometheus
- Loki
- Tempo
- Promtail

## Deploy

From this folder:

```bash
kubectl apply -f simple-observability.yaml
```

## Access

Open Grafana:

```bash
kubectl -n observability port-forward svc/grafana 3000:3000
```

Open Prometheus:

```bash
kubectl -n observability port-forward svc/prometheus 9090:9090
```

URLs:
- http://localhost:3000 (Grafana: `admin` / `admin`)
- http://localhost:9090 (Prometheus UI)

## Quick Checks

Check pods:

```bash
kubectl -n observability get pods
```

Basic Loki query in Grafana Explore:

```logql
{namespace="demo-voting-app"}
```

## Cleanup

```bash
kubectl delete -f simple-observability.yaml
```
