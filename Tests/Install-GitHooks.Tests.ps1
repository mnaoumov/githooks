#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

$poshUnitFolder = if (Test-Path "$PSScriptRoot\..\PoshUnit.Dev.txt") { ".." } else { "..\packages\PoshUnit" }
$poshUnitModuleFile = Resolve-Path "$PSScriptRoot\$poshUnitFolder\PoshUnit.psm1"

if (-not (Test-Path $poshUnitModuleFile))
{
    throw "$poshUnitModuleFile not found"
}

Import-Module $poshUnitModuleFile

function Get-ExtensionlessFileNames
{
    param
    (
        [string] $Path
    )

    Get-ChildItem -Path $Path -Filter "*." | `
        Select-Object -ExpandProperty Name
}

Test-Fixture "Install-GitHooks Tests" `
    -SetUp `
    {
        $tempPath = "$env:Temp\Test_{0}" -f (Get-Date -Format "yyyy-MM-dd_HH-mm-ss-ffff")
        New-Item -Path $tempPath -ItemType Directory

        $localRepoPath = "$tempPath\LocalGitRepo"
        New-Item $localRepoPath -ItemType Directory

        Push-Location $localRepoPath
        git init

        Copy-Item "$PSScriptRoot\..\tools" $localRepoPath -Recurse
    } `
    -TearDown `
    {
        Pop-Location
        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "Install-GitHooks copies all extensionless files from tools\GitHooks into .\git\hooks" `
        {
            & "tools\GitHooks\Install-GitHooks.ps1"

            $sourceHookFiles = Get-ExtensionlessFileNames "tools\GitHooks"
            $installedHookFiles = Get-ExtensionlessFileNames ".git\hooks"

            $Assert::That($installedHookFiles, $Is::EqualTo($sourceHookFiles))
        }
    )