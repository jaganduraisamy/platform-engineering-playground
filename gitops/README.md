# GitOps (ArgoCD) — next experiment

Not implemented yet. **Depends on CI artifacts from [`.github/`](../.github/).**

Planned flow:

1. GHA builds `ghcr.io/<owner>/otel-kafka-*:sha-<gitsha>`
2. Manifests (or Kustomize overlay) pin that tag — not `localhost:5001`
3. ArgoCD Application syncs Git → Kind/cluster
4. No image build inside ArgoCD

See [`.github/README.md`](../.github/README.md) → “Extension path → ArgoCD / CD”.
