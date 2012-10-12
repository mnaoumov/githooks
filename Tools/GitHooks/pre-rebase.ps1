#requires -version 2.0

[CmdletBinding()]
param
(
    [string] $NewBaseCommit,
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

if (-not $BranchName)
{
    $BranchName = Get-CurrentBranchName
}

if (Check-IsBranchPushed)
{
    $newBaseBranchName = Get-BranchName $NewBaseCommit
    $remoteBranch = Get-TrackedBranchName
    
    if ($newBaseBranchName -eq $remoteBranch)
    {
        Write-Debug "Pull rebase $BranchName with $remoteBranch detected"
        ExitWithSuccess
    }

    Write-Warning "You cannot rebase branch $BranchName because it was already pushed."
    ExitWithFailure
}
else
{
    Write-Debug "Branch $BranchName was not pushed. Rebase allowed."
    ExitWithSuccess
}