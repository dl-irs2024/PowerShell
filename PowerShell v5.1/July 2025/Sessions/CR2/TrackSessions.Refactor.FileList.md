# TrackSessions CR2 - Complete File Inventory & Relationships

**Generated**: 2026-09-20  
**Purpose**: Document all files, functions, and dependencies in the standalone CR2 folder  
**Status**: ✅ Self-contained - No external dependencies

---

## 📁 Folder Structure

```
Sessions\CR2\
├── 📜 PowerShell Scripts (3 files, 5,946 lines)
│   ├── TrackSessions.Refactor.CR2.ps1              (3,426 lines, 132 KB) [MAIN]
│   ├── TrackSessions.UserEditor2.ps1               (1,748 lines,  67 KB)
│   └── TrackSessions.Reservations.CalendarDialog2.ps1 (772 lines,  30 KB)
│
├── 📦 PowerShell Modules (1 file, 1,023 lines)
│   └── TrackSessions.Reservations2.psm1            (1,023 lines,  34 KB)
│
├── ⚙️ Configuration Files (2 files, 762 lines)
│   ├── TrackSessions.Settings.json                 (644 lines,  44 KB)
│   └── TrackSessions.Users.json                    (118 lines,   4 KB)
│
├── 📋 Schema Files (1 file, 202 lines)
│   └── TrackSessions.Reservations.Schema.json      (202 lines, 6.4 KB)
│
├── 📖 Documentation (3 files, 339 lines)
│   ├── TrackSessions.CR2.Setup.md                  (119 lines)
│   ├── TrackSessions.Refactor.Prompts.md           (220 lines)
│   └── TrackSessions.Refactor.Chat.md              (0 lines, empty)
│
└── 📂 Subfolders
    ├── Reservations\                               (data storage)
    └── Sessions\                                   (optional data)

Total: 10 files, 8,272 lines of code/config
```

---

## 📜 File Details & Key Functions

### 1. TrackSessions.Refactor.CR2.ps1 (MAIN SCRIPT)

**Size**: 3,426 lines (132 KB)  
**Type**: Main application script with WPF UI  
**Purpose**: Session tracking and monitoring tool for PAWS machines

#### 🔧 Key Functions (47 total)

##### Background Job Management
- `Start-BackgroundUserContextJob` - LDAP user lookup in background with timeout
- `Wait-BackgroundJobWithTimeout` - Generic job wait handler with timeout
- `Start-BackgroundSessionLoadJob` - JSON file enumeration in background

##### User & Identity
- `Get-CurrentUserContext` - Gets Windows identity with LDAP lookup
- `Get-UserDisplayName` - Maps SEID to display name from Users.json
- `Test-IsCurrentUserAdmin` - Checks if user has admin privileges
- `Get-CachedUserDisplayName` - Cached user display name lookup

##### Session Management
- `Get-CurrentSessionName` - Gets current RDP session name
- `Write-SessionSnapshot` - Creates session JSON snapshot
- `Write-SessionCloseArtifacts` - Creates .Logout.json files
- `Get-SessionGridRows` - Loads and filters session data from JSON files
- `Get-SessionStatusFromSnapshot` - Calculates session status (Logged In, Disconnected, Logged Out)
- `Update-SessionGridData` - Refreshes grid with live session data
- `Update-SessionGridDataFromCache` - Updates grid from cached background data
- `Get-CachedSessionData` - Retrieves cached session data

##### Settings & Configuration
- `Read-TrackSessionsSettings` - Loads TrackSessions.Settings.json
- `Save-TrackSessionsSettings` - Saves TrackSessions.Settings.json
- `Get-DefaultTrackedMachines` - Returns default PAWS machines
- `Resolve-TrackingConfiguration` - Resolves shared path and folder mode
- `Add-StartupTrace` - Logs startup events to Settings.json
- `Show-EditSettingsDialog` - WPF dialog for editing settings

##### UI Functions
- `Show-WindowsNotification` - Shows Windows 10 toast notifications
- `Save-MiniWindowPosition` - Saves mini window position to settings
- `Save-SplitterPosition` - Saves splitter position to settings
- `Save-MainWindowBounds` - Saves main window size/position
- `Set-MainContentZoom` - Sets UI zoom level
- `Update-MinimumLayoutConstraints` - Calculates responsive layout
- `Update-MainContentZoom` - Updates zoom based on window size
- `Set-ResponsiveInfoLayout` - Adjusts UI for window size
- `Show-MiniSessionPanel` - Shows minimized session panel
- `Restore-MainWindowFromMini` - Restores from mini window

##### Activity Grid Simulation
- `Get-SimulationInterval` - Gets simulation timer interval
- `Get-NextSimulatedState` - Generates next simulated state
- `New-SimulatedStateMachineEvent` - Creates state machine event
- `New-SimulatedActivityRow` - Creates simulated activity row

##### Utilities
- `Convert-ToSafeFileToken` - Sanitizes strings for filenames
- `Test-IsFiniteDouble` - Validates double values
- `Add-DebugLog` - Adds debug log entry
- `Update-StatusBar` - Updates status bar text
- `Copy-TextToClipboard` - Copies text to clipboard
- `Convert-ToSingleQuotedPsString` - Escapes PowerShell strings
- `Convert-TrackingSettingsToPsObjectText` - Converts settings to PS code
- `Convert-MainViewToPsObjectText` - Converts UI state to PS code
- `New-OrangeCircleIconFrame` - Creates status icon

##### Task Scheduler
- `Register-TrackSessionsLogonTask` - Registers Windows Task Scheduler job

#### 📤 External File References

**Calls to other CR2 files:**
- Line 2886: `& "$PSScriptRoot\TrackSessions.UserEditor2.ps1"`
- Lines 2901-2902: `Join-Path $PSScriptRoot 'TrackSessions.Reservations.CalendarDialog2.ps1'`

**Configuration files:**
- `TrackSessions.Settings.json` - Loaded via `Read-TrackSessionsSettings`
- `TrackSessions.Users.json` - Referenced at line 2884, 2935

**Data files:**
- Session JSON files: `Session.*.json` (read from SharedPath)
- Logout JSON files: `*.Logout.json`

---

### 2. TrackSessions.UserEditor2.ps1

**Size**: 1,748 lines (67 KB)  
**Type**: WPF user management dialog  
**Purpose**: Add, edit, and manage user records in Users.json

#### 🔧 Key Functions (23 total)

##### Core User Operations
- `Import-Users` - Loads users from TrackSessions.Users.json
- `Save-Users` - Saves users to TrackSessions.Users.json
- `Convert-ToUserObject` - Converts hashtable to user object
- `Convert-FromUserObject` - Converts user object to hashtable
- `Show-EditUserDialog` - WPF dialog for editing individual user

##### External Lookups
- `Find-ExternalUserFromCsv` - Lookup user by SEID from CSV
- `Find-ExternalUserFromCsvByEmail` - Lookup user by email from CSV
- `Find-ExternalUserFromAd` - Lookup user by SEID from Active Directory
- `Find-ExternalUserFromAdByEmail` - Lookup user by email from AD
- `Find-ExternalUserFromGraph` - Lookup user by SEID from Microsoft Graph
- `Find-ExternalUserFromGraphByEmail` - Lookup user by email from Graph
- `Resolve-ExternalUserBySeid` - Multi-source user resolver (CSV → AD → Graph)
- `Resolve-ExternalUserByEmail` - Multi-source email resolver

##### Input Processing
- `ConvertFrom-IrsEmailInput` - Parses IRS email format (copy/paste from Outlook)
- `New-ExternalUserLookupResult` - Creates lookup result object
- `Split-ProductsValue` - Parses products field (comma-separated)

##### Utilities
- `Format-UserDateTime` - Formats datetime for display
- `ConvertTo-UserDateTime` - Parses datetime from user input
- `Show-ValidationError` - Shows validation error dialog
- `Get-TrackedPawsFqdns` - Gets PAWS machine FQDNs from settings

##### Settings Integration
- Uses `$script:UsersPath` = `Join-Path $PSScriptRoot 'TrackSessions.Users.json'`
- Uses `$script:SettingsPath` = `Join-Path $PSScriptRoot 'TrackSessions.Settings.json'`

#### 📤 External File References

**Configuration files:**
- `TrackSessions.Users.json` - User database (read/write)
- `TrackSessions.Settings.json` - Settings for PAWS machine list
- `TrackSessions.Users.External.csv` - Optional external user CSV

**Called by:**
- TrackSessions.Refactor.CR2.ps1 line 2886 (Manage Users button)

---

### 3. TrackSessions.Reservations.CalendarDialog2.ps1

**Size**: 772 lines (30 KB)  
**Type**: WPF calendar reservation dialog  
**Purpose**: Visual calendar interface for managing machine reservations

#### 🔧 Key Functions (9 total)

##### Data Loading
- `Get-TrackedMachines` - Loads machine list from Settings.json
- `Load-AllReservations` - Loads all reservation JSON files
- `Get-DayReservations` - Gets reservations for specific date/machine
- `Get-AvailableTimeSlots` - Calculates available time slots (conflict detection)

##### UI Rendering
- `Render-MonthCalendar` - Renders month view grid
- `Render-DayView` - Renders day view with time slots
- `Render-ListView` - Renders list view of all reservations
- `Update-TimeSlots` - Updates time slot buttons based on selection

##### Data Operations
- `Refresh-Data` - Reloads reservations from disk

#### 📦 Module Dependencies

**Imports:**
- Line 31: `Import-Module $reservationModulePath -Force`
  - `$reservationModulePath` = `Join-Path $PSScriptRoot 'TrackSessions.Reservations2.psm1'`

**Uses functions from TrackSessions.Reservations2.psm1:**
- `Get-ReservationSettings`
- `Get-UserDatabase`
- `New-Reservation`
- `Update-Reservation`
- `Cancel-Reservation`
- `Get-Reservations`
- `Test-ReservationConflict`
- `Test-ReservationEditPermission`

#### 📤 External File References

**Configuration files:**
- `TrackSessions.Settings.json` - Machine list, reservation path
- `TrackSessions.Users.json` - User database

**Module files:**
- `TrackSessions.Reservations2.psm1` - Core reservation functions

**Data files:**
- `Reservation.*.Active.json` - Active reservations
- `Reservation.*.CANCELLED.json` - Cancelled reservations
- `Reservation.*.html` - HTML copies (optional)

**Called by:**
- TrackSessions.Refactor.CR2.ps1 lines 2900-2903 (Reservations button)

---

### 4. TrackSessions.Reservations2.psm1 (MODULE)

**Size**: 1,023 lines (34 KB)  
**Type**: PowerShell module with exported functions  
**Purpose**: Core reservation CRUD operations and business logic

#### 🔧 Exported Functions (9 total)

##### Settings & Users
- `Get-ReservationSettings` - Loads reservation settings from Settings.json
- `Get-UserDatabase` - Loads user database from Users.json

##### Permission Checking
- `Test-ReservationEditPermission` - Checks if user can edit/cancel reservation
  - Returns `$true` if user is reservation owner OR admin
  - Checks `$ReservationAdmins` array from settings

##### Conflict Detection
- `Test-ReservationConflict` - Checks for time slot conflicts
  - Searches for existing Active reservations
  - Compares start/end times for overlaps
  - Returns conflicting reservation details

##### CRUD Operations
- `New-Reservation` - Creates new reservation
  - Generates GUID ReservationId
  - Creates filename: `Reservation.{Machine}.{User}.{yyyyMMdd}.{HHmmss}.{HHmmss}.Active.json`
  - Optionally creates HTML copy
  - Returns reservation object

- `Get-Reservations` - Queries reservations
  - Filters by MachineName, Date, Status (Active/CANCELLED/*)
  - Parses filenames for metadata
  - Returns array of reservation objects

- `Update-Reservation` - Updates existing reservation
  - Checks permissions
  - Updates LastModifiedAtGmt, LastModifiedByUserId
  - Can add comments, change times/dates
  - Maintains audit history

- `Cancel-Reservation` - Cancels reservation
  - Checks permissions
  - Renames file: `.Active.json` → `.CANCELLED.json`
  - Records cancellation reason, timestamp
  - Updates HTML copy

##### Utilities
- `ConvertTo-ReservationHtml` - Generates HTML representation of reservation

#### 📤 External File References

**Configuration files:**
- `TrackSessions.Settings.json` - ReservationPath, ReservationAdmins
- `TrackSessions.Users.json` - User display names, emails

**Data files:**
- `Reservation.{Machine}.{User}.{Date}.{Start}.{End}.Active.json` - Active reservations
- `Reservation.{Machine}.{User}.{Date}.{Start}.{End}.CANCELLED.json` - Cancelled reservations
- `Reservation.*.html` - Optional HTML copies

**Schema file:**
- `TrackSessions.Reservations.Schema.json` - Referenced in comments (not loaded at runtime)

**Used by:**
- TrackSessions.Reservations.CalendarDialog2.ps1 (imports this module)

---

## ⚙️ Configuration Files

### 5. TrackSessions.Settings.json

**Size**: 644 lines (44 KB)  
**Type**: JSON configuration file  
**Purpose**: Application settings, machine list, UI state

#### 📋 Key Sections

```json
{
  "SchemaVersion": "1.0",
  "MiniWindow": { "Left": null, "Top": null },
  "Layout": {
    "BottomPaneHeight": 167,
    "WindowLeft": null, "WindowTop": null,
    "WindowWidth": null, "WindowHeight": null
  },
  "Tracking": {
    "SharedPath": "\\\\Vp0wxsqm365as02\\SPS\\PAWS-Sessions\\TestSimulate",
    "Machines": [
      {
        "ShortName": "PAWS 66",
        "FQDN": "mtb012vp0030366.ds.irsnet.gov",
        "Comment": "Preset PAWS machine"
      },
      // ... more machines
    ]
  },
  "StartupTrace": {
    "Enabled": true,
    "Events": [ /* startup event log */ ]
  }
}
```

#### 🔑 Important Properties

- **SharedPath**: UNC path where session JSON files are stored
- **Machines[]**: Array of tracked machines (ShortName, FQDN, Comment)
- **ReservationPath**: Path for reservation files (optional, defaults to `Reservations\`)
- **ReservationAdmins**: Array of admin SEIDs who can edit/cancel any reservation
- **Layout**: Window position, size, splitter position
- **StartupTrace**: Debug trace events for troubleshooting

#### 📤 Used By

- TrackSessions.Refactor.CR2.ps1 - Main settings
- TrackSessions.UserEditor2.ps1 - Machine list for LastPawsUsed dropdown
- TrackSessions.Reservations.CalendarDialog2.ps1 - Machine list for calendar
- TrackSessions.Reservations2.psm1 - ReservationPath, ReservationAdmins

---

### 6. TrackSessions.Users.json

**Size**: 118 lines (4 KB)  
**Type**: JSON user database  
**Purpose**: User profile information for display names, emails, admin status

#### 📋 User Schema

```json
{
  "SEID": "YMJNB",
  "FirstName": "Davis",
  "LastName": "Lee",
  "Status": "FTE",
  "IRSEmail": "davis.s.lee@irs.gov",
  "SEIDEmail": "YMJNB@ds.irsnet.gov",
  "Timezone": "Washington, DC (ET) [UTC-05:00 / UTC-04:00]",
  "DaylightSavings": true,
  "Products": ["SharePoint", "OneDrive"],
  "LastLogin": "Mon 07/09/2026 09:15",
  "LastPawsUsed": "mtb012vp0030366.ds.irsnet.gov",
  "LastModified": "Mon 07/09/2026 09:15",
  "Created": "Mon 07/09/2026 09:15",
  "IsAdmin": false
}
```

#### 🔑 Key Fields

- **SEID**: Unique user identifier (used throughout application)
- **FirstName, LastName**: Used by `Get-UserDisplayName` function
- **IRSEmail, SEIDEmail**: Contact information
- **IsAdmin**: Admin privilege flag
- **Products**: Array of product access (SharePoint, OneDrive, Teams, etc.)
- **LastLogin, LastPawsUsed**: Usage tracking

#### 📤 Used By

- TrackSessions.Refactor.CR2.ps1 - `Get-UserDisplayName` function
- TrackSessions.UserEditor2.ps1 - Full CRUD operations
- TrackSessions.Reservations2.psm1 - `Get-UserDatabase` function

---

## 📋 Schema Files

### 7. TrackSessions.Reservations.Schema.json

**Size**: 202 lines (6.4 KB)  
**Type**: JSON schema documentation  
**Purpose**: Documents reservation file structure and validation rules

#### 📋 File Naming Convention

```
Reservation.{MachineName}.{UserId}.{yyyyMMdd}.{HHmmss_Start}.{HHmmss_End}.{Status}.json

Example:
Reservation.PAWS66.YMJNB.20260910.100000.120000.Active.json
```

#### 🔑 Key Schema Fields

- **ReservationId**: GUID identifier
- **MachineName, MachineShortName, MachineFqdn**: Machine identifiers
- **UserId, UserDisplayName, UserEmail**: Reservation owner
- **ReservationDate**: yyyy-MM-dd format
- **StartTime, EndTime**: HH:mm format (24-hour)
- **Status**: Active, CANCELLED (reflected in filename)
- **CreatedAtGmt, LastModifiedAtGmt**: ISO-8601 UTC timestamps
- **CreatedByUserId, LastModifiedByUserId**: Audit trail
- **Comments[]**: Array of comment objects with timestamps
- **CancellationReason, CancelledAtGmt, CancelledByUserId**: Cancellation details

#### 📤 Used By

- Documentation reference only (not loaded at runtime)
- Guides `New-Reservation`, `Update-Reservation`, `Cancel-Reservation` functions

---

## 📖 Documentation Files

### 8. TrackSessions.CR2.Setup.md

**Size**: 119 lines  
**Purpose**: Documents setup process and file relationships

**Contents**:
- Files copied from parent folder
- Folder structure
- Script references verification
- Running instructions

---

### 9. TrackSessions.Refactor.Prompts.md

**Size**: 220 lines  
**Purpose**: Development prompts and requirements

**Contents**:
- Feature requests
- Bug reports
- Development notes

---

### 10. TrackSessions.Refactor.Chat.md

**Size**: 0 lines (empty placeholder)  
**Purpose**: Chat history placeholder

---

## 🔗 File Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                 TrackSessions.Refactor.CR2.ps1                  │
│                         [MAIN SCRIPT]                           │
│  • Session monitoring UI                                        │
│  • Background jobs for performance                              │
│  • Status bar, grid, mini window                                │
└────────────┬───────────────────────┬────────────────────────────┘
             │                       │
             │ (line 2886)          │ (lines 2900-2903)
             │ & "$PSScriptRoot\..." │ Join-Path $PSScriptRoot...
             │                       │
   ┌─────────▼──────────┐   ┌────────▼─────────────────────────┐
   │ UserEditor2.ps1    │   │ Reservations.CalendarDialog2.ps1  │
   │ [USER DIALOG]      │   │ [CALENDAR DIALOG]                 │
   │ • Add/Edit users   │   │ • Month/Day/List views             │
   │ • LDAP/AD/Graph    │   │ • Conflict detection               │
   │ • CSV import       │   │ • Create/Edit/Cancel UI            │
   └─────────┬──────────┘   └────────┬───────────────────────────┘
             │                       │
             │ (read/write)          │ (import line 31)
             │                       │ Import-Module -Force
             │                       │
   ┌─────────▼──────────┐   ┌────────▼─────────────────────────┐
   │  Users.json        │   │    Reservations2.psm1             │
   │  [USER DATABASE]   │   │    [MODULE]                       │
   │  • 2 sample users  │   │    • Get-Reservations             │
   │  • SEID, names     │   │    • New-Reservation              │
   │  • Admin flags     │   │    • Update-Reservation           │
   └─────────┬──────────┘   │    • Cancel-Reservation           │
             │              │    • Test-ReservationConflict     │
             │              └────────┬───────────────────────────┘
             │                       │
             │ (referenced)          │ (uses for conflict detection)
             │                       │ (uses for user names)
             │                       │
   ┌─────────▼───────────────────────▼──────────────────────────┐
   │                  Settings.json                              │
   │                  [CONFIGURATION]                            │
   │  • SharedPath: \\Vp0wxsqm365as02\SPS\PAWS-Sessions\...     │
   │  • Machines[]: PAWS 66, 67, 68, 69                         │
   │  • ReservationPath (optional)                               │
   │  • ReservationAdmins[]                                      │
   │  • Layout, MiniWindow state                                 │
   └─────────────────────────────────────────────────────────────┘

External Data Files (not in CR2 folder):
  ┌──────────────────────────────────────────────┐
  │ \\Vp0wxsqm365as02\SPS\PAWS-Sessions\...      │
  │  • Session.*.json (read by main script)      │
  │  • *.Logout.json (created by main script)    │
  └──────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────┐
  │ CR2\Reservations\                             │
  │  • Reservation.*.Active.json (CRUD by module) │
  │  • Reservation.*.CANCELLED.json               │
  │  • Reservation.*.html (optional copies)       │
  └──────────────────────────────────────────────┘

Schema Reference (documentation only):
  ┌──────────────────────────────────────────────┐
  │ Reservations.Schema.json                      │
  │  • File naming convention                     │
  │  • Field definitions                          │
  │  • Validation rules                           │
  └──────────────────────────────────────────────┘
```

---

## 🔐 Dependency Analysis

### Internal Dependencies (within CR2 folder)

| File | Depends On | Relationship Type |
|------|-----------|------------------|
| **TrackSessions.Refactor.CR2.ps1** | Settings.json | Read/Write config |
| | Users.json | Read user names (via Get-UserDisplayName) |
| | UserEditor2.ps1 | Launches via `&` operator |
| | Reservations.CalendarDialog2.ps1 | Launches via `&` operator |
| **TrackSessions.UserEditor2.ps1** | Settings.json | Read machine list |
| | Users.json | Read/Write user database |
| **Reservations.CalendarDialog2.ps1** | Settings.json | Read machine list, paths |
| | Users.json | Read user names |
| | Reservations2.psm1 | Import-Module (required) |
| **Reservations2.psm1** | Settings.json | Read ReservationPath, admins |
| | Users.json | Read user display names |

### External Dependencies (outside CR2 folder)

| File | External Path | Purpose |
|------|--------------|---------|
| **TrackSessions.Refactor.CR2.ps1** | `\\Vp0wxsqm365as02\SPS\PAWS-Sessions\TestSimulate\*.json` | Read session files |
| | `CR2\Reservations\*.json` | Reservation data storage |
| **Reservations2.psm1** | `{ReservationPath}\*.json` | Read/Write reservations |

### No External Script Dependencies

✅ **All PowerShell scripts are self-contained within CR2 folder**  
✅ **No dependencies on parent `Sessions\` folder**  
✅ **No dependencies on sibling folders**  
✅ **All `$PSScriptRoot` references resolve to CR2 folder**

---

## 🔄 Function Call Graph

### Main Script → Dialogs

```
TrackSessions.Refactor.CR2.ps1
├─[Manage Users button]──────────────────────┐
│  └─ & "$PSScriptRoot\UserEditor2.ps1"      │
│                                             ▼
│                              TrackSessions.UserEditor2.ps1
│                                ├─ Import-Users()
│                                ├─ Save-Users()
│                                ├─ Show-EditUserDialog()
│                                ├─ Resolve-ExternalUserBySeid()
│                                └─ Find-ExternalUserFromAd()
│
└─[Reservations button]──────────────────────┐
   └─ & "$PSScriptRoot\Reservations.        │
      CalendarDialog2.ps1"                   ▼
                         TrackSessions.Reservations.CalendarDialog2.ps1
                           ├─ Import-Module Reservations2.psm1
                           ├─ Load-AllReservations()
                           ├─ Render-MonthCalendar()
                           ├─ Render-DayView()
                           └─ Get-AvailableTimeSlots()
                                      │
                                      │ [Uses module functions]
                                      ▼
                           TrackSessions.Reservations2.psm1
                             ├─ Get-Reservations()
                             ├─ New-Reservation()
                             ├─ Update-Reservation()
                             ├─ Cancel-Reservation()
                             ├─ Test-ReservationConflict()
                             └─ Test-ReservationEditPermission()
```

### Settings Flow

```
All Scripts
    │
    ├─ Read-TrackSessionsSettings()
    │    └─ Get-Content Settings.json | ConvertFrom-Json
    │
    ├─ Save-TrackSessionsSettings()
    │    └─ ConvertTo-Json | Set-Content Settings.json
    │
    └─ Uses Settings Properties:
         ├─ Tracking.SharedPath
         ├─ Tracking.Machines[]
         ├─ Tracking.ReservationPath
         ├─ Tracking.ReservationAdmins[]
         ├─ Layout.*
         └─ MiniWindow.*
```

### User Lookup Flow

```
TrackSessions.Refactor.CR2.ps1
    │
    └─ Get-UserDisplayName(UserId, UsersList)
         ├─ Extract username from "DOMAIN\USER"
         ├─ Search Users.json by SEID
         └─ Return "FirstName LastName" or SEID

TrackSessions.UserEditor2.ps1
    │
    └─ Resolve-ExternalUserBySeid(SEID)
         ├─ Try: Find-ExternalUserFromCsv()
         ├─ Try: Find-ExternalUserFromAd()
         └─ Try: Find-ExternalUserFromGraph()

TrackSessions.Reservations2.psm1
    │
    └─ Get-UserDatabase(UsersPath)
         └─ Get-Content Users.json | ConvertFrom-Json
```

---

## ✅ Standalone Verification Checklist

### ✅ File Independence

- [x] All `.ps1` scripts use `$PSScriptRoot` for relative paths
- [x] No hardcoded paths to parent or sibling folders
- [x] No `Import-Module` calls outside CR2 folder
- [x] No `& "..\"` references to parent scripts

### ✅ Configuration Self-Contained

- [x] Settings.json exists in CR2 folder
- [x] Users.json exists in CR2 folder
- [x] Reservations.Schema.json exists in CR2 folder (reference only)
- [x] All configuration loaded from CR2 folder

### ✅ Module Dependencies

- [x] Reservations2.psm1 in CR2 folder
- [x] CalendarDialog2.ps1 imports from `$PSScriptRoot`
- [x] No external PowerShell modules required (except built-in)

### ✅ Data Storage

- [x] Reservations\ subfolder created for data storage
- [x] Session data path configurable via Settings.json
- [x] No assumptions about parent folder structure

### ✅ Naming Isolation

- [x] All CR2 modules renamed with `2` suffix
- [x] UserEditor.ps1 → UserEditor2.ps1
- [x] Reservations.CalendarDialog.ps1 → Reservations.CalendarDialog2.ps1
- [x] Reservations.psm1 → Reservations2.psm1
- [x] All references updated to match new names

---

## 🚀 Quick Start

### Run Main Application

```powershell
cd "C:\...\Sessions\CR2"
.\TrackSessions.Refactor.CR2.ps1
```

### Run User Editor (Standalone)

```powershell
cd "C:\...\Sessions\CR2"
.\TrackSessions.UserEditor2.ps1
```

### Run Reservations Calendar (Standalone)

```powershell
cd "C:\...\Sessions\CR2"
.\TrackSessions.Reservations.CalendarDialog2.ps1 `
    -ReservationPath "C:\...\Sessions\CR2\Reservations" `
    -SettingsPath "C:\...\Sessions\CR2\TrackSessions.Settings.json" `
    -UsersPath "C:\...\Sessions\CR2\TrackSessions.Users.json" `
    -SelectedMachine "PAWS 66"
```

---

## 📊 Statistics Summary

| Metric | Count |
|--------|-------|
| **Total Files** | 10 |
| **PowerShell Scripts** | 3 (5,946 lines) |
| **PowerShell Modules** | 1 (1,023 lines) |
| **Configuration Files** | 2 (762 lines) |
| **Schema Files** | 1 (202 lines) |
| **Documentation Files** | 3 (339 lines) |
| **Total Lines of Code** | 8,272 |
| **Total Size** | ~364 KB |
| **Functions Defined** | 88 |
| **External Dependencies** | 0 (self-contained) |

---

## 🔍 Function Cross-Reference

### Functions Shared Across Files

| Function Name | Defined In | Called By |
|---------------|-----------|-----------|
| `Get-ReservationSettings` | Reservations2.psm1 | CalendarDialog2.ps1 |
| `Get-UserDatabase` | Reservations2.psm1 | CalendarDialog2.ps1 |
| `Get-Reservations` | Reservations2.psm1 | CalendarDialog2.ps1 |
| `New-Reservation` | Reservations2.psm1 | CalendarDialog2.ps1 |
| `Update-Reservation` | Reservations2.psm1 | CalendarDialog2.ps1 |
| `Cancel-Reservation` | Reservations2.psm1 | CalendarDialog2.ps1 |
| `Test-ReservationConflict` | Reservations2.psm1 | CalendarDialog2.ps1 |
| `Test-ReservationEditPermission` | Reservations2.psm1 | CalendarDialog2.ps1 |
| `Get-UserDisplayName` | Refactor.CR2.ps1 | Refactor.CR2.ps1 (internal) |
| `Read-TrackSessionsSettings` | Refactor.CR2.ps1 | Refactor.CR2.ps1 (internal) |

### Unique Functions (Not Shared)

| Script | Unique Functions |
|--------|------------------|
| **Refactor.CR2.ps1** | 37 unique functions (background jobs, UI, simulation) |
| **UserEditor2.ps1** | 23 unique functions (CRUD, lookups, validation) |
| **CalendarDialog2.ps1** | 9 unique functions (rendering, UI) |
| **Reservations2.psm1** | 9 exported functions (CRUD, validation) |

---

## 📝 Notes

1. **Self-Contained**: All dependencies are within CR2 folder - no parent/sibling references
2. **Renamed Files**: All modules use `2` suffix to avoid conflicts with parent folder
3. **Data Separation**: Session data in UNC path, Reservations in CR2\Reservations\
4. **Configuration**: Settings.json and Users.json in CR2 folder
5. **Module Loading**: CalendarDialog2.ps1 dynamically imports Reservations2.psm1 with `-Force`
6. **Background Jobs**: Main script uses jobs for LDAP and file I/O to prevent UI blocking
7. **Extensibility**: User Editor supports LDAP, AD, Graph lookups for user auto-population

---

## 🔗 Related Documentation

- [TrackSessions.CR2.Setup.md](TrackSessions.CR2.Setup.md) - Setup and dependency documentation
- [TrackSessions.Refactor.Prompts.md](TrackSessions.Refactor.Prompts.md) - Development prompts
- [TrackSessions.Reservations.Schema.json](TrackSessions.Reservations.Schema.json) - Reservation schema

---

**End of File Inventory**
