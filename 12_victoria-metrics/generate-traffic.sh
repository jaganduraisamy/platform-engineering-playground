#!/usr/bin/env bash
# Drives the voting app through its ingress so the OTel auto-instrumentation
# (5_otel-instrumentation/) emits real spans, which otel-gateway-collector's
# span_metrics connector turns into calls_total/duration_* series, which
# step 4's Prometheus scrapes and remote_writes into VictoriaMetrics.
set -euo pipefail

VOTE_HOST="${VOTE_HOST:-demo-vote.localhost}"
REQUESTS="${REQUESTS:-200}"

echo "==> Sending ${REQUESTS} votes to http://${VOTE_HOST}/"
for i in $(seq 1 "${REQUESTS}"); do
  choice=$([ $((i % 2)) -eq 0 ] && echo a || echo b)
  curl -s -o /dev/null -H "Host: ${VOTE_HOST}" -X POST --data "vote=${choice}" "http://127.0.0.1/" || true
  curl -s -o /dev/null -H "Host: ${VOTE_HOST}" "http://127.0.0.1/result/" || true
  sleep 0.1
done
echo "OK — traffic sent, spans/spanmetrics should land within ~15-30s"
