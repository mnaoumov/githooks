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
            $hasSpace = $true
            if ($lastSpaceIndex -eq -1)
            {
                $lastSpaceIndex = $MaxLength
                $hasSpace = $false
            }

            $currentLine = $line.Substring(0, $lastSpaceIndex)
            Write-Output $currentLine
            if ($line.Length -le $lastSpaceIndex)
            {
                $line = ""
            }
            elseif ($hasSpace)
            {
                $line = $line.Substring($lastSpaceIndex + 1)
            }
            else
            {
                $line = $line.Substring($lastSpaceIndex)
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

function Parse-MergeCommitMessage
{
    param
    (
        [string] $CommitMessage
    )

    $result = New-Object PSObject -Property `
    @{
        Parsed = $false;
        From = "N/A";
        Into = "N/A";
        SpecificCommit = $false
    }

    $patterns = `
    @(
        "^Merge branch '(?<from>\S*)'$",
        "^Merge remote branch '(?<from>\S*)'$",
        "^Merge remote-tracking branch '(?<from>\S*)'$",

        "^Merge (?<from>\S*) branch to (?<into>\S*)$",
        "^Merge (?<from>\S*) to (?<into>\S*)$",

        "^Merge branch '(?<from>\S*)' into (?<into>\S*)$",
        "^Merge remote branch '(?<from>\S*)' into (?<into>\S*)$",
        "^Merge remote-tracking branch '(?<from>\S*)' into (?<into>\S*)$",
        "^Merge branch (?<from>\S*) to (?<into>\S*)$",

        "^Merge branch '(?<from>\S*)' of (?<url>\S*)$",
        "^Merge branch '(?<from>\S*)' of (?<url>\S*) into (?<into>\S*)$",
        "^Merge branches '(?<into>\S*)' and '(?<from>\S*)'$",
        "^Merge branches '(?<into>\S*)' and '(?<from>\S*)' of (?<url>\S*)$"

        "(?<commit>^Merge commit '(?<from>\S*)'$)",
        "(?<commit>^Merge commit '(?<from>\S*)' into (?<into>\S*)$)"
    )

    foreach ($pattern in $patterns)
    {
        if ($CommitMessage -match $pattern)
        {
            $from = $Matches["from"]
            $into = $Matches["into"]
            $url = $Matches["url"]

            if (-not $into)
            {
                $into = "master"
            }

            if ($url)
            {
                $remote = Get-RemoteName $url
                $from = "$remote/$from"
            }

            $result.From = $from
            $result.Into = $into
            $result.Parsed = $true
            $result.SpecificCommit = [bool] $Matches["commit"]

            break
        }
    }

    $result
}

function Get-RemoteName
{
    param
    (
        [string] $url
    )

    $map = (Get-HooksConfiguration).Pushes.RemotesMap.Map | `
        Where-Object { $_.url -eq $url } | `
        Select-Object -First 1

    if ($map)
    {
        return $map.remoteName
    }
    else
    {
        return $url
    }
}

function Test-MergeAllowed
{
    param
    (
        [string] $From,
        [string] $Into
    )

    if ([Convert]::ToBoolean((Get-HooksConfiguration).Merges.allowAllMerges))
    {
        Write-Debug "Merges/@allowAllMerges is enabled in HooksConfiguration.xml"
        return $true
    }

    $From = $From -replace "origin/"
    $Into = $Into -replace "origin/"

    if (-not (Test-KnownBranch $Into))
    {
        return $true
    }

    if (-not (Test-KnownBranch $From))
    {
        return $false
    }
    
    $mergeConfiguration = Get-MergesConfiguration -From $From | `
        Where-Object { $_.into -eq $Into }

    $mergeConfiguration -ne $null
}

function Test-BranchMerged
{
    param
    (
        [string] $BranchName
    )

    $nextBranchName = Get-NextBranchName $BranchName
    if ($nextBranchName -eq $null)
    {
        return $true
    }

    Test-FastForward -From $BranchName -To $nextBranchName
}

function Get-NextBranchName
{
    param
    (
        [string] $BranchName
    )
    
    $nextBranchName = Get-MergesConfiguration -From $BranchName |
        Where-Object { [Convert]::ToBoolean($_.required) } | `
        Select-Object -First 1 -ExpandProperty into

    $nextBranchName
}

function Test-BuildStatus
{
    param
    (
        [string] $BranchName
    )

    $mockBuildStatus = (Get-HooksConfiguration).TeamCity.mockBuildStatus

    $buildTypeId = (Get-HooksConfiguration).Branches.Branch | `
        Where-Object { $_.name -eq $BranchName } | `
        Select-Object -ExpandProperty teamCityBuildTypeId

    if ($buildTypeId -eq $null)
    {
        return $null
    }

    if ($mockBuildStatus -ne "")
    {
        return [Convert]::ToBoolean($mockBuildStatus)
    }

    try
    {
        $configuration = Get-HooksConfiguration
        $client = New-Object System.Net.WebClient
        $client.Credentials = New-Object System.Net.NetworkCredential $configuration.TeamCity.userName, $configuration.TeamCity.password

        $url = "$($configuration.TeamCity.url)/httpAuth/app/rest/buildTypes/id:$buildTypeId/builds/canceled:false/status"

        $status = $client.DownloadString($url)

        if ($status -ne "SUCCESS")
        {
            return $false
        }
        else
        {
            $url = "$($configuration.TeamCity.url)/httpAuth/app/rest/buildTypes/id:$buildTypeId/builds/canceled:false,running:any/status"
            $status = $client.DownloadString($url)
            $status -eq "SUCCESS"
        }
    }
    catch
    {
        return $null
    }
}

function Has-UnrebaseableMerges
{
    param
    (
        [string] $From,
        [string] $Into
    )

    $From = Get-BranchName $From

    $merges = @(git rev-list --merges --no-walk "$From..$Into")

    foreach ($merge in $merges)
    {
        $mergeCommitMessage = git log -1 $merge --format=%s
        $result = Parse-MergeCommitMessage $mergeCommitMessage
        if (($result.From -ne $From) -or ($result.Into -ne $Into))
        {
            return $true;
        }
    }

    return $false
}

function Test-PullRebase
{
    param
    (
        [string] $NewBaseCommit,
        [string] $RebasingBranchName
    )

    $trackedBranchName = Get-TrackedBranchName $RebasingBranchName
    Test-RefEquals $NewBaseCommit $trackedBranchName
}

function Test-RunningFromConsole
{
    try
    {
        $height = [Console]::WindowHeight
        return ($height -ne $null)
    }
    catch
    {
        return $false
    }
}

function Get-MergeInfo
{
    param
    (
        [string] $Ref
    )

    Validate-Ref $Ref

    $refsString = git rev-list $Ref --no-walk --parents
    $refs = $refsString -split " "

    if ($refs.Length -eq 2)
    {
        return New-Object PSObject -Property `
        @{
            IsMerge = $false
        }
    }
    elseif ($refs.Length -gt 3)
    {
        throw "Octopus merges are not supported: $Ref"
    }
    else
    {
        $from = Get-OriginatingBranch $refs[2];
        $into = Get-OriginatingBranch $refs[1];
        $message = Get-CommitMessage $Ref
        $parseResult = Parse-MergeCommitMessage $message

        if (($from -eq $null) -or ($into -eq $null))
        {
            $from = $parseResult.From
            $into = $parseResult.Into
        }

        return New-Object PSObject -Property `
        @{
            IsMerge = $true;
            From = $from;
            Into = $into;
            MessageParseable = $parseResult.Parsed;
            SpecificCommit = $parseResult.SpecificCommit
        }
    }
}

function Validate-Ref
{
    param
    (
        [string] $Ref
    )

    if (-not (Resolve-RefSafe $Ref))
    {
        throw "Cannot resolve ref $Ref"
    }
}

function Get-OriginatingBranch
{
    param
    (
        [string] $Ref
    )

    Validate-Ref $Ref

    $Ref = Resolve-RefSafe $Ref

    $branches = @(git branch --all --contains $Ref) | `
        ForEach-Object { $_ -replace "\*? +" -replace "remotes/" }

    foreach ($branch in $branches)
    {
        if (-not (Test-KnownBranch ($branch -replace "origin/")))
        {
            continue
        }

        $refs = git rev-list "$Ref^..$branch" --first-parent
        if ($refs -contains $Ref)
        {
            return $branch
        }
        else
        {
            $excludePreviousBranchSelector = Get-ExcludePreviousBranchSelector $branch
            $refs = git rev-list "$Ref^..$branch" $excludePreviousBranchSelector
            if ($refs -contains $Ref)
            {
                return "origin/$branch"
            }
        }
    }
}

function Test-KnownBranch
{
    param
    (
        [string] $BranchName
    )

    $branchConfiguration = (Get-HooksConfiguration).Branches.Branch | `
        Where-Object { $_.name -eq $BranchName } | `
        Select-Object -First 1

    $branchConfiguration -ne $null
}

function Get-MergesConfiguration
{
    param
    (
        [string] $From
    )

    (Get-HooksConfiguration).Branches.Branch | `
        Where-Object { $_.name -eq $From } | `
        Select-Object -ExpandProperty Merge -ErrorAction SilentlyContinue
}

function Get-PushDate
{
    param
    (
        [string] $Ref
    )

    $pushDateString = @(git log -1 $Ref --notes=push-date --format=%N)[0]

    if ($pushDateString -eq "")
    {
        return $null;
    }

    return [DateTime] $pushDateString
}

function Fetch-PushDateNotes
{
    git fetch origin refs/notes/push-date:refs/notes/push-date --quiet
}

function Get-ExcludePreviousBranchSelector
{
    param
    (
        [string] $BranchName,
        [switch] $Remote
    )

    $previousBranchName = Get-PreviousBranchName $BranchName

    if ($previousBranchName -eq $null)
    {
        return ""
    }
    elseif ($Remote)
    {
        return "^origin/$previousBranchName"
    }
    else
    {
        return "^$previousBranchName"
    }
}

}