#requires -version 2.0

[CmdletBinding()]
param
(
)

$ErrorActionPreference = "Stop"

Trap [Exception] `
{
    Write-Error $_
    exit 1
}

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

. "$scriptFolder\GitHelpers.ps1"

if (-not Check-IsMergeCommit)
{
    Write-Debug "`nCurrent commit is not a merge commit"
    exit
}

$currentBranchName = Get-CurrentBranchName
$mergedBranchName = Get-MergedBranchName
$isPullMerge = Check-IsPullMerge

if ($isPullMerge)
{
    . "$scriptFolder\Fix-PullMerge.ps1"
}
else
{
    Write-Debug "`nCurrent merge '$currentBranchName' with '$mergedBranchName' is not a pull merge"
    return
}