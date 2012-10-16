#requires -version 2.0

[CmdletBinding()]
param
(
)

$ErrorActionPreference = "Stop";
Set-StrictMode -Version Latest
$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

Describe "pre-commit hook" `
{
    Setup -Dir "LocalRepository"
    Setup -Dir "RemoteRepository"

    In ("$TestDrive\RemoteRepository") `
    {
        git init --bare
    }

    In ("$TestDrive\LocalRepository") `
    {
        git init
    }

    It "Checks against merge pulls" `
    {
        #$true.should.be($false)
    }
}
