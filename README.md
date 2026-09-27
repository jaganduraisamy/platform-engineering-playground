# platform-engineering-sandbox

A personal homelab for platform engineering — one Kind cluster, one numbered folder per tool, built up incrementally as I learn each piece. If you're evaluating a tool and want to see it wired into an actual stack (not just a "hello world"), find it in the table below and go straight to that folder — each one has its own README with what it does, why it's there, and exact start/validate/cleanup commands.

Full study roadmap (what's covered vs. planned): [docs/platform-engineering-roadmap.md](docs/platform-engineering-roadmap.md)

## Tools covered, by folder

Everything runs on one Kind cluster, numbered in the order I built them. Steps 10 and 11 only need steps 1, 3, and 4 — skip step 9 if GitOps isn't what you're after.

| Step | Tool / Pattern | Folder | Deploy | Uninstall |
| :--- | :--- | :--- | :--- | :--- |
| **1** | Kind, kubectl | [1_kind-cluster/](1_kind-cluster/) | `./create-cluster.sh` | `./uninstall-cluster.sh` |
| **2** | Multi-service app on K8s (Deployments, Services, namespaces) | [2_kodekloud-voting-app/](2_kodekloud-voting-app/) | `kubectl apply -f deployment.yaml` | `./uninstall-app.sh` |
| **3** | Ingress NGINX | [3_networking/ingress-nginx/](3_networking/ingress-nginx/) | `./deploy-ingress.sh` | `./uninstall-ingress.sh` |
| **4** | Prometheus, Grafana, Loki, Tempo, Promtail (LGTM stack) | [4_observability-grafana-stack/](4_observability-grafana-stack/) | `./deploy-observability.sh` | `./uninstall-observability.sh` |
| **5** | OpenTelemetry Operator + auto-instrumentation | [5_otel-instrumentation/](5_otel-instrumentation/) | `./deploy-otel.sh` | `./uninstall-otel.sh` |
| **6** | Kafka (KRaft mode) + trace context propagation | [6_kafka-otel-tracing/](6_kafka-otel-tracing/) | `./deploy-kafka.sh` | `./uninstall-kafka.sh` |
| **7** | Kustomize overlays (one image, per-env config) | [7_kustomize-webapp/](7_kustomize-webapp/) | `./deploy-webapp.sh dev` | `./uninstall-webapp.sh` |
| **8** | GitHub Actions — multi-arch build, publish to GHCR | [8_github-actions/](8_github-actions/) | `./validate-ci-local.sh` (workflow in `.github/`) | — |
| **9** | ArgoCD + Image Updater — GitOps, promotion gates | [9_gitops-argocd/](9_gitops-argocd/) | `./install-argocd.sh` + `./install-image-updater.sh` | `./uninstall-argocd.sh` + `./uninstall-image-updater.sh` |
| **10** | OpenCost — Kubernetes cost allocation | [10_opencost-cost-analysis/](10_opencost-cost-analysis/) | `./install-opencost.sh` | `./uninstall-opencost.sh` |
| **11** | Thanos + MinIO — Prometheus long-term storage, global query | [11_thanos/](11_thanos/) | `./deploy-thanos.sh` | `./uninstall-thanos.sh` |

Not a lab yet, but on deck — RBAC/policy/secrets, Elasticsearch, Backstage, Terraform: see the roadmap doc above.

## Quick start

```bash
cd 1_kind-cluster && ./create-cluster.sh
cd ../2_kodekloud-voting-app && kubectl apply -f deployment.yaml
cd ../3_networking/ingress-nginx && ./deploy-ingress.sh
cd ../../4_observability-grafana-stack && ./deploy-observability.sh
cd ../5_otel-instrumentation && ./deploy-otel.sh
cd ../6_kafka-otel-tracing && ./deploy-kafka.sh
cd ../7_kustomize-webapp && ./deploy-webapp.sh dev
cd ../8_github-actions && ./validate-ci-local.sh
cd ../9_gitops-argocd && ./install-argocd.sh && kubectl apply -f apps/
cd ../10_opencost-cost-analysis && ./install-opencost.sh
cd ../11_thanos && ./deploy-thanos.sh
```

## Teardown (reverse order)

```bash
cd 11_thanos && ./uninstall-thanos.sh
cd ../10_opencost-cost-analysis && ./uninstall-opencost.sh
cd ../9_gitops-argocd && ./uninstall-image-updater.sh && ./uninstall-argocd.sh
cd ../7_kustomize-webapp && ./uninstall-webapp.sh
cd ../6_kafka-otel-tracing && ./uninstall-kafka.sh
cd ../5_otel-instrumentation && ./uninstall-otel.sh
cd ../4_observability-grafana-stack && ./uninstall-observability.sh
cd ../3_networking/ingress-nginx && ./uninstall-ingress.sh
cd ../../2_kodekloud-voting-app && ./uninstall-app.sh
cd ../1_kind-cluster && ./uninstall-cluster.sh
```

## Why this exists

I wanted a place to actually *use* the tools platform engineering job specs list, not just read about them — a real Kind cluster where adding Thanos means editing a real Prometheus config, and "GitOps" means an ArgoCD Application actually syncing a real overlay. Each folder is additive where it makes sense (Thanos and OpenCost both build on step 4's stack instead of duplicating it) and disposable where it doesn't (every teardown script actually tears down).

Guardrails followed throughout — no plaintext secrets, requests/limits on new workloads, blast radius called out before anything that mutates infra state — are in [AGENTS.md](AGENTS.md).
