#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_NS="${OBS_NS:-observability}"
HELM_RELEASE="${HELM_RELEASE:-vmsingle}"

echo "==> Removing VictoriaMetrics ingress"
kubectl delete -f "${SCRIPT_DIR}/02-vm-ingress.yaml" --ignore-not-found

echo "==> Helm uninstall VictoriaMetrics"
helm uninstall "${HELM_RELEASE}" -n "${OBS_NS}" --ignore-not-found

echo
echo "Additive-only, like 10_/11_: this leaves step 4's Prometheus remote_write"
echo "block and the VictoriaMetrics Grafana datasource in place. Prometheus will"
echo "just log failed remote_write sends against a DNS name that no longer"
echo "resolves (harmless, same tolerance as the Thanos objstore Secret)."
echo "To fully revert step 4, remove the 'remote_write:' block and the"
echo "'VictoriaMetrics' datasource entry from"
echo "../4_observability-grafana-stack/lgtm-observability-stack.yaml and re-apply it."
