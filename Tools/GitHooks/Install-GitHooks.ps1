#requires -version 2.0

[CmdletBinding()]
param
(
)

$ErrorActionPreference = "Stop"

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Join-Path $scriptFolder "..\..\"
$gitHooksFolder = Join-Path $repoRoot ".git\hooks"

if (-not (Test-Path $gitHooksFolder))
{
    throw "Failed to locate .git\hooks directory"
}

Get-ChildItem -Path $scriptFolder | `
    Where-Object -Filter { $_.Extension -eq "" } | `
    Copy-Item -Destination $gitHooksFolder

Write-Host "Git hooks installed"