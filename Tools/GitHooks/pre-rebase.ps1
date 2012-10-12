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
    ExitWithFailure
}

$currentBranchName = Get-CurrentBranchName

if (Check-IsBranchPushed)
{
    Write-Warning "You cannot rebase branch $currentBranchName because it was already pushed."
    ExitWithFailure
}
else
{
    Write-Debug "Branch $currentBranchName was not pushed. Rebase allowed."
    ExitWithSuccess
}