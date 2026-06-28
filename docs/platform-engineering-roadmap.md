# Platform Engineering Roadmap

A practical study map for this sandbox, aligned with [AGENTS.md](../AGENTS.md). Focus on hands-on workflows you can run locally, document, break, and fix.

## How To Use This List

- Pick one capability area at a time.
- One folder per experiment, with README covering goal, prerequisites, validate, cleanup.
- Pin versions where possible.
- After each experiment, note what broke and how you fixed it.

## Core Capability Areas

### 1. Kubernetes & Runtime (in progress)

| Tool / technique | Why it matters | Sandbox status |
| :--- | :--- | :--- |
| **kind** — local multi-node clusters | Fast feedback loop for manifests and controllers | `1_kind-cluster/` |
| **kubectl** — deploy, debug, rollout | Day-to-day platform operator skill | Used everywhere |
| **Helm** — packaged releases | Standard way teams consume platform addons | Ingress NGINX (step 3), OTel operator (step 5) |
| **Kustomize** — overlay-based config | GitOps-friendly manifest composition | Planned |
| **Resource requests/limits** | Scheduling fairness and noisy-neighbor control | Apply in new manifests |
| **Probes (liveness/readiness)** | Safe rollouts and traffic eligibility | Apply in new manifests |
| **RBAC** | Least-privilege access for humans and automation | `security/` (planned) |
| **Namespaces & labels** | Multi-tenant boundaries and selector contracts | Demo app uses `demo-voting-app` |

### 2. Networking & Traffic

| Tool / technique | Why it matters | Sandbox status |
| :--- | :--- | :--- |
| **Services & CoreDNS** | Foundation for all routing | `3_networking/` roadmap |
| **Ingress NGINX** | Widely deployed north-south HTTP entry | `3_networking/ingress-nginx/` |
| **Gateway API** (`Gateway`, `HTTPRoute`) | Cleaner multi-tenant edge model | Planned in networking track |
| **NetworkPolicy** | East-west isolation baseline | Planned |
| **cert-manager** | Automated TLS lifecycle | Planned |
| **Istio / service mesh mTLS** | Identity and encryption between services | Planned |
| **Egress control** | Outbound dependency governance | Planned |

### 3. Delivery & GitOps

| Tool / technique | Why it matters | Sandbox status |
| :--- | :--- | :--- |
| **Git as source of truth** | Auditable, reversible platform changes | This repo |
| **ArgoCD** — declarative sync | Continuous reconciliation to cluster desired state | `gitops/` (planned) |
| **GitHub Actions** — CI pipelines | Build, test, scan before deploy | `.github/` (expand) |
| **Image registry workflow** | Repeatable artifact promotion | `6_kafka-otel-tracing/` uses `localhost:5001` |
| **Progressive delivery** — canary, weighted routes | Safer rollouts via Gateway API / mesh | Future networking experiments |

### 4. Infrastructure as Code

| Tool / technique | Why it matters | Sandbox status |
| :--- | :--- | :--- |
| **Terraform / OpenTofu** | Declarative cloud and cluster foundations | `terraform/` (planned) |
| **State management** | Know blast radius of every apply | Document per experiment |
| **Modules & environments** | Reuse without copy-paste drift | Planned |
| **Drift detection** | Catch manual console changes | Planned |

### 5. Observability

| Tool / technique | Why it matters | Sandbox status |
| :--- | :--- | :--- |
| **Golden signals** — latency, traffic, errors, saturation | Minimum viable service health view | Step 4 stack |
| **Prometheus** — metrics | Alerting and capacity signals | `4_observability-grafana-stack/` |
| **Grafana** — dashboards & Explore | Shared operational visibility | Same |
| **Loki** — log aggregation | Correlate logs with metrics/traces | Same |
| **Tempo** — distributed tracing | End-to-end request flow | Same + kafka OTel POC |
| **OpenTelemetry** — instrumentation & collectors | Vendor-neutral telemetry pipeline | Step 5 + `6_kafka-otel-tracing/` |
| **SLOs & error budgets** | Reliability contracts with product teams | `observability/` (planned) |
| **Alerting examples** | Actionable pages, not noise | Add to observability experiments |

### 6. Security & Secrets

| Tool / technique | Why it matters | Sandbox status |
| :--- | :--- | :--- |
| **Sealed Secrets** | Encrypted secrets safe in Git | `security/` (planned) |
| **HashiCorp Vault** | Dynamic credentials and secret rotation | Planned |
| **Policy as code** — OPA/Gatekeeper, Kyverno | Enforce standards at admission time | Planned |
| **Image scanning** — Trivy, Grype | Catch CVEs before deploy | Add to CI track |
| **No plaintext secrets in Git** | Non-negotiable guardrail | Enforced in AGENTS.md |

### 7. Messaging & Async (advanced)

| Tool / technique | Why it matters | Sandbox status |
| :--- | :--- | :--- |
| **Kafka (KRaft)** | Event-driven platform patterns | `6_kafka-otel-tracing/` |
| **Trace context over message headers** | Observability across async boundaries | Same POC |

## Suggested Study Order In This Repo

```text
1. 1_kind-cluster/                  → cluster foundation
2. 2_kodekloud-voting-app/          → realistic multi-service workload
3. 3_networking/                    → expose and secure traffic
4. 4_observability-grafana-stack/   → LGTM stack (metrics, logs, traces)
5. 5_otel-instrumentation/          → OTel operator + app auto-instrumentation
6. 6_kafka-otel-tracing/            → async messaging + distributed tracing
7. gitops/                          → delivery automation
8. terraform/                       → cloud/cluster provisioning
9. security/                        → secrets, RBAC, policy
```

## Platform Engineering Mindset (evaluate every experiment)

- What is the **contract** for application teams?
- What is **centralized** (platform-owned) vs **delegated** (team-owned)?
- How is **policy enforced** — admission, runtime, network?
- How is **TLS** handled and who owns renewal?
- How do you **troubleshoot at 2 AM** — logs, metrics, traces, runbooks?
- What is **portable** across clusters and cloud vendors?
- What **breaks during upgrades** — controller swaps, CRD changes, mesh rollouts?

## Quality Bar For New Experiments

From AGENTS.md — each addition should aim for:

- Requests/limits and probes on Kubernetes workloads
- At least one alerting or SLO example in observability work
- State/drift notes for Terraform changes
- Reconciliation flow explained for GitOps examples
- Start, validate, and cleanup commands in the README
