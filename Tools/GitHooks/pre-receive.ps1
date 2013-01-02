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
. "$(PSScriptRoot)\GoogleSpreadsheetHelper\GoogleSpreadsheetHelper.ps1"

function Main
{
    if ($RefName -notlike "refs/heads/*")
    {
        Write-Debug "$RefName is not a branch commit."
        return $true
    }

    $branchName = $RefName -replace "refs/heads/"

    $missingRef = "0000000000000000000000000000000000000000"

    if ($NewRef -eq $missingRef)
    {
        Write-Debug "This push deletes branch $branchName"
        ExitWithSuccess
    }

    if ($OldRef -ne $missingRef)
    {
        $refQuery = @("$OldRef..$NewRef")
    }
    else
    {
        $refQuery = @(git for-each-ref --format="%(refname)" "refs/heads/*" | `
            ForEach-Object { "^$_" }) + $NewRef
    }

    $success = Test-PushAllowed

    if ($success)
    {
        ExitWithSuccess
    }
    else
    {
        if (-not ([Convert]::ToBoolean((Get-HooksConfiguration).Pushes.allowForcePushes)))
        {
            Write-Debug "Pushes/@allowForcePushes is disabled in HooksConfiguration.xml"
            ExitWithFailure
        }

        $commiterName = git log -1 $NewRef --format=%cN
        $result = Test-ForcePushAllowed -UserName $commiterName

        if ($result.IsAllowed)
        {
            Write-HooksWarning "ForcePush allowed because of the reason '$($result.Reason)'.`nSee wiki-url/index.php?title=Git#ForcePush"
            ExitWithSuccess
        }
        else
        {
            Write-HooksWarning "If you really need to push your changes`nSee wiki-url/index.php?title=Git#ForcePush"
            ExitWithFailure
        }
    }
}

function Test-PushAllowed
{
    return (Test-BrokenBuild) -and (Test-UnmergedBranch) -and (Test-IncorrectMerges)
}

function Test-IncorrectMerges
{
    $merges = @(git log $refQuery --merges --first-parent --format=%H --reverse)

    foreach ($merge in $merges)
    {
        $mergeCommitMessage = git log -1 $merge --format=%s

        $result = Parse-MergeCommitMessage $mergeCommitMessage

        $commitInfo = git log -1 $merge --format=oneline

        if (-not $result.Parsed)
        {
            if (-not ([Convert]::ToBoolean((Get-HooksConfiguration).Pushes.allowUnparsableMergeCommitMessages)))
            {
                Write-HooksWarning "Cannot parse merge commit message`n$commitInfo`nSee wiki-url/index.php?title=Git#Parse_merge_commit_messages"
                return $false
            }
        }
        elseif (($result.From -eq "origin/$branchName") -and ($result.Into -eq $branchName))
        {
            if (-not ([Convert]::ToBoolean((Get-HooksConfiguration).Pushes.allowMergePulls)))
            {
                Write-HooksWarning "Pull merge commits are not allowed:`n$commitInfo`nSee wiki-url/index.php?title=Git#Pull_merges"
                return $false
            }
        }
        elseif ($result.Into -eq $branchName)
        {
            if (-not(Test-MergeAllowed -From $result.From -Into $result.Into))
            {
                Write-HooksWarning "Merge from '$($result.From)' into '$($result.Into)' is not allowed:`n$commitInfo`nSee wiki-url/index.php?title=Git#Merges"
                return $false
            }
        }
        else
        {
            Write-HooksWarning "The following commit should not exist in this branch:`n$commitInfo`nSee wiki-url/index.php?title=Git#Incorrect_reset"
            return $false
        }
    }

    return $true
}

function Test-BrokenBuild
{
    $buildStatus = Test-BuildStatus $branchName

    if ($buildStatus -eq $true)
    {
        return $true
    }
    elseif ($buildStatus -eq $null)
    {
        if (-not ([Convert]::ToBoolean((Get-HooksConfiguration).TeamCity.allowUnknownBuildStatus)))
        {
            Write-HooksWarning "Cannot get TeamCity build status for branch '$branchName'.`nSee wiki-url/index.php?title=Git#TeamCity"
            return $false
        }
    }

    $commitMessages = @(git log $refQuery --no-merges --format=%s)
    foreach ($commitMessage in $commitMessages)
    {
        if ($commitMessage -notlike "BUILDFIX*")
        {
            Write-HooksWarning "TeamCity build for branch '$branchName' is broken.`nSee wiki-url/index.php?title=Git#Broken_build"
            return $false
        }
    }

    return $true
}

function Test-UnmergedBranch
{
    if (Test-BranchMerged $branchName)
    {
        return $true
    }

    $nextBranchName = Get-NextBranchName $branchName
    $committerName = git log -1 $OldRef --format=%an
    $commitInfo = git log -1 $OldRef --format=oneline
    $relativeCommitDate = git log -1 $OldRef --format=%ar
    Write-HooksWarning "Cannot push to '$branchName' because it has unmerged commits to branch '$nextBranchName'. Wait for $committerName to merge the following commit into '$nextBranchName':`n$commitInfo`nChanges to be merged were made $relativeCommitDate`nSee wiki-url/index.php?title=Git#Unmerged_changes"
    return $false
}

Main
