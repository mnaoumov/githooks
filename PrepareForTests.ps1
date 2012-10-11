#requires -version 2.0

[CmdletBinding()]
param
(
)

$ErrorActionPreference = "Stop";

function Commit-File
{
    param
    (
        [string] $FileContent,
        [string] $FileName
    )

    $FileContent | Out-File $FileName -Encoding Ascii
    git add $FileName
    $currentBranchName = git rev-parse --abbrev-ref HEAD
    $prefix = if ($currentBranchName -like "TFS*") { "" } else { "ADH " }

    git commit -m ($prefix + $FileContent) --quiet
}

function Make-ParentCommit
{
    Commit-File -FileContent "Parent commit" -FileName "ParentCommit.txt"
}

function Make-MergeConflictCommit
{
    Commit-File -FileContent "Commit which will cause pull merge conflict" -FileName CommitWhichWilCausePullMergeConflict.txt
}

Write-Output "Installing git hooks"
Tools\GitHooks\Install-GitHooks.ps1

$localGitRepoPath = "C:\Temp\LocalGitRepo"

if (Test-Path $localGitRepoPath)
{
    Write-Output "Removing existing local git repository '$localGitRepoPath'"
    Remove-Item $localGitRepoPath -Recurse -Force
}

Write-Output "Creating local git repository '$localGitRepoPath'"
New-Item $localGitRepoPath -ItemType Directory | Out-Null
git init --bare --quiet $localGitRepoPath

$remotes = git remote

if ($remotes -contains "local")
{
    Write-Output "Removing existing git remote 'local'"
    git remote rm local
}

Write-Output "Creating git remote 'local' within '$localGitRepoPath'"
git remote add local $localGitRepoPath


function Prepare-Branch
{
    param
    (
        [string] $BranchName,
        [ScriptBlock[]] $Actions
    )

    Write-Output "Preparing branch $BranchName"

    for ($i = 0; $i -lt $Actions.Length; $i++)
    {
        Write-Progress "Preparing branch $BranchName" -PercentComplete ($i / $Actions.Length * 100)
        & $Actions[$i]
    }

    Write-Progress "Preparing branch $BranchName" -Completed
}

Prepare-Branch test_merge_pull -Actions `
    { git checkout master -B test_merge_pull --quiet | Out-Null },
    { Make-ParentCommit },
    { Commit-File -FileContent "Commit which will cause pull merge" -FileName CommitWhichWilCausePullMerge.txt },
    { git push local test_merge_pull --set-upstream --quiet | Out-Null },
    { git reset --hard HEAD~1 --quiet },
    { Commit-File -FileContent "Another commit which will cause pull merge" -FileName AnotherCommitWhichWilCausePullMerge.txt },
    { git config branch.test_merge_pull.rebase false }

Prepare-Branch test_merge_pull_backup -Actions `
    { git checkout test_merge_pull -B test_merge_pull_backup --quiet | Out-Null }

Prepare-Branch test_merge_pull_conflict -Actions `
    { git checkout master -B test_merge_pull_conflict --quiet | Out-Null },
    { Make-ParentCommit },
    { Make-MergeConflictCommit },
    { git push local test_merge_pull_conflict --set-upstream --quiet | Out-Null },
    { git reset --hard HEAD~1 --quiet },
    { Commit-File -FileContent "Another commit which will cause pull merge conflict" -FileName CommitWhichWilCausePullMergeConflict.txt },
    { git config branch.test_merge_pull_conflict.rebase false }

Prepare-Branch test_merge_pull_conflict_backup -Actions `
    { git checkout test_merge_pull_conflict -B test_merge_pull_conflict_backup --quiet | Out-Null }

Prepare-Branch TFS1234 -Actions `
    { git checkout master -B TFS1234 --quiet | Out-Null }

Prepare-Branch non_TFS_branch -Actions `
    { git checkout master -B non_TFS_branch --quiet | Out-Null },
    { Make-ParentCommit },
    { Make-MergeConflictCommit }

Write-Output "Checkout master branch"
git checkout master --quiet