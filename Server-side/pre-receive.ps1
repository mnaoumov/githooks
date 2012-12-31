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

        $result = Test-ForcePushAllowed -UserName $commiterName

        if ($result.IsAllowed)
        {
            Write-HooksWarning "Allowing to push because of the reason '$result.Reason'"
            ExitWithSuccess
        }
        else
        {
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

    if ($NewRef -eq $missingRef)
    {
        Write-Debug "This push deletes branch $branchName"
        return $true
    }

    Write-HooksWarning "Push should be declined because it is bad."
    return $false
}

Main
