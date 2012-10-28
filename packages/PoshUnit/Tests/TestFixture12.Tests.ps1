#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path

if ((Get-Module PoshUnit) -eq $null)
{
    Import-Module "$PSScriptRoot\..\PoshUnit.psm1"
}

Test-Fixture "Test Fixture 1" `
    -TestFixtureSetUp `
    {
        "TestFixtureSetUp"
    } `
    -TestFixtureTearDown `
    {
        "TestFixtureTearDown"
    } `
    -SetUp `
    {
        "SetUp"
    } `
    -TearDown `
    {
        "TearDown"
    } `
    -Tests `
    (
        Test "Test 1" `
        {
            "Test 1"
        }
    ),
    (
        Test "Test 2" `
        {
            "Test 2"
        }
    )

Test-Fixture "Test Fixture 2" `
    -TestFixtureSetUp `
    {
        "TestFixtureSetUp2"
    } `
    -TestFixtureTearDown `
    {
        "TestFixtureTearDown2"
    } `
    -SetUp `
    {
        "SetUp2"
    } `
    -TearDown `
    {
        "TearDown2"
    } `
    -Tests `
    (
        Test "Test 1" `
        {
            "Test 1 (2)"
        }
    ),
    (
        Test "Test 2" `
        {
            "Test 2 (2)"
        }
    )