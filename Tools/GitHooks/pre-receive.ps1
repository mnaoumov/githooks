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
Trap { throw $_ }

. "$(PSScriptRoot)\Common.ps1"
. "$(PSScriptRoot)\GoogleSpreadsheetHelper\GoogleSpreadSheetHelper.ps1"

function Main
{
    $success = Test-PushAllowed

    if ($success)
    {
        ExitWithSuccess
    }
    else
    {
        $commiterName = git log -1 $NewRef --format=%cN

        if (-not ([Convert]::ToBoolean((Get-HooksConfiguration).Pushes.allowForcePushes)))
        {
            Write-Debug "Pushes/@allowForcePushes is disabled in HooksConfiguration.xml"
            ExitWithFailure
        }

        $result = Test-ForcePushAllowed -UserName $commiterName

        if ($result.IsAllowed)
        {
            Write-HooksWarning "Allowing to push because of the reason '$($result.Reason)'"
            ExitWithSuccess
        }
        else
        {
            Write-Debug "Force push is not allowed for '$commiterName'"
            ExitWithFailure
        }
    }
}

function Test-PushAllowed
{
    if ($RefName -notlike "refs/heads/*")
    {
        Write-Debug "$RefName is not a branch commit."
        return $true
    }

    $branchName = $RefName -replace "refs/heads/"

    $missingRef = "0000000000000000000000000000000000000000"

    if ($OldRef -eq $missingRef)
    {
        Write-Debug "$branchName is a new branch"
        return $true
    }

    if ($NewRef -eq $missingRef)
    {
        Write-Debug "This push deletes branch $branchName"
        return $true
    }

    $mergeCommits = @(git log --first-parent --merges --format=%H "$OldRef..$NewRef")
    if (-not $mergeCommits)
    {
        ExitWithSuccess
    }

    [Array]::Reverse($mergeCommits)

    foreach ($mergeCommit in $mergeCommits)
    {
        $firstParentCommit = git rev-parse $mergeCommit^1
        if (-not (Test-FastForward -From $OldRef -To $firstParentCommit))
        {
            $commitMessage = git log -1 $mergeCommit --format=oneline
            Write-HooksWarning "The following commit should not exist in branch $branchName`n$commitMessage`nPlease execute 'git pull --rebase' and try to push again"
            ExitWithFailure
        }
    }

    ExitWithSuccess
}

Main
