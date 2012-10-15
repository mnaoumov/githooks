#requires -version 2.0

[CmdletBinding()]
param
(
)

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

function Main
{
    $ErrorActionPreference = "Stop";

    $gitHooksFolder = "$scriptFolder\Tools\GitHooks"

    . "$gitHooksFolder\Common.ps1"

    Write-Host "Installing git hooks"
    & "$gitHooksFolder\Install-GitHooks.ps1"

    New-GitRepo -Path "C:\Temp\LocalGitRepo" -RemoteName local
    New-GitRepo -Path "C:\Temp\LocalGitRepo2" -RemoteName local2

    Prepare-Branch test_merge_pull -Actions `
        { git checkout master -B test_merge_pull --quiet },
        { Make-ParentCommit },
        { Commit-File -FileContent "Commit which will cause pull merge" -FileName CommitWhichWilCausePullMerge.txt },
        { git push local test_merge_pull --set-upstream --quiet },
        { git reset --hard HEAD~1 --quiet },
        { Commit-File -FileContent "Another commit which will cause pull merge" -FileName AnotherCommitWhichWilCausePullMerge.txt },
        { git config branch.test_merge_pull.rebase false }

    Prepare-Branch test_merge_pull_conflict -Actions `
        { git checkout master -B test_merge_pull_conflict --quiet },
        { Make-ParentCommit },
        { Make-MergeConflictCommit },
        { git push local test_merge_pull_conflict --set-upstream --quiet },
        { git reset --hard HEAD~1 --quiet },
        { Commit-File -FileContent "Another commit which will cause pull merge conflict" -FileName CommitWhichWilCausePullMergeConflict.txt },
        { git config branch.test_merge_pull_conflict.rebase false }

    Prepare-Branch non_TFS_branch -Actions `
        { git checkout master -B non_TFS_branch --quiet }

    Prepare-Branch future -Actions `
        { git checkout master -B future --quiet },
        { Commit-File -FileContent "Before releases" -FileName BeforeReleases.txt }

    Prepare-Branch release.1.0 -Actions `
        { git checkout future --quiet },
        { Commit-File -FileContent "Ready for release 1.0" -FileName ReadyForRelease10.txt },
        { git checkout future -B release.1.0 --quiet },
        { Commit-File -FileContent "Release 1.0 fix" -FileName Release10Fix.txt }

    Prepare-Branch release.2.0 -Actions `
        { git checkout future --quiet },
        { Commit-File -FileContent "Ready for release 2.0" -FileName ReadyForRelease20.txt },
        { git checkout future -B release.2.0 --quiet },
        { Commit-File -FileContent "Release 2.0 fix" -FileName Release20Fix.txt },
        { Make-MergeConflictCommit }

    Prepare-Branch future -Actions `
        { git checkout future --quiet },
        { Commit-File -FileContent "Feature release fix" -FileName FutureReleaseFix.txt },
        { Make-AnotherMergeConflictCommit }

    Prepare-Branch test_rebase -Actions `
        { git checkout master -B test_rebase --quiet },
        { Commit-File -FileContent "Some change" -FileName SomeChange.txt },
        { git push local test_rebase --set-upstream --quiet }

    Prepare-Branch test_rebase2 -Actions `
        { git checkout master -B test_rebase2 --quiet },
        { Commit-File -FileContent "Some other change" -FileName SomeOtherChange.txt }

    Prepare-Branch test_push -Actions `
        { git checkout master -B test_push --quiet },
        { Commit-File -FileContent "Some change" -FileName SomeChange.txt },
        { git push local2 test_push --set-upstream --quiet },
        { Commit-File -FileContent "Change before merge" -FileName ChangeBeforeMerge.txt },
        { git checkout master -B test_push2 --quiet },
        { Commit-File -FileContent "Some other change" -FileName SomeOtherChange.txt },
        { git merge test_push },
        { Commit-File -FileContent "Change after merge" -FileName ChangeAfterMerge.txt },
        { git checkout test_push --quiet },
        { git reset --hard test_push2 }

    Write-Host "Checkout branch master"
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

    Write-Host "Preparing branch $BranchName"

    for ($i = 0; $i -lt $Actions.Length; $i++)
    {
        Write-Progress "Preparing branch $BranchName" -PercentComplete ($i / $Actions.Length * 100)
        & $Actions[$i] | Out-Null
    }

    Write-Progress "Preparing branch $BranchName" -Completed

    Write-Host "Creating backup for branch $BranchName"
    git checkout $BranchName -B "$($BranchName)_backup" --quiet | Out-Null
}

function New-GitRepo
{
    param
    (
        [string] $Path,
        [string] $RemoteName
    )

    if (Test-Path $Path)
    {
        Write-Host "Removing existing local git repository '$Path'"
        Remove-Item $Path -Recurse -Force
    }

    Write-Host "Creating local git repository '$Path'"
    New-Item $Path -ItemType Directory | Out-Null
    git init --bare --quiet $Path

    $remotes = git remote

    if ($remotes -contains $RemoteName)
    {
        Write-Host "Removing existing git remote '$RemoteName'"
        git remote rm $RemoteName
    }

    Write-Host "Creating git remote '$RemoteName' within '$Path'"
    git remote add $RemoteName $Path

    Write-Host "Copying server hooks into remote '$RemoteName'"
    Get-ChildItem -Path $gitHooksFolder -Include ("pre-receive*", "Common.ps1") -Recurse | `
        Copy-Item -Destination "$Path\hooks"
}

Main