# Deploying the Feature Flags Service to Azure Kubernetes Service (AKS) using Helm, Exposed via Azure Load Balancer

[FeatBit](https://www.featbit.co) is an open-source feature flags service that enables teams to test their applications in production, roll out features incrementally, and instantly rollback if an issue arises.

This guide outlines how to deploy FeatBit to Azure Kubernetes Service (AKS) using Helm charts, with services exposed via Azure Load Balancer and `static public IP addresses`.

> Note: This guide is for demonstration purposes only. It is not intended for production use.

## Prerequisites

- An active Azure subscription.
- An AKS cluster.
- Azure CLI installed.
- `kubectl` installed.

## Creating Public Static IPs for FeatBit Services

FeatBit utilizes three public services:

1. **UI Portal**: This is the interface for team members to manage feature flags.
2. **API Server**: The backend which the portal communicates with to fetch and manage feature flags.
3. **Evaluation Server**: The endpoint SDKs communicate with to retrieve feature flag variations or rules.

Each service requires its own public IP. Here's how you can set them up:

```bash
# Public IP for the UI Portal
az network public-ip create --resource-group {resource group containing your AKS's vnet} --name featbit-ui-ip --sku Standard --allocation-method static

# Public IP for the API Service
az network public-ip create --resource-group {resource group containing your AKS's vnet} --name featbit-api-ip --sku Standard --allocation-method static

# Public IP for the Evaluation Service
az network public-ip create --resource-group {resource group containing your AKS's vnet} --name featbit-eval-ip --sku Standard --allocation-method static
```

Retrieve the IPs using:

```bash
az network public-ip show --resource-group {resource group containing your AKS's vnet} --name featbit-ui-ip --query ipAddress --output tsv

az network public-ip show --resource-group {resource group containing your AKS's vnet} --name featbit-api-ip --query ipAddress --output tsv

az network public-ip show --resource-group {resource group containing your AKS's vnet} --name featbit-eval-ip --query ipAddress --output tsv
```

# Granting Delegated Permissions to AKS Cluster Identity

Before deploying services with a load balancer, ensure the AKS cluster identity has the necessary permissions to the node resource group.

```bash
CLIENT_ID=$(az aks show --name {your AKS name} --resource-group {resource group name where your aks located in} --query identity.principalId -o tsv)

RG_SCOPE=$(az group show --name {resource group containing your public IPs} --query id -o tsv)

az role assignment create --assignee ${CLIENT_ID} --role "Network Contributor" --scope ${RG_SCOPE}
```

# Deploying with Helm and Custom Values

Add the FeatBit Helm repository:

```bash
helm repo add featbit https://featbit.github.io/featbit-charts/
```

Clone and navigate to the Helm chart repository:

```bash
git clone https://github.com/featbit/featbit-charts
```

In the `featbit-charts/charts/featbit/examples/azure` directory, locate the AKS example file, `expose-services-via-azure-static-ip.yaml`. Replace placeholders ({}) with the appropriate values:

- `apiExternalUrl`, the URL the UI portal utilizes to retrieve feature flags.
- `evaluationServerExternalUrl`, the URL the SDK accesses to obtain variations or rules for feature flags.
- `service.beta.kubernetes.io/azure-load-balancer-ipv4`, bind the public IPs you created in previous step to each service
- `service.beta.kubernetes.io/azure-load-balancer-resource-group`, the name of the resource group where your public IPs are situated.

```yaml
apiExternalUrl: "http://{API Service Public IP Address with port if not 80, ex. 4.194.69.254}"
evaluationServerExternalUrl: "http://{Evaluation Service Public IP Address with port if not 80, ex. 4.193.158.12}"

ui:
  service:
    type: LoadBalancer
    port: 80
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-resource-group: {Resource Group where your Public IP located in, ex. myNetworkResourceGroup}
      service.beta.kubernetes.io/azure-load-balancer-ipv4: {UI Portal Public IP Address, ex. 4.194.13.155}

api:
  service:
    type: LoadBalancer
    port: 80
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-resource-group: {Resource Group where your Public IP located in, ex. myNetworkResourceGroup}
      service.beta.kubernetes.io/azure-load-balancer-ipv4: {API Service Public IP Address, ex. 4.194.69.254}

els:
  service:
    type: LoadBalancer
    port: 80
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-resource-group: {Resource Group where your Public IP located in, ex. myNetworkResourceGroup}
      service.beta.kubernetes.io/azure-load-balancer-ipv4: {Evaluation Service Public IP Address, ex. 4.193.158.12}
```

Preview the Helm installation:

```bash
helm install featbit featbit/featbit -f featbit-charts/charts/featbit/examples/azure/expose-services-via-azure-static-ip.yaml --dry-run
```

If all looks well, install the Helm chart:

```bash
helm install featbit featbit/featbit -f featbit-charts/charts/featbit/examples/azure/expose-services-via-azure-static-ip.yaml

# or to upgrade
helm upgrade --install featbit featbit/featbit -f featbit-charts/charts/featbit/examples/azure/expose-services-via-azure-static-ip.yaml
```

NOTE: 

- Ensure you run the command from the directory containing `expose-services-via-azure-static-ip.yaml`.
- Specify a namespace with `--namespace` option during installation if needed.

# Verification

Check that the services and pods are running:

```bash
kubectl get svc

kubectl get po
```

This should show output similar to the provided image:

![kubectl get svc](./kubectl-get-svc-po.png)

Finally, access the UI Portal via the public IP you established earlier:

![login page](./login-page.png)

# References

[Deploying ASP.NET Core applications to Kubernetes](https://andrewlock.net/deploying-asp-net-core-applications-to-kubernetes-part-3-deploying-applications-with-helm/)

[FeatBit's helm chart repository](https://github.com/featbit/featbit-charts)

[Use a public standard load balancer in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard)
