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
    -not (Test-RefEquals HEAD^2 $null)
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

    $remoteBranches = @((git branch -r) -replace "^  ")

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
    Test-RefEquals (Get-MergedBranchName) (Get-TrackedBranchName)
}

function Test-RefEquals
{
    param
    (
        [string] $FirstRef,
        [string] $SecondRef
    )

    (Resolve-RefSafe $FirstRef) -eq (Resolve-RefSafe $SecondRef)
}

function Resolve-RefSafe
{
    param
    (
        [string] $Ref
    )

    if (-not $Ref)
    {
        return $null
    }

    git rev-parse --verify --quiet $Ref
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

    if (-not (Resolve-RefSafe $Commit))
    {
        return $null
    }

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

    Test-RefEquals $mergeBase $From
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

        while ($line.Length -gt $MaxLength)
        {
            $trim = $line.Substring(0, $MaxLength + 1)
            $lastSpaceIndex = $trim.LastIndexOf(" ")
            $currentLine = $line.Substring(0, $lastSpaceIndex)
            Write-Output $currentLine
            if ($line.Length -le $lastSpaceIndex)
            {
                $line = ""
            }
            else
            {
                $line = $line.Substring($lastSpaceIndex + 1)
            }
        }

        if ($line -ne "")
        {
            Write-Output $line
        }
    }
}

function Test-CommitPushed
{
    $fetchHeadRef = Resolve-RefSafe FETCH_HEAD
    if (-not $fetchHeadRef)
    {
        return $false;
    }
    Test-FastForward -From HEAD -To $fetchHeadRef
}