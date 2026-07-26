#!/usr/bin/env bash
# Install Argo CD Image Updater (v1.x, CRD-based) into the argocd namespace.
set -euo pipefail

NAMESPACE="argocd"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require kubectl

echo "==> Installing argocd-image-updater into namespace: ${NAMESPACE}"
# Server-side apply: same reason as install-argocd.sh — avoid the
# last-applied-configuration annotation size limit on large CRDs.
kubectl apply --server-side --force-conflicts -n "${NAMESPACE}" \
  -f "https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml"

echo "==> Waiting for rollout"
kubectl -n "${NAMESPACE}" wait --for=condition=available --timeout=180s deployment/argocd-image-updater-controller

echo
echo "OK — argocd-image-updater installed in namespace '${NAMESPACE}'"
echo "Next: create the git write-back credential secret, then apply image-updater.yaml — see README."
