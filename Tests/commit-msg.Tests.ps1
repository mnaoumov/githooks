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

function Start-PowerShell
{
    param
    (
        [ScriptBlock] $ScriptBlock
    )

    $command = ([string] $ScriptBlock) -replace "`"", "\`""

    Start-Process -FilePath PowerShell.exe -ArgumentList "-NoExit -Command `"$command`"" -PassThru -WindowStyle Minimized
}

Test-Fixture "commit-msg hook tests" `
    -SetUp `
    {
        $externalProcess = $null
        $tempPath = "$env:Temp\Test_{0}" -f (Get-Date -Format "yyyy-MM-dd_HH-mm-ss-ffff")
        New-Item -Path $tempPath -ItemType Directory

        $localRepoPath = Prepare-LocalGitRepo $tempPath
        Push-Location $localRepoPath

        tools\GitHooks\Install-GitHooks.ps1 commit-msg
    } `
    -TearDown `
    {
        if ($externalProcess -ne $null)
        {
            taskkill /PID $($externalProcess.Id) /F /T
        }

        Pop-Location
        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "When commit message starts with TFSxxxx it is used as is" `
        {
            git commit --allow-empty -m "TFS1234 Some message"
            $commitMessage = Get-CurrentCommitMessage

            $Assert::That($commitMessage, $Is::EqualTo("TFS1234 Some message"))
        }
    ),
    (
        Test "When commit message starts with ADH, ADH is trimmed out" `
        {
            git commit --allow-empty -m "ADH Some other message"
            $commitMessage = Get-CurrentCommitMessage

            $Assert::That($commitMessage, $Is::EqualTo("Some other message"))
        }
    ),
    (
        Test "When branch name starts with TFSxxxx, the branch name is added as a prefix to all commit messages" `
        {
            git checkout -b TFS1234 --quiet
            git commit --allow-empty -m "Some message"
            $commitMessage = Get-CurrentCommitMessage

            $Assert::That($commitMessage, $Is::EqualTo("TFS1234 Some message"))
        }
    )

Test-Fixture "commit-msg hook UI dialog tests" `
    -SetUp `
    {
        $tempPath = "$env:Temp\Test_{0}" -f (Get-Date -Format "yyyy-MM-dd_HH-mm-ss-ffff")
        New-Item -Path $tempPath -ItemType Directory

        $localRepoPath = Prepare-LocalGitRepo $tempPath
        Push-Location $localRepoPath

        tools\GitHooks\Install-GitHooks.ps1 commit-msg

        $externalProcess = Start-PowerShell { git commit --allow-empty -m "Some message" }

        Import-Module "$PSScriptRoot\..\packages\UIAutomation.0.8.1.NET40\UIAutomation.dll"

        $dialog = Get-UIAWindow -Name "Provide TFS WorkItem ID"
    } `
    -TearDown `
    {
        Pop-Location

        taskkill /PID $($externalProcess.Id) /F /T

        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "When commit message does not start with TFSxxx the dialog is shown" `
        {
            $Assert::That($dialog, $Is::Not.Null)
        }
    ),
    (
        Test "When Cancel button in the dialog is clicked commit is cancelled" `
        {
            $lastCommitMessage = Get-CurrentCommitMessage

            $dialog | `
                Get-UIAButton -Name Cancel | `
                Invoke-UIAButtonClick

            $currentCommitMessage = Get-CurrentCommitMessage

            $Assert::That($currentCommitMessage, $Is::EqualTo($lastCommitMessage))
        }
    )
