#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

. "$(PSScriptRoot)\GoogleSpreadsheetHelper\GoogleSpreadSheetHelper.ps1"

function Main
{
    $branchName = Get-CurrentBranchName

    Write-Host "Please privide a reason why do you need to do force push of branch '$branchName' and bypass server-side hooks. Leave it blank if you want to cancel."
    $reason = Read-Host -Prompt "Reason"

    if (-not $reason)
    {
        Write-Warning "Reason was not provided. Force push cancelled"
        exit 1
    }

    $userName = git config user.name

    Enable-ForcePush -UserName $userName -Reason $reason

    git push origin $branchName

    Disable-ForcePush -UserName $userName
}

function Get-CurrentBranchName
{
    git rev-parse --abbrev-ref HEAD
}

Main