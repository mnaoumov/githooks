#requires -version 2.0

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string] $CommitMessagePath
)

$ErrorActionPreference = "Stop";

function ExitWithCode
{ 
    param
    (
        [int] $exitcode
    )

    $host.SetShouldExit($exitcode)
    exit
}

function Show-Dialog
{
    Write-Progress -Activity "Getting commit metadata" -Status "Initializing UI" -PercentComplete 0

    Add-Type -AssemblyName PresentationFramework

    $xaml = [xml] @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Provide TFS WorkItem ID" Height="140" Width="480">
    <Grid>
        <TextBlock HorizontalAlignment="Left" Margin="10,10,0,0" TextWrapping="Wrap"
                   Text="You should provide TFS WorkItem ID for your commit or mark it as an ad-hoc change" VerticalAlignment="Top" />
        <Label Content="TFS WorkItem ID" HorizontalAlignment="Left" Margin="10,30,0,0" VerticalAlignment="Top" />
        <TextBox x:Name="workItemIdTextBox" HorizontalAlignment="Left" Margin="110,35,0,0" Text=""
                 VerticalAlignment="Top" Width="120" />
        <CheckBox x:Name="adHocCheckBox" Content="Ad-hoc change" HorizontalAlignment="Left" Margin="250,35,0,0" VerticalAlignment="Top" />
        <Button x:Name="okButton" Content="OK" HorizontalAlignment="Left" Margin="285,65,0,0" VerticalAlignment="Top" Width="75" IsEnabled="False" IsDefault="True" />
        <Button x:Name="cancelButton" Content="Cancel" HorizontalAlignment="Left" Margin="375,65,0,0" VerticalAlignment="Top" Width="75" IsCancel="True" />
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $form = [Windows.Markup.XamlReader]::Load($reader)

    $okButton = $form.FindName("okButton")
    $cancelButton = $form.FindName("cancelButton")
    $adhocCheckBox = $form.FindName("adHocCheckBox")
    $workItemIdTextBox = $form.FindName("workItemIdTextBox")

    $result = @{}

    $okButton.add_Click({
        $form.Close()
        $result.AdHoc = $adhocCheckBox.IsChecked;
        $result.WorkItemId = $workItemIdTextBox.Text;
    })

    $cancelButton.add_Click({
        $form.Close()
        $result.Cancel = $true
    })

    $adhocCheckBox.add_Click({
        $workItemIdTextBox.IsEnabled = !$adhocCheckBox.IsChecked
        if ($workItemIdTextBox.Text -eq "")
        {
            $okButton.IsEnabled = $adhocCheckBox.IsChecked
        }
    })

    $workItemIdTextBox.add_PreviewTextInput({
        param($Sender, $e)

        [UInt32] $value = 0
        if (!([UInt32]::TryParse($e.Text, [ref] $value)))
        {
            $e.Handled = $true
        }
    })

    $workItemIdTextBox.add_TextChanged({
        $okButton.IsEnabled = $workItemIdTextBox.Text -ne ""
    })

    Write-Progress -Activity "Getting commit metadata" -Status "Prompting for metadata" -PercentComplete 0

    $form.WindowStartupLocation = "CenterScreen"
    [void] $form.ShowDialog();

    Write-Progress -Activity "Getting commit metadata" -Status "Prompting for metadata" -Completed

    $result
}


Trap [Exception] {
    Write-Error $_
    ExitWithCode 1
}

Write-Debug "Running commit hook"
$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent
$workingCopyRoot = Join-Path $scriptFolder "..\.."
Write-Debug "WorkingCopyRoot is $workingCopyRoot"

$mergeHeadFile = Join-Path $workingCopyRoot ".git\MERGE_HEAD"
$workItemPattern = "^TFS\d+"
$adhocPattern = "^ADH\s+"
$fixupSquashPattern = "(fixup)|(squash)[!]\s+"
$revertPattern = "This reverts commit [0-9a-fA-F]{40}"

$currentBranchName = git name-rev --name-only HEAD
$commitMessage = Get-Content $CommitMessagePath | Out-String

function Update-CommitMessage()
{
    $commitMessage | Out-File $CommitMessagePath -Encoding Ascii
}

#Allow commits that contain a work item ID in the message
if ($commitMessage -match $workItemPattern)
{
    Write-Debug "ID in message"
    ExitWithCode 0
}
#Also allow commits that contain a work item ID in the branch name
elseif ($currentBranchName -match $workItemPattern)
{
    Write-Debug "ID in branch"
    $WorkItem = $matches[0];

    #Include the work item ID in the commit message
    $commitMessage = "$WorkItem $commitMessage"
    Update-CommitMessage
    ExitWithCode 0
}

#Allow merge commits
if (Test-Path $mergeHeadFile)
{
    Write-Debug "Commit was a merge"
    ExitWithCode 0
}

#Allow fixup/squash commits
if ($commitMessage -match $fixupSquashPattern) {
    Write-Debug "Commit was a fixup/squash"
    ExitWithCode 0
}

#Allow revert commits
if ($commitMessage -match $revertPattern) {
    Write-Debug "Commit was a revert"
    ExitWithCode 0
}

#Allow Adhoc commits
if ($commitMessage -match $adhocPattern) {
    Write-Debug "Commit was an Adhoc"
    #Strip out the "ADH"
    $commitMessage = $commitMessage -replace $adhocPattern, ""
    Update-CommitMessage
    ExitWithCode 0
}

$result = Show-Dialog

if ($result.Cancel)
{
    Write-Warning "Commit message missing TFS WorkItem ID.`nIt should appear at the start of your commit message, like: TFS1234 Add more awesome"
    ExitWithCode 1
}
elseif ($result.AdHoc)
{
    Write-Debug "Commit was an ad-hoc"
    ExitWithCode 0
}
else
{
    Write-Debug "Adding TFS WorkItem ID $($result.WorkItemId)"
    $commitMessage = "TFS$($result.WorkItemId) $commitMessage"
    Update-CommitMessage
    ExitWithCode 0
}