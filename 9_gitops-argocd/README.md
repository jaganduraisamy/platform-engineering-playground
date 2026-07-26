# Step 9: GitOps (ArgoCD)

Install the ArgoCD controller and hand it the 3 namespaces already deployed manually in step 7 (`welcome-dev`, `welcome-uat`, `welcome-prod`).

## Why this matters (PE)

| Concern | This step |
| :--- | :--- |
| Source of truth | Git, not `kubectl apply` from a laptop |
| Build once, deploy many | Same GHCR `sha-*` image (step 8) promoted via overlay, not rebuilt |
| Reconciliation | ArgoCD continuously diffs cluster vs Git, self-heals drift |

## Prerequisites

- Kind cluster running: [../1_kind-cluster/](../1_kind-cluster/)
- Overlays pinned to a real image: [../7_kustomize-webapp/kustomize/overlays/](../7_kustomize-webapp/kustomize/overlays/) — each `kustomization.yaml` `images:` block points at `ghcr.io/jaganduraisamy/welcome-webapp:sha-*` (public package, no pull secret needed)
- CI image published: [../8_github-actions/](../8_github-actions/) → [package page](https://github.com/jaganduraisamy/platform-engineering-sandbox/pkgs/container/welcome-webapp)

```bash
kubectl config current-context   # kind-home-k8-cluster
kubectl get ns | grep welcome    # welcome-dev / welcome-uat / welcome-prod
```

## 1. Install ArgoCD

```bash
chmod +x install-argocd.sh uninstall-argocd.sh
./install-argocd.sh
```

Pinned to `v3.4.5`, non-HA manifest — one cluster, no value overrides needed, so no Helm chart (see [`1_kind-cluster/README.md`](../1_kind-cluster/README.md#metrics-api-metrics-server) for the same reasoning applied to metrics-server).

## 2. Access the UI

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open https://localhost:8080 — user `admin`, password printed by `install-argocd.sh` (or re-fetch: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`).

## 3. Validate controller

```bash
kubectl -n argocd get pods
kubectl -n argocd get deploy
```

All deployments `Available`.

## 4. Deploy the Applications

`apps/{dev,uat,prod}-app.yaml` — one plain `Application` CR per env, each pointing at `../7_kustomize-webapp/kustomize/overlays/<env>`, `automated` sync (prune + selfHeal). No App-of-Apps, no ApplicationSet — 3 static envs don't earn that abstraction yet (see concepts note below).

```bash
kubectl apply -f apps/
kubectl -n argocd get applications
```

Each `Application` takes over the namespace step 7's `deploy-webapp.sh` created manually — on first sync it flips the running Deployment from `welcome-webapp:local` to the pinned `ghcr.io/jaganduraisamy/welcome-webapp:sha-*` image. That's the manual→GitOps handover moment.

**`targetRevision` currently points at `lab/gitops-argocd`** (this branch, since the config isn't merged yet) — switch all 3 to `main` once merged, or ArgoCD keeps tracking a branch that may get deleted.

Config lives in this repo (`9_gitops-argocd/apps/`, sourcing `7_kustomize-webapp/kustomize/overlays/`) rather than a separate `welcomeapp-gitops` repo — no cross-repo push credentials needed for a single-person sandbox. Revisit only if this needs its own RBAC/promotion boundary later.

### Concepts (why not App-of-Apps / ApplicationSet)

- **Application** — one CRD: (repo path + revision) → (cluster + namespace) + sync policy. What's used here.
- **App-of-Apps** — an `Application` whose source is a directory of *other* `Application` manifests, so ArgoCD bootstraps its own app inventory from Git. Solves "many unrelated apps across teams, one entrypoint." Doesn't fit 1 app × 3 envs.
- **ApplicationSet** — separate controller (already installed, running as `argocd-applicationset-controller`) that *generates* Applications from a generator (`list`, `git` directory glob, `cluster`, `matrix`). A `git` directory generator over `overlays/*` would collapse these 3 files into 1 template and auto-pick-up new overlay folders. Natural upgrade once the plain-`Application` version is understood and working — not needed to start.

## Validate deployment

```bash
kubectl -n argocd get applications -o wide          # expect Synced + Healthy x3
kubectl -n welcome-dev get deploy welcome-webapp -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Image should now read `ghcr.io/jaganduraisamy/welcome-webapp:sha-*`, not `:local`.

## Cleanup

```bash
kubectl delete -f apps/
./uninstall-argocd.sh
```

## Next step

Once working: collapse `apps/*.yaml` into a single `ApplicationSet` (git directory generator), then approval gates / promotion flow across envs.
