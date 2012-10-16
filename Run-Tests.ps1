#requires -version 2.0

[CmdletBinding()]
param
(
)

$ErrorActionPreference = "Stop";
Set-StrictMode -Version Latest

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

Import-Module "$scriptFolder\packages\Pester\Pester.psm1"

Invoke-Pester Tests