#requires -version 2.0

[CmdletBinding()]
param
(
)

$scriptFolder = Split-Path $MyInvocation.MyCommand.Path -Parent

function Main
{
    $ErrorActionPreference = "Stop"

    Trap [Exception] `
    {
        Write-Error ($_ | Out-String)
        exit
    }

    Add-Type -AssemblyName PresentationFramework

    $hooksConfiguration = ([xml] (Get-Content "$scriptFolder\HooksConfiguration.xml")).HooksConfiguration

    . "$scriptFolder\GitHelpers.ps1"

    if (-not (Check-IsMergeCommit))
    {
        Write-Debug "`nCurrent commit is not a merge commit"
        exit
    }

    $currentBranchName = Get-CurrentBranchName
    $mergedBranchName = Get-MergedBranchName

    if (Check-IsPullMerge)
    {
        Fix-PullMerge
    }
    else
    {
        Fix-UnallowedMerge
    }
}

function Fix-PullMerge
{
    if (-not ([Convert]::ToBoolean($hooksConfiguration.Merges.fixPullMerges)))
    {
        Write-Debug "Merges/@fixPullMerges is disabled in HooksConfiguration.xml"
        return
    }

    Write-Host "`nCurrent merge '$currentBranchName' with '$mergedBranchName' is a pull merge"

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

    $yesButton.add_Click(
        {
            $form.Close()
            RevertAndRebase
        })

    $yesPermanentlyButton.add_Click(
        {
            $form.Close()

            Write-Host "`nExecuting 'git config branch.$currentBranchName.rebase true'"
            git config "branch.$currentBranchName.rebase" true | Write-Host

            RevertAndRebase
        })

    $noButton.add_Click(
        {
            $form.Close()
            Write-Warning "`nPlease avoid pushing merge pull commit `"$(Get-CurrentCommitMessage)`"."
        })

    $form.WindowStartupLocation = "CenterScreen"
    [void] $form.ShowDialog();
}

function RevertAndRebase
{
    Write-Host "`nReverting pull merge commit by 'git reset --hard HEAD^1'"
    git reset --hard HEAD^1 | Write-Host
    Write-Host "`nExecuting 'git git pull --rebase'"
    git pull --rebase | Write-Host
}

function Fix-UnallowedMerge
{
    if ([Convert]::ToBoolean($hooksConfiguration.Merges.allowAllMerges))
    {
        Write-Debug "Merges/@allowAllMerges is enabled in HooksConfiguration.xml"
        exit
    }

    $mergeAllowed = ($hooksConfiguration.Merges | `
        Where-Object { ($_.branch -eq $mergedBranchName) -and ($_.into -eq $currentBranchName) } | `
        Select-Object -First 1) -ne $null

    if ($mergeAllowed)
    {
        Write-Debug "Merge '$mergedBranchName' into '$currentBranchName' is allowed."
        exit
    }

    $xaml = [xml] @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Unallowed merge"
    Height="110"
    Width="450"
    ResizeMode="NoResize">
<Grid>
    <TextBlock HorizontalAlignment="Left"
               Margin="10,10,0,0"
               TextWrapping="Wrap"
               Text="Merge '$mergedBranchName' into '$currentBranchName' is unallowed. Do you want to revert it?"
               VerticalAlignment="Top" />
    <Button x:Name="yesButton"
            Content="Yes"
            HorizontalAlignment="Left"
            Margin="223,44,0,0"
            VerticalAlignment="Top"
            Width="100"
            IsDefault="True" />
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
    $noButton = $form.FindName("noButton")

    $yesButton.add_Click(
        {
            $form.Close()
            Write-Host "`nReverting merge commit by 'git reset --hard HEAD^1'"
            git reset --hard HEAD^1 | Write-Host
        })

    $noButton.add_Click(
        {
            $form.Close()
            Write-Warning "Merge '$mergedBranchName' into '$currentBranchName' is unallowed."
        })

    $form.WindowStartupLocation = "CenterScreen"
    [void] $form.ShowDialog();
}


Main