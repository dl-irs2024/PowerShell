# Diff Summary: TrackSessions.Simulator CR1.PreReserve

**Comparison between:**
- `TrackSessions.Simulator CR1.PreReserve.2026-09-07.ps1` (original)
- `TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1` (modified)

**Date:** September 7, 2026  
**Purpose:** Enhancements for debug logging, file system monitoring, and improved state management

---

## Summary of Changes

This modification adds **debug logging infrastructure**, **file system watcher monitoring**, **improved error handling**, and **refined simulation logic** to the TrackSessions Simulator. The changes are primarily focused on diagnostics and reliability.

---

## Detailed Changes by Section

### 1. New Debug Logging Infrastructure

#### Added: `Add-DebugLog` Function
- **Location:** After script variables initialization, before window setup
- **Purpose:** Central logging function for diagnostic messages with timestamps
- **Keeps:** Last 500 log entries in memory to prevent unlimited growth
- **Format:** `[HH:mm:ss.fff] Message`

```powershell
function Add-DebugLog {
    param([string]$Message)
    $timestamp = [DateTime]::Now.ToString('HH:mm:ss.fff')
    $entry = "[$timestamp] $Message"
    $script:debugLog += $entry
    if ($script:debugLog.Count -gt 500) {
        $script:debugLog = @($script:debugLog | Select-Object -Last 500)
    }
}
```

#### Added: Debug Log Storage Variable
- **Location:** Variable initialization section
- **New variable:** `$script:debugLog = @()`
- **Purpose:** In-memory storage for debug log entries

---

### 2. UI Changes: New Debug Log Viewer Button

#### Added: `$btnLog` Control
- **XAML Change:** In button row Grid.ColumnDefinitions
  - Added new ColumnDefinition for `$btnLog`
  - Shifted `BtnMinimize` and `BtnCloseAfterSession` columns
- **Button Properties:**
  - Content: "Log..."
  - Width: 60 pixels
  - Tooltip: "Show debug and trace log output."

#### Added: `$btnLog` Click Handler
- **Location:** After `$btnEditSettings` click handler
- **Features:**
  - Creates a modal debug log window (800x600)
  - Displays all logged entries in read-only text box
  - Monospace font (Courier New, 11pt)
  - Two action buttons:
    - **Clear Log:** Empties the debug log and resets display
    - **Copy:** Copies full log to clipboard
    - **Close:** Closes the log viewer window
  - Updates display dynamically when "Clear" is clicked

---

### 3. Simulation State Machine Logic Change

#### Modified: `Get-NextSimulatedState` Function
- **Location:** In simulation setup section
- **Change:** Logic for 'Logged In' state

**Original:**
```powershell
'Logged In' {
    if ((Get-Random -Minimum 1 -Maximum 101) -le 45) {
        return 'Disconnected'
    }
    return 'Logged Out'
}
```

**Modified (mod1):**
```powershell
'Logged In' {
    if ((Get-Random -Minimum 1 -Maximum 101) -le 45) {
        return 'Disconnected'
    }
    return 'Logged In'    # Changed from 'Logged Out' to 'Logged In'
}
```

- **Impact:** Simulated sessions now stay "Logged In" more often before transitioning to "Disconnected"
- **Reasoning:** Provides more realistic user session behavior with longer active sessions

---

### 4. Session Grid Data Retrieval: Enhanced Logging

#### Enhanced: `Get-SessionGridRows` Function
- **Added at start:** Debug logging for function entry and folder path check
- **Added in loop:** Detailed logging for each JSON file processed
  - File name being processed
  - Parsed JSON validation
  - Machine token comparisons
  - Tracked machine filtering results
  - Inclusion/exclusion decisions with reasons
- **Added before deduplication:** Summary of all unique machines found
- **Added in dedup loop:** Entry/comparison/skip decisions with status
- **Added at end:** Final count comparison (before/after deduplication)

**New Debug Statements:**
```
"Session folder not found: $FolderPath"
"Found $($jsonFiles.Count) JSON session files in $FolderPath"
"Excluded machine (current): $ExcludeMachineName"
"Processing file: $($file.Name)"
"  -> JSON parsed but was null, skipping"
"  -> Skipping excluded machine: $machineValue"
"  -> File: ... | Machine: ... | User: ... | Status: ... | LastActivity: ..."
"  -> ERROR processing file: $($_.Exception.Message)"
"=== SUMMARY: All unique machines found in folder ==="
"  * $machine (EXCLUDED - current machine)" / "  * $machine"
"=== END SUMMARY ==="
"Added to final list: $key | Status: $($row.RowStatus)"
"Updating $key from Status: ... to ... (newer timestamp)"
"Skipped duplicate $key - keeping existing Status: ..."
"Failed to parse timestamps for $key, keeping existing"
"Deduplication complete: $($rows.Count) rows -> $($deduped.Values.Count) final entries"
```

---

### 5. Session Status Detection: Improved Parsing

#### Modified: `Get-SessionStatusFromSnapshot` Function
- **Change:** Use `Select-Object -ExpandProperty` instead of direct bracket notation
- **Benefit:** More robust handling of missing or null properties
- **Properties updated:**
  - `SessionStatus`
  - `SessionCloseEvent`
  - `SessionClosedAtGmt`
  - `LastUpdatedAtGmt`

**Pattern:**
```powershell
# Old: $sessionStatus = [string]$SnapshotObject.SessionStatus
# New: $sessionStatus = $SnapshotObject | Select-Object -ExpandProperty SessionStatus -ErrorAction SilentlyContinue
```

- **Timeout change:** Disconnected threshold changed from **10 minutes** to **3 minutes**

---

### 6. Grid Data Update Function: Enhanced with Logging & Error Handling

#### Completely Rewritten: `Update-SessionGridData` Function
- **Wrapped:** Entire function in try-catch block
- **Added:** Entry/exit debug logging with separator markers
- **Added:** Count logging after retrieving real rows
- **Added:** Simulation mode status and combined row count
- **Added:** Detailed listing of each row being displayed
- **Added:** Error logging for exceptions and stack traces
- **Added:** Null-safety checks before updating grid ItemsSource
- **Grid update:** Now clears ItemsSource, sets to null, then reassigns

**Debug Output Format:**
```
======= UPDATE-SESSIONGRIDDATA START =======
Got $($realRows.Count) real rows from folder
Simulation enabled - combined with ... simulated rows = ... total
Final grid will display ... entries:
  - MachineName | UserId | Status: ... | Activity: ...
======= UPDATE-SESSIONGRIDDATA END =======
```

---

### 7. Main Refresh Action: Error Handling & Protection

#### Modified: `$refreshAction` Script Block
- **Wrapped:** Entire block in try-catch
- **Added:** Null checks before accessing grid and ItemsSource
- **Added:** Error logging for exceptions and stack traces
- **Protection:** Safely handles cases where grid control doesn't exist or is null

---

### 8. Mini Session Panel: Non-Blocking Fade Animation

#### Modified: `Show-MiniSessionPanel` Function
- **Change:** Fade-out animation now uses **timer-based non-blocking approach**

**Original approach (blocking):**
```powershell
for ($opacity = 1.0; $opacity -ge 0; $opacity -= 0.1) {
    $miniWindow.Opacity = $opacity
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 50
}
```

**Modified approach (non-blocking timer):**
```powershell
$fadeTimer = New-Object System.Windows.Threading.DispatcherTimer
$fadeTimer.Interval = [TimeSpan]::FromMilliseconds(50)
$script:fadeOpacity = 1.0

$fadeTimer.Add_Tick({
    $script:fadeOpacity -= 0.1
    if ($script:fadeOpacity -lt 0) { $script:fadeOpacity = 0 }
    $miniWindow.Opacity = $script:fadeOpacity
    
    if ($script:fadeOpacity -le 0) {
        $fadeTimer.Stop()
        $miniWindow.Hide()
        $miniWindow.Opacity = 1.0
    }
})
$fadeTimer.Start()
```

- **Benefit:** UI remains responsive during fade animation

---

### 9. New Debug Log Viewer: `$btnLog` Click Handler

#### Added: Complete Debug Log Window
- **Window Size:** 800x600 pixels, centered on parent
- **Controls:**
  - Read-only TextBox with monospace font (Courier New, 11pt)
  - Automatic scroll bars (vertical and horizontal)
  - Button panel with three buttons:
    1. **Clear Log** - Clears debug log, re-adds confirmation entry
    2. **Copy** - Copies full log to clipboard, adds confirmation entry
    3. **Close** - Closes the window
- **Dynamic Updates:** Log display updates as operations are performed

---

### 10. Grid Refresh Timer: Automatic Updates Every 60 Seconds

#### Added: `$gridRefreshTimer` Timer
- **Location:** After icon timer creation, before initial `$refreshAction` call
- **Interval:** 60 seconds (1 minute)
- **Purpose:** Regular grid refresh independent of file system changes
- **Handler:**
  - Wrapped in try-catch
  - Calls `Update-SessionGridData`
  - Logs timer events and errors
- **Cleanup:** Stopped in window Close handler

```powershell
$gridRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
$gridRefreshTimer.Interval = [TimeSpan]::FromSeconds(60)
$gridRefreshTimer.Add_Tick({
    try {
        Add-DebugLog "Grid refresh timer fired - updating grid data"
        Update-SessionGridData
    }
    catch {
        Add-DebugLog "ERROR in grid refresh timer: $_"
    }
})
$gridRefreshTimer.Start()
```

---

### 11. File System Watcher: Monitor JSON Changes

#### Added: FileSystemWatcher for JSON Files
- **Location:** After grid refresh timer, before window.ShowDialog()
- **Path Monitored:** `$script:effectiveOutputFolder`
- **Filter:** `*.json` files only
- **Events Monitored:**
  - Changed
  - Created
  - Deleted

#### Added: `$fileChangedAction` Handler
- **Debouncing:** Prevents rapid consecutive updates (500ms minimum interval)
- **UI Thread Safety:** Uses `Dispatcher.BeginInvoke` for thread-safe updates
- **Non-blocking:** Calls `Update-SessionGridData` asynchronously
- **Error Handling:** Comprehensive try-catch blocks with debug logging

**Implementation:**
```powershell
$script:lastFileWatcherTime = [System.Diagnostics.Stopwatch]::StartNew()
$fileChangedAction = {
    param($source, $eventArgs)
    # Debounce check
    if ($script:lastFileWatcherTime.ElapsedMilliseconds -lt 500) {
        return
    }
    $script:lastFileWatcherTime.Restart()
    
    # Non-blocking UI update
    try {
        $window.Dispatcher.BeginInvoke({
            try {
                Add-DebugLog "FileSystemWatcher detected change: $($eventArgs.Name)"
                Update-SessionGridData
            }
            catch { Add-DebugLog "ERROR updating grid from file watcher: $_" }
        }) | Out-Null
    }
    catch { Add-DebugLog "ERROR in file watcher dispatcher: $_" }
}
```

#### Current Status: TEMPORARILY DISABLED
- **Note:** `EnableRaisingEvents = $true` is currently commented out
- **Reason:** FileSystemWatcher causing crashes during testing
- **Mitigation:** Grid refresh timer (every 60 seconds) provides fallback updates
- **Comment in code:** "TEMPORARILY DISABLED: FileSystemWatcher causing crash - disable for testing"

#### Cleanup in Window Close Handler
```powershell
if ($watcher) {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
}
```

---

### 12. Window Close Handler: Enhanced Cleanup

#### Modified: `$window.Add_Closed` Handler
- **Added:** Stop and cleanup of `$gridRefreshTimer`
- **Added:** Disable and dispose of `$watcher` FileSystemWatcher

---

## Integration Notes for Merging

### Prerequisites
- All changes are **additive** with one behavioral change (Get-NextSimulatedState)
- **No breaking changes** to existing function signatures
- **New functions** are isolated and don't override existing code

### Merge Strategy Recommendations

1. **Apply debug logging additions first:**
   - Add `Add-DebugLog` function
   - Add `$script:debugLog = @()` initialization
   - Add debug logging statements throughout existing functions

2. **Update Get-NextSimulatedState:**
   - Change return value from 'Logged Out' to 'Logged In'
   - Test simulation behavior

3. **Add UI enhancements:**
   - Add `$btnLog` button to XAML
   - Add `$btnLog` variable retrieval after button refs
   - Add `$btnLog` click handler

4. **Update function implementations:**
   - Enhance `Get-SessionGridRows` with debug logging
   - Update `Get-SessionStatusFromSnapshot` to use Select-Object
   - Rewrite `Update-SessionGridData` with error handling
   - Update `$refreshAction` with error handling
   - Update `Show-MiniSessionPanel` fade animation

5. **Add monitoring infrastructure:**
   - Add `$gridRefreshTimer` creation and handler
   - Add `$fileChangedAction` handler and FileSystemWatcher setup
   - Add cleanup code to window Close handler

### Testing Checklist

- [ ] Debug log window opens and displays entries
- [ ] Clear Log button works and resets display
- [ ] Copy button copies to clipboard successfully
- [ ] Simulation mode produces realistic state transitions
- [ ] Grid updates every 60 seconds (regardless of file changes)
- [ ] FileSystemWatcher can be re-enabled when stability verified
- [ ] Mini window fade animation is smooth and non-blocking
- [ ] No crashes when FileSystemWatcher disabled
- [ ] All error messages appear in debug log
- [ ] Debug log respects 500-entry limit

---

## Files Affected

- **Current:** `TrackSessions.Simulator CR1.PreReserve.2026-09-07.ps1`
- **Target:** Should become `TrackSessions.Simulator CR1.ps1` (production version)
- **This diff applies mod1 changes to**: Create enhanced version with diagnostics

---

## Migration Path

Once stability is verified and FileSystemWatcher reliability is confirmed:

1. Enable FileSystemWatcher in production
2. Remove debug logging overhead if performance impact observed
3. Merge into main `TrackSessions.Simulator CR1.ps1`
4. Update version string in window title if needed
5. Archive this .mod1 version for reference

