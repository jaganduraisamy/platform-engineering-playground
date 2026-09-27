# Step 12: VictoriaMetrics (single-node metrics TSDB, remote_write target)

Adds VictoriaMetrics as a second, always-on write target for step 4's Prometheus, and brings up the KodeKloud voting app with OTel auto-instrumentation (step 5) as the trace/spanmetrics source, so there's real data flowing end to end: vote app → OTel Collector → spanmetrics connector → Prometheus scrape → remote_write → VictoriaMetrics storage. Design notes and how VM's model differs from Prometheus + Thanos: [../docs/victoriametrics-notes.md](../docs/victoriametrics-notes.md).

**Components added:** VictoriaMetrics single-node (Helm chart `victoria-metrics-single`), demo voting app (redis/db/vote/result/worker), Grafana `VictoriaMetrics` datasource, `vm.localhost` ingress.

## Why this matters (PE)

| Concern | This step |
| :--- | :--- |
| Prometheus's remote_write is a standard interface, not a Thanos-only feature | VM's `/api/v1/write` accepts it natively — same Prometheus config change pattern as 11_thanos's Sidecar, no new protocol |
| Single binary vs. sidecar-per-Prometheus | VM stores what's written to it directly; no shared TSDB volume, no hard-link trick, no sidecar container in the Prometheus pod |
| Full PromQL/MetricsQL compatibility | Grafana's `Prometheus`-type datasource points straight at VM — nothing app-side changes to switch backends |
| Cardinality-heavy data (spanmetrics) is a real test | The vote app's traces route through the spanmetrics connector (5_otel-instrumentation/) so VM has to ingest live `traces_span_metrics_calls_total`/`traces_span_metrics_duration_milliseconds_*` series, not just synthetic scrape targets |

## Prerequisites

- Kind cluster: [../1_kind-cluster/](../1_kind-cluster/)
- ingress-nginx: [../3_networking/ingress-nginx/](../3_networking/ingress-nginx/)
- Observability stack: [../4_observability-grafana-stack/](../4_observability-grafana-stack/) — this step edits that folder's `lgtm-observability-stack.yaml` directly (same pattern 10_/11_ used), it doesn't fork it
- OTel Collector + Instrumentation CR: [../5_otel-instrumentation/](../5_otel-instrumentation/) — must already be applied (`otel-gateway-collector` deployment and `demo-auto-instrumentation` Instrumentation CR)

```bash
kubectl config current-context   # kind-home-k8-cluster
kubectl -n observability get deploy/prometheus deploy/grafana deploy/otel-gateway-collector
```

## 1. Deploy

```bash
chmod +x deploy-victoriametrics.sh uninstall-victoriametrics.sh generate-traffic.sh
./deploy-victoriametrics.sh
```

In order: Helm install VictoriaMetrics → re-apply step 4's file (adds `remote_write` to Prometheus, adds the `VictoriaMetrics` Grafana datasource) → VM ingress → deploy the voting app + patch OTel auto-instrumentation annotations onto `vote`/`result`/`worker` → send synthetic vote traffic → query VM directly for `calls_total` to confirm spanmetrics landed.

## 2. What changed in step 4's file, and why

- **`remote_write` block on Prometheus**, pointed at `http://vmsingle.observability.svc.cluster.local:8428/api/v1/write` — VM implements Prometheus's remote_write protocol natively, no adapter needed. `optional`-style tolerance: if VM isn't deployed, Prometheus just logs failed-send retries against an unresolvable name, same as the Thanos objstore Secret's `optional: true`.
- **`VictoriaMetrics` Grafana datasource**, `type: prometheus` — VM's query API is PromQL/MetricsQL-compatible, so Grafana needs no VM-specific datasource plugin.

## 3. Best practices highlighted in this lab

- **remote_write, not a second scrape target** — VM gets exactly what Prometheus scraped, once, instead of double-scraping every target (which would double the load on `otel-gateway-collector`, `kube-state-metrics`, etc.).
- **Headless Service (`clusterIP: None`)** is what the Helm chart deploys for a single-replica StatefulSet — fine here since there's one VM pod; a clustered setup (`victoria-metrics-cluster` chart) would front vminsert/vmselect with real Services instead.
- **`server.persistentVolume.enabled: false`** ([vm-helm-values.yaml](vm-helm-values.yaml)) — matches this repo's convention of ephemeral storage for every LGTM component except MinIO (11_thanos/README.md); the point of this lab is the remote_write/query wiring, not surviving a pod restart.
- **Resource requests/limits set** — same rationale as 11_thanos: VM is memory-sensitive under real cardinality, cheap to get right from the start even in a homelab.
- **Reuse over duplication** — the voting app and its OTel instrumentation aren't reinvented here; this step just deploys what 2_/5_ already define and wires their output into a new storage backend.

## 4. Validate

**VictoriaUI:** http://vm.localhost/vmui/ → run `traces_span_metrics_calls_total` or `up` and see live series.

**Vote app:** http://demo-vote.localhost/ (cast votes) → http://demo-vote.localhost/result/ (see results) — every request is a traced span.

```bash
kubectl -n observability get pods -l app.kubernetes.io/name=victoria-metrics-single
curl -H "Host: vm.localhost" "http://127.0.0.1/api/v1/query?query=traces_span_metrics_calls_total"
kubectl -n observability logs deploy/prometheus -c prometheus --tail=50 | grep -i remote_write
```

**Grafana:** http://grafana.localhost/ (`admin`/`admin`) → Explore → switch datasource to **VictoriaMetrics** → query `traces_span_metrics_calls_total` or `histogram_quantile(0.95, sum(rate(traces_span_metrics_duration_milliseconds_bucket[5m])) by (le))` for spanmetrics-derived p95 latency.

Note: the spanmetrics connector's default metric namespace is `traces.span.metrics` (Prometheus-sanitized to `traces_span_metrics_*`), not the bare `calls_total`/`duration_*` some docs assume — `otel-gateway-collector`'s own `/metrics` endpoint is the ground truth if a metric name ever looks wrong.

## Known caveats (homelab scope, not a production topology)

- Single VM instance, no cluster (`vminsert`/`vmstorage`/`vmselect` split) — the `victoria-metrics-cluster` chart is the horizontally-scalable variant; not needed at this data volume.
- No `vmagent` — Prometheus's own `remote_write` is used directly instead of adding a separate scrape/relabel/remote_write agent in front of VM. `vmagent` earns its place when you need one write-fan-out for multiple sources instead of one Prometheus.
- No downsampling/retention-tiering configured — `retentionPeriod: 10d` is a flat window; VM's downsampling (Enterprise) or manual multi-instance rollup pattern isn't exercised here.
- No liveness/readiness probes wired past the chart's own defaults — matches this repo's existing convention (see 11_thanos/README.md's same note).

## Cleanup

```bash
./uninstall-victoriametrics.sh
```

Removes the VM Helm release and ingress — additive-only like 10_/11_, so it leaves the `remote_write` block and the `VictoriaMetrics` datasource in step 4's file (Prometheus just logs harmless failed sends). See the script's own output for the one-line full-revert.

## Next step

None yet — this is the newest lab. See [../docs/platform-engineering-roadmap.md](../docs/platform-engineering-roadmap.md) for what's still on the roadmap.
