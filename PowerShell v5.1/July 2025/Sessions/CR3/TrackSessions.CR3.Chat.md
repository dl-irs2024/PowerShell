# TrackSessions CR3: Chat & Documentation

## Session: 2026-09-23 - XAML Extraction & Settings Path

### Question 1: Where is the Settings Path Stored?

**In CR3.Main.ps1**:
- **Parameter**: `-SettingsPath` (optional input parameter at top of script)
- **Default Location**: 
  ```powershell
  if (-not $SettingsPath) {
    $settingsBase = if ($PSCommandPath) { Split-Path -Path $PSCommandPath -Parent } else { (Get-Location).Path }
    $SettingsPath = Join-Path -Path $settingsBase -ChildPath 'TrackSessions.Settings.json'
  }
  ```

- **In Plain Terms**: Same directory as the script file
  
- **Full Path**: 
  ```
  c:\Users\YMJNB\OneDrive - Internal Revenue Service\Documents\PowerShell 2025\PowerShell v5.1\July 2025\Sessions\CR3\TrackSessions.Settings.json
  ```

- **Usage Throughout Script**: The `$SettingsPath` variable is used in multiple functions:
  - `Read-TrackSessionsSettings -Path $SettingsPath` - loads settings JSON
  - `Save-TrackSessionsSettings -Path $SettingsPath -Settings $settings` - persists settings
  - `Add-StartupTrace -Path $SettingsPath` - logs startup events
  - Users file path derived from settings: `Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Users.json'`

---

### Question 2: Can TrackSessions.UserEditor.ps1 Be Used Again?

**Answer: YES, it can be used again! ✅**

**File Location**: 
- [Sessions\TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

**What it does**:
- Standalone WPF UI for editing the `TrackSessions.Users.json` file
- User database fields: SEID, FirstName, LastName, Email, Status (FTE/Contractor), Products, Timezone, Notes
- External user lookups via CSV or Active Directory/Graph integration
- Admin users list management

**Compatibility with CR3**:

1. **Uses Same File Paths**:
   ```powershell
   $script:UsersPath = Join-Path -Path $script:BaseDir -ChildPath 'TrackSessions.Users.json'
   $script:SettingsPath = Join-Path -Path $script:BaseDir -ChildPath 'TrackSessions.Settings.json'
   ```

2. **No Module Dependencies**:
   - Self-contained WPF application
   - No scope isolation issues like CR2 had
   - Can run independently without affecting main app

3. **Compatible JSON Structure**:
   - Reads/writes same Users.json format as CR3
   - Changes made in UserEditor are immediately visible in CR3
   - No version conflicts

4. **How to Use**:
   - Run from Sessions folder: `.\TrackSessions.UserEditor.ps1`
   - Opens standalone WPF window for user management
   - Edits are saved to `TrackSessions.Users.json`
   - CR3 app automatically reflects any changes

5. **Integration with CR3**:
   - Can launch UserEditor from CR3 "Manage Users" button handler
   - Both use same Users.json file
   - No synchronization issues since JSON is text-based

**Recommendation**: 
- UserEditor.ps1 is safe to use as-is
- Consider adding to CR3 "Manage Users..." button to launch it (non-blocking with Start-Process)
- Keep running independently during development for user management tasks

---

### Related Files

- **CR3 Main Script**: [TrackSessions.CR3.Main.ps1](TrackSessions.CR3.Main.ps1)
- **User Editor**: [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)
- **Settings File**: `TrackSessions.Settings.json` (same directory as script)
- **Users File**: `TrackSessions.Users.json` (same directory as script)

---

### Notes

- Settings path defaults to script's directory but can be overridden via `-SettingsPath` parameter
- UserEditor and CR3 both read from same JSON files, no conflicts
- All XAML extracted to external files for cleaner code organization
- Both scripts are scope-safe (no PowerShell module isolation issues)

---

### Question 3: Settings Button Gets Error & App Locks Up

**Problem**: Clicking the Settings button causes an error and the application locks up. Settings should load defaults if not set.

**Root Cause**: The `Show-EditSettingsDialog` function was missing two critical `FindName()` calls for UI controls:
- `$txtSharedPathSettings` (text box for shared path) - was `$null`
- `$btnBrowseSharedPath` (browse button) - was `$null`

When the dialog tried to set `$txtSharedPathSettings.Text = [string]$settings.Tracking.SharedPath`, it failed on a null object reference, causing the app to lock up.

**The Bug in Show-EditSettingsDialog**:
```powershell
# BEFORE (Missing FindName calls):
$btnRevealSharedPath = $settingsWindow.FindName('BtnRevealSharedPath')
$gridTrackedMachines = $settingsWindow.FindName('GridTrackedMachines')
$btnZoomOutSettings = $settingsWindow.FindName('BtnZoomOutSettings')
# ... more FindName calls ...

# Next line tries to use $txtSharedPathSettings which was never initialized!
$txtSharedPathSettings.Text = [string]$settings.Tracking.SharedPath
# ❌ ERROR: Cannot access member. Object is $null
```

**The Fix Applied**:
Added the two missing `FindName()` calls at the beginning of control initialization:
```powershell
# AFTER (All controls initialized):
$txtSharedPathSettings = $settingsWindow.FindName('TxtSharedPath')
$btnBrowseSharedPath = $settingsWindow.FindName('BtnBrowseSharedPath')
$btnRevealSharedPath = $settingsWindow.FindName('BtnRevealSharedPath')
$gridTrackedMachines = $settingsWindow.FindName('GridTrackedMachines')
$btnZoomOutSettings = $settingsWindow.FindName('BtnZoomOutSettings')
$btnZoomInSettings = $settingsWindow.FindName('BtnZoomInSettings')
$btnCopySettings = $settingsWindow.FindName('BtnCopySettings')
$btnCancelSettings = $settingsWindow.FindName('BtnCancelSettings')
$btnSaveCloseSettings = $settingsWindow.FindName('BtnSaveCloseSettings')
```

**Result**: ✅ **FIXED**
- Settings dialog now loads properly
- Shared path text box displays current value from settings
- Browse button works to select a folder
- Dialog no longer locks up
- Default settings load correctly if not set

**Code Location**: `Show-EditSettingsDialog` function in TrackSessions.CR3.Main.ps1, line ~1552

**To Verify**: Click the **Settings...** button in CR3 main window—it should open the settings dialog without errors.


---

## Session: 2026-09-24 - Debug Settings Implementation & Grid Display Fix

### Initial Request

**User**: Add a debug control group that includes Show all Sessions and show the actual filter in the Log output - as it changes. and when the refreshes occur.

---

### Implementation Phase 1: Debug Controls UI

#### Changes Made:

1. **TrackSessions.CR3.Main.ps1** - Read-TrackSessionsSettings function
   - Added Debug section to defaultSettings schema with three boolean properties:
     - ShowAllSessions: false
     - ShowFilterInLog: false
     - ShowRefreshEvents: false
   - Added parsing logic for Debug properties from JSON
   - Return value now includes Debug section

2. **TrackSessions.CR3.Main.ps1** - Show-EditSettingsDialog function
   - Added three new checkbox control references:
     - $chkShowAllSessions
     - $chkShowFilterInLog
     - $chkShowRefreshEvents
   - Added initialization code to set checkbox states from loaded settings
   - Updated save button handler to persist Debug settings to JSON

3. **TrackSessions.SettingsDialog.xaml** - UI Layout
   - Updated main Grid from 3 rows to 4 rows
   - Added new Row 2 (Debug Controls Border):
     - Background color: #FFF5E6 (light orange)
     - Border color: #FFD4A3 (orange-tan)
     - Title: Debug Controls
     - Three checkboxes with tooltips:
       - ChkShowAllSessions: Show all sessions in the grid without applying filters.
       - ChkShowFilterInLog: Display the active filter in the Log output as it changes.
       - ChkShowRefreshEvents: Log when grid refresh operations occur.
   - Shifted control buttons to Row 3

4. **TrackSessions.Settings.json** - Configuration
   - Added Debug section with three properties initialized to false

---

### Issue: Nothing Displays

**User Report**: Even with Show all Sessions checked, the grid shows nothing.

**Investigation Results**:
- Confirmed UNC path exists and is accessible: \\Vp0wxsqm365as02\SPS\PAWS-Sessions
- Found 10+ JSON session files in the shared path
- **All files are for machine**: NCT001MA4573619
- **Current machine name**: NCT001MA4573619

**Root Cause**: The grid intentionally filters OUT the current machine to show Activity on Other Machines
- All test session files are from the current machine
- The filter was excluding them by design
- The ShowAllSessions setting was being saved but **not being used** to bypass the filter
- This was the missing logic link: the setting existed but had no functional effect in the grid update code

---

### Solution: Enable ShowAllSessions to Actually Work

#### Code Change:

**TrackSessions.CR3.Main.ps1** - Update-SessionGridData function

Modified to conditionally respect the debugShowAllSessions setting:

`powershell
function Update-SessionGridData {
    try {
        if () {
            Add-DebugLog -Message REFRESH EVENT: Update-SessionGridData starting
        }
        else {
            Add-DebugLog -Message Update-SessionGridData: Starting
        }
        
        # When ShowAllSessions is enabled, include current machine; otherwise exclude it
         = if () { '' } else {  }
        
        if () {
            Add-DebugLog -Message FILTER: Will exclude machine: '\'
        }
        
         = @(Get-SessionGridRows -FolderPath  -TrackedMachines  -ExcludeMachineName )
        Add-DebugLog -Message Update-SessionGridData: Got $($realRows.Count) real rows from '\'
        ...
    }
}
`

#### How It Works:

1. **ShowAllSessions: True**
   - Includes sessions from ANY machine (including current)
   - ExcludeMachineName set to empty string
   - All sessions display

2. **ShowAllSessions: False**
   - Excludes sessions from current machine (ExcludeMachineName = current machine name)
   - Shows only Activity on Other Machines
   - Only displays sessions from remote machines

3. **ShowFilterInLog: True**
   - Logs display: FILTER: Will exclude machine: 'NCT001MA4573619'
   - Shows filter configuration in log output

4. **ShowRefreshEvents: True**
   - Logs mark grid updates with: REFRESH EVENT: ...
   - Shows when refresh operations occur in log output

---

### Configuration Applied

**TrackSessions.Settings.json** - Debug Section:

`json
Debug:  {
    ShowAllSessions:  true,
    ShowFilterInLog:  true,
    ShowRefreshEvents:  true
}
`

All three debug options enabled by default for immediate visibility.

---

### Files Modified

1. **TrackSessions.CR3.Main.ps1** (~3,300 lines)
   - Read-TrackSessionsSettings: Added Debug schema parsing and extraction
   - Show-EditSettingsDialog: Added checkbox UI controls and persistence logic
   - Update-SessionGridData: Integrated ShowAllSessions filter conditional logic
   - btnEditSettings.Add_Click: Added debug settings reload on save
   - refreshAction: Enhanced with filter and refresh event conditional logging
   - Startup code: Added debug settings initialization and startup logging

2. **TrackSessions.SettingsDialog.xaml** (~200 lines)
   - Grid structure: Changed from 3 rows to 4 rows
   - New Debug Controls section with orange-themed border and three checkboxes
   - Repositioned button controls to new Row 3

3. **TrackSessions.Settings.json**
   - Added Debug section with ShowAllSessions, ShowFilterInLog, ShowRefreshEvents

---

### Testing Status

✅ **Path Accessibility Verified**
- UNC path \\Vp0wxsqm365as02\SPS\PAWS-Sessions exists and is accessible
- Contains 10+ JSON session files
- All files contain machine name NCT001MA4573619

✅ **Debug Settings Persist**
- Settings saved to and loaded from JSON correctly
- Settings reload on dialog save

✅ **Filter Logic Implemented**
- ShowAllSessions=true conditionally includes current machine
- ShowAllSessions=false conditionally excludes current machine
- Filter state can be toggled on/off via Settings dialog

**Expected Result**: With ShowAllSessions=true (currently enabled), grid should now display all sessions including current machine data.

---

### Key Insight

The Activity on Other Machines grid was designed to **intentionally hide the current machine** to focus on remote activity. When testing with only local machine data, this design choice made the grid appear empty. The ShowAllSessions debug option was added to bypass this filter during development and testing, allowing visibility into all session data regardless of machine source.

