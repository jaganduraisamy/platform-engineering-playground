# LinkedIn post: Thanos (part 1 of a series — Thanos, VictoriaMetrics, Mimir)

Status: final, verified against the live homelab build before publishing.

Source material: [../thanos-notes.md](../thanos-notes.md), [../../11_thanos/README.md](../../11_thanos/README.md).

Verification note: the "fixed by pinning both containers to the same user" claim below was confirmed live — 4 blocks uploaded successfully to MinIO (04:59, 05:05, 05:15, 05:25 UTC on 2026-09-26), zero errors in Sidecar logs after the `securityContext.runAsUser: 65534` fix landed in [../../4_observability-grafana-stack/lgtm-observability-stack.yaml](../../4_observability-grafana-stack/lgtm-observability-stack.yaml).

---

Prometheus is the default choice for metrics in most stacks I have worked with. Even OpenTelemetry built OTLP's metric types (Counter, Gauge, Histogram) directly on top of Prometheus's own model, with an official spec to convert between the two.

But Prometheus was built as a single node database. Cross that line and you hit 3 hard limits:

- Retention capped by local disk. Most teams run 15-30 days locally because that is what fits, not what they need.
- No cross cluster view. One Prometheus per cluster is the norm, and there is no single query across all of them.
- HA gives you duplicate data, not safer data. Two identical replicas, and a plain query across both double counts everything.

Prometheus's own docs say clustering and long term storage are out of scope. Deliberate design choice. That gap is exactly why a separate category of tools exists.

I have used 3 of them for this problem, Thanos, VictoriaMetrics and Mimir. Starting this series with Thanos, my first one for long term storage.

What Thanos is:
- Runs alongside Prometheus, adds global query, long term object storage, and HA dedup
- Does not change anything inside Prometheus itself
- CNCF incubating project, in production at HelloFresh, Monzo, Red Hat, Adobe

Core components:
- Sidecar: sits next to each Prometheus, uploads sealed blocks to object storage, also serves live data for recent queries
- Store Gateway: reads blocks back from the bucket when queried
- Compactor: merges and downsamples old blocks, must run as a single instance, never more than one
- Querier: fans out to every source and merges results into one answer
- Ruler, Receiver: optional, for cross cluster alerting rules and remote write ingestion

3 things I would tell anyone running this in production:
- Watch cardinality before it watches you. prometheus_tsdb_head_series warns you before an OOM does
- Never run more than one Compactor. Two racing on the same bucket will corrupt your blocks
- Check what your downsampled data stores. Should be min, max, sum, count, not just average, or rate() and max_over_time() quietly give wrong answers on old data

What I actually hit building this in a homelab:

- Ran the full stack on Kind cluster, code and configs here: github.com/jaganduraisamy/platform-engineering-sandbox, branch docs/thanos-notes, folder 11_thanos
- Local setup: Prometheus cuts a block every 10 minutes (lab-shortened from the 2h production default), Sidecar ships each sealed block to a MinIO bucket named thanos, Compactor keeps raw data 30 days, 5m rollups 120 days, 1h rollups 1 year, and Querier ties Sidecar plus Store Gateway together with replica-label dedup and auto-downsampling turned on
- Blocks refused to upload for days. Root cause: Sidecar ships blocks via hard link, not copy, and Prometheus + Sidecar were running as different Linux users. Linux blocks a hard link to a file you do not own by default, so every upload silently failed. Fixed by pinning both containers to the same user.
- This is not in any getting started guide, only shows up once you actually run it

What worked from minute one: querying live data, Grafana to Thanos Query to Prometheus's own in-memory data, well before any block reached object storage. Querying and archiving are 2 separate paths, only one is time gated.

Next in this series: what changes when I swap Thanos for VictoriaMetrics.

#Prometheus #Thanos #VictoriaMetrics #GrafanaMimir #Observability #PlatformEngineering #SRE #Kubernetes
