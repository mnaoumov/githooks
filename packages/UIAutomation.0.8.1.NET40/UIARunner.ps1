Set-StrictMode -Version Latest

# So-called profiles, i.e. sets of settings
[UIAutomation.Mode]::Profile = [UIAutomation.Modes]::Presentation;
# default: [UIAutomation.Modes]::Presentation;
# ------------------------------------------------------


# Highlighting of controls
[UIAutomation.Preferences]::Highlight = $true;
# default: $true
# ------------------------------------------------------
#[UIAutomation.Preferences]::HighlighterColor = [System.Drawing.Color]::Red;
# default: [System.Drawing.Color]::Red
# ------------------------------------------------------
#[UIAutomation.Preferences]::HighlighterBorder = 3;
# default: 3
# ------------------------------------------------------
[UIAutomation.Preferences]::HighlightParent = $true;
# default: $true
# ------------------------------------------------------
#[UIAutomation.Preferences]::HighlighterColorParent = [System.Drawing.Color]::HotPink;
# default: [System.Drawing.Color]::HotPink
# ------------------------------------------------------
#[UIAutomation.Preferences]::HighlighterBorderParent = 5;
# default: 5
# ------------------------------------------------------


# The timeout for Get-UIAWindow, Get-UIA[ControlType], Wait- cmdlets
# No more do/while cycles or sleeps
# Adjust your code with individual timeouts (per cmdlet) or 
# use one universal timeout.
# Remember, that with overly short timeout you risk not 
# to catch a window or a control
# Unnecessarily long timeout in turn swallow your time
# if a window or a control is gone. The cmdlet will wait all
# the time that you set to.
[UIAutomation.Preferences]::Timeout = 5000;
# default: 5000
# ------------------------------------------------------
# This is a time-saving way to go through a window
# If a window or a child window is gone or never appeared,
# the test suite start working with lesser timeout,
# i.e., if your test suite should do ten clicks to the window
# that is gone, you must spend 10*5=50 seconds.
# However, if the window is gone, ten clicks will take
# only 10*2=20 seconds.
#[UIAutomation.Preferences]::AfterFailTurboTimeout = 2000;
# default: 2000
# ------------------------------------------------------


# Types of search used when we are searching for a control            
# the classical UIAutomaiton's FindFirst query
#[UIAutomation.Preferences]::DisableExactSearch = $true;
# default: $true
# ------------------------------------------------------
# the FindWindowEx search. The search supports wildcards.
#[UIAutomation.Preferences]::DisableWildCardSearch = $false;
# default: $false
# ------------------------------------------------------
#[UIAutomation.Preferences]::DisableWin32Search = $false;
# default: $false
# ------------------------------------------------------


# There is also the possibility to take screenshots automatically
# if a cmdlet fails            
#[UIAutomation.Preferences]::ScreenShotFolder = 
# default: user's TEMP folder
# ------------------------------------------------------
#[UIAutomation.Preferences]::OnErrorScreenShot = $false;
# default: $false
# ------------------------------------------------------


# The transcript interval is used in the Start-UIARecorder cmdlet
# to set the frequency the cmdlet queries the cursor position
#[UIAutomation.Preferences]::TranscriptInterval = 200;
# default: 200
# ------------------------------------------------------
# By default, you are working in the Presentation mode
# This means that after catching a control successfully
# a Get-UIAWindow, Get-UIA[ControlType] and
# several other cmdlets sleep for the OnSuccessDelay time.
# It's useful in case you need to view what's going on.
[UIAutomation.Preferences]::OnSuccessDelay = 200;
# default: 500
# ------------------------------------------------------
# You can attach one or more scriptblock to a cmdlet individually.
# In addition, you may also set one or more scriptblock to
# run after every successful cmdlet
#[UIAutomation.Preferences]::OnSuccessAction = $null;
# default: $null
# example: [UIAutomation.Preferences]::OnSuccessAction = {Start-Process calc;},{"It works!" >> C:\1\works.txt;},{sleep -Seconds 2; Save-UIAScreenshot -Description "Two calcs";}
# ------------------------------------------------------
# The time a cmdlet holds the pipeline after an error caused
#[UIAutomation.Preferences]::OnErrorDelay = 500;
# default: 500
# ------------------------------------------------------
# The default error handler(s)
#[UIAutomation.Preferences]::OnErrorAction = $null;
# default: $null
# ------------------------------------------------------
# The Get- cmdlets query Automaiton tree until the timeout expires
# However, it's not a requirement to perform queries without a sleep
# This delay is a delay betwwen subsequent queries to the Automaiton tree
#[UIAutomation.Preferences]::OnSleepDelay = 500;
# default: 500
# ------------------------------------------------------
# There is also the possibility (rarely used possibility)
# to run scriptblock(s) between performing queries.
# This may be useful if you need, for example,
# re-run a process of your AUT
#[UIAutomation.Preferences]::OnSleepAction = $null;
# default: $null
# ------------------------------------------------------
# This delay is for watching what's happened afer
# a Win32 click was performed
#[UIAutomation.Preferences]::OnClickDelay = 0;
# default: 0
# ------------------------------------------------------


# The log file is being written to the UIAutomaiton.log file in user's TEMP folder
#[UIAutomation.Preferences]::Log = $true;
# default: $true
# ------------------------------------------------------
#[UIAutomation.Preferences]::LogPath = 
# default: user's TEMP folder
# ------------------------------------------------------


# The UIAutomaiton module stores error records in the collection
# [UIAutomation.CurrentData]::Error
# that is a subset of PowerShell's $Error collections
#[UIAutomation.Preferences]::MaximumErrorCount = 256;
# ------------------------------------------------------


# The events that were subscribed to are also stores
# in a collection
# Theoretically, you can learn which events are caught
# default: 
#[UIAutomation.Preferences]::MaximumEventCount = 256;
# ------------------------------------------------------


#            // CacheRequest
#[UIAutomation.Preferences]::FromCache = $false;
# default: $false
# ------------------------------------------------------
            
#            // Test Case Management
[UIAutomation.Preferences]::EveryCmdletAsTestResult = $true;
# default: $false
# ------------------------------------------------------

[TMX.TestData]::ResetData();

#$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue;
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue;