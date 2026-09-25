# TrackSessions.Reservations.Recurring.psm1
# Recurring Reservation Management Module (Phase 7)
# Extends Phase 2 CRUD with recurrence patterns, exception handling, and bulk operations

Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Defines recurrence patterns for reservations.

.DESCRIPTION
    Contains recurrence frequency options: None (one-time), Daily, Weekly, Monthly.
    Used by New-RecurringReservation and UI dialogs.

.OUTPUTS
    [PSCustomObject] with RecurrencePattern enum values
#>
function Get-RecurrencePatterns {
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        None = 'None'
        Daily = 'Daily'
        Weekly = 'Weekly'
        Monthly = 'Monthly'
    }
}

<#
.SYNOPSIS
    Validates recurrence settings.

.DESCRIPTION
    Ensures:
    - RecurrencePattern is valid (None, Daily, Weekly, Monthly)
    - EndDate is after StartDate (if provided)
    - MaxOccurrences > 0 (if provided)
    - For Weekly: DayOfWeek is valid (Sunday-Saturday)
    - For Monthly: DayOfMonth is 1-31

.PARAMETER RecurrencePattern
    Pattern type: None, Daily, Weekly, Monthly

.PARAMETER StartDate
    First occurrence date (yyyy-MM-dd format)

.PARAMETER EndDate
    Final occurrence date (yyyy-MM-dd format, optional)

.PARAMETER MaxOccurrences
    Maximum number of occurrences (optional, overrides EndDate if both provided)

.PARAMETER DayOfWeek
    For Weekly patterns: Day of week (Sunday-Saturday)

.PARAMETER DayOfMonth
    For Monthly patterns: Day of month (1-31)

.OUTPUTS
    [PSCustomObject] @{ Valid=$true; Message=''; Errors=@() }
    [PSCustomObject] @{ Valid=$false; Message='...'; Errors=@(...) }
#>
function Test-RecurrenceSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RecurrencePattern,
        [Parameter(Mandatory = $true)][string]$StartDate,
        [string]$EndDate,
        [int]$MaxOccurrences,
        [string]$DayOfWeek,
        [int]$DayOfMonth
    )

    $errors = @()
    $patterns = Get-RecurrencePatterns

    # Validate pattern
    if ($RecurrencePattern -notin @($patterns.None, $patterns.Daily, $patterns.Weekly, $patterns.Monthly)) {
        $errors += "Invalid recurrence pattern: $RecurrencePattern"
    }

    # Validate date format
    try {
        [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null) | Out-Null
    }
    catch {
        $errors += "StartDate must be yyyy-MM-dd format, got: $StartDate"
    }

    # Validate EndDate
    if ($EndDate) {
        try {
            $endDt = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
            $startDt = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
            if ($endDt -le $startDt) {
                $errors += "EndDate must be after StartDate"
            }
        }
        catch {
            $errors += "EndDate must be yyyy-MM-dd format, got: $EndDate"
        }
    }

    # Validate MaxOccurrences
    if ($MaxOccurrences -gt 0 -and $MaxOccurrences -lt 1) {
        $errors += "MaxOccurrences must be > 0"
    }

    # Weekly-specific validation
    if ($RecurrencePattern -eq $patterns.Weekly) {
        if (-not $DayOfWeek) {
            $errors += "Weekly recurrence requires DayOfWeek"
        }
        elseif ($DayOfWeek -notin @('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')) {
            $errors += "Invalid DayOfWeek: $DayOfWeek"
        }
    }

    # Monthly-specific validation
    if ($RecurrencePattern -eq $patterns.Monthly) {
        if ($DayOfMonth -lt 1 -or $DayOfMonth -gt 31) {
            $errors += "DayOfMonth must be 1-31, got: $DayOfMonth"
        }
    }

    if ($errors.Count -gt 0) {
        return @{
            Valid = $false
            Message = "Recurrence validation failed: $($errors[0])"
            Errors = $errors
        }
    }

    return @{
        Valid = $true
        Message = 'Recurrence settings valid'
        Errors = @()
    }
}

<#
.SYNOPSIS
    Generates occurrence dates for a recurring reservation.

.DESCRIPTION
    Based on pattern and date range, returns array of [DateTime] objects for each occurrence.
    Respects MaxOccurrences limit and EndDate boundary.

.PARAMETER RecurrencePattern
    None (single), Daily, Weekly, Monthly

.PARAMETER StartDate
    First occurrence (yyyy-MM-dd)

.PARAMETER EndDate
    Last possible occurrence (yyyy-MM-dd, optional)

.PARAMETER MaxOccurrences
    Maximum count (optional, default: no limit)

.PARAMETER DayOfWeek
    For Weekly: Sunday-Saturday

.PARAMETER DayOfMonth
    For Monthly: 1-31

.OUTPUTS
    [DateTime[]] array of occurrence dates
#>
function Get-RecurrenceOccurrences {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RecurrencePattern,
        [Parameter(Mandatory = $true)][string]$StartDate,
        [string]$EndDate,
        [int]$MaxOccurrences,
        [string]$DayOfWeek,
        [int]$DayOfMonth
    )

    $patterns = Get-RecurrencePatterns
    $startDt = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
    $endDt = if ($EndDate) { [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null) } else { $null }
    $occurrences = @()

    if ($RecurrencePattern -eq $patterns.None) {
        return @($startDt)
    }

    $current = $startDt
    $count = 0

    switch ($RecurrencePattern) {
        $patterns.Daily {
            while (($null -eq $endDt -or $current -le $endDt) -and ($MaxOccurrences -eq 0 -or $count -lt $MaxOccurrences)) {
                $occurrences += $current
                $current = $current.AddDays(1)
                $count++
            }
        }

        $patterns.Weekly {
            $targetDayOfWeek = [DayOfWeek]::Parse([type]'System.DayOfWeek', $DayOfWeek)
            # Advance to first matching day
            while ($current.DayOfWeek -ne $targetDayOfWeek) {
                $current = $current.AddDays(1)
            }
            while (($null -eq $endDt -or $current -le $endDt) -and ($MaxOccurrences -eq 0 -or $count -lt $MaxOccurrences)) {
                $occurrences += $current
                $current = $current.AddDays(7)
                $count++
            }
        }

        $patterns.Monthly {
            while (($null -eq $endDt -or $current -le $endDt) -and ($MaxOccurrences -eq 0 -or $count -lt $MaxOccurrences)) {
                # Check if target day exists in month (e.g., Feb 31 doesn't exist)
                try {
                    $occurrence = New-Object DateTime $current.Year, $current.Month, $DayOfMonth
                    if ($occurrence -ge $startDt -and ($null -eq $endDt -or $occurrence -le $endDt)) {
                        $occurrences += $occurrence
                        $count++
                    }
                }
                catch {
                    # Day doesn't exist in this month, skip
                }
                # Move to next month
                $current = New-Object DateTime $current.Year, $current.Month, 1
                $current = $current.AddMonths(1)
            }
        }
    }

    return $occurrences
}

<#
.SYNOPSIS
    Generates iCalendar RRULE string for recurrence pattern.

.DESCRIPTION
    Converts recurrence settings to RFC 5545 RRULE format.
    Example: RRULE:FREQ=DAILY;UNTIL=20261231T235959Z;COUNT=10

.PARAMETER RecurrencePattern
    None, Daily, Weekly, Monthly

.PARAMETER EndDate
    Until date (yyyy-MM-dd)

.PARAMETER MaxOccurrences
    COUNT value

.PARAMETER DayOfWeek
    BYDAY value (Weekly only)

.PARAMETER DayOfMonth
    BYMONTHDAY value (Monthly only)

.OUTPUTS
    [string] RRULE (empty if pattern is None)
#>
function ConvertTo-ICalendarRRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RecurrencePattern,
        [string]$EndDate,
        [int]$MaxOccurrences,
        [string]$DayOfWeek,
        [int]$DayOfMonth
    )

    $patterns = Get-RecurrencePatterns
    if ($RecurrencePattern -eq $patterns.None) {
        return ''
    }

    $parts = @()

    # Add frequency
    $freq = switch ($RecurrencePattern) {
        $patterns.Daily { 'DAILY' }
        $patterns.Weekly { 'WEEKLY' }
        $patterns.Monthly { 'MONTHLY' }
    }
    $parts += "FREQ=$freq"

    # Add UNTIL (convert to UTC)
    if ($EndDate) {
        $endDt = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
        $until = $endDt.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $parts += "UNTIL=$until"
    }

    # Add COUNT
    if ($MaxOccurrences -gt 0) {
        $parts += "COUNT=$MaxOccurrences"
    }

    # Add BYDAY (Weekly)
    if ($RecurrencePattern -eq $patterns.Weekly -and $DayOfWeek) {
        $dayAbbrv = ($DayOfWeek.Substring(0, 2)).ToUpper()
        $parts += "BYDAY=$dayAbbrv"
    }

    # Add BYMONTHDAY (Monthly)
    if ($RecurrencePattern -eq $patterns.Monthly -and $DayOfMonth -gt 0) {
        $parts += "BYMONTHDAY=$DayOfMonth"
    }

    return "RRULE:" + ($parts -join ';')
}

<#
.SYNOPSIS
    Creates multiple reservation instances from a recurring pattern.

.DESCRIPTION
    Generates all occurrence dates, then calls New-Reservation for each.
    Returns array of created reservation objects with SeriesId (unique identifier).
    Failures in any single occurrence do NOT prevent others from being created.

.PARAMETER MachineName
    Machine name

.PARAMETER UserId
    User creating reservation

.PARAMETER UserDisplayName
    Display name for user

.PARAMETER RecurrencePattern
    None, Daily, Weekly, Monthly

.PARAMETER StartDate
    First occurrence (yyyy-MM-dd)

.PARAMETER EndDate
    Last possible date (yyyy-MM-dd)

.PARAMETER MaxOccurrences
    Max count (if provided, overrides EndDate)

.PARAMETER StartTime
    HH:mm format (same for all occurrences)

.PARAMETER EndTime
    HH:mm format (same for all occurrences)

.PARAMETER Comments
    Comments (same for all occurrences)

.PARAMETER OverrideWarning
    $true to bypass conflict warnings

.PARAMETER SettingsPath
    Path to Settings.json

.PARAMETER ReservationPath
    Path to reservation storage

.PARAMETER DayOfWeek
    For Weekly (Sunday-Saturday)

.PARAMETER DayOfMonth
    For Monthly (1-31)

.OUTPUTS
    [PSCustomObject[]] array with ReservationId, SeriesId, Date, Status, Error (if failed)
#>
function New-RecurringReservation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$MachineName,
        [Parameter(Mandatory = $true)][string]$UserId,
        [Parameter(Mandatory = $true)][string]$UserDisplayName,
        [Parameter(Mandatory = $true)][string]$RecurrencePattern,
        [Parameter(Mandatory = $true)][string]$StartDate,
        [string]$EndDate,
        [int]$MaxOccurrences,
        [Parameter(Mandatory = $true)][string]$StartTime,
        [Parameter(Mandatory = $true)][string]$EndTime,
        [string]$Comments,
        [bool]$OverrideWarning,
        [Parameter(Mandatory = $true)][string]$SettingsPath,
        [Parameter(Mandatory = $true)][string]$ReservationPath,
        [string]$DayOfWeek,
        [int]$DayOfMonth
    )

    # Import Phase 2 module
    $phase2ModulePath = Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Reservations.psm1'
    if (-not (Test-Path -LiteralPath $phase2ModulePath)) {
        throw "Phase 2 module not found: $phase2ModulePath"
    }
    Import-Module -Name $phase2ModulePath -Force

    # Generate SeriesId for grouping
    $seriesId = [guid]::NewGuid().ToString()

    # Validate recurrence settings
    $validation = Test-RecurrenceSettings -RecurrencePattern $RecurrencePattern `
        -StartDate $StartDate -EndDate $EndDate -MaxOccurrences $MaxOccurrences `
        -DayOfWeek $DayOfWeek -DayOfMonth $DayOfMonth

    if (-not $validation.Valid) {
        throw "Recurrence validation failed: $($validation.Message)"
    }

    # Get occurrences
    $occurrences = Get-RecurrenceOccurrences -RecurrencePattern $RecurrencePattern `
        -StartDate $StartDate -EndDate $EndDate -MaxOccurrences $MaxOccurrences `
        -DayOfWeek $DayOfWeek -DayOfMonth $DayOfMonth

    $results = @()

    foreach ($occurrence in $occurrences) {
        try {
            $dateString = $occurrence.ToString('yyyy-MM-dd')

            # Call Phase 2 New-Reservation for this occurrence
            $reservation = New-Reservation -MachineName $MachineName `
                -UserId $UserId -UserDisplayName $UserDisplayName `
                -ReservationDate $dateString -StartTime $StartTime `
                -EndTime $EndTime -Comments "$Comments [Series: $seriesId]" `
                -OverrideWarning $OverrideWarning `
                -SettingsPath $SettingsPath -ReservationPath $ReservationPath

            $results += [PSCustomObject]@{
                Date = $dateString
                ReservationId = $reservation.ReservationId
                SeriesId = $seriesId
                Status = 'Success'
                Error = $null
            }
        }
        catch {
            $results += [PSCustomObject]@{
                Date = $occurrence.ToString('yyyy-MM-dd')
                ReservationId = $null
                SeriesId = $seriesId
                Status = 'Failed'
                Error = $_.Exception.Message
            }
        }
    }

    return $results
}

<#
.SYNOPSIS
    Cancels all reservations in a series.

.DESCRIPTION
    Finds all reservations with matching SeriesId in comments.
    Calls Cancel-Reservation for each. Partial failures don't stop processing.

.PARAMETER SeriesId
    Unique series identifier

.PARAMETER CancellationReason
    Reason for cancellation

.PARAMETER CancelledByUserId
    User initiating cancellation

.PARAMETER SettingsPath
    Path to Settings.json

.PARAMETER ReservationPath
    Path to reservation storage

.OUTPUTS
    [PSCustomObject[]] array with ReservationId, Status, Error (if failed)
#>
function Remove-RecurringReservationSeries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SeriesId,
        [string]$CancellationReason = 'Series cancelled',
        [string]$CancelledByUserId,
        [Parameter(Mandatory = $true)][string]$SettingsPath,
        [Parameter(Mandatory = $true)][string]$ReservationPath
    )

    # Import Phase 2 module
    $phase2ModulePath = Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Reservations.psm1'
    Import-Module -Name $phase2ModulePath -Force

    # Find all reservations with this SeriesId
    $allReservations = Get-Reservations -ReservationPath $ReservationPath
    $seriesToCancel = $allReservations | Where-Object { $_.Comments -match $SeriesId }

    $results = @()

    foreach ($reservation in $seriesToCancel) {
        try {
            Cancel-Reservation -ReservationId $reservation.ReservationId `
                -CancellationReason $CancellationReason `
                -CancelledByUserId $CancelledByUserId `
                -ReservationPath $ReservationPath

            $results += [PSCustomObject]@{
                ReservationId = $reservation.ReservationId
                Status = 'Cancelled'
                Error = $null
            }
        }
        catch {
            $results += [PSCustomObject]@{
                ReservationId = $reservation.ReservationId
                Status = 'Failed'
                Error = $_.Exception.Message
            }
        }
    }

    return $results
}

<#
.SYNOPSIS
    Skips (cancels) a single occurrence from recurring series.

.DESCRIPTION
    Useful for removing one date while keeping others active.
    Finds reservation by SeriesId + Date and cancels it.

.PARAMETER SeriesId
    Series identifier

.PARAMETER OccurrenceDate
    Date to skip (yyyy-MM-dd)

.PARAMETER CancelledByUserId
    User initiating skip

.PARAMETER SettingsPath
    Path to Settings.json

.PARAMETER ReservationPath
    Path to reservation storage

.OUTPUTS
    [PSCustomObject] with ReservationId, Status, Error
#>
function Skip-RecurrenceOccurrence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SeriesId,
        [Parameter(Mandatory = $true)][string]$OccurrenceDate,
        [string]$CancelledByUserId,
        [Parameter(Mandatory = $true)][string]$SettingsPath,
        [Parameter(Mandatory = $true)][string]$ReservationPath
    )

    # Import Phase 2 module
    $phase2ModulePath = Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Reservations.psm1'
    Import-Module -Name $phase2ModulePath -Force

    # Find the specific occurrence
    $allReservations = Get-Reservations -ReservationPath $ReservationPath `
        -StartDate $OccurrenceDate -EndDate $OccurrenceDate
    $targetReservation = $allReservations | Where-Object { $_.Comments -match $SeriesId } | Select-Object -First 1

    if (-not $targetReservation) {
        throw "No reservation found for series $SeriesId on date $OccurrenceDate"
    }

    Cancel-Reservation -ReservationId $targetReservation.ReservationId `
        -CancellationReason "Skipped occurrence from series $SeriesId" `
        -CancelledByUserId $CancelledByUserId `
        -ReservationPath $ReservationPath

    return [PSCustomObject]@{
        ReservationId = $targetReservation.ReservationId
        SeriesId = $SeriesId
        OccurrenceDate = $OccurrenceDate
        Status = 'Skipped'
        Error = $null
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Get-RecurrencePatterns',
    'Test-RecurrenceSettings',
    'Get-RecurrenceOccurrences',
    'ConvertTo-ICalendarRRule',
    'New-RecurringReservation',
    'Remove-RecurringReservationSeries',
    'Skip-RecurrenceOccurrence'
)
