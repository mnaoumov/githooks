#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

# -----------------------------------------------------------------------------------------------------------
# This block is not mandatory. It is needed only if you want your TestFixture script to be self-testable
#

$poshUnitFolder = if (Test-Path "$PSScriptRoot\..\PoshUnit.Dev.txt") { ".." } else { "..\packages\PoshUnit" }
$poshUnitModuleFile = Resolve-Path "$PSScriptRoot\$poshUnitFolder\PoshUnit.psm1"

if (-not (Test-Path $poshUnitModuleFile))
{
    throw "$poshUnitModuleFile not found"
}

Import-Module $poshUnitModuleFile

#
# -----------------------------------------------------------------------------------------------------------

Test-Fixture "<Insert Test Fixture Name>" `
    -TestFixtureSetUp `
    {
        # Executed once before tests
    } `
    -TestFixtureTearDown `
    {
        # Executed once after tests
    } `
    -SetUp `
    {
        # Executed before each test
    } `
    -TearDown `
    {
        # Executed after each test
    } `
    -Tests `
    (
        Test "<Insert Test Name>" `
        {
            # Write test
            # For example
            # $Assert::That(2 + 2, $Is::EqualTo(4))
        }
    ),
    (
        Test "<Insert Test Name 2>" `
        {
            # Write test
        }
    )