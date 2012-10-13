#requires -version 2.0

[CmdletBinding()]
param
(
    [string] $PrevCommit,
    [string] $NewCommit,
    [string] $RefName
)

$ErrorActionPreference = "Stop"

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

. "$scriptFolder\Common.ps1"

Trap [Exception] `
{
    Write-Error ($_ | Out-String)
    ExitWithFailure
}

$missingCommit = "0000000000000000000000000000000000000000"

$commitsRange = if ($PrevCommit -eq $missingCommit) { $NewCommit } else { "$PrevCommit..$NewCommit" }

$commits = git log --pretty=%s%b $commitsRange
$commits = $commits[$commits.Length..0]

$commits | `
    ForEach-Object `
    {
        if ($_ -eq "Change 2")
        {
            Write-Warning "Change 2 is not allowed"
            ExitWithFailure
        }
    }
