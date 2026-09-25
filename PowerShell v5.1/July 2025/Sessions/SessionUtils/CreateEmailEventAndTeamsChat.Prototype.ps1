# Sessions\SessionUtils\CreateEmailEventAndTeamsChat.Prototype.ps1
# WPF PowerShell 5.1 App for Creating Outlook Emails, Calendar Events, and Teams Chats
# Created: September 19, 2026
# claude code


[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

#region Helper Functions

function Test-OutlookInstalled {
    try {
        $outlook = New-Object -ComObject Outlook.Application -ErrorAction Stop
        $version = $outlook.Version
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
        return @{
            Installed = $true
            Version = $version
            ProductName = "Microsoft Outlook"
        }
    }
    catch {
        return @{
            Installed = $false
            Version = 'N/A'
            ProductName = "Microsoft Outlook"
        }
    }
}

function Get-OutlookVersionDetails {
    try {
        $outlook = New-Object -ComObject Outlook.Application -ErrorAction Stop
        $version = $outlook.Version
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null

        # Map version to release info
        $versionMap = @{
            '16.0' = @{ Name = 'Outlook 2016/2019/2021/365'; Released = '2015-2021' }
            '15.0' = @{ Name = 'Outlook 2013'; Released = 'January 2013' }
            '14.0' = @{ Name = 'Outlook 2010'; Released = 'June 2010' }
            '12.0' = @{ Name = 'Outlook 2007'; Released = 'January 2007' }
        }

        $majorVersion = ($version -split '\.')[0] + '.0'
        $releaseInfo = $versionMap[$majorVersion]

        if (-not $releaseInfo) {
            $releaseInfo = @{ Name = "Outlook (Version $version)"; Released = 'Unknown' }
        }

        # Try to get install date from registry
        $installDate = 'Unknown'
        try {
            $regPaths = @(
                'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
                'HKLM:\SOFTWARE\Microsoft\Office\16.0\Common\InstallRoot'
                'HKLM:\SOFTWARE\Microsoft\Office\15.0\Common\InstallRoot'
            )
            foreach ($regPath in $regPaths) {
                if (Test-Path $regPath) {
                    $installRoot = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                    if ($installRoot.PSObject.Properties.Name -contains 'InstallDate') {
                        $installDate = $installRoot.InstallDate
                        break
                    }
                }
            }
        }
        catch {
        }

        return @{
            Installed = $true
            Version = $version
            ProductName = $releaseInfo.Name
            Released = $releaseInfo.Released
            InstallDate = $installDate
        }
    }
    catch {
        return @{
            Installed = $false
            Version = 'N/A'
            ProductName = 'Microsoft Outlook'
            Released = 'N/A'
            InstallDate = 'N/A'
        }
    }
}

function Test-TeamsInstalled {
    try {
        # Check for Teams executable
        $teamsClassicPath = "$env:LOCALAPPDATA\Microsoft\Teams\current\Teams.exe"
        $teamsNewPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\ms-teams.exe"

        $teamsPath = $null
        $version = 'Unknown'
        $isNewTeams = $false

        if (Test-Path $teamsClassicPath) {
            $teamsPath = $teamsClassicPath
            $versionInfo = (Get-Item $teamsClassicPath).VersionInfo
            $version = $versionInfo.FileVersion
        }
        elseif (Test-Path $teamsNewPath) {
            $teamsPath = $teamsNewPath
            $version = 'Teams 2.0 (New Teams)'
            $isNewTeams = $true
        }

        if ($teamsPath) {
            $installDate = 'Unknown'
            try {
                $fileInfo = Get-Item $teamsPath
                $installDate = $fileInfo.CreationTime.ToString('yyyy-MM-dd')
            }
            catch {
            }

            return @{
                Installed = $true
                Path = $teamsPath
                Version = $version
                InstallDate = $installDate
                IsNewTeams = $isNewTeams
                ProductName = if ($isNewTeams) { 'Microsoft Teams 2.0' } else { 'Microsoft Teams (Classic)' }
            }
        }

        return @{
            Installed = $false
            Path = ''
            Version = 'N/A'
            InstallDate = 'N/A'
            IsNewTeams = $false
            ProductName = 'Microsoft Teams'
        }
    }
    catch {
        return @{
            Installed = $false
            Path = ''
            Version = 'N/A'
            InstallDate = 'N/A'
            IsNewTeams = $false
            ProductName = 'Microsoft Teams'
        }
    }
}

function Get-CurrentUserContext {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $userId = $identity.Name
    $samAccountName = $env:USERNAME
    $email = $null
    $displayName = $null

    # Try whoami /upn with timeout using background job
    try {
        $job = Start-Job -ScriptBlock { whoami /upn }
        $upnResult = Wait-Job $job -Timeout 2 | Receive-Job
        Remove-Job $job -Force -ErrorAction SilentlyContinue

        if ($upnResult -and $upnResult -match '@') {
            $email = $upnResult.Trim()
        }
    }
    catch {
    }

    # Try LDAP query with timeout using background job
    try {
        $ldapJob = Start-Job -ScriptBlock {
            param($sam)
            try {
                $root = [ADSI]"LDAP://RootDSE"
                $defaultNamingContext = $root.defaultNamingContext
                if ($defaultNamingContext) {
                    $searchRoot = [ADSI]("LDAP://{0}" -f $defaultNamingContext)
                    $searcher = New-Object System.DirectoryServices.DirectorySearcher($searchRoot)
                    $searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$sam))"
                    $searcher.ClientTimeout = [TimeSpan]::FromSeconds(2)
                    $searcher.ServerTimeLimit = [TimeSpan]::FromSeconds(2)
                    [void]$searcher.PropertiesToLoad.Add('displayName')
                    [void]$searcher.PropertiesToLoad.Add('mail')
                    [void]$searcher.PropertiesToLoad.Add('userPrincipalName')
                    $result = $searcher.FindOne()

                    if ($result) {
                        @{
                            DisplayName = if ($result.Properties['displayname'].Count -gt 0) { [string]$result.Properties['displayname'][0] } else { $null }
                            Mail = if ($result.Properties['mail'].Count -gt 0) { [string]$result.Properties['mail'][0] } else { $null }
                            UPN = if ($result.Properties['userprincipalname'].Count -gt 0) { [string]$result.Properties['userprincipalname'][0] } else { $null }
                        }
                    }
                }
            }
            catch { }
        } -ArgumentList $samAccountName

        $ldapResult = Wait-Job $ldapJob -Timeout 3 | Receive-Job
        Remove-Job $ldapJob -Force -ErrorAction SilentlyContinue

        if ($ldapResult) {
            if ($ldapResult.DisplayName) { $displayName = $ldapResult.DisplayName }
            if ($ldapResult.Mail -and -not $email) { $email = $ldapResult.Mail }
            if ($ldapResult.UPN -and -not $email) { $email = $ldapResult.UPN }
        }
    }
    catch {
    }

    if (-not $displayName) {
        $displayName = $samAccountName
    }

    if (-not $email) {
        if ($env:USERDNSDOMAIN) {
            $email = "{0}@{1}" -f $samAccountName, $env:USERDNSDOMAIN
        }
        else {
            $email = 'unknown@local'
        }
    }

    [pscustomobject]@{
        UserId = $userId
        SamAccountName = $samAccountName
        Email = $email
        DisplayName = $displayName
    }
}

function New-OutlookEmail {
    param(
        [string]$To,
        [string]$CC,
        [string]$BCC,
        [string]$Subject,
        [string]$Body
    )

    try {
        $outlook = New-Object -ComObject Outlook.Application
        $mail = $outlook.CreateItem(0) # olMailItem = 0

        if (-not [string]::IsNullOrWhiteSpace($To)) {
            $mail.To = $To.Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($CC)) {
            $mail.CC = $CC.Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($BCC)) {
            $mail.BCC = $BCC.Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($Subject)) {
            $mail.Subject = $Subject.Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($Body)) {
            $mail.Body = $Body.Trim()
        }

        $mail.Display($false) # Display modeless (non-blocking)

        # Clean up
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($mail) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        return @{ Success = $true; Message = 'Email created successfully' }
    }
    catch {
        return @{ Success = $false; Message = "Error creating email: $($_.Exception.Message)" }
    }
}

function New-OutlookCalendarEvent {
    param(
        [DateTime]$StartDateTime,
        [int]$DurationMinutes,
        [string]$Subject,
        [string]$Body,
        [string]$Location,
        [string]$RequiredAttendees,
        [string]$OptionalAttendees,
        [bool]$ReminderSet,
        [int]$ReminderMinutesBeforeStart
    )

    try {
        $outlook = New-Object -ComObject Outlook.Application
        $appointment = $outlook.CreateItem(1) # olAppointmentItem = 1

        $appointment.Start = $StartDateTime
        $appointment.Duration = $DurationMinutes

        if (-not [string]::IsNullOrWhiteSpace($Subject)) {
            $appointment.Subject = $Subject.Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($Body)) {
            $appointment.Body = $Body.Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($Location)) {
            $appointment.Location = $Location.Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($RequiredAttendees)) {
            $appointment.RequiredAttendees = $RequiredAttendees.Trim()
            $appointment.MeetingStatus = 1 # olMeeting = 1
        }
        if (-not [string]::IsNullOrWhiteSpace($OptionalAttendees)) {
            $appointment.OptionalAttendees = $OptionalAttendees.Trim()
            $appointment.MeetingStatus = 1
        }

        $appointment.ReminderSet = $ReminderSet
        if ($ReminderSet) {
            $appointment.ReminderMinutesBeforeStart = $ReminderMinutesBeforeStart
        }

        $appointment.Display($false) # Display modeless (non-blocking)

        # Clean up
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($appointment) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        return @{ Success = $true; Message = 'Calendar event created successfully' }
    }
    catch {
        return @{ Success = $false; Message = "Error creating event: $($_.Exception.Message)" }
    }
}

function Open-TeamsChat {
    param(
        [string]$UserEmail,
        [string]$Message,
        [string]$TeamsUrl
    )

    try {
        # Check if Teams URL provided first
        if (-not [string]::IsNullOrWhiteSpace($TeamsUrl)) {
            $TeamsUrl = $TeamsUrl.Trim()

            # Validate URL format
            if ($TeamsUrl -notmatch '^https://teams\.microsoft\.com/') {
                return @{
                    Success = $false
                    Message = 'Invalid Teams URL. Must start with https://teams.microsoft.com/'
                }
            }

            # Launch URL directly
            Start-Process $TeamsUrl
            return @{ Success = $true; Message = 'Teams URL opened successfully' }
        }

        # Email-based chat logic
        if ([string]::IsNullOrWhiteSpace($UserEmail)) {
            return @{ Success = $false; Message = 'Email address or Teams URL is required' }
        }

        # Build Teams deep link URL for email
        # Format: msteams:/l/chat/0/0?users=email@domain.com&message=text
        $encodedEmail = [System.Uri]::EscapeDataString($UserEmail.Trim())
        $teamsUrl = "msteams:/l/chat/0/0?users=$encodedEmail"

        if (-not [string]::IsNullOrWhiteSpace($Message)) {
            $encodedMessage = [System.Uri]::EscapeDataString($Message.Trim())
            $teamsUrl += "&message=$encodedMessage"
        }

        # Launch Teams using URL protocol
        Start-Process $teamsUrl

        return @{ Success = $true; Message = 'Teams chat opened successfully' }
    }
    catch {
        return @{ Success = $false; Message = "Error opening Teams: $($_.Exception.Message)" }
    }
}

function Get-SampleEmailAddress {
    return 'john.doe@irs.gov'
}

function Get-SampleEmailSubject {
    return 'Meeting Follow-up - Q3 Project Review'
}

function Get-SampleEmailBody {
    return @"
Hello,

Following up on our discussion during today's meeting. Please review the attached documents and provide your feedback by end of week.

Key action items:
1. Review project timeline
2. Submit resource requirements
3. Confirm availability for next meeting

Best regards,
Your Name
"@
}

# Initialize diagnostic log
$script:diagnosticLog = [System.Collections.ArrayList]::new()

function Add-DiagnosticLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')][string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logEntry = "[$timestamp] [$Level] $Message"
    [void]$script:diagnosticLog.Add($logEntry)

    # Keep log size manageable (max 500 entries)
    if ($script:diagnosticLog.Count -gt 500) {
        $script:diagnosticLog.RemoveAt(0)
    }
}

function Show-WindowsNotification {
    <#
    .SYNOPSIS
        Shows a Windows toast notification with advanced options.

    .DESCRIPTION
        Displays a modern Windows notification using the WinRT Toast API.
        Supports sounds, duration control, Tag/Group for replacement and grouping.

    .PARAMETER Title
        Notification title (first line, bold text)

    .PARAMETER Message
        Notification message (second line, regular text)

    .PARAMETER AppId
        Application identifier for grouping. Default: "CreateEmailEventAndTeamsChat"

    .PARAMETER Tag
        Unique tag for this notification (enables replacement/removal)

    .PARAMETER Group
        Group identifier for related notifications

    .PARAMETER ImagePath
        Path to image file for app logo override (circle icon)

    .PARAMETER Sound
        Sound to play: Default, Mail, Reminder, SMS, IM, Silent

    .PARAMETER Duration
        How long to display: Short (5s), Long (25s), Default (7s)
    #>

    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$AppId = "CreateEmailEventAndTeamsChat",
        [string]$Tag = $null,
        [string]$Group = $null,
        [ValidateScript({Test-Path $_ -PathType Leaf})][string]$ImagePath = $null,
        [ValidateSet('Default', 'Mail', 'Reminder', 'SMS', 'IM', 'Silent')][string]$Sound = 'Default',
        [ValidateSet('Short', 'Long', 'Default')][string]$Duration = 'Default'
    )

    Add-DiagnosticLog "Starting notification: Title='$Title', AppId='$AppId', Tag='$Tag', Group='$Group'" -Level Info

    try {
        # Load WinRT types
        Add-DiagnosticLog "Loading WinRT types..." -Level Info
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
        Add-DiagnosticLog "WinRT types loaded successfully" -Level Success

        # Escape XML special characters
        Add-DiagnosticLog "Escaping XML characters in Title and Message" -Level Info
        $TitleEscaped = [System.Security.SecurityElement]::Escape($Title)
        $MessageEscaped = [System.Security.SecurityElement]::Escape($Message)

        # Build toast duration attribute
        $toastDuration = if ($Duration -ne 'Default') { " duration=`"$($Duration.ToLower())`"" } else { "" }
        Add-DiagnosticLog "Duration set to: $Duration" -Level Info

        # Build image XML if provided
        $imageXml = ""
        if ($ImagePath) {
            Add-DiagnosticLog "Image path provided: $ImagePath" -Level Info
            $ImagePathEscaped = [System.Security.SecurityElement]::Escape($ImagePath)
            $imageXml = "<image placement=`"appLogoOverride`" hint-crop=`"circle`" src=`"$ImagePathEscaped`"/>"
        }

        # Build audio XML
        $soundSrc = switch ($Sound) {
            'Default' { "ms-winsoundevent:Notification.Default" }
            'Mail' { "ms-winsoundevent:Notification.Mail" }
            'Reminder' { "ms-winsoundevent:Notification.Reminder" }
            'SMS' { "ms-winsoundevent:Notification.SMS" }
            'IM' { "ms-winsoundevent:Notification.IM" }
            'Silent' { $null }
        }

        $audioXml = if ($Sound -eq 'Silent') {
            '<audio silent="true"/>'
        } elseif ($soundSrc) {
            "<audio src=`"$soundSrc`"/>"
        } else {
            ""
        }
        Add-DiagnosticLog "Sound set to: $Sound" -Level Info

        # Build XML template
        Add-DiagnosticLog "Building XML template..." -Level Info
        $template = @"
<toast$toastDuration>
    <visual>
        <binding template="ToastGeneric">
            <text>$TitleEscaped</text>
            <text>$MessageEscaped</text>
            $imageXml
        </binding>
    </visual>
    $audioXml
</toast>
"@
        Add-DiagnosticLog "XML template built. Length: $($template.Length) characters" -Level Info
        Add-DiagnosticLog "=== XML TEMPLATE START ===" -Level Info
        Add-DiagnosticLog $template -Level Info
        Add-DiagnosticLog "=== XML TEMPLATE END ===" -Level Info

        # Create and show notification
        Add-DiagnosticLog "Creating XML document..." -Level Info
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        Add-DiagnosticLog "XML document created successfully" -Level Success

        Add-DiagnosticLog "Creating ToastNotification object..." -Level Info
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml

        # Set Tag and Group for replacement/grouping
        if ($Tag) {
            $toast.Tag = $Tag
            Add-DiagnosticLog "Tag set to: $Tag" -Level Info
        }
        if ($Group) {
            $toast.Group = $Group
            Add-DiagnosticLog "Group set to: $Group" -Level Info
        }

        Add-DiagnosticLog "Calling ToastNotificationManager.Show()..." -Level Info
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
        Add-DiagnosticLog "Notification shown successfully! AppId: $AppId" -Level Success

        return @{ Success = $true; Message = "Notification shown successfully" }
    }
    catch {
        $errorMsg = "Error showing notification: $($_.Exception.Message)"
        Add-DiagnosticLog $errorMsg -Level Error
        Add-DiagnosticLog "Stack trace: $($_.Exception.StackTrace)" -Level Error
        return @{ Success = $false; Message = $errorMsg }
    }
}

function Remove-WindowsNotification {
    <#
    .SYNOPSIS
        Removes a specific notification from Action Center by Tag and Group.
    #>

    param(
        [Parameter(Mandatory = $true)][string]$Tag,
        [string]$Group = "",
        [string]$AppId = "CreateEmailEventAndTeamsChat"
    )

    Add-DiagnosticLog "Removing notification: Tag='$Tag', Group='$Group'" -Level Info

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $history = [Windows.UI.Notifications.ToastNotificationManager]::History
        $history.Remove($Tag, $Group, $AppId)
        Add-DiagnosticLog "Notification removed successfully" -Level Success
        return @{ Success = $true; Message = "Notification removed" }
    }
    catch {
        $errorMsg = "Error removing notification: $($_.Exception.Message)"
        Add-DiagnosticLog $errorMsg -Level Error
        return @{ Success = $false; Message = $errorMsg }
    }
}

function Clear-AllWindowsNotifications {
    <#
    .SYNOPSIS
        Clears all notifications for this application from Action Center.
    #>

    param([string]$AppId = "CreateEmailEventAndTeamsChat")

    Add-DiagnosticLog "Clearing all notifications for AppId: $AppId" -Level Info

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $history = [Windows.UI.Notifications.ToastNotificationManager]::History
        $history.Clear($AppId)
        Add-DiagnosticLog "All notifications cleared successfully" -Level Success
        return @{ Success = $true; Message = "All notifications cleared" }
    }
    catch {
        $errorMsg = "Error clearing notifications: $($_.Exception.Message)"
        Add-DiagnosticLog $errorMsg -Level Error
        return @{ Success = $false; Message = $errorMsg }
    }
}

function Get-WindowsNotificationHistory {
    <#
    .SYNOPSIS
        Retrieves notification history from Action Center for this application.
    #>

    param([string]$AppId = "CreateEmailEventAndTeamsChat")

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $history = [Windows.UI.Notifications.ToastNotificationManager]::History
        $notifications = $history.GetHistory($AppId)

        $results = @()
        foreach ($notification in $notifications) {
            $results += [PSCustomObject]@{
                Tag = $notification.Tag
                Group = $notification.Group
                ExpirationTime = $notification.ExpirationTime
                Content = $notification.Content.GetXml()
            }
        }
        return @{ Success = $true; Notifications = $results }
    }
    catch {
        return @{ Success = $false; Message = "Error retrieving history: $($_.Exception.Message)" }
    }
}

function Show-DiagnosticLogWindow {
    <#
    .SYNOPSIS
        Shows a diagnostic log window with Copy, Clear, Close buttons and zoom controls.
    #>

    $logXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Diagnostic Log" Height="600" Width="900"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResize">
    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header with controls -->
        <Border Grid.Row="0" Background="#ECF0F1" BorderBrush="#BDC3C7"
               BorderThickness="1" CornerRadius="6" Padding="12" Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Orientation="Horizontal">
                    <Button Name="BtnCopyLog" Content="Copy" Width="80" Height="32"
                           Margin="0,0,8,0"
                           ToolTip="Copy log contents to clipboard"/>
                    <Button Name="BtnClearLog" Content="Clear" Width="80" Height="32"
                           Margin="0,0,8,0"
                           ToolTip="Clear all log entries"/>
                </StackPanel>

                <StackPanel Grid.Column="2" Orientation="Horizontal">
                    <Button Name="BtnZoomOut" Content="-" Width="32" Height="32"
                           FontSize="18" FontWeight="Bold"
                           Margin="0,0,4,0"
                           ToolTip="Decrease font size"/>
                    <TextBlock Name="TxtFontSize" Text="12" FontSize="14" FontWeight="SemiBold"
                              VerticalAlignment="Center" Margin="8,0"
                              ToolTip="Current font size"/>
                    <Button Name="BtnZoomIn" Content="+" Width="32" Height="32"
                           FontSize="18" FontWeight="Bold"
                           Margin="4,0,0,0"
                           ToolTip="Increase font size"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Log content -->
        <Border Grid.Row="1" Background="White" BorderBrush="#BDC3C7"
               BorderThickness="1" CornerRadius="6" Padding="8">
            <TextBox Name="TxtLogContent" IsReadOnly="True"
                    TextWrapping="Wrap"
                    VerticalScrollBarVisibility="Auto"
                    HorizontalScrollBarVisibility="Auto"
                    FontFamily="Consolas"
                    FontSize="12"
                    Background="White"
                    ToolTip="Diagnostic log entries showing notification operations"/>
        </Border>

        <!-- Footer with Close button -->
        <Button Grid.Row="2" Name="BtnClose" Content="Close" Width="100" Height="36"
               Margin="0,12,0,0"
               Background="#3498DB" Foreground="White"
               BorderBrush="#2980B9" BorderThickness="2"
               HorizontalAlignment="Right"
               ToolTip="Close the diagnostic log window"/>
    </Grid>
</Window>
"@

    try {
        $logWindow = [Windows.Markup.XamlReader]::Parse($logXaml)

        # Get controls
        $txtLogContent = $logWindow.FindName('TxtLogContent')
        $btnCopyLog = $logWindow.FindName('BtnCopyLog')
        $btnClearLog = $logWindow.FindName('BtnClearLog')
        $btnZoomIn = $logWindow.FindName('BtnZoomIn')
        $btnZoomOut = $logWindow.FindName('BtnZoomOut')
        $txtFontSize = $logWindow.FindName('TxtFontSize')
        $btnClose = $logWindow.FindName('BtnClose')

        # Initialize log content
        $txtLogContent.Text = ($script:diagnosticLog -join "`r`n")
        if ($script:diagnosticLog.Count -eq 0) {
            $txtLogContent.Text = "No log entries yet. Try showing a notification to see diagnostic information here."
        }

        # Scroll to bottom
        $txtLogContent.ScrollToEnd()

        # Store font size in TextBox Tag property
        $txtLogContent.Tag = 12

        # Copy button
        $btnCopyLog.Add_Click({
            try {
                [System.Windows.Clipboard]::SetText($txtLogContent.Text)
                [System.Windows.MessageBox]::Show(
                    "Log contents copied to clipboard!",
                    "Success",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                ) | Out-Null
            }
            catch {
                [System.Windows.MessageBox]::Show(
                    "Failed to copy to clipboard: $($_.Exception.Message)",
                    "Error",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                ) | Out-Null
            }
        })

        # Clear button
        $btnClearLog.Add_Click({
            $result = [System.Windows.MessageBox]::Show(
                "Are you sure you want to clear all log entries?",
                "Confirm Clear",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )

            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                $script:diagnosticLog.Clear()
                $txtLogContent.Text = "Log cleared. New entries will appear here."
                Add-DiagnosticLog "Log cleared by user" -Level Info
            }
        })

        # Zoom In button
        $btnZoomIn.Add_Click({
            $currentSize = [int]$txtLogContent.Tag
            if ($currentSize -lt 32) {
                $currentSize += 2
                $txtLogContent.FontSize = $currentSize
                $txtLogContent.Tag = $currentSize
                $txtFontSize.Text = $currentSize.ToString()
            }
        })

        # Zoom Out button
        $btnZoomOut.Add_Click({
            $currentSize = [int]$txtLogContent.Tag
            if ($currentSize -gt 8) {
                $currentSize -= 2
                $txtLogContent.FontSize = $currentSize
                $txtLogContent.Tag = $currentSize
                $txtFontSize.Text = $currentSize.ToString()
            }
        })

        # Close button
        $btnClose.Add_Click({
            $logWindow.Close()
        })

        # Show window
        $logWindow.ShowDialog() | Out-Null
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Failed to show log window: $($_.Exception.Message)",
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}

function Get-SampleNotificationTitle {
    $samples = @(
        "Email Sent Successfully",
        "Calendar Event Created",
        "Meeting Reminder",
        "Task Completed",
        "Document Saved",
        "Upload Complete",
        "New Message Received",
        "System Backup Finished"
    )
    return $samples | Get-Random
}

function Get-SampleNotificationMessage {
    $samples = @(
        "Your email to john.doe@irs.gov has been sent.",
        "Team standup meeting scheduled for 10:00 AM tomorrow.",
        "Daily standup starts in 5 minutes.",
        "Report.docx has been saved to OneDrive.",
        "File upload completed successfully.",
        "New message from Alice: 'Can we meet today?'",
        "Backup completed: 1,234 files backed up.",
        "Task 'Review budget' marked as complete."
    )
    return $samples | Get-Random
}

function Get-SampleEventSubject {
    return 'Q4 Planning Meeting'
}

function Get-SampleEventBody {
    return @"
Agenda:
- Review Q3 accomplishments
- Discuss Q4 goals and objectives
- Resource allocation planning
- Timeline and milestones

Please come prepared with your team's priorities.
"@
}

function Initialize-StatusBarTimer {
    param(
        [System.Windows.Controls.TextBlock]$VersionsTextBlock,
        [System.Windows.Controls.TextBlock]$DateTimeTextBlock,
        [hashtable]$OutlookInfo,
        [hashtable]$TeamsInfo
    )

    # Store in script scope for access in timer event
    $script:statusBarVersionsTextBlock = $VersionsTextBlock
    $script:statusBarDateTimeTextBlock = $DateTimeTextBlock
    $script:statusBarOutlookInfo = $OutlookInfo
    $script:statusBarTeamsInfo = $TeamsInfo

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)

    $timer.Add_Tick({
        # Update versions (static)
        $outlookVer = if ($script:statusBarOutlookInfo.Installed) { "Outlook: $($script:statusBarOutlookInfo.Version)" } else { "Outlook: N/A" }
        $teamsVer = if ($script:statusBarTeamsInfo.Installed) { "Teams: $($script:statusBarTeamsInfo.Version)" } else { "Teams: N/A" }
        $script:statusBarVersionsTextBlock.Text = "$outlookVer | $teamsVer"

        # Update date/time (dynamic)
        $script:statusBarDateTimeTextBlock.Text = Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt'
    })

    # Set initial values
    $outlookVer = if ($OutlookInfo.Installed) { "Outlook: $($OutlookInfo.Version)" } else { "Outlook: N/A" }
    $teamsVer = if ($TeamsInfo.Installed) { "Teams: $($TeamsInfo.Version)" } else { "Teams: N/A" }
    $VersionsTextBlock.Text = "$outlookVer | $teamsVer"
    $DateTimeTextBlock.Text = Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt'

    $timer.Start()
    return $timer
}

#endregion

#region XAML Definition

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Email, Event, and Teams Chat Creator"
        Height="680"
        Width="900"
        MinHeight="620"
        MinWidth="800"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize"
        Background="#F5F7FA">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
        <Style TargetType="Label">
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Foreground" Value="#2C3E50"/>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#34495E" CornerRadius="8" Padding="16,12" Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="Outlook &amp; Teams Integration Tool"
                          FontSize="20" FontWeight="SemiBold" Foreground="White"
                          VerticalAlignment="Center"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Name="BorderOutlookStatus" Background="#27AE60" CornerRadius="4"
                           Padding="8,4" Margin="0,0,8,0">
                        <TextBlock Name="TxtOutlookStatus" Text="Outlook: Ready"
                                  Foreground="White" FontSize="11" FontWeight="SemiBold"/>
                    </Border>
                    <Border Name="BorderTeamsStatus" Background="#3498DB" CornerRadius="4"
                           Padding="8,4">
                        <TextBlock Name="TxtTeamsStatus" Text="Teams: Ready"
                                  Foreground="White" FontSize="11" FontWeight="SemiBold"/>
                    </Border>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Tab Control -->
        <TabControl Grid.Row="1" Name="MainTabControl" Padding="4">

            <!-- Email Tab -->
            <TabItem Header="Email" FontSize="14" FontWeight="SemiBold">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Sample Data Buttons -->
                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,12">
                        <Button Name="BtnLoadSampleEmail" Content="Load Sample Data"
                               Width="140" Height="32" Margin="0,0,8,0"
                               ToolTip="Load sample email addresses and content"/>
                        <Button Name="BtnClearEmail" Content="Clear All"
                               Width="100" Height="32"
                               ToolTip="Clear all email fields"/>
                    </StackPanel>

                    <!-- To Field -->
                    <Grid Grid.Row="1" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="100"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Label Grid.Column="0" Content="To:" VerticalAlignment="Center"/>
                        <TextBox Grid.Column="1" Name="TxtEmailTo"
                                ToolTip="Primary recipients (semicolon separated)"/>
                    </Grid>

                    <!-- CC Field -->
                    <Grid Grid.Row="2" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="100"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Label Grid.Column="0" Content="CC:" VerticalAlignment="Center"/>
                        <TextBox Grid.Column="1" Name="TxtEmailCC"
                                ToolTip="CC recipients (semicolon separated)"/>
                    </Grid>

                    <!-- BCC Field -->
                    <Grid Grid.Row="3" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="100"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Label Grid.Column="0" Content="BCC:" VerticalAlignment="Center"/>
                        <TextBox Grid.Column="1" Name="TxtEmailBCC"
                                ToolTip="BCC recipients (semicolon separated)"/>
                    </Grid>

                    <!-- Subject Field -->
                    <Grid Grid.Row="4" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="100"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Label Grid.Column="0" Content="Subject:" VerticalAlignment="Center"/>
                        <TextBox Grid.Column="1" Name="TxtEmailSubject"
                                ToolTip="Email subject line"/>
                    </Grid>

                    <!-- Body Field -->
                    <Grid Grid.Row="5" Margin="0,0,0,12">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <Label Grid.Row="0" Content="Body:" Margin="0,0,0,4"/>
                        <TextBox Grid.Row="1" Name="TxtEmailBody"
                                TextWrapping="Wrap"
                                AcceptsReturn="True"
                                VerticalScrollBarVisibility="Auto"
                                ToolTip="Email message body"/>
                    </Grid>

                    <!-- Create Email Button -->
                    <Button Grid.Row="6" Name="BtnCreateEmail"
                           Content="Create Email in Outlook"
                           Height="40" FontSize="14"
                           Background="#3498DB" Foreground="White"
                           BorderBrush="#2980B9" BorderThickness="2"
                           ToolTip="Create and display email in Outlook (not sent yet)"/>
                </Grid>
            </TabItem>

            <!-- Event Tab -->
            <TabItem Header="Event" FontSize="14" FontWeight="SemiBold">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Scrollable Content Area -->
                    <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" Margin="0,0,0,12">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Sample Data Buttons -->
                            <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,12">
                                <Button Name="BtnLoadSampleEvent" Content="Load Sample Data"
                                       Width="140" Height="32" Margin="0,0,8,0"
                                       ToolTip="Load sample event data"/>
                                <Button Name="BtnClearEvent" Content="Clear All"
                                       Width="100" Height="32"
                                       ToolTip="Clear all event fields"/>
                            </StackPanel>

                            <!-- Date Field -->
                            <Grid Grid.Row="1" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Event Date:" VerticalAlignment="Center"/>
                                <DatePicker Grid.Column="1" Name="DatePickerEvent"
                                           ToolTip="Select event date"/>
                            </Grid>

                            <!-- Start Time Field -->
                            <Grid Grid.Row="2" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Start Time:" VerticalAlignment="Center"/>
                                <StackPanel Grid.Column="1" Orientation="Horizontal">
                                    <ComboBox Name="CmbEventHour" Width="70" Margin="0,0,8,0"
                                             ToolTip="Hour (1-12)"/>
                                    <ComboBox Name="CmbEventMinute" Width="70" Margin="0,0,8,0"
                                             ToolTip="Minute"/>
                                    <ComboBox Name="CmbEventAMPM" Width="70"
                                             ToolTip="AM/PM"/>
                                </StackPanel>
                            </Grid>

                            <!-- Duration Field -->
                            <Grid Grid.Row="3" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Duration (minutes):" VerticalAlignment="Center"/>
                                <ComboBox Grid.Column="1" Name="CmbEventDuration"
                                         ToolTip="Event duration in minutes"/>
                            </Grid>

                            <!-- Subject Field -->
                            <Grid Grid.Row="4" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Subject:" VerticalAlignment="Center"/>
                                <TextBox Grid.Column="1" Name="TxtEventSubject"
                                        ToolTip="Event subject/title"/>
                            </Grid>

                            <!-- Location Field -->
                            <Grid Grid.Row="5" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Location:" VerticalAlignment="Center"/>
                                <TextBox Grid.Column="1" Name="TxtEventLocation"
                                        ToolTip="Meeting location or Teams link"/>
                            </Grid>

                            <!-- Required Attendees Field -->
                            <Grid Grid.Row="6" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Required Attendees:" VerticalAlignment="Center"/>
                                <TextBox Grid.Column="1" Name="TxtEventRequired"
                                        ToolTip="Required attendees (semicolon separated)"/>
                            </Grid>

                            <!-- Optional Attendees Field -->
                            <Grid Grid.Row="7" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Optional Attendees:" VerticalAlignment="Center"/>
                                <TextBox Grid.Column="1" Name="TxtEventOptional"
                                        ToolTip="Optional attendees (semicolon separated)"/>
                            </Grid>

                            <!-- Body Field -->
                            <Grid Grid.Row="8" Margin="0,0,0,12">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="180"/>
                                </Grid.RowDefinitions>
                                <Label Grid.Row="0" Content="Event Description:" Margin="0,0,0,4"/>
                                <TextBox Grid.Row="1" Name="TxtEventBody"
                                        TextWrapping="Wrap"
                                        AcceptsReturn="True"
                                        VerticalScrollBarVisibility="Auto"
                                        ToolTip="Event agenda or description"/>
                            </Grid>

                            <!-- Reminder Options -->
                            <StackPanel Grid.Row="9" Orientation="Horizontal" Margin="0,0,0,12">
                                <CheckBox Name="ChkEventReminder" Content="Set Reminder"
                                         IsChecked="True" VerticalAlignment="Center" Margin="0,0,12,0"
                                         ToolTip="Enable reminder notification before event starts"/>
                                <Label Content="Minutes before:" VerticalAlignment="Center"/>
                                <ComboBox Name="CmbEventReminderMinutes" Width="100" Margin="4,0,0,0"
                                         IsEnabled="{Binding ElementName=ChkEventReminder, Path=IsChecked}"
                                         ToolTip="How many minutes before the event to show reminder"/>
                            </StackPanel>
                        </Grid>
                    </ScrollViewer>

                    <!-- Create Event Button (Docked to Bottom) -->
                    <Button Grid.Row="1" Name="BtnCreateEvent"
                           Content="Create Event in Outlook"
                           Height="40" FontSize="14"
                           Background="#27AE60" Foreground="White"
                           BorderBrush="#229954" BorderThickness="2"
                           ToolTip="Create and display calendar event in Outlook (not sent yet)"/>
                </Grid>
            </TabItem>

            <!-- Teams Tab -->
            <TabItem Header="Teams Chat" FontSize="14" FontWeight="SemiBold">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Info Panel -->
                    <Border Grid.Row="0" Background="#ECF0F1" BorderBrush="#BDC3C7"
                           BorderThickness="1" CornerRadius="6" Padding="12" Margin="0,0,0,16">
                        <StackPanel>
                            <TextBlock Text="Teams Chat Integration" FontWeight="SemiBold"
                                      FontSize="14" Margin="0,0,0,6"/>
                            <TextBlock TextWrapping="Wrap" Foreground="#555">
                                Choose to open a 1:1 chat by email address, or paste a Teams URL
                                to open a channel or group chat. Teams must be installed.
                            </TextBlock>
                        </StackPanel>
                    </Border>

                    <!-- Sample Data Buttons -->
                    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,12">
                        <Button Name="BtnLoadSampleTeams" Content="Load Sample Data"
                               Width="140" Height="32" Margin="0,0,8,0"
                               ToolTip="Load sample email address or Teams URL"/>
                        <Button Name="BtnClearTeams" Content="Clear All"
                               Width="100" Height="32"
                               ToolTip="Clear all Teams fields"/>
                    </StackPanel>

                    <!-- Mode Selection -->
                    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,12">
                        <RadioButton Name="RbTeamsEmail" Content="Chat with User (Email)"
                                     IsChecked="True" GroupName="TeamsMode" Margin="0,0,20,0"
                                     ToolTip="Open 1:1 chat by entering email address"/>
                        <RadioButton Name="RbTeamsUrl" Content="Open Teams URL"
                                     GroupName="TeamsMode"
                                     ToolTip="Open channel or group chat from Teams URL (right-click in Teams &gt; Get link)"/>
                    </StackPanel>

                    <!-- Email Input (visible when RbTeamsEmail checked) -->
                    <Grid Grid.Row="3" Name="GridTeamsEmail" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="150"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Label Grid.Column="0" Content="Email Address:" VerticalAlignment="Center"/>
                        <TextBox Grid.Column="1" Name="TxtTeamsEmail"
                                 ToolTip="Email address or UPN of person to chat with (e.g., john.doe@irs.gov)"/>
                    </Grid>

                    <!-- URL Input (collapsed by default, visible when RbTeamsUrl checked) -->
                    <Grid Grid.Row="3" Name="GridTeamsUrl" Visibility="Collapsed" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="150"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Label Grid.Column="0" Content="Teams URL:" VerticalAlignment="Center"/>
                        <TextBox Grid.Column="1" Name="TxtTeamsUrl"
                                 ToolTip="Paste Teams channel or group chat URL (right-click in Teams &gt; Get link to conversation)"/>
                    </Grid>

                    <!-- Message Field (only for email mode) -->
                    <Grid Grid.Row="4" Name="GridTeamsMessage" Margin="0,0,0,12">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <Label Grid.Row="0" Content="Message (Optional):" Margin="0,0,0,4"/>
                        <TextBox Grid.Row="1" Name="TxtTeamsMessage"
                                TextWrapping="Wrap"
                                AcceptsReturn="True"
                                VerticalScrollBarVisibility="Auto"
                                ToolTip="Pre-fill Teams chat with this message (email mode only)"/>
                    </Grid>

                    <!-- Teams Status Info -->
                    <Border Grid.Row="5" Background="#E8F8F5" BorderBrush="#A9DFBF"
                           BorderThickness="1" CornerRadius="6" Padding="12" Margin="0,0,0,12">
                        <StackPanel Name="PanelTeamsInfo">
                            <TextBlock Name="TxtTeamsInfo" TextWrapping="Wrap"
                                      FontSize="12" Foreground="#27AE60"/>
                        </StackPanel>
                    </Border>

                    <!-- Action Button -->
                    <Button Grid.Row="6" Name="BtnOpenTeamsChat"
                           Content="Open Teams Chat"
                           Height="40" FontSize="14"
                           Background="#9B59B6" Foreground="White"
                           BorderBrush="#8E44AD" BorderThickness="2"
                           ToolTip="Open Teams chat or URL"/>
                </Grid>
            </TabItem>

            <!-- Notifications Tab -->
            <TabItem Header="Notifications" FontSize="14" FontWeight="SemiBold">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Scrollable Content Area -->
                    <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" Margin="0,0,0,12">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Info Panel -->
                            <Border Grid.Row="0" Background="#ECF0F1" BorderBrush="#BDC3C7"
                                   BorderThickness="1" CornerRadius="6" Padding="12" Margin="0,0,0,16">
                                <StackPanel>
                                    <TextBlock Text="Windows Toast Notifications" FontWeight="SemiBold"
                                              FontSize="14" Margin="0,0,0,6"/>
                                    <TextBlock TextWrapping="Wrap" Foreground="#555">
                                        Create and send Windows toast notifications to test appearance, sounds,
                                        grouping, and persistence. Notifications appear in the lower-right corner
                                        and are stored in Action Center (Win+A).
                                    </TextBlock>
                                </StackPanel>
                            </Border>

                            <!-- Sample Data Buttons -->
                            <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,12">
                                <Button Name="BtnLoadSampleNotification" Content="Load Sample Data"
                                       Width="140" Height="32" Margin="0,0,8,0"
                                       ToolTip="Load sample notification title and message"/>
                                <Button Name="BtnClearNotification" Content="Clear All"
                                       Width="100" Height="32" Margin="0,0,8,0"
                                       ToolTip="Clear all notification fields"/>
                                <Button Name="BtnClearHistory" Content="Clear History"
                                       Width="110" Height="32"
                                       ToolTip="Clear all notifications from Action Center"/>
                            </StackPanel>

                            <!-- Title Field -->
                            <Grid Grid.Row="2" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Title:" VerticalAlignment="Center"/>
                                <TextBox Grid.Column="1" Name="TxtNotificationTitle"
                                        ToolTip="Notification title (first line, bold text)"/>
                            </Grid>

                            <!-- Message Field -->
                            <Grid Grid.Row="3" Margin="0,0,0,12">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="100"/>
                                </Grid.RowDefinitions>
                                <Label Grid.Row="0" Content="Message:" Margin="0,0,0,4"/>
                                <TextBox Grid.Row="1" Name="TxtNotificationMessage"
                                        TextWrapping="Wrap"
                                        AcceptsReturn="True"
                                        VerticalScrollBarVisibility="Auto"
                                        ToolTip="Notification message (second line, regular text)"/>
                            </Grid>

                            <!-- Sound Selection -->
                            <Grid Grid.Row="4" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Sound:" VerticalAlignment="Center"/>
                                <ComboBox Grid.Column="1" Name="CmbNotificationSound"
                                         ToolTip="Notification sound to play">
                                    <ComboBoxItem Content="Default" IsSelected="True"/>
                                    <ComboBoxItem Content="Mail"/>
                                    <ComboBoxItem Content="Reminder"/>
                                    <ComboBoxItem Content="SMS"/>
                                    <ComboBoxItem Content="IM"/>
                                    <ComboBoxItem Content="Silent"/>
                                </ComboBox>
                            </Grid>

                            <!-- Duration Selection -->
                            <Grid Grid.Row="5" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Duration:" VerticalAlignment="Center"/>
                                <ComboBox Grid.Column="1" Name="CmbNotificationDuration"
                                         ToolTip="How long to display the notification on screen">
                                    <ComboBoxItem Content="Default (7 seconds)" IsSelected="True"/>
                                    <ComboBoxItem Content="Short (5 seconds)"/>
                                    <ComboBoxItem Content="Long (25 seconds)"/>
                                </ComboBox>
                            </Grid>

                            <!-- Tag Field (Optional) -->
                            <Grid Grid.Row="6" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Tag (Optional):" VerticalAlignment="Center"/>
                                <TextBox Grid.Column="1" Name="TxtNotificationTag"
                                        ToolTip="Unique identifier for this notification (enables replacement/removal)"/>
                            </Grid>

                            <!-- Group Field (Optional) -->
                            <Grid Grid.Row="7" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Label Grid.Column="0" Content="Group (Optional):" VerticalAlignment="Center"/>
                                <TextBox Grid.Column="1" Name="TxtNotificationGroup"
                                        ToolTip="Group identifier for related notifications (e.g., 'emails', 'events')"/>
                            </Grid>

                            <!-- Notification Info -->
                            <Border Grid.Row="8" Background="#FFF4E5" BorderBrush="#F9CA7B"
                                   BorderThickness="1" CornerRadius="6" Padding="12" Margin="0,0,0,12">
                                <StackPanel>
                                    <TextBlock FontWeight="SemiBold" Margin="0,0,0,4">Tips:</TextBlock>
                                    <TextBlock TextWrapping="Wrap" FontSize="11" Foreground="#333">
                                        - Use same Tag to replace existing notification<LineBreak/>
                                        - Use Group to organize related notifications<LineBreak/>
                                        - View notifications in Action Center (Win+A)<LineBreak/>
                                        - See Windows.Notify.Explain.md for full details
                                    </TextBlock>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </ScrollViewer>

                    <!-- Action Button (Docked to Bottom) -->
                    <Button Grid.Row="1" Name="BtnShowNotification"
                           Content="Show Notification"
                           Height="40" FontSize="14"
                           Background="#F39C12" Foreground="White"
                           BorderBrush="#D68910" BorderThickness="2"
                           ToolTip="Display the notification as a Windows toast"/>
                </Grid>
            </TabItem>
        </TabControl>

        <!-- User Info Area -->
        <Border Grid.Row="2" Background="#E8F4F8" BorderBrush="#B4D7E5"
                BorderThickness="1" CornerRadius="6" Padding="12,8" Margin="0,12,0,8">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Label Grid.Column="0" Content="Current User:" FontWeight="SemiBold"
                       Margin="0,0,8,0" VerticalAlignment="Center"/>
                <TextBox Grid.Column="1" Name="TxtCurrentUserId" IsReadOnly="True"
                         Background="White" BorderBrush="#D0D0D0" Margin="0,0,16,0"
                         ToolTip="Windows domain user identity (auto-detected)"/>

                <Label Grid.Column="2" Content="Email:" FontWeight="SemiBold"
                       Margin="0,0,8,0" VerticalAlignment="Center"/>
                <TextBox Grid.Column="3" Name="TxtCurrentUserEmail" IsReadOnly="True"
                         Background="White" BorderBrush="#D0D0D0" Margin="0,0,16,0"
                         ToolTip="User email address from Active Directory (auto-detected)"/>

                <Button Grid.Column="4" Name="BtnShowLog" Content="View Log"
                       Width="90" Height="32"
                       Background="#FF8C00" Foreground="White"
                       BorderBrush="#E67E00" BorderThickness="2"
                       ToolTip="Open diagnostic log window to troubleshoot issues"/>
            </Grid>
        </Border>

        <!-- Status Bar -->
        <Border Grid.Row="3" Background="#ECF0F1" CornerRadius="6" Padding="12,8" Margin="0,8,0,0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Orientation="Horizontal">
                    <TextBlock Name="TxtStatusBar" Text="Ready" Foreground="#34495E"
                               VerticalAlignment="Center" Margin="0,0,16,0"/>
                    <TextBlock Name="TxtStatusVersions" FontSize="11" Foreground="#7F8C8D"
                               VerticalAlignment="Center"
                               ToolTip="Installed application versions"/>
                </StackPanel>
                <TextBlock Name="TxtStatusDateTime" Grid.Column="1" FontSize="11"
                           Foreground="#7F8C8D" VerticalAlignment="Center"
                           ToolTip="Current date and time (updates every second)"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

#endregion

# Load XAML
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

#region Get UI Elements

# Status indicators
$borderOutlookStatus = $window.FindName('BorderOutlookStatus')
$txtOutlookStatus = $window.FindName('TxtOutlookStatus')
$borderTeamsStatus = $window.FindName('BorderTeamsStatus')
$txtTeamsStatus = $window.FindName('TxtTeamsStatus')

# Email tab controls
$btnLoadSampleEmail = $window.FindName('BtnLoadSampleEmail')
$btnClearEmail = $window.FindName('BtnClearEmail')
$txtEmailTo = $window.FindName('TxtEmailTo')
$txtEmailCC = $window.FindName('TxtEmailCC')
$txtEmailBCC = $window.FindName('TxtEmailBCC')
$txtEmailSubject = $window.FindName('TxtEmailSubject')
$txtEmailBody = $window.FindName('TxtEmailBody')
$btnCreateEmail = $window.FindName('BtnCreateEmail')

# Event tab controls
$btnLoadSampleEvent = $window.FindName('BtnLoadSampleEvent')
$btnClearEvent = $window.FindName('BtnClearEvent')
$datePickerEvent = $window.FindName('DatePickerEvent')
$cmbEventHour = $window.FindName('CmbEventHour')
$cmbEventMinute = $window.FindName('CmbEventMinute')
$cmbEventAMPM = $window.FindName('CmbEventAMPM')
$cmbEventDuration = $window.FindName('CmbEventDuration')
$txtEventSubject = $window.FindName('TxtEventSubject')
$txtEventLocation = $window.FindName('TxtEventLocation')
$txtEventRequired = $window.FindName('TxtEventRequired')
$txtEventOptional = $window.FindName('TxtEventOptional')
$txtEventBody = $window.FindName('TxtEventBody')
$chkEventReminder = $window.FindName('ChkEventReminder')
$cmbEventReminderMinutes = $window.FindName('CmbEventReminderMinutes')
$btnCreateEvent = $window.FindName('BtnCreateEvent')

# Teams tab controls
$btnLoadSampleTeams = $window.FindName('BtnLoadSampleTeams')
$btnClearTeams = $window.FindName('BtnClearTeams')
$txtTeamsEmail = $window.FindName('TxtTeamsEmail')
$txtTeamsMessage = $window.FindName('TxtTeamsMessage')
$txtTeamsInfo = $window.FindName('TxtTeamsInfo')
$btnOpenTeamsChat = $window.FindName('BtnOpenTeamsChat')

# Status bar
$txtStatusBar = $window.FindName('TxtStatusBar')

# User info controls
$txtCurrentUserId = $window.FindName('TxtCurrentUserId')
$txtCurrentUserEmail = $window.FindName('TxtCurrentUserEmail')
$btnShowLog = $window.FindName('BtnShowLog')

# Enhanced status bar controls
$txtStatusVersions = $window.FindName('TxtStatusVersions')
$txtStatusDateTime = $window.FindName('TxtStatusDateTime')

# Teams tab - enhanced controls
$rbTeamsEmail = $window.FindName('RbTeamsEmail')
$rbTeamsUrl = $window.FindName('RbTeamsUrl')
$gridTeamsEmail = $window.FindName('GridTeamsEmail')
$gridTeamsUrl = $window.FindName('GridTeamsUrl')
$txtTeamsUrl = $window.FindName('TxtTeamsUrl')
$gridTeamsMessage = $window.FindName('GridTeamsMessage')

# Notifications tab controls
$txtNotificationTitle = $window.FindName('TxtNotificationTitle')
$txtNotificationMessage = $window.FindName('TxtNotificationMessage')
$cmbNotificationSound = $window.FindName('CmbNotificationSound')
$cmbNotificationDuration = $window.FindName('CmbNotificationDuration')
$txtNotificationTag = $window.FindName('TxtNotificationTag')
$txtNotificationGroup = $window.FindName('TxtNotificationGroup')
$btnLoadSampleNotification = $window.FindName('BtnLoadSampleNotification')
$btnClearNotification = $window.FindName('BtnClearNotification')
$btnClearHistory = $window.FindName('BtnClearHistory')
$btnShowNotification = $window.FindName('BtnShowNotification')

#endregion

#region Initialize UI

# Initialize date picker to today
$datePickerEvent.SelectedDate = [DateTime]::Now.Date

# Populate hour combo box (1-12)
for ($i = 1; $i -le 12; $i++) {
    [void]$cmbEventHour.Items.Add($i)
}
$cmbEventHour.SelectedIndex = 8 # Default 9 AM

# Populate minute combo box (00, 15, 30, 45)
@('00', '15', '30', '45') | ForEach-Object { [void]$cmbEventMinute.Items.Add($_) }
$cmbEventMinute.SelectedIndex = 0 # Default :00

# Populate AM/PM combo box
@('AM', 'PM') | ForEach-Object { [void]$cmbEventAMPM.Items.Add($_) }
$cmbEventAMPM.SelectedIndex = 0 # Default AM

# Populate duration combo box
$durations = @(15, 30, 45, 60, 90, 120, 180, 240)
$durations | ForEach-Object {
    $hours = [Math]::Floor($_ / 60)
    $mins = $_ % 60
    $label = if ($hours -gt 0 -and $mins -gt 0) {
        "$hours hr $mins min"
    } elseif ($hours -gt 0) {
        "$hours hr"
    } else {
        "$mins min"
    }
    [void]$cmbEventDuration.Items.Add([PSCustomObject]@{ Label = $label; Minutes = $_ })
}
$cmbEventDuration.DisplayMemberPath = 'Label'
$cmbEventDuration.SelectedValuePath = 'Minutes'
$cmbEventDuration.SelectedIndex = 3 # Default 60 minutes

# Populate reminder minutes combo box
$reminderOptions = @(0, 5, 10, 15, 30, 60, 120, 1440) # Last is 1 day
$reminderOptions | ForEach-Object {
    $label = if ($_ -eq 0) { 'At event time' }
             elseif ($_ -lt 60) { "$_ minutes" }
             elseif ($_ -eq 60) { '1 hour' }
             elseif ($_ -lt 1440) { "$([Math]::Floor($_ / 60)) hours" }
             else { '1 day' }
    [void]$cmbEventReminderMinutes.Items.Add([PSCustomObject]@{ Label = $label; Minutes = $_ })
}
$cmbEventReminderMinutes.DisplayMemberPath = 'Label'
$cmbEventReminderMinutes.SelectedValuePath = 'Minutes'
$cmbEventReminderMinutes.SelectedIndex = 3 # Default 15 minutes

# Check Outlook and Teams installation
$outlookInfo = Get-OutlookVersionDetails
$teamsInfo = Test-TeamsInstalled

if ($outlookInfo.Installed) {
    $txtOutlookStatus.Text = "Outlook: Ready"
    $borderOutlookStatus.Background = [System.Windows.Media.Brushes]::MediumSeaGreen
    $tooltipText = "Product: $($outlookInfo.ProductName)`nVersion: $($outlookInfo.Version)`nReleased: $($outlookInfo.Released)`nInstall Date: $($outlookInfo.InstallDate)"
    $borderOutlookStatus.ToolTip = $tooltipText
    $txtStatusBar.Text = "Outlook COM available - Version $($outlookInfo.Version)"
}
else {
    $txtOutlookStatus.Text = "Outlook: Not Found"
    $borderOutlookStatus.Background = [System.Windows.Media.Brushes]::Tomato
    $borderOutlookStatus.ToolTip = "Microsoft Outlook is not installed or not accessible"
    $txtStatusBar.Text = "Warning: Outlook COM not available"
    $btnCreateEmail.IsEnabled = $false
    $btnCreateEvent.IsEnabled = $false
}

if ($teamsInfo.Installed) {
    $txtTeamsStatus.Text = "Teams: Ready"
    $borderTeamsStatus.Background = [System.Windows.Media.Brushes]::DodgerBlue
    $tooltipText = "Product: $($teamsInfo.ProductName)`nVersion: $($teamsInfo.Version)`nInstall Date: $($teamsInfo.InstallDate)`nPath: $($teamsInfo.Path)"
    $borderTeamsStatus.ToolTip = $tooltipText
    $txtTeamsInfo.Text = "✅ $($teamsInfo.ProductName) is installed (Version: $($teamsInfo.Version)). Teams chat will open in the Teams application."
}
else {
    $txtTeamsStatus.Text = "Teams: Not Found"
    $borderTeamsStatus.Background = [System.Windows.Media.Brushes]::Orange
    $borderTeamsStatus.ToolTip = "Microsoft Teams is not installed"
    $txtTeamsInfo.Text = "⚠️ Microsoft Teams is not detected. The Teams chat feature requires Teams to be installed."
    $btnOpenTeamsChat.IsEnabled = $false
}

# Initialize diagnostic logging
Add-DiagnosticLog "Application started: CreateEmailEventAndTeamsChat" -Level Info
Add-DiagnosticLog "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Info
Add-DiagnosticLog "OS: $([System.Environment]::OSVersion.VersionString)" -Level Info
Add-DiagnosticLog "User: $($env:USERNAME)" -Level Info
Add-DiagnosticLog "Outlook installed: $($outlookInfo.Installed)" -Level Info
Add-DiagnosticLog "Teams installed: $($teamsInfo.Installed)" -Level Info

# Get and display current user context
Add-DiagnosticLog "Retrieving current user context..." -Level Info
$userContext = Get-CurrentUserContext
$txtCurrentUserId.Text = $userContext.UserId
$txtCurrentUserEmail.Text = $userContext.Email
$txtCurrentUserId.ToolTip = "User: $($userContext.DisplayName)`nSAM: $($userContext.SamAccountName)"
Add-DiagnosticLog "User context loaded: $($userContext.UserId)" -Level Success

# Initialize status bar timer for live updates
$script:statusTimer = Initialize-StatusBarTimer `
    -VersionsTextBlock $txtStatusVersions `
    -DateTimeTextBlock $txtStatusDateTime `
    -OutlookInfo $outlookInfo `
    -TeamsInfo $teamsInfo

# Teams tab mode switching handlers
$rbTeamsEmail.Add_Checked({
    $gridTeamsEmail.Visibility = [System.Windows.Visibility]::Visible
    $gridTeamsUrl.Visibility = [System.Windows.Visibility]::Collapsed
    $gridTeamsMessage.Visibility = [System.Windows.Visibility]::Visible
    $btnOpenTeamsChat.Content = 'Open Teams Chat'
})

$rbTeamsUrl.Add_Checked({
    $gridTeamsEmail.Visibility = [System.Windows.Visibility]::Collapsed
    $gridTeamsUrl.Visibility = [System.Windows.Visibility]::Visible
    $gridTeamsMessage.Visibility = [System.Windows.Visibility]::Collapsed
    $btnOpenTeamsChat.Content = 'Open Teams URL'
})

#endregion

#region Email Tab Event Handlers

$btnLoadSampleEmail.Add_Click({
    $txtEmailTo.Text = Get-SampleEmailAddress
    $txtEmailCC.Text = 'cc.user@irs.gov'
    $txtEmailBCC.Text = ''
    $txtEmailSubject.Text = Get-SampleEmailSubject
    $txtEmailBody.Text = Get-SampleEmailBody
    $txtStatusBar.Text = 'Sample email data loaded'
})

$btnClearEmail.Add_Click({
    $txtEmailTo.Text = ''
    $txtEmailCC.Text = ''
    $txtEmailBCC.Text = ''
    $txtEmailSubject.Text = ''
    $txtEmailBody.Text = ''
    $txtStatusBar.Text = 'Email fields cleared'
})

$btnCreateEmail.Add_Click({
    try {
        $txtStatusBar.Text = 'Creating Outlook email...'
        $window.Cursor = [System.Windows.Input.Cursors]::Wait

        $result = New-OutlookEmail `
            -To $txtEmailTo.Text `
            -CC $txtEmailCC.Text `
            -BCC $txtEmailBCC.Text `
            -Subject $txtEmailSubject.Text `
            -Body $txtEmailBody.Text

        if ($result.Success) {
            $txtStatusBar.Text = $result.Message
            [System.Windows.MessageBox]::Show(
                'Email created successfully in Outlook. Review and click Send when ready.',
                'Success',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
        else {
            $txtStatusBar.Text = 'Error creating email'
            [System.Windows.MessageBox]::Show(
                $result.Message,
                'Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
        }
    }
    catch {
        $txtStatusBar.Text = 'Error creating email'
        [System.Windows.MessageBox]::Show(
            "Unexpected error: $($_.Exception.Message)",
            'Error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
})

#endregion

#region Event Tab Event Handlers

$btnLoadSampleEvent.Add_Click({
    $datePickerEvent.SelectedDate = [DateTime]::Now.Date.AddDays(1)
    $cmbEventHour.SelectedValue = 10
    $cmbEventMinute.SelectedValue = '00'
    $cmbEventAMPM.SelectedValue = 'AM'
    $cmbEventDuration.SelectedIndex = 3 # 60 minutes
    $txtEventSubject.Text = Get-SampleEventSubject
    $txtEventLocation.Text = 'Conference Room A / Teams'
    $txtEventRequired.Text = Get-SampleEmailAddress
    $txtEventOptional.Text = 'optional.attendee@irs.gov'
    $txtEventBody.Text = Get-SampleEventBody
    $chkEventReminder.IsChecked = $true
    $cmbEventReminderMinutes.SelectedIndex = 3 # 15 minutes
    $txtStatusBar.Text = 'Sample event data loaded'
})

$btnClearEvent.Add_Click({
    $datePickerEvent.SelectedDate = [DateTime]::Now.Date
    $cmbEventHour.SelectedIndex = 8
    $cmbEventMinute.SelectedIndex = 0
    $cmbEventAMPM.SelectedIndex = 0
    $cmbEventDuration.SelectedIndex = 3
    $txtEventSubject.Text = ''
    $txtEventLocation.Text = ''
    $txtEventRequired.Text = ''
    $txtEventOptional.Text = ''
    $txtEventBody.Text = ''
    $chkEventReminder.IsChecked = $true
    $cmbEventReminderMinutes.SelectedIndex = 3
    $txtStatusBar.Text = 'Event fields cleared'
})

$btnCreateEvent.Add_Click({
    try {
        $txtStatusBar.Text = 'Creating Outlook calendar event...'
        $window.Cursor = [System.Windows.Input.Cursors]::Wait

        # Validate required fields
        if (-not $datePickerEvent.SelectedDate) {
            [System.Windows.MessageBox]::Show(
                'Please select an event date.',
                'Validation Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            ) | Out-Null
            return
        }

        # Build start date/time
        $eventDate = $datePickerEvent.SelectedDate
        $hour = [int]$cmbEventHour.SelectedValue
        $minute = [int]$cmbEventMinute.SelectedValue
        $ampm = $cmbEventAMPM.SelectedValue

        if ($ampm -eq 'PM' -and $hour -ne 12) {
            $hour += 12
        }
        elseif ($ampm -eq 'AM' -and $hour -eq 12) {
            $hour = 0
        }

        $startDateTime = $eventDate.AddHours($hour).AddMinutes($minute)
        $duration = $cmbEventDuration.SelectedItem.Minutes
        $reminderMinutes = if ($chkEventReminder.IsChecked) { $cmbEventReminderMinutes.SelectedItem.Minutes } else { 0 }

        $result = New-OutlookCalendarEvent `
            -StartDateTime $startDateTime `
            -DurationMinutes $duration `
            -Subject $txtEventSubject.Text `
            -Body $txtEventBody.Text `
            -Location $txtEventLocation.Text `
            -RequiredAttendees $txtEventRequired.Text `
            -OptionalAttendees $txtEventOptional.Text `
            -ReminderSet $chkEventReminder.IsChecked `
            -ReminderMinutesBeforeStart $reminderMinutes

        if ($result.Success) {
            $txtStatusBar.Text = $result.Message
            [System.Windows.MessageBox]::Show(
                'Calendar event created successfully in Outlook. Review and click Send to invite attendees.',
                'Success',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
        else {
            $txtStatusBar.Text = 'Error creating event'
            [System.Windows.MessageBox]::Show(
                $result.Message,
                'Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
        }
    }
    catch {
        $txtStatusBar.Text = 'Error creating event'
        [System.Windows.MessageBox]::Show(
            "Unexpected error: $($_.Exception.Message)",
            'Error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
})

#endregion

#region Teams Tab Event Handlers

$btnLoadSampleTeams.Add_Click({
    if ($rbTeamsUrl.IsChecked) {
        # Sample Teams channel URL
        $txtTeamsUrl.Text = 'https://teams.microsoft.com/l/channel/19%3a1203fd26b4cf4b06a8b51ae2b82c4a38%40thread.v2/General?groupId=abc123&tenantId=def456'
    }
    else {
        # Sample email and message
        $txtTeamsEmail.Text = Get-SampleEmailAddress
        $txtTeamsMessage.Text = 'Hi! I wanted to follow up on our discussion. Can we chat?'
    }
    $txtStatusBar.Text = 'Sample Teams data loaded'
})

$btnClearTeams.Add_Click({
    $txtTeamsEmail.Text = ''
    $txtTeamsMessage.Text = ''
    $txtTeamsUrl.Text = ''
    $txtStatusBar.Text = 'Teams fields cleared'
})

$btnOpenTeamsChat.Add_Click({
    try {
        $txtStatusBar.Text = 'Opening Teams...'
        $window.Cursor = [System.Windows.Input.Cursors]::Wait

        $result = $null

        if ($rbTeamsUrl.IsChecked) {
            # URL mode
            if ([string]::IsNullOrWhiteSpace($txtTeamsUrl.Text)) {
                [System.Windows.MessageBox]::Show(
                    'Please enter a Teams URL.',
                    'Validation Error',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            $result = Open-TeamsChat -TeamsUrl $txtTeamsUrl.Text
        }
        else {
            # Email mode
            if ([string]::IsNullOrWhiteSpace($txtTeamsEmail.Text)) {
                [System.Windows.MessageBox]::Show(
                    'Please enter an email address.',
                    'Validation Error',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            $result = Open-TeamsChat `
                -UserEmail $txtTeamsEmail.Text `
                -Message $txtTeamsMessage.Text
        }

        if ($result.Success) {
            $txtStatusBar.Text = $result.Message
            [System.Windows.MessageBox]::Show(
                $result.Message,
                'Success',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
        else {
            $txtStatusBar.Text = 'Error opening Teams'
            [System.Windows.MessageBox]::Show(
                $result.Message,
                'Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
        }
    }
    catch {
        $txtStatusBar.Text = 'Error opening Teams'
        [System.Windows.MessageBox]::Show(
            "Unexpected error: $($_.Exception.Message)",
            'Error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
})

#endregion

#region Notifications Tab Event Handlers

# Load Sample Notification Data
$btnLoadSampleNotification.Add_Click({
    $txtNotificationTitle.Text = Get-SampleNotificationTitle
    $txtNotificationMessage.Text = Get-SampleNotificationMessage
    $txtNotificationTag.Text = "notify-$(Get-Date -Format 'HHmmss')"
    $txtNotificationGroup.Text = "samples"
    $txtStatusBar.Text = 'Sample notification data loaded'
})

# Clear Notification Fields
$btnClearNotification.Add_Click({
    $txtNotificationTitle.Text = ''
    $txtNotificationMessage.Text = ''
    $txtNotificationTag.Text = ''
    $txtNotificationGroup.Text = ''
    $cmbNotificationSound.SelectedIndex = 0
    $cmbNotificationDuration.SelectedIndex = 0
    $txtStatusBar.Text = 'Notification fields cleared'
})

# Clear Notification History
$btnClearHistory.Add_Click({
    try {
        $txtStatusBar.Text = 'Clearing notification history...'
        $window.Cursor = [System.Windows.Input.Cursors]::Wait

        $result = Clear-AllWindowsNotifications

        if ($result.Success) {
            $txtStatusBar.Text = $result.Message
            [System.Windows.MessageBox]::Show(
                'All notifications have been cleared from Action Center.',
                'Success',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
        else {
            $txtStatusBar.Text = 'Error clearing notifications'
            [System.Windows.MessageBox]::Show(
                $result.Message,
                'Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
        }
    }
    catch {
        $txtStatusBar.Text = 'Error clearing notifications'
        [System.Windows.MessageBox]::Show(
            "Unexpected error: $($_.Exception.Message)",
            'Error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
})

# Show Notification
$btnShowNotification.Add_Click({
    try {
        $txtStatusBar.Text = 'Showing notification...'
        $window.Cursor = [System.Windows.Input.Cursors]::Wait

        # Validate inputs
        if ([string]::IsNullOrWhiteSpace($txtNotificationTitle.Text)) {
            [System.Windows.MessageBox]::Show(
                'Please enter a notification title.',
                'Validation Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            ) | Out-Null
            return
        }

        if ([string]::IsNullOrWhiteSpace($txtNotificationMessage.Text)) {
            [System.Windows.MessageBox]::Show(
                'Please enter a notification message.',
                'Validation Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            ) | Out-Null
            return
        }

        # Parse selected sound
        $sound = switch ($cmbNotificationSound.SelectedIndex) {
            0 { 'Default' }
            1 { 'Mail' }
            2 { 'Reminder' }
            3 { 'SMS' }
            4 { 'IM' }
            5 { 'Silent' }
            default { 'Default' }
        }

        # Parse selected duration
        $duration = switch ($cmbNotificationDuration.SelectedIndex) {
            0 { 'Default' }
            1 { 'Short' }
            2 { 'Long' }
            default { 'Default' }
        }

        # Build parameters
        $params = @{
            Title = $txtNotificationTitle.Text
            Message = $txtNotificationMessage.Text
            Sound = $sound
            Duration = $duration
        }

        if (-not [string]::IsNullOrWhiteSpace($txtNotificationTag.Text)) {
            $params.Tag = $txtNotificationTag.Text
        }

        if (-not [string]::IsNullOrWhiteSpace($txtNotificationGroup.Text)) {
            $params.Group = $txtNotificationGroup.Text
        }

        # Show notification
        $result = Show-WindowsNotification @params

        if ($result.Success) {
            $txtStatusBar.Text = $result.Message
            [System.Windows.MessageBox]::Show(
                "Notification displayed successfully!`n`nCheck the lower-right corner of your screen, or press Win+A to view in Action Center.",
                'Success',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
        else {
            $txtStatusBar.Text = 'Error showing notification'
            [System.Windows.MessageBox]::Show(
                $result.Message,
                'Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
        }
    }
    catch {
        $txtStatusBar.Text = 'Error showing notification'
        [System.Windows.MessageBox]::Show(
            "Unexpected error: $($_.Exception.Message)",
            'Error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
})

#endregion

#region View Log Button Event Handler

# View Log button
$btnShowLog.Add_Click({
    Show-DiagnosticLogWindow
})

#endregion

# Cleanup on window close
$window.Add_Closed({
    if ($script:statusTimer) {
        $script:statusTimer.Stop()
    }
})

# Show window
[void]$window.ShowDialog()
