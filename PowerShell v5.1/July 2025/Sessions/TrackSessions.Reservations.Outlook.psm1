# TrackSessions.Reservations.Outlook.psm1
# Phase 3: Outlook Integration
# Creates calendar events and sends email notifications for reservations

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module-level variables
$script:OutlookApp = $null
$script:LastOutlookCheck = $null
$script:OutlookAvailable = $false

<#
.SYNOPSIS
    Initializes Outlook COM object with error handling.
.DESCRIPTION
    Attempts to create Outlook.Application COM object.
    Gracefully handles unavailable Outlook installations.
.PARAMETER Force
    If $true, reinitializes even if already initialized
.EXAMPLE
    Initialize-OutlookConnection
#>
function Initialize-OutlookConnection {
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Force = $false
    )

    # Prevent repeated initialization attempts within short timeframe
    if ($script:LastOutlookCheck -and (-not $Force)) {
        $timeSinceLastCheck = [datetime]::UtcNow - $script:LastOutlookCheck
        if ($timeSinceLastCheck.TotalSeconds -lt 60) {
            return $script:OutlookAvailable
        }
    }

    $script:LastOutlookCheck = [datetime]::UtcNow

    if ($script:OutlookApp) {
        $script:OutlookAvailable = $true
        return $true
    }

    try {
        $script:OutlookApp = New-Object -ComObject Outlook.Application
        $script:OutlookAvailable = $true
        return $true
    }
    catch {
        Write-Warning "Outlook not available: $_"
        $script:OutlookAvailable = $false
        $script:OutlookApp = $null
        return $false
    }
}

<#
.SYNOPSIS
    Gets the Outlook calendar folder for a user.
.DESCRIPTION
    Retrieves the calendar folder from Outlook.
.PARAMETER CalendarName
    Calendar folder name (default: "Calendar")
.EXAMPLE
    $calendar = Get-OutlookCalendar -CalendarName "Calendar"
#>
function Get-OutlookCalendar {
    param(
        [Parameter(Mandatory = $false)]
        [string]$CalendarName = "Calendar"
    )

    if (-not (Initialize-OutlookConnection)) {
        throw "Outlook is not available"
    }

    try {
        $namespace = $script:OutlookApp.GetNamespace("MAPI")
        $mailbox = $namespace.Folders.Item(1)  # Default mailbox
        $calendar = $null

        # Search for calendar folder
        foreach ($folder in $mailbox.Folders) {
            if ($folder.Name -eq $CalendarName) {
                $calendar = $folder
                break
            }
        }

        if (-not $calendar) {
            throw "Calendar folder '$CalendarName' not found"
        }

        return $calendar
    }
    catch {
        throw "Failed to access Outlook calendar: $_"
    }
}

<#
.SYNOPSIS
    Creates an Outlook calendar event for a reservation.
.DESCRIPTION
    Adds a new event to Outlook calendar with reservation details.
    Handles conflicts and unavailable Outlook gracefully.
.PARAMETER MachineName
    Computer name
.PARAMETER UserDisplayName
    User making the reservation
.PARAMETER ReservationDate
    Date in yyyy-MM-dd format
.PARAMETER StartTime
    Start time in HH:mm format
.PARAMETER EndTime
    End time in HH:mm format
.PARAMETER Comments
    Optional event comments
.PARAMETER CreatedByUser
    User creating the event (for tracking)
.EXAMPLE
    New-OutlookReservationEvent -MachineName 'PAWS01' -UserDisplayName 'Davis Lee' `
        -ReservationDate '2026-09-15' -StartTime '10:00' -EndTime '11:00' `
        -Comments 'Team meeting'
#>
function New-OutlookReservationEvent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MachineName,
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName,
        [Parameter(Mandatory = $true)]
        [string]$ReservationDate,
        [Parameter(Mandatory = $true)]
        [string]$StartTime,
        [Parameter(Mandatory = $true)]
        [string]$EndTime,
        [Parameter(Mandatory = $false)]
        [string]$Comments = '',
        [Parameter(Mandatory = $false)]
        [string]$CreatedByUser = ''
    )

    # Check if Outlook is available
    if (-not (Initialize-OutlookConnection)) {
        Write-Warning "Outlook event not created: Outlook is unavailable. Reservation created but calendar event skipped."
        return @{
            Success = $false
            Message = "Outlook unavailable"
            EventId = $null
        }
    }

    try {
        $calendar = Get-OutlookCalendar

        # Parse date and time
        $eventDate = [datetime]::ParseExact($ReservationDate, 'yyyy-MM-dd', $null)
        $startTimeObj = [datetime]::ParseExact($StartTime, 'HH:mm', $null)
        $endTimeObj = [datetime]::ParseExact($EndTime, 'HH:mm', $null)

        $eventStartTime = $eventDate.AddHours($startTimeObj.Hour).AddMinutes($startTimeObj.Minute)
        $eventEndTime = $eventDate.AddHours($endTimeObj.Hour).AddMinutes($endTimeObj.Minute)

        # Create appointment
        $appointment = $calendar.Items.Add(1)  # 1 = olAppointmentItem
        $appointment.Subject = "[RESERVED] $MachineName - $UserDisplayName"
        $appointment.Start = $eventStartTime
        $appointment.End = $eventEndTime
        $appointment.AllDayEvent = $false
        $appointment.BusyStatus = 2  # olBusy
        $appointment.ReminderSet = $true
        $appointment.ReminderMinutesBeforeStart = 15

        # Build body with details
        $bodyParts = @(
            "Machine Reservation",
            "",
            "Computer: $MachineName",
            "User: $UserDisplayName",
            "Date: $ReservationDate",
            "Time: $StartTime - $EndTime"
        )

        if ($Comments) {
            $bodyParts += ""
            $bodyParts += "Comments: $Comments"
        }

        if ($CreatedByUser) {
            $bodyParts += ""
            $bodyParts += "Created by: $CreatedByUser"
        }

        $appointment.Body = $bodyParts -join "`r`n"

        # Save appointment
        $appointment.Save()

        return @{
            Success = $true
            Message = "Event created successfully"
            EventId = $appointment.EntryID
            Subject = $appointment.Subject
            StartTime = $eventStartTime
            EndTime = $eventEndTime
        }
    }
    catch {
        Write-Warning "Failed to create Outlook event: $_"
        return @{
            Success = $false
            Message = "Event creation failed: $_"
            EventId = $null
        }
    }
}

<#
.SYNOPSIS
    Removes an Outlook calendar event for a cancelled reservation.
.DESCRIPTION
    Deletes event from Outlook when reservation is cancelled.
.PARAMETER EventId
    Outlook EntryID of the event
.EXAMPLE
    Remove-OutlookReservationEvent -EventId $eventId
#>
function Remove-OutlookReservationEvent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventId
    )

    if (-not (Initialize-OutlookConnection)) {
        Write-Warning "Cannot remove Outlook event: Outlook unavailable"
        return @{
            Success = $false
            Message = "Outlook unavailable"
        }
    }

    try {
        $namespace = $script:OutlookApp.GetNamespace("MAPI")
        $item = $namespace.GetItemFromID($EventId)
        
        if ($item) {
            $item.Delete()
            return @{
                Success = $true
                Message = "Event deleted successfully"
            }
        }
        else {
            return @{
                Success = $false
                Message = "Event not found"
            }
        }
    }
    catch {
        Write-Warning "Failed to delete Outlook event: $_"
        return @{
            Success = $false
            Message = "Deletion failed: $_"
        }
    }
}

<#
.SYNOPSIS
    Sends a reservation notification email.
.DESCRIPTION
    Creates and sends email notification about a new, updated, or cancelled reservation.
    Includes .ics attachment for calendar integration.
.PARAMETER ReservationData
    Reservation object with all details
.PARAMETER Recipients
    Array of email addresses to notify
.PARAMETER EventType
    'New', 'Updated', or 'Cancelled'
.PARAMETER SettingsPath
    Path to TrackSessions.Settings.json (for distribution list config)
.EXAMPLE
    Send-ReservationNotification -ReservationData $reservation -Recipients @('team@example.com') -EventType 'New' -SettingsPath 'C:\config\settings.json'
#>
function Send-ReservationNotification {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ReservationData,
        [Parameter(Mandatory = $true)]
        [string[]]$Recipients,
        [Parameter(Mandatory = $false)]
        [ValidateSet('New', 'Updated', 'Cancelled')]
        [string]$EventType = 'New',
        [Parameter(Mandatory = $false)]
        [string]$SettingsPath = ''
    )

    if (-not (Initialize-OutlookConnection)) {
        Write-Warning "Email notification not sent: Outlook unavailable"
        return @{
            Success = $false
            Message = "Outlook unavailable"
        }
    }

    # Validate recipients
    if (-not $Recipients -or $Recipients.Count -eq 0) {
        Write-Warning "No recipients specified for notification"
        return @{
            Success = $false
            Message = "No recipients"
        }
    }

    try {
        $namespace = $script:OutlookApp.GetNamespace("MAPI")
        $mailItem = $script:OutlookApp.CreateItem(0)  # 0 = olMailItem

        # Build email subject
        $actionText = switch ($EventType) {
            'New' { 'Reservation Created' }
            'Updated' { 'Reservation Updated' }
            'Cancelled' { 'Reservation Cancelled' }
            default { 'Reservation Notification' }
        }

        $mailItem.Subject = "[$actionText] $($ReservationData.MachineName) - $($ReservationData.UserDisplayName)"
        $mailItem.To = $Recipients -join '; '

        # Build email body with HTML formatting
        $statusColor = switch ($ReservationData.Status) {
            'Active' { '#107c10' }      # Green
            'Cancelled' { '#da3b01' }   # Red
            default { '#606e7a' }       # Gray
        }

        $htmlBody = @"
<html>
<head>
    <style>
        body { font-family: Segoe UI, sans-serif; color: #2e3a48; }
        .container { max-width: 600px; margin: 20px auto; border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; }
        .header { background-color: #0078d4; color: white; padding: 16px; border-radius: 6px 6px 0 0; margin: -20px -20px 20px -20px; }
        .header h2 { margin: 0; font-size: 18px; }
        .status-badge { display: inline-block; background-color: $statusColor; color: white; padding: 4px 8px; border-radius: 3px; font-size: 12px; font-weight: 600; margin-left: 10px; }
        .section { margin-bottom: 20px; }
        .section-title { font-weight: 600; color: #0078d4; margin-bottom: 8px; border-bottom: 2px solid #e0e0e0; padding-bottom: 4px; }
        .detail-row { display: flex; margin-bottom: 8px; }
        .detail-label { font-weight: 600; width: 120px; color: #606e7a; }
        .detail-value { flex: 1; }
        .time-highlight { background-color: #f3f2f1; padding: 12px; border-left: 4px solid #0078d4; border-radius: 4px; margin: 12px 0; }
        .footer { margin-top: 20px; padding-top: 12px; border-top: 1px solid #e0e0e0; font-size: 12px; color: #606e7a; text-align: center; }
        .footer p { margin: 4px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>Machine Reservation $actionText<span class="status-badge">$($ReservationData.Status)</span></h2>
        </div>

        <div class="section">
            <div class="section-title">Reservation Details</div>
            <div class="detail-row">
                <div class="detail-label">Machine:</div>
                <div class="detail-value">$($ReservationData.MachineName)</div>
            </div>
            <div class="detail-row">
                <div class="detail-label">User:</div>
                <div class="detail-value">$($ReservationData.UserDisplayName) ($($ReservationData.UserEmail))</div>
            </div>
            <div class="detail-row">
                <div class="detail-label">Date:</div>
                <div class="detail-value">$($ReservationData.ReservationDate)</div>
            </div>
        </div>

        <div class="time-highlight">
            <strong>Time Slot:</strong> $($ReservationData.StartTime) - $($ReservationData.EndTime)
        </div>

        $(if ($ReservationData.Comments) {
            @"
        <div class="section">
            <div class="section-title">Comments</div>
            <div style="background-color: #f3f2f1; padding: 12px; border-radius: 4px;">$($ReservationData.Comments)</div>
        </div>
"@
        })

        <div class="section">
            <div class="section-title">Metadata</div>
            <div class="detail-row">
                <div class="detail-label">Reservation ID:</div>
                <div class="detail-value" style="font-family: monospace; font-size: 12px;">$($ReservationData.ReservationId)</div>
            </div>
            <div class="detail-row">
                <div class="detail-label">Created:</div>
                <div class="detail-value">$($ReservationData.CreatedAtGmt)</div>
            </div>
            $(if ($ReservationData.Status -eq 'Cancelled') {
                @"
            <div class="detail-row">
                <div class="detail-label">Cancelled At:</div>
                <div class="detail-value">$($ReservationData.CancelledAtGmt)</div>
            </div>
            <div class="detail-row">
                <div class="detail-label">Cancelled By:</div>
                <div class="detail-value">$($ReservationData.CancelledByUserId)</div>
            </div>
            $(if ($ReservationData.CancellationReason) {
                @"
            <div class="detail-row">
                <div class="detail-label">Reason:</div>
                <div class="detail-value">$($ReservationData.CancellationReason)</div>
            </div>
"@
            })
"@
            })
        </div>

        <div class="footer">
            <p>This is an automated notification from TrackSessions Reservation System</p>
            <p>Do not reply to this email</p>
        </div>
    </div>
</body>
</html>
"@

        $mailItem.HTMLBody = $htmlBody

        # Create .ics calendar attachment if reservation is active
        if ($ReservationData.Status -eq 'Active') {
            $icsContent = ConvertTo-IcsCalendarEvent -ReservationData $ReservationData
            $tempIcsPath = [System.IO.Path]::GetTempFileName()
            $tempIcsPath = $tempIcsPath -replace '\..+$', '.ics'

            try {
                Set-Content -LiteralPath $tempIcsPath -Value $icsContent -Encoding UTF8
                $attachment = $mailItem.Attachments.Add($tempIcsPath, 3)  # 3 = olByValue
                $attachment.PropertyAccessor.SetProperty("http://schemas.microsoft.com/mapi/proptag/0x37D001E", "text/calendar")
            }
            finally {
                if (Test-Path -LiteralPath $tempIcsPath) {
                    Remove-Item -LiteralPath $tempIcsPath -Force -ErrorAction SilentlyContinue
                }
            }
        }

        # Send the email
        $mailItem.Send()

        return @{
            Success = $true
            Message = "Notification sent to $($Recipients.Count) recipient(s)"
            Recipients = $Recipients
        }
    }
    catch {
        Write-Warning "Failed to send email notification: $_"
        return @{
            Success = $false
            Message = "Email failed: $_"
        }
    }
}

<#
.SYNOPSIS
    Converts reservation to iCalendar (.ics) format.
.DESCRIPTION
    Generates RFC 5545 compliant .ics file content for calendar applications.
.PARAMETER ReservationData
    Reservation object
.EXAMPLE
    $ics = ConvertTo-IcsCalendarEvent -ReservationData $reservation
#>
function ConvertTo-IcsCalendarEvent {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ReservationData
    )

    # Parse date and time
    $eventDate = [datetime]::ParseExact($ReservationData.ReservationDate, 'yyyy-MM-dd', $null)
    $startTimeObj = [datetime]::ParseExact($ReservationData.StartTime, 'HH:mm', $null)
    $endTimeObj = [datetime]::ParseExact($ReservationData.EndTime, 'HH:mm', $null)

    $startDateTime = $eventDate.AddHours($startTimeObj.Hour).AddMinutes($startTimeObj.Minute)
    $endDateTime = $eventDate.AddHours($endTimeObj.Hour).AddMinutes($endTimeObj.Minute)

    # Format as UTC for iCalendar
    $dtStart = $startDateTime.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $dtEnd = $endDateTime.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $dtStamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')

    # Create UID (unique identifier)
    $uid = "$($ReservationData.ReservationId)@tracksessions.local"

    # Build ICS content
    $icsContent = @"
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//TrackSessions//Reservation System//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
BEGIN:VEVENT
UID:$uid
DTSTAMP:$dtStamp
DTSTART:$dtStart
DTEND:$dtEnd
SUMMARY:[RESERVED] $($ReservationData.MachineName) - $($ReservationData.UserDisplayName)
DESCRIPTION:Machine Reservation\nComputer: $($ReservationData.MachineName)\nUser: $($ReservationData.UserDisplayName)\nEmail: $($ReservationData.UserEmail)\nComments: $($ReservationData.Comments -replace "`r`n", '\n')
LOCATION:$($ReservationData.MachineName)
ORGANIZER;CN=$($ReservationData.UserDisplayName):mailto:$($ReservationData.UserEmail)
STATUS:CONFIRMED
SEQUENCE:0
TRANSP:OPAQUE
END:VEVENT
END:VCALENDAR
"@

    return $icsContent
}

<#
.SYNOPSIS
    Gets notification recipients from settings.
.DESCRIPTION
    Loads email distribution list from Settings.json for notifications.
.PARAMETER SettingsPath
    Path to TrackSessions.Settings.json
.EXAMPLE
    $recipients = Get-NotificationRecipients -SettingsPath 'C:\config\settings.json'
#>
function Get-NotificationRecipients {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsPath
    )

    if (-not (Test-Path -LiteralPath $SettingsPath)) {
        return @()
    }

    try {
        $settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
        
        if ($settings.Outlook.EmailDistributionList -and $settings.Outlook.EmailDistributionList.Count -gt 0) {
            return @($settings.Outlook.EmailDistributionList)
        }
    }
    catch {
        Write-Warning "Failed to load notification recipients: $_"
    }

    return @()
}

<#
.SYNOPSIS
    Creates a complete reservation with Outlook integration.
.DESCRIPTION
    Wraps New-Reservation from Phase 2 and adds Outlook calendar event and notifications.
.PARAMETER MachineName
    Computer name
.PARAMETER UserId
    SEID of user
.PARAMETER UserDisplayName
    Display name
.PARAMETER UserEmail
    Email address
.PARAMETER ReservationDate
    Date in yyyy-MM-dd
.PARAMETER StartTime
    Start in HH:mm
.PARAMETER EndTime
    End in HH:mm
.PARAMETER Comments
    Optional comments
.PARAMETER ReservationPath
    UNC path to reservations
.PARAMETER SettingsPath
    Path to Settings.json
.PARAMETER UsersPath
    Path to Users.json
.PARAMETER SendNotifications
    If $true, send email notifications
.EXAMPLE
    New-ReservationWithOutlook -MachineName 'PAWS01' -UserId 'YMJNB' `
        -UserDisplayName 'Davis Lee' -UserEmail 'davis@example.com' `
        -ReservationDate '2026-09-15' -StartTime '10:00' -EndTime '11:00' `
        -ReservationPath '\\share\res' -SettingsPath 'C:\cfg\settings.json' `
        -UsersPath 'C:\cfg\users.json' -SendNotifications $true
#>
function New-ReservationWithOutlook {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MachineName,
        [Parameter(Mandatory = $true)]
        [string]$UserId,
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName,
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        [Parameter(Mandatory = $true)]
        [string]$ReservationDate,
        [Parameter(Mandatory = $true)]
        [string]$StartTime,
        [Parameter(Mandatory = $true)]
        [string]$EndTime,
        [Parameter(Mandatory = $false)]
        [string]$Comments = '',
        [Parameter(Mandatory = $true)]
        [string]$ReservationPath,
        [Parameter(Mandatory = $true)]
        [string]$SettingsPath,
        [Parameter(Mandatory = $true)]
        [string]$UsersPath,
        [Parameter(Mandatory = $false)]
        [bool]$SendNotifications = $true
    )

    # Import Phase 2 module functions
    if (-not (Get-Command New-Reservation -ErrorAction SilentlyContinue)) {
        throw "TrackSessions.Reservations module not loaded. Import it first with: Import-Module ./TrackSessions.Reservations.psm1"
    }

    # Create the reservation
    $reservation = New-Reservation -MachineName $MachineName -UserId $UserId `
        -UserDisplayName $UserDisplayName -UserEmail $UserEmail `
        -ReservationDate $ReservationDate -StartTime $StartTime -EndTime $EndTime `
        -Comments $Comments -ReservationPath $ReservationPath `
        -SettingsPath $SettingsPath -UsersPath $UsersPath

    if (-not $reservation) {
        throw "Failed to create reservation"
    }

    # Load the full reservation data
    $jsonPath = Join-Path $ReservationPath $reservation.JsonFile
    $reservationData = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json

    # Create Outlook event
    $outlookResult = New-OutlookReservationEvent -MachineName $MachineName `
        -UserDisplayName $UserDisplayName -ReservationDate $ReservationDate `
        -StartTime $StartTime -EndTime $EndTime -Comments $Comments `
        -CreatedByUser $env:USERNAME

    # Send notifications
    $emailResult = $null
    if ($SendNotifications) {
        $recipients = Get-NotificationRecipients -SettingsPath $SettingsPath
        if ($recipients.Count -gt 0) {
            $emailResult = Send-ReservationNotification -ReservationData $reservationData `
                -Recipients $recipients -EventType 'New' -SettingsPath $SettingsPath
        }
    }

    return @{
        Reservation = $reservation
        OutlookEvent = $outlookResult
        EmailNotification = $emailResult
        Success = $reservation.ReservationId -ne $null
    }
}

<#
.SYNOPSIS
    Closes Outlook connection and releases COM object.
.DESCRIPTION
    Cleans up Outlook COM object to prevent resource leaks.
.EXAMPLE
    Close-OutlookConnection
#>
function Close-OutlookConnection {
    if ($script:OutlookApp) {
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:OutlookApp) | Out-Null
            $script:OutlookApp = $null
            $script:OutlookAvailable = $false
        }
        catch {
            Write-Warning "Error closing Outlook connection: $_"
        }
    }
}

# Register cleanup on module unload
$ExecutionContext.SessionState.Module.OnRemove = {
    Close-OutlookConnection
}

Export-ModuleMember -Function @(
    'Initialize-OutlookConnection',
    'Get-OutlookCalendar',
    'New-OutlookReservationEvent',
    'Remove-OutlookReservationEvent',
    'Send-ReservationNotification',
    'ConvertTo-IcsCalendarEvent',
    'Get-NotificationRecipients',
    'New-ReservationWithOutlook',
    'Close-OutlookConnection'
)
