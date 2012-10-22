#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

function Prepare-LocalGitRepo
{
    param
    (
        [string] $Path
    )

    $localRepoPath = "$Path\LocalGitRepo"

    . `
    {
        New-Item $localRepoPath -ItemType Directory

        Push-Location $localRepoPath
        git init
        git commit --allow-empty -m "Init repo"

        Copy-Item "$PSScriptRoot\..\tools" $localRepoPath -Recurse
        git add -A
        git commit -m "Copy tools"

        Pop-Location
    } | Out-Null

    $localRepoPath
}

function Start-PowerShell
{
    param
    (
        [ScriptBlock] $ScriptBlock
    )

    $command = ([string] $ScriptBlock) -replace "`"", "\`""

    Start-Process -FilePath PowerShell.exe -ArgumentList "-Command `"$command`"" -PassThru -WindowStyle Minimized
}