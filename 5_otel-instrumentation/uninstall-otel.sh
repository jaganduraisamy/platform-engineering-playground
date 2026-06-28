#!/usr/bin/env bash
set -euo pipefail

OBS_NS="${OBS_NS:-observability}"

helm uninstall otel-operator -n "${OBS_NS}" 2>/dev/null || true
kubectl delete -f "$(dirname "$0")/otel-auto-instrumentation.yaml" --ignore-not-found

echo "otel instrumentation removed (LGTM stack in step 4 is unchanged)"
