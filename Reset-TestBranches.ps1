#requires -version 2.0

[CmdletBinding()]
param (
)

$ErrorActionPreference = "Stop";

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

Write-Output "Preparing branch test_merge_pull"
git checkout master -B test_merge_pull --quiet | Out-Null

"Parent commit change" | Out-File ParentCommitChange.txt -Encoding Ascii
git add ParentCommitChange.txt
git commit -m "Parent commit change" --quiet

"Commit which will cause pull merge" | Out-File CommitWhichWilCausePullMerge.txt -Encoding Ascii
git add CommitWhichWilCausePullMerge.txt
git commit -m "Commit which will cause pull merge" --quiet

git push local test_merge_pull --set-upstream --quiet | Out-Null

git reset --hard HEAD~1 --quiet

"Another commit which will cause pull merge" | Out-File AnotherCommitWhichWilCausePullMerge.txt -Encoding Ascii
git add AnotherCommitWhichWilCausePullMerge.txt
git commit -m "Another commit which will cause pull merge" --quiet

git config branch.test_merge_pull.rebase false

Write-Output "Creating branch test_merge_pull_backup"
git checkout test_merge_pull -B test_merge_pull_backup --quiet | Out-Null

Write-Output "Checkout master branch"
git checkout master --quiet