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
. "$(PSScriptRoot)\..\Tools\GitHooks\Common.ps1"

Test-Fixture "pre-rebase hooks" `
    -SetUp `
    {
        $tempPath = Get-TempTestPath
        $localRepoPath = Prepare-LocalGitRepo $tempPath

        $remoteRepoPath = "$tempPath\RemoteGitRepo"
        New-Item -Path $remoteRepoPath -ItemType Directory
        Push-Location $remoteRepoPath
        git init --bare
        Pop-Location

        Push-Location $localRepoPath
        git remote add origin $remoteRepoPath
        git push origin master --set-upstream
        tools\GitHooks\Install-GitHooks.ps1 pre-rebase

        New-Item -Path "BeforeRebase.txt" -ItemType File
        git add "BeforeRebase.txt"
        git commit -m "Before rebase"
        git push origin master

        git checkout -b other_branch

        New-Item -Path "SomeFile.txt" -ItemType File
        git add "SomeFile.txt"
        git commit -m "Some change"

        git checkout master

        New-Item -Path "SomeOtherFile.txt" -ItemType File
        git add "SomeOtherFile.txt"
        git commit -m "Some other change"
        git push origin master
    } `
    -TearDown `
    {
        Pop-Location
        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "Rebase of local branches is allowed" `
        {
            git checkout other_branch
            git rebase master

            $rebaseExitCode = $LASTEXITCODE

            $Assert::That($rebaseExitCode, $Is::EqualTo(0))
        }
    ),
    (
        Test "Rebase of pushed branches is not allowed" `
        {
            git rebase other_branch

            $rebaseExitCode = $LASTEXITCODE

            $Assert::That($rebaseExitCode, $Is::EqualTo(1))
        }
    ),
    (
        Test "Rebase of pushed branches on tracked remote branch is allowed" `
        {
            $anotherLocalRepoPath = "$tempPath\AnotherLocalGitRepo"
            New-Item -Path $anotherLocalRepoPath -ItemType Directory

            Push-Location $anotherLocalRepoPath
            git clone $remoteRepoPath .
            New-Item -Path "SomeRemoteChange.txt" -ItemType File
            git add "SomeRemoteChange.txt"
            git commit -m "Some remote change"
            git push
            Pop-Location

            git fetch origin

            git rebase origin/master

            $rebaseExitCode = $LASTEXITCODE

            $Assert::That($rebaseExitCode, $Is::EqualTo(0))
        }
    ),
    (
        Test "Rebase of pushed branches on descendant of tracked remote branch is allowed" `
        {
            New-Item -Path "ChangeInMaster.txt" -ItemType File
            git add "ChangeInMaster.txt"
            git commit -m "Change in master"

            git checkout HEAD~1 -b new_branch
            New-Item -Path "NewChange.txt" -ItemType File
            git add "NewChange.txt"
            git commit -m "New change"

            git checkout master

            git rebase new_branch

            $rebaseExitCode = $LASTEXITCODE

            $Assert::That($rebaseExitCode, $Is::EqualTo(0))
        }
    )