# TrackSessions Reservations System - Phase 1 Implementation

**Phase**: 1 - Data Model & Settings  
**Status**: ✅ Complete  
**Date**: 2026-09-09  

---

## Overview

Phase 1 establishes the foundation for the reservation system by:
1. Extending the settings schema with reservation configuration
2. Adding admin user tracking to the users database
3. Defining the reservation JSON data structure
4. Creating an HTML template for rich display

---

## Changes Made

### 1. TrackSessions.Settings.json Updates

#### New Section: `Tracking.ReservationPath` & `Tracking.ReservationAdmins`

```json
"Tracking": {
  "SharedPath": "",
  "Machines": [...],
  "ReservationPath": "",                    // NEW: UNC path for reservation files
  "ReservationAdmins": ["YMJNB"]           // NEW: Array of admin SEIDs
}
```

**Purpose**:
- `ReservationPath`: UNC path where all reservation JSON/HTML files are stored (separate from SharedPath)
- `ReservationAdmins`: List of user SEIDs who can edit any reservation (bypass ownership check)

**Example Value**:
```json
"ReservationPath": "\\\\fileserver\\shared\\TrackSessions\\Reservations\\"
```

---

#### New Section: `Reservations` Configuration

```json
"Reservations": {
  "Enabled": true,                         // Toggle feature on/off
  "BusinessHoursStart": "09:00",           // Start of business hours (HH:mm)
  "BusinessHoursEnd": "18:00",             // End of business hours (HH:mm)
  "TimeSlotGranularity": 30,               // Minutes (30 = 30-min increments)
  "AllowPastDateReservations": false,      // Prevent reserving past dates
  "PreventOverlappingReservations": false, // Warn instead of prevent (per requirements)
  "AutoRefreshIntervalSeconds": 30         // UI polling interval for calendar
}
```

**Defaults**:
- Business hours: 09:00-18:00 (configurable)
- Time slot increments: 30 minutes (9:00, 9:30, 10:00, etc.)
- Overlaps: Warned but allowed
- Past dates: Not allowed

---

#### New Section: `Outlook` Integration Settings

```json
"Outlook": {
  "Enabled": true,                         // Toggle Outlook features
  "CreateCalendarEvents": true,            // Create Outlook events on reservation
  "SendEmailNotifications": true,          // Email team on create/cancel
  "EmailDistributionList": [
    "davis.s.lee@irs.gov",
    "Richard.Patterson@irs.gov"            // Hardcoded recipient list
  ]
}
```

**Purpose**:
- Controls whether Outlook calendar events are created
- Manages email notifications to team
- Defines recipients for reservation notifications

---

### 2. TrackSessions.Users.json Updates

#### New Field: `IsAdmin`

Added to each user object:

```json
{
  "SEID": "YMJNB",
  "FirstName": "Davis",
  "LastName": "Lee",
  ...
  "IsAdmin": true         // NEW: Admin permissions flag
}
```

**Current Admin Status**:
- ✅ YMJNB (Davis Lee) — IsAdmin: **true**
- ❌ ABCD123 (Sample User) — IsAdmin: **false**
- ❌ bsypb (Richard Patterson) — IsAdmin: **false**

**Usage**:
- Admins in `Settings.Tracking.ReservationAdmins` can edit any reservation
- `IsAdmin` flag in Users.json matches ReservationAdmins list (advisory)
- Used by WPF UI to enable/disable edit buttons

---

### 3. Reservation JSON Schema (TrackSessions.Reservations.Schema.json)

**File Location**: `Sessions/TrackSessions.Reservations.Schema.json`

**File Naming Convention**:
```
Reservation.{MachineName}.{UserId}.{yyyyMMdd}.{HHmmss_StartTime}.{HHmmss_EndTime}.{Status}.json
```

**Example Filename**:
```
Reservation.PAWS66.YMJNB.20260910.100000.120000.Active.json
Reservation.PAWS66.YMJNB.20260910.100000.120000.Cancelled.json
```

**Core Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| SchemaVersion | string | Yes | "1.0" |
| ReservationId | string | Yes | Unique ID (GUID or timestamp-based) |
| MachineName | string | Yes | Display name (e.g., "PAWS 66") |
| MachineShortName | string | Yes | From Settings.Tracking.Machines[].ShortName |
| MachineFqdn | string | No | From Settings.Tracking.Machines[].FQDN |
| UserId | string | Yes | SEID of reserving user (e.g., "YMJNB") |
| UserDisplayName | string | Yes | Full name (e.g., "Davis Lee") |
| UserEmail | string | Yes | Email address |
| ReservationDate | string | Yes | yyyy-MM-dd format (e.g., "2026-09-10") |
| StartTime | string | Yes | HH:mm format (e.g., "10:00") |
| EndTime | string | Yes | HH:mm format (e.g., "12:00") |
| CreatedAtGmt | string | Yes | ISO-8601 UTC timestamp |
| LastModifiedAtGmt | string | Yes | ISO-8601 UTC timestamp |
| Status | string | Yes | "Active" or "Cancelled" |
| Comments | string | No | User notes (max 500 chars) |
| Purpose | string | No | Categorization (e.g., "Testing", "Maintenance") |
| OverrideWarning | boolean | No | True if user accepted overlap conflict |
| ConflictingReservations | array | No | IDs of conflicting reservations (if override=true) |
| ApprovalRequested | boolean | No | True if admin approval pending (reserved for future) |
| CancelledAtGmt | string | No | Cancellation timestamp |
| CancelledByUserId | string | No | SEID of who cancelled |
| CancellationReason | string | No | Why was it cancelled (max 500 chars) |

**Complete Example (Active)**:
```json
{
  "SchemaVersion": "1.0",
  "ReservationId": "res-20260909-143045-123",
  "MachineName": "PAWS 66",
  "MachineShortName": "PAWS 66",
  "MachineFqdn": "mtb012vp0030366.ds.irsnet.gov",
  "UserId": "YMJNB",
  "UserDisplayName": "Davis Lee",
  "UserEmail": "davis.s.lee@irs.gov",
  "ReservationDate": "2026-09-10",
  "StartTime": "10:00",
  "EndTime": "12:00",
  "CreatedAtGmt": "2026-09-09T14:30:45.123Z",
  "CreatedByUserId": "YMJNB",
  "LastModifiedAtGmt": "2026-09-09T14:30:45.123Z",
  "LastModifiedByUserId": "YMJNB",
  "Status": "Active",
  "Comments": "Testing SharePoint migration impact on PAWS machine",
  "Purpose": "Testing",
  "OverrideWarning": false
}
```

**Cancelled Example**:
```json
{
  ...same as above...
  "Status": "Cancelled",
  "LastModifiedAtGmt": "2026-09-09T15:00:00.456Z",
  "LastModifiedByUserId": "YMJNB",
  "CancelledAtGmt": "2026-09-09T15:00:00.456Z",
  "CancelledByUserId": "YMJNB",
  "CancellationReason": "Testing completed early, machine available again"
}
```

---

### 4. HTML Template for Reservation Display (TrackSessions.Reservations.Template.html)

**File Location**: `Sessions/TrackSessions.Reservations.Template.html`

**Features**:
- ✅ Responsive design (mobile + desktop)
- ✅ Print-friendly CSS
- ✅ Color-coded status badges (Active/Cancelled)
- ✅ Embedded CSS (no external dependencies)
- ✅ JavaScript `populateReservationData()` function to populate from JSON
- ✅ Support for embedded JSON via `<script type="application/json">` tag

**Sections**:
1. **Header** — Reservation title + status badge
2. **Reservation Details** — Machine name, user, email
3. **Time Slot** — Date, start/end times, duration
4. **Purpose & Notes** — Purpose category, comments
5. **Metadata** — Reservation ID, dates, FQDN
6. **Cancellation Info** — Shows only if Status="Cancelled"
7. **Footer** — Generation timestamp

**Usage Example** (embedded JSON):
```html
<html>
  <body>
    <!-- HTML content from template -->
    <script type="application/json">
    {
      "SchemaVersion": "1.0",
      "ReservationId": "res-20260909-143045-123",
      ...
    }
    </script>
  </body>
</html>
```

**Print Preview**: CSS includes `@media print` rules for clean printing

---

## Configuration Steps for Admins

### Step 1: Set ReservationPath

1. Open TrackSessions.Settings.json
2. Find `Tracking.ReservationPath` and set to UNC path:
   ```json
   "ReservationPath": "\\\\fileserver\\shared\\TrackSessions\\Reservations\\"
   ```
3. Verify path is accessible with read/write permissions
4. Create subdirectories if needed

### Step 2: Configure Admins

1. Add SEIDs to `Tracking.ReservationAdmins`:
   ```json
   "ReservationAdmins": ["YMJNB", "bsypb"]
   ```
2. Update matching users in TrackSessions.Users.json with `IsAdmin: true`

### Step 3: Configure Outlook

1. Set email distribution list in `Outlook.EmailDistributionList`:
   ```json
   "EmailDistributionList": [
     "team-name@irs.gov",
     "admin@irs.gov"
   ]
   ```
2. Enable/disable calendar events: `"CreateCalendarEvents": true`
3. Enable/disable email notifications: `"SendEmailNotifications": true`

### Step 4: Adjust Business Hours (Optional)

```json
"Reservations": {
  "BusinessHoursStart": "08:00",
  "BusinessHoursEnd": "17:00",
  "TimeSlotGranularity": 15
}
```

---

## Files Created/Modified

### Created
- ✅ `TrackSessions.Reservations.Schema.json` — JSON schema + examples
- ✅ `TrackSessions.Reservations.Template.html` — HTML reservation display template
- ✅ `TrackSessions.Reservations.Phase1.md` — This documentation

### Modified
- ✅ `TrackSessions.Settings.json` — Added Tracking.ReservationPath, ReservationAdmins, Reservations, Outlook sections
- ✅ `TrackSessions.Users.json` — Added IsAdmin field to all users

---

## Testing Phase 1 Foundation

### ✅ Verification Steps

1. **Settings Load/Validate**
   ```powershell
   $settings = Get-Content .\TrackSessions.Settings.json | ConvertFrom-Json
   $settings.Reservations.Enabled                    # Should be: true
   $settings.Tracking.ReservationPath                # Should be: empty (set by admin)
   $settings.Tracking.ReservationAdmins              # Should be: @("YMJNB")
   ```

2. **Users Schema**
   ```powershell
   $users = Get-Content .\TrackSessions.Users.json | ConvertFrom-Json
   $users[1].IsAdmin                                 # Should be: true (YMJNB)
   ```

3. **JSON Schema Validation**
   - Open `TrackSessions.Reservations.Schema.json` in VS Code
   - Verify structure has SchemaDefinition, Example, ExampleCancelled sections

4. **HTML Template**
   - Open `TrackSessions.Reservations.Template.html` in browser
   - Should display with placeholder data
   - Test responsive design by resizing window
   - Test print preview (Ctrl+P)

---

## Next Phase (Phase 2)

Once Phase 1 is validated, Phase 2 will implement:
- `TrackSessions.Reservations.psm1` — Core PowerShell module with CRUD functions
- `New-Reservation`, `Get-Reservations`, `Update-Reservation`, `Cancel-Reservation`
- `Test-ReservationConflict` — Conflict detection logic
- Atomic file writes + error handling
- Permission validation (owner vs admin vs read-only)

---

## Success Criteria for Phase 1

- ✅ Settings.json contains all Reservation + Outlook configuration
- ✅ Users.json has IsAdmin field on all users
- ✅ ReservationAdmins list matches IsAdmin users
- ✅ JSON schema is well-documented with examples
- ✅ HTML template renders correctly and is responsive
- ✅ JavaScript function can populate template from JSON data
- ✅ No JSON validation errors in IDE

---

## Notes for Phase 2 Developers

When creating the reservation module (Phase 2), remember:

1. **File Naming**: Use the naming convention exactly:
   ```
   Reservation.{MachineName}.{UserId}.{yyyyMMdd}.{HHmmss_Start}.{HHmmss_End}.{Status}.json
   ```

2. **Status in Filename**: Keep status in filename for easy browsing:
   - `...Active.json` → Active reservation
   - `...Cancelled.json` → Cancelled reservation

3. **Atomic Writes**: Use PowerShell's `Out-File -Encoding UTF8 -Force` with lock handling

4. **Validation Priority**:
   - Check machine exists in Settings.Tracking.Machines
   - Check user exists in Users.json
   - Check time slot is within business hours
   - Check for conflicts (warn, don't block)
   - Check permissions (owner/admin only for edits)

5. **Timestamps**: Always use ISO-8601 UTC format (`yyyy-MM-ddTHH:mm:ss.fffZ`)

6. **Permission Model**:
   - **Owner**: Can always edit/cancel own reservation
   - **Admin** (in ReservationAdmins): Can edit any reservation
   - **Others**: Read-only access

---

## Appendix: Schema Version & Evolution

**Current Version**: 1.0

**Future Enhancement Considerations** (Phase 2+):
- 1.1 — Add recurring/multi-day reservations
- 1.2 — Add approval workflow (ApprovalRequested field)
- 1.3 — Add team/group reservations
- 1.4 — Add calendar color customization

Always maintain backward compatibility when incrementing versions.
