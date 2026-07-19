# CI — GitHub Actions

Build and publish container images for the Kafka OTel experiment. Uses **GitHub-hosted runners** (`ubuntu-latest`) and **GHCR**.

## What this proves (CI)

- Build once on every relevant change
- Immutable tag: `sha-<7-char>`
- `latest` only on `main` (convenience; prefer sha for deploys)
- Artifacts land in GitHub Packages (GHCR) for later CD/GitOps

## What this does *not* do

- Does not deploy to Kind
- Does not push to `localhost:5001` (laptop-only registry)
- Does not run self-hosted / in-cluster runners

Local Kind path stays: [`6_kafka-otel-tracing/deploy-kafka.sh`](../6_kafka-otel-tracing/deploy-kafka.sh) → `localhost:5001`.

## Workflow

| File | Images |
| :--- | :--- |
| [workflows/ci-kafka-images.yml](workflows/ci-kafka-images.yml) | `otel-kafka-producer`, `otel-kafka-consumer` |

Triggers on changes under `6_kafka-otel-tracing/producer-java/**` or `consumer-python/**`, or `workflow_dispatch`.

### Validate

1. Actions tab → run `ci-kafka-images` (or push a path-touching commit).
2. Packages: `ghcr.io/<owner>/otel-kafka-producer:sha-xxxxxxx` (and consumer).
3. On `main` only: also `:latest`.

First GHCR push from a private repo may need the package visibility set (Settings → Packages) or `packages: write` (already in the workflow).

## Extension path → ArgoCD / CD (next experiment)

```text
GHA (this folder)     →  ghcr.io/.../otel-kafka-*:sha-abc1234
ArgoCD (gitops/)      →  Application points at manifests that pin that tag
Cluster               →  pulls GHCR (imagePullSecrets if private)
```

When adding GitOps:

1. Keep CI as the only image builder (no rebuild in Argo).
2. Update deploy manifests (or a Kustomize overlay) from `localhost:5001/...:latest` → `ghcr.io/<owner>/...:sha-...`.
3. ArgoCD syncs Git; it does not build images.
4. Optional later: image-updater or CI opens a PR that bumps the tag in Git.

That separation is the PE interview story: **CI produces the artifact; GitOps converges the cluster.**
