# AGENTS.md

Purpose: This repository is a personal self-study sandbox for platform engineering across DevOps, SRE, platform, and observability domains. Prefer practical, reproducible examples over abstract explanations.

## Project Context
- Read [README.md](README.md) first for scope and tool landscape.
- Prioritize hands-on workflows that can be run locally with minimal assumptions.
- Treat this repo as an experimentation lab: suggest safe iteration paths and rollback steps.

## Working Style For AI Agents
- Be concise and action-oriented. Propose concrete files, commands, and verification steps.
- For any non-trivial change, include a short "why this matters" note.
- Prefer incremental scaffolding over large one-shot generation.
- When introducing a tool, include minimal "start", "validate", and "cleanup" commands.

## Conventions To Follow
- Keep content organized by capability area when created:
  - `terraform/` for IaC experiments
  - `kubernetes/` for manifests, Helm, Kustomize
  - `gitops/` for ArgoCD and delivery patterns
  - `observability/` for metrics, logs, traces, dashboards, SLOs
  - `security/` for Vault, sealed-secrets, RBAC and policy
  - `docs/` for runbooks and architecture notes
- Use one folder per experiment with a local README describing goal, prerequisites, and test steps.
- Pin versions where possible to reduce drift in reproducibility.

## Safety And Security Guardrails
- Never commit plaintext secrets, tokens, kubeconfigs, or Terraform state with credentials.
- Prefer sealed-secrets or external secret managers over inline secret manifests.
- Flag risky defaults (cluster-admin RBAC, open network policies, unauthenticated endpoints).
- Call out blast radius before actions that mutate infra state.

## Platform Engineering Quality Checks
- Kubernetes resources should include requests/limits and probes unless intentionally omitted.
- Observability setups should include basic golden signals and at least one alerting example.
- Terraform/OpenTofu changes should describe state implications and drift risk.
- GitOps examples should explain desired source of truth and reconciliation flow.

## Troubleshooting Expectations
- When diagnosing issues, provide:
  - symptom summary
  - likely root causes
  - exact commands to confirm each hypothesis
  - least-risk fix first
- Prefer deterministic checks over guesswork.

## What To Avoid
- Avoid over-engineering early experiments.
- Avoid hidden magic scripts without explanation.
- Avoid introducing multiple new tools in one change unless explicitly requested.

## If Information Is Missing
- State assumptions explicitly.
- Propose 1-2 reasonable options with tradeoffs.
- Ask focused follow-up questions only when needed to unblock implementation.
