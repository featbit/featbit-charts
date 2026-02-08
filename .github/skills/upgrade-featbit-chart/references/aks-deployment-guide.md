# AKS Production Deployment Guide

Complete workflow for deploying FeatBit upgrades to Azure Kubernetes Service (AKS).

## Prerequisites

- Azure CLI installed and configured
- kubectl >= 1.23
- Helm >= 3.7.0
- AKS cluster access
- Successful local testing completed

## Azure Login & AKS Access

```bash
# Login to Azure (if not already logged in)
az login
# Opens browser for authentication

# Verify your subscription
az account show

# List all subscriptions
az account list --output table

# Switch subscription if needed
az account set --subscription <subscription-id-or-name>

# Get AKS credentials and merge into kubeconfig
az aks get-credentials \
  --resource-group <your-resource-group> \
  --name <your-aks-cluster-name>
# This adds AKS context to ~/.kube/config

# Verify AKS context is set
kubectl config current-context
# Output: <your-aks-context>

# List all available contexts
kubectl config get-contexts
#   CURRENT   NAME              CLUSTER           AUTHINFO
#   *         my-aks-cluster    my-aks-cluster    clusterUser_xxx
#             docker-desktop    docker-desktop    docker-desktop

# Switch to AKS context (if needed)
kubectl config use-context <your-aks-context>

# Verify cluster connectivity and permissions
kubectl get nodes
kubectl auth can-i create deployments
```

## Execute Helm Upgrade on AKS

```bash
# Verify current release
helm list -A | grep featbit
# Note the current namespace and release name

# Update Helm repo to get latest chart
helm repo update featbit

# Dry-run with AKS values (using PUBLISHED chart from repo)
helm upgrade <your-release-name> featbit/featbit \
  -f charts/featbit/examples/aks/featbit-aks-values.local.yaml \
  --namespace <your-namespace> \
  --dry-run
# Review output carefully for any issues

# If dry-run succeeds, execute actual upgrade
helm upgrade <your-release-name> featbit/featbit \
  -f charts/featbit/examples/aks/featbit-aks-values.local.yaml \
  --namespace <your-namespace>

# Monitor deployment rollout
kubectl get pods -n <your-namespace> -w
```

## ⚠️ IMPORTANT: Chart Source for AKS

- For AKS, use `featbit/featbit` (published chart from Helm repo)
- NOT `charts/featbit` (local path - only for local testing)
- Ensure your values file has correct external URLs configured

## Post-Upgrade Verification

```bash
# Check all pods transitioned to Running state
kubectl get pods -n <your-namespace>
# All should show STATUS: Running, READY: 1/1

# Check deployment rollout status
kubectl rollout status deployment/featbit-api -n <your-namespace>
kubectl rollout status deployment/featbit-els -n <your-namespace>
kubectl rollout status deployment/featbit-ui -n <your-namespace>
kubectl rollout status deployment/featbit-da-server -n <your-namespace>

# Check for errors in logs
kubectl logs -n <your-namespace> -l app.kubernetes.io/name=featbit-api --tail=100
kubectl logs -n <your-namespace> -l app.kubernetes.io/name=featbit-els --tail=100

# Verify ingress/service endpoints
kubectl get ingress -n <your-namespace>
kubectl get svc -n <your-namespace>

# Test API health endpoint
curl https://api.yourdomain.com/health
# Expected: {"status":"healthy"}

# Test Evaluation Server health
curl https://els.yourdomain.com/health
# Expected: {"status":"healthy"}

# Access UI in browser
# https://ui.yourdomain.com
```

## Post-Upgrade Checklist

- [ ] All pods transitioned to Running state (no restarts)
- [ ] Check logs for errors in API, ELS, DA Server
- [ ] UI accessible via configured ingress URL
- [ ] API health check returns 200 OK
- [ ] Evaluation server health check returns 200 OK
- [ ] Can login to UI successfully
- [ ] Existing feature flags visible and functional
- [ ] SDK connections working (if applicable)
- [ ] No elevated error rates in monitoring

## Context Management

```bash
# List all Kubernetes contexts
kubectl config get-contexts
#   CURRENT   NAME              CLUSTER
#   *         my-aks-cluster    my-aks-cluster
#             docker-desktop    docker-desktop

# Switch to local Docker Desktop
kubectl config use-context docker-desktop

# Switch back to AKS
kubectl config use-context <your-aks-context>

# Show current context
kubectl config current-context
```

## AKS Credentials Management

```bash
# Refresh AKS credentials (if expired)
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --overwrite-existing

# Get admin credentials (for troubleshooting)
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --admin \
  --overwrite-existing

# List AKS clusters in subscription
az aks list --output table
```

## Azure Authentication

```bash
# Check current Azure login status
az account show

# Logout from Azure CLI
az logout

# Clear all cached credentials
az account clear

# Re-login with specific tenant
az login --tenant <tenant-id>

# Login with service principal (for CI/CD)
az login --service-principal \
  --username <app-id> \
  --password <password-or-cert> \
  --tenant <tenant-id>
```

## Best Practices

1. **Always test locally first** - Catch issues before production
2. **Use dry-run extensively** - Simulate changes before applying
3. **External URLs mandatory** - Set `apiExternalUrl` and `evaluationServerExternalUrl`
4. **Managed services** - Use external PostgreSQL/MongoDB, Redis for production
5. **Have rollback plan** - Know your previous Helm revision number
6. **Monitor during upgrade** - Watch pod logs and status in real-time
