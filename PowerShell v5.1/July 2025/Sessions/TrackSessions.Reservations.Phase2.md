# TrackSessions.Reservations - Phase 2 Implementation
## Core Reservation Management Module

**Date**: September 9, 2026  
**Status**: ✅ Complete  
**Module File**: `TrackSessions.Reservations.psm1`

---

## Overview

Phase 2 implements the **core reservation management engine** with full CRUD operations, conflict detection, permission validation, and atomic file handling. This module is the foundation for all subsequent phases (UI, Outlook integration, calendar views).

---

## Module Functions

### Core CRUD Operations

#### **1. New-Reservation**
Creates a new reservation with complete validation.

**Signature**:
```powershell
New-Reservation -MachineName <string> -UserId <string> -UserDisplayName <string> 
                -UserEmail <string> -ReservationDate <yyyy-MM-dd> -StartTime <HH:mm> 
                -EndTime <HH:mm> -ReservationPath <string> -SettingsPath <string> 
                -UsersPath <string> [-MachineFqdn <string>] [-Comments <string>] 
                [-OverrideWarning <bool>]
```

**Validation Rules**:
- ✅ Time format validation (HH:mm, yyyy-MM-dd)
- ✅ Start < End validation
- ✅ Business hours check (default 09:00-18:00)
- ✅ Time slot granularity alignment (default 30-minute slots)
- ✅ Conflict detection with existing reservations
- ✅ Admin override permission check
- ✅ Atomic file write (temp → rename)

**Output**:
```powershell
@{
    ReservationId = "guid-here"
    JsonFile = "Reservation.PAWS01.YMJNB.20260915.100000.110000.Active.json"
    HtmlFile = "Reservation.PAWS01.YMJNB.20260915.100000.110000.Active.html"
    CreatedAt = "2026-09-09T14:30:45.123Z"
}
```

**Example**:
```powershell
$reservation = New-Reservation `
    -MachineName 'PAWS01' `
    -UserId 'YMJNB' `
    -UserDisplayName 'Davis Lee' `
    -UserEmail 'davis@example.com' `
    -ReservationDate '2026-09-15' `
    -StartTime '10:00' `
    -EndTime '11:00' `
    -Comments 'Debugging issue' `
    -ReservationPath '\\share\reservations' `
    -SettingsPath 'C:\config\TrackSessions.Settings.json' `
    -UsersPath 'C:\config\TrackSessions.Users.json'
```

#### **2. Get-Reservations**
Queries reservations with multiple filter options.

**Signature**:
```powershell
Get-Reservations -ReservationPath <string> [-MachineName <string>] [-UserId <string>]
                 [-ReservationDate <string>] [-StartDate <string>] [-EndDate <string>]
                 [-Status <string>]
```

**Filter Options**:
- `MachineName`: Single machine filter
- `UserId`: Single user filter
- `ReservationDate`: Exact date match (yyyy-MM-dd)
- `StartDate` / `EndDate`: Date range (inclusive)
- `Status`: 'Active' (default), 'Cancelled', or '*' for all

**Output**: Array of reservation objects from JSON files

**Examples**:
```powershell
# Get all active reservations for a machine
$paws01 = Get-Reservations -ReservationPath '\\share\reservations' -MachineName 'PAWS01'

# Get all user's reservations (past and current)
$myRes = Get-Reservations -ReservationPath '\\share\reservations' -UserId 'YMJNB' -Status '*'

# Get reservations in date range
$nextWeek = Get-Reservations -ReservationPath '\\share\reservations' `
    -StartDate '2026-09-15' -EndDate '2026-09-21'
```

#### **3. Update-Reservation**
Modifies reservation details (owner and admin only).

**Signature**:
```powershell
Update-Reservation -ReservationFile <string> -UserId <string> [-StartTime <string>]
                   [-EndTime <string>] [-Comments <string>] -ReservationAdmins <string[]>
                   -SettingsPath <string>
```

**Permissions**:
- ✅ Owner can update own reservation
- ✅ Admin can update any reservation
- ❌ Others: Access denied

**Example**:
```powershell
$updated = Update-Reservation `
    -ReservationFile '\\share\reservations\Reservation.PAWS01.YMJNB.20260915.100000.110000.Active.json' `
    -UserId 'YMJNB' `
    -Comments 'Meeting moved to 11:00' `
    -ReservationAdmins @('YMJNB', 'BSYPB') `
    -SettingsPath 'C:\config\TrackSessions.Settings.json'
```

#### **4. Cancel-Reservation**
Marks reservation as cancelled and renames file.

**Signature**:
```powershell
Cancel-Reservation -ReservationFile <string> -UserId <string> -ReservationAdmins <string[]>
                   [-CancellationReason <string>]
```

**Actions**:
- ✅ Renames file from `.Active` to `.CANCELLED`
- ✅ Sets Status = 'Cancelled' in JSON
- ✅ Records cancellation timestamp and user
- ✅ Updates HTML to show cancellation details
- ✅ Permission check (owner or admin only)

**Example**:
```powershell
Cancel-Reservation `
    -ReservationFile '\\share\reservations\Reservation.PAWS01.YMJNB.20260915.100000.110000.Active.json' `
    -UserId 'YMJNB' `
    -CancellationReason 'Need to use different machine' `
    -ReservationAdmins @('YMJNB')
```

---

### Validation & Permission Functions

#### **5. Test-ReservationConflict**
Detects overlapping reservations on same machine and date.

**Signature**:
```powershell
Test-ReservationConflict -MachineName <string> -ReservationDate <string> 
                        -StartTime <string> -EndTime <string> 
                        -ReservationPath <string>
```

**Output**:
```powershell
@{
    HasConflict = $true/$false
    ConflictingReservations = @(
        @{
            FileName = "Reservation.PAWS01.USER2.20260915.110000.120000.Active.json"
            MachineName = "PAWS01"
            StartTime = "11:00"
            EndTime = "12:00"
        }
    )
}
```

**Example**:
```powershell
$conflict = Test-ReservationConflict `
    -MachineName 'PAWS01' `
    -ReservationDate '2026-09-15' `
    -StartTime '10:00' `
    -EndTime '11:00' `
    -ReservationPath '\\share\reservations'

if ($conflict.HasConflict) {
    Write-Host "Conflicts found:"
    $conflict.ConflictingReservations | ForEach-Object {
        Write-Host "  - $($_.FileName): $($_.StartTime) - $($_.EndTime)"
    }
}
```

#### **6. Test-ReservationEditPermission**
Validates if user can edit a reservation.

**Signature**:
```powershell
Test-ReservationEditPermission -CurrentUserId <string> -ReservationOwnerId <string>
                              -Users <object[]> -ReservationAdmins <string[]>
```

**Permission Rules**:
1. **Owner** (CurrentUserId == ReservationOwnerId) → **Can Edit** ✅
2. **Admin** (CurrentUserId in ReservationAdmins) → **Can Edit** ✅
3. **Other** → **Read-Only** ❌

**Example**:
```powershell
if (Test-ReservationEditPermission -CurrentUserId 'YMJNB' `
    -ReservationOwnerId 'ABCD123' -Users $users -ReservationAdmins @('YMJNB')) {
    Write-Host "Permission granted to edit"
}
```

---

### Utility Functions

#### **7. Get-ReservationSettings**
Loads reservation configuration from Settings.json.

**Output**: Reservations section:
```json
{
  "Enabled": true,
  "BusinessHoursStart": "09:00",
  "BusinessHoursEnd": "18:00",
  "TimeSlotGranularity": 30,
  "AllowPastDateReservations": false,
  "PreventOverlappingReservations": false,
  "AutoRefreshIntervalSeconds": 30
}
```

#### **8. Get-UserDatabase**
Loads user database from Users.json for permission checks.

#### **9. ConvertTo-ReservationHtml**
Generates responsive HTML from reservation data.

**Features**:
- ✅ Responsive design (mobile-friendly)
- ✅ Status badges (Active=green, Cancelled=red)
- ✅ Embedded CSS (no external dependencies)
- ✅ Embedded JSON data for JavaScript rendering
- ✅ Print-friendly styles
- ✅ Metadata table with timestamps
- ✅ Cancellation details section (if cancelled)

---

## File Naming Convention

All reservation files follow the strict pattern:

```
Reservation.{MachineName}.{UserId}.{yyyyMMdd}.{HHmmss_Start}.{HHmmss_End}.{Status}.json
Reservation.{MachineName}.{UserId}.{yyyyMMdd}.{HHmmss_Start}.{HHmmss_End}.{Status}.html
```

**Example**:
```
Reservation.PAWS01.YMJNB.20260915.100000.110000.Active.json
Reservation.PAWS01.YMJNB.20260915.100000.110000.Active.html

Reservation.PAWS02.ABCD123.20260916.140000.150000.CANCELLED.json
Reservation.PAWS02.ABCD123.20260916.140000.150000.CANCELLED.html
```

---

## JSON Data Structure

**Active Reservation**:
```json
{
  "ReservationId": "550e8400-e29b-41d4-a716-446655440000",
  "MachineName": "PAWS01",
  "MachineShortName": "PAWS01",
  "MachineFqdn": "paws01.irsqa.irs.gov",
  "UserId": "YMJNB",
  "UserDisplayName": "Davis Lee",
  "UserEmail": "davis.lee@irs.gov",
  "ReservationDate": "2026-09-15",
  "StartTime": "10:00",
  "EndTime": "11:00",
  "Duration": "60 minutes",
  "CreatedAtGmt": "2026-09-09T14:30:45.123Z",
  "LastModifiedAtGmt": "2026-09-09T14:30:45.123Z",
  "Status": "Active",
  "Comments": "Debugging production issue",
  "OverrideWarning": false,
  "CancelledAtGmt": null,
  "CancelledByUserId": null,
  "CancellationReason": null
}
```

**Cancelled Reservation**:
```json
{
  "ReservationId": "550e8400-e29b-41d4-a716-446655440001",
  "MachineName": "PAWS02",
  ...
  "Status": "Cancelled",
  "CancelledAtGmt": "2026-09-09T15:45:30.456Z",
  "CancelledByUserId": "YMJNB",
  "CancellationReason": "Schedule conflict"
}
```

---

## Error Handling

All functions include comprehensive error handling:

| Error | Cause | Resolution |
|-------|-------|------------|
| "Invalid date format. Expected yyyy-MM-dd" | Bad date | Use yyyy-MM-dd format |
| "Invalid start time format. Expected HH:mm" | Bad time | Use HH:mm format (24-hour) |
| "Start time must be before end time" | StartTime >= EndTime | Swap times or increase duration |
| "Reservation outside business hours" | Time before 09:00 or after 18:00 | Adjust within business hours |
| "Times must align with 30-minute granularity" | Not on 30-min boundary | Use 09:00, 09:30, 10:00, etc. |
| "Reservation conflicts with existing bookings" | Overlap detected | Use OverrideWarning=$true if admin |
| "Only admins can override conflicts" | Non-admin attempted override | Use admin account or pick different time |
| "Permission denied: User X cannot edit" | Non-owner, non-admin | Must be owner or admin to edit |
| "Reservation file not found" | File deleted or wrong path | Verify file path and existence |

---

## Business Logic

### Time Slot Validation
1. **Format**: HH:mm (24-hour format)
2. **Granularity**: 30-minute slots (09:00, 09:30, 10:00, ...)
3. **Business Hours**: 09:00-18:00 (configurable)
4. **Duration**: Minimum 30 minutes, maximum until end of business hours

### Conflict Detection
- Checks for **overlaps** on same machine, same date, same status (Active only)
- Allows admin override with `OverrideWarning=$true`
- Non-admins cannot override

### Permission Model
| Role | View Own | Edit Own | View Others | Edit Others | Override Conflicts |
|------|----------|----------|-------------|-------------|-------------------|
| Owner | ✅ | ✅ | ❌ | ❌ | ❌ |
| Admin | ✅ | ✅ | ✅ | ✅ | ✅ |
| Other | ❌ | ❌ | ❌ | ❌ | ❌ |

### File Operations
- **Atomic writes**: Temp file → Rename (prevents corruption)
- **Paired files**: JSON (data) + HTML (view) created together
- **Cancellation**: Renames file from .Active to .CANCELLED (prevents re-activation)
- **Timestamps**: All in UTC (yyyy-MM-ddTHH:mm:ss.fffZ)

---

## Usage Examples

### Complete Reservation Workflow

```powershell
# 1. Create a reservation
$reservation = New-Reservation `
    -MachineName 'PAWS01' `
    -UserId 'YMJNB' `
    -UserDisplayName 'Davis Lee' `
    -UserEmail 'davis.lee@irs.gov' `
    -ReservationDate '2026-09-15' `
    -StartTime '10:00' `
    -EndTime '11:00' `
    -Comments 'Team meeting' `
    -ReservationPath '\\irs-reserve\reservations' `
    -SettingsPath 'C:\config\TrackSessions.Settings.json' `
    -UsersPath 'C:\config\TrackSessions.Users.json'

Write-Host "Created: $($reservation.ReservationId)"

# 2. View reservation
$res = Get-Reservations -ReservationPath '\\irs-reserve\reservations' `
    -MachineName 'PAWS01' -ReservationDate '2026-09-15' | Select-Object -First 1
Write-Host "$($res.UserDisplayName) reserved $($res.MachineName) from $($res.StartTime) to $($res.EndTime)"

# 3. Update reservation
$updated = Update-Reservation `
    -ReservationFile "\\irs-reserve\reservations\$($reservation.JsonFile)" `
    -UserId 'YMJNB' `
    -Comments 'Team meeting (location changed to Conference Room B)' `
    -ReservationAdmins @('YMJNB') `
    -SettingsPath 'C:\config\TrackSessions.Settings.json'

# 4. Cancel reservation
Cancel-Reservation `
    -ReservationFile "\\irs-reserve\reservations\$($reservation.JsonFile)" `
    -UserId 'YMJNB' `
    -CancellationReason 'Meeting cancelled' `
    -ReservationAdmins @('YMJNB')
```

---

## Configuration Integration

### Required Settings.json Sections
```json
{
  "Reservations": {
    "Enabled": true,
    "BusinessHoursStart": "09:00",
    "BusinessHoursEnd": "18:00",
    "TimeSlotGranularity": 30,
    "AllowPastDateReservations": false,
    "PreventOverlappingReservations": false,
    "AutoRefreshIntervalSeconds": 30
  },
  "Tracking": {
    "ReservationPath": "\\\\irs-reserve\\reservations",
    "ReservationAdmins": ["YMJNB", "BSYPB"]
  }
}
```

### Required Users.json Fields
```json
[
  {
    "SEID": "YMJNB",
    "FirstName": "Davis",
    "LastName": "Lee",
    "IsAdmin": true,
    ...other fields...
  }
]
```

---

## Testing Phase 2

### Test 1: Create Reservation
```powershell
# Should succeed: Valid times within business hours
$res = New-Reservation -MachineName 'TEST01' -UserId 'YMJNB' `
    -UserDisplayName 'Test User' -UserEmail 'test@example.com' `
    -ReservationDate '2026-09-20' -StartTime '10:00' -EndTime '11:00' `
    -ReservationPath 'C:\temp\reservations' `
    -SettingsPath 'C:\config\TrackSessions.Settings.json' `
    -UsersPath 'C:\config\TrackSessions.Users.json'

# Should fail: Outside business hours
$res = New-Reservation -MachineName 'TEST01' -UserId 'YMJNB' `
    -UserDisplayName 'Test User' -UserEmail 'test@example.com' `
    -ReservationDate '2026-09-20' -StartTime '08:00' -EndTime '09:00' `
    -ReservationPath 'C:\temp\reservations' `
    -SettingsPath 'C:\config\TrackSessions.Settings.json' `
    -UsersPath 'C:\config\TrackSessions.Users.json'
```

### Test 2: Conflict Detection
```powershell
# Create first reservation
$res1 = New-Reservation -MachineName 'TEST02' -UserId 'USER1' `
    -UserDisplayName 'User One' -UserEmail 'user1@example.com' `
    -ReservationDate '2026-09-20' -StartTime '10:00' -EndTime '11:00' ...

# Try to create overlapping as non-admin (should fail)
$res2 = New-Reservation -MachineName 'TEST02' -UserId 'USER2' `
    -UserDisplayName 'User Two' -UserEmail 'user2@example.com' `
    -ReservationDate '2026-09-20' -StartTime '10:30' -EndTime '11:30' ...
    # Error: "Reservation conflicts with existing bookings"

# Create overlapping as admin with override (should succeed)
$res3 = New-Reservation -MachineName 'TEST02' -UserId 'YMJNB' `
    -UserDisplayName 'Admin User' -UserEmail 'admin@example.com' `
    -ReservationDate '2026-09-20' -StartTime '10:30' -EndTime '11:30' `
    -OverrideWarning $true ...
    # Success!
```

### Test 3: Permission Checks
```powershell
# Owner can update own (should succeed)
Update-Reservation -ReservationFile $res1JsonFile -UserId 'USER1' `
    -Comments 'Updated' -ReservationAdmins @('YMJNB') ...

# Non-owner cannot update (should fail)
Update-Reservation -ReservationFile $res1JsonFile -UserId 'USER2' `
    -Comments 'Updated' -ReservationAdmins @('YMJNB') ...
    # Error: "Permission denied"

# Admin can update any (should succeed)
Update-Reservation -ReservationFile $res1JsonFile -UserId 'YMJNB' `
    -Comments 'Admin updated' -ReservationAdmins @('YMJNB') ...
```

---

## Next Steps (Phase 3)

Phase 3 will add **Outlook Integration**:
- Create Outlook calendar events from reservations
- Send email notifications to team
- Handle Outlook unavailability gracefully

See: `TrackSessions.Exploration.Reserve.Plan.md` Phase 3 section

---

## Dependencies

- PowerShell 5.1+
- .NET Framework (ConvertTo-Json, ConvertFrom-Json)
- UNC path access (for shared reservation storage)
- Windows file system (for atomic rename operations)

---

## Performance Notes

- **Conflict Detection**: O(n) where n = reservations on same date
- **Query Performance**: Filtered by filename pattern first, then JSON parsing
- **File Operations**: Atomic (no risk of partial writes)
- **Memory**: Entire file loaded into memory (typical reservation = ~2KB)

---

## Known Limitations

1. **No recurring reservations** (Phase 2 scope) - Future enhancement
2. **No approval workflow** (Phase 2 scope) - Future enhancement
3. **Conflict detection only within same date** - Design choice (prevents 24-hour lookups)
4. **No soft-delete** - Cancelled reservations remain in filesystem for audit trail

---

## Module Export

The module exports these functions:
```powershell
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
```

---

## Phase 2 Completion Checklist

- ✅ Created TrackSessions.Reservations.psm1 module
- ✅ Implemented New-Reservation with full validation
- ✅ Implemented Get-Reservations with filtering
- ✅ Implemented Update-Reservation with permissions
- ✅ Implemented Cancel-Reservation with audit trail
- ✅ Implemented Test-ReservationConflict with overlap detection
- ✅ Implemented Test-ReservationEditPermission with role model
- ✅ Implemented ConvertTo-ReservationHtml with responsive design
- ✅ Implemented atomic file operations (no corruption risk)
- ✅ Created comprehensive documentation
- ✅ Defined error handling strategy
- ✅ Defined business logic rules
- ✅ Ready for Phase 3: Outlook Integration

**Phase 2 Status**: ✅ **PRODUCTION READY**
