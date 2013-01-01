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
            Write-HooksWarning "Allowing to push because of the reason '$($result.Reason)'"
            ExitWithSuccess
        }
        else
        {
            Write-HooksWarning "If you really need to push your changes and bypass all these checks use 'tools\ForcePush.ps1' utility"
            ExitWithFailure
        }
    }
}

function Test-PushAllowed
{
    if (-not (Test-BrokenBuild))
    {
        return $false
    }

    if (-not (Test-Merges))
    {
        return $false
    }

    return $true
}

function Test-Merges
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
                Write-HooksWarning "Cannot parse merge commit message`n$commitInfo`nPlease don't modify merge commit messages"
                return $false
            }
        }
        elseif (($result.From -eq "origin/$branchName") -and ($return.Into -eq $branchName))
        {
            if (-not ([Convert]::ToBoolean((Get-HooksConfiguration).Pushes.allowMergePulls)))
            {
                Write-HooksWarning "Pull merge commits are not allowed:`n$commitInfo"
                return $false
            }
        }
        elseif ($result.Into -eq $branchName)
        {
            if (-not(Test-MergeAllowed -From $result.From -Into $result.Into))
            {
                Write-HooksWarning "Merge from '$($result.From)' into '$($result.Into)' is not allowed:`n$commitInfo"
                return $false
            }
        }
        else
        {
            Write-HooksWarning "Your '$branchName' branch seems to be incorrectly reset to a wrong branch. The following commit should not exist in this branch:`n$commitInfo`nYou have to backup your '$branchName' branch, hard reset it to the 'origin/$branchName' and cherry-pick your changes"
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
    else if ($buildStatus -eq $null)
    {
        if (-not ([Convert]::ToBoolean((Get-HooksConfiguration).TeamCity.allowUnknownBuildStatus)))
        {
            Write-HooksWarning "Cannot get TeamCity build status for branch '$branchName'"
            return $false
        }
    }

    $commitMessages = @(git log $refQuery --format=%s)
    foreach ($commitMessage in $commitMessages)
    {
        if ($commitMessage -notlike "BUILDFIX*")
        {
            Write-HooksWarning "TeamCity build for branch '$branchName' is broken. You can only push commits that fix broken build. If it is the case, please prefix your commit messages with BUILDFIX to bypass this check.`nTo modify commit messages follow http://stackoverflow.com/questions/179123/how-do-i-edit-an-incorrect-commit-message-in-git"
            return $false
        }
    }

    return $true
}

function Test-BuildStatus
{
    param
    (
        [string] $BranchName
    )

    $mockBuildStatus = (Get-HooksConfiguration).TeamCity.mockBuildStatus

    if ($mockBuildStatus -ne "")
    {
        return [Convert]::ToBoolean($mockBuildStatus)
    }

    $client = New-Object System.Net.WebClient
    $client.Credentials = New-Object System.Net.NetworkCredential (Get-HooksConfiguration).TeamCity.userName, (Get-HooksConfiguration).TeamCity.password

    $restUrl = "$((Get-HooksConfiguration).TeamCity.url)/httpAuth/app/rest"

    [xml] $xml = $client.DownloadString("$restUrl/buildTypes")

    $buildId = $xml.buildTypes.buildType | `
        Where-Object { $_.projectName -eq $BranchName -and $_.name -eq (Get-HooksConfiguration).TeamCity.buildTypeName } | `
        Select-Object -ExpandProperty id

    if ($buildId -eq $null)
    {
        return $null
    }

    $status = $client.DownloadString("$restUrl/buildTypes/id:$buildId/builds/canceled:false/status")
    $status -ne "FAILURE"
}

Main
