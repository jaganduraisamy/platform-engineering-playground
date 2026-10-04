#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_NS="${OBS_NS:-observability}"

echo "==> Removing VictoriaMetrics ingress"
kubectl delete -f "${SCRIPT_DIR}/02-vm-ingress.yaml" --ignore-not-found
kubectl delete -f "${SCRIPT_DIR}/03-vm-cluster-ingress.yaml" --ignore-not-found

echo "==> Removing VictoriaMetrics cluster mode (vminsert/vmstorage/vmselect/vmalert)"
kubectl delete -f "${SCRIPT_DIR}/vm-cluster-stack.yaml" --ignore-not-found

echo "==> Removing vmsingle"
kubectl delete -f "${SCRIPT_DIR}/vmsingle-stack.yaml" --ignore-not-found

echo
echo "Additive-only, like 10_/11_: this leaves step 4's Prometheus with both"
echo "remote_write blocks (vmsingle + vminsert) and both Grafana datasources"
echo "(VictoriaMetrics, VictoriaMetrics Cluster) in place. Prometheus will just"
echo "log failed remote_write sends against DNS names that no longer resolve"
echo "(harmless, same tolerance as the Thanos objstore Secret)."
echo "To fully revert step 4, remove both 'remote_write:' entries and both"
echo "VictoriaMetrics datasource entries from"
echo "../4_observability-grafana-stack/lgtm-observability-stack.yaml and re-apply it."
