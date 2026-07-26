#!/usr/bin/env bash
# Install ArgoCD (non-HA, pinned manifest) into the local Kind cluster.
set -euo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-v3.4.5}"
NAMESPACE="argocd"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require kubectl

echo "==> Creating namespace: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing ArgoCD ${ARGOCD_VERSION}"
# Server-side apply: the ApplicationSet CRD exceeds the 262144-byte
# last-applied-configuration annotation that client-side `apply` writes.
kubectl apply --server-side --force-conflicts -n "${NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "==> Waiting for rollout"
kubectl -n "${NAMESPACE}" wait --for=condition=available --timeout=300s deployment --all

echo
echo "OK — ArgoCD ${ARGOCD_VERSION} installed in namespace '${NAMESPACE}'"
echo
echo "Admin password:"
kubectl -n "${NAMESPACE}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
echo
echo "Access UI:"
echo "  kubectl -n ${NAMESPACE} port-forward svc/argocd-server 8080:443"
echo "  open https://localhost:8080  (user: admin)"
