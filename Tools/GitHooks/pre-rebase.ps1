#requires -version 2.0

[CmdletBinding()]
param
(
)

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent
. "$scriptFolder\Common.ps1"

$ErrorActionPreference = "Stop"

Trap [Exception] `
{
    Write-Error ($_ | Out-String)
    ExitWithCode 1
}

$currentBranchName = Get-CurrentBranchName

if (Check-IsBranchPushed)
{
    Write-Warning "Rebase of already pushed branches is not allowed"
    ExitWithCode 1
}
else
{
    Write-Debug "Branch was not pushed. Rebase allowed"
}