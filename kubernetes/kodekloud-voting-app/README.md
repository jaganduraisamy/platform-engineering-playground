# KodeKloud-Style Demo: Example Voting App on kind

This experiment deploys the open-source Example Voting App (widely used in KodeKloud labs).

It is a good match for your next phase because it includes:
- UI services (`vote` and `result`)
- Multi-language microservices
- Redis for message queue/cache behavior
- PostgreSQL for persistent vote results

Reference project:
- https://github.com/dockersamples/example-voting-app

## Architecture

Services used in this deployment:
- `vote` (Python web UI): users cast a vote
- `redis`: stores incoming votes
- `worker` (.NET): reads from Redis and writes to Postgres
- `db` (PostgreSQL): stores vote counts
- `result` (Node.js web UI): displays live results

## Prerequisites

- Existing kind cluster from `kubernetes/kind-cluster`
- `kubectl` configured to your kind context

Verify context:

```bash
kubectl config current-context
```

You should see `kind-home-k8-cluster`.

## Deploy

From this folder, run:

```bash
kubectl apply -f deployment.yaml
```

Check rollout status:

```bash
kubectl -n demo-voting-app get pods
kubectl -n demo-voting-app get svc
```

## Access The UIs

Use port-forward for local access on macOS + kind:

```bash
kubectl -n demo-voting-app port-forward svc/vote 8080:80
kubectl -n demo-voting-app port-forward svc/result 8081:80
```

Open:
- http://localhost:8080 (vote UI)
- http://localhost:8081 (result UI)

## Test The Flow

1. Open vote UI and cast a vote.
2. Open result UI and confirm counts update.
3. Repeat with other option to verify end-to-end processing.

## Clean Up

```bash
kubectl delete -f deployment.yaml
```

## Notes

- This manifest uses `emptyDir` for Postgres storage, so data is ephemeral.
- For durable storage, replace with a `PersistentVolumeClaim`.
- Image tags are set to stable demo tags. If an image pull fails, switch to available tags from the upstream repo.
