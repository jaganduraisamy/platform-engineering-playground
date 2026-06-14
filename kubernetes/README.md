# Kubernetes Sandbox

This folder contains Kubernetes-focused experiments for this repository.

## Current Experiment

- `kind-cluster/`: local 3-node kind cluster setup (1 control-plane + 2 workers)
- `kodekloud-voting-app/`: multi-language demo app with UI, Redis, and PostgreSQL
- `observability-grafana-stack/`: simple PoC stack for metrics, logs, and traces

Use the detailed guide in:

- [kind-cluster/README.md](kind-cluster/README.md)
- [kodekloud-voting-app/README.md](kodekloud-voting-app/README.md)
- [observability-grafana-stack/README.md](observability-grafana-stack/README.md)

## Notes

- Keep one README per experiment folder as the source of truth.
- Prefer additive experiments over editing old ones in place.
