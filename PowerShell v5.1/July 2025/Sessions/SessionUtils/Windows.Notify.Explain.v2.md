# Windows Notification System - Comprehensive Technical Reference v2.0

<a name="top"></a>

**Document Version**: 2.0  
**Last Updated**: 2026-09-19  
**For**: CreateEmailEventAndTeamsChat.Prototype.ps1 Notifications Feature

---

## Executive Summary

This document provides a comprehensive technical reference for implementing Windows toast notifications using the Windows Runtime (WinRT) API in PowerShell applications.

**Key Findings**:

- **Notification Architecture**: Windows 10/11 use the WinRT Toast Notification API for modern desktop alerts. Notifications appear in the lower-right corner for 5-25 seconds (configurable), then persist in Action Center for up to 7 days. The system supports rich content including images, sounds, progress bars, and interactive buttons.

- **Multiple Notifications**: Windows queues notifications intelligently, displaying a maximum of 3 toasts simultaneously on screen. All notifications are stored in Action Center with a limit of 20 per application. Tag and Group properties enable notification replacement and threading for better organization.

- **Persistence and Loss**: Notifications persist through reboots and are stored in Action Center for 5 days by default (max 7 days). However, Focus Assist can suppress notifications completely without storing them. The system has no built-in authentication—any application running as the current user can send notifications under any App ID.

- **Cross-Device Sync**: Optional but unreliable. If users enable notification sync via Microsoft Account, toasts may appear on multiple devices. However, this feature uses best-effort delivery with 15-30 minute delays and is not suitable for critical notifications. Local file paths and custom sounds do not sync.

- **Security Model**: User-level only with no App ID authentication. Applications are trusted to display accurate content. Notification content is logged in Action Center's SQLite database and may sync to Microsoft servers if cross-device sync is enabled. Do not include PII or sensitive data in notification text.

- **PowerShell Implementation**: Full support via COM-style WinRT type loading. The implementation pattern requires loading three WinRT types, building XML toast templates, and calling the ToastNotificationManager. The codebase already has a working implementation in TrackSessions.Simulator CR1.ps1 that can be adapted.

**Quick Reference**:
- Basic notification: 5 lines of PowerShell (load types, create XML, show)
- Supported sounds: Default, Mail, Reminder, SMS, IM, Silent
- Duration options: Short (5s), Default (7s), Long (25s)
- Max 20 notifications per app in Action Center
- Tag enables replacement, Group enables threading
- Focus Assist can silently suppress all notifications

---

## Table of Contents

1. [Overview](#1-overview)
2. [How Windows Notifications Work](#2-how-windows-notifications-work)
   - 2.1 [Architecture](#21-architecture)
   - 2.2 [Process Flow](#22-process-flow)
3. [Toast Notification Framework](#3-toast-notification-framework)
   - 3.1 [Basic Template Types](#31-basic-template-types)
   - 3.2 [Modern Adaptive Templates](#32-modern-adaptive-templates)
4. [Multiple Notifications from Same Application](#4-multiple-notifications-from-same-application)
   - 4.1 [How Windows Handles Multiple Toasts](#41-how-windows-handles-multiple-toasts)
   - 4.2 [Sending Multiple Notifications](#42-sending-multiple-notifications)
   - 4.3 [Notification Throttling Best Practice](#43-notification-throttling-best-practice)
5. [Grouping and Threading](#5-grouping-and-threading)
   - 5.1 [Tag and Group System](#51-tag-and-group-system)
   - 5.2 [Grouped Notifications Example](#52-grouped-notifications-example)
   - 5.3 [Header-Based Grouping](#53-header-based-grouping)
   - 5.4 [Replacing Notifications](#54-replacing-notifications)
6. [Silencing Notifications](#6-silencing-notifications)
   - 6.1 [User-Level Controls](#61-user-level-controls)
   - 6.2 [Programmatic Silencing](#62-programmatic-silencing)
7. [Notification Persistence and Loss Prevention](#7-notification-persistence-and-loss-prevention)
   - 7.1 [Do Notifications Get Lost?](#71-do-notifications-get-lost)
   - 7.2 [When Notifications Persist](#72-when-notifications-persist)
   - 7.3 [When Notifications Are Lost](#73-when-notifications-are-lost)
   - 7.4 [Ensuring Notifications Don't Get Lost](#74-ensuring-notifications-dont-get-lost)
8. [Customizing the Toast UI](#8-customizing-the-toast-ui)
   - 8.1 [Toast Display Duration](#81-toast-display-duration)
   - 8.2 [Adding Images](#82-adding-images)
   - 8.3 [Interactive Buttons](#83-interactive-buttons)
   - 8.4 [Text Input Fields](#84-text-input-fields)
   - 8.5 [Progress Bar](#85-progress-bar)
   - 8.6 [Sounds](#86-sounds)
9. [Security Model](#9-security-model)
   - 9.1 [Application ID Registration](#91-application-id-registration)
   - 9.2 [Notification Content Security](#92-notification-content-security)
   - 9.3 [Privacy Considerations](#93-privacy-considerations)
   - 9.4 [Code Execution Security](#94-code-execution-security)
   - 9.5 [Sandboxing](#95-sandboxing)
10. [Multi-Machine Considerations](#10-multi-machine-considerations)
    - 10.1 [Cross-Device Notifications](#101-cross-device-notifications)
    - 10.2 [Best Practices for Multi-Machine Scenarios](#102-best-practices-for-multi-machine-scenarios)
    - 10.3 [Notification Action Center Sync Behavior](#103-notification-action-center-sync-behavior)
11. [PowerShell Implementation Guide](#11-powershell-implementation-guide)
    - 11.1 [Minimal Working Example](#111-minimal-working-example)
    - 11.2 [Production-Ready Implementation](#112-production-ready-implementation)
    - 11.3 [Helper Functions](#113-helper-functions)
12. [Advanced Features](#12-advanced-features)
    - 12.1 [Scheduled Notifications](#121-scheduled-notifications)
    - 12.2 [Notification Update (Progress Bar)](#122-notification-update-progress-bar)
    - 12.3 [Notification with Buttons (Advanced)](#123-notification-with-buttons-advanced)
13. [Summary and Feature Matrix](#13-summary-and-feature-matrix)
14. [Glossary](#14-glossary)

---

## 1. Overview

[↑ Top](#top)

Windows 10 and Windows 11 use the **Windows Runtime (WinRT) Toast Notification API** for modern app notifications. This system replaced the older balloon tip notifications and provides:

- Rich, interactive notifications with buttons, images, progress bars
- Notification grouping and threading
- Persistent notification history in Action Center
- User-controlled Do Not Disturb (Focus Assist)
- Per-app notification settings and permissions
- Cross-device notification sync (optional)

**Key Namespace**: `Windows.UI.Notifications`

---

## 2. How Windows Notifications Work

[↑ Top](#top)

### 2.1 Architecture

[↑ Top](#top)

```
┌─────────────────────────────────────────────────────────────┐
│                     Your PowerShell App                      │
│                                                              │
│  1. Create XML Toast Template                               │
│  2. Load WinRT Types                                        │
│  3. Create ToastNotification Object                         │
│  4. Show via ToastNotificationManager                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Windows Notification Platform                   │
│                                                              │
│  • Validates XML Schema                                     │
│  • Checks App ID Registration                               │
│  • Applies User Preferences (Focus Assist, Per-App)         │
│  • Queues Notification                                      │
│  • Renders Toast in Top-Right Corner                        │
│  • Archives to Action Center (Win+A)                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Action Center History                       │
│                                                              │
│  • Stores up to 20 notifications per app                    │
│  • User can clear individually or in bulk                   │
│  • Syncs across devices (if enabled)                        │
│  • Persists through reboots                                 │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Process Flow

[↑ Top](#top)

1. **App ID Registration**: When you call `CreateToastNotifier($APP_ID)`, Windows creates or uses an existing registration for that App ID in the registry.

2. **XML Template**: You define the notification content in XML format following the Toast Content Schema.

3. **WinRT Types**: PowerShell loads the Windows Runtime types from `Windows.UI.Notifications.dll` which ships with Windows 10/11.

4. **Show()**: Calling `.Show()` submits the notification to the Windows notification broker service.

5. **Rendering**: Windows displays the toast in the lower-right corner for ~5 seconds (default), then moves it to Action Center.

---

## 3. Toast Notification Framework

[↑ Top](#top)

### 3.1 Basic Template Types

[↑ Top](#top)

Windows provides several built-in toast templates:

| Template | Description | Fields |
|----------|-------------|--------|
| `ToastText01` | Single line of text | Title only |
| `ToastText02` | Two lines of text | Title + Message |
| `ToastText03` | Two lines with wrapped text | Title + Long Message |
| `ToastText04` | Three lines | Title + Message + Secondary Message |
| `ToastImageAndText01` | Image + one line | Image + Title |
| `ToastImageAndText02` | Image + two lines | Image + Title + Message |
| `ToastImageAndText03` | Image + wrapped text | Image + Title + Long Message |
| `ToastImageAndText04` | Image + three lines | Image + Title + Message + Secondary |

### 3.2 Modern Adaptive Templates

[↑ Top](#top)

Windows 10+ supports **adaptive toast templates** with richer layouts:

```xml
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Title Text</text>
            <text>Body Text Line 1</text>
            <text>Body Text Line 2</text>
            <image placement="appLogoOverride" src="C:\path\to\icon.png"/>
            <image placement="hero" src="C:\path\to\banner.png"/>
        </binding>
    </visual>
    <actions>
        <action content="Reply" arguments="reply" />
        <action content="Dismiss" arguments="dismiss" />
    </actions>
    <audio src="ms-winsoundevent:Notification.Default" loop="false" />
</toast>
```

**Key Elements**:
- `<visual>`: Display content (text, images)
- `<actions>`: Interactive buttons (up to 5)
- `<audio>`: Sound file or Windows system sound
- `<header>`: For grouping notifications

---

## 4. Multiple Notifications from Same Application

[↑ Top](#top)

### 4.1 How Windows Handles Multiple Toasts

[↑ Top](#top)

When you show multiple notifications from the same App ID:

1. **Queuing**: Windows queues notifications if more than 3-4 are shown rapidly
2. **Display Limit**: Maximum 3 toasts visible simultaneously on screen
3. **Action Center**: All notifications stored in history (up to 20 per app)
4. **Replacement**: New notifications push older ones to Action Center faster

### 4.2 Sending Multiple Notifications

[↑ Top](#top)

```powershell
function Show-WindowsNotification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Tag = $null,      # Unique identifier for replacement
        [string]$Group = $null     # Group identifier for threading
    )
    
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    
    $APP_ID = "CreateEmailEventAndTeamsChat"
    $template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$Title</text>
            <text id="2">$Message</text>
        </binding>
    </visual>
</toast>
"@
    
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($template)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    
    # Set Tag and Group for replacement/threading
    if ($Tag) { $toast.Tag = $Tag }
    if ($Group) { $toast.Group = $Group }
    
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).Show($toast)
}

# Send multiple notifications
Show-WindowsNotification -Title "Email Created" -Message "Email to john.doe@irs.gov" -Tag "email-001"
Show-WindowsNotification -Title "Event Created" -Message "Meeting scheduled for 2PM" -Tag "event-001"
Show-WindowsNotification -Title "Teams Chat" -Message "Opened chat with Jane" -Tag "teams-001"
```

### 4.3 Notification Throttling Best Practice

[↑ Top](#top)

To avoid overwhelming users, implement throttling:

```powershell
$script:lastNotificationTime = $null
$script:notificationQueue = @()

function Queue-Notification {
    param([string]$Title, [string]$Message)
    
    $script:notificationQueue += @{ Title = $Title; Message = $Message; Time = Get-Date }
    
    # Only show one notification per 3 seconds
    $now = Get-Date
    if (-not $script:lastNotificationTime -or 
        ($now - $script:lastNotificationTime).TotalSeconds -ge 3) {
        
        $notification = $script:notificationQueue[0]
        Show-WindowsNotification -Title $notification.Title -Message $notification.Message
        $script:lastNotificationTime = $now
        $script:notificationQueue = $script:notificationQueue | Select-Object -Skip 1
    }
}
```

---

## 5. Grouping and Threading

[↑ Top](#top)

### 5.1 Tag and Group System

[↑ Top](#top)

Windows supports **Tag** and **Group** properties for notification management:

- **Tag**: Unique identifier within a group. Used to replace or remove specific notifications.
- **Group**: Category identifier. Used to group related notifications together.

### 5.2 Grouped Notifications Example

[↑ Top](#top)

```powershell
# Emails group
Show-WindowsNotification -Title "New Email" -Message "From: Alice" -Tag "email-1" -Group "emails"
Show-WindowsNotification -Title "New Email" -Message "From: Bob" -Tag "email-2" -Group "emails"

# Events group
Show-WindowsNotification -Title "Meeting Soon" -Message "Team standup in 10 min" -Tag "event-1" -Group "events"
Show-WindowsNotification -Title "Meeting Soon" -Message "1:1 with manager in 30 min" -Tag "event-2" -Group "events"
```

**Result**: Action Center shows these as two separate groups:
- "emails" (2 notifications)
- "events" (2 notifications)

### 5.3 Header-Based Grouping

[↑ Top](#top)

Use `<header>` element for visual grouping with a title:

```xml
<toast>
    <header id="email-header" 
            title="New Emails" 
            arguments="group:emails"
            activationType="background"/>
    <visual>
        <binding template="ToastText02">
            <text>Email from Alice</text>
            <text>RE: Project Update</text>
        </binding>
    </visual>
</toast>
```

### 5.4 Replacing Notifications

[↑ Top](#top)

To update an existing notification, use the same **Tag** and **Group**:

```powershell
# Initial notification
Show-WindowsNotification -Title "Download Started" -Message "0% complete" -Tag "download-1" -Group "downloads"

# Update (replaces previous)
Show-WindowsNotification -Title "Download Progress" -Message "50% complete" -Tag "download-1" -Group "downloads"

# Final update (replaces again)
Show-WindowsNotification -Title "Download Complete" -Message "File saved" -Tag "download-1" -Group "downloads"
```

Only one notification appears in Action Center (the latest one).

---

## 6. Silencing Notifications

[↑ Top](#top)

### 6.1 User-Level Controls

[↑ Top](#top)

Windows provides several ways for users to control notifications:

#### 6.1.1 Focus Assist (Do Not Disturb)

[↑ Top](#top)

**Location**: Settings → System → Focus Assist

**Modes**:
- **Off**: All notifications show
- **Priority only**: Only starred apps/contacts notify
- **Alarms only**: Only alarms and timers
- **Automatic rules**: Schedule-based (e.g., during presentations, gaming)

**Your App Cannot Override**: If Focus Assist blocks your app, notifications are suppressed silently and NOT stored in Action Center.

#### 6.1.2 Per-App Notification Settings

[↑ Top](#top)

**Location**: Settings → System → Notifications & actions → [Your App Name]

**User can disable**:
- Show notifications in Action Center
- Show notification banners
- Play notification sounds
- Show notification on lock screen
- Number of visible notifications in Action Center (1-20)

**Registry Location**:
```
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\[APP_ID]
```

### 6.2 Programmatic Silencing

[↑ Top](#top)

#### 6.2.1 Silent Notifications (No Banner)

[↑ Top](#top)

Show notification in Action Center only (no pop-up):

```xml
<toast launch="silent">
    <visual>
        <binding template="ToastText02">
            <text>Silent Update</text>
            <text>Check Action Center for details</text>
        </binding>
    </visual>
    <audio silent="true"/>
</toast>
```

#### 6.2.2 Suppress Sound

[↑ Top](#top)

```xml
<toast>
    <visual>...</visual>
    <audio silent="true"/>
</toast>
```

#### 6.2.3 Remove Notification Programmatically

[↑ Top](#top)

```powershell
function Remove-WindowsNotification {
    param(
        [string]$Tag,
        [string]$Group = ""
    )
    
    $APP_ID = "CreateEmailEventAndTeamsChat"
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID)
    $history = [Windows.UI.Notifications.ToastNotificationManager]::History
    
    if ($Tag) {
        $history.Remove($Tag, $Group, $APP_ID)
    }
}

# Remove specific notification
Remove-WindowsNotification -Tag "email-001" -Group "emails"
```

#### 6.2.4 Clear All Notifications for App

[↑ Top](#top)

```powershell
function Clear-AllWindowsNotifications {
    $APP_ID = "CreateEmailEventAndTeamsChat"
    $history = [Windows.UI.Notifications.ToastNotificationManager]::History
    $history.Clear($APP_ID)
}
```

---

## 7. Notification Persistence and Loss Prevention

[↑ Top](#top)

### 7.1 Do Notifications Get Lost?

[↑ Top](#top)

**Short Answer**: Notifications can be lost in specific scenarios, but Windows has built-in persistence.

### 7.2 When Notifications Persist

[↑ Top](#top)

✅ **Notifications ARE stored** in these cases:
- User is away when notification shows → Stored in Action Center
- User dismisses notification → Stored in Action Center (unless manually cleared)
- System reboots → Notifications survive reboot (Action Center history persists)
- Screen is locked → Notification shown on lock screen (if enabled) + Action Center
- Focus Assist enabled → **Depends on mode** (see below)

### 7.3 When Notifications Are Lost

[↑ Top](#top)

❌ **Notifications ARE NOT stored** in these cases:
- **Focus Assist "Alarms only" mode**: Notification suppressed completely, not saved
- **App notifications disabled in Settings**: Silently dropped
- **Action Center full (20 notification limit)**: Oldest notification removed when 21st arrives
- **User clears Action Center**: Manually removed
- **App unregistered/removed**: All associated notifications cleared
- **Notification XML is malformed**: Fails silently, not shown or stored

### 7.4 Ensuring Notifications Don't Get Lost

[↑ Top](#top)

#### 7.4.1 Set Expiration Time

[↑ Top](#top)

```powershell
$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
$toast.ExpirationTime = (Get-Date).AddHours(24)  # Keep for 24 hours
```

Default expiration: 5 days. Max: 7 days.

#### 7.4.2 Use Scheduled Notifications

[↑ Top](#top)

Deliver notification at specific time:

```powershell
$scheduledTime = (Get-Date).AddMinutes(30)
$scheduledToast = New-Object Windows.UI.Notifications.ScheduledToastNotification($xml, $scheduledTime)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).AddToSchedule($scheduledToast)
```

#### 7.4.3 Check Notification History

[↑ Top](#top)

Query existing notifications:

```powershell
function Get-WindowsNotificationHistory {
    param([string]$AppId = "CreateEmailEventAndTeamsChat")
    
    $history = [Windows.UI.Notifications.ToastNotificationManager]::History
    $notifications = $history.GetHistory($AppId)
    
    foreach ($notification in $notifications) {
        [PSCustomObject]@{
            Tag = $notification.Tag
            Group = $notification.Group
            Content = $notification.Content.GetXml()
        }
    }
}
```

#### 7.4.4 Logging and Redundancy

[↑ Top](#top)

Maintain your own log of sent notifications:

```powershell
function Show-WindowsNotification-WithLogging {
    param([string]$Title, [string]$Message, [string]$Tag)
    
    try {
        # Show notification
        Show-WindowsNotification -Title $Title -Message $Message -Tag $Tag
        
        # Log to file
        $logEntry = [PSCustomObject]@{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Tag = $Tag
            Title = $Title
            Message = $Message
            Status = "Sent"
        }
        $logEntry | Export-Csv -Path ".\NotificationLog.csv" -Append -NoTypeInformation
    }
    catch {
        # Log failure
        $logEntry = [PSCustomObject]@{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Tag = $Tag
            Title = $Title
            Message = $Message
            Status = "Failed: $($_.Exception.Message)"
        }
        $logEntry | Export-Csv -Path ".\NotificationLog.csv" -Append -NoTypeInformation
    }
}
```

---

## 8. Customizing the Toast UI

[↑ Top](#top)

### 8.1 Toast Display Duration

[↑ Top](#top)

Default: **7 seconds** on screen, then moves to Action Center

**Short Duration** (5 seconds):
```xml
<toast duration="short">...</toast>
```

**Long Duration** (25 seconds):
```xml
<toast duration="long">...</toast>
```

### 8.2 Adding Images

[↑ Top](#top)

#### 8.2.1 App Logo Override (Small Icon)

[↑ Top](#top)

```xml
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Meeting Reminder</text>
            <text>Team standup in 5 minutes</text>
            <image placement="appLogoOverride" 
                   hint-crop="circle" 
                   src="C:\Icons\calendar.png"/>
        </binding>
    </visual>
</toast>
```

**Supported Formats**: PNG, JPG, GIF (max 200 KB)

#### 8.2.2 Hero Image (Large Banner)

[↑ Top](#top)

```xml
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Document Ready</text>
            <text>Your report has been generated</text>
            <image placement="hero" src="C:\Images\report-preview.jpg"/>
        </binding>
    </visual>
</toast>
```

#### 8.2.3 Inline Image

[↑ Top](#top)

```xml
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Weather Alert</text>
            <text>Severe thunderstorm warning</text>
            <image src="C:\Weather\radar.png"/>
        </binding>
    </visual>
</toast>
```

### 8.3 Interactive Buttons

[↑ Top](#top)

Add up to 5 buttons:

```xml
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>New Email from Alice</text>
            <text>RE: Project Update - Can we meet tomorrow?</text>
        </binding>
    </visual>
    <actions>
        <action content="Reply" arguments="reply:alice@company.com" />
        <action content="Mark Read" arguments="markread:12345" />
        <action content="Delete" arguments="delete:12345" />
    </actions>
</toast>
```

**Handling Button Clicks**: Requires registering a COM server or using protocol activation (advanced).

### 8.4 Text Input Fields

[↑ Top](#top)

Allow user to type response directly in toast:

```xml
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Quick Reply to Alice</text>
        </binding>
    </visual>
    <actions>
        <input id="textBox" type="text" placeHolderContent="Type a reply..."/>
        <action content="Send" arguments="send" />
    </actions>
</toast>
```

### 8.5 Progress Bar

[↑ Top](#top)

Show dynamic progress:

```xml
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Downloading File</text>
            <progress value="0.5" valueStringOverride="50%" status="Downloading..." />
        </binding>
    </visual>
</toast>
```

**Update Progress**:
```powershell
$data = New-Object Windows.UI.Notifications.NotificationData
$data.Values["progress"] = "0.75"
$data.Values["progressStatus"] = "Almost done..."
$history.Update($data, "download-tag", "downloads", $APP_ID)
```

### 8.6 Sounds

[↑ Top](#top)

#### 8.6.1 System Sounds

[↑ Top](#top)

```xml
<audio src="ms-winsoundevent:Notification.Default"/>
<audio src="ms-winsoundevent:Notification.Mail"/>
<audio src="ms-winsoundevent:Notification.Reminder"/>
<audio src="ms-winsoundevent:Notification.SMS"/>
<audio src="ms-winsoundevent:Notification.IM"/>
<audio src="ms-winsoundevent:Notification.Looping.Alarm"/>
<audio src="ms-winsoundevent:Notification.Looping.Call"/>
```

#### 8.6.2 Custom Sound

[↑ Top](#top)

```xml
<audio src="file:///C:/Sounds/custom-notification.mp3"/>
```

**Supported Formats**: MP3, WMA, WAV (max 1 MB, max 30 seconds)

#### 8.6.3 Looping Sound

[↑ Top](#top)

```xml
<audio src="ms-winsoundevent:Notification.Looping.Alarm" loop="true"/>
```

---

## 9. Security Model

[↑ Top](#top)

### 9.1 Application ID Registration

[↑ Top](#top)

When you call `CreateToastNotifier($APP_ID)`, Windows registers this App ID in:

```
HKEY_CURRENT_USER\Software\Classes\AppUserModelId\[APP_ID]
```

**Permissions Required**: None (user-level registry access)

**Security Implications**:
- Any process running as the current user can send notifications under any App ID
- App IDs are **not authenticated** - two different apps can use the same App ID
- No admin rights required

### 9.2 Notification Content Security

[↑ Top](#top)

**User Trust Model**:
- Notifications display content from the calling application
- Windows does **not validate or sanitize** notification text
- Applications are trusted to show accurate, non-malicious content

**Risks**:
- **Spoofing**: Malicious app could impersonate another app's App ID
- **Phishing**: Notification could display misleading text/links
- **Spam**: No built-in rate limiting (app must implement)

**Mitigations**:
- Use unique, namespace-qualified App IDs: `YourCompany.YourApp.Module`
- Validate all user input before showing in notifications
- Include app branding (logo) to prevent confusion
- Don't include sensitive data in notification text (use Action Center detail view)

### 9.3 Privacy Considerations

[↑ Top](#top)

**What Windows Logs**:
- Notification content (stored in Action Center database)
- Timestamp of notification
- App ID that sent notification

**Location**: 
```
%LOCALAPPDATA%\Microsoft\Windows\Notifications\wpndatabase.db
```

**Retention**: 
- Up to 20 notifications per app
- Cleared when user clears Action Center
- Can be cleared by IT admin via Group Policy

**Cross-Device Sync**:
- If user enables "Get notifications from apps and other senders" + "Sync across devices"
- Notifications sync to Microsoft account
- Stored on Microsoft servers temporarily
- **Don't send PII, credentials, or sensitive data in notifications**

### 9.4 Code Execution Security

[↑ Top](#top)

**Activation Arguments**:
When user clicks a toast button, the `arguments` value is passed back to your app:

```xml
<action content="Open Document" arguments="file://C:\Docs\report.pdf"/>
```

**Security Risk**: Command injection if arguments are not validated

**Safe Pattern**:
```powershell
function Handle-NotificationActivation {
    param([string]$Arguments)
    
    # Validate argument format
    if ($Arguments -match '^action:(\w+):(\d+)$') {
        $action = $Matches[1]
        $id = $Matches[2]
        
        switch ($action) {
            "reply" { Send-Reply -MessageId $id }
            "delete" { Remove-Item -ItemId $id }
        }
    }
    else {
        Write-Warning "Invalid activation arguments: $Arguments"
    }
}
```

**Never use**:
```powershell
# DANGEROUS - allows arbitrary code execution
Invoke-Expression $Arguments
```

### 9.5 Sandboxing

[↑ Top](#top)

- Notifications run in the Windows Notification Platform service
- Limited file system access (can load local images)
- No network access from notification XML itself
- Interactive elements (buttons, inputs) require activation contract

---

## 10. Multi-Machine Considerations

[↑ Top](#top)

### 10.1 Cross-Device Notifications

[↑ Top](#top)

**Question**: If you show a notification on Machine A, does it appear on Machine B?

**Answer**: **Depends on Windows configuration**

#### 10.1.1 Requirements for Sync

[↑ Top](#top)

1. User signed in with Microsoft Account (not local account)
2. Settings → System → Notifications → "Get notifications from apps and other senders" = ON
3. Settings → System → Notifications → "Show me notifications from all of my devices" = ON
4. Same app installed on both machines with same App ID

#### 10.1.2 What Syncs

[↑ Top](#top)

- Toast notification content (title, message)
- Notification timestamp
- App ID
- Tag and Group

#### 10.1.3 What Doesn't Sync

[↑ Top](#top)

- Images (local file paths don't work across machines)
- Progress bars (state not synced)
- Custom sounds (file paths)
- Interactive button state (not synced)

### 10.2 Best Practices for Multi-Machine Scenarios

[↑ Top](#top)

#### 10.2.1 Use HTTP/HTTPS URLs for Images

[↑ Top](#top)

Instead of:
```xml
<image src="C:\Icons\calendar.png"/>
```

Use:
```xml
<image src="https://yourcdn.com/icons/calendar.png"/>
```

#### 10.2.2 Include Machine Context

[↑ Top](#top)

```powershell
$machineName = $env:COMPUTERNAME
Show-WindowsNotification `
    -Title "Document Saved" `
    -Message "Report.docx saved on $machineName"
```

#### 10.2.3 Tag Notifications with Machine ID

[↑ Top](#top)

```powershell
$tag = "email-001-$env:COMPUTERNAME"
Show-WindowsNotification -Title "New Email" -Message "From Alice" -Tag $tag
```

This prevents conflicts if same notification sent from different machines.

#### 10.2.4 Server-Side Notification Deduplication

[↑ Top](#top)

If using a centralized system:

```powershell
# Server tracks which machine showed notification
$notificationLog = @{
    Id = "email-001"
    ShownOnMachines = @("MACHINE-A", "MACHINE-B")
    Content = "New Email from Alice"
}

# Client queries server before showing
function Show-NotificationIfNotSeen {
    param([string]$NotificationId)
    
    $machine = $env:COMPUTERNAME
    $status = Get-NotificationStatus -Id $NotificationId -Machine $machine
    
    if (-not $status.ShownOnThisMachine) {
        Show-WindowsNotification -Title $status.Title -Message $status.Message
        Update-NotificationStatus -Id $NotificationId -Machine $machine -Shown $true
    }
}
```

### 10.3 Notification Action Center Sync Behavior

[↑ Top](#top)

**Important**: Action Center sync is **best-effort**:
- Syncs every 15-30 minutes (not real-time)
- Requires internet connection
- May be delayed or dropped if network unreliable
- User can disable sync anytime

**Don't rely on sync for critical notifications**. Use alternative delivery:
- Email notifications
- Server-side tracking
- Database logging

---

## 11. PowerShell Implementation Guide

[↑ Top](#top)

### 11.1 Minimal Working Example

[↑ Top](#top)

```powershell
function Show-SimpleToast {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message
    )
    
    # Load WinRT types
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    
    # Create XML
    $template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$Title</text>
            <text id="2">$Message</text>
        </binding>
    </visual>
</toast>
"@
    
    # Show notification
    $xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $xml.LoadXml($template)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("MyApp").Show($toast)
}

# Usage
Show-SimpleToast -Title "Test" -Message "Hello World"
```

### 11.2 Production-Ready Implementation

[↑ Top](#top)

```powershell
function Show-WindowsNotification {
    <#
    .SYNOPSIS
        Shows a Windows toast notification with advanced options.
    
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
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$AppId = "CreateEmailEventAndTeamsChat",
        
        [string]$Tag = $null,
        
        [string]$Group = $null,
        
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ImagePath = $null,
        
        [ValidateSet('Default', 'Mail', 'Reminder', 'SMS', 'IM', 'Silent')]
        [string]$Sound = 'Default',
        
        [ValidateSet('Short', 'Long', 'Default')]
        [string]$Duration = 'Default'
    )
    
    try {
        # Load WinRT types
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
        
        # Escape XML special characters
        $TitleEscaped = [System.Security.SecurityElement]::Escape($Title)
        $MessageEscaped = [System.Security.SecurityElement]::Escape($Message)
        
        # Build toast duration attribute
        $toastDuration = if ($Duration -ne 'Default') { " duration=`"$($Duration.ToLower())`"" } else { "" }
        
        # Build image XML if provided
        $imageXml = ""
        if ($ImagePath) {
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
        
        # Build XML template
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
        
        # Create and show notification
        $xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
        $xml.LoadXml($template)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        
        # Set Tag and Group
        if ($Tag) { $toast.Tag = $Tag }
        if ($Group) { $toast.Group = $Group }
        
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
        
        Write-Verbose "Notification shown: Title='$Title', Tag='$Tag', Group='$Group'"
        return $true
    }
    catch {
        Write-Error "Failed to show notification: $($_.Exception.Message)"
        return $false
    }
}
```

### 11.3 Helper Functions

[↑ Top](#top)

```powershell
function Remove-WindowsNotification {
    param(
        [Parameter(Mandatory)][string]$Tag,
        [string]$Group = "",
        [string]$AppId = "CreateEmailEventAndTeamsChat"
    )
    
    $history = [Windows.UI.Notifications.ToastNotificationManager]::History
    $history.Remove($Tag, $Group, $AppId)
}

function Clear-AllWindowsNotifications {
    param([string]$AppId = "CreateEmailEventAndTeamsChat")
    
    $history = [Windows.UI.Notifications.ToastNotificationManager]::History
    $history.Clear($AppId)
}

function Get-WindowsNotificationHistory {
    param([string]$AppId = "CreateEmailEventAndTeamsChat")
    
    $history = [Windows.UI.Notifications.ToastNotificationManager]::History
    $notifications = $history.GetHistory($AppId)
    
    foreach ($notification in $notifications) {
        [PSCustomObject]@{
            Tag = $notification.Tag
            Group = $notification.Group
            ExpirationTime = $notification.ExpirationTime
            Content = $notification.Content.GetXml()
        }
    }
}
```

---

## 12. Advanced Features

[↑ Top](#top)

### 12.1 Scheduled Notifications

[↑ Top](#top)

Deliver notification at future time:

```powershell
function Schedule-WindowsNotification {
    param(
        [string]$Title,
        [string]$Message,
        [datetime]$DeliveryTime,
        [string]$AppId = "CreateEmailEventAndTeamsChat"
    )
    
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.UI.Notifications.ScheduledToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    
    $template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$Title</text>
            <text id="2">$Message</text>
        </binding>
    </visual>
</toast>
"@
    
    $xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $xml.LoadXml($template)
    
    $scheduledToast = [Windows.UI.Notifications.ScheduledToastNotification]::new($xml, $DeliveryTime)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).AddToSchedule($scheduledToast)
}

# Schedule notification for 30 minutes from now
Schedule-WindowsNotification -Title "Meeting Reminder" -Message "Team sync in 5 minutes" -DeliveryTime (Get-Date).AddMinutes(30)
```

### 12.2 Notification Update (Progress Bar)

[↑ Top](#top)

```powershell
function Show-ProgressNotification {
    param(
        [string]$Title,
        [double]$Progress,  # 0.0 to 1.0
        [string]$Status,
        [string]$Tag = "progress",
        [string]$AppId = "CreateEmailEventAndTeamsChat"
    )
    
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.UI.Notifications.NotificationData, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    
    $progressValue = [Math]::Round($Progress, 2)
    $progressPercent = [Math]::Round($Progress * 100)
    
    $template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <progress value="$progressValue" valueStringOverride="$progressPercent%" status="$Status" />
        </binding>
    </visual>
</toast>
"@
    
    # Show initial notification
    $xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $xml.LoadXml($template)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    $toast.Tag = $Tag
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
}

# Usage: Show progress bar
Show-ProgressNotification -Title "Downloading File" -Progress 0.0 -Status "Starting..."
Start-Sleep -Seconds 2
Show-ProgressNotification -Title "Downloading File" -Progress 0.5 -Status "50% complete"
Start-Sleep -Seconds 2
Show-ProgressNotification -Title "Downloading File" -Progress 1.0 -Status "Complete!"
```

### 12.3 Notification with Buttons (Advanced)

[↑ Top](#top)

```powershell
function Show-InteractiveNotification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$AppId = "CreateEmailEventAndTeamsChat"
    )
    
    $template = @"
<toast launch="app-action">
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
    <actions>
        <action content="View" arguments="action=view" />
        <action content="Dismiss" arguments="action=dismiss" />
    </actions>
</toast>
"@
    
    $xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $xml.LoadXml($template)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    
    # Note: Handling button clicks requires COM activation or protocol handler
    # See: https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/send-local-toast
    
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
}
```

**Note**: Interactive notifications require additional setup:
- Register COM server for activation
- Or use protocol activation (e.g., `myapp://action=view`)

---

## 13. Summary and Feature Matrix

[↑ Top](#top)

### Summary Table

| Feature | Capability | PowerShell Support |
|---------|------------|-------------------|
| Basic toast (title + message) | ✅ Yes | ✅ Full support |
| Images (logo, hero, inline) | ✅ Yes | ✅ Full support |
| Custom sounds | ✅ Yes | ✅ Full support |
| Silent notifications | ✅ Yes | ✅ Full support |
| Duration control (short/long) | ✅ Yes | ✅ Full support |
| Tag and Group | ✅ Yes | ✅ Full support |
| Replace/Remove notifications | ✅ Yes | ✅ Full support |
| Progress bar | ✅ Yes | ✅ Full support |
| Scheduled delivery | ✅ Yes | ✅ Full support |
| Action Center history | ✅ Yes | ✅ Full support |
| Interactive buttons | ⚠️ Limited | ⚠️ Requires COM/protocol handler |
| Text input | ⚠️ Limited | ⚠️ Requires COM/protocol handler |
| Button click handling | ⚠️ Limited | ⚠️ Requires COM/protocol handler |
| Cross-device sync | ⚠️ User-controlled | N/A (Windows feature) |
| Security/Authentication | ❌ No | N/A (not supported by Windows) |

### References

- [Windows Toast Notifications Official Docs](https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/adaptive-interactive-toasts)
- [Toast Content Schema](https://learn.microsoft.com/en-us/uwp/schemas/tiles/toastschema/schema-root)
- [Windows.UI.Notifications Namespace](https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications)
- [Notification Activation (Interactive)](https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/send-local-toast)

---

## 14. Glossary

[↑ Top](#top)

**Action Center**: Windows notification history panel accessible via Win+A keyboard shortcut. Stores up to 20 notifications per application.

**Adaptive Template**: Modern toast notification layout (ToastGeneric) that supports rich content like images, progress bars, and buttons.

**App ID (Application ID)**: Unique identifier string used to register and group notifications from the same application.

**App Logo Override**: Small circular icon image that replaces the default app icon in a toast notification.

**Audio Element**: XML tag in toast template that specifies notification sound (system sound or custom file).

**BurntToast**: Third-party PowerShell module for Windows notifications (not used in this implementation).

**COM (Component Object Model)**: Microsoft's binary interface standard for inter-process communication.

**ContentType = WindowsRuntime**: PowerShell syntax for loading WinRT (Windows Runtime) assemblies into the session.

**Cross-Device Sync**: Optional Windows feature that syncs notifications across devices signed into the same Microsoft Account.

**Duration**: How long a toast notification remains visible on screen (Short=5s, Default=7s, Long=25s).

**Expiration Time**: When a notification should be removed from Action Center (default 5 days, max 7 days).

**Focus Assist**: Windows Do Not Disturb mode that suppresses notifications based on rules (Off, Priority only, Alarms only).

**GAL (Global Address List)**: The organization-wide Outlook address book (not directly related to notifications).

**Group**: Category identifier for related notifications enabling threading in Action Center.

**Header**: XML element that provides a title for grouped notifications in Action Center.

**Hero Image**: Large banner image displayed at the top of a toast notification.

**Inline Image**: Medium-sized image displayed within the notification body content.

**Interactive Notification**: Toast with buttons or input fields that users can click or type into.

**MAPI (Messaging Application Programming Interface)**: Microsoft's email client protocol (not used for toast notifications).

**Microsoft Account**: User account format (email@domain.com) that enables cross-device sync.

**NDR (Non-Delivery Report)**: Email bounce-back notification (not related to toast notifications).

**Notification Data**: Object containing key-value pairs for updating dynamic notification content (e.g., progress bars).

**Notification History**: Collection of notifications stored in Action Center, queryable via ToastNotificationManager.History.

**Per-App Settings**: Windows notification settings specific to one application (sound, banner, Action Center visibility).

**Priority Only**: Focus Assist mode that only shows notifications from starred apps or contacts.

**Progress Bar**: Visual indicator in toast notification showing completion percentage with status text.

**Protocol Activation**: Method for handling interactive button clicks using custom URL schemes (e.g., myapp://action).

**PWA (Progressive Web App)**: Web application that runs like a native app (New Outlook is a PWA).

**Registry**: Windows hierarchical database storing system and app settings, including notification App IDs.

**Scheduled Notification**: Toast notification set to appear at a future time rather than immediately.

**Silent Notification**: Toast that appears in Action Center without displaying a banner or playing sound.

**SQLite Database**: File-based database format used by Windows to store Action Center notifications (wpndatabase.db).

**System Sound**: Built-in Windows notification sound (Default, Mail, Reminder, SMS, IM, Alarm, Call).

**Tag**: Unique identifier for a notification within a Group, used for replacement or removal.

**Toast**: Pop-up notification that appears in the lower-right corner of the screen.

**Toast Notification Manager**: WinRT class that creates, shows, schedules, and manages toast notifications.

**ToastGeneric**: Modern adaptive template type supporting rich content and layouts.

**ToastText02**: Legacy template type with two text lines (title and message).

**WinRT (Windows Runtime)**: Microsoft's API for Windows Store apps and modern Windows features like notifications.

**wpndatabase.db**: SQLite database file storing Action Center notification history.

**XAML (Extensible Application Markup Language)**: XML-based UI definition language for Windows applications.

**XML Template**: String defining notification content structure following the Toast Content Schema.

**[Windows.Data.Xml.Dom.XmlDocument]**: WinRT class for creating and manipulating XML documents.

**[Windows.UI.Notifications.ToastNotification]**: WinRT class representing a single toast notification.

**[Windows.UI.Notifications.ToastNotificationManager]**: WinRT class for showing and managing toast notifications.

---

**End of Document**

[↑ Top](#top)

**Document Version**: 2.0  
**Last Updated**: 2026-09-19  
**For**: CreateEmailEventAndTeamsChat.Prototype.ps1 Notifications Feature
