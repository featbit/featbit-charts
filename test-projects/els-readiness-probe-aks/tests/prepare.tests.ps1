#Requires -Version 7.0
# Local file tests only. No registry, container engine, or cluster client is used.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$directory = Split-Path $PSScriptRoot
$prepare = Join-Path $directory 'prepare.ps1'
$testRoot = Join-Path $directory ('.generated/prepare-tests-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$script:caseNumber = 0
$script:passed = 0

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-Configuration {
    $configuration = Get-Content -LiteralPath (Join-Path $directory 'runtime-config.example.json') -Raw | ConvertFrom-Json -AsHashtable
    $configuration.env[0].value = 'Host=pg.example.invalid;Port=5432;Username=reader;Database=featbit;SSL Mode=VerifyFull;Application Name="Probe: test #1"'
    $configuration.env[2].value = 'redis.example.invalid:6380,defaultDatabase=0,abortConnect=false,ssl=true,user=reader'
    return $configuration
}

function Invoke-Preparation($Configuration, [string]$Mode = 'background', [string]$Namespace = 'featbit') {
    $script:caseNumber++
    $configPath = Join-Path $testRoot "config-$script:caseNumber.local.json"
    $output = Join-Path $testRoot "output-$script:caseNumber"
    $Configuration | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding utf8
    $before = (Get-FileHash -LiteralPath $configPath).Hash
    $result = & $prepare -Image 'example.azurecr.io/els-readiness-probe:test' -ConfigFile $configPath `
        -SamplingMode $Mode -Namespace $Namespace -IntervalSeconds 45 -OutputDirectory $output | ConvertFrom-Json
    Assert ((Get-FileHash -LiteralPath $configPath).Hash -eq $before) 'Preparation changed its input configuration.'
    $result | Add-Member -NotePropertyName configPath -NotePropertyValue $configPath -PassThru
}

function Read-Environment([string]$Manifest) {
    [regex]::Matches($Manifest, '(?m)^\s+- (\{[^\r\n]+\})\r?$') | ForEach-Object {
        $_.Groups[1].Value | ConvertFrom-Json -AsHashtable
    }
}

function Assert-Rejected($Configuration) {
    $rejected = $false
    try { $null = Invoke-Preparation $Configuration }
    catch {
        Assert (-not $_.ToString().Contains('DO-NOT-PRINT-CANARY')) 'Preparation disclosed a rejected credential.'
        $rejected = $true
    }
    Assert $rejected 'Invalid configuration was accepted.'
}

function Test-Case([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:passed++
    Write-Output "PASS: $Name"
}

Test-Case 'Exact connection strings, shared Secret references, and isolated resources' {
    $configuration = New-Configuration
    $configuration.env += @{ name = 'Redis__ConnectTimeoutMs'; value = '2500' }
    $result = Invoke-Preparation $configuration
    $manifest = Get-Content -LiteralPath $result.manifest -Raw
    $entries = @(Read-Environment $manifest)
    Assert ($entries.Count -eq 8) 'Unexpected number of environment entries.'
    Assert (@($entries.name | Select-Object -Unique).Count -eq $entries.Count) 'Duplicate environment entries.'
    foreach ($expected in $configuration.env) {
        $actual = @($entries | Where-Object { $_.name -ceq $expected.name })[0]
        if ($expected.Contains('value')) {
            Assert ($actual.value -ceq $expected.value) 'A literal connection parameter or timeout changed.'
        }
        else {
            Assert ($actual.valueFrom.secretKeyRef.name -ceq $expected.valueFrom.secretKeyRef.name) 'Secret name changed.'
            Assert ($actual.valueFrom.secretKeyRef.key -ceq $expected.valueFrom.secretKeyRef.key) 'Secret key changed.'
        }
    }
    Assert ([regex]::Matches($manifest, '(?m)^kind: (Deployment|Service)\r?$').Count -eq 2) 'Unexpected resource kinds.'
    Assert ($manifest -notmatch '(?m)^kind: Secret\r?$') 'Preparation created a Secret.'
    Assert ([regex]::Matches($manifest, 'app.kubernetes.io/instance: els-readiness-probe').Count -eq 5) 'Resource selectors lost isolation.'
    Assert ($manifest -match 'replicas: 1' -and $manifest -match 'type: Recreate') 'Sampler replica settings changed.'
    Assert ($manifest -notmatch '__[A-Z_]+__') 'Manifest has unexpanded placeholders.'
}

Test-Case 'Sampling modes keep liveness independent and avoid double sampling' {
    foreach ($mode in @('background', 'kubelet')) {
        $result = Invoke-Preparation (New-Configuration) $mode 'probe-tests'
        $manifest = Get-Content -LiteralPath $result.manifest -Raw
        $enabled = @(Read-Environment $manifest | Where-Object { $_.name -ceq 'Probe__Enabled' })[0].value
        Assert ($enabled -ceq ($mode -eq 'background').ToString().ToLowerInvariant()) 'Sampler enablement is incorrect.'
        Assert ([regex]::Matches($manifest, 'namespace: "probe-tests"').Count -eq 2) 'Namespace was not applied to both resources.'
        $paths = @([regex]::Matches($manifest, 'path: /health/(liveness|readiness)') | ForEach-Object { $_.Groups[1].Value })
        Assert ($paths[0] -eq 'liveness' -and $paths[1] -eq 'liveness') 'Dependency health affects startup or liveness.'
        Assert ($paths[2] -eq $(if ($mode -eq 'kubelet') { 'readiness' } else { 'liveness' })) 'Readiness mode is incorrect.'
        if ($mode -eq 'kubelet') {
            Assert ($manifest -match 'periodSeconds: 45\s+timeoutSeconds: 60') 'Kubelet readiness timeout/interval changed.'
        }
    }
}

Test-Case 'Build context excludes runtime connection settings and local files' {
    $result = Invoke-Preparation (New-Configuration)
    Assert (Test-Path -LiteralPath (Join-Path $result.buildContext 'Dockerfile')) 'Dockerfile is missing.'
    Assert (Test-Path -LiteralPath (Join-Path $result.buildContext 'src/Els.ReadinessProbe/Program.cs')) 'Application source is missing.'
    Get-ChildItem -LiteralPath $result.buildContext -Recurse -File | ForEach-Object {
        $relative = [System.IO.Path]::GetRelativePath($result.buildContext, $_.FullName)
        Assert ($relative -notmatch '(^|[/\\])(bin|obj|tests)([/\\]|$)|\.local\.|appsettings\.Local|\.env') 'Private or generated files entered the context.'
        $content = Get-Content -LiteralPath $_.FullName -Raw
        Assert ($content -notmatch 'pg\.example\.invalid|redis\.example\.invalid|featbit-pg-wu3-secret|featbit-redis-wu3-secret') 'Runtime configuration entered the build context.'
    }
    $source = Join-Path $directory '../els-readiness-probe/src/Els.ReadinessProbe'
    $expectedSources = @(Get-ChildItem -LiteralPath $source -Recurse -File -Filter '*.cs' | Where-Object {
        [System.IO.Path]::GetRelativePath($source, $_.FullName) -notmatch '(^|[/\\])(bin|obj)([/\\]|$)'
    })
    $stagedSources = @(Get-ChildItem -LiteralPath $result.buildContext -Recurse -File -Filter '*.cs')
    Assert ($expectedSources.Count -eq $stagedSources.Count) 'Not all public application sources were staged.'
}

Test-Case 'A complete connection string can reference an existing Secret' {
    $configuration = New-Configuration
    $configuration.env[0] = @{ name = 'Postgres__ConnectionString'; valueFrom = @{ secretKeyRef = @{ name = 'shared-pg-connection'; key = 'connection' } } }
    $result = Invoke-Preparation $configuration
    $entry = @(Read-Environment (Get-Content -LiteralPath $result.manifest -Raw) | Where-Object { $_.name -ceq 'Postgres__ConnectionString' })[0]
    Assert ($entry.valueFrom.secretKeyRef.name -ceq 'shared-pg-connection') 'Whole-connection Secret reference was lost.'
}

Test-Case 'Reject duplicate names, missing entries, and unsupported environment variables' {
    $configuration = New-Configuration
    $configuration.env += $configuration.env[0]
    Assert-Rejected $configuration
    $configuration = New-Configuration
    $configuration.env = @($configuration.env | Where-Object { $_.name -cne 'Redis__Password' })
    Assert-Rejected $configuration
    $configuration = New-Configuration
    $configuration.env += @{ name = 'UNRELATED_SETTING'; value = 'DO-NOT-PRINT-CANARY' }
    Assert-Rejected $configuration
}

Test-Case 'Reject literal credentials, connection expansion, and unresolved placeholders' {
    $configuration = New-Configuration
    $configuration.env[1] = @{ name = 'Postgres__Password'; value = 'DO-NOT-PRINT-CANARY' }
    Assert-Rejected $configuration
    $configuration = New-Configuration
    $configuration.env[0].value += ';Password=DO-NOT-PRINT-CANARY'
    Assert-Rejected $configuration
    $configuration = New-Configuration
    $configuration.env[0].value += ';Password=$(PASSWORD)'
    Assert-Rejected $configuration
    $configuration = New-Configuration
    $configuration.env[0].value = '__POSTGRES_CONNECTION_STRING__'
    Assert-Rejected $configuration
}

Test-Case 'Malformed JSON errors do not disclose input contents' {
    $configPath = Join-Path $testRoot 'malformed.local.json'
    Set-Content -LiteralPath $configPath -Value '{"password":"DO-NOT-PRINT-CANARY' -Encoding utf8
    $rejected = $false
    try { $null = & $prepare -Image 'probe:test' -ConfigFile $configPath }
    catch {
        Assert (-not $_.ToString().Contains('DO-NOT-PRINT-CANARY')) 'JSON parser error disclosed input contents.'
        $rejected = $true
    }
    Assert $rejected 'Malformed JSON was accepted.'
}

Test-Case 'An existing output directory is never overwritten' {
    $result = Invoke-Preparation (New-Configuration)
    $before = (Get-FileHash -LiteralPath $result.manifest).Hash
    $rejected = $false
    try { $null = & $prepare -Image 'probe:replacement' -ConfigFile $result.configPath -OutputDirectory $result.outputDirectory }
    catch { $rejected = $true }
    Assert $rejected 'Existing output was overwritten.'
    Assert ((Get-FileHash -LiteralPath $result.manifest).Hash -eq $before) 'Existing manifest changed.'
}

Write-Output "$script:passed local preparation tests passed. Artifacts: $testRoot"
