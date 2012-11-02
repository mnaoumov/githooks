#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

function ExitWithCode
{ 
    param
    (
        [int] $exitCode
    )

    $host.SetShouldExit($exitCode)
    exit
}

function ExitWithSuccess
{
    ExitWithCode 0
}

function ExitWithFailure
{
    ExitWithCode 1
}

function Get-HooksConfiguration
{
    ([xml] (Get-Content "$(PSScriptRoot)\HooksConfiguration.xml")).HooksConfiguration
}

function Set-HooksConfiguration
{
    param
    (
        [System.Xml.XmlElement] $HooksConfiguration
    )

    $HooksConfiguration.OwnerDocument.Save("$(PSScriptRoot)\HooksConfiguration.xml")
}

function Test-MergeCommit
{
    (git rev-parse --verify --quiet HEAD^2) -ne $null
}

function Get-CurrentBranchName
{
    git rev-parse --abbrev-ref HEAD
}

function Get-MergedBranchName
{
    Get-BranchName HEAD^2
}

function Get-TrackedBranchName
{
    param
    (
        [string] $BranchName
    )

    if (-not $BranchName)
    {
        $BranchName = Get-CurrentBranchName
    }

    $remote = git config branch.$BranchName.remote
    if (-not $remote)
    {
        $remote = "origin"
    }

    $remoteBranch = "$remote/$BranchName"

    $remoteBranches = (git branch --remote) -replace "^  "

    if ($remoteBranches -contains $remoteBranch)
    {
        return $remoteBranch
    }
    else
    {
        return $null
    }
}

function Test-PullMerge
{
    (Get-MergedBranchName) -eq (Get-TrackedBranchName)
}

function Get-CommitMessage
{
    param
    (
        [string] $Rev = "HEAD"
    )

    git log $Rev -1 --format=%s
}

function Test-BranchPushed
{
    (Get-TrackedBranchName) -ne $null
}

function Get-BranchName
{
    param
    (
        [string] $Commit
    )

    (git name-rev --name-only $Commit) -replace "remotes/"
}

function Test-FastForward
{
    param
    (
        [string] $From,
        [string] $To
    )

    $From = git rev-parse $From
    $mergeBase = git merge-base $From $To

    $mergeBase -eq $From
}

function Get-RepoRoot
{
    git rev-parse --show-toplevel
}

function Test-RebaseInProcess
{
    Test-Path "$(Get-RepoRoot)\.git\rebase-apply"
}

function Write-HooksWarning
{
    param
    (
        [string] $Message
    )

    $maxLength = 70

    Write-Warning ("*" * $maxLength)
    Wrap-Text -Text $Message -MaxLength $maxLength | `
        Write-Warning
    Write-Warning ("*" * $maxLength)
}

function Wrap-Text
{
    param
    (
        [string] $Text,
        [int] $MaxLength
    )

    $lines = $Text -split "`n"

    foreach ($line in $lines)
    {
        if ($line -eq "")
        {
            Write-Output ""
            continue
        }

        while ($line.Length -ge $MaxLength)
        {
            Write-Output ($line.Substring(0, $MaxLength))
            $line = $line.Substring($MaxLength)
        }

        if ($line -ne "")
        {
            Write-Output $line
        }
    }
}