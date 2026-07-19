# CNPA Syllabus Alignment

Purpose: map [CNPA](https://www.cncf.io/training/certification/cnpa/) (Certified Cloud Native Platform Engineering Associate) domains to tools and experiments in this repo.

This sandbox is a **portfolio / interview lab**, not an exam course. Use this file for parallel CNPA study: see what you already practice hands-on vs what needs theory or a future experiment.

Official sources:

- [CNCF CNPA](https://www.cncf.io/training/certification/cnpa/)
- [Linux Foundation CNPA domains](https://training.linuxfoundation.org/certification/certified-cloud-native-platform-engineering-associate-cnpa/)
- [cncf/curriculum](https://github.com/cncf/curriculum) (`CNPA_Curriculum.pdf`)

Hands-on PE skill path (not exam-ordered): [platform-engineering-roadmap.md](platform-engineering-roadmap.md)

---

## Coverage at a glance

| Domain | Weight | Status | Primary evidence in this repo |
| :--- | ---: | :--- | :--- |
| Platform Engineering Core Fundamentals | 36% | Partial | Steps 1–3 (Kind, declarative YAML, Helm); CI/GitOps concepts still Gap |
| Platform Observability, Security, and Conformance | 20% | Partial | Steps 4–6 (LGTM, OTel, Kafka traces); policy / secure service comms Gap |
| Continuous Delivery & Platform Engineering | 16% | Gap | Concepts only; ArgoCD + GitHub Actions planned |
| Platform APIs and Provisioning Infrastructure | 12% | Partial | OTel Operator + Instrumentation CR; deeper CRDs / self-service Gap |
| IDPs and Developer Experience | 8% | Gap | No Backstage / service catalog yet |
| Measuring your Platform | 8% | Gap | Golden signals via Grafana; DORA / platform productivity not instrumented |

**Status legend:** Covered = hands-on in repo · Partial = some competencies covered · Gap = study theory and/or add a future experiment

---

## Domain-by-domain

### 1. Platform Engineering Core Fundamentals (36%)

| Competency | Tools / concepts | Repo | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Declarative Resource Management | Kubernetes YAML, `kubectl apply` | `1_kind-cluster/`, `2_kodekloud-voting-app/` | Covered | Manifests as desired state |
| DevOps Practices in Platform Engineering | Platform-as-product, shared tooling | README, AGENTS.md | Partial | Documented mindset; deepen with platform contracts in future labs |
| Application Environments and Infrastructure Concepts | Namespaces, Services, Deployments | Steps 1–3 | Covered | `demo-voting-app`, ingress hosts |
| Platform Architecture and Capabilities | Kind multi-node, ingress, observability stack | Steps 1–6 | Partial | Local platform slice; no full IDP yet |
| Platform Engineering Goals, Objectives, and Approaches | Golden paths, self-service, reduce cognitive load | Docs | Partial | Theory + lab narrative; Backstage later |
| Continuous Integration Fundamentals | Build, test, publish artifacts | `.github/` (planned) | Gap | Registry flow in step 6 is local only |
| Continuous Delivery and GitOps | Git as source of truth, reconcile to cluster | `gitops/` (planned) | Gap | Concepts for exam; ArgoCD for portfolio |

### 2. Platform Observability, Security, and Conformance (20%)

| Competency | Tools / concepts | Repo | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Observability Fundamentals: Traces, Metrics, Logs, and Events | Prometheus, Grafana, Loki, Tempo, OTel | `4_observability-grafana-stack/`, `5_otel-instrumentation/`, `6_kafka-otel-tracing/` | Covered | Strong hands-on evidence for interviews |
| Secure Service Communication | mTLS, mesh, NetworkPolicy | Planned under networking / security | Gap | Ingress today is HTTP localhost demo |
| Policy Engines for Platform Governance | Kyverno, OPA/Gatekeeper | `security/` (planned) | Gap | Exam: know why policy-as-code exists |
| Kubernetes Security Essentials | RBAC, least privilege, Secrets hygiene | AGENTS.md guardrails | Partial | Practices documented; dedicated RBAC lab Gap |
| Security in CI/CD Pipelines | Image scan, signed artifacts, no secrets in Git | CI track + AGENTS.md | Partial | Guardrails yes; pipeline scanning Gap |

**Optional depth (portfolio, not CNPA-required):** Thanos + object storage; Elasticsearch index settings / ILM — see roadmap observability track.

### 3. Continuous Delivery & Platform Engineering (16%)

| Competency | Tools / concepts | Repo | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Continuous Integration Pipelines Overview | GitHub Actions | `.github/` (planned) | Gap | Target: build once, promote image tags |
| Incident Response in Platform Engineering | Runbooks, golden signals, rollback | Lab READMEs (validate/cleanup) | Partial | Practice via troubleshooting notes; formal IR playbooks Gap |
| CI/CD Relationship Fundamentals | CI produces artifacts; CD deploys them | Docs / planned | Gap | Tie GHA → registry → ArgoCD later |
| GitOps Basics and Workflows | Declarative sync, drift detection | `gitops/` (planned) | Gap | ArgoCD |
| GitOps for Application Environments | Per-env overlays, promotion | Planned with ArgoCD + Kustomize | Gap | Multi-env + approval gates on roadmap |

### 4. Platform APIs and Provisioning Infrastructure (12%)

| Competency | Tools / concepts | Repo | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Kubernetes Reconciliation Loop | Controllers, desired vs actual state | Kind workloads, OTel Operator | Partial | Observe via operator rollouts in step 5 |
| APIs for Self-Service Platforms (CRDs) | Custom resources as platform API | `Instrumentation` CR (step 5) | Partial | Good example; app-facing CRDs Gap |
| Infrastructure Provisioning with Kubernetes | Cluster addons via Helm/manifests | Ingress, LGTM, OTel Helm | Covered | Local “platform services” install pattern |
| Kubernetes Operator Pattern for Integration | Operators manage complex software | OpenTelemetry Operator (step 5) | Partial | Extend with more operators later |

### 5. IDPs and Developer Experience (8%)

| Competency | Tools / concepts | Repo | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Simplified Access to Platform Capabilities | Golden paths, templates | Planned `idp/` or Backstage | Gap | Exam: portal / catalog concepts |
| API-Driven Service Catalogs | Catalog entries → provision | Gap | Gap | Theory until Backstage or Crossplane |
| Developer Portals for Platform Adoption | Backstage | Gap | Gap | Minimal Backstage experiment planned on roadmap |
| AI/ML in Platform Automation | Assistants, codegen, ops copilots | Out of scope for now | Gap | Light theory for exam if asked |

### 6. Measuring your Platform (8%)

| Competency | Tools / concepts | Repo | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Platform Efficiency and Team Productivity | Adoption, self-service rate, toil | Gap | Gap | Document metrics you would track |
| DORA Metrics for Platform Initiatives | Deployment frequency, lead time, CFR, MTTR | Gap (Grafana can host later) | Gap | Theory for CNPA; optional dashboard experiment |

---

## Gaps prioritized for PE portfolio (post–step 6)

Order matches interview / job-signal value and CNPA weight overlap:

1. **GitOps (ArgoCD)** — CD domain + PE storytelling
2. **CI (GitHub Actions)** — build once, multi-env promote with approval
3. **Policy / security** — Kyverno or OPA, RBAC, NetworkPolicy
4. **IDP (Backstage)** — DX / service catalog
5. **Platform metrics (DORA)** — measurement domain + SRE fluency

---

## CNPE

Deferred. A separate [`cnpe-syllabus-alignment.md`](cnpe-syllabus-alignment.md) will be added later for the performance-based [CNPE](https://www.cncf.io/training/certification/cnpe/) exam. Do not restructure this repo around CNPE until then.
