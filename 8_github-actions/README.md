# Step 8: GitHub Actions CI

CI for platform demos: build images on **GitHub-hosted runners**, publish to **GHCR**.

Primary app for CD demos (build once / promote / approvals): the welcome webapp from [../7_kustomize-webapp/](../7_kustomize-webapp/).  
Optional: Kafka images from step 6 (heavy service build).

Workflow YAML must live under [`.github/workflows/`](../.github/workflows/) — GitHub only loads Actions from there. This folder is the experiment entrypoint.

## Prerequisites

- Step 7 app: [../7_kustomize-webapp/app/](../7_kustomize-webapp/app/)
- (Optional) Kafka Dockerfiles: [../6_kafka-otel-tracing/](../6_kafka-otel-tracing/)

```bash
ls ../7_kustomize-webapp/app/Dockerfile
ls ../.github/workflows/
```

## Registry

Use **GHCR** (`ghcr.io/<owner>/…`). Do not use `localhost:5001` for CI — GitHub runners cannot reach your laptop registry. Kind pulls GHCR for CD demos (public package = simplest).

## Layout

| Path | Role |
| :--- | :--- |
| This folder | Experiment README + local validate |
| [../.github/workflows/](../.github/workflows/) | Workflow files |
| [../7_kustomize-webapp/](../7_kustomize-webapp/) | App + Kustomize overlays (env config) |

## 1. Validate webapp build locally

```bash
chmod +x validate-ci-local.sh
./validate-ci-local.sh
```

## 2. Workflows (on GitHub when you push)

| Workflow | Status |
| :--- | :--- |
| `ci-kafka-images.yml` | Present — Kafka producer/consumer → GHCR |
| `ci-welcome-webapp.yml` | Next — welcome app → GHCR `sha-*` (add when ready) |
| promote / Environments | Next — same digest → uat/prod with approvals |

## Next step

[../gitops/](../gitops/) — ArgoCD pins GHCR `sha-*` into the Kustomize overlays from step 7.

## Cleanup

No cluster uninstall for CI. Delete unused GHCR packages from GitHub if needed.
