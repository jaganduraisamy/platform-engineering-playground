# Local Docker Registry Setup

This folder contains the in-cluster Docker registry that stores the producer and consumer images.

## Step 1: Create the registry namespace and deploy the registry

```sh
kubectl create namespace registry

kubectl apply -f registry-deployment.yaml

# Wait for it to be ready
kubectl rollout status deployment/docker-registry -n registry
```

## Step 2: Configure Colima Docker insecure registry (one-time)

Colima profile config supports Docker daemon settings directly.

Edit `~/.colima/default/colima.yaml` and set:

```yaml
docker:
  insecure-registries:
    - 127.0.0.1:30501
```

Restart Colima:

```sh
colima stop
colima start
```

## Step 3: Tag and push the images from the host Docker

In another terminal:

```sh
cd 6_kafka-otel-tracing

# Tag images for the registry
docker tag otel-kafka-producer:local 127.0.0.1:30501/otel-kafka-producer:latest
docker tag otel-kafka-consumer:local 127.0.0.1:30501/otel-kafka-consumer:latest

# Push to the registry
docker push 127.0.0.1:30501/otel-kafka-producer:latest
docker push 127.0.0.1:30501/otel-kafka-consumer:latest

# Verify
curl http://127.0.0.1:30501/v2/_catalog
```

Expected output from curl:
```json
{
  "repositories": [
    "otel-kafka-consumer",
    "otel-kafka-producer"
  ]
}
```

## Step 4: Deploy the apps

Now the producer and consumer can pull from the in-cluster registry:

```sh
cd 6_kafka-otel-tracing

kubectl apply -f manifests/02-producer-deployment.yaml -n otel-kafka-poc
kubectl apply -f manifests/03-consumer-deployment.yaml -n otel-kafka-poc

kubectl get pods -n otel-kafka-poc
```

All pods should be `Running`.

**Note:** The producer and consumer manifests are configured to pull from `127.0.0.1:30501`, which is the node-local endpoint for the in-cluster registry service.

## Bonus: Deploy Registry UI (optional)

To view pushed images via a web UI with CORS support:

```sh
# Deploy the registry UI
kubectl apply -f registry-ui-deployment.yaml

# Wait for it to be ready
kubectl rollout status deployment/registry-ui -n registry

# Access the UI via NodePort (recommended)
# URL: http://127.0.0.1:30502
```

Or use port-forward:
```bash
kubectl port-forward -n registry svc/registry-ui 8080:80 &
# Then open: http://localhost:8080
```

**Important:** The registry is configured with CORS headers to allow the browser UI to communicate with the registry API:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: HEAD, GET, OPTIONS`
- `Access-Control-Expose-Headers: Docker-Content-Digest`

This is configured in the `registry-deployment.yaml` ConfigMap and is required for the UI to work.
