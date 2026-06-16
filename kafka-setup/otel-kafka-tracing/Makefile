# =============================================================================
# OTel Kafka Tracing – local Kind cluster workflow
#
# Prerequisites:
#   - kind cluster "home-k8-cluster" must be running
#   - Docker (via Colima) must be running
#   - kubectl context must be pointing to home-k8-cluster
#
# Typical flow:
#   make setup-registry   # once per cluster lifecycle
#   make build            # after any code change
#   make push             # push new images to local registry
#   make deploy           # apply all k8s manifests
#   make verify           # check pod health and pull source
#   make verify-traces    # confirm e2e trace stitching in Tempo
#   make logs             # tail producer/consumer/collector logs
#   make cleanup          # remove app workloads
# =============================================================================

REGISTRY       := localhost:5001
CLUSTER_NAME   := home-k8-cluster
NAMESPACE      := otel-kafka-poc
PRODUCER_IMAGE := $(REGISTRY)/otel-kafka-producer:latest
CONSUMER_IMAGE := $(REGISTRY)/otel-kafka-consumer:latest

.PHONY: all setup-registry build push deploy verify verify-traces logs cleanup help

# --------------------------------------------------------------------------
# Default: show help
# --------------------------------------------------------------------------
all: help

# --------------------------------------------------------------------------
# 1) One-time setup: start local registry and wire it to Kind nodes
# --------------------------------------------------------------------------
setup-registry:
	@echo ">>> Setting up Kind local registry at $(REGISTRY)"
	sh scripts/setup-kind-registry.sh

# --------------------------------------------------------------------------
# 2) Build Docker images locally
# --------------------------------------------------------------------------
build:
	@echo ">>> Building producer image: $(PRODUCER_IMAGE)"
	docker build -t $(PRODUCER_IMAGE) ./producer-java
	@echo ">>> Building consumer image: $(CONSUMER_IMAGE)"
	docker build -t $(CONSUMER_IMAGE) ./consumer-python

# --------------------------------------------------------------------------
# 3) Push images to local registry (cluster nodes pull from here)
# --------------------------------------------------------------------------
push:
	@echo ">>> Pushing producer image to local registry"
	docker push $(PRODUCER_IMAGE)
	@echo ">>> Pushing consumer image to local registry"
	docker push $(CONSUMER_IMAGE)
	@echo ">>> Registry catalog:"
	curl -s http://$(REGISTRY)/v2/_catalog

# --------------------------------------------------------------------------
# 4) Deploy all manifests to the cluster
# --------------------------------------------------------------------------
deploy:
	@echo ">>> Deploying OTel Collector and Kafka infra"
	kubectl apply -f manifests/00-otel-collector.yaml
	kubectl apply -f manifests/01-kafka-kraft.yaml
	kubectl apply -f manifests/05-otel-auto-instrumentation.yaml
	kubectl rollout status deployment/otel-collector -n $(NAMESPACE)
	kubectl rollout status deployment/kafka -n $(NAMESPACE)
	@echo ">>> Deploying producer and consumer apps"
	kubectl apply -f manifests/02-producer-deployment.yaml
	kubectl apply -f manifests/03-consumer-deployment.yaml
	kubectl rollout status deployment/kafka-producer -n $(NAMESPACE)
	kubectl rollout status deployment/kafka-consumer -n $(NAMESPACE)

# --------------------------------------------------------------------------
# 5) Redeploy only the app images (after build+push)
# --------------------------------------------------------------------------
redeploy:
	@echo ">>> Restarting producer and consumer deployments"
	kubectl rollout restart deployment/kafka-producer -n $(NAMESPACE)
	kubectl rollout restart deployment/kafka-consumer -n $(NAMESPACE)
	kubectl rollout status deployment/kafka-producer -n $(NAMESPACE)
	kubectl rollout status deployment/kafka-consumer -n $(NAMESPACE)

# --------------------------------------------------------------------------
# 6) Verify pod health and image pull source
# --------------------------------------------------------------------------
verify:
	@echo ">>> Pod status:"
	kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo ">>> Verifying image pull source (must show $(REGISTRY)/...):"
	kubectl describe pod -n $(NAMESPACE) -l app=kafka-producer \
	  | grep -E 'Pulling image|Successfully pulled image'
	kubectl describe pod -n $(NAMESPACE) -l app=kafka-consumer \
	  | grep -E 'Pulling image|Successfully pulled image'
	@echo ""
	@echo ">>> Deployed image refs:"
	kubectl get deployment kafka-producer -n $(NAMESPACE) \
	  -o jsonpath='producer: {.spec.template.spec.containers[0].image}{"\n"}'
	kubectl get deployment kafka-consumer -n $(NAMESPACE) \
	  -o jsonpath='consumer: {.spec.template.spec.containers[0].image}{"\n"}'

# --------------------------------------------------------------------------
# 7) Verify E2E trace stitching via Grafana/Tempo
#    Requires: kubectl -n observability port-forward svc/grafana 3000:3000
# --------------------------------------------------------------------------
verify-traces:
	@echo ">>> Checking E2E trace stitching (Grafana must be port-forwarded on 3000)"
	python3 - <<'PY'
import json, urllib.request, base64, time
uid = 'P214B5B846CF3925F'
auth = base64.b64encode(b'admin:admin').decode()
now = int(time.time()); start = now - 1200
search_url = f'http://127.0.0.1:3000/api/datasources/proxy/uid/{uid}/api/search?limit=100&start={start}&end={now}'
traces = json.loads(urllib.request.urlopen(urllib.request.Request(search_url, headers={'Authorization': f'Basic {auth}'}), timeout=30).read().decode()).get('traces', [])
for t in traces:
    tid = t.get('traceID')
    try:
        obj = json.loads(urllib.request.urlopen(urllib.request.Request(f'http://127.0.0.1:3000/api/datasources/proxy/uid/{uid}/api/traces/{tid}', headers={'Authorization': f'Basic {auth}'}), timeout=30).read().decode())
    except Exception:
        continue
    batches = obj.get('batches', [])
    services = set(); spans = []
    for b in batches:
        attrs = {a.get('key'): (a.get('value', {}).get('stringValue') or a.get('value', {}).get('intValue')) for a in b.get('resource', {}).get('attributes', [])}
        svc = str(attrs.get('service.name', ''))
        if svc: services.add(svc)
        for ss in b.get('scopeSpans', []):
            for s in ss.get('spans', []):
                spans.append((svc, s.get('name'), s.get('spanId'), s.get('parentSpanId')))
    if {'producer-service', 'consumer-service'}.issubset(services):
        producer_ids = {s[2] for s in spans if s[0] == 'producer-service'}
        stitched = [s for s in spans if s[0] == 'consumer-service' and s[3] in producer_ids and s[3]]
        print('TRACE_ID         ', tid)
        print('SERVICES         ', sorted(services))
        print('SPAN_COUNT       ', len(spans))
        print('STITCHED_LINKS   ', len(stitched))
        break
else:
    print('No stitched trace found – wait a moment and retry')
PY

# --------------------------------------------------------------------------
# 8) Tail logs
# --------------------------------------------------------------------------
logs:
	@echo ">>> Producer logs:"
	kubectl logs -f deployment/kafka-producer -n $(NAMESPACE) &
	@echo ">>> Consumer logs:"
	kubectl logs -f deployment/kafka-consumer -n $(NAMESPACE) &
	@echo ">>> Collector logs:"
	kubectl logs -f deployment/otel-collector -n $(NAMESPACE)

logs-producer:
	kubectl logs -f deployment/kafka-producer -n $(NAMESPACE)

logs-consumer:
	kubectl logs -f deployment/kafka-consumer -n $(NAMESPACE)

logs-collector:
	kubectl logs -f deployment/otel-collector -n $(NAMESPACE)

# --------------------------------------------------------------------------
# 9) Full cycle: build → push → redeploy (after code change)
# --------------------------------------------------------------------------
release: build push redeploy verify

# --------------------------------------------------------------------------
# 10) Remove app workloads (leaves infra: Kafka, Collector, OTel Operator)
# --------------------------------------------------------------------------
cleanup:
	kubectl delete -f manifests/03-consumer-deployment.yaml --ignore-not-found
	kubectl delete -f manifests/02-producer-deployment.yaml --ignore-not-found

cleanup-all:
	kubectl delete -f manifests/03-consumer-deployment.yaml --ignore-not-found
	kubectl delete -f manifests/02-producer-deployment.yaml --ignore-not-found
	kubectl delete -f manifests/05-otel-auto-instrumentation.yaml --ignore-not-found
	kubectl delete -f manifests/01-kafka-kraft.yaml --ignore-not-found
	kubectl delete -f manifests/00-otel-collector.yaml --ignore-not-found

# --------------------------------------------------------------------------
# Help
# --------------------------------------------------------------------------
help:
	@echo ""
	@echo "OTel Kafka Tracing – Makefile targets"
	@echo "======================================"
	@echo "  make setup-registry   Start local registry and wire Kind nodes (run once)"
	@echo "  make build            Build producer and consumer Docker images"
	@echo "  make push             Push images to local registry (localhost:5001)"
	@echo "  make deploy           Apply all Kubernetes manifests"
	@echo "  make redeploy         Restart app deployments after image update"
	@echo "  make release          build + push + redeploy + verify (full cycle)"
	@echo "  make verify           Check pod health and confirm registry pull source"
	@echo "  make verify-traces    Confirm E2E trace stitching via Grafana/Tempo API"
	@echo "  make logs             Tail producer, consumer, collector logs"
	@echo "  make logs-producer    Tail producer logs only"
	@echo "  make logs-consumer    Tail consumer logs only"
	@echo "  make logs-collector   Tail collector logs only"
	@echo "  make cleanup          Delete producer/consumer deployments"
	@echo "  make cleanup-all      Delete all app manifests including infra"
	@echo ""
