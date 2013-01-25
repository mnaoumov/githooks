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

    if (-not (Test-KnownBranch $branchName))
    {
        Write-Debug "$branchName is not known branch."
        ExitWithSuccess
    }

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

        $mergeInfo = Get-MergeInfo $merge

        $commitInfo = git log -1 $merge --format=oneline

        if (-not $mergeInfo.MessageParseable)
        {
            if (-not ([Convert]::ToBoolean((Get-HooksConfiguration).Pushes.allowUnparsableMergeCommitMessages)))
            {
                Write-HooksWarning "Cannot parse merge commit message`n$commitInfo`nSee wiki-url/index.php?title=Git#Parse_merge_commit_messages"
                return $false
            }
        }
        elseif ($mergeInfo.SpecificCommit)
        {
            $originatingBranch = Get-OriginatingBranch "$merge^2"
            if ($originatingBranch -eq $null)
            {
                $commitInfo = git log -1 "$merge^2" --format=oneline
                Write-HooksWarning "Cannot detect originating branch for commit:`n$commitInfo`nPlease make sure that corresponding branch is pushed`nSee wiki-url/index.php?title=Git#Originating_branches"
                return $false
            }
        }
        elseif (($mergeInfo.From -eq "origin/$branchName") -and ($mergeInfo.Into -eq $branchName))
        {
            if (-not ([Convert]::ToBoolean((Get-HooksConfiguration).Pushes.allowMergePulls)))
            {
                Write-HooksWarning "Pull merge commits are not allowed:`n$commitInfo`nSee wiki-url/index.php?title=Git#Pull_merges"
                return $false
            }
        }
        elseif (($mergeInfo.Into -eq $branchName) -or ($mergeInfo.Into -eq "origin/$branchName"))
        {
            if (-not(Test-MergeAllowed -From $mergeInfo.From -Into $mergeInfo.Into))
            {
                Write-HooksWarning "Merge from '$($mergeInfo.From)' into '$($mergeInfo.Into)' is not allowed:`n$commitInfo`nSee wiki-url/index.php?title=Git#Merges"
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
        else
        {
            return $true
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
    $nextBranchName = Get-NextBranchName $BranchName

    if ($nextBranchName -eq $null)
    {
        Write-Debug "Next branch for '$BranchName' is not configured"
        return $true
    }

    $excludePreviousBranchSelector = Get-ExcludePreviousBranchSelector $BranchName

    $earliestUnmergedCommit = @(git rev-list "$nextBranchName..$BranchName" $excludePreviousBranchSelector) | `
        Sort-ByPushDate | `
        Select-Object -First 1

    if ($earliestUnmergedCommit -eq $null)
    {
        Write-Debug "No unpushed changes"
        return $true
    }

    $allowedMergeIntervalInHours = [Convert]::ToInt32((Get-HooksConfiguration).Pushes.allowedMergeIntervalInHours)

    $pushDate = Get-PushDate $earliestUnmergedCommit
    if ($pushDate -eq $null)
    {
        $elapsedHours = "N/A"
    }
    else
    {
        $elapsed = [DateTime]::Now - $pushDate
        $elapsedHours = [Math]::Round($elapsed.TotalHours, 1)

        if ($elapsedHours -le $allowedMergeIntervalInHours)
        {
            Write-Debug "Commits within configured interval"
            return $true
        }
    }

    $committerName = git log -1 $earliestUnmergedCommit --format=%an
    $commitInfo = git log -1 $earliestUnmergedCommit --format=oneline
    Write-HooksWarning "Cannot push to '$branchName' because it has unmerged commits made to branch '$nextBranchName' pushed $elapsedHours hours ago (only $allowedMergeIntervalInHours hours interval is allowed).`nWait for $committerName to merge the following commit into '$nextBranchName':`n$commitInfo`nSee wiki-url/index.php?title=Git#Unmerged_changes"
    return $false
}

Main