#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Trap { throw $_ }

$packagesFolder = if (Test-Path "$PSScriptRoot\PoshUnit.Dev.txt") { "packages" } else { ".." }
$packagesFolder = Resolve-Path "$PSScriptRoot\$packagesFolder"

$nunitPackageFolder = Get-ChildItem $packagesFolder | `
    Where-Object { $_.Name -match "^NUnit[.\d]+$" } | `
    Select-Object -ExpandProperty FullName

if (-not $nunitPackageFolder)
{
    throw "NUnit package folder is not found in '$packagesFolder'"
}

$nunitAssemblyFile = "$nunitPackageFolder\lib\nunit.framework.dll"

if (-not (Test-Path $nunitAssemblyFile))
{
    throw "'$nunitAssemblyFile' is not found"
}

Import-Module $nunitAssemblyFile

Add-Type -Language CSharp -ReferencedAssemblies $nunitAssemblyFile `
@"
using System;
using System.Management.Automation;
using NUnit.Framework;

namespace PoshUnit
{
    public static class NUnitHelper
    {
        public static TestDelegate ToTestDelegate(ScriptBlock block)
        {
            return delegate
                { 
                    try
                    {
                        block.Invoke();
                    }
                    catch (RuntimeException e)
                    {
                        throw e.InnerException;
                    }
                };
        }
    }
}
"@

$Assert = [NUnit.Framework.Assert]
$Is = [NUnit.Framework.Is]
$Has = [NUnit.Framework.Has]
$Throws = [NUnit.Framework.Throws]

function Test-Delegate
{
    [OutputType({ [NUnit.Framework.TestDelegate] })]
    [CmdletBinding()]
    param
    (
        [ScriptBlock] $ScriptBlock
    )

    [PoshUnit.NUnitHelper]::ToTestDelegate($ScriptBlock)
}

Export-ModuleMember -Variable Assert, Is, Has, Throws
Export-ModuleMember Test-Delegate