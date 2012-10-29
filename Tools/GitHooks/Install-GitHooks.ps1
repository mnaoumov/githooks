#requires -version 2.0

[CmdletBinding()]
param
(
    [string[]] $Hooks = "*",
    [bool] $ServerSide = $false,
    [string] $RemoteRepoPath = ""
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

if (-not $ServerSide)
{
    $gitHooksFolder = Resolve-Path "$PSScriptRoot\..\..\.git\hooks"

    if (-not (Test-Path $gitHooksFolder))
    {
        throw "Failed to locate .git\hooks directory"
    }

    Copy-Item -Path "$PSScriptRoot\*" -Filter "*." -Include $Hooks -Destination $gitHooksFolder

    Write-Host "Git hooks installed"
}
elseif (-not $RemoteRepoPath)
{
    throw "RemoteRepoPath is not specified"
}
else
{
    $gitHooksFolder = Join-Path $RemoteRepoPath "hooks"
    Copy-Item -Path "$PSScriptRoot\*" -Include "pre-receive", "pre-receive.ps1", "Common.ps1" -Destination $gitHooksFolder
}

