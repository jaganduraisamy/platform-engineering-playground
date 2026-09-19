# Step 10: OpenCost (Kubernetes cost analysis)

Install OpenCost and point it at the Prometheus already running from step 4, instead of deploying a second one.

## Why this matters (PE)

| Concern | This step |
| :--- | :--- |
| Cost visibility | Per-namespace/workload $ estimates from requests, not a spreadsheet guess |
| Reuse over duplication | Same Prometheus + kube-state-metrics as step 4 power both observability and cost |
| Trend history | OpenCost's own `/metrics` scraped back into Prometheus so cost isn't just a live snapshot |

## Prerequisites

- Kind cluster: [../1_kind-cluster/](../1_kind-cluster/)
- ingress-nginx: [../3_networking/ingress-nginx/](../3_networking/ingress-nginx/) (exposes `*.localhost` hosts)
- Observability stack: [../4_observability-grafana-stack/](../4_observability-grafana-stack/) — Prometheus (`prometheus.observability.svc.cluster.local:9090`) already scrapes kube-state-metrics, which OpenCost needs for request-based allocation

```bash
kubectl config current-context   # kind-home-k8-cluster
kubectl -n observability get svc prometheus
```

## 1. Install OpenCost

OpenCost dropped its standalone manifest install — as of the current release it's Helm-chart-only (`kubernetes/opencost.yaml` no longer exists upstream, per the chart's own README). Installed the same way step 3 installs ingress-nginx: Helm chart + a values file, not a hand-patched raw manifest.

```bash
chmod +x install-opencost.sh uninstall-opencost.sh
./install-opencost.sh
```

`opencost-values.yaml` points `opencost.prometheus.internal` at the existing `prometheus.observability` Service (port 9090) instead of installing a bundled Prometheus, and enables the chart's built-in ingress (`opencost.ui.ingress`) for `opencost.localhost`.

## 2. Access the UI

Open http://opencost.localhost — no login.

```bash
kubectl -n opencost get pods
kubectl -n opencost get deploy
```

## 3. Validate cost allocation

```bash
kubectl get ns   # confirm which namespaces are actually live before reading the numbers below
curl 'http://opencost.localhost/model/allocation/compute?window=1d&aggregate=namespace'
```

## Known caveats (illustrative numbers, not real spend)

- Step 4's Prometheus now scrapes cAdvisor (`kubernetes-cadvisor` job, added alongside the `opencost` job) so usage-based costing (actual CPU/RAM used) works too, not just request-based allocation off kube-state-metrics.
- Only `welcome-webapp` ([../7_kustomize-webapp/kustomize/base/deployment.yaml](../7_kustomize-webapp/kustomize/base/deployment.yaml)) sets `resources.requests`. The voting-app (step 2) and Kafka stack (step 6) don't — their pods show near-zero / evenly-split cost. Expected, not a bug.
- Kind, no cloud billing API → OpenCost falls back to its baseline on-prem custom pricing defaults. Dollar figures are illustrative only.
- 3-node cluster (1 control-plane + 2 workers, [../1_kind-cluster/kind-config.yaml](../1_kind-cluster/kind-config.yaml)) → real per-node breakdown, not one flat number.

## 4. Grafana dashboard (cost trends over time)

This step edits a step-4 file, not just adds new ones — `../4_observability-grafana-stack/lgtm-observability-stack.yaml` gets:

- A new `opencost` Prometheus scrape job (`opencost.opencost.svc.cluster.local:9003`) — OpenCost's own `/metrics` endpoint, so cost data persists as a time series instead of only living in OpenCost's own live UI.
- A new `network-costs` scrape job (pod role, `opencost` namespace) — picks up the `network-costs` DaemonSet's per-node network cost metrics.
- A new `kubernetes-cadvisor` scrape job (node role, `/metrics/cadvisor`) — feeds OpenCost's usage-based costing with actual CPU/RAM used, not just requests.
- A new `opencost.json` entry in the `grafana-dashboards` ConfigMap — Kubecost/OpenCost's official "Cluster cost & utilization metrics" dashboard ([grafana.com/grafana/dashboards/8670](https://grafana.com/grafana/dashboards/8670), linked from [OpenCost's own exporter docs](https://opencost.io/docs/integrations/opencost-exporter#dashboard-examples)), adapted for file-based provisioning: its `${DS_PROMETHEUS}` / `${VAR_COST*}` placeholders (which normally only resolve through Grafana's manual "Import dashboard" UI flow) are pre-substituted with this stack's `Prometheus` datasource and the dashboard's own default cost constants.

Re-apply step 4, then restart Prometheus — a ConfigMap update alone doesn't make a running Prometheus reload its scrape config (no `--web.enable-lifecycle` flag set), while Grafana's dashboard provisioner picks up the new file on its own within a few seconds:

```bash
cd ../4_observability-grafana-stack && ./deploy-observability.sh
kubectl -n observability rollout restart deploy/prometheus
kubectl -n observability rollout status deploy/prometheus --timeout=120s
```

Open Grafana (http://grafana.localhost/, `admin`/`admin`) → Dashboards → Kubernetes folder → **Cluster cost & utilization metrics**. Confirm Prometheus is scraping OpenCost: Prometheus UI (`kubectl -n observability port-forward svc/prometheus 9090:9090`) → Status → Targets → `opencost` job is `UP`.

## Cleanup

```bash
./uninstall-opencost.sh
```

The step-4 scrape job and dashboard addition are additive-only (new job, new ConfigMap key) — leaving them in `lgtm-observability-stack.yaml` after uninstalling OpenCost is harmless; the scrape target just goes unreachable.

## Next step

None yet — this is the newest lab. See [../docs/platform-engineering-roadmap.md](../docs/platform-engineering-roadmap.md) for what's still on the roadmap.
