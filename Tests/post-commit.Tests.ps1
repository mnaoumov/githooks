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

Test-Fixture "post-commit hooks tests" `
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
        tools\GitHooks\Install-GitHooks.ps1 post-commit
        Pop-Location

        $anotherLocalRepoPath = "$tempPath\AnotherLocalGitRepo"
        New-Item -Path $anotherLocalRepoPath -ItemType Directory

        Push-Location $anotherLocalRepoPath
        git clone $remoteRepoPath .
        New-Item -Path "SomeFile.txt" -ItemType File -Value "Change that will cause conflict pull merge"
        git add "SomeFile.txt"
        git commit -m "Change that will cause conflict pull merge"
        git push
        Pop-Location

        Push-Location $localRepoPath
        New-Item -Path "SomeFile.txt" -ItemType File -Value "Another change that will cause conflict pull merge"
        git add "SomeFile.txt"
        git commit -m "Another change that will cause conflict pull merge"

        git pull
        git add -A

        function TearDown
        {
            Pop-Location

            Stop-ProcessTree $externalProcess

            Remove-Item -Path $tempPath -Recurse -Force
        }

        try
        {
            $externalProcess = Start-PowerShell { git commit -F ".git\\MERGE_MSG" }

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
        Test "After conflict merge pull UI dialog is shown" `
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

            $Assert::That((Test-MergeCommit), $Is::True)
        }
    ),
    (
        Test "When Yes button in the dialog is clicked rebase conflict occurs" `
        {
            $dialog | `
                Get-UIAButton -Name Yes | `
                Invoke-UIAButtonClick

            $Assert::That((Test-RebaseInProcess), $Is::True)
        }
    ),
    (
        Test "When Yes button in the dialog is clicked pull is reset and rebased" `
        {
            $dialog | `
                Get-UIAButton -Name Yes | `
                Invoke-UIAButtonClick

            git add -A
            git rebase --continue

            $commitMessage = Get-CommitMessage
            $previousCommitMessage = Get-CommitMessage HEAD~1

            $Assert::That($commitMessage, $Is::EqualTo("Another change that will cause conflict pull merge"))
            $Assert::That($previousCommitMessage, $Is::EqualTo("Change that will cause conflict pull merge"))
        }
    ),
    (
        Test "When 'Yes, permanently' button in the dialog is clicked rebase conflict occurs" `
        {
            $dialog | `
                Get-UIAButton -Name "Yes, permanently" | `
                Invoke-UIAButtonClick

            $Assert::That((Test-RebaseInProcess), $Is::True)
        }
    ),
    (
        Test "When 'Yes, permanently' button in the dialog is clicked pull is reset and rebased" `
        {
            $dialog | `
                Get-UIAButton -Name "Yes, permanently" | `
                Invoke-UIAButtonClick

            git add -A
            git rebase --continue

            $commitMessage = Get-CommitMessage
            $previousCommitMessage = Get-CommitMessage HEAD~1

            $Assert::That($commitMessage, $Is::EqualTo("Another change that will cause conflict pull merge"))
            $Assert::That($previousCommitMessage, $Is::EqualTo("Change that will cause conflict pull merge"))
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