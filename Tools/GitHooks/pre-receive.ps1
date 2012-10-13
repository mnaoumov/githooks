#requires -version 2.0

[CmdletBinding()]
param
(
    [string] $PrevCommit,
    [string] $NewCommit,
    [string] $RefName
)

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

$ErrorActionPreference = "Stop"

Trap [Exception] `
{
    Write-Error ($_ | Out-String)
    ExitWithFailure
}

Write-Warning $RefName

$commits = git log --pretty=%s%b "$PrevCommit..$NewCommit"
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
