#requires -version 2.0

[CmdletBinding()]
param
(
    [string] $OldRef,
    [string] $NewRef,
    [string] $RefName
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

. "$(PSScriptRoot)\Common.ps1"

if ($RefName -notlike "refs/heads/*")
{
    Write-Debug "$RefName is not a branch commit"
    ExitWithSuccess
}

$branchName = $RefName -replace "refs/heads/"

if (-not (Test-KnownBranch $branchName))
{
    Write-Debug "$branchName is not known branch."
    ExitWithSuccess
}

$nextBranch = Get-NextBranchName $branchName

if ($nextBranch -ne $null)
{
    $allowedMergeIntervalInHours = [Convert]::ToInt32((Get-HooksConfiguration).Pushes.allowedMergeIntervalInHours)
    Write-HooksWarning "You pushed branch '$branchName'. Please merge your changes into '$nextBranch' and push it as well during next $allowedMergeIntervalInHours hours.`nSee wiki-url/index.php?title=Git#Unmerged_changes"
}

$reflog = git log -1 -g --date=iso --format=%gD $branchName
if ($reflog -notmatch ".*@\{(?<date>.*)\}")
{
    Write-HooksWarning "Cannot parse reflog date: $reflog"
    ExitWithSuccess
}

$pushDate = $Matches.date

$commits = @(git rev-list "$OldRef..$NewRef" --first-parent)

foreach ($commit in $commits)
{
    git notes --ref=push-date add -m $pushDate $commit
}