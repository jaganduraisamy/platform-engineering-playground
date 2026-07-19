# Step 8: GitHub Actions CI (welcome webapp)

Build the step 7 welcome app **once** and push to **GHCR**.  
Kustomize overlays (`dev` / `uat` / `prod`) deploy that same image into different namespaces — CI does not rebuild per env.

Workflow YAML lives under [`.github/workflows/`](../.github/workflows/) (required by GitHub). This folder is the experiment entrypoint.

## Prerequisites

- [../7_kustomize-webapp/app/](../7_kustomize-webapp/app/)

```bash
ls ../7_kustomize-webapp/app/Dockerfile
ls ../.github/workflows/ci-welcome-webapp.yml
```

## Registry

**GHCR** (`ghcr.io/<owner>/welcome-webapp`). Not `localhost:5001` (unreachable from GitHub runners).

## 1. Validate locally

```bash
chmod +x validate-ci-local.sh
./validate-ci-local.sh
```

## 2. Base CI job (implemented)

| Workflow | What it does |
| :--- | :--- |
| [ci-welcome-webapp.yml](../.github/workflows/ci-welcome-webapp.yml) | Build + push `welcome-webapp:sha-<7chars>` (and `latest` on `main`) |

Triggers: changes under `7_kustomize-webapp/app/**`, or **Actions → Run workflow**.

### Validate on GitHub

1. Run `ci-welcome-webapp` (workflow_dispatch or push a path-touching commit).
2. Packages: `ghcr.io/<owner>/welcome-webapp:sha-xxxxxxx`

## Next (not in this base job)

- Promote same digest into Kind via overlays / ArgoCD
- GitHub Environments + approvals (uat/prod)
- Tag-based / trunk-based promotion flows

## Cleanup

No cluster uninstall. Delete unused GHCR packages from the GitHub UI if needed.
