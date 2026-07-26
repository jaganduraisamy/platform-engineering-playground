#!/usr/bin/env bash
set -euo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-v3.4.5}"
NAMESPACE="argocd"

kubectl delete -n "${NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" --ignore-not-found
kubectl delete namespace "${NAMESPACE}" --ignore-not-found

echo "ArgoCD removed"
