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

. "$PSScriptRoot\TestHelpers.ps1"

function Get-ExtensionlessFileNames
{
    param
    (
        [string] $Path
    )

    [string[]] (Get-ChildItem -Path $Path -Filter "*." | `
        Select-Object -ExpandProperty Name)
}

Test-Fixture "Install-GitHooks Tests" `
    -SetUp `
    {
        $tempPath = Get-TempTestPath

        $localRepoPath = Prepare-LocalGitRepo $tempPath
        Push-Location $localRepoPath
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
            tools\GitHooks\Install-GitHooks.ps1

            $sourceHookFiles = Get-ExtensionlessFileNames "tools\GitHooks"
            $installedHookFiles = Get-ExtensionlessFileNames ".git\hooks"

            $Assert::That($installedHookFiles, $Is::EqualTo($sourceHookFiles))
        }
    ),
    (
        Test "Install-GitHooks with parameter copies only specified hooks" `
        {
            tools\GitHooks\Install-GitHooks.ps1 -Hooks "commit-msg", "post-merge"

            $installedHookFiles = Get-ExtensionlessFileNames ".git\hooks"
            $Assert::That($installedHookFiles, $Is::EqualTo(@("commit-msg", "post-merge")))
        }
    )