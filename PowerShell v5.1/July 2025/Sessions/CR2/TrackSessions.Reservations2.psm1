# TrackSessions.Reservations.psm1
# Phase 2: Core Reservation Management Module
# Provides CRUD operations, conflict detection, permission checks, and file management

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Gets the reservation settings from TrackSessions.Settings.json
.DESCRIPTION
    Loads reservation configuration from the settings file.
.PARAMETER SettingsPath
    Path to TrackSessions.Settings.json
.EXAMPLE
    $settings = Get-ReservationSettings -SettingsPath 'C:\config\TrackSessions.Settings.json'
#>
function Get-ReservationSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsPath
    )

    # Default reservation settings - used if file missing or Reservations section not found
    $defaultSettings = @{
        BusinessHoursStart = "09:00"
        BusinessHoursEnd = "18:00"
        TimeSlotGranularity = 30
        AllowPastDateReservations = $false
        PreventOverlappingReservations = $false
    }

    if (-not (Test-Path -LiteralPath $SettingsPath)) {
        # Settings file not found - return defaults
        return $defaultSettings
    }

    try {
        $settingsJson = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
        
        # Check if Reservations section exists
        if ($settingsJson.PSObject.Properties.Name -contains 'Reservations') {
            $reservations = $settingsJson.Reservations
            # Validate all required properties exist
            if ($reservations.PSObject.Properties.Name -contains 'BusinessHoursStart' -and
                $reservations.PSObject.Properties.Name -contains 'TimeSlotGranularity') {
                return $reservations
            }
        }
        
        # Reservations section missing or incomplete - return defaults
        return $defaultSettings
    }
    catch {
        # JSON parse error or other issue - return defaults silently
        Write-Debug "Failed to parse settings file, using defaults: $_"
        return $defaultSettings
    }
}

<#
.SYNOPSIS
    Gets the user database from TrackSessions.Users.json
.DESCRIPTION
    Loads the user database for permission and admin checks.
.PARAMETER UsersPath
    Path to TrackSessions.Users.json
.EXAMPLE
    $users = Get-UserDatabase -UsersPath 'C:\config\TrackSessions.Users.json'
#>
function Get-UserDatabase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UsersPath
    )

    if (-not (Test-Path -LiteralPath $UsersPath)) {
        throw "Users file not found: $UsersPath"
    }

    try {
        $usersJson = Get-Content -LiteralPath $UsersPath -Raw | ConvertFrom-Json
        return $usersJson
    }
    catch {
        throw "Failed to load users database: $_"
    }
}

<#
.SYNOPSIS
    Tests if a user has edit permission for a reservation.
.DESCRIPTION
    Checks permission rules: Owner can edit own, Admins can edit any, others read-only.
.PARAMETER CurrentUserId
    SEID of current user
.PARAMETER ReservationOwnerId
    SEID of reservation owner
.PARAMETER Users
    User database array from TrackSessions.Users.json
.PARAMETER ReservationAdmins
    Array of admin SEIDs from Settings
.EXAMPLE
    if (Test-ReservationEditPermission -CurrentUserId 'YMJNB' -ReservationOwnerId 'ABCD123' -Users $users -ReservationAdmins $admins) { ... }
#>
function Test-ReservationEditPermission {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentUserId,
        [Parameter(Mandatory = $true)]
        [string]$ReservationOwnerId,
        [Parameter(Mandatory = $true)]
        [object[]]$Users,
        [Parameter(Mandatory = $true)]
        [string[]]$ReservationAdmins
    )

    # Owner can always edit own reservation
    if ($CurrentUserId -eq $ReservationOwnerId) {
        return $true
    }

    # Admin can edit any reservation
    if ($ReservationAdmins -contains $CurrentUserId) {
        return $true
    }

    return $false
}

<#
.SYNOPSIS
    Tests if a time slot overlaps with existing reservations.
.DESCRIPTION
    Checks for conflicts between proposed reservation and existing ones.
.PARAMETER MachineName
    Computer name
.PARAMETER ReservationDate
    Date in yyyy-MM-dd format
.PARAMETER StartTime
    Start time in HH:mm format
.PARAMETER EndTime
    End time in HH:mm format
.PARAMETER ReservationPath
    UNC path to reservations folder
.EXAMPLE
    $conflict = Test-ReservationConflict -MachineName 'PAWS01' -ReservationDate '2026-09-15' -StartTime '10:00' -EndTime '11:00' -ReservationPath '\\share\reservations'
#>
function Test-ReservationConflict {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MachineName,
        [Parameter(Mandatory = $true)]
        [string]$ReservationDate,
        [Parameter(Mandatory = $true)]
        [string]$StartTime,
        [Parameter(Mandatory = $true)]
        [string]$EndTime,
        [Parameter(Mandatory = $true)]
        [string]$ReservationPath
    )

    if (-not (Test-Path -LiteralPath $ReservationPath)) {
        return @{
            HasConflict = $false
            ConflictingReservations = @()
        }
    }

    # Convert times to minutes for comparison
    $startMinutes = ([timespan]::Parse($StartTime)).TotalMinutes
    $endMinutes = ([timespan]::Parse($EndTime)).TotalMinutes

    # Get all active reservations for this machine on this date
    $pattern = "Reservation.$($MachineName -replace '\$', '\`$').*$($ReservationDate -replace '-', '').*.Active.json"
    $conflicts = @()

    try {
        $existingFiles = @(Get-ChildItem -LiteralPath $ReservationPath -Filter "Reservation.*$ReservationDate*.Active.json" -ErrorAction SilentlyContinue)
        
        foreach ($file in $existingFiles) {
            # Parse filename: Reservation.{Machine}.{User}.{yyyyMMdd}.{HHmmss_Start}.{HHmmss_End}.Active.json
            if ($file.Name -match '^Reservation\.([^.]+)\.([^.]+)\.(\d{8})\.(\d{6})\.(\d{6})\.Active\.json$') {
                $fileMachine = $Matches[1]
                $fileDate = $Matches[3]
                $fileStartStr = $Matches[4]
                $fileEndStr = $Matches[5]

                # Only check same machine and date
                if ($fileMachine -ne $MachineName) { continue }
                if ($fileDate -ne ($ReservationDate -replace '-', '')) { continue }

                # Convert HHmmss to minutes
                $fileStartMinutes = [int]($fileStartStr.Substring(0, 2)) * 60 + [int]($fileStartStr.Substring(2, 2))
                $fileEndMinutes = [int]($fileEndStr.Substring(0, 2)) * 60 + [int]($fileEndStr.Substring(2, 2))

                # Check for overlap: NOT (A.end <= B.start OR A.start >= B.end)
                if (-not (($fileEndMinutes -le $startMinutes) -or ($fileStartMinutes -ge $endMinutes))) {
                    $conflicts += @{
                        FileName = $file.Name
                        MachineName = $fileMachine
                        StartTime = "{0:D2}:{1:D2}" -f ([int]($fileStartStr.Substring(0, 2))), ([int]($fileStartStr.Substring(2, 2)))
                        EndTime = "{0:D2}:{1:D2}" -f ([int]($fileEndStr.Substring(0, 2))), ([int]($fileEndStr.Substring(2, 2)))
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Error checking conflicts: $_"
    }

    return @{
        HasConflict = $conflicts.Count -gt 0
        ConflictingReservations = $conflicts
    }
}

<#
.SYNOPSIS
    Creates a new reservation with validation.
.DESCRIPTION
    Creates paired JSON and HTML files for a reservation.
    Validates time slots, business hours, permissions, and conflicts.
.PARAMETER MachineName
    Computer name
.PARAMETER MachineFqdn
    Fully qualified domain name (optional)
.PARAMETER UserId
    SEID of user making reservation
.PARAMETER UserDisplayName
    Display name of user
.PARAMETER UserEmail
    Email address of user
.PARAMETER ReservationDate
    Date in yyyy-MM-dd format
.PARAMETER StartTime
    Start time in HH:mm format
.PARAMETER EndTime
    End time in HH:mm format
.PARAMETER Comments
    Optional reservation comments
.PARAMETER OverrideWarning
    If $true, allows overlap if user is admin
.PARAMETER ReservationPath
    UNC path to reservations folder
.PARAMETER SettingsPath
    Path to TrackSessions.Settings.json
.PARAMETER UsersPath
    Path to TrackSessions.Users.json
.EXAMPLE
    New-Reservation -MachineName 'PAWS01' -UserId 'YMJNB' -UserDisplayName 'Davis Lee' -UserEmail 'davis@example.com' -ReservationDate '2026-09-15' -StartTime '10:00' -EndTime '11:00' -ReservationPath '\\share\reservations' -SettingsPath 'C:\config\TrackSessions.Settings.json' -UsersPath 'C:\config\TrackSessions.Users.json'
#>
function New-Reservation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MachineName,
        [Parameter(Mandatory = $false)]
        [string]$MachineFqdn = '',
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
        [Parameter(Mandatory = $false)]
        [bool]$OverrideWarning = $false,
        [Parameter(Mandatory = $true)]
        [string]$ReservationPath,
        [Parameter(Mandatory = $true)]
        [string]$SettingsPath,
        [Parameter(Mandatory = $true)]
        [string]$UsersPath
    )

    # Validate inputs
    if ($ReservationDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
        throw "Invalid date format. Expected yyyy-MM-dd"
    }
    if ($StartTime -notmatch '^\d{2}:\d{2}$') {
        throw "Invalid start time format. Expected HH:mm"
    }
    if ($EndTime -notmatch '^\d{2}:\d{2}$') {
        throw "Invalid end time format. Expected HH:mm"
    }

    # Load settings and users
    $settings = Get-ReservationSettings -SettingsPath $SettingsPath
    $users = Get-UserDatabase -UsersPath $UsersPath

    # Validate time slot
    $startMinutes = ([timespan]::Parse($StartTime)).TotalMinutes
    $endMinutes = ([timespan]::Parse($EndTime)).TotalMinutes

    if ($startMinutes -ge $endMinutes) {
        throw "Start time must be before end time"
    }

    # Check business hours
    $businessStart = ([timespan]::Parse($settings.BusinessHoursStart)).TotalMinutes
    $businessEnd = ([timespan]::Parse($settings.BusinessHoursEnd)).TotalMinutes

    if ($startMinutes -lt $businessStart -or $endMinutes -gt $businessEnd) {
        throw "Reservation outside business hours ($($settings.BusinessHoursStart) - $($settings.BusinessHoursEnd))"
    }

    # Check if time slot is multiple of granularity
    $granularity = $settings.TimeSlotGranularity
    if (($startMinutes % $granularity -ne 0) -or (($endMinutes - $startMinutes) % $granularity -ne 0)) {
        throw "Times must align with $granularity-minute granularity"
    }

    # Check for conflicts
    $conflictCheck = Test-ReservationConflict -MachineName $MachineName -ReservationDate $ReservationDate -StartTime $StartTime -EndTime $EndTime -ReservationPath $ReservationPath

    if ($conflictCheck.HasConflict) {
        if (-not $OverrideWarning) {
            throw "Reservation conflicts with existing bookings. Set OverrideWarning=`$true to proceed as admin."
        }

        # Verify user is admin
        $userRecord = $users | Where-Object { $_.SEID -eq $UserId } | Select-Object -First 1
        if (-not $userRecord.IsAdmin) {
            throw "Only admins can override conflicts"
        }
    }

    # Generate reservation ID
    $reservationId = [guid]::NewGuid().ToString()
    $now = [datetime]::UtcNow
    $createdAtGmt = $now.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    # Create safe machine name for filename
    $safeFileName = $MachineName -replace '[^A-Za-z0-9._-]', '-'
    
    # Format times for filename (HHmmss)
    $fileStartTime = $StartTime -replace ':', ''
    $fileEndTime = $EndTime -replace ':', ''
    $fileDate = $ReservationDate -replace '-', ''

    # Build JSON data
    $reservationData = [ordered]@{
        ReservationId = $reservationId
        MachineName = $MachineName
        MachineShortName = ($MachineName -split '\.')[0]
        MachineFqdn = $MachineFqdn
        UserId = $UserId
        UserDisplayName = $UserDisplayName
        UserEmail = $UserEmail
        ReservationDate = $ReservationDate
        StartTime = $StartTime
        EndTime = $EndTime
        Duration = "$([int]($endMinutes - $startMinutes)) minutes"
        CreatedAtGmt = $createdAtGmt
        LastModifiedAtGmt = $createdAtGmt
        Status = 'Active'
        Comments = $Comments
        OverrideWarning = $OverrideWarning
        CancelledAtGmt = $null
        CancelledByUserId = $null
        CancellationReason = $null
    }

    # Create filename: Reservation.{Machine}.{User}.{yyyyMMdd}.{HHmmss_Start}.{HHmmss_End}.Active.json
    $jsonFileName = "Reservation.$safeFileName.$UserId.$fileDate.$fileStartTime.$fileEndTime.Active.json"
    $jsonFilePath = Join-Path -Path $ReservationPath -ChildPath $jsonFileName

    # Ensure reservation path exists
    if (-not (Test-Path -LiteralPath $ReservationPath)) {
        New-Item -ItemType Directory -Path $ReservationPath -Force | Out-Null
    }

    # Write JSON file with atomic operation
    try {
        $jsonContent = $reservationData | ConvertTo-Json -Depth 10
        $tempPath = "$jsonFilePath.tmp"
        Set-Content -LiteralPath $tempPath -Value $jsonContent -Encoding UTF8 -Force
        Rename-Item -LiteralPath $tempPath -NewName $jsonFileName -Force
    }
    catch {
        throw "Failed to create reservation JSON: $_"
    }

    # Generate and write HTML file
    try {
        $htmlContent = ConvertTo-ReservationHtml -ReservationData $reservationData
        $htmlFileName = $jsonFileName -replace '\.json$', '.html'
        $htmlFilePath = Join-Path -Path $ReservationPath -ChildPath $htmlFileName
        Set-Content -LiteralPath $htmlFilePath -Value $htmlContent -Encoding UTF8 -Force
    }
    catch {
        # Log warning but don't fail
        Write-Warning "Failed to create HTML file for reservation $reservationId : $_"
    }

    return @{
        ReservationId = $reservationId
        JsonFile = $jsonFileName
        HtmlFile = $htmlFileName
        CreatedAt = $createdAtGmt
    }
}

<#
.SYNOPSIS
    Retrieves reservations with filtering options.
.DESCRIPTION
    Query reservations by machine, user, date range, or status.
.PARAMETER ReservationPath
    UNC path to reservations folder
.PARAMETER MachineName
    Filter by machine name (optional)
.PARAMETER UserId
    Filter by user ID (optional)
.PARAMETER ReservationDate
    Filter by specific date (optional)
.PARAMETER StartDate
    Filter by date range start (optional)
.PARAMETER EndDate
    Filter by date range end (optional)
.PARAMETER Status
    Filter by status: Active, Cancelled, or * for all (default: Active)
.EXAMPLE
    $reservations = Get-Reservations -ReservationPath '\\share\reservations' -MachineName 'PAWS01'
    $reservations = Get-Reservations -ReservationPath '\\share\reservations' -UserId 'YMJNB' -Status '*'
#>
function Get-Reservations {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReservationPath,
        [Parameter(Mandatory = $false)]
        [string]$MachineName = '',
        [Parameter(Mandatory = $false)]
        [string]$UserId = '',
        [Parameter(Mandatory = $false)]
        [string]$ReservationDate = '',
        [Parameter(Mandatory = $false)]
        [string]$StartDate = '',
        [Parameter(Mandatory = $false)]
        [string]$EndDate = '',
        [Parameter(Mandatory = $false)]
        [string]$Status = 'Active'
    )

    if (-not (Test-Path -LiteralPath $ReservationPath)) {
        return @()
    }

    try {
        # Build file pattern
        $pattern = if ($Status -eq '*') { '*.json' } else { "*.$Status.json" }
        $files = @(Get-ChildItem -LiteralPath $ReservationPath -Filter $pattern -ErrorAction SilentlyContinue)

        $results = @()

        foreach ($file in $files) {
            # Parse filename for quick filtering
            if ($file.Name -notmatch '^Reservation\.([^.]+)\.([^.]+)\.(\d{8})') {
                continue
            }

            $fileMachine = $Matches[1]
            $fileUser = $Matches[2]
            $fileDate = $Matches[3]

            # Apply filters
            if ($MachineName -and $fileMachine -ne $MachineName) { continue }
            if ($UserId -and $fileUser -ne $UserId) { continue }

            # Load JSON for detailed filtering
            try {
                $jsonContent = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
                
                if ($ReservationDate -and $jsonContent.ReservationDate -ne $ReservationDate) { continue }
                if ($StartDate -and $jsonContent.ReservationDate -lt $StartDate) { continue }
                if ($EndDate -and $jsonContent.ReservationDate -gt $EndDate) { continue }

                $results += $jsonContent
            }
            catch {
                Write-Warning "Failed to parse reservation file $($file.Name): $_"
            }
        }

        return $results
    }
    catch {
        throw "Failed to retrieve reservations: $_"
    }
}

<#
.SYNOPSIS
    Updates an existing reservation.
.DESCRIPTION
    Modifies reservation details with permission checks.
.PARAMETER ReservationFile
    Full path to the reservation JSON file
.PARAMETER UserId
    SEID of user making the update
.PARAMETER StartTime
    New start time (optional)
.PARAMETER EndTime
    New end time (optional)
.PARAMETER Comments
    New comments (optional)
.PARAMETER ReservationAdmins
    Array of admin SEIDs
.PARAMETER SettingsPath
    Path to TrackSessions.Settings.json
.EXAMPLE
    Update-Reservation -ReservationFile '\\share\reservations\Reservation.PAWS01.YMJNB.20260915.100000.110000.Active.json' -UserId 'YMJNB' -Comments 'New comment' -ReservationAdmins @('YMJNB') -SettingsPath 'C:\config\settings.json'
#>
function Update-Reservation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReservationFile,
        [Parameter(Mandatory = $true)]
        [string]$UserId,
        [Parameter(Mandatory = $false)]
        [string]$StartTime = '',
        [Parameter(Mandatory = $false)]
        [string]$EndTime = '',
        [Parameter(Mandatory = $false)]
        [string]$Comments = '',
        [Parameter(Mandatory = $true)]
        [string[]]$ReservationAdmins,
        [Parameter(Mandatory = $true)]
        [string]$SettingsPath
    )

    if (-not (Test-Path -LiteralPath $ReservationFile)) {
        throw "Reservation file not found: $ReservationFile"
    }

    try {
        $reservationData = Get-Content -LiteralPath $ReservationFile -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to load reservation: $_"
    }

    # Check permission
    if (-not (Test-ReservationEditPermission -CurrentUserId $UserId -ReservationOwnerId $reservationData.UserId -Users @() -ReservationAdmins $ReservationAdmins)) {
        throw "Permission denied: User $UserId cannot edit this reservation"
    }

    # Update fields if provided
    if ($StartTime) { $reservationData.StartTime = $StartTime }
    if ($EndTime) { $reservationData.EndTime = $EndTime }
    if ($Comments -ne '') { $reservationData.Comments = $Comments }

    $reservationData.LastModifiedAtGmt = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    # Write back
    try {
        $jsonContent = $reservationData | ConvertTo-Json -Depth 10
        $tempPath = "$ReservationFile.tmp"
        Set-Content -LiteralPath $tempPath -Value $jsonContent -Encoding UTF8 -Force
        Rename-Item -LiteralPath $tempPath -NewName (Split-Path -Leaf $ReservationFile) -Force
    }
    catch {
        throw "Failed to update reservation: $_"
    }

    return $reservationData
}

<#
.SYNOPSIS
    Cancels a reservation.
.DESCRIPTION
    Marks reservation as cancelled and renames file with .CANCELLED status.
.PARAMETER ReservationFile
    Full path to the reservation JSON file
.PARAMETER UserId
    SEID of user cancelling
.PARAMETER CancellationReason
    Reason for cancellation
.PARAMETER ReservationAdmins
    Array of admin SEIDs
.EXAMPLE
    Cancel-Reservation -ReservationFile '\\share\reservations\Reservation.PAWS01.YMJNB.20260915.100000.110000.Active.json' -UserId 'YMJNB' -CancellationReason 'Schedule conflict' -ReservationAdmins @('YMJNB')
#>
function Cancel-Reservation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReservationFile,
        [Parameter(Mandatory = $true)]
        [string]$UserId,
        [Parameter(Mandatory = $false)]
        [string]$CancellationReason = '',
        [Parameter(Mandatory = $true)]
        [string[]]$ReservationAdmins
    )

    if (-not (Test-Path -LiteralPath $ReservationFile)) {
        throw "Reservation file not found: $ReservationFile"
    }

    try {
        $reservationData = Get-Content -LiteralPath $ReservationFile -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to load reservation: $_"
    }

    # Check permission
    if (-not (Test-ReservationEditPermission -CurrentUserId $UserId -ReservationOwnerId $reservationData.UserId -Users @() -ReservationAdmins $ReservationAdmins)) {
        throw "Permission denied: User $UserId cannot cancel this reservation"
    }

    # Update cancellation fields
    $reservationData.Status = 'Cancelled'
    $reservationData.CancelledAtGmt = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $reservationData.CancelledByUserId = $UserId
    $reservationData.CancellationReason = $CancellationReason
    $reservationData.LastModifiedAtGmt = $reservationData.CancelledAtGmt

    # Rename file from .Active to .CANCELLED
    $newFileName = $ReservationFile -replace '\.Active\.json$', '.CANCELLED.json'

    try {
        # Write updated JSON to new location
        $jsonContent = $reservationData | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath $newFileName -Value $jsonContent -Encoding UTF8 -Force

        # Remove old file
        Remove-Item -LiteralPath $ReservationFile -Force

        # Create HTML for cancelled status
        $htmlFileName = $newFileName -replace '\.json$', '.html'
        $htmlContent = ConvertTo-ReservationHtml -ReservationData $reservationData
        Set-Content -LiteralPath $htmlFileName -Value $htmlContent -Encoding UTF8 -Force
    }
    catch {
        throw "Failed to cancel reservation: $_"
    }

    return $reservationData
}

<#
.SYNOPSIS
    Converts a reservation object to HTML format.
.DESCRIPTION
    Generates responsive HTML representation of a reservation using embedded CSS and JavaScript.
.PARAMETER ReservationData
    Reservation object (typically from JSON)
.EXAMPLE
    $html = ConvertTo-ReservationHtml -ReservationData $reservation
#>
function ConvertTo-ReservationHtml {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ReservationData
    )

    $statusBadgeColor = if ($ReservationData.Status -eq 'Cancelled') { '#da3b01' } elseif ($ReservationData.Status -eq 'Active') { '#107c10' } else { '#606e7a' }
    $statusBadgeText = $ReservationData.Status

    # Prepare display data
    $displayData = @{
        ReservationId = $ReservationData.ReservationId
        MachineName = $ReservationData.MachineName
        UserDisplayName = $ReservationData.UserDisplayName
        UserEmail = $ReservationData.UserEmail
        ReservationDate = $ReservationData.ReservationDate
        StartTime = $ReservationData.StartTime
        EndTime = $ReservationData.EndTime
        Status = $ReservationData.Status
        Comments = $ReservationData.Comments
        CreatedAtGmt = $ReservationData.CreatedAtGmt
        LastModifiedAtGmt = $ReservationData.LastModifiedAtGmt
        CancelledAtGmt = $ReservationData.CancelledAtGmt
        CancelledByUserId = $ReservationData.CancelledByUserId
        CancellationReason = $ReservationData.CancellationReason
    }

    $jsonData = $displayData | ConvertTo-Json -Compress

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reservation: $($ReservationData.MachineName)</title>
    <style>
        :root {
            --primary-color: #0078d4;
            --success-color: #107c10;
            --danger-color: #da3b01;
            --warning-color: #ffb900;
            --neutral-color: #606e7a;
            --light-gray: #f3f2f1;
            --dark-gray: #2e3a48;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
            background-color: #f8f8f8;
            padding: 20px;
            line-height: 1.6;
            color: var(--dark-gray);
        }

        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            padding: 24px;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
            border-bottom: 2px solid var(--light-gray);
            padding-bottom: 16px;
        }

        .header h1 {
            font-size: 24px;
            color: var(--dark-gray);
            margin: 0;
        }

        .status-badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 4px;
            font-size: 13px;
            font-weight: 600;
            color: white;
            background-color: $statusBadgeColor;
        }

        .section {
            margin-bottom: 24px;
        }

        .section-title {
            font-size: 14px;
            font-weight: 600;
            color: var(--dark-gray);
            margin-bottom: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .details-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 16px;
        }

        .detail-item {
            background-color: var(--light-gray);
            padding: 12px;
            border-radius: 4px;
        }

        .detail-label {
            font-size: 12px;
            font-weight: 600;
            color: var(--neutral-color);
            text-transform: uppercase;
            margin-bottom: 4px;
        }

        .detail-value {
            font-size: 15px;
            color: var(--dark-gray);
            word-break: break-word;
        }

        .time-slot {
            background: linear-gradient(135deg, var(--primary-color) 0%, #1090da 100%);
            color: white;
            padding: 16px;
            border-radius: 4px;
            margin-bottom: 16px;
        }

        .time-slot-row {
            display: flex;
            justify-content: space-around;
            gap: 16px;
            flex-wrap: wrap;
        }

        .time-slot-item {
            text-align: center;
        }

        .time-slot-label {
            font-size: 12px;
            opacity: 0.9;
            margin-bottom: 4px;
        }

        .time-slot-value {
            font-size: 20px;
            font-weight: 600;
        }

        .comments-box {
            background-color: var(--light-gray);
            padding: 12px;
            border-left: 4px solid var(--primary-color);
            border-radius: 4px;
            white-space: pre-wrap;
            word-wrap: break-word;
        }

        .metadata-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }

        .metadata-table tr {
            border-bottom: 1px solid var(--light-gray);
        }

        .metadata-table th {
            background-color: var(--light-gray);
            padding: 8px 12px;
            text-align: left;
            font-weight: 600;
            color: var(--neutral-color);
        }

        .metadata-table td {
            padding: 8px 12px;
        }

        .cancellation-info {
            background-color: #fde7e9;
            border-left: 4px solid var(--danger-color);
            padding: 12px;
            border-radius: 4px;
            margin-top: 16px;
        }

        .footer {
            border-top: 1px solid var(--light-gray);
            padding-top: 16px;
            margin-top: 24px;
            font-size: 12px;
            color: var(--neutral-color);
            text-align: center;
        }

        @media print {
            body {
                background-color: white;
                padding: 0;
            }
            .container {
                box-shadow: none;
                padding: 0;
            }
        }

        @media (max-width: 768px) {
            .container {
                padding: 16px;
            }
            .header {
                flex-direction: column;
                align-items: flex-start;
            }
            .header h1 {
                margin-bottom: 12px;
            }
            .details-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Machine Reservation</h1>
            <span class="status-badge">$statusBadgeText</span>
        </div>

        <div class="section">
            <div class="section-title">Machine &amp; User</div>
            <div class="details-grid">
                <div class="detail-item">
                    <div class="detail-label">Machine Name</div>
                    <div class="detail-value">$($ReservationData.MachineName)</div>
                </div>
                <div class="detail-item">
                    <div class="detail-label">User</div>
                    <div class="detail-value">$($ReservationData.UserDisplayName)</div>
                </div>
                <div class="detail-item">
                    <div class="detail-label">Email</div>
                    <div class="detail-value">$($ReservationData.UserEmail)</div>
                </div>
            </div>
        </div>

        <div class="section">
            <div class="section-title">Time Slot</div>
            <div class="time-slot">
                <div class="time-slot-row">
                    <div class="time-slot-item">
                        <div class="time-slot-label">DATE</div>
                        <div class="time-slot-value">$($ReservationData.ReservationDate)</div>
                    </div>
                    <div class="time-slot-item">
                        <div class="time-slot-label">FROM</div>
                        <div class="time-slot-value">$($ReservationData.StartTime)</div>
                    </div>
                    <div class="time-slot-item">
                        <div class="time-slot-label">TO</div>
                        <div class="time-slot-value">$($ReservationData.EndTime)</div>
                    </div>
                </div>
            </div>
        </div>

        $(if ($ReservationData.Comments) {
            @"
        <div class="section">
            <div class="section-title">Comments</div>
            <div class="comments-box">$($ReservationData.Comments)</div>
        </div>
"@
        })

        <div class="section">
            <div class="section-title">Metadata</div>
            <table class="metadata-table">
                <tr>
                    <th>Field</th>
                    <th>Value</th>
                </tr>
                <tr>
                    <td>Reservation ID</td>
                    <td>$($ReservationData.ReservationId)</td>
                </tr>
                <tr>
                    <td>Created</td>
                    <td>$($ReservationData.CreatedAtGmt)</td>
                </tr>
                <tr>
                    <td>Last Modified</td>
                    <td>$($ReservationData.LastModifiedAtGmt)</td>
                </tr>
            </table>
        </div>

        $(if ($ReservationData.Status -eq 'Cancelled') {
            @"
        <div class="cancellation-info">
            <div class="section-title">Cancellation Details</div>
            <table class="metadata-table">
                <tr>
                    <td><strong>Cancelled At:</strong></td>
                    <td>$($ReservationData.CancelledAtGmt)</td>
                </tr>
                <tr>
                    <td><strong>Cancelled By:</strong></td>
                    <td>$($ReservationData.CancelledByUserId)</td>
                </tr>
                $(if ($ReservationData.CancellationReason) {
                    "<tr><td><strong>Reason:</strong></td><td>$($ReservationData.CancellationReason)</td></tr>"
                })
            </table>
        </div>
"@
        })

        <div class="footer">
            <p>This is an automated reservation generated by TrackSessions</p>
        </div>
    </div>

    <script type="application/json" id="reservation-data">
$jsonData
    </script>
</body>
</html>
"@

    return $html
}

Export-ModuleMember -Function @(
    'Get-ReservationSettings',
    'Get-UserDatabase',
    'Test-ReservationEditPermission',
    'Test-ReservationConflict',
    'New-Reservation',
    'Get-Reservations',
    'Update-Reservation',
    'Cancel-Reservation',
    'ConvertTo-ReservationHtml'
)
