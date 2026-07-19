# Step 7: Kustomize + welcome webapp

Python welcome page whose **greeting**, **background color**, and **environment name** come from env vars.  
Kustomize overlays (`dev` / `uat` / `prod`) change those values — **not** a different container image per env.

## Why this matters (PE / CI later)

| Concern | This step |
| :--- | :--- |
| Build once, deploy many | One image `welcome-webapp:local` loaded into Kind |
| Env-specific UX | Overlays patch `ENV_NAME`, `BG_COLOR`, `GREETING` |
| Next (step 8) | GHA builds the **same** app → GHCR `sha-*`; overlays later pin that tag |

Do **not** bake colors into three Docker images. That breaks “build once.”

## Prerequisites

- Kind cluster: [../1_kind-cluster/](../1_kind-cluster/)
- `docker`, `kind`, `kubectl`

```bash
kubectl config current-context   # kind-home-k8-cluster
```

## Layout

```text
7_kustomize-webapp/
  app/                 # Flask app + Dockerfile
  kustomize/
    base/
    overlays/dev|uat|prod/
  deploy-webapp.sh
  uninstall-webapp.sh
```

| Overlay | Namespace | Background | Greeting |
| :--- | :--- | :--- | :--- |
| `dev` | `welcome-dev` | red (`#dc2626`) | Hello from DEV |
| `uat` | `welcome-uat` | blue (`#2563eb`) | Hello from UAT |
| `prod` | `welcome-prod` | green (`#166534`) | Hello from PROD (2 replicas) |

## 1. Deploy an environment

```bash
chmod +x deploy-webapp.sh uninstall-webapp.sh
./deploy-webapp.sh dev
# ./deploy-webapp.sh uat
# ./deploy-webapp.sh prod
```

## 2. Validate

```bash
kubectl -n welcome-dev get pods
kubectl -n welcome-dev port-forward svc/welcome-webapp 8080:80
```

Open http://localhost:8080 — red page, “Hello from DEV”, environment badge `dev`.

Render without apply:

```bash
kubectl kustomize kustomize/overlays/dev
```

## Cleanup

```bash
./uninstall-webapp.sh dev          # one env
./uninstall-webapp.sh              # all envs
```

## Next step

[../8_github-actions/](../8_github-actions/) — CI builds this app to **GHCR**; promote the same digest across envs (Approvals / trunk / tags). GitOps (ArgoCD) comes after.
