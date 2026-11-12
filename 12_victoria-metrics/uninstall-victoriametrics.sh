#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_NS="${OBS_NS:-observability}"

echo "==> Removing VictoriaMetrics ingress"
kubectl delete -f "${SCRIPT_DIR}/03-vm-cluster-ingress.yaml" --ignore-not-found

echo "==> Removing VictoriaMetrics cluster mode (vminsert/vmstorage/vmselect/vmalert)"
kubectl delete -f "${SCRIPT_DIR}/vm-cluster-stack.yaml" --ignore-not-found

echo
echo "Additive-only, like 10_/11_: this leaves step 4's Prometheus with its"
echo "remote_write block (vminsert) and the VictoriaMetrics Grafana datasource"
echo "in place. Prometheus will just"
echo "log failed remote_write sends against DNS names that no longer resolve"
echo "(harmless, same tolerance as the Thanos objstore Secret)."
echo "To fully revert step 4, remove the 'remote_write:' entry and the"
echo "VictoriaMetrics datasource entry from"
echo "../4_observability-grafana-stack/lgtm-observability-stack.yaml and re-apply it."
