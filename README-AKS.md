https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard#scale-the-number-of-managed-outbound-public-ips
https://learn.microsoft.com/en-us/azure/aks/static-ip

```
az network public-ip create --resource-group MC_bestpractice_featbit-k8s-trial_southeastasia --name featbit-ui-ip --sku Standard --allocation-method static

az network public-ip create --resource-group MC_bestpractice_featbit-k8s-trial_southeastasia --name featbit-api-ip --sku Standard --allocation-method static

az network public-ip create --resource-group MC_bestpractice_featbit-k8s-trial_southeastasia --name featbit-eval-ip --sku Standard --allocation-method static

az network public-ip show --resource-group MC_bestpractice_featbit-k8s-trial_southeastasia --name featbit-ui-ip --query ipAddress --output tsv
az network public-ip show --resource-group MC_bestpractice_featbit-k8s-trial_southeastasia --name featbit-api-ip --query ipAddress --output tsv
az network public-ip show --resource-group MC_bestpractice_featbit-k8s-trial_southeastasia --name featbit-eval-ip --query ipAddress --output tsv
```

```

CLIENT_ID=$(az aks show --name featbit-k8s-trial --resource-group bestpractice --query identity.principalId -o tsv)
RG_SCOPE=$(az group show --name MC_bestpractice_featbit-k8s-trial_southeastasia --query id -o tsv)
az role assignment create --assignee ${CLIENT_ID} --role "Network Contributor" --scope ${RG_SCOPE}
```

```
helm dependency update

helm install featbit-trial . -f ./examples/expose-services-via-azurelb.yaml --dry-run

helm install featbit-trial . -f ./examples/expose-services-via-azurelb.yaml

helm upgrade --install featbit-trial . -f ./examples/expose-services-via-azurelb.yaml --dry-run

helm upgrade --install featbit-trial . -f ./examples/expose-services-via-azurelb.yaml

helm uninstall featbit-trial
```