# Deploy the ELS readiness probe to your existing ACA environment

Run these steps yourself, in order, from the **repository root**, using the same
**PowerShell 7.1+** terminal. Install the **.NET 10 SDK** and a recent **Azure CLI** first.
The commands have not been executed during this documentation change.

The resource names below come from your screenshots:

| Resource | Name |
| --- | --- |
| Existing resource group | `featbit-saas-wu3` |
| Region | West US 3 (`westus3`) |
| Existing ACA environment | `featbit-aca-wu3` |
| Existing ACR | `featbitrdawu3` |
| Existing Key Vault | `featbit-kv-wu3` |
| New Container App | `els-readiness-probe` |

This deploys a new **Container App**, independently of the existing Container App
Job and FeatBit services. It reuses your environment, registry, and Key Vault.
No resource group, registry, environment, database, or secret value is created or replaced.

The ACA environment must already have network access to Key Vault, PostgreSQL,
and Redis, including private DNS/VNet routing where required. **The same resource
group and region do not establish connectivity or grant permissions.** These steps
do not change networking or any AKS configuration.

## 1. Sign in and confirm the existing resources

Replace only the subscription ID if the resource names above are correct:

```powershell
$SubscriptionId = '<your FeatBit subscription ID>'
$ResourceGroup = 'featbit-saas-wu3'
$Location = 'westus3'
$EnvironmentName = 'featbit-aca-wu3'
$AcrName = 'featbitrdawu3'
$KeyVaultName = 'featbit-kv-wu3'
$AppName = 'els-readiness-probe'
$IdentityName = 'els-readiness-probe-mi'
$PgSecretName = 'featbit-pg-wu3-secret'
$RedisSecretName = 'featbit-redis-wu3-secret'

az login
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw 'Select the intended subscription before continuing.' }
az extension add --name containerapp --upgrade

$Environment = az containerapp env show --resource-group $ResourceGroup --name $EnvironmentName --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $Environment.id) { throw 'The existing ACA environment was not found.' }
$Acr = az acr show --resource-group $ResourceGroup --name $AcrName --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $Acr.id) { throw 'The existing ACR was not found.' }
$Vault = az keyvault show --resource-group $ResourceGroup --name $KeyVaultName --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $Vault.id) { throw 'The existing Key Vault was not found.' }

$EnvironmentId = $Environment.id
$Registry = $Acr.loginServer
$VaultUri = $Vault.properties.vaultUri.TrimEnd('/')
$PgSecretUri = "$VaultUri/secrets/$PgSecretName"
$RedisSecretUri = "$VaultUri/secrets/$RedisSecretName"
```

The `show` commands read resource metadata, not password values. The existing
Key Vault secrets are used as **passwords**, matching your AKS CSI configuration:

| Probe setting | Existing Key Vault secret |
| --- | --- |
| `Postgres__Password` | `featbit-pg-wu3-secret` |
| `Redis__Password` | `featbit-redis-wu3-secret` |

## 2. Give the probe identity image-pull and secret-read access

Create a dedicated identity for this probe. If reusing an approved ACA identity,
substitute its name and resource group in the identity commands and skip `create`.
Use an ACA identity's **resource ID**, not the AKS kubelet client ID from the CSI file.

```powershell
az identity create --resource-group $ResourceGroup --name $IdentityName --location $Location --output none
if ($LASTEXITCODE -ne 0) { throw 'Identity creation failed.' }
$Identity = az identity show --resource-group $ResourceGroup --name $IdentityName --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $Identity.id) { throw 'Identity lookup failed.' }
$IdentityId = $Identity.id
$PrincipalId = $Identity.principalId

$PullRole = switch ($Acr.roleAssignmentMode) {
    'AbacRepositoryPermissions' { 'Container Registry Repository Reader' }
    'LegacyRegistryPermissions' { 'AcrPull' }
    default { throw 'Check the ACR permission mode with your administrator before assigning a pull role.' }
}
az role assignment create --assignee-object-id $PrincipalId --assignee-principal-type ServicePrincipal `
  --role $PullRole --scope $Acr.id --output none
if ($LASTEXITCODE -ne 0) { throw 'ACR image-pull permission assignment failed.' }
```

Next, grant access according to the vault's **existing** permission model. The
RBAC branch limits access to the two named secrets. **The legacy access-policy
branch grants `get` for all secrets in this vault; run it only if the vault owner
approves that scope for the probe.** Keep the vault's permission model unchanged.

```powershell
if ($Vault.properties.enableRbacAuthorization) {
    foreach ($SecretName in @($PgSecretName, $RedisSecretName)) {
        az role assignment create --assignee-object-id $PrincipalId --assignee-principal-type ServicePrincipal `
          --role 'Key Vault Secrets User' --scope "$($Vault.id)/secrets/$SecretName" --output none
        if ($LASTEXITCODE -ne 0) { throw 'Key Vault secret-read role assignment failed.' }
    }
}
else {
    az keyvault set-policy --resource-group $ResourceGroup --name $KeyVaultName `
      --object-id $PrincipalId --secret-permissions get --output none
    if ($LASTEXITCODE -ne 0) { throw 'Key Vault access policy assignment failed.' }
}
```

The access-policy command targets only the probe identity; it does not modify
other identities' policies. If you lack permission to assign roles or policies,
have the registry/vault administrator perform this step.

Allow permission changes to propagate before deploying. These are separate grants:
ACR pull permission does not grant Key Vault access. References:
[ACR roles](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-rbac-built-in-roles-overview),
[Key Vault RBAC](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide),
[legacy access policies](https://learn.microsoft.com/en-us/azure/key-vault/general/assign-access-policy).

## 3. Publish locally, then build and push the image in ACR

This publishes the [.NET project](../els-readiness-probe/README.md) into a fresh
temporary directory and generates a runtime Dockerfile there. No Dockerfile or
helper script needs to be added to the repository, and Docker Desktop is not required.

```powershell
$Tag = Get-Date -Format 'yyyyMMdd-HHmmss'
$ImageName = "${AppName}:$Tag"
$Image = "$Registry/$ImageName"
$BuildDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('els-probe-' + [Guid]::NewGuid().ToString('N'))

dotnet publish test-projects/els-readiness-probe/src/Els.ReadinessProbe/Els.ReadinessProbe.csproj `
  --configuration Release --os linux --arch x64 --self-contained false `
  -p:UseAppHost=false --output $BuildDirectory
if ($LASTEXITCODE -ne 0) { throw 'Publish failed. Stop here.' }

Get-ChildItem -LiteralPath $BuildDirectory -Recurse -File -Filter 'appsettings.Local*.json' |
  ForEach-Object { Remove-Item -LiteralPath $_.FullName }

@'
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY . .
USER $APP_UID
ENV Urls=http://0.0.0.0:5080
EXPOSE 5080
ENTRYPOINT ["dotnet", "Els.ReadinessProbe.dll"]
'@ | Set-Content -LiteralPath (Join-Path $BuildDirectory 'Dockerfile') -Encoding utf8

az acr build --resource-group $ResourceGroup --registry $AcrName --image $ImageName `
  --platform linux/amd64 --file Dockerfile $BuildDirectory
if ($LASTEXITCODE -ne 0) { throw 'ACR build failed. Stop here.' }
```

[ACR builds and pushes the image in Azure](https://learn.microsoft.com/en-us/cli/azure/acr#az-acr-build).
Your account needs permission to run ACR builds. Only the temporary runtime files
are uploaded, not the repository or FeatBit values. Keep tracked `appsettings.json`
and all other published files free of credentials; optional local settings are
removed from the temporary directory before upload.

## 4. Enter password-free connection strings and deploy

Copy ELS's effective connection strings from your local deployment configuration,
including any `els.env` overrides. For PostgreSQL, preserve host, port, username,
database, and `externalPostgresql.extraParams`. For Redis, preserve the exact
endpoint port, TLS, database, user, and cluster/sentinel options. Do not infer the
Redis endpoint or port from its Azure resource name.

Enter **no passwords** here. ACA resolves the two existing Key Vault passwords
using the managed identity and injects them at runtime; your terminal, image,
deployment arguments, and repository do not need the password values.

```powershell
$PgConnection = Read-Host 'Paste the ELS PostgreSQL connection string WITHOUT a password'
$RedisConnection = Read-Host 'Paste the ELS Redis connection string WITHOUT a password'

az containerapp create --name $AppName --resource-group $ResourceGroup `
  --environment $EnvironmentId --image $Image `
  --user-assigned $IdentityId --registry-server $Registry --registry-identity $IdentityId `
  --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 1 --revisions-mode single `
  --secrets "pg-password=keyvaultref:$PgSecretUri,identityref:$IdentityId" `
    "redis-password=keyvaultref:$RedisSecretUri,identityref:$IdentityId" `
  --env-vars "Postgres__ConnectionString=$PgConnection" "Postgres__Password=secretref:pg-password" `
    "Redis__ConnectionString=$RedisConnection" "Redis__Password=secretref:redis-password" `
    "Probe__Enabled=true" "Probe__IntervalSeconds=30" --output none
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed. Check the error before continuing.' }
```

See [ACA Key Vault references](https://learn.microsoft.com/en-us/azure/container-apps/manage-secrets#reference-secret-from-key-vault).
These are Azure CLI commands run from PowerShell, not Azure PowerShell `Az.*` cmdlets.
If ELS explicitly sets `Redis__ConnectTimeoutMs` or `Redis__SyncTimeoutMs`, add the
same values to `--env-vars` before deployment.

This creates one continuously running background sampler. It runs the same PG/Redis
checks as `/health/readiness`, waiting 30 seconds after each completed sample.
Ingress is disabled, so there is no public HTTP endpoint and no HTTP polling is
needed. `--min-replicas 1` keeps the sampler running without incoming traffic.
The probe does not change the existing ELS deployment or its Secrets.

## 5. Confirm the app and view its container logs

```powershell
az containerapp show --name $AppName --resource-group $ResourceGroup `
  --query '{state:properties.provisioningState,revision:properties.latestReadyRevisionName}' --output table

az containerapp logs show --name $AppName --resource-group $ResourceGroup --type console --follow
```

Look for JSON readiness samples with `Source=background`, a `TraceId`, and separate
`npgsql` / `redis` results and durations. Shared resource placement alone does not
prove connectivity: image-pull errors need ACR identity/access checks; Key Vault
reference errors need secret-read permission and vault network access; dependency
failures need the correct PG/Redis connection settings and network path.

Use the ACA environment's existing container-log collection for Azure Monitor.
Counters reset on process restart. Versionless Key Vault references can refresh
after secret rotation and restart replicas. ACA also has a different network path
from AKS, so these observations describe the ACA environment.

## 6. Deploy a newer image or remove only the test app

After changing the local application, rerun step 3 for a new image tag, then update
only this Container App. Its existing secret references and settings are retained:

```powershell
az containerapp update --name $AppName --resource-group $ResourceGroup --image $Image --output none
```

When the test is finished:

```powershell
az containerapp delete --name $AppName --resource-group $ResourceGroup --yes
```

The registry, environment, Key Vault secrets, databases, FeatBit services, and AKS
resources remain in place. The image and probe identity also remain for reuse.

Validation of this guide is limited to local syntax/link checks and public CLI
documentation. No Azure build, permission change, deployment, or secret retrieval
has been executed as part of writing it.
