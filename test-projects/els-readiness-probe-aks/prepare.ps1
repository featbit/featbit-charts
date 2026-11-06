[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Image,
    [string]$ValuesFile,
    [string]$Namespace = 'featbit',
    [ValidateSet('background', 'kubelet')]
    [string]$SamplingMode = 'background',
    [ValidateRange(1, 3600)]
    [int]$IntervalSeconds = 30,
    [string]$OutputDirectory,
    [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
$prepareArguments = @(
    (Join-Path $PSScriptRoot 'prepare.py'),
    '--image', $Image, '--namespace', $Namespace,
    '--sampling-mode', $SamplingMode, '--interval-seconds', "$IntervalSeconds"
)
if ($ValuesFile) { $prepareArguments += @('--values', $ValuesFile) }
if ($OutputDirectory) { $prepareArguments += @('--output', $OutputDirectory) }

# Local files only. No build, push, Helm or cluster commands are invoked.
& $Python @prepareArguments
if ($LASTEXITCODE -ne 0) { throw 'Local preparation failed. No cloud or cluster commands were run.' }
