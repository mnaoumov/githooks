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

Test-Fixture "post-commit hooks tests for conflict pull merge" `
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

            Wait-ProcessExit $externalProcess

            $commitMessage = Get-CommitMessage

            $Assert::IsTrue((Test-MergeCommit))
        }
    ),
    (
        Test "When Yes button in the dialog is clicked rebase conflict occurs" `
        {
            $dialog | `
                Get-UIAButton -Name Yes | `
                Invoke-UIAButtonClick

            Wait-ProcessExit $externalProcess

            $Assert::IsTrue((Test-RebaseInProcess))
        }
    ),
    (
        Test "When Yes button in the dialog is clicked pull is reset and rebased" `
        {
            $dialog | `
                Get-UIAButton -Name Yes | `
                Invoke-UIAButtonClick

            Wait-ProcessExit $externalProcess

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

            Wait-ProcessExit $externalProcess

            $Assert::IsTrue((Test-RebaseInProcess))
        }
    ),
    (
        Test "When 'Yes, permanently' button in the dialog is clicked pull is reset and rebased" `
        {
            $dialog | `
                Get-UIAButton -Name "Yes, permanently" | `
                Invoke-UIAButtonClick

            Wait-ProcessExit $externalProcess

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

            Wait-ProcessExit $externalProcess

            $setting = git config branch.master.rebase
            $Assert::That($setting, $Is::EqualTo("true"))
        }
    )


Test-Fixture "post-commit hooks tests for allowed and unallowed conflict merges" `
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

        New-Item -Path "ReadyForRelease10.txt" -ItemType File
        git add "ReadyForRelease10.txt"
        git commit -m "Ready for release 1.0"
        git push origin master
        git checkout -b release.1.0

        New-Item -Path "SomeFile.txt" -ItemType File -Value "Change that will cause conflict merge"
        git add "SomeFile.txt"
        git commit -m "Change that will cause conflict merge"
        git push origin release.1.0 --set-upstream

        git checkout master
        New-Item -Path "SomeFile.txt" -ItemType File -Value "Another change that will cause conflict merge"
        git add "SomeFile.txt"
        git commit -m "Another change that will cause conflict merge"

        $externalProcess = $null
    } `
    -TearDown `
    {
        Pop-Location

        Stop-ProcessTree $externalProcess

        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "Merge allowed branches from configuration is made as is" `
        {
            git merge release.1.0
            git add -A
            git commit -F ".git\\MERGE_MSG"

            $Assert::IsTrue((Test-MergeCommit))
        }
    ),
    (
        Test "Merge unallowed branches from configuration prompts UI dialog" `
        {
            git checkout release.1.0
            git merge master
            git add -A

            $externalProcess = Start-PowerShell { git commit -F ".git\\MERGE_MSG" }

            Init-UIAutomation

            $dialog = Get-UIAWindow -Name "Unallowed merge"
            $Assert::That($dialog, $Is::Not.Null)
        }
    ),
    (
        Test "When No button in the dialog is clicked pull merge is preserved" `
        {
            git checkout release.1.0
            git merge master
            git add -A
            
            $externalProcess = Start-PowerShell { git commit -F ".git\\MERGE_MSG" }

            Init-UIAutomation

            $dialog = Get-UIAWindow -Name "Unallowed merge"

            $dialog | `
                Get-UIAButton -Name No | `
                Invoke-UIAButtonClick

            Wait-ProcessExit $externalProcess

            $Assert::IsTrue((Test-MergeCommit))
        }
    ),
    (
        Test "When Yes button in the dialog is clicked pull merge is rolled back" `
        {
            git checkout release.1.0
            git merge master
            git add -A
            
            $externalProcess = Start-PowerShell { git commit -F ".git\\MERGE_MSG" }

            Init-UIAutomation

            $dialog = Get-UIAWindow -Name "Unallowed merge"

            $dialog | `
                Get-UIAButton -Name Yes | `
                Invoke-UIAButtonClick

            Wait-ProcessExit $externalProcess

            $Assert::IsFalse((Test-MergeCommit))
        }
    )