#requires -version 2.0

[CmdletBinding()]
param (
)

$scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent

& "$scriptRoot\Fix-PullMergeCommits.ps1"