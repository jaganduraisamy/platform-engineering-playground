#!/usr/bin/env bash
# Local check: build welcome webapp (and optionally Kafka images).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require docker

echo "==> Build welcome-webapp (step 7 app — primary CI/CD demo)"
docker build -t welcome-webapp:ci-local "${ROOT}/7_kustomize-webapp/app"

if [ "${INCLUDE_KAFKA:-false}" = "true" ]; then
  echo
  echo "==> Build Kafka images (optional)"
  docker build -t otel-kafka-producer:ci-local "${ROOT}/6_kafka-otel-tracing/producer-java"
  docker build -t otel-kafka-consumer:ci-local "${ROOT}/6_kafka-otel-tracing/consumer-python"
fi

echo
echo "OK — welcome-webapp:ci-local"
echo "Remote CI will push to ghcr.io (not localhost:5001)."
echo "Kustomize overlays (step 7) keep one image and change ENV_NAME / colors per env."
