#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

$poshUnitFolder = if (Test-Path "$PSScriptRoot\PoshUnit.Dev.txt") { $PSScriptRoot } else { "$PSScriptRoot\packages\PoshUnit" }

$poshUnitModuleFile = "$poshUnitFolder\PoshUnit.psm1"

if (-not (Test-Path $poshUnitModuleFile))
{
    throw "$poshUnitModuleFile is not found"
}

Import-Module $poshUnitModuleFile

Invoke-PoshUnit