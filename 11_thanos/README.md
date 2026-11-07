# Step 11: Thanos (Prometheus long-term storage + global query)

Extends step 4's single Prometheus with a Thanos Sidecar, SeaweedFS as the object-storage stand-in, a Store Gateway, a Compactor, and a Querier that fronts Grafana. Background and component-by-component design notes: [../docs/thanos-notes.md](../docs/thanos-notes.md).

**Components added:** Thanos Sidecar (inside step 4's Prometheus pod), SeaweedFS, Thanos Store Gateway, Thanos Compactor, Thanos Query

## Why this matters (PE)

| Concern | This step |
| :--- | :--- |
| Retention beyond local disk | Sidecar ships sealed TSDB blocks to SeaweedFS (S3 API); Prometheus itself only needs to hold the last ~30m |
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

In order: SeaweedFS + bucket-creation Job → Thanos objstore Secret → re-apply step 4's file (adds the Sidecar container to the Prometheus pod, the `thanos-sidecar` Service, and a `Thanos Query` Grafana datasource) → Store Gateway / Compactor / Querier → Ingress.

## 2. What changed in step 4's file, and why

- **`external_labels: {cluster, replica}`** on Prometheus — Thanos identifies and dedups series by these labels. Set now even for a single replica so a second Prometheus can be added later without touching the Querier.
- **`--storage.tsdb.min-block-duration` / `--storage.tsdb.max-block-duration` both set to `30m`** — real Thanos deployments use Prometheus's `2h` default and let it be. Set equal here only to make this lab's blocks land in SeaweedFS in minutes instead of hours; call this out if you copy this file — it is a lab-only shortcut, not the production recommendation.
- **`prometheus-data` emptyDir volume, mounted in both containers** — the Sidecar reads Prometheus's TSDB directory directly; without a shared volume the two containers see different filesystems and the Sidecar finds nothing to upload.
- **`thanos-objstore-config` Secret, mounted with `optional: true`** — keeps step 4 deployable standalone on a bare cluster (the Sidecar container just idles/crashloops harmlessly until this step's Secret exists), instead of coupling step 4's rollout to this one.

## 3. Best practices highlighted in this lab

- **Objstore credentials as a Secret, not a ConfigMap** ([thanos-objstore-secret.yaml](thanos-objstore-secret.yaml)) — it holds the S3 access/secret key. `thanosadmin`/`thanosadmin` here are homelab-only defaults committed in plaintext for a local Kind cluster; a real deployment replaces this with Sealed Secrets / External Secrets, per [../AGENTS.md](../AGENTS.md)'s guardrail.
- **Compactor is a forced singleton** ([thanos-stack.yaml](thanos-stack.yaml)) — `strategy: Recreate` on its Deployment, not the `RollingUpdate` default, so Kubernetes fully terminates the old pod before starting a new one. Two Compactors racing on the same bucket blocks would corrupt them mid-merge; this is the concrete k8s mechanism behind that constraint, not just a doc footnote.
- **SeaweedFS is the one component in this repo that gets a PersistentVolumeClaim.** Every other piece of the LGTM stack (step 4) intentionally writes to ephemeral container storage — that's fine for Prometheus/Loki/Tempo here since they're short-retention by design, but the object store is the durable tier the whole lab exists to demonstrate; losing it on every pod restart would defeat the point.
- **Bucket retention is 7 days, and SeaweedFS is capped at `-volume.max=20` (about 5GB).** The compactor runs `--retention.resolution-raw=7d --downsampling.disable` (Thanos rejects 5m/1h retention under 10 days, and downsampling never kicks in within 7 days anyway). The cap is a slot count, not a size: when SeaweedFS ran out of slots, every S3 call timed out with "Not enough data nodes found". The `standard` class on Kind does not enforce the PVC size.
- **StoreAPI discovery via `dnssrv+_grpc._tcp.<service>...`** (Thanos Query's `--endpoint` flags) instead of hardcoded addresses — the standard Thanos service-discovery pattern, and it's what lets you add a second Sidecar/Store Gateway later by just adding a Service, no Querier redeploy.
- **Resource requests/limits set on every new container** — the rest of this repo mostly omits them (lab simplicity); added here since Thanos is memory-sensitive by nature ([../docs/thanos-notes.md](../docs/thanos-notes.md)'s cardinality section) and it's cheap to get right from the start.
- **No liveness/readiness probes** — matches this repo's existing convention (none of steps 1–10 set them either). Flagging the gap rather than silently deviating: add `/-/healthy` and `/-/ready` probes (Thanos exposes both on the http port) before using any of this beyond a homelab.

## 4. Validate

**Thanos Query UI:** http://thanos-query.localhost/ → Stores tab should show the Sidecar and Store Gateway both `UP`.

**SeaweedFS filer UI:** http://seaweedfs.localhost/buckets/thanos/ → the `thanos` bucket should start filling with block directories ~30m after Prometheus starts (see the min/max block duration note above).

```bash
kubectl -n observability get pods
kubectl -n observability logs deploy/prometheus -c thanos-sidecar --tail=50
```

**Grafana:** http://grafana.localhost/ (`admin`/`admin`) → Explore → switch datasource to **Thanos Query** → same PromQL as the `Prometheus` datasource, now served through Thanos.

## Known caveats (homelab scope, not a production topology)

- Single Prometheus replica — the dedup path (`--query.replica-label`) is wired but has nothing to actually merge yet. A second Prometheus + Sidecar (same `external_labels.cluster`, different `replica` value) would exercise it; not added here to keep this step additive-only, matching [../docs/thanos-notes.md](../docs/thanos-notes.md)'s "Mapping to this repo's existing stack" scoping call.
- No Ruler or Receiver — this repo has no cross-cluster rule evaluation need, and Sidecar already covers ingestion. See the component write-up in the design notes for what each would add.
- **Why SeaweedFS, not MinIO:** MinIO withdrew its public images — Docker Hub in late 2025, then `quay.io/minio/*` as well (401 on pull, confirmed 2026-10-06). This lab uses SeaweedFS (`chrislusf/seaweedfs`, Apache-2.0, official image, S3 API). Only `seaweedfs.yaml`, the objstore Secret and the ingress reference it; Thanos itself just speaks S3. Garage would also work but needs a layout/key bootstrap.
- Kind, single node pool for storage — SeaweedFS here is a single instance, not the distributed/erasure-coded mode real object storage would run in.

## Cleanup

```bash
./uninstall-thanos.sh
```

Removes SeaweedFS, the objstore Secret, and the Store Gateway/Compactor/Querier — additive-only like step 10, so it leaves the Sidecar container and `Thanos Query` datasource in step 4's file. The Sidecar goes back to idle (waits for the objstore Secret) with SeaweedFS gone (see the script's own output for the one-line full-revert command if that's undesirable).

## Next step

None yet — this is the newest lab. See [../docs/platform-engineering-roadmap.md](../docs/platform-engineering-roadmap.md) for what's still on the roadmap.
