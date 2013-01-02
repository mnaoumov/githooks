#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

Get-ChildItem "$(PSScriptRoot)\*.dll" | Import-Module

$service = $null
$listQuery = $null
$filteredQuery = $null

function Enable-ForcePush
{
    param
    (
        [string] $UserName,
        [string] $Reason
    )

    InitHelpers $UserName

    $listFeed = $service.Query($listQuery)

    $listEntry = New-Object Google.GData.Spreadsheets.ListEntry
    [void] $listEntry.Elements.Add((New-Object Google.GData.Spreadsheets.ListEntry+Custom -Property @{ LocalName = "timestamp"; Value = [DateTime]::UtcNow.ToString() }))
    [void] $listEntry.Elements.Add((New-Object Google.GData.Spreadsheets.ListEntry+Custom -Property @{ LocalName = "username"; Value = $UserName }))
    [void] $listEntry.Elements.Add((New-Object Google.GData.Spreadsheets.ListEntry+Custom -Property @{ LocalName = "reason"; Value = $Reason }))
    [void] $listEntry.Elements.Add((New-Object Google.GData.Spreadsheets.ListEntry+Custom -Property @{ LocalName = "enabled"; Value = "Yes" }))

    $method = $service.GetType().GetMethods() | `
        Where-Object { ($_.Name -eq "Insert") -and ($_.GetParameters()[0].ParameterType -eq [Google.GData.Client.AtomFeed]) } | `
        Select -First 1

    $method = $method.MakeGenericMethod([Google.GData.Spreadsheets.ListEntry])

    [void] $method.Invoke($service, @([Google.GData.Client.AtomFeed] $listFeed, [Google.GData.Spreadsheets.ListEntry] $listEntry))
}

function Disable-ForcePush
{
    param
    (
        [string] $UserName
    )

    InitHelpers $UserName

    $listFeed = $service.Query($filteredQuery);
    $row = $listFeed.Entries[0];

    foreach ($element in $row.Elements)
    {
        if ($element.LocalName -eq "enabled")
        {
            $element.Value = "No";
        }
    }

     [void] $row.Update();
}

function Test-ForcePushAllowed
{
    param
    (
        [string] $UserName
    )

    InitHelpers $UserName

    $listFeed = $service.Query($filteredQuery);

    if ($listFeed.Entries.Count -eq 0)
    {
        New-Object PSObject -Property `
        @{
            IsAllowed = $false;
            Reason = ""
        }
    }
    else
    {
        $reason = ""
        $row = $listFeed.Entries[0];

        foreach ($element in $row.Elements)
        {
            if ($element.LocalName -eq "reason")
            {
                $reason = $element.Value
            }
        }

        New-Object PSObject -Property `
        @{
            IsAllowed = $true;
            Reason = $reason
        }
    }
}

function InitHelpers
{
    param
    (
        $UserName
    )

    $SpreadsheetUserName = "git.helper@gmail.com"
    $SpreadsheetPassword = "git.helper123"
    $SpreadsheetTitle = "Git Force Push"

    $script:service = New-Object Google.GData.Spreadsheets.SpreadsheetsService "MySpreadsheetIntegration-v1"
    $service.setUserCredentials($SpreadsheetUserName, $SpreadsheetPassword);

    $spreadsheetQuery = New-Object Google.GData.Spreadsheets.SpreadsheetQuery -Property @{ Title = $SpreadsheetTitle }
    $spreadsheetFeed = $service.Query($spreadsheetQuery)
    $spreadsheet = $spreadsheetFeed.Entries[0];

    $wsFeed = $spreadsheet.Worksheets;
    $worksheet = $wsFeed.Entries[0];

    $listFeedLink = $worksheet.Links.FindService([Google.GData.Spreadsheets.GDataSpreadsheetsNameTable]::ListRel, $null);

    $script:listQuery = New-Object Google.GData.Spreadsheets.ListQuery $listFeedLink.HRef.ToString()
    $script:filteredQuery = New-Object Google.GData.Spreadsheets.ListQuery $listFeedLink.HRef.ToString() -Property @{ SpreadsheetQuery = "enabled=Yes and username=`"$UserName`"" }
}