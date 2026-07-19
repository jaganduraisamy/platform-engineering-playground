# Platform Engineering Roadmap

Hands-on skill path for this sandbox — platform engineering capabilities practiced with concrete tools and reproducible labs.

Aligned with [AGENTS.md](../AGENTS.md): one experiment at a time, README with start / validate / cleanup, pin versions.

## How To Use This List

- Treat numbered folders `1_*` … `6_*` as the completed Kind lab spine — do not renumber them for certifications.
- Pick the next **capability track** below; add a folder when you start (`gitops/`, `security/`, etc.).
- After each experiment, note what broke and how you fixed it.

---

## Capability tracks

### 1. Runtime & workload foundation

**Why it matters for PE roles:** You own the shared Kubernetes fabric application teams run on.

| Tools | Sandbox status | Suggested folder |
| :--- | :--- | :--- |
| Kind, kubectl | Covered — `1_kind-cluster/` | — |
| Multi-service app (Deployments, Services, namespaces) | Covered — `2_kodekloud-voting-app/` | — |
| Helm for platform addons | Covered — Ingress (step 3), OTel Operator (step 5) | — |
| Kustomize overlays | Covered — [`7_kustomize-webapp/`](../7_kustomize-webapp/) (env config, same image) | — |
| Requests/limits, probes | Apply on new manifests | Existing + new labs |

### 2. Networking & traffic

**Why it matters:** North-south entry, east-west isolation, and TLS are platform contracts.

| Tools | Sandbox status | Suggested folder |
| :--- | :--- | :--- |
| Ingress NGINX | Covered — `3_networking/ingress-nginx/` | — |
| Services & CoreDNS | Covered (via demo app) | — |
| NetworkPolicy | Planned | `3_networking/` or `security/` |
| Gateway API | Planned | `3_networking/` |
| cert-manager | Planned | `3_networking/` or `security/` |
| Service mesh mTLS (Istio / Linkerd) | Planned (optional depth) | Later |

### 3. Observability

**Why it matters:** Platforms must expose golden signals and support 2 AM troubleshooting across metrics, logs, and traces.

| Tools | Sandbox status | Suggested folder |
| :--- | :--- | :--- |
| Prometheus, Grafana, Loki, Tempo, Promtail | Covered — `4_observability-grafana-stack/` | — |
| OpenTelemetry Operator + auto-instrumentation | Covered — `5_otel-instrumentation/` | — |
| Kafka + trace context propagation | Covered — `6_kafka-otel-tracing/` | — |
| Alerting examples / SLOs | Partial — add examples | Extend step 4 or `observability/` |
| **Thanos** — Prometheus HA + long-term metrics on object storage | Planned | `observability/` |
| **Elasticsearch** — logs/docs, index templates, ILM / mappings | Planned | `observability/` |

### 4. Delivery & GitOps

**Why it matters:** Safe, auditable path from commit to cluster; build once, promote many.

| Tools | Sandbox status | Suggested folder |
| :--- | :--- | :--- |
| Git as source of truth | Covered — this repo | — |
| Local image registry workflow | Covered — `localhost:5001` in step 6; Kind `load` in step 7 | — |
| **GitHub Actions** — CI: build, publish to GHCR | Partial — Kafka workflow present; welcome-webapp CI next | [`8_github-actions/`](../8_github-actions/) |
| Build once, deploy many + **approval gates** | Partial — Kustomize envs ready; GHA Environments next | steps 7–8 + `gitops/` |
| **ArgoCD** — declarative sync | Planned — pin GHCR `sha-*` into step 7 overlays | `gitops/` |
| Progressive delivery (canary / blue-green) | Planned (optional) | With Gateway API / mesh |

### 5. Platform APIs & self-service

**Why it matters:** Platforms expose APIs (often CRDs) so teams self-serve without tickets.

| Tools | Sandbox status | Suggested folder |
| :--- | :--- | :--- |
| Operators + CRDs (consume) | Partial — OTel Operator / Instrumentation CR | — |
| Custom CRDs or Crossplane compositions (light) | Planned | `platform-apis/` or under `gitops/` |
| Reconciliation loop literacy | Partial — observe controllers in Kind | Docs + labs |

### 6. Security & conformance

**Why it matters:** Guardrails without blocking delivery; clear blast radius and policy enforcement.

| Tools | Sandbox status | Suggested folder |
| :--- | :--- | :--- |
| No plaintext secrets in Git | Covered — AGENTS.md | — |
| RBAC least privilege | Planned | `security/` |
| NetworkPolicy baselines | Planned | `security/` / networking |
| Policy-as-code (Kyverno or OPA/Gatekeeper) | Planned | `security/` |
| Sealed Secrets / Vault basics | Planned | `security/` |
| Image scanning in CI (Trivy / Grype) | Planned | With GitHub Actions |

### 7. IDP & developer experience

**Why it matters:** Adoption is the product metric; portals and catalogs reduce cognitive load.

| Tools | Sandbox status | Suggested folder |
| :--- | :--- | :--- |
| Golden-path docs / scripts | Partial — per-step READMEs | Keep improving |
| **Backstage** (minimal portal / catalog) | Planned | `idp/` |
| Service templates / scaffolder | Planned | With Backstage |

### 8. Platform measurement

**Why it matters:** Prove the platform improves delivery (DORA) and efficiency, not just “more YAML.”

| Tools | Sandbox status | Suggested folder |
| :--- | :--- | :--- |
| Golden signals in Grafana | Covered — step 4 | — |
| DORA-style metrics / platform adoption notes | Planned | Docs + optional Grafana dashboard |
| SLOs & error budgets | Planned | `observability/` |

### Infrastructure as Code (supporting track)

| Tools | Sandbox status | Suggested folder |
| :--- | :--- | :--- |
| Terraform / OpenTofu | Planned | `terraform/` |
| State, modules, drift awareness | Planned | Document per experiment |

---

## Suggested order in this repo

```text
Done (Kind lab spine)
1. 1_kind-cluster/                → runtime foundation
2. 2_kodekloud-voting-app/        → multi-service workload
3. 3_networking/ingress-nginx/    → north-south traffic
4. 4_observability-grafana-stack/ → LGTM
5. 5_otel-instrumentation/        → OTel auto-instrumentation
6. 6_kafka-otel-tracing/          → async + distributed tracing
7. 7_kustomize-webapp/            → Kustomize overlays (one image, env-specific config)
8. 8_github-actions/              → GitHub Actions CI → GHCR (workflow in .github/)

Next capability areas
9.  gitops/                       → ArgoCD GitOps (deploy sha tags into overlays)
10. security/                     → RBAC, policy, secrets
11. observability/                → Thanos + Elasticsearch (optional scale-out)
12. idp/                          → Backstage (minimal)
13. terraform/                    → IaC foundations
```

---

## Platform engineering mindset (evaluate every experiment)

- What is the **contract** for application teams?
- What is **centralized** (platform-owned) vs **delegated** (team-owned)?
- How is **policy enforced** — admission, runtime, network?
- How is **TLS** handled and who owns renewal?
- How do you **troubleshoot at 2 AM** — logs, metrics, traces, runbooks?
- What is **portable** across clusters and cloud vendors?
- What **breaks during upgrades** — controller swaps, CRD changes, mesh rollouts?

## Quality bar for new experiments

From AGENTS.md — each addition should aim for:

- Requests/limits and probes on Kubernetes workloads
- At least one alerting or SLO example in observability work
- State/drift notes for Terraform changes
- Reconciliation flow explained for GitOps examples
- Start, validate, and cleanup commands in the README
