#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

$TestTimeout = 60000

function Prepare-LocalGitRepo
{
    param
    (
        [string] $Path
    )

    $localRepoPath = "$Path\LocalGitRepo"

    . `
    {
        New-Item $localRepoPath -ItemType Directory

        Push-Location $localRepoPath
        git init
        git commit --allow-empty -m "Init repo"

        Copy-Item "$PSScriptRoot\..\tools" $localRepoPath -Recurse
        git add -A
        git commit -m "Copy tools"

        Pop-Location
    } | Out-Null

    $localRepoPath
}

function Start-PowerShell
{
    param
    (
        [ScriptBlock] $ScriptBlock
    )

    $command = ([string] $ScriptBlock) -replace "`"", "\`""

    Start-Process -FilePath PowerShell.exe -ArgumentList "-Command `"$command`"" -PassThru -WindowStyle Minimized
}

function Init-UIAutomation
{
    Import-Module "$PSScriptRoot\..\packages\UIAutomation.0.8.1.NET40\UIAutomation.dll"
    [UIAutomation.Mode]::Profile = "Normal"
    [UIAutomation.Preferences]::Timeout = $TestTimeout
}

function Stop-ProcessTree
{
    param
    (
        [System.Diagnostics.Process] $Process
    )

    if (($Process -ne $null) -and (-not $Process.HasExited))
    {
        taskkill /PID $($Process.Id) /F /T
    }
}

function Wait-ProcessExit
{
    param
    (
        [System.Diagnostics.Process] $Process
    )

    if (($Process -ne $null) -and (-not $Process.HasExited))
    {
        $Process.WaitForExit($TestTimeout)
    }
}