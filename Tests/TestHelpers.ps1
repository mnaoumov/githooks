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
        Pop-Location

        Copy-Item "$PSScriptRoot\..\tools" $localRepoPath -Recurse
    } | Out-Null

    $localRepoPath
}
