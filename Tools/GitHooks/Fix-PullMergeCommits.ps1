#requires -version 2.0

[CmdletBinding()]
param (
)

$ErrorActionPreference = "Stop";

Trap [Exception] {
    Write-Error $_
    exit 1
}

$isMergeCommit = (git rev-parse --verify --quiet HEAD^2) -ne $null

if (-not $isMergeCommit) {
    Write-Debug "`nCurrent commit is not a merge commit"
    exit
}

$currentBranchName = git name-rev --name-only HEAD
$mergedBranchName = git name-rev --name-only HEAD^2

$isPullMerge = $mergedBranchName -like "remotes/*"
$mergedBranchName = $mergedBranchName -replace 'remotes/'

if (-not $isPullMerge) {
    Write-Debug "`nCurrent merge '$currentBranchName' with '$mergedBranchName' is not a pull merge"
    return
}

Write-Host "`nCurrent merge '$currentBranchName' with '$mergedBranchName' is a pull merge"

Add-Type -AssemblyName PresentationFramework

$xaml = [xml] @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Merge pull warning"
        Height="110"
        Width="450"
        ResizeMode="NoResize">
    <Grid>
        <TextBlock HorizontalAlignment="Left"
                   Margin="10,10,0,0"
                   TextWrapping="Wrap"
                   Text="Usage of merge pulls is a bad practice. Do you want to use rebase pull instead?"
                   VerticalAlignment="Top" />
        <Button x:Name="yesButton"
                Content="Yes"
                HorizontalAlignment="Left"
                Margin="118,44,0,0"
                VerticalAlignment="Top"
                Width="100"
                IsDefault="True" />
        <Button x:Name="yesPermanentlyButton"
                Content="Yes, permanently"
                HorizontalAlignment="Left"
                Margin="223,44,0,0"
                VerticalAlignment="Top"
                Width="100" />
        <Button x:Name="noButton"
                Content="No"
                HorizontalAlignment="Left"
                Margin="328,44,0,0"
                VerticalAlignment="Top"
                Width="100"
                IsCancel="True" />
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$form = [Windows.Markup.XamlReader]::Load($reader)

$yesButton = $form.FindName("yesButton")
$yesPermanentlyButton = $form.FindName("yesPermanentlyButton")
$noButton = $form.FindName("noButton")

function RevertAndRebase() {
    Write-Host "`nReverting pull merge commit by 'git reset --hard HEAD^1'"
    git reset --hard HEAD^1 | Write-Host
    Write-Host "`nExecuting 'git git pull --rebase'"
    git pull --rebase | Write-Host
}

$yesButton.add_Click(
{    $form.Close()
    RevertAndRebase
})

$yesPermanentlyButton.add_Click({
    $form.Close()

    Write-Host "`nExecuting 'git config branch.$currentBranchName.rebase true'"
    git config "branch.$currentBranchName.rebase" true | Write-Host

    RevertAndRebase
})


$commitMessage = git log -1 --pretty=%B

$noButton.add_Click({
    $form.Close()
    Write-Warning "`nPlease avoid pushing merge pull commit `"$commitMessage`"."
})

$form.WindowStartupLocation = "CenterScreen"
[void] $form.ShowDialog();