#requires -version 2.0

[CmdletBinding()]
param
(
    [string] $NewBaseBranchName
    [string] $BranchName
)

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent
. "$scriptFolder\Common.ps1"

$ErrorActionPreference = "Stop"

Trap [Exception] `
{
    Write-Error ($_ | Out-String)
    ExitWithFailure
}

if ([Convert]::ToBoolean((Get-HooksConfiguration).Branches.allowRebasePushedBranches))
{
    Write-Debug "Rebases/@allowRebasePushedBranches is enabled in HooksConfiguration.xml"
    ExitWithSuccess
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