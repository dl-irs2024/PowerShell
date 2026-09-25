# Settings and Security Model for Session Tracker

## Problem Statement

The application needs to:
- **Centralize** configuration (UNC path, authorized users) to prevent individual modifications
- **Localize** user preferences (window size, position, UI zoom) per-machine
- **Protect** sensitive paths from exposure in script
- **Allow** read-only access to shared user list
- **Log** session data to a shared UNC location
- **Prevent** users from editing centralized settings

---

## Solution Architecture

### Configuration Hierarchy

```
┌─────────────────────────────────────────────────┐
│  Centralized Config (UNC Share - Read-Only)     │
│  ├─ Config.Master.json                          │
│  │  └─ Authorized User List                     │
│  │  └─ Primary UNC Path                         │
│  │  └─ Backup UNC Path (optional)               │
│  │  └─ Shared Settings Version                  │
│  └─ .config-signature (optional integrity)      │
└─────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────┐
│  Local User Settings (%APPDATA%)                │
│  ├─ TrackSessions.Settings.json                 │
│  │  └─ Window Position/Size                     │
│  │  └─ UI Zoom Level                            │
│  │  └─ Local Tracking Overrides (optional)      │
│  └─ TrackSessions.Manifest.json (optional)      │
│     └─ Tracks which configs were loaded         │
└─────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────┐
│  Shared Output (UNC Share - Read/Write)         │
│  ├─ Session.cr1.user.machine.timestamp.json     │
│  └─ Audit Log (optional)                        │
└─────────────────────────────────────────────────┘
```

---

## Implementation Details

### 1. Centralized Master Configuration (UNC Share)

**Location:** `\\SharedServer\SessionTracker\Config\Config.Master.json`

**File Permissions:**
- Created by: Administrator only
- Modified by: Administrator only
- Read by: Everyone (Domain Users)
- Everyone else: Read-Only

**Content Model:**
```json
{
  "Version": "1.0",
  "CreatedDate": "2026-09-06T00:00:00Z",
  "LastModifiedDate": "2026-09-06T00:00:00Z",
  "LastModifiedBy": "DOMAIN\\Administrator",
  "PrimaryOutputUNC": "\\\\SessionServer\\SessionLogs",
  "BackupOutputUNC": "\\\\SessionServer\\SessionLogsBackup",
  "AuthorizedUsers": {
    "Version": "1.0",
    "Users": [
      {
        "SamAccountName": "john.doe",
        "DisplayName": "John Doe",
        "Email": "john.doe@domain.com",
        "Department": "IT",
        "AllowedMachines": ["PAWS-001", "PAWS-002"],
        "IsAdmin": false,
        "IsActive": true,
        "AddedDate": "2026-01-15"
      },
      {
        "SamAccountName": "admin.user",
        "DisplayName": "Admin User",
        "Email": "admin.user@domain.com",
        "Department": "IT Security",
        "AllowedMachines": ["*"],
        "IsAdmin": true,
        "IsActive": true,
        "AddedDate": "2026-01-01"
      }
    ]
  },
  "ApplicationSettings": {
    "RequireUserApproval": false,
    "LogAuditTrail": true,
    "AuditLogPath": "\\\\SessionServer\\SessionLogs\\Audit",
    "AutoUpdateInterval": 180,
    "MinimumPSVersion": "5.1"
  },
  "Constraints": {
    "DisallowLocalPathOverride": true,
    "RequireNetworkValidation": true,
    "MaxOfflineGracePeriod": 3600
  }
}
```

**Integrity Protection:**
- Optional: Create `.config-signature` file with SHA256 hash
- Script validates hash on startup (if offline protection needed)
- Prevents local tampering with cached config

---

### 2. Local User Settings (%APPDATA%\SessionTracker)

**Location:** `C:\Users\USERNAME\AppData\Roaming\SessionTracker\TrackSessions.Settings.json`

**File Permissions:**
- Owner: User (read/write)
- Admins: read/write
- Other users: no access

**Content Model:**
```json
{
  "Version": "1.0",
  "LocalSettings": {
    "Layout": {
      "WindowWidth": 860,
      "WindowHeight": 460,
      "WindowLeft": 100,
      "WindowTop": 100,
      "BottomPaneHeight": 190
    },
    "UIPreferences": {
      "ZoomLevel": 1.0,
      "Theme": "Light",
      "AutoRefreshInterval": 180
    }
  },
  "CachedSettings": {
    "CachedMasterConfig": {
      "Timestamp": "2026-09-06T10:30:00Z",
      "ConfigVersion": "1.0",
      "PrimaryUNC": "\\\\SessionServer\\SessionLogs",
      "ValidUntil": "2026-09-06T11:30:00Z"
    }
  },
  "Tracking": {
    "Machines": [
      {
        "MachineName": "SERVER-01",
        "Enabled": true
      },
      {
        "MachineName": "SERVER-02",
        "Enabled": false
      }
    ],
    "SharedPath": null,
    "LocalOverridePath": null
  },
  "LastValidation": "2026-09-06T10:00:00Z"
}
```

---

## Security Implementation Strategy

### A. UNC Path Obfuscation

**Option 1: Encrypted Embedded Config**
```powershell
# Instead of hardcoding: \\SessionServer\SessionLogs
# Encrypt and embed a default "fallback" location

$encryptedUNC = "AQAAANCMnd8BFdERjHoAwE/Cl+sQAAAA..."
$decryptedUNC = Unprotect-SecureString $encryptedUNC -AsPlainText

# Load real UNC from master config (overrides fallback)
$configUNC = (Read-CentralConfig).PrimaryOutputUNC
```

**Option 2: Network Discovery**
```powershell
# Discover UNC from Active Directory
# Example: SRV record, DNS alias, or Group Policy

$uncPath = Get-SessionTrackerPath -FromAD
# AD administrators maintain the actual path
# Script never contains the real path
```

**Option 3: Hybrid Approach**
```powershell
# Script contains URL/endpoint, not UNC
$configServer = "https://appsettings.domain.com/session-tracker/config"
$config = Invoke-RestMethod $configServer

# Central web service returns the actual UNC
# Single point of control, auditable
```

### B. User List Management

**Flow:**
1. Master config stored on UNC (read-only)
2. Script downloads config at startup
3. User's SamAccountName validated against list
4. Unauthorized users → show error, disable functions

```powershell
function Validate-UserAuthorization {
    param([Parameter(Mandatory=$true)][object]$Config)
    
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $samAccount = $currentUser -split '\\' | Select-Object -Last 1
    
    $authorizedUsers = $Config.AuthorizedUsers.Users
    $userRecord = $authorizedUsers | Where-Object { $_.SamAccountName -eq $samAccount }
    
    if (-not $userRecord) {
        Show-UnauthorizedDialog
        exit 1
    }
    
    if (-not $userRecord.IsActive) {
        Show-DisabledUserDialog
        exit 1
    }
    
    return $userRecord
}
```

### C. Caching & Offline Scenarios

**Cache Strategy:**
```powershell
function Read-CentralConfig {
    param([string]$CentralConfigPath)
    
    try {
        # Attempt to load from UNC
        $config = Get-Content $CentralConfigPath | ConvertFrom-Json
        
        # Cache locally with timestamp
        $cacheFile = "$env:APPDATA\SessionTracker\ConfigCache.json"
        $config | Add-Member -NotePropertyName _CachedAt -NotePropertyValue (Get-Date) -Force
        $config | ConvertTo-Json -Depth 10 | Set-Content $cacheFile
        
        return $config
    }
    catch {
        # Fall back to cache if available
        $cacheFile = "$env:APPDATA\SessionTracker\ConfigCache.json"
        
        if (Test-Path $cacheFile) {
            $cachedConfig = Get-Content $cacheFile | ConvertFrom-Json
            $cacheAge = (Get-Date) - [DateTime]$cachedConfig._CachedAt
            
            if ($cacheAge.TotalSeconds -lt 3600) {
                # Cache is fresh (< 1 hour)
                Write-Warning "Using cached configuration (network unavailable)"
                return $cachedConfig
            }
            else {
                # Cache expired
                Write-Error "Network unavailable and cache expired"
                exit 1
            }
        }
        else {
            Write-Error "Cannot access central config and no cache available"
            exit 1
        }
    }
}
```

---

## File Permissions Setup

### UNC Share Configuration

```powershell
# PowerShell script to set up permissions (run as admin once)

$uncPath = "\\SessionServer\SessionTracker"
$configPath = "$uncPath\Config"
$logsPath = "$uncPath\Logs"

# Config directory (read-only for users)
icacls $configPath /inheritance:r /grant:r "DOMAIN\Domain Users:(OI)(CI)RX"
icacls $configPath /grant:r "DOMAIN\Administrators:(OI)(CI)F"

# Logs directory (read/write for users)
icacls $logsPath /inheritance:r /grant:r "DOMAIN\Domain Users:(OI)(CI)M"
icacls $logsPath /grant:r "DOMAIN\Administrators:(OI)(CI)F"

# Config.Master.json (read-only, immutable)
icacls "$configPath\Config.Master.json" /inheritance:r 
icacls "$configPath\Config.Master.json" /grant:r "DOMAIN\Domain Users:R"
icacls "$configPath\Config.Master.json" /grant:r "DOMAIN\Administrators:F"
```

---

## Workflow Summary

### On Application Startup

```
1. Load Local Settings (fast, always available)
   └─ Window position, zoom, local preferences
   
2. Attempt to Load Central Config
   ├─ Connect to UNC\\SessionServer\SessionTracker\Config
   ├─ Download Config.Master.json
   └─ Validate digital signature (if used)
   
3. Authorize Current User
   ├─ Extract SamAccountName
   ├─ Check against authorized user list
   ├─ Check AllowedMachines (if applicable)
   └─ Cache authorization result
   
4. Resolve Output Path
   ├─ Use PrimaryOutputUNC from central config
   └─ Validate write access
   
5. Initialize Application
   ├─ Show startup instructions overlay
   └─ Enable/disable features based on user role
```

---

## Key Security Principles

| Principle | Implementation |
|-----------|-----------------|
| **Centralized Authority** | Master config on UNC, admin-controlled |
| **Read-Only Distribution** | Users cannot modify shared settings |
| **Local Preferences** | Window state, zoom in user's AppData |
| **Path Obfuscation** | UNC path not in script, derived from config |
| **User Validation** | SamAccountName checked against authed list |
| **Offline Resilience** | Cache config locally, validate gracefully |
| **Audit Trail** | Log downloads and user validation events |
| **Immutability** | Config files locked down with NTFS ACLs |

---

## Future Enhancements

1. **Group Policy Integration**
   - Distribute config via GPSI or PowerShell DSC
   - Automatic updates without user intervention

2. **Encryption at Rest**
   - Encrypt UNC logs on server-side
   - DPAPI for sensitive local settings

3. **Role-Based Access Control (RBAC)**
   - Admin users: manage machines, view all logs
   - Standard users: view only their sessions
   - Auditors: view logs only

4. **Multi-Tenant Support**
   - Per-department user lists
   - Department-specific output paths
   - Segregated audit trails

5. **Configuration Versioning**
   - Keep multiple versions of Config.Master.json
   - Rollback capability if update breaks something
   - Version negotiation between script and config

6. **Compliance & Auditing**
   - Immutable audit log on UNC (append-only)
   - Track who accessed which configs
   - Log authorization failures

---

## Questions for Implementation

- Should backup UNC path auto-failover if primary is unreachable?
- Do you want to encrypt sensitive data in local settings?
- Should users be able to override machine list locally?
- How often should config be refreshed from central store?
- Should there be a web service layer instead of direct UNC access?
