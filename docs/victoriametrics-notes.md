# VictoriaMetrics: what it actually solves and how

Research notes before building [../12_victoria-metrics/](../12_victoria-metrics/). Sources: [VictoriaMetrics docs — Single-server](https://docs.victoriametrics.com/victoriametrics/single-server-victoriametrics/), [VictoriaMetrics docs — Cluster](https://docs.victoriametrics.com/victoriametrics/cluster-victoriametrics/), [MetricsQL](https://docs.victoriametrics.com/victoriametrics/metricsql/), [Storage design](https://docs.victoriametrics.com/victoriametrics/#storage).

Same three Prometheus limits as [thanos-notes.md](thanos-notes.md) — bounded local retention, no cross-instance view, HA means duplicates — but VictoriaMetrics (VM) solves them with a different architecture: it's a standalone TSDB that speaks Prometheus's `remote_write`/PromQL wire protocols, not a set of sidecar processes wrapped around Prometheus itself. Where Thanos re-uses Prometheus's on-disk block format and adds object storage + a query-federation layer, VM replaces the storage engine entirely and lets Prometheus (or any remote_write-capable agent) become a pure scrape-and-forward layer in front of it.

## Where VM and Thanos diverge on the same three problems

| Problem | Thanos's fix | VM's fix |
| :--- | :--- | :--- |
| Retention bounded by local disk | Sidecar ships Prometheus's own sealed 2h blocks, unmodified, to S3-compatible object storage; Store Gateway serves them back | Prometheus `remote_write`s samples directly into VM's own storage engine, which is built for long retention on local/network disk from the start — no object-storage tier required at homelab scale |
| No cross-instance view | Thanos Query fans out over gRPC StoreAPI to every Sidecar/Store Gateway and merges | VM Cluster's `vmselect` fans out over its own RPC to every `vmstorage` node and merges; single-node VM has nothing to fan out to (there's only one store) |
| HA means duplicate, not resilient, data | `external_labels.replica` + `--query.replica-label` dedup at query time in Thanos Query | Same idea, `-dedup.minScrapeInterval` + duplicate `remote_write` streams from two Prometheus replicas — VM does the corresponding dedup at ingest, not query, time |

**The core structural difference:** Thanos is additive around Prometheus — Prometheus keeps being the source of truth for recent data, Thanos only extends what happens to sealed blocks. VM is a replacement storage backend — Prometheus becomes disposable (short local retention, or none) because every sample already lives in VM the moment it's scraped, via the standard `remote_write` protocol every Prometheus-compatible agent already speaks. Neither is "correct" in the abstract: Thanos preserves 100% Prometheus-native operations (PromQL functions, recording rules, alerting all still run against local Prometheus) while adding global query/long-term storage as a layer; VM asks you to trust a different storage/query engine for the parts of PromQL it reimplements (MetricsQL, mostly superset-compatible, see below) in exchange for a much simpler operational footprint — one binary, no object storage dependency, no sidecar-per-Prometheus.

## What VM actually is

A single Go binary (`victoria-metrics`) that is simultaneously: a `remote_write` receiver, a time-series database, and a PromQL-compatible query API — no separate ingester/store/querier processes needed at single-node scale. The cluster variant (`victoria-metrics-cluster`, not used in this lab) splits that binary into three roles that scale independently:

- **`vminsert`** — stateless, receives `remote_write`, shards samples across `vmstorage` nodes by series hash
- **`vmstorage`** — stateful, owns a shard of the data, no cross-talk between storage nodes
- **`vmselect`** — stateless, fans a query out to every relevant `vmstorage`, merges results

This lab uses `victoria-metrics-single` — the single-binary form — since the data volume (one homelab Prometheus + spanmetrics from one demo app) never approaches the point clustering pays for itself.

## Storage engine: why VM claims better compression and lower RAM than Prometheus's own TSDB

Prometheus's TSDB (see [thanos-notes.md](thanos-notes.md#internals-the-2h-block-and-ingest-pipeline)) is optimized for one process holding ~15-30 days locally: a 2h-block, Gorilla-compressed-chunks design, ~1-3KB RAM per active series held in the head.

VM's storage engine is a custom LSM-tree-like structure (VictoriaMetrics calls it `MergeSet`), purpose-built for years-scale retention on disk with far lower per-series overhead:

- **Columnar storage of labels** — label names/values are stored and compressed separately from the raw sample stream, deduplicated across series, so repeated label sets (the common case — most series share `cluster`, `namespace`, `job`, etc.) don't each pay full storage cost.
- **Delta + dictionary encoding tuned for metric data**, not a generic compressor — VM's published benchmarks show meaningfully smaller on-disk footprint than Prometheus's own TSDB at equivalent retention, though exact ratios are workload-dependent (label cardinality, value entropy) and worth verifying against your own data before treating any specific multiplier as a guarantee.
- **No fixed 2h block boundary** — VM's merge/compaction cadence is driven by its own LSM-style background merging, not Prometheus's crash-recovery-driven block-cut design, so there's no equivalent to Prometheus's "head block held in RAM until the next 2h cut."

Net effect for this lab's cardinality-heavy spanmetrics data (`traces_span_metrics_calls_total`/`duration_*`, one series per unique `span_name`×`http_method`×`http_status_code`×pod-instance combination): VM absorbs churny, high-cardinality series without the same head-block RAM pressure Prometheus's own TSDB would show under the same load (see [thanos-notes.md](thanos-notes.md#cardinality-explosion) for why churn is the actual driver of that pressure in Prometheus).

## MetricsQL: PromQL-compatible, not PromQL-identical

VM's query language is a superset of PromQL — every PromQL query this repo's Grafana dashboards already use (`rate()`, `histogram_quantile()`, `sum by (...)`) runs unmodified against VM, which is exactly why swapping Grafana's datasource type stays `prometheus` (see [12_victoria-metrics/README.md](../12_victoria-metrics/README.md)). MetricsQL adds VM-specific extensions on top — `rollup_rate()`, `sum_over_time()`, and several vector-matching relaxations documented at the [MetricsQL reference](https://docs.victoriametrics.com/victoriametrics/metricsql/) — none of which this lab depends on, since the whole point is proving the vanilla-PromQL query path (spanmetrics → `histogram_quantile` p95, per [12_victoria-metrics/README.md](../12_victoria-metrics/README.md#4-validate)) works identically against either backend.

## Ingestion path: `remote_write` as the actual interface, not a Thanos-only concept

`remote_write`/`remote_read` are Prometheus's own standard export APIs (see [thanos-notes.md](thanos-notes.md#native-long-term-storage-story)) — Prometheus's docs are explicit that whatever's on the receiving end does the actual long-term storing, and name Thanos Receiver, Cortex, Mimir, and VictoriaMetrics as equally valid receivers. This lab exercises that exact seam: [12_victoria-metrics/](../12_victoria-metrics/) adds one `remote_write` block to step 4's existing Prometheus config, pointed at VM's `/api/v1/write`, and nothing else about Prometheus's scrape config or Thanos Sidecar changes. VM implements that receiver endpoint natively — no adapter, no protocol translation layer — which is the whole reason this integration is a five-line config diff instead of a new component.

## Mapping to this repo's existing stack

| Existing component | Interaction with VM |
| :--- | :--- |
| Step 4 Prometheus | Gains a `remote_write` target; keeps scraping and keeps its own (short-retention, tmpfs-backed) local TSDB exactly as before — VM is additive, not a replacement, in this lab's wiring |
| Step 4 Grafana | Gains a `VictoriaMetrics` datasource, `type: prometheus` — same PromQL panels work against either datasource, proving query-layer compatibility |
| Step 5 OTel Collector + spanmetrics connector | Unmodified — already exposes `traces_span_metrics_calls_total`/`duration_*` on its `:9464` Prometheus exporter; Prometheus's existing `otel-collector` scrape job is what actually feeds VM, via the new remote_write hop |
| Step 11 Thanos Sidecar | Runs in parallel, untouched — same Prometheus pod ships blocks to MinIO (object storage, sealed blocks) *and* streams live samples to VM (remote_write, all samples) at the same time. Two independent long-term-storage strategies coexisting on one Prometheus, which is itself a demonstration of `remote_write`'s decoupling: neither consumer knows or cares that the other exists |

## Known caveats (of the comparison itself, not just this lab)

- VM's compression/RAM advantages over Prometheus's TSDB are real and documented, but the magnitude is workload-dependent; this lab's traffic volume (a few hundred synthetic votes) is too small to observe the difference meaningfully — the point here is proving the wiring, not benchmarking storage efficiency.
- MetricsQL's PromQL superset status means the common path (this lab's queries) is safe, but a query using very obscure PromQL edge-case semantics is the kind of thing worth testing before treating "MetricsQL is PromQL" as absolute.
- This doc compares VM single-node vs. Prometheus+Thanos as deployed in this repo — it does not cover VM Cluster's own operational tradeoffs (shard rebalancing, `vmstorage` node loss behavior), since [12_victoria-metrics/](../12_victoria-metrics/) doesn't deploy the cluster variant.
