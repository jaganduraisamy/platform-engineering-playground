#!/usr/bin/env bash
# Local check: same Docker context as .github/workflows/ci-welcome-webapp.yml
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require docker

echo "==> Build welcome-webapp (context: 7_kustomize-webapp/app)"
docker build -t welcome-webapp:ci-local "${ROOT}/7_kustomize-webapp/app"

echo
echo "OK — welcome-webapp:ci-local"
echo "GHA workflow: .github/workflows/ci-welcome-webapp.yml → ghcr.io/<owner>/welcome-webapp:sha-*"
echo "Envs (dev/uat/prod) stay in Kustomize overlays — one image, many namespaces."
