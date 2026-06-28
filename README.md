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

## Quick Start

```bash
cd 1_kind-cluster && ./create-cluster.sh
cd ../2_kodekloud-voting-app && kubectl apply -f deployment.yaml
cd ../3_networking/ingress-nginx && ./deploy-ingress.sh
cd ../../4_observability-grafana-stack && ./deploy-observability.sh
cd ../5_otel-instrumentation && ./deploy-otel.sh
cd ../6_kafka-otel-tracing && ./deploy-kafka.sh
```

## Teardown (reverse order)

```bash
cd 6_kafka-otel-tracing && ./uninstall-kafka.sh
cd ../5_otel-instrumentation && ./uninstall-otel.sh
cd ../4_observability-grafana-stack && ./uninstall-observability.sh
cd ../3_networking/ingress-nginx && ./uninstall-ingress.sh
cd ../../2_kodekloud-voting-app && ./uninstall-app.sh
cd ../1_kind-cluster && ./uninstall-cluster.sh
```

Future capability areas (not yet populated): `terraform/`, `gitops/`, `security/`.

---

## Tech Stack & Ecosystem

| Category | Tools Explored |
| :--- | :--- |
| **Orchestration & Compute** | Kubernetes (K8s), Kind, Helm |
| **Messaging** | Kafka (KRaft) |
| **Infrastructure as Code** | Terraform, OpenTofu |
| **GitOps & Delivery** | ArgoCD, GitHub Actions |
| **Observability & Monitoring** | Prometheus, Grafana, OpenTelemetry, Loki, Tempo |
| **Service Mesh & Networking** | Istio / Linkerd, Ingress-NGINX |
| **Security & Secrets** | HashiCorp Vault, Sealed Secrets |
