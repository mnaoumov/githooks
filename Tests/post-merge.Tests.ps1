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
. "$PSScriptRoot\..\Tools\GitHooks\Common.ps1"

Test-Fixture "post-merge hooks tests for non-conflict pull merge" `
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
        tools\GitHooks\Install-GitHooks.ps1 post-merge
        Pop-Location

        $anotherLocalRepoPath = "$tempPath\AnotherLocalGitRepo"
        New-Item -Path $anotherLocalRepoPath -ItemType Directory

        Push-Location $anotherLocalRepoPath
        git clone $remoteRepoPath .
        New-Item -Path "SomeFile.txt" -ItemType File
        git add "SomeFile.txt"
        git commit -m "Change"
        git push
        Pop-Location

        Push-Location $localRepoPath
        New-Item -Path "SomeOtherFile.txt" -ItemType File
        git add "SomeOtherFile.txt"
        git commit -m "Change that will cause non-conflict merge"

        function TearDown
        {
            Pop-Location

            if (($externalProcess -ne $null) -and (-not $externalProcess.HasExited))
            {
                taskkill /PID $($externalProcess.Id) /F /T
            }

            Remove-Item -Path $tempPath -Recurse -Force
        }

        try
        {
            $externalProcess = Start-PowerShell { git pull }

            Init-UIAutomation

            $dialog = Get-UIAWindow -Name "Merge pull warning"
        }
        catch
        {
            TearDown
            throw
        }
    } `
    -TearDown `
    {
        TearDown
    } `
    -Tests `
    (
        Test "After non-conflict merge pull UI dialog is shown" `
        {
            $Assert::That($dialog, $Is::Not.Null)
        }
    ),
    (
        Test "When No button in the dialog is clicked pull merge is preserved" `
        {
            $dialog | `
                Get-UIAButton -Name No | `
                Invoke-UIAButtonClick

            $commitMessage = Get-CommitMessage

            $Assert::That($commitMessage, $Is::StringStarting("Merge branch 'master'"))
        }
    ),
    (
        Test "When Yes button in the dialog is clicked pull is reset and rebased" `
        {
            $dialog | `
                Get-UIAButton -Name Yes | `
                Invoke-UIAButtonClick

            $commitMessage = Get-CommitMessage
            $previousCommitMessage = Get-CommitMessage HEAD~1

            $Assert::That($commitMessage, $Is::EqualTo("Change that will cause non-conflict merge"))
            $Assert::That($previousCommitMessage, $Is::EqualTo("Change"))
        }
    ),
    (
        Test "When 'Yes, permanently' button in the dialog is clicked pull is reset and rebased" `
        {
            $dialog | `
                Get-UIAButton -Name "Yes, permanently" | `
                Invoke-UIAButtonClick

            $commitMessage = Get-CommitMessage
            $previousCommitMessage = Get-CommitMessage HEAD~1

            $Assert::That($commitMessage, $Is::EqualTo("Change that will cause non-conflict merge"))
            $Assert::That($previousCommitMessage, $Is::EqualTo("Change"))
        }
    ),
    (
        Test "When 'Yes, permanently' button in the dialog is clicked pull rebase setting is set to true" `
        {
            $dialog | `
                Get-UIAButton -Name "Yes, permanently" | `
                Invoke-UIAButtonClick

            $setting = git config branch.master.rebase
            $Assert::That($setting, $Is::EqualTo("true"))
        }
    )

Test-Fixture "post-merge hooks tests for allowed and unallowed non-conflict merges" `
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
        tools\GitHooks\Install-GitHooks.ps1 post-merge

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

        $externalProcess = $null
    } `
    -TearDown `
    {
        Pop-Location

        if (($externalProcess -ne $null) -and (-not $externalProcess.HasExited))
        {
            taskkill /PID $($externalProcess.Id) /F /T
        }

        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "Merge allowed branches from configuration is made as is" `
        {
            git merge release.1.0

            $Assert::That((Test-MergeCommit), $Is::True)
        }
    ),
    (
        Test "Merge unallowed branches from configuration prompts UI dialog" `
        {
            git checkout release.1.0
            $externalProcess = Start-PowerShell { git merge master }

            Init-UIAutomation

            $dialog = Get-UIAWindow -Name "Unallowed merge"

            $Assert::That($dialog, $Is::Not.Null)
        }
    )