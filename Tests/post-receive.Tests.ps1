#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

if ((Get-Module PoshUnit) -eq $null)
{
    $poshUnitFolder = if (Test-Path "$(PSScriptRoot)\..\PoshUnit.Dev.txt") { ".." } else { "..\packages\PoshUnit" }
    $poshUnitModuleFile = Resolve-Path "$(PSScriptRoot)\$poshUnitFolder\PoshUnit.psm1"

    if (-not (Test-Path $poshUnitModuleFile))
    {
        throw "$poshUnitModuleFile not found"
    }

    Import-Module $poshUnitModuleFile
}

. "$(PSScriptRoot)\TestHelpers.ps1"
. "$(PSScriptRoot)\..\Tools\GitHooks\Common.ps1"

function Invoke-NativeWithFullRedirect
{
    param
    (
        [string] $Command,
        [string] $OutputVariable
    )

    $suffix = "$([char] 27)\[K"

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try
    {
        Invoke-Expression "$Command 2>&1" | `
            ForEach-Object `
            {
                if ($_ -is [System.Management.Automation.ErrorRecord])
                {
                    $message = $_.Exception.Message
                }
                else
                {
                    $message = $_
                }

                $message -replace $suffix
            } | `
            Tee-Object -Variable outputLines

        Set-Variable -Name $OutputVariable -Value ($outputLines | Out-String) -Scope 1
    }
    finally
    {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

Test-Fixture "post-receive hooks" `
    -SetUp `
    {
        $tempPath = Get-TempTestPath
        $localRepoPath = Prepare-LocalGitRepo $tempPath

        $remoteRepoPath = "$tempPath\RemoteGitRepo"
        New-Item -Path $remoteRepoPath -ItemType Directory
        Push-Location $remoteRepoPath
        git init --bare
        Pop-Location

        Push-Location $localRepoPath
        git remote add origin $remoteRepoPath
        git push origin master --set-upstream

        New-Item -Path "ReadyForRelease10.txt" -ItemType File
        git add "ReadyForRelease10.txt"
        git commit -m "Ready for release 1.0"
        git push origin master
        git checkout -b release.1.0
        New-Item -Path "FixForRelease10.txt" -ItemType File
        git add "FixForRelease10.txt"
        git commit -m "Fix for release 1.0"

        git checkout master
        New-Item -Path "FeatureForFutureReleases.txt" -ItemType File
        git add "FeatureForFutureReleases.txt"
        git commit -m "Fix for future releases"

        tools\GitHooks\Install-GitHooks.ps1 "post-receive" -ServerSide $true -RemoteRepoPath $remoteRepoPath
    } `
    -TearDown `
    {
        Pop-Location
        Remove-Item -Path $tempPath -Recurse -Force
    } `
    -Tests `
    (
        Test "When you push branch it will warn you to merge to the next branch" `
        {
            git checkout release.1.0
            Invoke-NativeWithFullRedirect "git push origin release.1.0 --set-upstream" -OutputVariable output

            $output = $output -replace "remote: WARNING: "
            $output = $output -replace "`n"

            $Assert::That($output, $Is::StringContaining("You pushed branch 'release.1.0'. Please merge it to the branch 'master' and push it as well ASAP"))
        }
    ),
    (
        Test "When you push branch which does not have next no warning is not show" `
        {
            Invoke-NativeWithFullRedirect "git push origin master" -OutputVariable output

            $Assert::That($output, $Is::Not.StringContaining("remote: WARNING"))
        }
    )