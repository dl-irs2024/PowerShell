# TrackSessions.EmailEventTeams.psm1
# Module for sending Email, Calendar Events, and Teams Chat notifications
# Extracted from CreateEmailEventAndTeamsChat.Prototype.ps1
# Created: September 20, 2026

Set-StrictMode -Version Latest

function New-OutlookEmail {
    <#
    .SYNOPSIS
        Creates a new Outlook email draft.

    .DESCRIPTION
        Creates and displays a new email in Outlook using COM automation.
        The email is displayed for review and is not automatically sent.

    .PARAMETER To
        Primary recipients (semicolon separated)

    .PARAMETER CC
        CC recipients (semicolon separated)

    .PARAMETER BCC
        BCC recipients (semicolon separated)

    .PARAMETER Subject
        Email subject line

    .PARAMETER Body
        Email body text

    .EXAMPLE
        New-OutlookEmail -To "user@domain.com" -Subject "Test" -Body "Hello"
    #>

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

        # Don't release COM objects immediately - Outlook needs them to keep the window open
        # The objects will be cleaned up when PowerShell exits

        return @{ Success = $true; Message = 'Email created successfully' }
    }
    catch {
        return @{ Success = $false; Message = "Error creating email: $($_.Exception.Message)" }
    }
}

function New-OutlookCalendarEvent {
    <#
    .SYNOPSIS
        Creates a new Outlook calendar event.

    .DESCRIPTION
        Creates and displays a new calendar appointment/meeting in Outlook using COM automation.
        The event is displayed for review and is not automatically sent.

    .PARAMETER StartDateTime
        Event start date and time

    .PARAMETER DurationMinutes
        Event duration in minutes

    .PARAMETER Subject
        Event subject/title

    .PARAMETER Body
        Event body/agenda text

    .PARAMETER Location
        Event location or Teams link

    .PARAMETER RequiredAttendees
        Required attendees (semicolon separated)

    .PARAMETER OptionalAttendees
        Optional attendees (semicolon separated)

    .PARAMETER ReminderSet
        Whether to set a reminder

    .PARAMETER ReminderMinutesBeforeStart
        Minutes before event to show reminder

    .EXAMPLE
        $start = (Get-Date).AddHours(2)
        New-OutlookCalendarEvent -StartDateTime $start -DurationMinutes 60 -Subject "Team Meeting"
    #>

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

        # Don't release COM objects immediately - Outlook needs them to keep the window open
        # The objects will be cleaned up when PowerShell exits

        return @{ Success = $true; Message = 'Calendar event created successfully' }
    }
    catch {
        return @{ Success = $false; Message = "Error creating event: $($_.Exception.Message)" }
    }
}

function Open-TeamsChat {
    <#
    .SYNOPSIS
        Opens a Microsoft Teams chat.

    .DESCRIPTION
        Opens a Teams chat window using either a user email address or a direct Teams URL.
        Teams must be installed on the system.

    .PARAMETER UserEmail
        Email address of user to open 1:1 chat with

    .PARAMETER Message
        Optional pre-filled message text (email mode only)

    .PARAMETER TeamsUrl
        Direct Teams URL for channel or group chat

    .EXAMPLE
        Open-TeamsChat -UserEmail "user@domain.com" -Message "Hello"

    .EXAMPLE
        Open-TeamsChat -TeamsUrl "https://teams.microsoft.com/l/chat/..."
    #>

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

# Export module functions
Export-ModuleMember -Function New-OutlookEmail, New-OutlookCalendarEvent, Open-TeamsChat
