---
name: upgrade-chart
description: "Guide for upgrading FeatBit deployment to new version"
tools: ["read_file", "grep_search", "run_in_terminal"]
agent: edit
---

# Upgrade FeatBit to New Version

This guide is for **users upgrading their deployed FeatBit instance**.

For repo maintainers releasing a new chart version, use the release workflow instead.

---

## Workflow Overview

1. ✅ Check migration requirements
2. ✅ Test locally on Docker Desktop Kubernetes
3. ✅ Deploy to AKS (or your target cluster)

---

## Step 1: Check Migration Requirements

**CRITICAL**: Always check for database migrations before upgrading!

```bash
# Find available migration files
ls migration/

# Read the migration file for target version
# Example: cat migration/RELEASE-v${input:targetVersion:0.9.2}.md
cat migration/RELEASE-v<target-version>.md
```

**Actions Required:**
- [ ] Verify what migration script exists for your target version
- [ ] Review database schema changes
- [ ] Share migration scripts with DBA team for **manual execution**
- [ ] Execute migrations on database (migrations are NOT auto-executed)
- [ ] Create database backup before proceeding

---

## Step 2: Test Locally on Docker Desktop K8s

Test the upgrade in your local environment first!

```bash
# Ensure you're using local context
kubectl config use-context docker-desktop

# Update Helm repo to get latest chart
helm repo update featbit

# Test with local PostgreSQL setup
helm upgrade featbit-test charts/featbit \
  -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml \
  --dry-run

# If dry-run looks good, apply the upgrade
helm upgrade featbit-test charts/featbit \
  -f charts/featbit/examples/standard/featbit-standard-local-pg.yaml

# Monitor rollout
kubectl get pods -w
kubectl logs -l app.kubernetes.io/name=featbit-api --tail=50 -f
```

**Dry-run Explanation**: The `--dry-run` flag simulates the upgrade without applying changes. It shows what Helm would do, helping catch errors before affecting your cluster.

**Verify the upgrade:**
- [ ] All pods running successfully
- [ ] UI accessible at http://localhost:8081 (with port-forward)
- [ ] API responding correctly
- [ ] No errors in logs

---

## Step 3: Deploy to AKS (Production)

After successful local testing, upgrade your AKS deployment.

### 3.1 Azure Login & AKS Access

```bash
# Login to Azure (if not already logged in)
az login

# Verify your subscription
az account show

# Switch subscription if needed
az account set --subscription <subscription-id-or-name>

# Get AKS credentials and merge into kubeconfig
az aks get-credentials \
  --resource-group <your-resource-group> \
  --name <your-aks-cluster-name>

# Verify AKS context is set
kubectl config current-context

# List all available contexts
kubectl config get-contexts

# Switch to AKS context (if needed)
kubectl config use-context <your-aks-context>

# Verify cluster connectivity
kubectl get nodes
```

### 3.2 Execute Helm Upgrade

```bash
# Verify current release
helm list -A | grep featbit

# Update Helm repo
helm repo update featbit

# Dry-run with AKS values (using PUBLISHED chart from repo)
helm upgrade <your-release-name> featbit/featbit \
  -f charts/featbit/examples/aks/featbit-aks-values.local.yaml \
  --namespace <your-namespace> \
  --dry-run

# If dry-run succeeds, execute upgrade
helm upgrade <your-release-name> featbit/featbit \
  -f charts/featbit/examples/aks/featbit-aks-values.local.yaml \
  --namespace <your-namespace>

# Monitor deployment
kubectl get pods -n <your-namespace> -w
```

**Note**: For AKS, use `featbit/featbit` (published chart from Helm repo), not local `charts/featbit` path.

**Post-Upgrade Verification:**
- [ ] All pods transitioned to Running state
- [ ] Check logs for errors: `kubectl logs -n <namespace> -l app.kubernetes.io/name=featbit-api`
- [ ] UI accessible via configured ingress URL
- [ ] API health check: `curl https://api.yourdomain.com/health`
- [ ] Evaluation server responding: `curl https://els.yourdomain.com/health`

---

## Pre-requisites Checklist

Before starting the upgrade:
- [ ] Migration scripts reviewed and executed by DBA
- [ ] Database backup completed
- [ ] Rollback plan prepared (previous Helm revision number noted)
- [ ] External URLs configured correctly in values file
- [ ] External managed services validated (PostgreSQL/MongoDB, Redis for production)
- [ ] Maintenance window scheduled (if needed)

---

## Troubleshooting

**If upgrade fails:**

```bash
# Check Helm revision history
helm history <release-name> -n <namespace>

# Rollback to previous version
helm rollback <release-name> <revision-number> -n <namespace>

# Check pod status and events
kubectl describe pod <pod-name> -n <namespace>
```

**Common Issues:**
- Migration not executed → Check database logs and migration status
- Pods not starting → Check resource limits and node capacity
- Connection errors → Verify external URLs in ConfigMaps/Secrets

---

## Additional Azure Commands

**Switch between contexts:**
```bash
# List all contexts
kubectl config get-contexts

# Switch to local Docker Desktop
kubectl config use-context docker-desktop

# Switch to AKS
kubectl config use-context <your-aks-context>
```

**Azure logout:**
```bash
# Logout from Azure CLI
az logout

# Clear cached credentials
az account clear
```

**Re-authenticate with AKS:**
```bash
# If credentials expired, refresh AKS access
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --overwrite-existing
```
