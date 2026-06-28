#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_NS="${OBS_NS:-observability}"

kubectl delete -f "${SCRIPT_DIR}/02-grafana-ingress.yaml" --ignore-not-found
kubectl delete -f "${SCRIPT_DIR}/lgtm-observability-stack.yaml" --ignore-not-found
kubectl -n kube-system delete deploy kube-state-metrics --ignore-not-found
kubectl -n kube-system delete svc kube-state-metrics --ignore-not-found
kubectl -n kube-system delete sa kube-state-metrics --ignore-not-found
kubectl delete clusterrole kube-state-metrics --ignore-not-found
kubectl delete clusterrolebinding kube-state-metrics --ignore-not-found

echo "LGTM observability stack removed"
