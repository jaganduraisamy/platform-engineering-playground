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

## 5. Promotion gate (uat / prod)

**No peer-reviewed gate is possible solo.** GitHub blocks self-approval on your own PR (branch protection) *and* blocks a workflow's triggering user from approving that same run via an Environment's required-reviewer rule. Neither is demonstrable with one GitHub account — don't bother setting up "Required reviewers," it'll never let you approve your own run.

**What's real and solo-compatible instead** — all in [`.github/workflows/promote-overlay.yml`](../.github/workflows/promote-overlay.yml), all automated, no human reviewer required:

1. **Deliberate trigger only** — `workflow_dispatch` with explicit `environment` + `tag` inputs. Nothing reaches uat/prod from an ordinary push; promotion only happens if someone consciously runs this workflow with those exact values.
2. **Tag existence check** — queries GHCR (anonymous token, same trick used to confirm the package is public) and fails the job if the given tag doesn't exist, before touching any file.
3. **Render validation** — `kubectl kustomize` must succeed and produce output before the commit happens. Note: no `kubectl apply --dry-run` here — tested and confirmed it still requires a reachable API server even with `--validate=false`, and GitHub-hosted runners have no path to this local Kind cluster. So this catches broken overlay syntax/patches, not full K8s schema errors.

ArgoCD (`automated: true` on all 3 `Application`s) applies the change the moment it's pushed — no ArgoCD-side gate either; delaying *who* can click sync doesn't gate the change itself, only who applies an already-merged one.

**Optional extra guardrails (GitHub UI, no reviewer needed, not demonstrated here):** an Environment "wait timer" (mandatory pause + cancel window before the job proceeds) and a "deployment branches" restriction (e.g. only `main` may deploy to the `prod` Environment). Both live in Settings → Environments, both work without a second person — worth adding once this is on `main`.

**Promote:**

```text
Actions → promote-overlay → Run workflow
  environment: uat
  tag: sha-980b8a6
```

Job verifies the tag, renders the overlay, commits, pushes → ArgoCD auto-syncs. Repeat with `environment: prod` once verified in `uat`.

## 6. Image Updater (dev only)

[`argocd-image-updater`](https://argocd-image-updater.readthedocs.io/) (v1.x, CRD-based — not the older annotation config some guides still show) watches GHCR for new builds and writes the new tag back into Git itself, closing the loop CI → registry → Git → cluster without a manual overlay edit.

**Scoped to `dev` only, deliberately.** It tracks the `:latest` tag's digest (`updateStrategy: digest` — your tags are `sha-*`, not semver, so the default `semver` strategy doesn't apply) and writes straight back to Git. Doing that on `uat`/`prod` would bypass `promote-overlay.yml` entirely — every CI build would auto-deploy everywhere. `dev` has no such gate to bypass.

### Install

```bash
chmod +x install-image-updater.sh uninstall-image-updater.sh
./install-image-updater.sh
```

### Git write-back credential (manual, one-time)

Fine-grained PAT, scoped to just this repo:

1. GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → New token.
2. Repository access: only `platform-engineering-sandbox`.
3. Permissions: **Contents: Read and write**. Nothing else.

```bash
kubectl -n argocd create secret generic image-updater-git-creds \
  --from-literal=username=jaganduraisamy \
  --from-literal=password='<paste PAT here>'
```

`writeBackConfig.method` is validated by a CRD regex (`^(argocd|git|git:[a-zA-Z0-9][a-zA-Z0-9-._/:]*)$`) that does **not** allow a `#field` suffix — unlike `pullSecret`'s `secret:<ns>/<name>#<field>` syntax. So the secret's key names must match a fixed convention instead of being pointed at explicitly: **confirmed live** — `username` + `password` (matching ArgoCD's own repository-credential secret schema) is correct.

### Apply

```bash
kubectl apply -f image-updater.yaml
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-image-updater -f
```

`gitConfig.writeBackTarget` is left unset — **confirmed live**: it doesn't need a value for Kustomize apps. Instead of editing `kustomization.yaml` directly, the controller writes a `.argocd-source-<app-name>.yaml` side-file into the overlay directory (here: `kustomize/overlays/dev/.argocd-source-welcome-webapp-dev.yaml`), containing:

```yaml
kustomize:
  images:
  - welcome-webapp=ghcr.io/jaganduraisamy/welcome-webapp:latest@sha256:<digest>
```

ArgoCD's repo-server auto-merges this as a Kustomize image override at render time — that's a built-in ArgoCD convention, not something `kustomization.yaml` needs to reference. The commit author is `argocd-image-updater <noreply@argoproj.io>`, commit message `build: automatic update of welcome-webapp-dev`.

### Validate

```bash
kubectl get imageupdater -n argocd
kubectl -n argocd get application welcome-webapp-dev -o wide      # Synced + Healthy at the bot's commit
kubectl -n welcome-dev get deploy welcome-webapp -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Image should read `ghcr.io/jaganduraisamy/welcome-webapp:latest@sha256:...` — digest-pinned, not `:sha-*`. Confirmed working end-to-end: push → CI builds multi-arch → GHCR `:latest` gets a new digest → Image Updater detects it within its 2min poll interval → commits the `.argocd-source-*.yaml` override → ArgoCD auto-syncs → pod updated. No `promote-overlay.yml` run needed for `dev`.

## Cleanup

```bash
kubectl delete -f apps/
./uninstall-argocd.sh
./uninstall-image-updater.sh
```

## Next step

Collapse `apps/*.yaml` into a single `ApplicationSet` (git directory generator) — the approval gate above is unaffected either way, since it lives in GitHub, not in how the `Application`/`ApplicationSet` objects are structured.
