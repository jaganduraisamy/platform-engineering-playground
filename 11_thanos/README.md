# Step 11: Thanos (Prometheus long-term storage + global query)

Extends step 4's single Prometheus with a Thanos Sidecar, MinIO as the object-storage stand-in, a Store Gateway, a Compactor, and a Querier that fronts Grafana. Background and component-by-component design notes: [../docs/thanos-notes.md](../docs/thanos-notes.md).

**Components added:** Thanos Sidecar (inside step 4's Prometheus pod), MinIO, Thanos Store Gateway, Thanos Compactor, Thanos Query

## Why this matters (PE)

| Concern | This step |
| :--- | :--- |
| Retention beyond local disk | Sidecar ships sealed TSDB blocks to MinIO; Prometheus itself only needs to hold the last ~30m |
| Global query surface | Thanos Query fans out to the Sidecar (live) and Store Gateway (historical) and merges — the actual fix for "one Prometheus, one island" |
| HA-ready without duplicate counting | `external_labels.replica` + `--query.replica-label=replica` wired in now, even with a single replica, so adding a second Prometheus later needs no query-side changes |
| Reuse over duplication | One Prometheus (step 4's), not a second one — Thanos is a layer around it, not a replacement |

## Prerequisites

- Kind cluster: [../1_kind-cluster/](../1_kind-cluster/)
- ingress-nginx: [../3_networking/ingress-nginx/](../3_networking/ingress-nginx/)
- Observability stack: [../4_observability-grafana-stack/](../4_observability-grafana-stack/) — this step edits that folder's `lgtm-observability-stack.yaml` directly (same pattern step 10/OpenCost used), it doesn't fork it

```bash
kubectl config current-context   # kind-home-k8-cluster
kubectl -n observability get deploy/prometheus
```

## 1. Deploy

```bash
chmod +x deploy-thanos.sh uninstall-thanos.sh
./deploy-thanos.sh
```

In order: MinIO + bucket-creation Job → Thanos objstore Secret → re-apply step 4's file (adds the Sidecar container to the Prometheus pod, the `thanos-sidecar` Service, and a `Thanos Query` Grafana datasource) → Store Gateway / Compactor / Querier → Ingress.

## 2. What changed in step 4's file, and why

- **`external_labels: {cluster, replica}`** on Prometheus — Thanos identifies and dedups series by these labels. Set now even for a single replica so a second Prometheus can be added later without touching the Querier.
- **`--storage.tsdb.min-block-duration` / `--storage.tsdb.max-block-duration` both set to `30m`** — real Thanos deployments use Prometheus's `2h` default and let it be. Set equal here only to make this lab's blocks land in MinIO in minutes instead of hours; call this out if you copy this file — it is a lab-only shortcut, not the production recommendation.
- **`prometheus-data` emptyDir volume, mounted in both containers** — the Sidecar reads Prometheus's TSDB directory directly; without a shared volume the two containers see different filesystems and the Sidecar finds nothing to upload.
- **`thanos-objstore-config` Secret, mounted with `optional: true`** — keeps step 4 deployable standalone on a bare cluster (the Sidecar container just idles/crashloops harmlessly until this step's Secret exists), instead of coupling step 4's rollout to this one.

## 3. Best practices highlighted in this lab

- **Objstore credentials as a Secret, not a ConfigMap** ([thanos-objstore-secret.yaml](thanos-objstore-secret.yaml)) — it holds MinIO's access/secret key. `minioadmin`/`minioadmin` here are homelab-only defaults committed in plaintext for a local Kind cluster; a real deployment replaces this with Sealed Secrets / External Secrets, per [../AGENTS.md](../AGENTS.md)'s guardrail.
- **Compactor is a forced singleton** ([thanos-stack.yaml](thanos-stack.yaml)) — `strategy: Recreate` on its Deployment, not the `RollingUpdate` default, so Kubernetes fully terminates the old pod before starting a new one. Two Compactors racing on the same bucket blocks would corrupt them mid-merge; this is the concrete k8s mechanism behind that constraint, not just a doc footnote.
- **MinIO is the one component in this repo that gets a PersistentVolumeClaim.** Every other piece of the LGTM stack (step 4) intentionally writes to ephemeral container storage — that's fine for Prometheus/Loki/Tempo here since they're short-retention by design, but MinIO is the durable tier the whole lab exists to demonstrate; losing it on every pod restart would defeat the point.
- **StoreAPI discovery via `dnssrv+_grpc._tcp.<service>...`** (Thanos Query's `--endpoint` flags) instead of hardcoded addresses — the standard Thanos service-discovery pattern, and it's what lets you add a second Sidecar/Store Gateway later by just adding a Service, no Querier redeploy.
- **Resource requests/limits set on every new container** — the rest of this repo mostly omits them (lab simplicity); added here since Thanos is memory-sensitive by nature ([../docs/thanos-notes.md](../docs/thanos-notes.md)'s cardinality section) and it's cheap to get right from the start.
- **No liveness/readiness probes** — matches this repo's existing convention (none of steps 1–10 set them either). Flagging the gap rather than silently deviating: add `/-/healthy` and `/-/ready` probes (Thanos exposes both on the http port) before using any of this beyond a homelab.

## 4. Validate

**Thanos Query UI:** http://thanos-query.localhost/ → Stores tab should show the Sidecar and Store Gateway both `UP`.

**MinIO console:** http://minio-console.localhost/ (`minioadmin` / `minioadmin`) → `thanos` bucket should start filling with block directories ~30m after Prometheus starts (see the min/max block duration note above).

```bash
kubectl -n observability get pods
kubectl -n observability logs deploy/prometheus -c thanos-sidecar --tail=50
```

**Grafana:** http://grafana.localhost/ (`admin`/`admin`) → Explore → switch datasource to **Thanos Query** → same PromQL as the `Prometheus` datasource, now served through Thanos.

## Known caveats (homelab scope, not a production topology)

- Single Prometheus replica — the dedup path (`--query.replica-label`) is wired but has nothing to actually merge yet. A second Prometheus + Sidecar (same `external_labels.cluster`, different `replica` value) would exercise it; not added here to keep this step additive-only, matching [../docs/thanos-notes.md](../docs/thanos-notes.md)'s "Mapping to this repo's existing stack" scoping call.
- No Ruler or Receiver — this repo has no cross-cluster rule evaluation need, and Sidecar already covers ingestion. See the component write-up in the design notes for what each would add.
- MinIO's own Docker Hub images were pulled in late 2025 as MinIO winds down its OSS community edition in favor of a commercial product — this lab pins `quay.io/minio/minio` (MinIO's other registry) as the current stopgap. If that also disappears, swap in a maintained S3-compatible alternative (Garage, SeaweedFS) — only `minio.yaml` needs to change; nothing else in this folder references MinIO by name.
- Kind, single node pool for storage — MinIO here is a single instance, not the distributed/erasure-coded mode real object storage would run in.

## Cleanup

```bash
./uninstall-thanos.sh
```

Removes MinIO, the objstore Secret, and the Store Gateway/Compactor/Querier — additive-only like step 10, so it leaves the Sidecar container and `Thanos Query` datasource in step 4's file. The Sidecar will crashloop with MinIO gone (see the script's own output for the one-line full-revert command if that's undesirable).

## Next step

None yet — this is the newest lab. See [../docs/platform-engineering-roadmap.md](../docs/platform-engineering-roadmap.md) for what's still on the roadmap.
