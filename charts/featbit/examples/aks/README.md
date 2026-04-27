# FeatBit AKS Deployment Guide

Deploy FeatBit to Azure AKS with Traffic Manager, NGINX Ingress, and automatic TLS certificates.

## Architecture

```
Internet → Traffic Manager → Azure LB → NGINX Ingress (TLS) → FeatBit Services
                                                              ↓
                                           Azure Key Vault ← PostgreSQL/Redis
```

**Key Features:**
- Multi-region high availability with Traffic Manager
- Free SSL certificates from Let's Encrypt (auto-renewal)
- WebSocket support (200K+ concurrent connections)
- Secure credential management via Azure Key Vault

## Files

- `featbit-aks-values.yaml` - Helm values configuration
- `keyvault-secret-provider.yaml` - Azure Key Vault integration
- `cluster-issuer.yaml` - Let's Encrypt certificate issuers
- `*.local.yaml` - Local configuration files (gitignored, copy from templates and update with your values)

## Prerequisites

```bash
# Install tools
az aks install-cli
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Enable Azure Key Vault CSI Driver on AKS (if not already enabled)
az aks enable-addons \
  --addons azure-keyvault-secrets-provider \
  --name <cluster-name> \
  --resource-group <rg-name>

# Connect to cluster
az aks get-credentials --resource-group <rg-name> --name <cluster-name>
```

## Deployment Steps

### 1. Install NGINX Ingress Controller

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=3 \
  --set controller.service.externalTrafficPolicy=Local \
  --set controller.config.proxy-read-timeout="3600" \
  --set controller.config.proxy-send-timeout="3600"
```

Get the Load Balancer IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### 2. Install cert-manager

```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --version v1.16.2
```

### 3. Configure Let's Encrypt Issuers

Copy and update cluster-issuer.yaml:
```bash
cp cluster-issuer.yaml cluster-issuer.local.yaml
# Edit cluster-issuer.local.yaml and update email address
```

Apply:
```bash
kubectl apply -f cluster-issuer.local.yaml
kubectl get clusterissuer
```

### 4. Configure Azure Key Vault

Grant Key Vault access to AKS identity:
```bash
# Get AKS identity
IDENTITY_CLIENT_ID=$(az aks show -g <rg-name> -n <cluster-name> \
  --query identityProfile.kubeletidentity.clientId -o tsv)

# Assign role
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $IDENTITY_CLIENT_ID \
  --scope /subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.KeyVault/vaults/<keyvault-name>
```

Copy and update keyvault-secret-provider.yaml:
```bash
cp keyvault-secret-provider.yaml keyvault-secret-provider.local.yaml
# Edit and update: userAssignedIdentityID, tenantId, keyvaultName
```

Apply:
```bash
kubectl create namespace featbit
kubectl apply -f keyvault-secret-provider.local.yaml
```

### 5. Configure DNS

Create DNS records pointing to NGINX Ingress Load Balancer IP:
```
app.example.com  → A → <NGINX-IP>
api.example.com  → A → <NGINX-IP>
eval.example.com → A → <NGINX-IP>
```

### 6. Deploy FeatBit

Copy and update values file:
```bash
cp featbit-aks-values.yaml featbit-aks-values.local.yaml
# Edit and update: domains, PostgreSQL, Redis, Key Vault secret names
```

Add FeatBit Helm repository:
```bash
helm repo add featbit https://featbit.github.io/featbit-charts/
helm repo update
```

Install FeatBit:
```bash
helm install featbit featbit/featbit \
  -f featbit-aks-values.local.yaml \
  --namespace featbit
```

### 7. Verify Deployment

```bash
# Check pods
kubectl get pods -n featbit

# Check certificates
kubectl get certificate -n featbit

# Check ingress
kubectl get ingress -n featbit

# Test endpoints
curl https://api.example.com/health/liveness
```

## Traffic Manager Setup (Multi-Region)

### 1. Create Traffic Manager Profiles

```bash
# UI Profile
az network traffic-manager profile create \
  --name featbit-ui-tm \
  --resource-group <rg-name> \
  --routing-method Performance \
  --protocol HTTPS \
  --port 443 \
  --path /health/liveness \
  --custom-headers Host=app.example.com

# API Profile
az network traffic-manager profile create \
  --name featbit-api-tm \
  --resource-group <rg-name> \
  --routing-method Performance \
  --protocol HTTPS \
  --port 443 \
  --path /health/liveness \
  --custom-headers Host=api.example.com

# ELS Profile
az network traffic-manager profile create \
  --name featbit-els-tm \
  --resource-group <rg-name> \
  --routing-method Performance \
  --protocol HTTPS \
  --port 443 \
  --path /health/liveness \
  --custom-headers Host=eval.example.com
```

### 2. Add Endpoints

```bash
# Region 1 (e.g., West US 3)
az network traffic-manager endpoint create \
  --name region1 \
  --profile-name featbit-ui-tm \
  --resource-group <rg-name> \
  --type externalEndpoints \
  --target <NGINX-IP-REGION1> \
  --endpoint-location "West US 3"

# Repeat for API and ELS profiles
```

### 3. Update DNS to CNAME

Change DNS records from A to CNAME:
```
app.example.com  → CNAME → featbit-ui-tm.trafficmanager.net
api.example.com  → CNAME → featbit-api-tm.trafficmanager.net
eval.example.com → CNAME → featbit-els-tm.trafficmanager.net
```

### 4. Verify Traffic Manager

```bash
# Check endpoint health
az network traffic-manager endpoint list \
  --profile-name featbit-ui-tm \
  --resource-group <rg-name>

# Test DNS resolution
nslookup app.example.com
```

## Multi-Region Deployment

To add a new region:

1. Deploy AKS cluster in new region
2. Install NGINX Ingress Controller
3. Install cert-manager and cluster issuers
4. Deploy FeatBit with same configuration
5. Add new endpoint to Traffic Manager profiles:

```bash
az network traffic-manager endpoint create \
  --name region2 \
  --profile-name featbit-ui-tm \
  --resource-group <rg-name> \
  --type externalEndpoints \
  --target <NGINX-IP-REGION2> \
  --endpoint-location "East US"
```

Traffic Manager automatically routes users to the nearest healthy endpoint.

## Troubleshooting

**Pods not starting:**
```bash
kubectl describe pod <pod-name> -n featbit
kubectl logs <pod-name> -n featbit
```

**Certificate not issued:**
```bash
kubectl describe certificate <cert-name> -n featbit
kubectl get certificaterequest -n featbit
kubectl logs -n cert-manager deployment/cert-manager
```

**Key Vault access denied:**
```bash
az role assignment list --assignee <identity-client-id> --scope <keyvault-id>
```

**Traffic Manager endpoints degraded:**
```bash
az network traffic-manager profile show \
  --name <profile-name> \
  --resource-group <rg-name> \
  --query monitorConfig
```

## References

- [FeatBit Helm Chart](https://github.com/featbit/featbit-charts)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Azure Traffic Manager](https://learn.microsoft.com/azure/traffic-manager/)
