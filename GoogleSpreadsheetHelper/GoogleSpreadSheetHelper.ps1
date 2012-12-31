#requires -version 2.0

[CmdletBinding()]
param
(
)

$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }

Import-Module "$(PSScriptRoot)\*.dll"

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
    $listEntry.Elements.Add((New-Object Google.GData.Spreadsheets.ListEntry.Custom -Property @{ LocalName = "timestamp", Value = [DateTime]::UtcNow.ToString() }))
    $listEntry.Elements.Add((New-Object Google.GData.Spreadsheets.ListEntry.Custom -Property @{ LocalName = "username", Value = $UserName }))
    $listEntry.Elements.Add((New-Object Google.GData.Spreadsheets.ListEntry.Custom -Property @{ LocalName = "reason", Value = $Reason }))
    $listEntry.Elements.Add((New-Object Google.GData.Spreadsheets.ListEntry.Custom -Property @{ LocalName = "enabled", Value = "Yes" }))

    $service.Insert($listFeed, listEntry)
}

function Disable-ForcePush
{
    param
    (
        [string] $UserName
    )

    InitHelpers $UserName

    $listFeed.Entries.Count -ne 0;

    $listFeed = _service.Query(_filteredQuery);
    $row = listFeed.Entries[0];

    foreach ($element in $row.Elements)
    {
        if (element.LocalName -eq "enabled")
        {
            element.Value = "No";
        }
    }

    $row.Update();
}

function Test-ForcePushAllowed
{
    param
    (
        [string] $UserName
    )

    InitHelpers $UserName

    $listFeed = $service.Query($filteredQuery);
    $listFeed.Entries.Count -ne 0;
}

function InitHelpers
{
    param
    (
        $UserName
    )

    $SpreadsheetUserName = "git.helper@gmail.com"
    $SpreadsheetPassword = "git.helper123"

    $spreadsheetQuery = New-Object Google.GData.Spreadsheets.SpreadsheetQuery -Property @{ Title = SpreadsheetTitle }
    $spreadsheetFeed = $service.Query($spreadsheetQuery)
    $spreadsheet = spreadsheetFeed.Entries[0];

    $wsFeed = spreadsheet.Worksheets;
    $worksheet = wsFeed.Entries[0];

    $listFeedLink = worksheet.Links.FindService([Google.GData.Spreadsheets.GDataSpreadsheetsNameTable]::ListRel, $null);

    $listQuery = New-Object Google.GData.Spreadsheets.ListQuery listFeedLink.HRef.ToString()
    $filteredQuery = New-Object Google.GData.Spreadsheets.ListQuery listFeedLink.HRef.ToString() -Property @{ SpreadsheetQuery = "enabled=Yes and username=`"$UserName`"" }
}