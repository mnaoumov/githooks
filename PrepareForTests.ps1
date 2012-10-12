#requires -version 2.0

[CmdletBinding()]
param
(
)

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

function Main
{
    $ErrorActionPreference = "Stop";

    . "$scriptFolder\Tools\GitHooks\Common.ps1"

    Write-Output "Installing git hooks"
    & "$scriptFolder\Tools\GitHooks\Install-GitHooks.ps1"

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

    Prepare-Branch test_merge_pull -Actions `
        { git checkout master -B test_merge_pull --quiet | Out-Null },
        { Make-ParentCommit },
        { Commit-File -FileContent "Commit which will cause pull merge" -FileName CommitWhichWilCausePullMerge.txt },
        { git push local test_merge_pull --set-upstream --quiet | Out-Null },
        { git reset --hard HEAD~1 --quiet },
        { Commit-File -FileContent "Another commit which will cause pull merge" -FileName AnotherCommitWhichWilCausePullMerge.txt },
        { git config branch.test_merge_pull.rebase false }

    Prepare-Branch test_merge_pull_conflict -Actions `
        { git checkout master -B test_merge_pull_conflict --quiet | Out-Null },
        { Make-ParentCommit },
        { Make-MergeConflictCommit },
        { git push local test_merge_pull_conflict --set-upstream --quiet | Out-Null },
        { git reset --hard HEAD~1 --quiet },
        { Commit-File -FileContent "Another commit which will cause pull merge conflict" -FileName CommitWhichWilCausePullMergeConflict.txt },
        { git config branch.test_merge_pull_conflict.rebase false }

    Prepare-Branch non_TFS_branch -Actions `
        { git checkout master -B non_TFS_branch --quiet | Out-Null }

    Prepare-Branch future -Actions `
        { git checkout master -B future --quiet | Out-Null },
        { Commit-File -FileContent "Before releases" -FileName BeforeReleases.txt }

    Prepare-Branch release.1.0 -Actions `
        { git checkout future --quiet },
        { Commit-File -FileContent "Ready for release 1.0" -FileName ReadyForRelease10.txt },
        { git checkout future -B release.1.0 --quiet | Out-Null },
        { Commit-File -FileContent "Release 1.0 fix" -FileName Release10Fix.txt }

    Prepare-Branch release.2.0 -Actions `
        { git checkout future --quiet },
        { Commit-File -FileContent "Ready for release 2.0" -FileName ReadyForRelease20.txt },
        { git checkout future -B release.2.0 --quiet | Out-Null },
        { Commit-File -FileContent "Release 2.0 fix" -FileName Release20Fix.txt },
        { Make-MergeConflictCommit }

    Prepare-Branch future -Actions `
        { git checkout future --quiet },
        { Commit-File -FileContent "Feature release fix" -FileName FutureReleaseFix.txt },
        { Make-AnotherMergeConflictCommit }

    Prepare-Branch test_rebase -Actions `
        { git checkout master -B test_rebase --quiet | Out-Null },
        { Commit-File -FileContent "Some change" -FileName SomeChange.txt },
        { git push local test_rebase --set-upstream --quiet | Out-Null }

    Prepare-Branch test_rebase2 -Actions `
        { git checkout master -B test_rebase2 --quiet | Out-Null },
        { Commit-File -FileContent "Some other change" -FileName SomeOtherChange.txt }

    Write-Output "Checkout branch master"
    git checkout master --quiet
}

function Commit-File
{
    param
    (
        [string] $FileContent,
        [string] $FileName
    )

    $FileContent | Out-File $FileName -Encoding Ascii
    git add $FileName
    $prefix = if ((Get-CurrentBranchName) -like "TFS*") { "" } else { "ADH " }

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

function Make-AnotherMergeConflictCommit
{
    Commit-File -FileContent "Another commit which will cause pull merge conflict" -FileName CommitWhichWilCausePullMergeConflict.txt
}

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

    Write-Output "Creating backup for branch $BranchName"
    git checkout $BranchName -B "$($BranchName)_backup" --quiet | Out-Null
}

Main