# OTel Kafka Tracing Setup - Working Solutions & Cleanup

**Date:** 2026-06-15  
**Status:** ✅ Complete - All components running with trace context propagation validated

---

## 1. What Was Fixed

### Issue 1: Consumer Pod Crashes with `ModuleNotFoundError: No module named 'pkg_resources'`

**Root Cause:** OpenTelemetry instrumentation wrapper requires `pkg_resources` module, which is only available in setuptools versions <70. Python 3.12 was pulling setuptools 82.0.1 which doesn't include it.

**Solution Applied:**
- **Dockerfile:** Added explicit `setuptools<70` constraint in pip install
- **File:** [consumer-python/Dockerfile](consumer-python/Dockerfile)
- **Change:** `RUN pip install 'setuptools<70' -r requirements.txt`
- **Result:** ✅ Consumer pod now starts successfully and consumes messages with trace context

### Issue 2: Registry UI Showing CORS Error

**Root Cause:** Docker Registry v2 doesn't include CORS headers by default, preventing browser-based UI from communicating with the registry API.

**Solution Applied:**
- **Method:** ConfigMap-based registry configuration with CORS headers
- **File:** [registry/registry-deployment.yaml](registry/registry-deployment.yaml)
- **Changes:**
  - Added `config.yml` ConfigMap with CORS headers
  - Mounted ConfigMap in registry pod
  - Headers: `Access-Control-Allow-Origin: ["*"]`, `Access-Control-Allow-Methods: ["HEAD", "GET", "OPTIONS"]`
- **Result:** ✅ Registry UI now loads and communicates successfully

### Issue 3: Registry UI Cannot Connect to Registry

**Root Cause:** Registry UI was configured with `http://docker-registry:5000` (in-cluster DNS), which browser cannot resolve. Browser needs external/NodePort address.

**Solution Applied:**
- **File:** [registry/registry-ui-deployment.yaml](registry/registry-ui-deployment.yaml)
- **Change:** `REGISTRY_URL: http://127.0.0.1:30501` (NodePort accessible from host)
- **Result:** ✅ Registry UI successfully displays pushed images

### Issue 4: Kubernetes Cluster Stability (k3s Crashes)

**Root Cause:** File descriptor limits too low for k3s inotify operations.

**Solution Applied:**
- **Colima sysctl limits:**
  ```
  fs.inotify.max_user_instances=8192
  fs.inotify.max_user_watches=1048576
  fs.file-max=2097152
  ```
- **k3s systemd override:** `LimitNOFILE=1048576`
- **Result:** ✅ k3s stable, no crashes

---

## 2. Configuration Files - Final State

### ✅ Working Files

**Consumer Application:**
- [consumer-python/Dockerfile](consumer-python/Dockerfile) - Has `setuptools<70` constraint
- [consumer-python/requirements.txt](consumer-python/requirements.txt) - kafka-python==2.2.15 (Python 3.12 compatible)
- [manifests/03-consumer-deployment.yaml](manifests/03-consumer-deployment.yaml) - Clean manifest, no temporary overrides

**Producer Application:**
- [producer-java/Dockerfile](producer-java/Dockerfile) - Multi-stage build with JavaAgent
- [manifests/02-producer-deployment.yaml](manifests/02-producer-deployment.yaml) - Standard deployment

**Registry:**
- [registry/registry-deployment.yaml](registry/registry-deployment.yaml) - ConfigMap-based CORS configuration
- [registry/registry-ui-deployment.yaml](registry/registry-ui-deployment.yaml) - UI with NodePort 30502 and correct registry URL

**OTel Collector:**
- [manifests/00-otel-collector.yaml](manifests/00-otel-collector.yaml) - Standard configuration

**Kafka:**
- [manifests/01-kafka-kraft.yaml](manifests/01-kafka-kraft.yaml) - KRaft mode single broker

---

## 3. Non-Working Attempts (Cleaned Up)

### ❌ Consumer Deployment with Runtime Fix
- **What was tried:** Adding `command: ["sh", "-c", "pip install setuptools && ..."]` in pod spec
- **Why it didn't work:** SSL cert verification failures downloading from PyPI in container
- **Status:** ❌ REMOVED - Solution was to fix Dockerfile instead

### ❌ Environment Variable-Based Registry CORS
- **What was tried:** `REGISTRY_HTTP_HEADERS_Access-Control-Allow-*` environment variables
- **Why it didn't work:** Registry config parser expected YAML format, not flat env variables
- **Status:** ❌ REMOVED - Solution was ConfigMap-based config

### ❌ Registry UI with docker-registry:5000
- **What was tried:** Using in-cluster Kubernetes DNS name for registry
- **Why it didn't work:** Browser cannot resolve in-cluster DNS names
- **Status:** ❌ REMOVED - Solution was NodePort address

---

## 4. Validation Checklist

- ✅ Producer pod running and publishing messages to Kafka
- ✅ Consumer pod running and consuming messages with traceparent headers
- ✅ Trace context propagation working (producer trace ID → consumer trace ID)
- ✅ OTel Collector receiving spans from both producer and consumer
- ✅ Registry accepting image pushes from Docker CLI
- ✅ Registry UI displaying all pushed images
- ✅ Kafka UI (Kafdrop) showing topics and messages
- ✅ All manifests in repo match running configuration

---

## 5. Port Forwarding Commands

```bash
# Registry UI (image browser)
kubectl port-forward -n registry svc/registry-ui 8080:80 &

# Kafka UI (Kafdrop)
kubectl port-forward -n otel-kafka-poc svc/kafdrop 9000:9000 &

# Grafana (traces/logs, if deployed)
kubectl port-forward -n lgtm svc/grafana 3000:3000 &
```

**Direct Access (NodePorts):**
- Registry UI: http://127.0.0.1:30502
- Kafka Registry API: http://127.0.0.1:30501/v2/_catalog
- Kafdrop: http://127.0.0.1:9000

---

## 6. Next Steps (Optional Enhancements)

1. **Persistent Storage** - Replace ephemeral registry storage with PVC
2. **Image Retention** - Add image lifecycle policies for cleanup
3. **Grafana Integration** - Connect Tempo traces to Grafana datasource
4. **CI/CD Pipeline** - Automate image builds and registry pushes
5. **Multi-Broker Kafka** - Scale to 3+ brokers for production
6. **TLS for Registry** - Add HTTPS and authentication to registry

---

## 7. Key Learnings

| Issue | Root Cause | Solution |
|-------|-----------|----------|
| pkg_resources missing | setuptools 82+ doesn't include pkg_resources | Pin setuptools<70 in Dockerfile |
| CORS errors | Registry lacks CORS headers | Use ConfigMap with registry config |
| Browser can't reach registry | In-cluster DNS not accessible from browser | Use NodePort external address |
| k3s crashes | File descriptor limits too low | Apply sysctl limits in Colima |
| Docker push SSL errors | Container can't verify SSL certs | Pre-download certs or use trusted-host |

---

## 8. Files Modified

**Final working state - only these files have been tested:**

1. ✅ [consumer-python/Dockerfile](consumer-python/Dockerfile)
2. ✅ [consumer-python/requirements.txt](consumer-python/requirements.txt)
3. ✅ [manifests/03-consumer-deployment.yaml](manifests/03-consumer-deployment.yaml)
4. ✅ [registry/registry-deployment.yaml](registry/registry-deployment.yaml)
5. ✅ [registry/registry-ui-deployment.yaml](registry/registry-ui-deployment.yaml)
6. ✅ [registry/README.md](registry/README.md) - Documentation updated

**All other files are unchanged and working.**

---

**Setup verified:** 2026-06-15 @ 14:46 UTC  
**All components:** Running ✅  
**Trace propagation:** Validated ✅  
**Clean slate:** Confirmed ✅
