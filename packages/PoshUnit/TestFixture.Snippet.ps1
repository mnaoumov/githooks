#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

Import-Module "$PSScriptRoot\relative\path\to\PoshUnit.psm1"

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