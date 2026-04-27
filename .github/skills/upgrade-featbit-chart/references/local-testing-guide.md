# Local Testing Guide - Docker Desktop Kubernetes

Complete workflow for testing FeatBit upgrades locally before production deployment.

## Prerequisites

- Docker Desktop with Kubernetes enabled
- Helm >= 3.7.0
- kubectl >= 1.23
- Local chart repository cloned

## Setup Local Context

```bash
# Switch to Docker Desktop K8s context
kubectl config use-context docker-desktop

# Verify local context
kubectl config current-context
# Output: docker-desktop

# Check local cluster nodes
kubectl get nodes
```

## Execute Local Upgrade

```bash
# Update Helm repo to get latest chart version
helm repo update featbit

# Dry-run with local PostgreSQL setup (simulate upgrade)
helm upgrade featbit-test charts/featbit \
  -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml \
  --dry-run

# Review dry-run output for any warnings or errors
# If dry-run looks good, apply the upgrade

helm upgrade featbit-test charts/featbit \
  -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml

# Monitor rollout in real-time
kubectl get pods -w
```

## Verify Local Upgrade

```bash
# Check all pods are running
kubectl get pods
# All pods should show STATUS: Running

# Check API logs for errors
kubectl logs -l app.kubernetes.io/name=featbit-api --tail=50 -f

# Port-forward to access UI locally
kubectl port-forward service/featbit-ui 8081:8081

# In another terminal, test API health
kubectl port-forward service/featbit-api 5000:5000
curl http://localhost:5000/health

# Test Evaluation Server
kubectl port-forward service/featbit-els 5100:5100
curl http://localhost:5100/health
```

## Verification Checklist

- [ ] All pods running successfully (no CrashLoopBackOff)
- [ ] UI accessible at http://localhost:8081 (with port-forward)
- [ ] API health endpoint returns 200 OK
- [ ] Evaluation server responding correctly
- [ ] No errors in API/ELS logs
- [ ] Can login and see existing feature flags

## Local Testing Configurations

### Standard Tier with Local PostgreSQL
```bash
helm upgrade featbit-test charts/featbit \
  -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml
```

### Standard Tier with Local MongoDB
```bash
helm upgrade featbit-test charts/featbit \
  -f charts/featbit/examples/standard/featbit-standard-local-mongo.yaml
```

### Pro Tier with Local PostgreSQL
```bash
helm upgrade featbit-test charts/featbit \
  -f charts/featbit/examples/pro/featbit-pro-local-pg.yaml
```

## Troubleshooting Local Tests

### Pods Not Starting
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check resource limits
kubectl top nodes
kubectl top pods

# View all events
kubectl get events --sort-by='.lastTimestamp'
```

### Database Connection Issues
```bash
# Check PostgreSQL pod logs
kubectl logs -l app.kubernetes.io/name=postgresql --tail=100

# Test database connectivity from API pod
kubectl exec -it <api-pod-name> -- nc -zv postgresql 5432
```

### Port Forward Not Working
```bash
# List all services
kubectl get svc

# Check service endpoints
kubectl get endpoints

# Try alternative port-forward syntax
kubectl port-forward deployment/featbit-ui 8081:8081
```

## Important Notes

**If local test fails**: Do NOT proceed to production. Debug and fix issues first.

**Chart Sources**: 
- Local testing uses local chart path: `charts/featbit`
- Never mix local and published charts in the same environment
