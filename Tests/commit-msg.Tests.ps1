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

Test-Fixture "commit-msg hook tests" `
    -SetUp `
    {
        $tempPath = Get-TempTestPath

        $localRepoPath = Prepare-LocalGitRepo $tempPath
        Push-Location $localRepoPath

        tools\GitHooks\Install-GitHooks.ps1 commit-msg
    } `
    -TearDown `
    {
        Pop-Location
        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "When commit message starts with TFSxxxx it is used as is" `
        {
            git commit --allow-empty -m "TFS1234 Some message"
            $commitMessage = Get-CommitMessage

            $Assert::That($commitMessage, $Is::EqualTo("TFS1234 Some message"))
        }
    ),
    (
        Test "When commit message starts with ADH, ADH is trimmed out" `
        {
            git commit --allow-empty -m "ADH Some other message"
            $commitMessage = Get-CommitMessage

            $Assert::That($commitMessage, $Is::EqualTo("Some other message"))
        }
    ),
    (
        Test "When branch name starts with TFSxxxx, the branch name is added as a prefix to all commit messages" `
        {
            git checkout -b TFS1234 --quiet
            git commit --allow-empty -m "Some message"
            $commitMessage = Get-CommitMessage

            $Assert::That($commitMessage, $Is::EqualTo("TFS1234 Some message"))
        }
    )

Test-Fixture "commit-msg hook UI dialog tests" `
    -SetUp `
    {
        $tempPath = Get-TempTestPath

        $localRepoPath = Prepare-LocalGitRepo $tempPath
        Push-Location $localRepoPath

        tools\GitHooks\Install-GitHooks.ps1 commit-msg

        $externalProcess = Start-PowerShell { git commit --allow-empty -m "Some message" }

        Init-UIAutomation

        $dialog = Get-UIAWindow -Name "Provide TFS WorkItem ID"
    } `
    -TearDown `
    {
        Pop-Location

        Stop-ProcessTree $externalProcess

        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "When commit message does not start with TFSxxxx the dialog is shown" `
        {
            $Assert::That($dialog, $Is::Not.Null)
        }
    ),
    (
        Test "When Cancel button in the dialog is clicked commit is cancelled" `
        {
            $lastCommitMessage = Get-CommitMessage

            $dialog | `
                Get-UIAButton -Name Cancel | `
                Invoke-UIAButtonClick

            $currentCommitMessage = Get-CommitMessage

            $Assert::That($currentCommitMessage, $Is::EqualTo($lastCommitMessage))
        }
    ),
    (
        Test "When TFS WorkItem ID is entered it is used as a prefix for commit message" `
        {
            $dialog | `
                Get-UIAEdit -AutomationId workItemIdTextBox | `
                Set-UIAEditText -Text 1234

            $dialog | `
                Get-UIAButton -Name OK | `
                Invoke-UIAButtonClick

            $commitMessage = Get-CommitMessage

            $Assert::That($commitMessage, $Is::EqualTo("TFS1234 Some message"))
        }
    ),
    (
        Test "When Ad-hoc checkbox is selected commit message is used as is" `
        {
            $dialog | `
                Get-UIACheckBox -Name "Ad-hoc change" | `
                Invoke-UIACheckBoxToggle

            $dialog | `
                Get-UIAButton -Name OK | `
                Invoke-UIAButtonClick

            $commitMessage = Get-CommitMessage

            $Assert::That($commitMessage, $Is::EqualTo("Some message"))
        }
    )