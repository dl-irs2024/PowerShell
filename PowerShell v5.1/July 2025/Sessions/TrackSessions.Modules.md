# TrackSessions Modules Architecture

**Document Version**: 1.0  
**Last Updated**: 2026-09-20  
**Purpose**: Reference guide for TrackSessions settings, users, and reservations modules

---

## Table of Contents

1. [Settings Modules](#settings-modules)
2. [Users Modules](#users-modules)
3. [Reservations Modules](#reservations-modules)
4. [Module Dependencies](#module-dependencies)
5. [File Locations](#file-locations)

---

## Settings Modules

### Read-TrackSessionsSettings
**File**: `TrackSessions.ps1`  
**Lines**: 167-301  
**Description**: Loads TrackSessions settings from JSON file. Returns default settings if file doesn't exist.

**Features**:
- Default settings with schema version 1.0
- Parses MiniWindow position (Left, Top)
- Parses Layout dimensions (BottomPaneHeight, WindowLeft, WindowTop, WindowWidth, WindowHeight)
- Loads tracked machines list
- Handles StartupTrace configuration

**Returns**: PSCustomObject with all settings

### Save-TrackSessionsSettings
**File**: `TrackSessions.ps1`  
**Lines**: 303-315  
**Description**: Saves settings object to JSON file with UTF8 encoding.

**Features**:
- Creates parent directory if missing
- Converts to JSON with proper formatting
- UTF8 encoding (no BOM)

**Parameters**:
- `Path` - Full path to settings JSON file
- `Settings` - Settings object to save

### Get-ReservationSettings
**File**: `TrackSessions.Reservations.psm1`  
**Lines**: 18-59  
**Description**: Loads reservation-specific settings from TrackSessions.Settings.json.

**Default Settings**:
```powershell
@{
    BusinessHoursStart = "09:00"
    BusinessHoursEnd = "18:00"
    TimeSlotGranularity = 30
    AllowPastDateReservations = $false
    PreventOverlappingReservations = $false
}
```

### Show-EditSettingsDialog
**File**: `TrackSessions.ps1`  
**Lines**: 1063+  
**Description**: WPF dialog for editing TrackSessions settings.

**Features**:
- Visual settings editor
- Validation before save
- Cancel/Save buttons

### TrackSessions.Reservations.SettingsDialog.ps1
**File**: `TrackSessions.Reservations.SettingsDialog.ps1`  
**Lines**: 1-100+  
**Description**: Admin settings panel for reservation configuration.

**Key Functions**:
- `Load-Settings` (Line 22): Load from SettingsPath
- `Load-CurrentUser` (Line 33): Get current user from UsersPath
- `Save-Settings` (Line 44): Save with error handling
- `Test-AdminAccess` (Line 58): Check IsAdmin flag before allowing changes
- `Test-PathAccessibility` (Line 71): Validate path accessibility and write permissions

**Requires**: User must have `IsAdmin: true` in TrackSessions.Users.json

---

## Users Modules

### TrackSessions.UserEditor.ps1
**File**: `TrackSessions.UserEditor.ps1`  
**Lines**: 38-585+  
**Description**: Full CRUD editor for TrackSessions.Users.json with WPF interface.

**Key Functions**:

#### User Data Management
- `Format-UserDateTime` (Line 38): Formats datetime as "ddd dd/MM/yyyy hh:mm"
- `ConvertTo-UserDateTime` (Line 47): Parses multiple datetime formats
- `Convert-ToUserObject` (Line 84): Converts raw JSON to typed PSObject
- `Convert-FromUserObject` (Line 128): Converts user object to ordered hashtable for JSON

#### External User Lookup
- `New-ExternalUserLookupResult` (Line 164): Creates standardized lookup result
- `Find-ExternalUserFromCsv` (Line 258): CSV lookup by SEID
- `Find-ExternalUserFromCsvByEmail` (Line 322): CSV lookup by email
- `Find-ExternalUserFromAd` (Line 351): Active Directory lookup via ADSI
- `Find-ExternalUserFromAdByEmail` (Line 374): AD lookup by email
- `Find-ExternalUserFromGraph` (Line 397): Microsoft Graph lookup (if enabled)
- `Find-ExternalUserFromGraphByEmail` (Line 425): Graph lookup by email

#### Lookup Orchestrators
- `Resolve-ExternalUserBySeid` (Line 453): Fallback chain: CSV → AD → Graph
- `Resolve-ExternalUserByEmail` (Line 484): Email-based fallback chain

#### File Operations
- `Import-Users` (Line 540): Loads users from TrackSessions.Users.json
- `Save-Users` (Line 560): Saves users array to JSON with backup

#### UI
- `Show-EditUserDialog` (Line 590+): WPF dialog for user CRUD operations

### User Schema
**File**: `TrackSessions.Users.json`

**Fields**:
```json
{
  "SEID": "LEEDA",
  "FirstName": "Davis",
  "LastName": "Lee",
  "Status": "FTE",
  "IRSEmail": "davis.lee@irs.gov",
  "SEIDEmail": "LEEDA@example.com",
  "Timezone": "Eastern Standard Time",
  "DaylightSavings": true,
  "Products": ["SharePoint", "Power Platform", "OneDrive", "Entra"],
  "LastLogin": "2026-09-20T08:15:30Z",
  "LastPawsUsed": "2026-09-19T14:22:00Z",
  "Created": "2026-01-01T00:00:00Z",
  "LastModified": "2026-09-20T08:15:30Z",
  "IsAdmin": true
}
```

**Key Fields**:
- `SEID`: Uppercase identifier (primary key)
- `IsAdmin`: Boolean flag for reservation admin access
- `Status`: "FTE" or "Contractor"
- `Products`: Array of product access

### Get-UserDatabase
**File**: `TrackSessions.Reservations.psm1`  
**Lines**: 71-88  
**Description**: Loads TrackSessions.Users.json for permission and admin checks.

**Returns**: Array of user objects  
**Throws**: Error if file not found

### Get-UserDisplayName
**File**: `TrackSessions.Simulator CR1.ps1`  
**Lines**: 56-92  
**Description**: Resolves User ID (SEID) to "FirstName LastName" display format.

**Features**:
- Case-insensitive SEID matching
- Extracts username from "DOMAIN\USERNAME" format
- Falls back to SEID if not found

**Returns**: "FirstName LastName" or original SEID

### Test-IsCurrentUserAdmin
**File**: `TrackSessions.Simulator CR1.ps1`  
**Lines**: 191-269  
**Description**: Checks if current Windows user has admin flag set in TrackSessions.Users.json.

**Matching Logic**:
1. Extract username from Windows identity (handles DOMAIN\USER)
2. Match by SEID (case-insensitive)
3. Match by SamAccountName
4. Match by UserId

**Returns**: Boolean

### Get-CurrentUserContext
**File**: Multiple files (TrackSessions.ps1, TrackSessions.Simulator CR1.ps1)  
**Lines**: 23-86 (TrackSessions.ps1), 105-168 (Simulator CR1.ps1)  
**Description**: Gets current Windows user identity including UserId, SamAccountName, Email, and DisplayName.

**Features**:
- Uses `whoami /upn` for email
- Uses LDAP DirectorySearcher for display name
- Falls back to environment variables

**Returns**:
```powershell
@{
    UserId = "DOMAIN\USERNAME"
    SamAccountName = "USERNAME"
    Email = "user@domain.com"
    DisplayName = "FirstName LastName"
}
```

**Note**: ⚠️ This function performs **synchronous LDAP queries** which can block the UI thread for 1-3+ seconds.

### EmailLookup.psm1
**File**: `SessionUtils\EmailLookup.psm1`  
**Description**: Email resolution and user lookup module.

**Exported Functions** (Lines 538-550):
- `Test-OutlookLegacyInstalled`: Checks Outlook installation
- `Initialize-OutlookConnection`: Creates Outlook COM object
- `Cleanup-OutlookConnection`: Releases Outlook COM object
- `Extract-RecipientsFromMailItem`: Extracts recipients from Outlook.MailItem
- `Extract-RecipientsFromMsgFile`: Extracts recipients from .msg files
- `Extract-RecipientsFromRawEmail`: Parses RFC 2822 email text
- `Resolve-UserViaGAL` (Line 323): Outlook Global Address List lookup
- `Get-UserFromContacts` (Line 379): Outlook Contacts folder lookup
- `Get-UserFromADSI` (Line 423): Active Directory LDAP lookup
- `Lookup-User` (Line 504): Orchestrator with fallback chain (GAL → Contacts → ADSI)

**Lookup Chain**:
1. Try Outlook Global Address List
2. Try Outlook Contacts folder
3. Try Active Directory ADSI

---

## Reservations Modules

### Phase 2: Core CRUD Module

**File**: `TrackSessions.Reservations.psm1`

**Exported Functions** (Lines 1013-1023):

#### Settings & Users
1. `Get-ReservationSettings` (Line 18): Load reservation config
2. `Get-UserDatabase` (Line 71): Load users for permission checks

#### Permission Checks
3. `Test-ReservationEditPermission` (Line 106): Owner or admin can edit
   - Parameters: ReservationObject, CurrentUserId, UsersJsonPath
   - Returns: Boolean
   - Logic: Current user is owner OR IsAdmin flag set

4. `Test-ReservationConflict` (Line 149): Detect overlapping reservations
   - Parameters: MachineName, Date, StartTime, EndTime, ExcludeReservationId
   - Returns: Boolean (true if conflict exists)
   - Checks: Same machine, same date, time overlap

#### CRUD Operations
5. `New-Reservation` (Line 254): Create reservation with validation
   - Creates `.json` file
   - Creates `.html` file for viewing
   - Validates permissions
   - Checks for conflicts (if enabled)
   - Returns: @{ Success = Boolean; Message = String; Reservation = Object }

6. `Get-Reservations` (Line 435): Query reservations with filters
   - Parameters: MachineName, UserId, DateFrom, DateTo, Status
   - Returns: Array of reservation objects
   - Supports multiple filter combinations

7. `Update-Reservation` (Line 522): Modify existing reservation
   - Permission check (owner or admin)
   - Conflict check (if enabled)
   - Updates JSON + HTML files
   - Returns: @{ Success = Boolean; Message = String }

8. `Cancel-Reservation` (Line 593): Mark as cancelled
   - Permission check (owner or admin)
   - Renames file: `.Active.json` → `.CANCELLED.json`
   - Records cancellation metadata
   - Returns: @{ Success = Boolean; Message = String }

#### HTML Rendering
9. `ConvertTo-ReservationHtml` (Line 661): Generate HTML view
   - Embedded CSS
   - Displays all reservation details
   - Timestamps in local time

### Reservation File Naming Convention
```
Reservation.{Machine}.{User}.{yyyyMMdd}.{HHmmss_Start}.{HHmmss_End}.Active.json

Example:
Reservation.NCT001MA4573619.LEEDA.20260920.090000.170000.Active.json
```

### Reservation Schema
```json
{
  "ReservationId": "guid-here",
  "MachineName": "NCT001MA4573619",
  "MachineFqdn": "NCT001MA4573619.irs.gov",
  "UserId": "LEEDA",
  "UserDisplayName": "Davis Lee",
  "UserEmail": "davis.lee@irs.gov",
  "ReservationDate": "2026-09-20",
  "StartTime": "09:00",
  "EndTime": "17:00",
  "Duration": 480,
  "Status": "Active",
  "CreatedAtGmt": "2026-09-19T22:00:00Z",
  "LastModifiedAtGmt": "2026-09-19T22:00:00Z",
  "Comments": "Project testing",
  "OverrideWarning": false,
  "CancelledAtGmt": null,
  "CancelledByUserId": null,
  "CancellationReason": null
}
```

### Phase 3: Outlook Calendar Integration

**File**: `TrackSessions.Reservations.Outlook.psm1`

**Exported Functions** (Lines 699-709):

1. `Initialize-OutlookConnection` (Line 24): Create Outlook COM object
   - Rate limiting to prevent overwhelming COM
   - Returns: Outlook.Application object or $null

2. `Get-OutlookCalendar` (Line 68): Get MAPI calendar folder
   - Parameters: OutlookApp
   - Returns: Calendar folder object

3. `New-OutlookReservationEvent` (Line 127): Create calendar appointment
   - Parameters: OutlookApp, Reservation
   - Creates appointment with:
     - Subject: "Reserved: {MachineName}"
     - Location: {MachineName}
     - Start/End times
     - Reminder: 15 minutes before
     - Body: Reservation details
   - Returns: @{ Success = Boolean; Message = String }

4. `Remove-OutlookReservationEvent` (Line 230): Delete calendar event
   - Searches calendar for matching reservation
   - Deletes appointment if found
   - Returns: @{ Success = Boolean; Message = String }

5. `Send-ReservationNotification` (Line 288): Send HTML email
   - Parameters: OutlookApp, Reservation, NotificationType (New/Updated/Cancelled)
   - Includes .ics attachment for calendar import
   - Recipients from settings (NotificationRecipients)
   - Returns: @{ Success = Boolean; Message = String }

6. `ConvertTo-IcsCalendarEvent` (Line 483): Generate RFC 5545 .ics file
   - Parameters: Reservation
   - Returns: iCalendar string
   - Includes: VEVENT, DTSTART, DTEND, SUMMARY, LOCATION, DESCRIPTION

7. `Get-NotificationRecipients` (Line 541): Load email distribution list
   - Reads from Settings.Reservations.NotificationRecipients
   - Returns: Array of email addresses

8. `New-ReservationWithOutlook` (Line 601): Wrapper function
   - Combines Phase 2 `New-Reservation` + Outlook integration
   - Creates reservation
   - Creates calendar event
   - Sends notification email
   - Returns: @{ Success = Boolean; Message = String; Reservation = Object }

9. `Close-OutlookConnection` (Line 681): Release COM object
   - Proper COM cleanup
   - Calls [System.Runtime.InteropServices.Marshal]::ReleaseComObject

**Features**:
- Graceful fallback if Outlook unavailable
- HTML email notifications with embedded CSS
- iCalendar attachment for calendar import
- COM object cleanup on module unload

### Phase 4: Calendar UI

**File**: `TrackSessions.Reservations.CalendarDialog.ps1`  
**Lines**: 1-100+  
**Description**: WPF calendar-based reservation management dialog.

**Key Functions**:
- `Get-TrackedMachines` (Line 49): Load machines from Settings.json
- `Load-AllReservations` (Line 70): Get all reservations from disk
- `Get-DayReservations` (Line 85): Filter reservations by date and machine

**Features**:
- Calendar grid with day buttons
- Display names under each date
- Conflict highlighting (color-coded)
- Auto-refresh timer (30-second interval)
- Machine selector dropdown
- Tooltip details on hover

**UI Elements**:
- Month/Year navigation
- Day buttons with reservation count
- Reservation list for selected day
- New/Edit/Cancel actions
- Light purple background (#F3E5F5) with dark purple border (#7B1FA2)

### Phase 6: Admin Settings Panel

**File**: `TrackSessions.Reservations.SettingsDialog.ps1`  
**Lines**: 1-100+  
**Description**: WPF settings management dialog for admin users.

**Requires**: `IsAdmin: true` flag in TrackSessions.Users.json

**Configurable Settings**:
- BusinessHoursStart (HH:mm)
- BusinessHoursEnd (HH:mm)
- TimeSlotGranularity (minutes)
- AllowPastDateReservations (checkbox)
- PreventOverlappingReservations (checkbox)
- NotificationRecipients (semicolon-separated emails)
- OutlookIntegrationEnabled (checkbox)

### Phase 7: Recurring Reservations

**File**: `TrackSessions.Reservations.Recurring.psm1`

**Exported Functions** (Lines 588-596):

1. `Get-RecurrencePatterns` (Line 18): Returns enum values
   - None, Daily, Weekly, Monthly

2. `Test-RecurrenceSettings` (Line 64): Validates recurrence parameters
   - Checks pattern validity
   - Validates date ranges
   - Validates occurrence limits

3. `Get-RecurrenceOccurrences` (Line 171): Generates occurrence dates
   - Parameters: Pattern, StartDate, EndDate, MaxOccurrences, DayOfWeek, DayOfMonth
   - Returns: Array of [DateTime] dates
   - Respects business hours and boundaries

4. `ConvertTo-ICalendarRRule` (Line 265): Creates RRULE string
   - For .ics calendar files
   - RFC 5545 compliant
   - Supports DAILY, WEEKLY, MONTHLY with BYDAY/BYMONTHDAY

5. `New-RecurringReservation` (Line 373): Creates reservation series
   - Creates multiple reservations
   - Adds `SeriesId` GUID to comments field
   - Links all occurrences
   - Returns: @{ Success = Boolean; Message = String; Reservations = Array }

6. `Remove-RecurringReservationSeries` (Line 479): Cancels entire series
   - Finds all reservations with matching SeriesId
   - Cancels each one
   - Returns count of cancelled reservations

7. `Skip-RecurrenceOccurrence` (Line 550): Cancels single occurrence
   - Cancels specific date in series
   - Other occurrences remain active

**Recurrence Patterns**:

**Daily**:
```powershell
New-RecurringReservation -Pattern Daily -MaxOccurrences 10
```

**Weekly** (specific day):
```powershell
New-RecurringReservation -Pattern Weekly -DayOfWeek Monday -EndDate "2026-12-31"
```

**Monthly** (specific day of month):
```powershell
New-RecurringReservation -Pattern Monthly -DayOfMonth 15 -MaxOccurrences 6
```

---

## Module Dependencies

### Dependency Graph
```
TrackSessions.ps1 (Main)
├── Read-TrackSessionsSettings
├── Save-TrackSessionsSettings
├── Get-CurrentUserContext
└── Show-EditSettingsDialog

TrackSessions.Simulator CR1.ps1
├── Get-CurrentUserContext (LDAP blocking)
├── Get-UserDisplayName (uses Users.json)
└── Test-IsCurrentUserAdmin (uses Users.json)

TrackSessions.UserEditor.ps1
├── Import-Users (loads Users.json)
├── Save-Users (saves Users.json)
├── Resolve-ExternalUserBySeid (CSV → AD → Graph)
└── Show-EditUserDialog (WPF UI)

TrackSessions.Reservations.psm1 (Phase 2)
├── Get-ReservationSettings (from Settings.json)
├── Get-UserDatabase (from Users.json)
├── Test-ReservationEditPermission
├── Test-ReservationConflict
├── New-Reservation
├── Get-Reservations
├── Update-Reservation
├── Cancel-Reservation
└── ConvertTo-ReservationHtml

TrackSessions.Reservations.Outlook.psm1 (Phase 3)
├── Initialize-OutlookConnection (Outlook COM)
├── Get-OutlookCalendar
├── New-OutlookReservationEvent
├── Remove-OutlookReservationEvent
├── Send-ReservationNotification
├── ConvertTo-IcsCalendarEvent
├── Get-NotificationRecipients
├── New-ReservationWithOutlook
└── Close-OutlookConnection

TrackSessions.Reservations.Recurring.psm