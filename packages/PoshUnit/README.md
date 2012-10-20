# PoshUnit #

Yet another PowerShell Unit testing framework

It designed to write **NUnit**-like tests.

    $Assert::That(2 + 2, $Is::EqualTo(4))

See **Tests\NUnitSyntaxExample.ps1** for more examples



## To create test ##

Create file **&lt;Test Fixture Name&gt;.Tests.ps1** using the following snippet

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
	        Test "<Insetrt Test Name>" `
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


## To run tests ##

Import module first
    
	Import-Module .\PoshUnit.psm1

Then run tests using
    
    Invoke-PoshUnit

Parameters:

    -Path
	 Default value: "."
    
	-Filter
	Default value: "*.Tests.ps1"

    -Recurse
	Default value: $true

    -ShowOutput
	Default value: $false

    -ShowErrors
	Default value: $true

    -ShowStackTrace
	Default value: $false


## Known issues ##

* **-ShowOutput $false** does not hide messages written by *Write-Host*
* Source line shown for exception thrown by *Write-Error* is not correct
