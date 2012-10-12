function Check-IsMergeCommit
{
    (git rev-parse --verify --quiet HEAD^2) -ne $null
}

function Get-CurrentBranchName
{
    git rev-parse --abbrev-ref HEAD
}

function Get-MergedBranchName
{
    (git name-rev --name-only HEAD^2) -replace "remotes/"
}

function Get-TrackedBranchName
{
    $currentBranchName = Get-CurrentBranchName
    $remote = git config branch.$currentBranchName.remote
    if (-not $remote)
    {
        $remote = "origin"
    }

    $remoteBranch = "$remote/$currentBranchName"

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

function Check-IsPullMerge
{
    (Get-MergedBranchName) -eq (Get-TrackedBranchName)
}

function Get-CurrentCommitMessage
{
    git log -1 --pretty=%B
}