# Maintainable PowerShell Patterns: TrackSessions System

## Overview
This document captures lessons learned from debugging a 2,500+ line WPF + PowerShell system spanning 7 integrated phases. Each section identifies a real problem encountered and recommends solutions for production readiness.

---

## 1. Scope Management: The Invisible Killer

### The Problem
PowerShell's scope rules are unpredictable in async contexts:
- Event handlers lose access to local functions during `ShowDialog()`
- Timer callbacks run in different thread contexts
- WPF modal loops create hidden scope boundaries
- `&` call operator creates child scopes that don't propagate back

### Real Example
```powershell
# ❌ THIS FAILS - Function loses scope during ShowDialog()
function MyFunction { Write-Host "Hello" }
$timer.Add_Tick({ MyFunction })  # ← Error during modal dialog
$window.ShowDialog()             # ← "MyFunction is not recognized"
```

### Solutions

#### 1a. Use Module Scope ($script:) for Event Handler Functions
```powershell
# ✅ WORKS - Variable persists in script scope
$script:MyData = @()
$script:RefreshAction = {
    # Can access $script:MyData reliably
    foreach ($item in $script:MyData) { ... }
}
$timer.Add_Tick($script:RefreshAction)
$window.ShowDialog()  # Works!
```

**Why it works**: `$script:` is module-scoped. Even during ShowDialog(), the timer can access it.

#### 1b. Use Error Handling for Event Handler Functions
```powershell
# ✅ DEFENSIVE - Handles scope loss gracefully
function Refresh-Data { ... }

$timer.Add_Tick({
    try {
        # Check if function exists before calling
        if (Get-Command Refresh-Data -ErrorAction SilentlyContinue) {
            Refresh-Data
        }
    }
    catch {
        # Silent failure during modal operations is acceptable
        # Log to file if needed: $_ | Out-File -Append $logPath
    }
})
```

**Why it works**: If function isn't accessible, we catch the error instead of crashing.

#### 1c. Pause Operations During Modal Dialogs
```powershell
# ✅ PROACTIVE - Stop timers during modal operations
$timer.Stop()
$window.ShowDialog()
$timer.Start()
```

**Why it works**: No async operations = no scope issues. Simple and reliable.

### Recommendation
**Use combination approach**:
1. Store data in `$script:` scope (never lose state)
2. Wrap function calls in try-catch in event handlers
3. Pause high-frequency timers during modal dialogs
4. Log errors to file instead of silent failures

---

## 2. Settings File Fragility: Trust Nothing

### The Problem
External tools (formatters, linters, editors) modify JSON files:
- VS Code formatters strip unknown properties
- JSON schema validation removes custom fields
- Third-party tools normalize formatting and lose data

### Real Example
```json
// ❌ FRAGILE - Custom properties get removed by formatters
{
  "Tracking": { "SharedPath": "" },
  "Reservations": { "BusinessHoursStart": "09:00" }  // ← Formatter removes this
}
```

### Solutions

#### 2a. Defensive Defaults Everywhere
```powershell
# ✅ BEST PRACTICE - Never crash from missing settings
function Get-ReservationSettings {
    param([string]$SettingsPath)
    
    try {
        $settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
    }
    catch {
        # If file corrupted, return defaults immediately
        return @{
            BusinessHoursStart = '09:00'
            BusinessHoursEnd = '18:00'
            TimeSlotGranularity = 30
        }
    }
    
    # Return defaults if section missing, don't error
    if (-not $settings.PSObject.Properties.Name -contains 'Reservations') {
        return @{
            BusinessHoursStart = '09:00'
            BusinessHoursEnd = '18:00'
            TimeSlotGranularity = 30
        }
    }
    
    return $settings.Reservations
}
```

**Why it works**: User experiences graceful degradation instead of crashes.

#### 2b. Schema Version Detection
```powershell
# ✅ FORWARD-COMPATIBLE - Handle multiple schema versions
function Read-Settings {
    param([string]$Path)
    
    $json = Get-Content $Path -Raw | ConvertFrom-Json
    $version = $json.SchemaVersion ?? '0.0'
    
    switch ($version) {
        '1.0' { return Convert-SettingsV1 $json }
        '1.1' { return Convert-SettingsV1_1 $json }
        '2.0' { return Convert-SettingsV2 $json }
        default {
            Write-Warning "Unknown schema version: $version. Using defaults."
            return Get-DefaultSettings
        }
    }
}
```

**Why it works**: When you add new settings, old configs don't break.

#### 2c. Atomic Write Operations
```powershell
# ✅ SAFE - Prevents partial writes and corruption
function Save-Settings {
    param([object]$Settings, [string]$Path)
    
    $tempPath = "$Path.tmp"
    
    try {
        # Write to temp first
        $Settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath
        
        # Only swap if write succeeded
        Move-Item -LiteralPath $tempPath -Path $Path -Force
    }
    catch {
        # Clean up temp file on failure
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        throw
    }
}
```

**Why it works**: If the process crashes mid-write, the original file is still intact.

### Recommendation
**Three-tier strategy**:
1. **Tier 1**: Detect and handle missing/corrupted settings gracefully
2. **Tier 2**: Use atomic file operations (write-to-temp then rename)
3. **Tier 3**: Make Settings.json read-only to prevent formatter interference

---

## 3. Module Loading: Import vs Dot-Source vs Invoke

### The Problem
Three different operators do similar but different things:
- `Import-Module` → Loads into separate namespace, public/private exports
- `. script.ps1` → Dot-source loads into current scope
- `& script.ps1` → Call operator loads in child scope

### Real Example
```powershell
# ❌ FRAGILE - Function defined in script.ps1 disappears after & runs
& 'Dialog.ps1'  # ← Defines function Dialog-Show in child scope
$timer.Add_Tick({ Dialog-Show })  # ← ERROR: Function not accessible after script completes
```

### Solutions

#### 3a. Use Module Format for Shared Code
```powershell
# TrackSessions.Reservations.psm1
# ✅ MODULAR - Clean namespace, explicit exports

function Public-Function { ... }
function Private-Function { ... }  # Prefix with "Private-" or use @Export

Export-ModuleMember -Function @('Public-Function', 'Public-Function2')
```

```powershell
# Main script
# ✅ CLEAN IMPORT - Functions available in global scope
Import-Module 'TrackSessions.Reservations.psm1' -Force
Public-Function  # Works!
```

**Why it works**: Module scope is explicit. No surprises about what's available.

#### 3b. Dot-Source for Shared Utilities
```powershell
# ✅ SCOPE-SHARING - Utilities become part of current scope
. 'Shared-Utilities.ps1'
SharedFunction  # Works! Function now in same scope

$timer.Add_Tick({ SharedFunction })  # Also works!
```

**When to use**: Helper functions that need to be referenced from event handlers.

#### 3c. Invoke (&) Only for Standalone Scripts
```powershell
# ✅ ISOLATED - Dialog runs independently, returns results via output
$result = & 'Dialog.ps1' -Param1 $value
# Dialog can't affect caller's scope (good for isolation)
```

**When to use**: Self-contained scripts that don't need to share functions with caller.

### Recommendation
```
┌─────────────────────────────────────────────────────┐
│ Shared Functions     → Use modules (.psm1)          │
│ Event Handlers       → Dot-source or module         │
│ Standalone Dialogs   → Use & call operator         │
│ Data/Config Files    → No scripting needed          │
└─────────────────────────────────────────────────────┘
```

---

## 4. Event Handler Initialization Order: Load Before Trigger

### The Problem
WPF event handlers fire when properties change. If data isn't ready, handlers crash:
```powershell
# ❌ WRONG ORDER - Handler fires before data is loaded
$cmbMachine.Items.Add("Machine1")
$cmbMachine.Add_SelectionChanged({
    # This fires immediately, but $script:Machines might not be loaded yet!
    Process-Selection $script:Machines
})
$cmbMachine.SelectedIndex = 0  # ← Handler fires NOW, before data loaded!
```

### Solutions

#### 4a. Load Data BEFORE Triggering Events
```powershell
# ✅ CORRECT ORDER
# Step 1: Populate combo box items
$cmbMachine.Items.Add("Machine1")
$cmbMachine.Items.Add("Machine2")

# Step 2: Load data that handler needs
$script:Machines = Load-MachineData

# Step 3: Register event handler
$cmbMachine.Add_SelectionChanged({
    Process-Selection $cmbMachine.SelectedItem  # Now safe!
})

# Step 4: Trigger events
$cmbMachine.SelectedIndex = 0  # Handler fires with data ready
```

**Why it works**: Handlers only run after dependencies are initialized.

#### 4b. Null-Check in All Event Handlers
```powershell
# ✅ DEFENSIVE - Handle both pre-load and post-load states
$radio.Add_Checked({
    # Data might not be loaded yet, or dialog might be closing
    if ($script:monthView) {
        $script:monthView.Visibility = 'Visible'
    }
})
```

#### 4c. Lazy Initialization Pattern
```powershell
# ✅ DEFERRED - Don't initialize until first access
$script:CachedData = $null

function Get-CachedData {
    if ($null -eq $script:CachedData) {
        $script:CachedData = Load-ExpensiveData
    }
    return $script:CachedData
}
```

### Recommendation
1. Load **all data** before registering **any event handlers**
2. Register event handlers **before** triggering property changes
3. Null-check in every event handler (data might not be available)
4. Use lazy initialization for expensive operations

---

## 5. PowerShell Collection Quirks: The @ Wrapper

### The Problem
`.Count` property behaves differently based on collection size:
```powershell
$items = @()
$items.Count  # ← Returns $null, not 0!

$items = @(1)
$items.Count  # ← Returns 1 (not wrapped)

$items = @(1,2)
$items.Count  # ← Returns 2 (correctly)
```

### Solutions

#### 5a. Always Wrap with @()
```powershell
# ✅ SAFE - Always works regardless of count
@($array).Count  # 0, 1, 2, ... all work correctly

# ✅ SAFE - Length also works
$array.Length    # Consistent across all sizes

# ❌ AVOID
$array.Count     # Unreliable for 0-1 items
```

#### 5b. Use Measure-Object for Clarity
```powershell
# ✅ EXPLICIT - Immediately obvious what we're measuring
$count = @($array) | Measure-Object | Select-Object -ExpandProperty Count

# ✅ CONCISE - Count 0-1 items reliably
$array.Count  # Only after wrapping with @()
```

#### 5c. Use -Contains and -In for Existence Checks
```powershell
# ✅ BETTER - Purpose is clear
if ($items -contains $targetItem) { ... }
if ($targetItem -in $items) { ... }

# ❌ LESS CLEAR
if (@($items).Count -gt 0) { ... }
```

### Recommendation
**Rule: Always wrap arrays with @() before accessing .Count**
```powershell
# BAD
if ($collection.Count -eq 0) { }

# GOOD
if (@($collection).Count -eq 0) { }
```

---

## 6. Error Handling: Context Matters

### The Problem
Silent failures hide problems. Crashes interrupt users. Finding the middle ground is hard.

### Solutions

#### 6a. Log Errors to File for Debugging
```powershell
# ✅ BEST - User-facing silence, but errors logged
$ErrorLogPath = Join-Path $script:SettingsPath 'Errors.log'

function Log-Error {
    param([string]$Message, [object]$Exception)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp | $Message | $Exception" | Out-File -LiteralPath $ErrorLogPath -Append
}

$timer.Add_Tick({
    try {
        Refresh-Data
    }
    catch {
        Log-Error 'Timer refresh failed' $_
    }
})
```

**Why it works**: Users see stable UI, but you can debug via logs.

#### 6b. Classify Errors: User vs Internal
```powershell
# ✅ USER ERRORS - Show message box
try {
    $result = New-Item -Path $path -Force -ErrorAction Stop
}
catch {
    # User needs to know this failed
    [System.Windows.MessageBox]::Show("Cannot create folder: $_", 'Error', 'OK', 'Error')
}

# ✅ INTERNAL ERRORS - Log silently
try {
    Update-UIElement
}
catch {
    # This is internal; user doesn't need to know
    Log-Error 'UI update failed' $_
}
```

#### 6c. Use Try-Catch-Finally for Cleanup
```powershell
# ✅ GUARANTEED CLEANUP
try {
    $timer.Stop()
    ShowDialog
}
catch {
    Log-Error 'Dialog failed' $_
}
finally {
    # Always runs, even if error occurred
    $timer.Start()
    Cleanup-Resources
}
```

### Recommendation
```
Error Severity Chart:
┌──────────────────────────────────────────┐
│ User-blocking (New Reservation)   →  Show MessageBox
│ UI-only (Refresh Timer)           →  Log silently, continue
│ Configuration (Missing Settings)  →  Use defaults, Log warning
│ Async (Timer, Event)              →  Log, ignore, continue
└──────────────────────────────────────────┘
```

---

## 7. Breaking Large Scripts Into Testable Pieces

### The Problem
2,500-line monolithic scripts are untestable and hard to debug:
- Can't test individual functions in isolation
- Everything depends on everything else
- One bug affects the whole app
- Hard to locate the actual error

### Solutions

#### 7a. Extract Functions Into Modules
```powershell
# ❌ UNTESTABLE - 500 lines in main script
TrackSessions.Simulator CR1.ps1
  - Session loading logic (100 lines)
  - UI rendering (200 lines)
  - Data refresh (100 lines)
  - Event handlers (100 lines)

# ✅ TESTABLE - Functions in modules
TrackSessions.Session.psm1
  - function Load-Session { }          # Can unit test
  - function Save-Session { }          # Can unit test
  
TrackSessions.UI.psm1
  - function Render-SessionList { }    # Can unit test
  - function Update-GridData { }       # Can unit test

TrackSessions.Simulator CR1.ps1
  - Imports modules
  - Wires up UI (high-level orchestration only)
```

**Benefits**:
- Each module can be tested independently
- Easier to fix bugs (smaller surface area)
- Easier to reuse code in other projects

#### 7b. Use Pester for Testing
```powershell
# TrackSessions.Session.tests.ps1
# ✅ TESTABLE - Verify behavior without UI
Import-Module 'TrackSessions.Session.psm1'

Describe 'Load-Session' {
    It 'loads valid session file' {
        $session = Load-Session 'ValidPath'
        $session.SessionId | Should -Not -BeNullOrEmpty
    }
    
    It 'returns $null for missing file' {
        $session = Load-Session 'InvalidPath'
        $session | Should -Be $null
    }
}

Describe 'Save-Session' {
    It 'creates file with correct format' {
        Save-Session @{SessionId='123'} 'OutputPath'
        $saved = Get-Content 'OutputPath' | ConvertFrom-Json
        $saved.SessionId | Should -Be '123'
    }
}
```

**Why it works**: Run tests independent of UI, database, Outlook, etc.

#### 7c. Dependency Injection for Testability
```powershell
# ❌ TIGHTLY COUPLED - Can't test without real database
function Load-Sessions {
    $data = Get-SessionsFromDatabase  # Hard dependency
    return $data
}

# ✅ LOOSELY COUPLED - Can inject test data
function Load-Sessions {
    param(
        [scriptblock]$DataProvider = { Get-SessionsFromDatabase }
    )
    $data = & $DataProvider
    return $data
}

# Test version - inject mock data
$mockData = @{ SessionId = '123' }
Load-Sessions -DataProvider { $mockData }
```

### Recommendation
```
Code Organization:
┌─────────────────────────────────────────────────────┐
│ .psm1 files    - Pure functions (testable)          │
│ .ps1 files     - Orchestration only (thin wrapper)  │
│ .tests.ps1     - Pester tests for each module       │
│ Main script    - Import modules + wire UI           │
└─────────────────────────────────────────────────────┘
```

---

## 8. Documentation: Comments Decay, Code Doesn't

### The Problem
Comments become lies over time:
```powershell
# ❌ OUTDATED - Comment says one thing, code does another
# This loads the session file from disk
$data = Get-SessionsFromAPI  # ← API call, not disk!
```

### Solutions

#### 8a. Comment the "Why", Not the "What"
```powershell
# ✅ GOOD - Explains intent
# Use atomic write to ensure file isn't corrupted if process crashes mid-write
$tempPath = "$Path.tmp"
$json | Set-Content -LiteralPath $tempPath
Move-Item -LiteralPath $tempPath -Path $Path -Force

# ❌ BAD - Just describes code
# Create temp path
$tempPath = "$Path.tmp"
# Write JSON content
$json | Set-Content -LiteralPath $tempPath
# Move file
Move-Item -LiteralPath $tempPath -Path $Path -Force
```

#### 8b. Document Assumptions and Side Effects
```powershell
# ✅ CLEAR - Explains when function is safe to use
<#
.SYNOPSIS
    Updates the session grid.
    
.NOTES
    ASSUMES: $gridSessionFiles already loaded from XAML
    ASSUMES: $script:CurrentSessionData is populated
    SIDE EFFECTS: Modifies $gridSessionFiles.ItemsSource
    SAFE ASYNC: No - use from UI thread only
#>
function Update-SessionGridData { }
```

#### 8c. Create README for Each Module
```markdown
# TrackSessions.Reservations.psm1

## Purpose
Core CRUD operations for machine reservations with conflict detection.

## Functions
- Get-Reservations: Retrieve all active reservations
- New-Reservation: Create reservation with conflict detection
- Test-ReservationConflict: Check for scheduling conflicts

## Dependencies
- TrackSessions.Reservations.psm1 must be imported first
- Settings.json must have [Reservations] section

## Example
$res = New-Reservation -MachineName 'Server1' -StartTime '09:00' -Duration 60
```

### Recommendation
```
Documentation Hierarchy:
┌──────────────────────────────────────────────────┐
│ Function .SYNOPSIS        - What it does         │
│ Function .DESCRIPTION     - How to use it        │
│ Function .NOTES           - When/why it works    │
│ Code comments             - Why we chose this    │
│ Module README             - Big picture          │
│ Architecture docs         - System design        │
└──────────────────────────────────────────────────┘
```

---

## 9. Real-World Patterns: Putting It Together

### Example: The "Resilient Refresh" Pattern
```powershell
# ✅ PRODUCTION-READY - Combines 7 lessons above

# 1. Store data in script scope
$script:CachedReservations = @()
$script:LastRefreshTime = $null

# 2. Defensive function with error handling
function Refresh-ReservationData {
    param(
        [scriptblock]$DataLoader = { Get-Reservations }
    )
    
    try {
        # 3. Use atomic-like operation (lazy refresh)
        $timeSinceRefresh = [datetime]::Now - $script:LastRefreshTime
        if ($timeSinceRefresh.TotalSeconds -lt 5) {
            return  # Don't hammer disk/API
        }
        
        # 4. Log what we're doing
        Log-Event "Refreshing reservations"
        
        # 5. Use injected data provider (testable)
        $data = & $DataLoader
        
        # 6. Validate before storing
        if ($null -eq $data) {
            Log-Error "Data loader returned null"
            return
        }
        
        # 7. Use @() wrapper for reliability
        $script:CachedReservations = @($data)
        $script:LastRefreshTime = [datetime]::Now
        
        Log-Event "Refresh complete: $(@($script:CachedReservations).Count) items"
    }
    catch {
        # 8. Error classification - this is internal
        Log-Error "Refresh-ReservationData failed" $_
    }
}

# 9. Use in timer with error handling
$refreshTimer = New-Object System.Windows.Threading.DispatcherTimer
$refreshTimer.Interval = [timespan]::FromSeconds(30)
$refreshTimer.Add_Tick({
    try {
        if (Get-Command Refresh-ReservationData -ErrorAction SilentlyContinue) {
            Refresh-ReservationData
        }
    }
    catch {
        # Silently ignore
    }
})
$refreshTimer.Start()
```

### Example: The "Defensive Settings" Pattern
```powershell
# ✅ SETTINGS FILE - Never crashes, always has defaults

function Get-ReservationSettings {
    param([string]$SettingsPath)
    
    $defaults = @{
        BusinessHoursStart = '09:00'
        BusinessHoursEnd = '18:00'
        TimeSlotGranularity = 30
        AllowPastDateReservations = $false
        PreventOverlappingReservations = $false
    }
    
    try {
        if (-not (Test-Path -LiteralPath $SettingsPath)) {
            return $defaults
        }
        
        $json = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json -ErrorAction Stop
        
        # Check for Reservations section
        if (-not $json.PSObject.Properties.Name -contains 'Reservations') {
            return $defaults
        }
        
        # Return actual settings, filling in any missing properties
        $settings = $json.Reservations
        foreach ($key in $defaults.Keys) {
            if (-not $settings.PSObject.Properties.Name -contains $key) {
                $settings | Add-Member -MemberType NoteProperty -Name $key -Value $defaults[$key]
            }
        }
        
        return $settings
    }
    catch {
        Log-Error "Error reading settings, using defaults" $_
        return $defaults
    }
}
```

---

## 10. Checklist: Making Your Scripts Production-Ready

### Code Quality
- [ ] All event handlers have null checks (`if ($script:Variable)`)
- [ ] All `.Count` accesses wrap arrays with `@()`
- [ ] All async operations (timers, threads) have try-catch
- [ ] All file operations are atomic (write-to-temp then rename)
- [ ] All database/external calls have fallback defaults

### Configuration
- [ ] Settings file validated on startup
- [ ] Missing settings return safe defaults (not errors)
- [ ] Schema version in settings for future upgrades
- [ ] Settings file is read-only (prevent external modification)

### Error Handling
- [ ] User-facing errors show MessageBox
- [ ] Internal errors logged to file
- [ ] No silent crashes (all try-catch blocks)
- [ ] Error logs easy to find and parse

### Debugging
- [ ] Startup trace logging enabled
- [ ] Key operations logged with timestamps
- [ ] Debug output goes to file, not console
- [ ] User can enable/disable logging in settings

### Testing
- [ ] Core functions extracted to .psm1 modules
- [ ] Each module has corresponding .tests.ps1
- [ ] Functions accept $-Provider parameters for injection
- [ ] Tests run without UI, database, or Outlook

### Documentation
- [ ] Each function has .SYNOPSIS + .NOTES
- [ ] Module has README.md with purpose and examples
- [ ] Assumptions documented (what must be loaded first?)
- [ ] Side effects documented (what changes state?)

---

## 11. When Things Go Wrong: Debugging Toolkit

### Startup Trace Logging
```powershell
# ✅ BUILT-IN DEBUG - Enable in settings
$traceEnabled = $true
function Append-StartupTrace {
    param([string]$EventName, [string]$Detail)
    
    if (-not $traceEnabled) { return }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $trace = @{ TimestampUtc = $timestamp; Event = $EventName; Detail = $Detail }
    
    $settingsJson.StartupTrace.Events += $trace
    $settingsJson | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath
}

# Then in code:
Append-StartupTrace 'Main.Loaded' 'Window loaded successfully'
Append-StartupTrace 'Dialog.Opened' "Opened for machine: $machine"
```

### Common Error Patterns
| Error | Root Cause | Fix |
|-------|-----------|-----|
| "Function not recognized" | Scope lost in event handler | Wrap call in try-catch, use $script: prefix |
| "Property cannot be found" | Missing settings section | Use PSObject.Properties.Name check |
| ".Count returns null" | Single-item array | Wrap with @() before .Count |
| "ShowDialog crashes" | Timer fires during modal | Pause timer or add error handling |
| "Settings reverted" | External formatter | Make read-only or accept defaults |
| "File corrupted" | Partial write | Use atomic write (temp + rename) |

---

## Conclusion

The TrackSessions system started as a monolithic 2,500-line script with tight coupling and fragile assumptions. Through systematic debugging, we discovered that **PowerShell's async model is fundamentally different from synchronous scripts**.

### Key Takeaway
**Design for failure, not success.**

Every external dependency (file system, JSON parsing, UI events, timers, Outlook) should:
1. Have a graceful fallback (defensive defaults)
2. Be wrapped in try-catch (error handling)
3. Be testable in isolation (dependency injection)
4. Be documented with assumptions (why it works)

This isn't pessimistic—it's pragmatic. Real systems fail. Real files get corrupted. Real formatters modify JSON. Real timers fire at awkward moments. **Code that handles these realities transparently will outlast code that doesn't.**

### Next Steps
1. Extract testable modules from main script
2. Add Pester test suite
3. Implement structured logging to file
4. Make Settings.json read-only
5. Document each module with README
6. Review error handling on every async operation
