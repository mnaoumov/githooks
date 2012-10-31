#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }

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

Test-Fixture "pre-receive hooks" `
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

        New-Item -Path "ReadyForRelease10.txt" -ItemType File
        git add "ReadyForRelease10.txt"
        git commit -m "Ready for release 1.0"
        git push origin master
        git checkout -b release.1.0
        New-Item -Path "FixForRelease10.txt" -ItemType File
        git add "FixForRelease10.txt"
        git commit -m "Fix for release 1.0"
        git push origin release.1.0 --set-upstream
        git checkout master
        New-Item -Path "FeatureForFutureReleases.txt" -ItemType File
        git add "FeatureForFutureReleases.txt"
        git commit -m "Fix for future releases"

        tools\GitHooks\Install-GitHooks.ps1 "pre-receive" -ServerSide $true -RemoteRepoPath $remoteRepoPath
    } `
    -TearDown `
    {
        Pop-Location
        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "Normal push is allowed" `
        {
            git merge release.1.0
            git push origin master

            $pushExitCode = $LASTEXITCODE

            $Assert::That($pushExitCode, $Is::EqualTo(0))
        }
    ),
    (
        Test "Push of branch reset after merge is not allowed" `
        {
            git merge release.1.0
            git push origin master
            git checkout release.1.0
            git reset --hard origin/master
            git push origin release.1.0

            $pushExitCode = $LASTEXITCODE

            $Assert::That($pushExitCode, $Is::EqualTo(1))
        }
    )