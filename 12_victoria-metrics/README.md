# Step 12: VictoriaMetrics (cluster mode, remote_write target)

Adds VictoriaMetrics (VM) as a second, always-on write target for step 4's Prometheus, in **cluster mode with one pod per role** (`vminsert`, `vmstorage`, `vmselect`, `vmalert`) instead of the single-binary `vmsingle`. `vmsingle` runs all of those roles inside one process, which is convenient but hides the very components worth learning. This is the same reason 11_thanos stood up Sidecar/Store Gateway/Compactor/Querier even though step 4 only runs one Prometheus. Also brings up the KodeKloud voting app with OTel auto-instrumentation (step 5) as the trace/spanmetrics source, so real data flows end to end: vote app → OTel Collector → spanmetrics connector → Prometheus scrape → `remote_write` → vminsert → vmstorage ×2 → vmselect. Design notes and how VM's model differs from Prometheus + Thanos: [../docs/victoriametrics-notes.md](../docs/victoriametrics-notes.md).

**Components added:** vminsert, vmstorage (×2 replicas), vmselect, vmalert, all hand-written manifests in [vm-cluster-stack.yaml](vm-cluster-stack.yaml). Plus the demo voting app (redis/db/vote/result/worker), one Grafana datasource (`VictoriaMetrics`, pointing at vmselect) and one ingress, `vm-cluster.localhost` (vmselect + vmalert).

## Why raw manifests, not the `victoria-metrics-cluster` Helm chart

The official chart is the right default for an off-the-shelf tool (same pattern as ingress-nginx/OTel operator/OpenCost in steps 3/5/10). This step uses hand-written manifests because the goal is *seeing every component's args/ports/volumes directly*, for the same reason 11_thanos is a raw manifest instead of a chart: a chart's defaults are correct but invisible.

## Why this matters (PE)

| Concern | This step |
| :--- | :--- |
| Prometheus's remote_write is a standard interface, not a Thanos-only feature | vminsert's `/insert/0/prometheus/api/v1/write` accepts it natively, same Prometheus config change pattern as 11_thanos's Sidecar, no new protocol |
| Separate roles, not a black box | Write path (vminsert), storage (vmstorage), read path (vmselect) and rules (vmalert) are separate pods, so each can be scaled, restarted and broken on its own |
| Full PromQL/MetricsQL compatibility | Grafana's `Prometheus`-type datasource points straight at vmselect, nothing app-side changes to switch backends |
| Cardinality-heavy data (spanmetrics) is a real test | The vote app's traces route through the spanmetrics connector (5_otel-instrumentation/) so VM has to ingest live `traces_span_metrics_calls_total`/`traces_span_metrics_duration_milliseconds_*` series, not just synthetic scrape targets |
| Real HA replication, not just wired-but-unproven | `vminsert --replicationFactor=2` writes every sample to both vmstorage replicas, the HA property 11_thanos's `external_labels.replica` dedup was wired for but never had a second Prometheus to prove |
| Alerting against the global view | vmalert evaluates rules against vmselect (the merged, deduped view), the Thanos Ruler equivalent, not in 11_thanos's scope at all |

## Prerequisites

- Kind cluster: [../1_kind-cluster/](../1_kind-cluster/)
- ingress-nginx: [../3_networking/ingress-nginx/](../3_networking/ingress-nginx/)
- Observability stack: [../4_observability-grafana-stack/](../4_observability-grafana-stack/). This step edits that folder's `lgtm-observability-stack.yaml` directly (same pattern 10_/11_ used), it doesn't fork it
- OTel Collector + Instrumentation CR: [../5_otel-instrumentation/](../5_otel-instrumentation/), must already be applied (`otel-gateway-collector` deployment and `demo-auto-instrumentation` Instrumentation CR)
- Optional: [../11_thanos/](../11_thanos/). VM sits next to the Thanos sidecar, it doesn't replace it

```bash
kubectl config current-context   # kind-home-k8-cluster
kubectl -n observability get deploy/prometheus deploy/grafana deploy/otel-gateway-collector
```

## 1. Deploy

```bash
chmod +x deploy-victoriametrics.sh uninstall-victoriametrics.sh generate-traffic.sh
./deploy-victoriametrics.sh
```

In order: apply `vm-cluster-stack.yaml` → re-apply step 4's file (adds a `remote_write` block to Prometheus and the `VictoriaMetrics` Grafana datasource) → VM cluster ingress → deploy the voting app + patch OTel auto-instrumentation annotations onto `vote`/`result`/`worker` → send synthetic vote traffic → query vmselect to confirm spanmetrics landed.

## 2. What changed in step 4's file, and why

- **One `remote_write` block on Prometheus**, pointing at vminsert (`http://vminsert...:8480/insert/0/prometheus/api/v1/write`). VM implements Prometheus's remote_write protocol natively, no adapter needed. It sits next to the Thanos Sidecar and doesn't change the 10-minute block flags. If VM isn't deployed, Prometheus just logs failed-send retries against an unresolvable name, same tolerance as the Thanos objstore Secret's `optional: true`.
- **One Grafana datasource**, `type: prometheus`, `VictoriaMetrics` (vmselect's `/select/0/prometheus` read path). VM's query API is PromQL/MetricsQL-compatible, so Grafana needs no VM-specific plugin. The `Thanos Query` datasource stays, so the two backends can be compared side by side in Explore.

## 3. Best practices highlighted in this lab

- **remote_write, not a second scrape target**: VM gets exactly what Prometheus scraped, instead of double-scraping every target (which would double the load on `otel-gateway-collector`, `kube-state-metrics`, etc.).
- **StatefulSet + headless Service (`clusterIP: None`)** for vmstorage: vminsert/vmselect address each replica by stable pod DNS (`vmstorage-0.vmstorage`, `vmstorage-1.vmstorage`). VM cluster mode has no DNS-SRV auto-discovery the way Thanos Query's `dnssrv+_grpc._tcp.` does, so a 3rd vmstorage replica means editing vminsert/vmselect's `-storageNode` flags, not just scaling a Service. A real operational gap worth knowing about vs. Thanos.
- **`replicationFactor=2` + `dedup.minScrapeInterval=15s`** ([vm-cluster-stack.yaml](vm-cluster-stack.yaml)): every sample lands on both vmstorage replicas, and vmselect's dedup collapses the resulting duplicates back into one series at query time. `dedup.minScrapeInterval` must match Prometheus's `scrape_interval` or you under/over-merge.
- **`vmalert --notifier.blackhole`**: evaluates recording/alerting rules against vmselect without needing an Alertmanager (not in this repo's scope; one new tool at a time per AGENTS.md). Results are still visible via vmalert's own `/api/v1/rules` API.
- **emptyDir, not a PVC**, on every VM component: the point of this lab is the remote_write/query/alerting wiring, not surviving a pod restart. SeaweedFS in step 11 is the only PVC in the repo.
- **Resource requests/limits set**: VM is memory-sensitive under real cardinality, cheap to get right from the start even in a homelab.
- **Reuse over duplication**: the voting app and its OTel instrumentation aren't reinvented here; this step deploys what 2_/5_ already define and wires their output into a new storage backend.

## 4. Validate

**Cluster UIs/APIs** (`vm-cluster.localhost`):
- vmselect query API: http://vm-cluster.localhost/select/0/prometheus/api/v1/query?query=up
- vmselect UI: http://vm-cluster.localhost/select/0/vmui/
- vmalert rules API: http://vm-cluster.localhost/api/v1/rules
- vmalert UI: http://vm-cluster.localhost/vmalert/

`vminsert` (write-only) and `vmstorage` (internal, no query API) have no ingress. Port-forward if you need them directly: `kubectl -n observability port-forward svc/vminsert 8480:8480` / `kubectl -n observability port-forward vmstorage-0 8482:8482`.

**Vote app:** http://demo-vote.localhost/ (cast votes) → http://demo-vote.localhost/result/ (see results). Every request is a traced span.

```bash
kubectl -n observability get pods -l 'app in (vmstorage,vminsert,vmselect,vmalert)'

# query through the cluster path (vminsert -> vmstorage x2 -> vmselect)
kubectl -n observability exec deploy/vmalert -- wget -qO- \
  "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=traces_span_metrics_calls_total"

# vmalert's recording + alerting rules
kubectl -n observability exec deploy/vmalert -- wget -qO- "http://127.0.0.1:8880/api/v1/rules"

kubectl -n observability logs deploy/prometheus -c prometheus --tail=50 | grep -i remote_write
```

VM hides the newest samples for `-search.latencyOffset` (30s by default), so a query right after a write can come back empty. Wait about 40s and re-query.

**Grafana:** http://grafana.localhost/ (`admin`/`admin`) → Explore → switch datasource to **VictoriaMetrics** (vmselect) → query `traces_span_metrics_calls_total` or `histogram_quantile(0.95, sum(rate(traces_span_metrics_duration_milliseconds_bucket[5m])) by (le))` for spanmetrics-derived p95 latency.

Note: the spanmetrics connector's default metric namespace is `traces.span.metrics` (Prometheus-sanitized to `traces_span_metrics_*`), not the bare `calls_total`/`duration_*` some docs assume. `otel-gateway-collector`'s own `/metrics` endpoint is the ground truth if a metric name ever looks wrong.

## Known caveats (homelab scope, not a production topology)

- `vmalert` runs with `--notifier.blackhole`: no Alertmanager wired, so firing alerts are visible via vmalert's own API/logs but never actually dispatched anywhere.
- No `vmagent`: Prometheus's own `remote_write` is used directly instead of adding a separate scrape/relabel/remote_write agent in front of VM. `vmagent` earns its place when you need one write-fan-out for multiple sources instead of one Prometheus.
- No downsampling/retention-tiering: `--retentionPeriod=7d` is a flat window, matching the Thanos bucket; VM's downsampling (Enterprise) isn't exercised here.
- `vmstorage` runs 2 replicas, not 3+: enough to prove `replicationFactor=2` actually replicates, not a production topology recommendation.
- No liveness/readiness probes on the VM components, matching this repo's existing convention (see 11_thanos/README.md's same note).

## Cleanup

```bash
./uninstall-victoriametrics.sh
```

Removes all VM components (vminsert, vmstorage, vmselect, vmalert) and the ingress. Additive-only like 10_/11_, so it leaves the `remote_write` block and the `VictoriaMetrics` datasource in step 4's file (Prometheus just logs harmless failed sends). See the script's own output for the one-line full-revert.

## Next step

None yet. This is the newest lab. See [../docs/platform-engineering-roadmap.md](../docs/platform-engineering-roadmap.md) for what's still on the roadmap.
