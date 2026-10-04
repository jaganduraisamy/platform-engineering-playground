# Step 12: VictoriaMetrics (single-node + cluster mode, remote_write target)

Adds VictoriaMetrics as a second, always-on write target for step 4's Prometheus — both single-node (`vmsingle`) and cluster mode (`vminsert`/`vmstorage`/`vmselect`/`vmalert`), running side by side so every component can actually be seen and queried, the same reason 11_thanos stood up Sidecar/Store Gateway/Compactor/Querier even though step 4 only runs one Prometheus. Brings up the KodeKloud voting app with OTel auto-instrumentation (step 5) as the trace/spanmetrics source, so there's real data flowing end to end: vote app → OTel Collector → spanmetrics connector → Prometheus scrape → dual remote_write → vmsingle + vminsert → vmstorage. Design notes and how VM's model differs from Prometheus + Thanos: [../docs/victoriametrics-notes.md](../docs/victoriametrics-notes.md).

**Components added:** vmsingle, vminsert, vmstorage (×2 replicas), vmselect, vmalert — all hand-written manifests ([vmsingle-stack.yaml](vmsingle-stack.yaml), [vm-cluster-stack.yaml](vm-cluster-stack.yaml)), not a Helm chart (see below for why). Plus the demo voting app (redis/db/vote/result/worker), two Grafana datasources (`VictoriaMetrics`, `VictoriaMetrics Cluster`), and two ingresses: `vm.localhost` (vmsingle) and `vm-cluster.localhost` (vmselect + vmalert).

## Why raw manifests, not the `victoria-metrics-single`/`-cluster` Helm charts

Started this step on the official Helm charts (genuinely the right default for an off-the-shelf tool — same pattern as ingress-nginx/OTel operator/OpenCost in steps 3/5/10). Switched to hand-written manifests once the goal became *seeing every component's args/ports/volumes directly*, for the same reason 11_thanos is a raw manifest instead of a chart: a chart's defaults are correct but invisible. [vmsingle-stack.yaml](vmsingle-stack.yaml) is spec-for-spec what `helm template victoria-metrics/victoria-metrics-single` actually rendered — swapping to it changed nothing at runtime, same image/flags/Service name+port.

## Why this matters (PE)

| Concern | This step |
| :--- | :--- |
| Prometheus's remote_write is a standard interface, not a Thanos-only feature | VM's `/api/v1/write` (vmsingle) and vminsert's `/insert/0/prometheus/api/v1/write` (cluster) both accept it natively — same Prometheus config change pattern as 11_thanos's Sidecar, no new protocol |
| Single binary vs. sidecar-per-Prometheus | VM stores what's written to it directly; no shared TSDB volume, no hard-link trick, no sidecar container in the Prometheus pod |
| Full PromQL/MetricsQL compatibility | Grafana's `Prometheus`-type datasource points straight at VM — nothing app-side changes to switch backends |
| Cardinality-heavy data (spanmetrics) is a real test | The vote app's traces route through the spanmetrics connector (5_otel-instrumentation/) so VM has to ingest live `traces_span_metrics_calls_total`/`traces_span_metrics_duration_milliseconds_*` series, not just synthetic scrape targets |
| Real HA replication, not just wired-but-unproven | `vminsert --replicationFactor=2` actually writes every sample to both vmstorage replicas — the HA property 11_thanos's `external_labels.replica` dedup was wired for but never had a second Prometheus to prove |
| Alerting against the global view | vmalert evaluates rules against vmselect (the merged, deduped view) — the Thanos Ruler equivalent, not in 11_thanos's scope at all |

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

In order: apply `vmsingle-stack.yaml` + `vm-cluster-stack.yaml` → re-apply step 4's file (adds both `remote_write` blocks to Prometheus, adds both `VictoriaMetrics`/`VictoriaMetrics Cluster` Grafana datasources) → VM ingress → deploy the voting app + patch OTel auto-instrumentation annotations onto `vote`/`result`/`worker` → send synthetic vote traffic → query vmsingle *and* vmselect to confirm spanmetrics landed through both paths.

## 2. What changed in step 4's file, and why

- **Two `remote_write` blocks on Prometheus** — one to vmsingle (`http://vmsingle...:8428/api/v1/write`), one to vminsert (`http://vminsert...:8480/insert/0/prometheus/api/v1/write`). Same sample set, written to both backends independently, so single-node and cluster mode can be compared side by side. VM implements Prometheus's remote_write protocol natively on both ingestion paths — no adapter needed. `optional`-style tolerance: if VM isn't deployed, Prometheus just logs failed-send retries against an unresolvable name, same as the Thanos objstore Secret's `optional: true`.
- **Two Grafana datasources**, both `type: prometheus` — `VictoriaMetrics` (vmsingle) and `VictoriaMetrics Cluster` (vmselect's `/select/0/prometheus` read path). VM's query API is PromQL/MetricsQL-compatible either way, so Grafana needs no VM-specific datasource plugin for either mode.

## 3. Best practices highlighted in this lab

- **remote_write, not a second scrape target** — VM gets exactly what Prometheus scraped, once per backend, instead of double-scraping every target (which would double the load on `otel-gateway-collector`, `kube-state-metrics`, etc.).
- **StatefulSet + headless Service (`clusterIP: None`)** for vmsingle and vmstorage — vmstorage specifically needs stable per-pod DNS names (`vmstorage-0.vmstorage`, `vmstorage-1.vmstorage`) because vminsert/vmselect address each replica directly; VM cluster mode has no DNS-SRV auto-discovery the way Thanos Query's `dnssrv+_grpc._tcp.` does, so a 3rd vmstorage replica means editing vminsert/vmselect's `-storageNode` flags, not just scaling a Service — a real operational gap worth knowing about vs. Thanos.
- **`replicationFactor=2` + `dedup.minScrapeInterval=15s`** ([vm-cluster-stack.yaml](vm-cluster-stack.yaml)) — every sample lands on both vmstorage replicas, and vmselect's dedup collapses the resulting duplicates back into one series at query time. `dedup.minScrapeInterval` must match Prometheus's `scrape_interval` or you under/over-merge.
- **`vmalert --notifier.blackhole`** — evaluates recording/alerting rules against vmselect without needing an Alertmanager (not in this repo's scope; one new tool at a time per AGENTS.md). Results are still visible via vmalert's own `/api/v1/rules` API.
- **emptyDir, not a PVC**, on every VM component — matches this repo's convention of ephemeral storage for everything except MinIO (11_thanos/README.md, now removed); the point of this lab is the remote_write/query/alerting wiring, not surviving a pod restart.
- **Resource requests/limits set** — same rationale as 11_thanos: VM is memory-sensitive under real cardinality, cheap to get right from the start even in a homelab.
- **Reuse over duplication** — the voting app and its OTel instrumentation aren't reinvented here; this step just deploys what 2_/5_ already define and wires their output into two new storage backends.

## 4. Validate

**VictoriaUI (vmsingle):** http://vm.localhost/vmui/ → run `traces_span_metrics_calls_total` or `up` and see live series.

**Cluster mode UIs/APIs** (`vm-cluster.localhost`):
- vmselect query API: http://vm-cluster.localhost/select/0/prometheus/api/v1/query?query=up
- vmselect UI: http://vm-cluster.localhost/select/0/vmui/
- vmalert rules API: http://vm-cluster.localhost/api/v1/rules
- vmalert UI: http://vm-cluster.localhost/vmalert/

`vminsert` (write-only) and `vmstorage` (internal, no query API) have no ingress — port-forward if you need them directly: `kubectl -n observability port-forward svc/vminsert 8480:8480` / `kubectl -n observability port-forward vmstorage-0 8482:8482`.

**Vote app:** http://demo-vote.localhost/ (cast votes) → http://demo-vote.localhost/result/ (see results) — every request is a traced span.

```bash
kubectl -n observability get pods -l 'app in (vmsingle,vmstorage,vminsert,vmselect,vmalert)'
curl -H "Host: vm.localhost" "http://127.0.0.1/api/v1/query?query=traces_span_metrics_calls_total"

# same query through the cluster path (vminsert -> vmstorage x2 -> vmselect)
kubectl -n observability exec deploy/vmalert -- wget -qO- \
  "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=traces_span_metrics_calls_total"

# vmalert's recording + alerting rules
kubectl -n observability exec deploy/vmalert -- wget -qO- "http://localhost:8880/api/v1/rules"

kubectl -n observability logs deploy/prometheus -c prometheus --tail=50 | grep -i remote_write
```

**Grafana:** http://grafana.localhost/ (`admin`/`admin`) → Explore → switch datasource to **VictoriaMetrics** (vmsingle) or **VictoriaMetrics Cluster** (vmselect) → query `traces_span_metrics_calls_total` or `histogram_quantile(0.95, sum(rate(traces_span_metrics_duration_milliseconds_bucket[5m])) by (le))` for spanmetrics-derived p95 latency.

Note: the spanmetrics connector's default metric namespace is `traces.span.metrics` (Prometheus-sanitized to `traces_span_metrics_*`), not the bare `calls_total`/`duration_*` some docs assume — `otel-gateway-collector`'s own `/metrics` endpoint is the ground truth if a metric name ever looks wrong.

## Known caveats (homelab scope, not a production topology)

- `vmalert` runs with `--notifier.blackhole` — no Alertmanager wired, so firing alerts are visible via vmalert's own API/logs but never actually dispatched anywhere.
- No `vmagent` — Prometheus's own `remote_write` is used directly instead of adding a separate scrape/relabel/remote_write agent in front of VM. `vmagent` earns its place when you need one write-fan-out for multiple sources instead of one Prometheus.
- No downsampling/retention-tiering configured — `retentionPeriod: 10d` is a flat window; VM's downsampling (Enterprise) or manual multi-instance rollup pattern isn't exercised here.
- `vmstorage` runs 2 replicas, not 3+ — enough to prove `replicationFactor=2` actually replicates, not a production topology recommendation.
- No liveness/readiness probes on the cluster-mode components (vminsert/vmstorage/vmselect/vmalert) — matches this repo's existing convention (see 11_thanos/README.md's same note); vmsingle keeps the probes the Helm chart used to set, since they came for free once written out.

## Cleanup

```bash
./uninstall-victoriametrics.sh
```

Removes all VM components (vmsingle, vminsert, vmstorage, vmselect, vmalert) and the ingress — additive-only like 10_/11_, so it leaves both `remote_write` blocks and both `VictoriaMetrics` datasources in step 4's file (Prometheus just logs harmless failed sends). See the script's own output for the one-line full-revert.

## Next step

None yet — this is the newest lab. See [../docs/platform-engineering-roadmap.md](../docs/platform-engineering-roadmap.md) for what's still on the roadmap.
