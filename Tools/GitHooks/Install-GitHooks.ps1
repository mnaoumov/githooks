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
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

if (-not $ServerSide)
{
    $gitHooksFolder = Resolve-Path "$(PSScriptRoot)\..\..\.git\hooks"

    if (-not (Test-Path $gitHooksFolder))
    {
        throw "Failed to locate .git\hooks directory"
    }

    Copy-Item -Path "$(PSScriptRoot)\*" -Filter "*." -Include $Hooks -Destination $gitHooksFolder

    Write-Host "Git hooks installed"
}
elseif (-not $RemoteRepoPath)
{
    throw "RemoteRepoPath is not specified"
}
else
{
    $gitHooksFolder = Join-Path $RemoteRepoPath "hooks"
    $commonFiles = @("Common.ps1", "HooksConfiguration.xml")
    $allServerHooks = @("pre-receive", "post-receive")
    $hooksToInstall = $allServerHooks -like $Hooks
    if (-not $hooksToInstall)
    {
        Write-Warning "No hooks to install"
    }
    else
    {
        $filesToCopy = $hooksToInstall + ($hooksToInstall | ForEach-Object { $_ + ".ps1" }) + $commonFiles
        Copy-Item -Path "$(PSScriptRoot)\*" -Include $filesToCopy -Destination $gitHooksFolder
    }
}

