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

Test-Fixture "Failing TestFixtureSetUp" `
    -TestFixtureSetUp `
    {
        throw "TestFixtureSetUp"
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

Test-Fixture "Failing TestFixtureTearDown" `
    -TestFixtureSetUp `
    {
        "TestFixtureSetUp"
    } `
    -TestFixtureTearDown `
    {
        throw "TestFixtureTearDown"
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

Test-Fixture "Failing SetUp" `
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
        throw "SetUp"
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

Test-Fixture "Failing TearDown" `
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
        throw "TearDown"
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

Test-Fixture "Failing Test" `
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
            throw "Test 1"
        }
    ),
    (
        Test "Test 2" `
        {
            "Test 2"
        }
    )