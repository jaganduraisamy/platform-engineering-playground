#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"

kubectl delete -n "${NAMESPACE}" \
  -f "https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml" \
  --ignore-not-found
kubectl -n "${NAMESPACE}" delete imageupdater welcome-webapp-dev-updater --ignore-not-found
kubectl -n "${NAMESPACE}" delete secret image-updater-git-creds --ignore-not-found

echo "argocd-image-updater removed"
