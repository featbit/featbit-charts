# Troubleshooting FeatBit Upgrades

Common issues and solutions for FeatBit Helm chart upgrades.

## Rollback Procedures

### If Upgrade Fails

```bash
# Check Helm revision history
helm history <release-name> -n <namespace>
# Shows all revisions with timestamps and status

# Rollback to previous version
helm rollback <release-name> <revision-number> -n <namespace>
# Example: helm rollback featbit 3 -n production

# Check pod status and events
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
# Look for events showing why pod failed

# Check pod logs for startup errors
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # For crashed pods

# Check Helm release status
helm status <release-name> -n <namespace>
```

## Common Issues & Solutions

### Issue: Migration Not Executed

**Symptom**: Pods crash with database errors like "table not found" or "column does not exist"

**Solution**:
- Execute migration scripts manually on database
- Migration files located in `migration/RELEASE-v{version}.md`
- Always review and run migrations BEFORE upgrading chart

**Verification**:
```bash
# Check database schema matches expected version
# Connect to database and verify tables/columns exist
kubectl exec -it <postgres-pod> -- psql -U postgres -d featbit -c "\dt"
```

### Issue: Pods Not Starting

**Symptom**: Pods stuck in Pending, CrashLoopBackOff, or ImagePullBackOff

**Solutions**:

#### Check Resource Limits
```bash
kubectl describe pod <pod-name> -n <namespace>
# Look for: "Insufficient cpu" or "Insufficient memory"

kubectl describe nodes
# Check available resources on nodes
```

#### Verify Image Availability
```bash
# Check if image exists and is accessible
kubectl describe pod <pod-name> -n <namespace>
# Look for: "Failed to pull image" or "ImagePullBackOff"

# Verify image tag in deployment
kubectl get deployment <deployment-name> -n <namespace> -o yaml | grep image:
```

#### Review Pod Events
```bash
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
# Shows recent events with error details
```

### Issue: Connection Errors

**Symptom**: Services can't connect to database, Redis, or each other

**Solutions**:

#### Verify External URLs
```bash
# Check ConfigMaps for correct URLs
kubectl get cm -n <namespace>
kubectl describe cm featbit-config -n <namespace>

# Verify secrets are correctly mounted
kubectl describe pod <pod-name> -n <namespace>
```

#### Test DNS Resolution
```bash
# Test service-to-service DNS
kubectl exec -it <pod-name> -n <namespace> -- nslookup <service-name>

# Example: Test PostgreSQL DNS
kubectl exec -it <api-pod> -n <namespace> -- nslookup postgresql
```

#### Verify Network Policies
```bash
kubectl get networkpolicies -n <namespace>
kubectl describe networkpolicy <policy-name> -n <namespace>
```

### Issue: Ingress Not Working

**Symptom**: Cannot access UI/API via external URL

**Solutions**:

#### Check Ingress Controller
```bash
# Verify ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

#### Verify Ingress Resource
```bash
kubectl describe ingress -n <namespace>
# Check: hosts, paths, backend services

kubectl get ingress -n <namespace> -o yaml
# Verify annotations and TLS configuration
```

#### Check TLS Certificates
```bash
kubectl get secrets -n <namespace>
kubectl describe secret <tls-secret-name> -n <namespace>

# Check certificate expiry
kubectl get certificate -n <namespace>
```

#### Test Internal Service First
```bash
# Port-forward to bypass ingress
kubectl port-forward svc/<service-name> <port>:<port> -n <namespace>

# Example: Test UI service directly
kubectl port-forward svc/featbit-ui 8081:8081 -n production
# Access: http://localhost:8081
```

### Issue: External Database Connection Failure

**Symptom**: Pods log "connection refused" or "authentication failed"

**Solutions**:

#### Verify Connection String
```bash
# Check database connection secret
kubectl get secret -n <namespace>
kubectl get secret <db-secret-name> -n <namespace> -o yaml

# Decode connection string (if base64 encoded)
kubectl get secret <db-secret-name> -n <namespace> -o jsonpath='{.data.connectionString}' | base64 -d
```

#### Check Database Firewall
- Verify database firewall rules allow AKS cluster IPs
- For Azure Database, add AKS outbound IPs to allowed list
- Check Virtual Network rules if using VNet integration

#### Test Connectivity
```bash
# Test port connectivity from pod
kubectl exec -it <pod-name> -n <namespace> -- nc -zv <db-host> <db-port>

# Example: Test PostgreSQL connection
kubectl exec -it <api-pod> -n production -- nc -zv mydb.postgres.database.azure.com 5432
```

#### Verify Database Credentials
```bash
# Test login with credentials
kubectl exec -it <pod-name> -n <namespace> -- psql -h <db-host> -U <username> -d <database>
```

### Issue: High Memory/CPU Usage

**Symptom**: Pods being OOMKilled or throttled

**Solutions**:

#### Check Resource Usage
```bash
# Current resource usage
kubectl top pods -n <namespace>
kubectl top nodes

# Get detailed metrics
kubectl describe node <node-name>
```

#### Adjust Resource Limits
```yaml
# In values file, increase resources
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

#### Enable HPA (Horizontal Pod Autoscaler)
```yaml
# In values file
hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### Issue: Slow Rollout

**Symptom**: Pods take too long to start or update

**Solutions**:

#### Check Init Containers
```bash
# View init container logs
kubectl logs <pod-name> -n <namespace> -c <init-container-name>

# Common init containers in FeatBit:
# - wait-for-postgres
# - wait-for-redis
```

#### Adjust Rollout Strategy
```yaml
# In values file, tune rollout parameters
rollout:
  maxSurge: 50%      # Increase for faster rollout
  maxUnavailable: 0  # Ensure zero downtime
```

#### Check Readiness Probes
```bash
kubectl describe pod <pod-name> -n <namespace>
# Look for: "Readiness probe failed"

# View probe configuration
kubectl get deployment <deployment-name> -n <namespace> -o yaml | grep -A 5 readinessProbe
```

## Debugging Commands

### Comprehensive Status Check
```bash
# All-in-one status check script
helm list -n <namespace>
kubectl get all -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
kubectl top pods -n <namespace>
```

### Log Aggregation
```bash
# Get logs from all API pods
kubectl logs -n <namespace> -l app.kubernetes.io/name=featbit-api --tail=100

# Follow logs in real-time across all replicas
kubectl logs -n <namespace> -l app.kubernetes.io/name=featbit-api --tail=50 -f

# Get logs from crashed pod (previous container)
kubectl logs -n <namespace> <pod-name> --previous
```

### Interactive Debugging
```bash
# Shell into running pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Or use sh if bash not available
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Common debugging commands inside pod:
ps aux                    # Check running processes
env | grep FEATBIT       # Check environment variables
cat /etc/resolv.conf     # Check DNS configuration
nc -zv <host> <port>     # Test network connectivity
```

## Monitoring Best Practices

1. **Before Upgrade**: Note current revision number and pod count
2. **During Upgrade**: Watch pod rollout and logs in real-time
3. **After Upgrade**: Verify health endpoints and run smoke tests
4. **Set Alerts**: Monitor pod restarts, error rates, and response times
5. **Keep Runbook**: Document environment-specific issues and solutions
