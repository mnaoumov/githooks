#requires -version 2.0

[CmdletBinding()]
param
(
    [string] $NewBaseCommit,
    [string] $RebasingBranchName
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

. "$(PSScriptRoot)\Common.ps1"

if (-not $RebasingBranchName)
{
    $RebasingBranchName = Get-CurrentBranchName
}

if (Has-UnrebaseableMerges -From $NewBaseCommit -Into $RebasingBranchName)
{
    if (-not (Test-RunningFromConsole))
    {
        Write-Debug "Git Extensions already showed it is own message"
        break
    }

    $isPullRebase = Test-PullRebase -NewBaseCommit $NewBaseCommit -RebasingBranchName $RebasingBranchName

    if ($isPullRebase)
    {
        $action = "Pull rebase"
    }
    else
    {
        $action = "Rebase"
    }

    Write-HooksWarning "$action is not recommended because it affects merge commits.`nSee wiki-url/index.php?title=Git#Rebase_merges"

    $result = $Host.UI.PromptForChoice("$action warning", "Do you want to continue rebase?", `
        [System.Management.Automation.Host.ChoiceDescription[]] @(
            (New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Yes")
            (New-Object System.Management.Automation.Host.ChoiceDescription "&No", "No")
        )
        , 1)

    switch ($result)
    {
        0 `
        {
            break
        }

        1 `
        {
            if ($isPullRebase)
            {
                Write-HooksWarning "You may want to use 'git pull --no-rebase' instead`nSee wiki wiki-url/index.php?title=Git#Rebase_merges"
            }

            ExitWithFailure
            break
        }
    }
}