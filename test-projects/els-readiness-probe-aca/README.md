# Deploy the ELS readiness probe to Azure Container Apps

This guide builds the local [.NET 10 project](../els-readiness-probe/README.md),
pushes its image to your **existing Azure Container Registry (ACR)**, and deploys
a new Container App inside your **existing Azure Container Apps (ACA) environment**.
All commands are for you to run; none have been
executed during this change. FeatBit configuration and AKS resources are unchanged.

Use **PowerShell 7.1+**, the **.NET 10 SDK**, and **Azure CLI**. Run the following
steps in the same terminal, starting from the **repository root**.

**Before starting, the resource group, ACR, and ACA environment must already exist.**
The steps below reuse those resources; provisioning them is outside this guide.
The ACA environment must already reach your PG/Redis endpoints, including private
DNS and VNet routing when applicable. Your account needs permission to run ACR
builds and create the test Container App. Creating a new pull identity in step 3
also requires identity creation and role-assignment permissions.

## 1. Select your existing ACR and ACA environment

Replace the placeholders with your existing resources:

```powershell
az login
az account set --subscription '<subscription ID>'
az extension add --name containerapp --upgrade

$ResourceGroup = '<resource group containing your ACA environment>'
$EnvironmentName = '<existing ACA environment name>'
$AcrName = '<existing ACR name>'
$AppName = 'els-readiness-probe'
$Tag = Get-Date -Format 'yyyyMMdd-HHmmss'
$ImageName = "${AppName}:$Tag"

$Registry = az acr show --name $AcrName --query loginServer --output tsv
if ($LASTEXITCODE -ne 0) { throw 'Select an existing ACR before continuing.' }
$AcrId = az acr show --name $AcrName --query id --output tsv
$EnvironmentId = az containerapp env show --resource-group $ResourceGroup --name $EnvironmentName --query id --output tsv
if ($LASTEXITCODE -ne 0) { throw 'Select an existing ACA environment before continuing.' }
$Location = az containerapp env show --resource-group $ResourceGroup --name $EnvironmentName --query location --output tsv
$Image = "$Registry/$ImageName"
```

The `show` commands only look up existing resources. The resulting environment
ID is used explicitly when creating the test app in step 4.

## 2. Publish locally, then build and push in ACR

This publishes runtime files into a fresh temporary directory. The small runtime
Dockerfile is generated there, outside the repository. Docker Desktop is not
required: [ACR builds and pushes the image](https://learn.microsoft.com/en-us/cli/azure/acr#az-acr-build).

```powershell
$BuildDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('els-probe-' + [Guid]::NewGuid().ToString('N'))

dotnet publish test-projects/els-readiness-probe/src/Els.ReadinessProbe/Els.ReadinessProbe.csproj `
  --configuration Release --os linux --arch x64 --self-contained false `
  -p:UseAppHost=false --output $BuildDirectory
if ($LASTEXITCODE -ne 0) { throw 'Publish failed. Stop here.' }

# Remove optional local settings before uploading the published files.
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

az acr build --registry $AcrName --image $ImageName --platform linux/amd64 `
  --file Dockerfile $BuildDirectory
if ($LASTEXITCODE -ne 0) { throw 'Image build failed. Stop here.' }
```

Keep credentials out of tracked `appsettings.json` and other published files.
Only the temporary publish directory is uploaded, not the repository or FeatBit values.

## 3. Allow ACA to pull the private image

If you already have an approved user-assigned identity with image-pull access to
this ACR, set `$IdentityId` to its resource ID and skip the commands in this step.
Otherwise, create a dedicated identity for this test app below. This uses managed
identity authentication without changing the ACR admin-user setting. See
[managed-identity image pulls](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity-image-pull).

```powershell
$IdentityName = "$AppName-pull"
az identity create --resource-group $ResourceGroup --name $IdentityName --location $Location --output none
$IdentityId = az identity show --resource-group $ResourceGroup --name $IdentityName --query id --output tsv
$PrincipalId = az identity show --resource-group $ResourceGroup --name $IdentityName --query principalId --output tsv

$PullRole = 'AcrPull'
# For an ABAC-enabled ACR, use 'Container Registry Repository Reader' instead.
az role assignment create --assignee-object-id $PrincipalId --assignee-principal-type ServicePrincipal `
  --role $PullRole --scope $AcrId --output none
```

Choose the role that matches your registry's [permission mode](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-rbac-built-in-roles-overview).
Allow time for a new role assignment to propagate before deployment.

## 4. Supply PG/Redis settings and create the app

Use the same connection parameters and passwords as ELS, preserving TLS, database,
user, pooling, and timeout settings. **ACA cannot reference Kubernetes Secrets.**
The command below creates separate secrets on this new Container App using the
same underlying passwords. Obtain them from your approved secret store; no AKS
access or changes to existing FeatBit configuration are needed.

```powershell
$PgConnection = Read-Host 'PostgreSQL connection string, without password'
$RedisConnection = Read-Host 'Redis connection string, without password'
$PgPassword = Read-Host 'PostgreSQL password' -MaskInput
$RedisPassword = Read-Host 'Redis password' -MaskInput

az containerapp create --name $AppName --resource-group $ResourceGroup `
  --environment $EnvironmentId --image $Image `
  --user-assigned $IdentityId --registry-server $Registry --registry-identity $IdentityId `
  --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 1 --revisions-mode single `
  --secrets "pg-password=$PgPassword" "redis-password=$RedisPassword" `
  --env-vars "Postgres__ConnectionString=$PgConnection" "Postgres__Password=secretref:pg-password" `
    "Redis__ConnectionString=$RedisConnection" "Redis__Password=secretref:redis-password" `
    "Probe__Enabled=true" "Probe__IntervalSeconds=30" --output none
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed. Check the error before continuing.' }

$PgPassword = $null
$RedisPassword = $null
```

This starts one continuously running replica, sampling PG/Redis health every
30 seconds after the previous check completes. Ingress is disabled, so the app
has no public HTTP endpoint. `--min-replicas 1` keeps background sampling running
without incoming requests; see [ACA scaling](https://learn.microsoft.com/en-us/azure/container-apps/scale-app#default-scale-rule).
The background sampler executes the same checks used by `/health/readiness`.

See the [create command reference](https://learn.microsoft.com/en-us/cli/azure/containerapp#az-containerapp-create)
for secrets, environment variables, and deployment options. If ELS overrides
`Redis__ConnectTimeoutMs` or `Redis__SyncTimeoutMs`, add matching entries to
`--env-vars` before deployment.

## 5. Observe or remove the test app

```powershell
az containerapp logs show --name $AppName --resource-group $ResourceGroup --type console --follow
```

The app writes JSON container logs with `TraceId`, per-dependency status, duration,
and failure details. Use your ACA environment's existing log collection for Azure
Monitor. Counters reset on process restart; ACA's network path differs from AKS.

When finished, remove only the test Container App:

```powershell
az containerapp delete --name $AppName --resource-group $ResourceGroup --yes
```

The image and selected pull identity remain available for reuse; the existing
ACR, ACA environment, databases, and FeatBit services are left in place.
