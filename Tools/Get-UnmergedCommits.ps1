#requires -version 2.0

[CmdletBinding()]
param
(
    [string] $From
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

. "$(PSScriptRoot)\GitHooks\Common.ps1"

if (-not $From)
{
    $From = Get-CurrentBranchName
}

if (-not (Test-KnownBranch $From))
{
    Write-Warning "'$From' is unknown branch"
    return
}

$nextBranch = Get-NextBranchName $From

if ($nextBranch -eq $null)
{
    Write-Warning "'$From' does not have branch to be merged in"
    return
}

"Calculating commits that needed to be merged from branch 'origin/$From' into 'origin/$nextBranch'"

git fetch --quiet
Fetch-PushDateNotes

$excludePreviousBranchSelector = Get-ExcludePreviousBranchSelector $From -Remote

$commits = @(git rev-list "origin/$nextBranch..origin/$From" $excludePreviousBranchSelector) | `
    Sort-ByPushDate

$commits = @($commits)

$lastCommit = $null
$lastAuthor = $null

for ($i = 0; $i -lt $commits.Length; $i++)
{
    $commit = $commits[$i]

    $author = git log -1 $commit --format=%aN

    if (($i -gt 0) -and (($author -ne $lastAuthor) -or ($i -eq $commits.Length - 1) -or (-not(Test-FastForward -From $lastCommit -To $commit))))
    {
        New-Object PSObject -Property `
        @{
            Author = $lastAuthor;
            Commit = $lastCommit;
            PushDate = Get-PushDate $lastCommit
        }
    }

    $lastAuthor = $author
    $lastCommit = $commit
}
