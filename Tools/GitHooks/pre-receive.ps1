#requires -version 2.0

[CmdletBinding()]
param
(
    [string] $OldRef,
    [string] $NewRef,
    [string] $RefName
)

$ErrorActionPreference = "Stop"

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

. "$scriptFolder\Common.ps1"

Trap [Exception] `
{
    ProcessErrors $_
}
    
$missingRef = "0000000000000000000000000000000000000000"

if ($RefName -notlike "refs/heads/*")
{
    Write-Debug "$RefName is not a branch commit"
    ExitWithSuccess
}

$branchName = $RefName -replace "refs/heads/"

if ($OldRef -eq $missingRef)
{
    Write-Debug "$branchName is a new branch"
    ExitWithSuccess
}

$mergeCommits = git log --merges --format=%H "$OldRef..$NewRef"
[Array]::Reverse($mergeCommits)

foreach ($mergeCommit in $mergeCommits)
{
    $firstParentCommit = git rev-parse $mergeCommit^1
    if (-not (Test-FastForward -From $OldRef -To $firstParentCommit))
    {
        $commitMessage = git log -1 $mergeCommit --format=oneline
        Write-Warning "The following commit should not exist in branch $branchName`n$commitMessage"
        ExitWithFailure
    }
}

ExitWithSuccess