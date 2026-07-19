# GitOps (ArgoCD) — next experiment

Not implemented yet.

**Depends on:**

- App + overlays: [../7_kustomize-webapp/](../7_kustomize-webapp/)
- CI images: [../8_github-actions/](../8_github-actions/) → GHCR `sha-*`

Planned flow:

1. GHA builds `ghcr.io/<owner>/welcome-webapp:sha-<gitsha>` once
2. Kustomize overlays keep env-specific `GREETING` / `BG_COLOR` / `ENV_NAME`
3. Overlays (or image transformer) pin the **same** sha for every env
4. ArgoCD syncs Git → Kind; no image rebuild in Argo
