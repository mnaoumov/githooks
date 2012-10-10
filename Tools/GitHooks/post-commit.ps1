#requires -version 2.0

[CmdletBinding()]
param (
)

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

& "$scriptFolder\Fix-PullMergeCommits.ps1"