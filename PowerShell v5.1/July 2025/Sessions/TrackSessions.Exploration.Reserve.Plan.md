# TrackSessions Codebase Exploration

## Current Structure Overview

### Main Entry Points
- **TrackSessions.ps1** (primary WPF application)
- **TrackSessions.UserEditor.ps1** (user data management WPF)
- **TrackSessions.Simulator CR1.ps1** (testing/validation)
- **TrackSessions.UserEditor.Lookup-SEID.CLI.ps1** (CLI SEID resolver)

### Settings & Configuration Files
- **TrackSessions.Settings.json** — Main settings file
- **TrackSessions.Users.json** — User database
- **TrackSessions.Users.External.csv** — External user lookup reference

## Current Data Structures

### TrackSessions.Settings.json Schema
```
{
  SchemaVersion: "1.0",
  MiniWindow: {
    Left: double|null,
    Top: double|null
  },
  Layout: {
    BottomPaneHeight: double|null,
    WindowLeft: double|null,
    WindowTop: double|null,
    WindowWidth: double|null,
    WindowHeight: double|null
  },
  Tracking: {
    SharedPath: string (UNC path),
    Machines: [
      {
        ShortName: string (required),
        FQDN: string (optional),
        Comment: string (optional)
      }
    ]
  },
  StartupTrace: {
    Enabled: boolean,
    Events: [
      {
        TimestampUtc: string (ISO-8601),
        Event: string,
        Detail: string
      }
    ]
  }
}
```

### Session JSON Files
**Location**: `$env:ProgramData\SessionTracker\Json\` (default) or SharedPath (if configured)  
**Naming**: `Session.{MachineName}.{UserId}.{DisplayName}.{yyyyMMdd_HHmmssZ}.json`

**Schema**:
```
{
  SchemaVersion: "1.0",
  MachineName: string,
  SessionId: int,
  SessionName: string,
  UserId: string,
  UserDisplayName: string,
  UserEmail: string,
  CreatedAtGmt: string (ISO-8601),
  LastUpdatedAtGmt: string (ISO-8601),
  JsonFileName: string,
  SessionStatus: "Closed" | "Open" (optional),
  SessionCloseEvent: "WindowClosed" (optional),
  SessionClosedAtGmt: string (optional)
}
```

**Close Artifact**: `Session.{MachineName}.{UserId}.{DisplayName}.{yyyyMMdd_HHmmssZ}.Logout.json`

### User Data (TrackSessions.Users.json)
```
[
  {
    SEID: string (unique ID),
    FirstName: string,
    LastName: string,
    Status: "FTE" | "Contractor",
    IRSEmail: string,
    SEIDEmail: string,
    Timezone: string (predefined list),
    DaylightSavings: boolean,
    Products: [string] (SharePoint, Power Platform, OneDrive, Entra),
    LastLogin: string (ddd dd/MM/yyyy hh:mm format),
    LastPawsUsed: string (machine name),
    LastModified: string (ddd dd/MM/yyyy hh:mm format),
    Created: string (ddd dd/MM/yyyy hh:mm format)
  }
]
```

## Current Functionality

### WPF Main Application (TrackSessions.ps1)

**Main Window Features**:
- Session info display (Windows session, user ID, display name, email, machine, JSON folder, current file, last update)
- DataGrid showing activity on other machines (MachineName, UserId, UserDisplayName, LastLogin, LastActivity)
- Animated orange circle icon
- Resizable, responsive layout with mobile breakpoints
- 3-minute auto-update timer

**Control Buttons**:
- Zoom in/out (font scaling)
- Refresh Now (manual update)
- Copy (PowerShell object format)
- Edit Settings
- Minimize (to mini panel)
- Close After Session

**Mini Window**:
- Floating panel with machine/user info
- Restore button to return to main window
- Position saved in settings

**Settings Dialog** (Show-EditSettingsDialog):
- Shared Path configuration (UNC browse/reveal)
- Tracked Machines grid (editable: ShortName, FQDN, Comment)
- Copy to Clipboard (PowerShell object format)
- Save & Close, Cancel buttons
- Zoom in/out

### Logging/Status Mechanism
- **StartupTrace**: Event log in Settings.json with UTC timestamps
- **Session JSON files**: Created at logon, updated every 3 minutes
- **Logout artifacts**: .Logout.json files created on window close
- **Max trace events**: 120 (older events purged)

### User Editor (TrackSessions.UserEditor.ps1)
- WPF dialog for editing user records
- Local JSON lookup (TrackSessions.Users.json)
- External lookup: CSV, Active Directory, Graph API (extensible)
- User field validation
- Date/time conversion (format: ddd dd/MM/yyyy hh:mm)

### Existing Lookup Logic
- **Local-first**: Checks TrackSessions.Users.json
- **CSV**: Optional external CSV lookup
- **Active Directory**: Optional AD integration
- **Graph**: Optional Microsoft Graph integration (not enabled)

## Shared Path Usage

**Purpose**: Central UNC location for session tracking output  
**Configuration**: Stored in Settings.Tracking.SharedPath  
**Current Usage**: Intended for JSON output (currently defaults to local $env:ProgramData)  
**File Format**: JSON session snapshots with ISO-8601 timestamps  

## Scheduled Task Integration
- **Parameter**: `-RegisterLogonTask` (creates Windows scheduled task)
- **Trigger**: ONLOGON event
- **Task Name**: "TrackSessionsWpf" (configurable)
- **Run Level**: LIMITED
- **Execution**: PowerShell with Bypass policy

## Key Functions & Patterns

### Core Helpers
- `Convert-ToSafeFileToken()` — Sanitizes file tokens (alphanumeric, dash, underscore)
- `Get-CurrentUserContext()` — Retrieves user identity (AD lookup with fallback)
- `Get-CurrentSessionName()` — Gets Windows session name via quser
- `Read-TrackSessionsSettings()` — Loads settings with defaults
- `Save-TrackSessionsSettings()` — Persists settings JSON
- `Append-StartupTrace()` — Adds UTC timestamped events to log

### Session Tracking
- `Write-SessionSnapshot()` — Creates initial session JSON
- `Write-SessionCloseArtifacts()` — Updates session status and creates .Logout.json
- `Get-SessionGridRows()` — Reads session files, filters by tracked machines, returns DataGrid rows

### Grid Display
- `New-OrangeCircleIconFrame()` — Renders animated icon bitmap

## Timezone & Date Handling
- User timezone stored as string (predefined list with UTC offsets)
- DaylightSavings boolean flag
- Date format: `ddd dd/MM/yyyy hh:mm` (e.g., "Mon 07/09/2026 09:15")
- Internal ISO-8601 for UTC timestamps: `yyyy-MM-ddTHH:mm:ss.fffZ`

## Currently NOT Implemented
- Calendar/scheduling logic
- Reservation/booking system
- Time slot blocking
- Availability calendars
- Recurring schedules
- Conflict detection

---

# Plan: Add Calendar & Reservation System to TrackSessions

## TL;DR
Add a calendar-based machine reservation system to TrackSessions that lets users reserve machines with custom time slots (start/end times) for a single day. Store reservations as paired JSON+HTML files in a separate `ReservationPath`, with status tracked in filenames and file contents. Include a WPF calendar dialog in TrackSessions plus an optional HTML browser view. Create Outlook events and email the team on new reservations. Owner + admins can modify/cancel; conflicts warn but allow override. Users can only view reservations through TrackSessions UI (not direct shared path browsing).

---

## Requirements Summary

| Aspect | Decision |
|--------|----------|
| Purpose | Informational (log planned activities, not enforce access blocking) |
| Storage | Separate `ReservationPath` subdirectory in settings (not same as SharedPath) |
| File Format | Paired JSON + HTML (JSON for data/filtering, HTML for rich display) |
| Time Slots | Custom time range per day (start/end times, e.g., 09:00-12:00) |
| UI | Both WPF dialog (integrated) and HTML browser view (rich UX) |
| Outlook | Write mode (create events + email team on new reservations) |
| Permissions | Owner can always edit own; admin list can edit any; others read-only |
| Conflicts | Warn user of overlaps but allow override (not hard block) |
| Cancellation | Rename file with .CANCELLED status AND set flag in JSON/HTML |
| Browsing | Only via TrackSessions UI (not direct path browsing) |

---

## Implementation Phases

### Phase 1: Data Model & Settings
**Deliverables:**
- Reservation JSON schema with custom time range support
- HTML template structure for rich display
- Update TrackSessions.Settings.json with:
  - `Tracking.ReservationPath` (new UNC path setting)
  - `Tracking.ReservationAdmins` (array of user IDs with edit rights)
  - `Outlook.EmailDistributionList` (team email recipients)
- Update TrackSessions.Users.json schema to include `IsAdmin` boolean flag

**Files to modify:**
- `Sessions/TrackSessions.Settings.json` — Add ReservationPath, ReservationAdmins, Outlook section
- `Sessions/TrackSessions.Users.json` — Add IsAdmin field to user schema

**Key decisions:**
- JSON schema includes: MachineId, UserId, UserDisplayName, StartTime, EndTime, ReservationDate, CreatedAtGmt, LastModifiedAtGmt, Status (Active|Cancelled), Comments, Approved (optional), OverrideWarning (boolean if user accepted conflict)
- HTML template uses embedded CSS for standalone rendering (no external dependencies)
- Naming convention: `Reservation.{MachineName}.{UserId}.{yyyyMMdd}.{HHmmss_StartTime}.{HHmmss_EndTime}.{Status}.json` and `.html`

---

### Phase 2: Core Reservation Management Functions
**Deliverables:**
- New PowerShell module: `TrackSessions.Reservations.psm1` with functions:
  - `New-Reservation` — Create JSON + HTML pair, validate time range
  - `Get-Reservations` — Query by machine, user, date, status
  - `Update-Reservation` — Modify existing (owner/admin only)
  - `Cancel-Reservation` — Rename file + set Cancelled status
  - `Test-ReservationConflict` — Check overlaps for date/machine, return conflicts
  - `Convert-ReservationToHtml` — Generate HTML from JSON
  - `Publish-ReservationFiles` — Write to ReservationPath with atomic writes

**Validations:**
- Time range: Start < End, both within business hours (9:00-18:00 default)
- Date: Not in past (optional: prevent past-day reservations)
- Machine: Must exist in Tracking.Machines list
- User: Must exist in Users.json
- Permissions: Check if requester is owner or admin

**Dependencies:**
- Reads: TrackSessions.Settings.json, TrackSessions.Users.json, Reservation files
- Writes: ReservationPath (paired JSON+HTML)

---

### Phase 3: Outlook Integration
**Deliverables:**
- Functions in `TrackSessions.Reservations.psm1`:
  - `New-OutlookEvent` — Create Outlook calendar event (COM-based, legacy API)
  - `Send-ReservationNotification` — Email team on new/cancelled reservations
  - `Get-OutlookAvailability` (optional) — Query existing events for conflict display

**Implementation Details:**
- Use Outlook.Application COM object (already available per user notes)
- Event title: `[RESERVED] {MachineName} - {UserId}`
- Event description: Include reservation JSON details (link to shared path file)
- Attendees: Distribution list from settings
- Invitations: Optional (send as update, not requiring RSVP)
- Error handling: Gracefully fail if Outlook not available; log to TrackSessions.Settings.StartupTrace

**Email template:**
- Subject: `[Reservation] {MachineName} reserved by {UserDisplayName} on {Date}`
- Body: Time slot, purpose (Comments field), Outlook event link
- Include .ICS attachment of calendar event

---

### Phase 4: WPF Calendar Dialog
**Deliverables:**
- New dialog: `Show-ReservationCalendarDialog`
- Display modes:
  - **Month view** (calendar grid, click date → show time slots)
  - **Day view** (when date selected, show hourly grid with existing reservations as blocks)
  - **List view** (scrollable list of all reservations for current machine, filter by user/status)

**UI Components:**
- Top: Machine selector (dropdown from Settings.Tracking.Machines)
- Left: Date picker (month/year navigation)
- Center: Calendar grid (month) or time slots (day) or list
- Right: Reservation details panel (show selected reservation, edit/cancel buttons if owner/admin)
- Buttons: New Reservation, View in Browser, Refresh, Close

**New Reservation Flow:**
1. Select machine, date, time range (start/end time picker with 30-min increments)
2. Optional: Add comments, request approval flag
3. Preview: Show conflict warnings with count
4. Confirm: Allow override if conflicts exist
5. Create: Write JSON+HTML, create Outlook event, send email
6. Result: Toast notification with success/failure

**Filtering:**
- Show only today's + future reservations by default
- Toggle: "Show past events" (optional archive view)
- Filter by: User, Status (Active|Cancelled)

**Refreshing:**
- Auto-refresh on file system changes (polling shared path every 30 seconds)
- Manual refresh button
- Timestamp shown: "Last updated: {time}"

---

### Phase 5: HTML Calendar Browser View
**Deliverables:**
- Standalone HTML file generator: `ConvertTo-ReservationHtml`
- Single-page HTML with embedded CSS + minimal JavaScript
- Display modes:
  - **Calendar view** (month or week)
  - **Day view** (hourly timeline with reservation blocks)
  - **Agenda view** (sorted list)

**Features:**
- Machine selector: Dropdown loads all machines
- Date range picker: Start/end date for filtering
- Color coding: Green (your reservation), Blue (other users), Red (conflicts), Gray (past)
- Hover tooltips: Show user, time, comments
- Click reservation: Show full details in overlay
- Responsive design: Works on desktop + tablet
- Print-friendly: CSS @media print styles

**Data Loading:**
- HTML includes embedded JSON data (for offline viewing)
- Optional: Fetch fresh data from ReservationPath if opened via UNC link
- Export options: Download as PDF, .ics calendar

---

### Phase 6: Settings & Admin UI
**Deliverables:**
- Update `Show-EditSettingsDialog` to add new tabs:
  - **Reservation Settings**: ReservationPath (browse/reveal buttons), enable/disable feature
  - **Admin Users**: List of admin usernames (add/remove), bulk import from AD group

**Components:**
- ReservationPath: TextBox + Browse button + UNC validation (ping path)
- Admin list: DataGrid with columns [Username, DisplayName, IsAdmin checkbox]
- Buttons: Add User (opens AD picker), Remove, Test Path, Save

**Validation:**
- ReservationPath must be valid UNC path (\\server\share\...)
- Must have read/write permissions
- Admin user must exist in TrackSessions.Users.json

---

### Phase 7: Integration with Existing TrackSessions
**Deliverables:**
- Add button to main TrackSessions window: "View Reservations Calendar" (tooltip: "Opens reservation calendar for all tracked machines")
- Update Settings.StartupTrace to log reservation events (create, cancel, conflict)
- Add status badge on main session grid if machine has active reservation (e.g., "RESERVED" tag next to machine name)
- Update file naming convention to support reservation status in session files

**Interactions:**
- Session active on reserved machine: Show info message in TrackSessions UI ("Machine is reserved until HH:MM")
- If session created during reservation: Log comment in reservation record
- Reservation window opens to currently selected machine (context-aware)

---

## File Structure Changes

### New Files to Create:
- `Sessions/TrackSessions.Reservations.psm1` — Core reservation logic module
- `Sessions/Show-ReservationCalendarDialog.ps1` — WPF dialog implementation
- `Sessions/ConvertTo-ReservationHtml.ps1` — HTML generation functions
- `Sessions/TrackSessions.Reservations.Prompts.md` — Documentation + examples

### Files to Modify:
- `Sessions/TrackSessions.ps1` — Add button, integrate dialog, update UI
- `Sessions/TrackSessions.Settings.json` — Add ReservationPath, ReservationAdmins, Outlook settings
- `Sessions/TrackSessions.UserEditor.ps1` — Add IsAdmin field editor

### Optional:
- `Sessions/TrackSessions.Outlook.psm1` — Separate Outlook COM wrapper module (if Outlook logic becomes complex)

---

## Verification Steps

1. **Settings Persistence**
   - [ ] Create new ReservationPath setting in TrackSessions.Settings.json
   - [ ] Verify path loads in Settings dialog and validates UNC format
   - [ ] Save/reload cycle persists ReservationPath correctly

2. **Reservation Creation**
   - [ ] Create reservation via dialog: Start 10:00, End 12:00, Machine paws66, Date today+1
   - [ ] Verify JSON file created: `Reservation.paws66.{UserId}.{date}.100000.120000.Active.json`
   - [ ] Verify HTML file created with same base name + `.html`
   - [ ] JSON content validates against schema (all required fields present)

3. **Conflict Detection & Override**
   - [ ] Create overlapping reservation → warn with conflict details
   - [ ] Allow override → file created with `OverrideWarning: true`
   - [ ] Query conflicts → `Test-ReservationConflict` returns both reservations

4. **Outlook Integration**
   - [ ] New reservation creates Outlook event with correct title/description
   - [ ] Outlook event includes attendees from DistributionList
   - [ ] Email notification sent to team with .ics attachment
   - [ ] Graceful failure if Outlook not available (log to StartupTrace, no crash)

5. **Cancellation**
   - [ ] Cancel reservation → file renamed to `.CANCELLED.json` / `.CANCELLED.html`
   - [ ] JSON Status field set to "Cancelled"
   - [ ] Outlook event updated with status or deleted (decision TBD)
   - [ ] Email sent to team on cancellation

6. **Calendar Dialog UI**
   - [ ] Month view loads, date selection works
   - [ ] Switching to day view shows time slots
   - [ ] Existing reservations render as blocks on timeline
   - [ ] Click to create new reservation opens form
   - [ ] Filter by user works
   - [ ] Past events toggle shows/hides old reservations

7. **Permissions**
   - [ ] Owner can edit/cancel own reservation
   - [ ] Non-owner non-admin cannot edit (button disabled)
   - [ ] Admin can edit any reservation
   - [ ] Admin role verified from TrackSessions.Users.json

8. **HTML Browser View**
   - [ ] Open in Edge/browser → calendar displays
   - [ ] Responsive on mobile view
   - [ ] Print preview works
   - [ ] Embedded JSON data loads correctly

9. **File System Robustness**
   - [ ] Concurrent writes don't corrupt files (atomic writes + lock handling)
   - [ ] Deleted file in ReservationPath → UI updates on refresh
   - [ ] Invalid JSON in ReservationPath → logged, UI shows warning, doesn't crash

10. **Integration with Main TrackSessions**
    - [ ] "View Reservations" button visible in main window
    - [ ] Button opens calendar dialog with current machine pre-selected
    - [ ] Reservation events logged to StartupTrace
    - [ ] Status badge visible on machine grid if reservation active

---

## Dependencies & Blockers

**External:**
- Outlook.Application COM object (must be installed locally; graceful fallback if not available)
- UNC path access to ReservationPath (network share must be accessible and writable)
- SMTP or Exchange for email notifications (can defer if direct email fails)

**Internal (existing code to leverage):**
- `Convert-ToSafeFileToken()` for sanitizing filenames
- Settings persistence pattern (Load-Settings, Save-Settings in TrackSessions.ps1)
- WPF dialog templates from TrackSessions.UserEditor.ps1 (OK/Cancel pattern, DataGrid for list views)
- StartupTrace logging mechanism for audit trail
- User lookup chain (CSV → AD → Graph) for displaying user names

**Implementation Order:**
1. Phase 1 (settings + schema) — Foundation, unblocks all others
2. Phase 2 (core module) — Business logic, can be tested independently
3. Phase 3 (Outlook) — Depends on Phase 1-2, no blocker
4. Phase 4 (WPF dialog) — Depends on Phase 1-2
5. Phase 5 (HTML view) — Depends on Phase 2, can run in parallel with Phase 4
6. Phase 6 (settings UI) — Depends on Phase 1
7. Phase 7 (integration) — Final glue, depends on all above

---

## Open Questions / Further Clarification

1. **Business Hours** — Should time slots be restricted to 9:00-18:00, or allow 24-hour reservations?
   - *Recommendation:* Default to 9:00-18:00 with 30-minute granularity, configurable in settings

2. **Recurring Reservations** — You mentioned "recurring status" — does this mean:
   - Multi-day reservation (e.g., Mon-Fri same time)?
   - Weekly repeating (same time slot every week)?
   - *Recommendation:* Start with single-day only; add recurring in Phase 2 enhancement if needed

3. **Approval Workflow** — Should reservations require admin approval before activation?
   - *Recommendation:* No approval required for Phase 1; optional "RequestsApproval" flag can be added for future

4. **Reservation Templates** — Should there be pre-defined reservation reasons/categories?
   - *Recommendation:* Use free-text Comments field; add categories later if needed

5. **Reservation Retention** — How long to keep cancelled/past reservations in ReservationPath?
   - *Recommendation:* No automatic deletion; manual archive/cleanup via admin UI (Phase 2 enhancement)

6. **Email Distribution List** — Should this be:
   - Hard-coded list in settings (admin-maintained)?
   - AD group (dynamically populated)?
   - *Recommendation:* Hard-coded list in settings for Phase 1; AD group lookup as enhancement

---

## Success Metrics

- ✅ Users can create reservation in < 30 seconds
- ✅ Calendar shows all reservations with < 2-second load time
- ✅ Conflicts are detected and warned before creation
- ✅ Outlook events created successfully for 95%+ of reservations
- ✅ Cancellation immediately visible in calendar (both UI + file system)
- ✅ Admin can override any user's reservation without friction
- ✅ HTML calendar is printable and mobile-responsive
