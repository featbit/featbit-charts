#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Image,
    [string]$ConfigFile = (Join-Path $PSScriptRoot 'runtime-config.local.json'),
    [string]$Namespace = 'featbit',
    [ValidateSet('background', 'kubelet')]
    [string]$SamplingMode = 'background',
    [ValidateRange(1, 3600)]
    [int]$IntervalSeconds = 30,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-JsonFile([string]$Path) {
    try {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    }
    catch {
        # Parser errors can quote credentials from the input line.
        throw 'Cannot read the JSON configuration; file contents were not printed.'
    }
}

function Test-SecretReference($Source) {
    if ($Source -isnot [System.Collections.IDictionary] -or $Source.Count -ne 1 -or
        -not $Source.Contains('secretKeyRef')) { return $false }
    $reference = $Source.secretKeyRef
    if ($reference -isnot [System.Collections.IDictionary] -or $reference.Count -ne 2 -or
        $reference.name -isnot [string] -or $reference.key -isnot [string]) { return $false }
    if ($reference.name.Length -gt 253 -or $reference.key.Length -gt 253 -or
        $reference.key -cnotmatch '^[A-Za-z0-9._-]+$') { return $false }
    foreach ($label in $reference.name.Split('.')) {
        if ($label.Length -gt 63 -or $label -cnotmatch '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$') { return $false }
    }
    return $true
}

if ($Image -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:/@-]*$' -or $Image.Contains('://') -or
    $Image.Split('/')[-1] -cnotmatch '^[A-Za-z0-9._-]+(:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}|@sha256:[a-f0-9]{64})$') {
    throw 'Supply an image with an explicit tag or digest and without a URL scheme.'
}
if ($Namespace.Length -gt 63 -or $Namespace -cnotmatch '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$') {
    throw 'Namespace must be a Kubernetes DNS label.'
}

$configuration = Read-JsonFile $ConfigFile
$required = @('Postgres__ConnectionString', 'Postgres__Password', 'Redis__ConnectionString', 'Redis__Password')
$optional = @('Redis__ConnectTimeoutMs', 'Redis__SyncTimeoutMs')
if ($configuration -isnot [System.Collections.IDictionary] -or $configuration.Count -ne 1 -or
    -not $configuration.Contains('env') -or $configuration.env -isnot [array]) {
    throw 'The runtime configuration must contain only an env array.'
}
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($entry in $configuration.env) {
    if ($entry -isnot [System.Collections.IDictionary] -or -not $entry.Contains('name') -or
        $entry.name -cnotin ($required + $optional) -or -not $seen.Add($entry.name) -or
        @($entry.Keys | Where-Object { $_ -cnotin @('name', 'value', 'valueFrom') }).Count -gt 0 -or
        ($entry.Contains('value') -eq $entry.Contains('valueFrom'))) {
        throw 'Dependency environment entries must be supported, unique, and have one value source.'
    }
    if ($entry.Contains('valueFrom')) {
        if ($entry.name -cin $optional -or -not (Test-SecretReference $entry.valueFrom)) {
            throw 'Dependency references must name an existing Secret and key; Redis timeouts must be literal strings.'
        }
    }
    else {
        if ($entry.name.EndsWith('__Password', [System.StringComparison]::Ordinal)) {
            throw 'Passwords must use existing Secret references; literal passwords are not copied.'
        }
        if ($entry.value -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.value) -or
            $entry.value -match '__[A-Z_]+__|\$\(|(?:^|[;,])\s*(?:password|pwd|passfile)\s*=') {
            throw 'Replace connection placeholders and use separate Secret references for credentials; environment expansion is unsupported.'
        }
        if ($entry.name -cin $optional -and $entry.value -notmatch '^[1-9][0-9]{0,8}$') {
            throw 'Redis timeouts must be positive integer strings in milliseconds.'
        }
    }
}
foreach ($name in $required) {
    if (-not $seen.Contains($name)) { throw 'Both dependency connection strings and password Secret references are required.' }
}

$project = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../els-readiness-probe'))
$application = Join-Path $project 'src/Els.ReadinessProbe'
$settings = Read-JsonFile (Join-Path $application 'appsettings.json')
foreach ($section in @('Postgres', 'Redis')) {
    foreach ($key in @('ConnectionString', 'Password')) {
        if ($settings[$section][$key]) { throw 'Public appsettings.json must have empty dependency credentials.' }
    }
}
try {
    [xml]$nuget = Get-Content -LiteralPath (Join-Path $project 'NuGet.Config') -Raw
}
catch { throw 'Cannot read the public NuGet configuration; file contents were not printed.' }
if ($nuget.DocumentElement.Name -ne 'configuration' -or
    @($nuget.SelectNodes('/configuration/*') | Where-Object { $_.Name -ne 'packageSources' }).Count -gt 0 -or
    @($nuget.SelectNodes('/configuration/packageSources/*') | Where-Object {
        $_.Name -notin @('clear', 'add') -or
        ($_.Name -eq 'add' -and ($_.GetAttribute('value') -ne 'https://api.nuget.org/v3/index.json' -or
            @($_.Attributes | Where-Object { $_.Name -notin @('key', 'value', 'protocolVersion') }).Count -gt 0))
    }).Count -gt 0) {
    throw 'Only public nuget.org package sources are supported; NuGet credentials are not copied.'
}

$generatedRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.generated'))
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $generatedRoot ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ'))
}
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
$comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
if (-not $output.StartsWith($generatedRoot + [System.IO.Path]::DirectorySeparatorChar, $comparison)) {
    throw 'OutputDirectory must be a fresh directory beneath this project''s .generated directory.'
}
if (Test-Path -LiteralPath $output) { throw 'Output directory already exists; choose a fresh directory.' }

$environment = @($configuration.env) + @(
    @{ name = 'Probe__Enabled'; value = ($SamplingMode -eq 'background').ToString().ToLowerInvariant() },
    @{ name = 'Probe__IntervalSeconds'; value = "$IntervalSeconds" },
    @{ name = 'Probe__RecentFailureLimit'; value = '100' }
)
# JSON objects are also valid YAML flow mappings and preserve quoting exactly.
$environmentYaml = ($environment | ForEach-Object {
    '            - ' + (ConvertTo-Json -InputObject $_ -Depth 8 -Compress)
}) -join "`n"
$deployment = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'deployment.template.yaml') -Raw
$deployment = $deployment.Replace('__READINESS_PATH__', $(if ($SamplingMode -eq 'kubelet') { '/health/readiness' } else { '/health/liveness' }))
$deployment = $deployment.Replace('__READINESS_PERIOD__', $(if ($SamplingMode -eq 'kubelet') { "$IntervalSeconds" } else { '10' }))
$deployment = $deployment.Replace('__READINESS_TIMEOUT__', $(if ($SamplingMode -eq 'kubelet') { '60' } else { '2' }))
$service = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'service.yaml') -Raw
$service = $service.Replace('namespace: featbit', 'namespace: __NAMESPACE__')
$manifest = ($deployment.TrimEnd() + "`n---`n" + $service).Replace('__NAMESPACE__', (ConvertTo-Json -InputObject $Namespace -Compress))
$manifest = $manifest.Replace('__IMAGE__', (ConvertTo-Json -InputObject $Image -Compress))
$manifest = $manifest.Replace('__ENVIRONMENT__', $environmentYaml)

# Local files only: no external process, registry, Helm, or Kubernetes client.
# The runtime manifest is deliberately outside the isolated image build context.
$context = Join-Path $output 'build-context'
$stagedApplication = Join-Path $context 'src/Els.ReadinessProbe'
$null = New-Item -ItemType Directory -Path $stagedApplication
foreach ($name in @('Dockerfile', '.dockerignore')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $context $name)
}
Copy-Item -LiteralPath (Join-Path $project 'global.json') -Destination $context
foreach ($name in @('Els.ReadinessProbe.csproj', 'appsettings.json')) {
    Copy-Item -LiteralPath (Join-Path $application $name) -Destination $stagedApplication
}
Get-ChildItem -LiteralPath $application -Recurse -File -Filter '*.cs' | ForEach-Object {
    $relative = [System.IO.Path]::GetRelativePath($application, $_.FullName)
    if ($relative -split '[/\\]' | Where-Object { $_ -in @('bin', 'obj') }) { return }
    $destination = Join-Path $stagedApplication $relative
    $null = New-Item -ItemType Directory -Path (Split-Path $destination) -Force
    Copy-Item -LiteralPath $_.FullName -Destination $destination
}
$publicNuget = '<?xml version="1.0" encoding="utf-8"?><configuration><packageSources><clear /><add key="nuget.org" value="https://api.nuget.org/v3/index.json" /></packageSources></configuration>'
Set-Content -LiteralPath (Join-Path $context 'NuGet.Config') -Value $publicNuget -Encoding utf8
$manifestPath = Join-Path $output 'deployment.local.yaml'
Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding utf8

@{
    outputDirectory = $output
    buildContext = $context
    manifest = $manifestPath
    image = $Image
    namespace = $Namespace
    samplingMode = $SamplingMode
} | ConvertTo-Json -Compress
