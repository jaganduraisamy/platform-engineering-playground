# platform-engineering-sandbox

Hands-on lab for platform engineering: build, break, fix, and document modern cloud-native patterns on a local Kind cluster.

Study roadmap: [docs/platform-engineering-roadmap.md](docs/platform-engineering-roadmap.md)

## Lab Flow

Everything runs on the same Kind cluster. Folders are numbered in suggested order:

| Step | Folder | Deploy | Uninstall |
| :--- | :--- | :--- | :--- |
| **1** | [1_kind-cluster/](1_kind-cluster/) | `./create-cluster.sh` | `./uninstall-cluster.sh` |
| **2** | [2_kodekloud-voting-app/](2_kodekloud-voting-app/) | `kubectl apply -f deployment.yaml` | `./uninstall-app.sh` |
| **3** | [3_networking/ingress-nginx/](3_networking/ingress-nginx/) | `./deploy-ingress.sh` | `./uninstall-ingress.sh` |
| **4** | [4_observability-grafana-stack/](4_observability-grafana-stack/) | `./deploy-observability.sh` | `./uninstall-observability.sh` |
| **5** | [5_otel-instrumentation/](5_otel-instrumentation/) | `./deploy-otel.sh` | `./uninstall-otel.sh` |
| **6** | [6_kafka-otel-tracing/](6_kafka-otel-tracing/) | `./deploy-kafka.sh` | `./uninstall-kafka.sh` |
| **7** | [7_kustomize-webapp/](7_kustomize-webapp/) | `./deploy-webapp.sh dev` | `./uninstall-webapp.sh` |
| **8** | [8_github-actions/](8_github-actions/) | `./validate-ci-local.sh` (workflow in `.github/`) | — |
| **10** | [10_opencost-cost-analysis/](10_opencost-cost-analysis/) | `./install-opencost.sh` | `./uninstall-opencost.sh` |
| **11** | [11_thanos/](11_thanos/) | `./deploy-thanos.sh` | `./uninstall-thanos.sh` |

Step 9 (ArgoCD GitOps) is still on `lab/gitops-argocd`, not merged yet — hence the gap. Steps 10 and 11 only need steps 1, 3, and 4, not step 9.

## Quick Start

```bash
cd 1_kind-cluster && ./create-cluster.sh
cd ../2_kodekloud-voting-app && kubectl apply -f deployment.yaml
cd ../3_networking/ingress-nginx && ./deploy-ingress.sh
cd ../../4_observability-grafana-stack && ./deploy-observability.sh
cd ../5_otel-instrumentation && ./deploy-otel.sh
cd ../6_kafka-otel-tracing && ./deploy-kafka.sh
cd ../7_kustomize-webapp && ./deploy-webapp.sh dev
cd ../8_github-actions && ./validate-ci-local.sh
cd ../10_opencost-cost-analysis && ./install-opencost.sh
cd ../11_thanos && ./deploy-thanos.sh
```

## Teardown (reverse order)

```bash
cd 11_thanos && ./uninstall-thanos.sh
cd ../10_opencost-cost-analysis && ./uninstall-opencost.sh
cd ../7_kustomize-webapp && ./uninstall-webapp.sh
cd ../6_kafka-otel-tracing && ./uninstall-kafka.sh
cd ../5_otel-instrumentation && ./uninstall-otel.sh
cd ../4_observability-grafana-stack && ./uninstall-observability.sh
cd ../3_networking/ingress-nginx && ./uninstall-ingress.sh
cd ../../2_kodekloud-voting-app && ./uninstall-app.sh
cd ../1_kind-cluster && ./uninstall-cluster.sh
```

Future capability areas: `gitops/` (ArgoCD — consumes GHCR tags from step 8 + overlays from step 7), `security/`, `observability/` (Elasticsearch), `idp/` (Backstage), `terraform/` (otel-benchmark) `rca-labs` . 

---

## Tech Stack

**In this repo (runnable labs)**

| Category | Tools |
| :--- | :--- |
| **Orchestration** | Kubernetes, Kind, Helm, kubectl, Kustomize |
| **Networking** | Ingress NGINX, Services / CoreDNS |
| **Observability** | Prometheus, Grafana, Loki, Tempo, Promtail, OpenTelemetry, Thanos, MinIO |
| **Messaging** | Kafka (KRaft) |
| **Images** | Local Kind load / `localhost:5001` (step 6); CI → GHCR (step 8) |
| **CI** | GitHub Actions ([8_github-actions/](8_github-actions/), workflow under `.github/`) |
| **Cost** | OpenCost ([10_opencost-cost-analysis/](10_opencost-cost-analysis/)) |
| **Long-term metrics** | Thanos ([11_thanos/](11_thanos/)) — Sidecar, Store Gateway, Compactor, Query on MinIO |

**On the roadmap (not labs yet)** — see [docs/platform-engineering-roadmap.md](docs/platform-engineering-roadmap.md): ArgoCD, Elasticsearch, NetworkPolicy / Gateway API, Kyverno or OPA, Vault / Sealed Secrets, Backstage, Terraform / OpenTofu.
