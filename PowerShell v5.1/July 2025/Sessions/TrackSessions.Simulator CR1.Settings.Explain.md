# TrackSessions Settings Architecture

## Overview

The TrackSessions system uses a hierarchical configuration model combining **shared settings** (JSON files in the script's directory or designated UNC path) with **local runtime state** (UI window positions, pane heights, startup trace events).

---

## Settings Configuration Hierarchy

### 1. **Shared Settings** (TrackSessions.Settings.json)
Location: Same directory as the script (or overridable via `-SettingsPath` parameter)

These settings are shared across all users running the script on any machine:

```json
{
    "SchemaVersion": "1.0",
    "MiniWindow": {
        "Left": null,
        "Top": null
    },
    "Layout": {
        "BottomPaneHeight": 143,
        "WindowLeft": null,
        "WindowTop": null,
        "WindowWidth": null,
        "WindowHeight": null
    },
    "Tracking": {
        "SharedPath": "",
        "Machines": [
            {
                "ShortName": "PAWS001",
                "FQDN": "",
                "Comment": "Preset PAWS machine"
            }
        ]
    },
    "StartupTrace": {
        "Enabled": true,
        "Events": [...]
    }
}
```

#### 2.1 **MiniWindow Section** (Local)
- `Left`, `Top`: Window position on user's screen
- **Scope**: Persists per-user, specific to their desktop

#### 2.2 **Layout Section** (Local)
- `BottomPaneHeight`: Height of the grid/status panel
- `WindowLeft`, `WindowTop`, `WindowWidth`, `WindowHeight`: Main window dimensions
- **Scope**: Persists per-user, specific to their desktop and monitor

#### 2.3 **Tracking Section** (Shared)
**This is the key configuration section for cross-machine monitoring:**

##### **SharedPath** (UNC Path - Optional but Recommended)
- **Type**: String (empty by default)
- **Format**: Must be UNC path, e.g., `\\server\share\SessionTracking`
- **Purpose**: 
  - Centralized location where all machines write session events
  - Used to create date/machine-specific subdirectories for organization
  - If empty or unreachable, falls back to local `%ProgramData%\SessionTracker\Json`

##### **Machines** (Predefined List)
- **Type**: Array of objects
- **Fields per machine**:
  - `ShortName`: NetBIOS name (e.g., "PAWS001", "mtb012vp0030366")
  - `FQDN`: Fully Qualified Domain Name (optional, e.g., "mtb012vp0030366.ds.irsnet.gov")
  - `Comment`: Metadata (e.g., "Preset PAWS machine", "Test environment")
- **Purpose**: Whitelist of machines to monitor
- **Default Machines**: If not specified, uses:
  - PAWS001, PAWS002, PAWS003 (hardcoded defaults)

#### 2.4 **StartupTrace Section** (Audit/Debug)
- `Enabled`: Boolean, tracks startup lifecycle events
- `Events`: Array of timestamped events
  - `TimestampUtc`: ISO 8601 format (e.g., "2026-09-10T03:56:01.252Z")
  - `Event`: Event name (e.g., "Script.Start", "Main.Loaded", "Main.Closed")
  - `Detail`: Optional context (PID, settings path, state, etc.)
- **Purpose**: Debugging and audit trail for script initialization

---

## Shared Users Configuration (TrackSessions.Users.json)

Location: Same directory as the script

This is a **shared, pre-defined list of authorized users** across all machines:

```json
[
    {
        "SEID": "ABCD123",
        "FirstName": "Sample",
        "LastName": "User",
        "Status": "FTE",
        "IRSEmail": "sample.user@irs.gov",
        "SEIDEmail": "ABCD123@ds.irsnet.gov",
        "Timezone": "Washington, DC (ET) [UTC-05:00 / UTC-04:00]",
        "DaylightSavings": true,
        "Products": ["SharePoint", "OneDrive"],
        "LastLogin": "Mon 07/09/2026 09:15",
        "LastPawsUsed": "mtb012vp0030366.ds.irsnet.gov",
        "LastModified": "Mon 07/09/2026 09:15",
        "Created": "Mon 07/09/2026 09:15",
        "IsAdmin": false
    },
    {
        "SEID": "YMJNB",
        "FirstName": "Davis",
        "LastName": "Lee",
        ...
        "IsAdmin": true
    }
]
```

### User Record Fields

| Field | Type | Purpose | Admin-Specific |
|-------|------|---------|---|
| `SEID` | String | Unique identifier (IRS Employee ID) | Yes |
| `FirstName` / `LastName` | String | Display name components | No |
| `Status` | String | Employment status (FTE, Contract, etc.) | No |
| `IRSEmail` | String | Corporate email address | No |
| `SEIDEmail` | String | SEID-based email (e.g., YMJNB@ds.irsnet.gov) | No |
| `Timezone` | String | User's geographic timezone | No |
| `DaylightSavings` | Boolean | Observes DST | No |
| `Products` | Array | Systems user accesses (SharePoint, Power Platform, etc.) | No |
| `LastLogin` | String | Last recorded session start | No |
| `LastPawsUsed` | String | Last PAWS machine accessed | No |
| `LastModified` | String | When user record last changed | No |
| `Created` | String | When user was added to system | No |
| **`IsAdmin`** | **Boolean** | **Administrative privileges flag** | **Yes** |

### Admin Flag Matching Logic

The script uses `Test-IsCurrentUserAdmin()` to determine if the running user is an administrator:

```powershell
$candidateIds = @(
    $CurrentUserContext.SamAccountName    # Environment username
    $CurrentUserContext.UserId             # Full domain\user
    $env:USERNAME                          # Short username
)
```

For each user record in the JSON, it checks:
- `SEID` field
- `UserId` field (if present)
- `SamAccountName` field (if present)

If **any** of these match the current user **AND** `IsAdmin = true`, that user is elevated.

---

## Tracking Configuration: UNC Path Behavior

### Scenario 1: UNC Path IS Set and Accessible
```
SharedPath = "\\server\share\SessionTracking"
```
- Session events are written to: `\\server\share\SessionTracking\{MachineName}\{Date}\...`
- All machines write to centralized location
- **Folder Mode**: "Shared UNC"
- Best for: Multi-machine monitoring, central audit

### Scenario 2: UNC Path NOT Set (Empty)
```
SharedPath = ""
```
- Falls back to local default: `%ProgramData%\SessionTracker\Json`
- Each machine maintains **local-only** session logs
- **Folder Mode**: "Default"
- **Can still use pre-defined users and machine lists!**

### Scenario 3: UNC Path Set but UNREACHABLE (Network down, permissions denied, etc.)
```
SharedPath = "\\server\share\SessionTracking"
# But path doesn't exist or can't be created
```
- Falls back to local default: `%ProgramData%\SessionTracker\Json`
- **Folder Mode**: "Default (Shared UNC unavailable)"
- Pre-defined machines and users continue to work with local logging

---

## Configuration Resolution Logic

```powershell
function Resolve-TrackingConfiguration {
    # 1. Load machine list from Settings.Tracking.Machines
    $trackedMachines = @($SettingsData.Tracking.Machines)
    
    # 2. Load SharedPath setting
    $sharedPath = [string]$SettingsData.Tracking.SharedPath
    
    # 3. Determine effective output folder
    $effectiveFolder = $DefaultOutputFolder  # %ProgramData%\SessionTracker\Json
    $folderMode = 'Default'
    
    if (-not [string]::IsNullOrWhiteSpace($sharedPath)) {
        if ($sharedPath.StartsWith('\\')) {
            try {
                if (-not (Test-Path -LiteralPath $sharedPath)) {
                    New-Item -Path $sharedPath -ItemType Directory -Force
                }
                $effectiveFolder = $sharedPath
                $folderMode = 'Shared UNC'
            } catch {
                # UNC path unreachable - fall back
                $effectiveFolder = $DefaultOutputFolder
                $folderMode = 'Default (Shared UNC unavailable)'
            }
        }
    }
    
    return @{
        EffectiveFolder = $effectiveFolder
        FolderMode = $folderMode
        TrackedMachines = $trackedMachines
        SharedPath = $sharedPath
        JsonPath = Join-Path -Path $effectiveFolder -ChildPath $JsonFileName
    }
}
```

---

## Session Tracking Events

### Event Types Generated

Session lifecycle creates three types of files per session:

#### 1. **Login Event** (Session Start)
- **File**: `{MachineName}.json`
- **Trigger**: Script startup
- **Contents**:
  - `CreatedAtGmt`: Timestamp of login
  - `MachineName`: Source PAWS machine
  - `UserId` / `UserDisplayName`: User context
  - `SessionName`: RDP session type (Console, RDP-Tcp:1, etc.)
  - Session status: "Logged In"

#### 2. **Logout Event** (Session End)
- **File**: `{MachineName}.Logout.json`
- **Trigger**: Window close, session disconnection, script exit
- **Contents**:
  - All login event data PLUS:
  - `LogoutFileCreatedAtGmt`: Timestamp of logout
  - `ClosedAt`: Time session ended
  - `CloseReason`: Event that triggered close
  - Session status: "Logged Out" or "Disconnected"

#### 3. **Disconnect Event** (RDP Disconnection)
- **Trigger**: User closes RDP window without logging off
- **Status**: "Disconnected" (intermediate state between login and logout)
- **Detection**: `.Logout.json` file exists with `"Disconnected"` status

### Event Directory Structure Example

```
\\server\share\SessionTracking\
├── PAWS001\
│   ├── 2026-09-16\
│   │   ├── PAWS001.json                    # Login
│   │   └── PAWS001.Logout.json             # Logout/Disconnect
│   ├── 2026-09-15\
│   │   └── PAWS001.json
│   └── 2026-09-14\
│       └── PAWS001.Logout.json
├── PAWS002\
│   ├── 2026-09-16\
│   │   └── ...
│   └── ...
└── mtb012vp0030366\
    ├── 2026-09-16\
    │   └── ...
    └── ...
```

---

## Settings vs Runtime Data

| Config Type | File | Scope | Shared | Purpose |
|---|---|---|---|---|
| **Shared Settings** | `TrackSessions.Settings.json` | All users, all machines | ✅ Yes | Machine list, UNC path, trace enabled flag |
| **Window Position** | Same file (MiniWindow, Layout) | Per-user desktop | ❌ Local | UI state persistence |
| **User Directory** | `TrackSessions.Users.json` | All machines | ✅ Yes | User registry with IsAdmin flag |
| **Session Events** | `{MachineName}.json` / `.Logout.json` | Per-machine, per-session | ✅ Yes (if UNC set) | Session lifecycle audit trail |
| **Startup Trace** | `TrackSessions.Settings.json` (StartupTrace) | All users | ✅ Shared (but filtered local) | Debug log of initialization |

---

## Configuration Editing

### Via UI (Settings Dialog)

The script provides a **Settings Dialog** (`Show-EditSettingsDialog`) accessible from the main window:

**Shared Settings Panel:**
- UNC Path text box (with validation: must start with `\\`)
- Browse button (folder picker)
- Reveal in Explorer button
- Machines list editor (add, edit, delete machines)

**Changes saved to**: `TrackSessions.Settings.json`

### Programmatically

```powershell
$settings = Read-TrackSessionsSettings -Path $SettingsPath
$settings.Tracking.SharedPath = "\\newserver\newshareshareName"
$settings.Tracking.Machines = @(
    [ordered]@{ ShortName = "PAWS001"; FQDN = ""; Comment = "..." }
)
Save-TrackSessionsSettings -Path $SettingsPath -Settings $settings
```

---

## Key Design Patterns

### 1. **Graceful Degradation**
- UNC unavailable? → Fall back to local output folder
- Users file missing? → No admin flag is set (non-admin assumed)
- Machines list empty? → Use hardcoded PAWS001/002/003 defaults

### 2. **Settings Persistence**
- Settings auto-created on first run with sensible defaults
- Window positions/sizes are updated on every close
- Startup trace events accumulate indefinitely (no automatic cleanup)

### 3. **User Identification**
- Multiple identity sources checked (SEID, UserId, SamAccountName, Environment)
- Case-insensitive matching
- Domain suffix stripped for flexible matching

### 4. **Admin Elevation Detection**
- Based on `IsAdmin` flag in `TrackSessions.Users.json`
- NOT based on Windows UAC or local admin group
- Allows fine-grained, centralized admin control per organization

---

## Summary: Pre-Defined Users + Machines Without UNC

### Fully Functional Configuration:
```json
{
    "Tracking": {
        "SharedPath": "",
        "Machines": [
            { "ShortName": "PAWS001", "FQDN": "", "Comment": "..." },
            { "ShortName": "PAWS002", "FQDN": "", "Comment": "..." }
        ]
    }
}
```

### What Works:
✅ Pre-defined machine list is monitored  
✅ Users in `TrackSessions.Users.json` are recognized  
✅ Admin flag (`IsAdmin`) is checked and applied  
✅ Login/logout/disconnect events are tracked  
✅ UI window positions are saved  

### What Changes:
📁 Output folder becomes: `%ProgramData%\SessionTracker\Json` (local machine)  
🔒 Events are NOT centralized (each machine keeps own logs)  
📊 Monitoring requires checking each machine individually  

### When to Add UNC Path:
1. **Multi-machine monitoring**: Need to see all sessions from central dashboard
2. **Audit/compliance**: Centralized session logs for all PAWS machines
3. **Remote monitoring**: Dashboard on different machine needs access to all events
