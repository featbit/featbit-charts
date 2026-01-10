# FeatBit AKS Deployment with Azure Key Vault - Complete Setup Guide

This guide shows how to securely store and retrieve database credentials using **Azure Key Vault CSI Driver**.

## Architecture

```
Azure Key Vault
    ↓ (CSI Driver)
Kubernetes Secrets
    ↓
FeatBit Pods
```

## Prerequisites

- AKS Automatic cluster (Key Vault CSI Driver addon is already enabled)
- Azure CLI installed and logged in
- kubectl configured for your cluster
- Helm 3.7.0 or later

## Step-by-Step Setup

### 1. Create Azure Key Vault and Store Secrets

```powershell
# Set variables
$KEYVAULT_NAME = "featbit-kv-wu3"  # Must be globally unique (3-24 chars, use your own naming)
$RESOURCE_GROUP = "<your-resource-group>"
$LOCATION = "<your-location>"  # e.g., eastus, westeurope

# Create Key Vault
az keyvault create `
  --name $KEYVAULT_NAME `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION

# Store PostgreSQL password
az keyvault secret set `
  --vault-name $KEYVAULT_NAME `
  --name "featbit-pg-wu3-secret" `
  --value "YOUR_POSTGRES_PASSWORD"

# Store Redis password
az keyvault secret set `
  --vault-name $KEYVAULT_NAME `
  --name featbit-redis-wu3-secret `
  --value "YOUR_REDIS_PASSWORD"

# Verify secrets
az keyvault secret list --vault-name $KEYVAULT_NAME -o table
```

### 2. Grant AKS Access to Key Vault

```powershell
# First, find your AKS cluster name and resource group
az aks list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" -o table

# Set your cluster details (replace with your actual values from above)
$AKS_CLUSTER_NAME = "<your-aks-cluster-name>"      # e.g., "featbitsaasakswu3"
$RESOURCE_GROUP = "<your-aks-resource-group>"      # e.g., "featbit-saas-aks-wu3"

# Get the managed identity client ID for the CSI driver
$IDENTITY_CLIENT_ID = az aks show `
  --resource-group $RESOURCE_GROUP `
  --name $AKS_CLUSTER_NAME `
  --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId `
  --output tsv

Write-Host "Identity Client ID: $IDENTITY_CLIENT_ID"

# Grant Key Vault access to the managed identity
az keyvault set-policy `
  --name $KEYVAULT_NAME `
  --spn $IDENTITY_CLIENT_ID `
  --secret-permissions get list
```

### 3. Get Your Azure Tenant ID

```powershell
# Get tenant ID (needed for SecretProviderClass)
$TENANT_ID = az account show --query tenantId -o tsv
Write-Host "Tenant ID: $TENANT_ID"
```

### 4. Update Configuration Files

Edit `keyvault-secret-provider.yaml`:

```yaml
spec:
  parameters:
    tenantId: "YOUR_TENANT_ID"        # Replace with $TENANT_ID from step 3
    keyvaultName: "YOUR_KEYVAULT_NAME" # Replace with $KEYVAULT_NAME from step 1
```

Edit `featbit-aks-automatic-via-alb-frontdoor.yaml`:

```yaml
externalPostgresql:
  hosts:
    - "your-server.postgres.database.azure.com:5432"  # Your Azure PostgreSQL hostname
  username: "your_username"                            # Your PostgreSQL username

externalRedis:
  hosts:
    - "your-redis.redis.cache.windows.net:6380"       # Your Azure Redis hostname
```

### 5. Create Namespace and Deploy SecretProviderClass

```powershell
# Create namespace
kubectl create namespace featbit

# Apply the SecretProviderClass
kubectl apply -f keyvault-secret-provider.yaml

# Verify it was created
kubectl get secretproviderclass -n featbit
```

### 6. Deploy FeatBit with Helm

```powershell
# Add FeatBit Helm repository
helm repo add featbit https://featbit.github.io/featbit-charts
helm repo update

# Deploy FeatBit using the released Helm chart
helm install featbit featbit/featbit `
  --namespace featbit `
  --values featbit-aks-automatic-via-alb-frontdoor.yaml

# Wait for pods to be ready
kubectl get pods -n featbit -w
```

### 7. Verify Secrets Were Created

```powershell
# Check if secrets were created by CSI driver
kubectl get secrets -n featbit | Select-String "featbit"

# You should see:
# featbit-pg-wu3-secret
# featbit-redis-wu3-secret

# Verify secret content (base64 encoded)
kubectl get secret featbit-pg-wu3-secret -n featbit -o yaml
```

### 8. Get Service External IPs

```powershell
# Get LoadBalancer IPs
kubectl get services -n featbit

# Example output:
# NAME                TYPE           EXTERNAL-IP     PORT(S)
# featbit-ui          LoadBalancer   20.10.20.30     8081:30080/TCP
# featbit-api         LoadBalancer   20.10.20.31     5000:30081/TCP
# featbit-els         LoadBalancer   20.10.20.32     5100:30082/TCP
```

### 9. Test the Deployment

```powershell
# Check UI
Invoke-WebRequest -Uri "http://<UI-EXTERNAL-IP>:8081" -UseBasicParsing

# Check API health
Invoke-WebRequest -Uri "http://<API-EXTERNAL-IP>:5000/health" -UseBasicParsing

# Check ELS health
Invoke-WebRequest -Uri "http://<ELS-EXTERNAL-IP>:5100/health" -UseBasicParsing
```

## Secret Rotation

To update secrets:

```powershell
# Update secret in Key Vault
az keyvault secret set `
  --vault-name $KEYVAULT_NAME `
  --name featbit-pg-wu3-secret `
  --value "NEW_PASSWORD"

# Secrets sync automatically every 2 minutes (default)
# Or restart pods to force immediate sync:
kubectl rollout restart deployment -n featbit
```

## Troubleshooting

### Check CSI Driver Logs

```powershell
# Get CSI driver pods
kubectl get pods -n kube-system | Select-String "csi-secrets-store"

# Check logs
kubectl logs -n kube-system <csi-secrets-store-pod> -f
```

### Check SecretProviderClass Status

```powershell
kubectl describe secretproviderclass featbit-keyvault-secrets -n featbit
```

### Check Pod Events

```powershell
kubectl describe pod <pod-name> -n featbit
```

### Common Issues

1. **Secrets not created**: Ensure at least one pod mounts the CSI volume (API pod does this automatically)
2. **Access denied**: Verify Key Vault permissions with `az keyvault show --name $KEYVAULT_NAME`
3. **Wrong tenant ID**: Double-check tenant ID matches your subscription

## Clean Up

```powershell
# Uninstall FeatBit
helm uninstall featbit -n featbit

# Delete namespace
kubectl delete namespace featbit

# Delete Key Vault (optional)
az keyvault delete --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP
```

## Security Best Practices

✅ **Use RBAC**: Limit which pods can access secrets  
✅ **Enable Key Vault firewall**: Restrict access to your AKS subnet  
✅ **Enable audit logging**: Track secret access in Azure Monitor  
✅ **Rotate secrets regularly**: Use Azure Key Vault secret versioning  
✅ **Use managed identities**: No passwords stored in cluster  

## Next Steps

- Configure Azure Front Door for global distribution
- Set up auto-scaling with HPA
- Enable monitoring with Azure Monitor
- Configure backup and disaster recovery
