#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

$gitHooksFolder = Resolve-Path "$PSScriptRoot\..\..\.git\hooks"

if (-not (Test-Path $gitHooksFolder))
{
    throw "Failed to locate .git\hooks directory"
}

Copy-Item -Path "$PSScriptRoot\*" -Filter "*." -Destination $gitHooksFolder

"Git hooks installed"