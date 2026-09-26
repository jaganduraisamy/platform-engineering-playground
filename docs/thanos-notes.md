# Thanos: what it actually solves and how

Research notes before building the lab. Sources: [Thanos design doc](https://github.com/thanos-io/thanos/blob/main/docs/design.md), [thanos.io design page](https://thanos.io/tip/thanos/design.md/), [thanos.io quick tutorial](https://thanos.io/tip/thanos/quick-tutorial.md/).

## The problem with vanilla Prometheus

Prometheus is a single-binary, single-node TSDB that scrapes and stores locally on disk. Three limits fall directly out of that design:

1. **Retention is bounded by local disk.** Prometheus's own docs size this: at a 15s scrape interval, ~1M active series, you get ~48.88 years of retention per 100TB of local disk before you even think about replicas. In practice teams run 15-30 days locally because disk is expensive and Prometheus's local TSDB isn't built to be a long-term store.
2. **No cross-instance view.** Each Prometheus server only knows its own data. Run one per cluster/region (the normal scaling pattern, since Prometheus doesn't federate well) and there's no single query that spans all of them — no "sum this metric across every cluster" without a separate federation layer.
3. **HA means duplicate, not resilient, data.** The standard Prometheus HA pattern is running two identical scrapers side by side. That gives you availability if one dies, but a naive query across both double-counts everything — there's no built-in dedup.

Thanos's stated goal is narrow on purpose: solve these three without touching Prometheus's reliability model or asking it to do anything it's not built for. It doesn't replace Prometheus — it's a set of extra processes wired around it.

## Prometheus challenges, in technical terms

### Internals: the 2h block and ingest pipeline
Prometheus's local TSDB writes data in fixed 2h windows. Each sealed block is a directory:

```
01HXYZ.../
├── meta.json      — min/max timestamp, sample/series counts, compaction level, external_labels
├── index          — inverted index: label pairs → series, series → chunk offsets
├── tombstones     — deletion markers (lazy delete, reclaimed on next compaction)
└── chunks/        — compressed (ts, value) pairs, Gorilla-style compression, immutable once sealed
```

2h is a fixed design constant, not meant to be tuned — it balances head memory size and WAL replay time against block-file overhead. A bigger block duration would mean a bigger head held longer: slower crash recovery, bigger data-loss blast radius, and (with Thanos in the picture) a longer delay before Sidecar can upload it.

Ingest pipeline, per Prometheus process: scrape target → parse sample → Appender, which writes to two places at once — the **head block** (in-memory, mutable, the live ~2h window that all queries actually read) and the **WAL** (on-disk, durability backstop only). The WAL is never the query path; it exists purely so a crash can rebuild the head by replay. Every 2h, the head compacts into a new immutable on-disk block, and blocks accumulate locally until the retention limit (default 15d) evicts the oldest.

### Cardinality explosion
A time series = metric name + full label set (e.g. `http_requests_total{pod="foo-7f9d",method="GET"}`). Every unique label combination is a distinct series with its own chunk stream. High-cardinality labels (`pod`, `session_id`, `user_id`, `request_id`) multiply series count combinatorially.

- **Head block cost is per-series, not per-sample.** Prometheus's own sizing puts memory overhead at roughly 1-3KB per series regardless of sample count — 1M series is 1-3GB before any sample data. So the failure mode is cumulative series count tracked per window, not true concurrent metric count.
- **Churn is what actually inflates that count.** Churn = the rate at which label values get replaced. Autoscaling/CI namespaces recycle pods every few minutes; each new pod name is a brand-new series. The old series doesn't free immediately — it sits stale in the head until the 2h block cut and compaction run. Constant churn inside a fixed window means the head only grows.
- **WAL replay scales with head size.** On crash or restart, Prometheus must replay the WAL to rebuild the in-memory head before serving anything. A bigger head (more series, more churn) means longer replay, i.e. longer downtime — worst exactly when the instance was already under load.
- **Query cost is single-node.** No distributed query engine — a PromQL range query over high-cardinality/long-range data is one process iterating and merging series, competing with ingestion for the same CPU/RAM.

### Native mitigations, and why they're limits not fixes
Prometheus ships guardrails, not scaling:
- `sample_limit` (scrape config) — reject a whole scrape if it returns more samples than N
- `label_limit`, `label_name_length_limit`, `label_value_length_limit` — reject a scrape exceeding label count/size thresholds
- `relabel_configs` (`drop`/`keep`) — drop high-cardinality labels or whole targets before ingestion
- `metric_relabel_configs` — same, applied post-scrape, pre-storage
- Recording rules — precompute expensive/high-cardinality queries into smaller aggregated series, so dashboards hit the cheap precomputed series instead of raw ones
- TSDB compaction — merges 2h blocks into larger ones, garbage-collects tombstoned series, shrinks index/disk footprint over time — helps disk, does nothing for head-block memory pressure while data is still active

Every one of these is opt-in, configured per scrape job, after you've already found out you needed it.

### Native long-term storage story
- `--storage.tsdb.retention.time` (default 15d) and `--storage.tsdb.retention.size` are the only native retention controls — time or disk-size bounded deletion. No tiering, no object storage, no downsampling.
- `remote_write` / `remote_read` is the only long-term hook Prometheus ships — it forwards samples to an external system as they're scraped. It's an export API, not a storage solution; whatever's on the receiving end (Thanos Receiver, Cortex, Mimir, VictoriaMetrics) does the actual long-term storing.
- This is scoping, not an oversight — Prometheus's own docs state clustering, HA storage, and long-term storage are explicitly out of scope. It's built to be a reliable single-node local monitor.

### Sharding: the manual scale-out Prometheus does support
Sharding = splitting one dataset/workload across multiple independent nodes so no single node holds it all. A single Prometheus process is always exactly one shard — there's no internal sharding concept inside one pod. Prometheus supports scale-out only manually, two ways:

- **Functional sharding** — split by job/type: one Prometheus instance's scrape config has only the `node_exporter` job, another has only `pod_monitor`/`kube-state-metrics`. Simple, hand-configured. Doesn't fix cardinality *within* a job — if `pod_monitor` alone is high-cardinality, that shard alone still OOMs.
- **Hash sharding** — split the *same* job across N shards via `hashmod` relabeling on `__address__`:
  ```yaml
  relabel_configs:
    - source_labels: [__address__]
      modulus: 3
      target_label: __tmp_hash
      action: hashmod
    - source_labels: [__tmp_hash]
      regex: "0"          # this instance's shard number
      action: keep
  ```
  `modulus` = number of shards; the hash is deterministic, so a given target always lands on the same shard. `__tmp_hash` never gets stored — the leading `__` strips it before ingestion. This balances load within one noisy job. Cost: querying "all pods" now needs an external merge layer across shards — no single shard has the full picture.

**Why just adding more Prometheus pods doesn't help on its own:** there's no coordinator and no shared state between replicas. Extra pods running identical scrape config just duplicate the same scrape — that's HA (availability), not scale. Actual horizontal scaling requires the manual hashmod split above, and once split, a query spanning shards needs an external merge layer — which is exactly the gap Thanos Querier fills.

### Prometheus concept → Thanos component mapping

| Prometheus-side concept | Thanos component that touches it |
|---|---|
| Sealed 2h block on local disk | Sidecar watches for it, uploads as-is to object storage — no format conversion, same index/chunks/meta.json |
| Live head block (not yet a block) | Sidecar also exposes this over StoreAPI, so unshipped data is still globally queryable |
| Uploaded blocks sitting in bucket | Store Gateway reads the index for lookup, streams `chunks/` on demand — never holds full data locally |
| Many small blocks in bucket | Compactor (singleton) merges into fewer/larger blocks, applies retention via tombstones, produces 5m/1h downsampled copies |
| WAL / `remote_write` queue | Receiver is the alternate path — ingests `remote_write` streams directly instead of waiting for Sidecar's block-cut cycle |
| Query needing both live + historical | Querier fans out to Sidecars (live) + Store Gateways (historical) via StoreAPI, merges, dedups on the replica label |

### Operational signals and gotchas
- `sample_limit` / `target_limit` (per scrape job config) — the actual guardrail against a cardinality bomb; without it, nothing stops a bad exporter from creating unbounded series.
- `prometheus_tsdb_head_series`, `prometheus_tsdb_wal_*` — Prometheus's own health metrics for this; watch them to catch cardinality growth before OOM, not after.
- Retention is size- **or** time-bound, whichever hits first (`--storage.tsdb.retention.time`, `--storage.tsdb.retention.size`) — easy to assume time-only and get surprised by early eviction under high volume.
- Out-of-order sample ingestion (native OOO window in newer Prometheus versions) — relevant if exporters or `remote_write` sources have clock skew.
- `relabel_configs` (target-level, pre-scrape, can skip scraping a target entirely) vs `metric_relabel_configs` (per-metric, post-scrape) — the latter is the actual place to drop a high-cardinality label before it hits storage.

## The core idea: reuse Prometheus's own storage format

This is the trick that makes the rest of it simple. Prometheus 2.x's on-disk TSDB writes immutable 2-hour blocks (index + chunk files) to disk. Thanos doesn't invent a new storage format — it takes those same blocks and ships them as-is to object storage (S3/GCS/Azure Blob/etc). Object storage becomes the unlimited, cheap, durable tier; local disk stays a thin, short-retention buffer in front of it.

Because every component speaks the same block format, and because every component exposes/consumes a common **StoreAPI** (a gRPC service — "give me these series for this time range and label matchers"), the query layer doesn't care whether the data it's reading is live off a Prometheus, cached on a Store Gateway's disk, or downsampled by the Compactor. It's all just StoreAPI endpoints to fan a query out to.

## Components, and which problem each one solves

- **Sidecar** — runs next to each Prometheus. Two jobs: (a) watches for new 2h TSDB blocks and uploads them to object storage, (b) exposes Prometheus's own recent/local data over StoreAPI so live (not-yet-uploaded) data is still queryable globally. This is what lets you drop Prometheus's local retention down to just a few hours — Sidecar is shipping everything out continuously.
- **Store Gateway** — the read side of object storage. Implements StoreAPI backed by whatever blocks are sitting in the bucket. It doesn't hold the data — it caches block *index* metadata locally (a few GB at most) so it can translate a query into the minimum number of object-storage range requests, then streams chunks back. This is what makes "query 2 years of history" not mean "download 2 years of data first."
- **Compactor** — a singleton, offline batch job against the bucket (not part of the query path). Three jobs: (a) merges many small 2h blocks into larger ones, which both shrinks total bucket size and cuts the number of object-storage requests a query needs; (b) **downsampling** — produces 5m and 1h resolution copies of older data; (c) applies retention/deletion policy on the bucket. It's a singleton because block compaction has to be serialized — two compactors racing on the same blocks would corrupt them.
- **Querier (Query)** — implements Prometheus's own HTTP/PromQL API, but fans each query out to every StoreAPI endpoint it knows about (sidecars for live data, store gateways for historical, receivers, rulers), merges the results, and returns one answer. This is the actual "global view" — from the outside it looks like one big Prometheus.
- **Query Frontend** — sits in front of Querier, not a StoreAPI implementor itself. Splits big queries (e.g. a 30-day range query) into daily chunks it can cache and parallelize, so a re-run of an expensive dashboard query is mostly cache hits.
- **Ruler** — evaluates recording/alerting rules, but against the Querier's *global* view instead of a single Prometheus's local data. Needed when a rule has to see data across clusters, or reach further back than any single Prometheus retains.
- **Receiver** — the alternative ingestion path. Instead of Sidecar pulling from a Prometheus that scrapes, Receiver accepts Prometheus's `remote_write` protocol directly, holds a local TSDB, and uploads blocks the same way Sidecar does. Used to scale out ingestion horizontally or to accept metrics from anything that speaks remote-write (not just Prometheus).

## Deduplication: how the double-counted HA problem actually gets fixed

Not a dedup *algorithm* running over stored data — it's done at query time in the Querier, using labels. Each Prometheus replica in an HA pair is configured with an `external_labels` block that includes a `replica` label with a distinct value (e.g. `replica: A` / `replica: B`), while every other label is identical across the pair. The Querier is told `--query.replica-label=replica`; when merging series from multiple StoreAPI sources, it treats series that are identical except for that one label as the same logical series and merges their samples (penalty-based merge — picks whichever replica has data for a given point, prefers the one with less staleness). The result: query either replica, or both, and you get one continuous series instead of two overlapping ones.

## Downsampling: why it exists

A dashboard rendering a 1-year range at 15s raw resolution would need to pull and plot ~2.1M points per series — wasted work, since a browser can't render that many pixels anyway and nobody needs 15s precision at that zoom level. The Compactor precomputes 5m and 1h resolution rollups (storing min/max/sum/count/counter-reset info per bucket, not just averages, so rate() and max_over_time() etc. still work correctly on downsampled data). The Querier automatically picks the coarsest resolution that's still accurate enough for the requested time range, so long-range queries hit a dataset orders of magnitude smaller instead of raw resolution.

## Cost model (from the design doc's own numbers)

The only Thanos-specific costs on top of a plain Prometheus setup are: object storage ($ per GB, ~$0.02/GB typical) plus retrieval requests (~$0.004/10k requests) plus running the Store/Compactor/Querier/Ruler processes. Everything else (network egress between Sidecar and bucket) is assumed to happen inside the same cloud/region and untaxed. Compute for Querier/Compactor/Ruler roughly nets out against what you'd otherwise spend running the same workload directly against Prometheus.

## Mapping to this repo's existing stack

We already run [step 4's observability stack](../4_observability-grafana-stack/) with a single Prometheus, no HA pair, and no object storage. A Thanos lab here would realistically demonstrate:
- Sidecar + a local object-storage stand-in (MinIO) instead of a real cloud bucket
- Store Gateway serving historical blocks back out of MinIO
- Querier as the new query entrypoint in front of Grafana (swap Grafana's datasource from `prometheus:9090` to `thanos-query:9090`)
- Compactor doing downsampling, to actually see 5m/1h resolution blocks appear in the bucket

HA dedup and Receiver-based ingestion aren't really demonstrable with this repo's single-Prometheus setup without adding a second Prometheus deployment first — worth flagging as scope decisions when the lab gets built.

## Built: [11_thanos/](../11_thanos/)

The lab above is implemented, not just planned. Sidecar patched into step 4's Prometheus pod, MinIO standing in for object storage, Store Gateway, Compactor, Querier, Grafana repointed at a new `Thanos Query` datasource. Full component breakdown and best-practices callouts (Secret vs ConfigMap for objstore creds, Compactor's forced-singleton `strategy: Recreate`, MinIO as the one PVC-backed piece in this repo) are in [11_thanos/README.md](../11_thanos/README.md), not duplicated here.

### Verified: the live-query path works end to end

Queried Thanos Query's PromQL API directly for `up` and for a real cAdvisor metric (`sum by (instance) (rate(container_cpu_usage_seconds_total[5m]))`). Both returned real per-node numbers for all 3 Kind nodes, and every series carried `cluster: home-lab` — a label only the Sidecar's StoreAPI layer attaches, proving the response actually routed Prometheus → Sidecar → Querier, not a direct Prometheus hit. This confirms the theoretical "Querier fans out to Sidecar for live data" claim above against a real running system, independent of whether any block has reached object storage yet.

### Found in production, not in the docs: hard-link uploads fail on fuse-overlayfs

The bucket stayed empty days after deploy — not a timing issue, a real bug. Thanos Sidecar's shipper uploads a sealed block by **hard-linking** its chunk files from `/prometheus/<block>/` into a local staging path, not by copying bytes — an optimization that assumes both paths sit on the same real filesystem. On this Kind-on-Docker-Desktop setup, `prometheus-data` was a plain `emptyDir`, and the node's storage driver (fuse-overlayfs) rejects hard links with `EPERM`. Sidecar logged the identical failure every 30s for over three days, silently stuck on the same block, never surfacing as a crash or a readiness-probe failure — it stayed "healthy" the whole time.

Fix: back that volume with tmpfs instead of disk (`emptyDir: {medium: Memory}`) — a real Linux filesystem, so hard links work. This is exactly the kind of failure mode [the internals section above](#internals-the-2h-block-and-ingest-pipeline) doesn't warn about: the 2h/30m block-cut mechanics are documented everywhere, but Sidecar's *upload mechanism* — hard link, not copy — is an implementation detail that only bites when the two paths don't share a real filesystem. Worth remembering for any future sidecar-pattern deployment (log shippers, backup agents) that assumes hard links work across an arbitrary shared volume.
