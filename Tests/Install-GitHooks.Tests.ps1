#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

if ((Get-Module PoshUnit) -eq $null)
{
    $poshUnitFolder = if (Test-Path "$(PSScriptRoot)\..\PoshUnit.Dev.txt") { ".." } else { "..\packages\PoshUnit" }
    $poshUnitModuleFile = Resolve-Path "$(PSScriptRoot)\$poshUnitFolder\PoshUnit.psm1"

    if (-not (Test-Path $poshUnitModuleFile))
    {
        throw "$poshUnitModuleFile not found"
    }

    Import-Module $poshUnitModuleFile
}

. "$(PSScriptRoot)\TestHelpers.ps1"

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
    ),
    (
        Test "Install-GitHooks -ServerSide installs pre-receive hoook" `
        {
            $remoteRepoPath = "$tempPath\RemoteGitRepo"
            New-Item -Path $remoteRepoPath -ItemType Directory
            Push-Location $remoteRepoPath
            git init --bare
            Pop-Location

            tools\GitHooks\Install-GitHooks.ps1 -ServerSide $true -RemoteRepoPath $remoteRepoPath

            $installedHookFiles = [string[]] (Get-ChildItem -Path "$remoteRepoPath\hooks" -Exclude "*.sample" | `
                Select-Object -ExpandProperty Name)

            $Assert::That($installedHookFiles, $Is::EquivalentTo([string[]] @("pre-receive", "pre-receive.ps1", "Common.ps1")))
        }
    )