---
name: otel-kafka-kind-registry
description: "Use when working on 6_kafka-otel-tracing image delivery, CI/CD, GitOps, Kind registry setup, image pull errors, or deployment manifests. This project uses a dedicated local registry container exposed as localhost:5001 and referenced directly in pod specs. Do not default to kind load or the in-cluster NodePort registry for producer/consumer images unless explicitly debugging."
---

# OTel Kafka Kind Registry Workflow

This project uses the Kind local registry pattern for producer and consumer images.

## Source Of Truth

- Registry host for manifests: `localhost:5001`
- Registry container name: `kind-registry`
- Cluster name: `home-k8-cluster`
- Setup script: `6_kafka-otel-tracing/scripts/setup-kind-registry.sh`

## Required Workflow

1. Run the setup script to ensure the local registry container is running, attached to the `kind` Docker network, and published to the cluster through containerd host aliases.
2. Build images with registry-backed tags:
   - `docker build -t localhost:5001/otel-kafka-producer:latest ./producer-java`
   - `docker build -t localhost:5001/otel-kafka-consumer:latest ./consumer-python`
3. Push images:
   - `docker push localhost:5001/otel-kafka-producer:latest`
   - `docker push localhost:5001/otel-kafka-consumer:latest`
4. Deploy manifests. Pod specs should reference `localhost:5001/...` and use pull-based delivery.

## Validation

- Verify registry contents from host: `curl http://localhost:5001/v2/_catalog`
- Verify tags: `curl http://localhost:5001/v2/otel-kafka-producer/tags/list`
- Verify cluster pull behavior: `kubectl describe pod -n otel-kafka-poc -l app=kafka-producer`

## What To Avoid

- Do not use `127.0.0.1:30501` in app manifests for Kind.
- Do not assume `kind load docker-image` pushes anything into a registry.
- Do not treat the in-cluster registry NodePort as the default app image source for GitOps-oriented workflows.