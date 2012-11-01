#requires -version 2.0

[CmdletBinding()]
param
(
    [string] $OldRef,
    [string] $NewRef,
    [string] $RefName
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }

. "$(PSScriptRoot)\Common.ps1"

if ($RefName -notlike "refs/heads/*")
{
    Write-Debug "$RefName is not a branch commit"
    ExitWithSuccess
}

$branchName = $RefName -replace "refs/heads/"

$nextBranch = (Get-HooksConfiguration).Merges.Merge | `
    Where-Object { ($_.branch -eq $branchName) } | `
    Select-Object -ExpandProperty into -First 1

if ($nextBranch -ne $null)
{
    Write-Warning "*****"
    Write-Warning "You pushed branch '$branchName'. Please merge it to the branch '$nextBranch' and push it as well ASAP"
    Write-Warning "*****"
}