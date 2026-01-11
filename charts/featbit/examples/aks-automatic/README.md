# FeatBit AKS Deployment with External PostgreSQL and Redis

This example demonstrates deploying FeatBit to AKS Automatic with:
- **External Azure PostgreSQL Flexible Server**
- **External Azure Redis Cache**
- **Azure Key Vault CSI Driver** for secure credential management

## Architecture

```
Azure Key Vault (PostgreSQL + Redis credentials)
    ↓ (CSI Driver)
Kubernetes Secrets
    ↓
FeatBit Pods (UI, API, ELS, DA-Server)
```

## Prerequisites

- AKS Automatic cluster (Key Vault CSI Driver addon pre-enabled)
- External Azure PostgreSQL Flexible Server
- External Azure Redis Cache
- Azure CLI and kubectl configured
- Helm 3.7.0 or later

## Step-by-Step Setup

### 1. Store Database Credentials in Azure Key Vault

Store your PostgreSQL and Redis passwords in Azure Key Vault. Secret names must match those in `keyvault-secret-provider.yaml`:

```powershell
# Store PostgreSQL password
az keyvault secret set --vault-name <your-keyvault> --name "pg-secret" --value "<your-postgres-password>"

# Store Redis password
az keyvault secret set --vault-name <your-keyvault> --name "redis-secret" --value "<your-redis-password>"
```

**Important**: Ensure secret names align with `keyvault-secret-provider.yaml`:

```yaml
# keyvault-secret-provider.yaml
objects: |
  array:
    - |
      objectName: pg-secret      # ← Must match Key Vault secret name
      objectType: secret
      objectAlias: password
    - |
      objectName: redis-secret   # ← Must match Key Vault secret name
      objectType: secret
      objectAlias: password
```

### 2. Grant AKS Access to Key Vault

```powershell
# Get AKS managed identity client ID
$IDENTITY_CLIENT_ID = az aks show \
  --resource-group <your-rg> \
  --name <your-aks-cluster> \
  --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv

# Grant Key Vault access
az keyvault set-policy \
  --name <your-keyvault> \
  --spn $IDENTITY_CLIENT_ID \
  --secret-permissions get list
```

### 3. Update Configuration Files

**Edit `keyvault-secret-provider.yaml`:**

```yaml
spec:
  parameters:
    tenantId: "<your-tenant-id>"           # az account show --query tenantId -o tsv
    keyvaultName: "<your-keyvault-name>"
```

**Edit `featbit-aks-automatic-via-lb.yaml`:**

```yaml
externalPostgresql:
  hosts:
    - "<your-server>.postgres.database.azure.com:5432"
  username: "<your-username>"
  database: "<your-database>"
  existingSecret: "featbit-pg-wu3-secret"        # ← Must match secret name from step 1

externalRedis:
  hosts:
    - "<your-redis>.redis.cache.windows.net:6380"
  existingSecret: "featbit-redis-wu3-secret"     # ← Must match secret name from step 1
  ssl: true  # Enable SSL/TLS for Azure Redis Cache
```

### 4. Initialize PostgreSQL Database

**Why database scripts are not auto-executed:**
- Security: Helm deployments should not have DDL permissions
- Governance: Schema changes require DBA approval and audit trails
- Risk: No rollback mechanism for automated schema changes

**DBA should choose the appropriate approach based on company policies:**

1. **View all migration scripts on GitHub:**  
   https://github.com/featbit/featbit/tree/main/infra/postgresql/docker-entrypoint-initdb.d

2. **Execute scripts in version order** (e.g., v0.0.0.sql → v5.0.4.sql → v5.0.5.sql → v5.1.0.sql)

**For schema updates:** Check the same GitHub directory for migration scripts when upgrading FeatBit versions.

### 5. Deploy FeatBit

```powershell
# Create namespace
kubectl create namespace featbit

# Deploy SecretProviderClass
kubectl apply -f keyvault-secret-provider.yaml

# Deploy FeatBit
helm install featbit featbit/featbit \
  --namespace featbit \
  --values featbit-aks-automatic-via-lb.yaml

# Wait for pods to be ready
kubectl get pods -n featbit -w
```

### 6. Verify Deployment

```powershell
# Check secrets created by CSI driver
kubectl get secrets -n featbit | Select-String "featbit"

# Get service endpoints
kubectl get services -n featbit

# Test endpoints
$UI_IP = kubectl get svc featbit-ui -n featbit -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Invoke-WebRequest -Uri "http://${UI_IP}:8081" -UseBasicParsing
```

## Secret Rotation

Secrets sync automatically every 2 minutes. To force immediate sync:

```powershell
kubectl rollout restart deployment -n featbit
```

## Troubleshooting

```powershell
# Check CSI driver logs
kubectl logs -n kube-system -l app=csi-secrets-store

# Check SecretProviderClass
kubectl describe secretproviderclass -n featbit

# Check pod events
kubectl describe pod <pod-name> -n featbit
```

**Common issues:**
- Secrets not created: Verify at least one pod is running (API pod mounts CSI volume)
- Access denied: Check Key Vault permissions
- Wrong tenant ID: Verify tenant ID matches your subscription

## Clean Up

```powershell
helm uninstall featbit -n featbit
kubectl delete namespace featbit
```
