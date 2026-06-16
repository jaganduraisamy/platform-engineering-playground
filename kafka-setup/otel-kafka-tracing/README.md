# OpenTelemetry Kafka Tracing POC

This POC demonstrates distributed trace context propagation from a Java Kafka producer to a Python Kafka consumer through Kafka message headers.

## 1) Prepare the Kind local registry

This experiment uses a dedicated local registry container for image pulls so the workflow matches CI/CD and GitOps more closely.

From this folder:

```sh
cd kafka-setup/otel-kafka-tracing

chmod +x scripts/setup-kind-registry.sh
./scripts/setup-kind-registry.sh
```

The application manifests are expected to pull images from `localhost:5001`.

## 2) Build and push images

From this folder:

```sh
cd kafka-setup/otel-kafka-tracing

docker build -t localhost:5001/otel-kafka-producer:latest ./producer-java
docker build -t localhost:5001/otel-kafka-consumer:latest ./consumer-python

docker push localhost:5001/otel-kafka-producer:latest
docker push localhost:5001/otel-kafka-consumer:latest

curl http://localhost:5001/v2/_catalog
```

## 3) Deploy infra and apps

Ensure OpenTelemetry Operator is installed in the cluster before applying app manifests.

```sh
kubectl apply -f manifests/00-otel-collector.yaml
kubectl apply -f manifests/01-kafka-kraft.yaml
kubectl apply -f manifests/05-otel-auto-instrumentation.yaml

kubectl rollout status deployment/otel-collector
kubectl rollout status deployment/kafka

kubectl apply -f manifests/02-producer-deployment.yaml
kubectl apply -f manifests/03-consumer-deployment.yaml

kubectl rollout status deployment/kafka-producer
kubectl rollout status deployment/kafka-consumer
```

## 4) Verify messages and trace context

Producer logs:

```sh
kubectl logs -f deployment/kafka-producer
```

Consumer logs (shows traceparent header value):

```sh
kubectl logs -f deployment/kafka-consumer
```

Collector logs (shows OTLP trace spans):

```sh
kubectl logs -f deployment/otel-collector
```

Note: this collector is configured to export traces to Tempo (`tempo.observability.svc.cluster.local:4317`) and to logging.

Verify the pods pulled images from the registry (not local image cache):

```sh
kubectl describe pod -n otel-kafka-poc -l app=kafka-producer | grep -E 'Pulling image|Successfully pulled image'
kubectl describe pod -n otel-kafka-poc -l app=kafka-consumer | grep -E 'Pulling image|Successfully pulled image'
```

Expected image source in events:

```text
localhost:5001/otel-kafka-producer:latest
localhost:5001/otel-kafka-consumer:latest
```

Confirm the deployed image refs:

```sh
kubectl get deployment kafka-producer -n otel-kafka-poc -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get deployment kafka-consumer -n otel-kafka-poc -o jsonpath='{.spec.template.spec.containers[0].image}'
```

They should resolve to `localhost:5001/...`.

## 5) Verify E2E trace stitching in Grafana/Tempo

Port-forward Grafana:

```sh
kubectl -n observability port-forward svc/grafana 3000:3000
```

In another terminal, run:

```sh
python3 - <<'PY'
import json, urllib.request, base64, time

uid = 'P214B5B846CF3925F'  # Tempo datasource UID in this stack
auth = base64.b64encode(b'admin:admin').decode()
now = int(time.time())
start = now - 1200

search_url = f'http://127.0.0.1:3000/api/datasources/proxy/uid/{uid}/api/search?limit=100&start={start}&end={now}'
search_req = urllib.request.Request(search_url, headers={'Authorization': f'Basic {auth}'})
traces = json.loads(urllib.request.urlopen(search_req, timeout=30).read().decode()).get('traces', [])

for t in traces:
  tid = t.get('traceID')
  try:
    trace_url = f'http://127.0.0.1:3000/api/datasources/proxy/uid/{uid}/api/traces/{tid}'
    trace_req = urllib.request.Request(trace_url, headers={'Authorization': f'Basic {auth}'})
    obj = json.loads(urllib.request.urlopen(trace_req, timeout=30).read().decode())
  except Exception:
    continue

  batches = obj.get('batches', [])
  services = set()
  spans = []
  for b in batches:
    attrs = {a.get('key'): (a.get('value', {}).get('stringValue') or a.get('value', {}).get('intValue')) for a in b.get('resource', {}).get('attributes', [])}
    svc = str(attrs.get('service.name', ''))
    if svc:
      services.add(svc)
    for ss in b.get('scopeSpans', []):
      for s in ss.get('spans', []):
        spans.append((svc, s.get('name'), s.get('spanId'), s.get('parentSpanId')))

  if {'producer-service', 'consumer-service'}.issubset(services):
    producer_ids = {s[2] for s in spans if s[0] == 'producer-service'}
    stitched = [s for s in spans if s[0] == 'consumer-service' and s[3] in producer_ids and s[3]]
    print('TRACE_ID', tid)
    print('SERVICES', sorted(services))
    print('SPAN_COUNT', len(spans))
    print('STITCHED_LINKS', len(stitched))
    break
else:
  print('No stitched trace found in the search window')
PY
```

Expected success markers:

```text
SERVICES ['consumer-service', 'producer-service']
STITCHED_LINKS 1
```

## 6) Optional open-source Kafka client smoke test (kcat)

Use kcat to manually publish and consume from the same Kafka service:

```sh
kubectl run kcat-producer --rm -it --restart=Never --image=edenhill/kcat:1.7.1 -- \
  -b kafka-service:9092 -t telemetry-test -P
```

Type a few messages and press Ctrl+D.

```sh
kubectl run kcat-consumer --rm -it --restart=Never --image=edenhill/kcat:1.7.1 -- \
  -b kafka-service:9092 -t telemetry-test -C -o beginning
```

## 7) Cleanup

```sh
kubectl delete -f manifests/03-consumer-deployment.yaml
kubectl delete -f manifests/02-producer-deployment.yaml
kubectl delete -f manifests/05-otel-auto-instrumentation.yaml
kubectl delete -f manifests/01-kafka-kraft.yaml
kubectl delete -f manifests/00-otel-collector.yaml
```

If you want to remove the dedicated local registry container as well:

```sh
docker rm -f kind-registry
```
