# Simple Observability Stack (PoC)

This folder contains a lightweight Proof of Concept observability setup for your kind cluster.

It uses one Kubernetes manifest file:
- `lgtm-observability-stack.yaml`

Optional OTel auto-instrumentation setup file:
- `otel-auto-instrumentation.yaml`

The manifest deploys these open source components:
- Grafana
- Prometheus
- Loki
- Tempo
- Promtail

## Prerequisite: Enable kube-state-metrics

Install kube-state-metrics first (required for Kubernetes object metrics like `kube_deployment_*`):

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/service-account.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/cluster-role.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/cluster-role-binding.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/service.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/deployment.yaml
```

If your cluster cannot pull from `registry.k8s.io` due TLS/cert issues, run:

```bash
kubectl -n kube-system set image deploy/kube-state-metrics kube-state-metrics=giantswarm/kube-state-metrics:v2.17.0
```

Wait until ready:

```bash
kubectl -n kube-system rollout status deploy/kube-state-metrics --timeout=240s
```

## Deploy

From this folder:

```bash
kubectl apply -f lgtm-observability-stack.yaml
```

## Enable OTel Operator Auto-Instrumentation

Install the OpenTelemetry Operator (Helm) with the same settings validated in this environment:

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade --install otel-operator open-telemetry/opentelemetry-operator \
  -n observability \
  --create-namespace \
  --set admissionWebhooks.certManager.enabled=false
```

Patch operator manager image if your cluster cannot pull from `ghcr.io`:

```bash
kubectl -n observability set image deploy/otel-operator-opentelemetry-operator \
  manager=otel/opentelemetry-operator:0.153.0
kubectl -n observability rollout status deploy/otel-operator-opentelemetry-operator --timeout=240s
```

Verify operator and CRDs are ready:

```bash
kubectl -n observability get pods
kubectl get crd | grep opentelemetry.io
```

### Challenges Faced and Solutions

1. Helm install failed with missing `cert-manager.io/v1` kinds (`Certificate`, `Issuer`).
	- Cause: chart default expects cert-manager resources.
	- Solution: install with `--set admissionWebhooks.certManager.enabled=false`.
2. Operator pod stuck in `ImagePullBackOff` pulling from `ghcr.io` with x509 unknown authority.
	- Cause: cluster trust/registry restrictions in this environment.
	- Solution: patch operator image to Docker Hub mirror `otel/opentelemetry-operator:0.153.0`.
3. OTel CR apply/dry-run can fail before operator CRDs exist.
	- Cause: CRDs are installed by the operator chart.
	- Solution: ensure operator install completes first, verify CRDs, then apply OTel CRs.

Apply OTel setup (collector + instrumentation CRs):

```bash
kubectl apply -f otel-auto-instrumentation.yaml
```

Enable language-specific injection on demo app deployment pod templates:

```bash
kubectl -n demo-voting-app patch deployment vote --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python":"demo-auto-instrumentation"}}}}}'
kubectl -n demo-voting-app patch deployment result --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"demo-auto-instrumentation"}}}}}'
kubectl -n demo-voting-app patch deployment worker --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-dotnet":"demo-auto-instrumentation"}}}}}'
```

Restart the deployments to trigger mutation/injection:

```bash
kubectl -n demo-voting-app rollout restart deployment vote result worker
```

Verify OTel collector and instrumented pods:

```bash
kubectl -n observability get pods
kubectl -n demo-voting-app get pods
kubectl -n demo-voting-app describe pod <pod-name>
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
kubectl delete -f lgtm-observability-stack.yaml
```
