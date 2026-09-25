# TrackSessions CR3: Safe Refactoring Without PowerShell Modules

## Executive Summary

CR2's modular refactoring failed because PowerShell module scope isolation breaks the event model needed for WPF dialogs. The solution: **organize code inline using Regions** and **extract XAML to separate files** (which don't have scope issues). This document outlines safe, incremental refactoring patterns that maintain functionality.

---

## Problem Statement: Why CR2 Failed

### The CR2 Refactoring Approach
```
TrackSessions.CR2.Main.ps1
├── Import-Module .\Core.psm1
├── Import-Module .\UI.psm1
├── Import-Module .\Dialogs.psm1
└── Import-Module .\Notifications.psm1
```

### Failures Encountered
1. **Event Handler Scope Isolation**: Click handlers couldn't access dialog functions exported from modules
2. **Function Resolution**: `Show-SettingsDialog` called from button click returned "not recognized as cmdlet"
3. **XAML Initialization**: `[System.Windows.Markup.XamlReader]::Load()` references in modules failed
4. **Scope Closure Breakdown**: `.GetNewClosure()` didn't capture module functions properly
5. **No Working UI**: All 5 dialogs failed to open; application was non-functional

### Root Cause
PowerShell modules create **isolated scope contexts**. When a scriptblock (event handler) is created at module import time, it captures the module's scope—not the caller's. Later, when that scriptblock executes in the main script's scope during a button click, it can't find functions from other modules or the main script.

```powershell
# ❌ This fails with modules:
# Module exports: Export-ModuleMember -Function Show-SettingsDialog
# Main script calls: $button.Add_Click({ Show-SettingsDialog })  # ERROR: not found
```

---

## Solution: Safe Refactoring Patterns

### Pattern 1: PowerShell Regions for Code Organization

**Purpose**: Organize inline code into logical sections without creating scope isolation.

**Benefits**:
- Functions remain in same scope → event handlers work correctly
- Readable code structure → easier to navigate large files
- Collapsible sections → VS Code fold regions feature
- No module-related debugging overhead

#### Region Organization Structure

```powershell
# ============================================================================
# TrackSessions.Main.ps1 - Safe Region-Based Organization
# ============================================================================

#region ASSEMBLY AND TYPES
# Load required .NET assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xml.Linq
#endregion ASSEMBLY AND TYPES

#region GLOBAL SETTINGS
# Configuration constants and global variables
$script:SettingsPath = "$PSScriptRoot\TrackSessions.Settings.json"
$script:UsersPath = "$PSScriptRoot\TrackSessions.Users.json"
$script:ReservationsPath = "$PSScriptRoot\TrackSessions.Reservations.json"
$script:LogPath = "$PSScriptRoot\TrackSessions.Log.txt"
#endregion GLOBAL SETTINGS

#region XAML LOADERS
# Load XAML files and create window objects
function New-MainWindow { ... }
function New-SettingsDialog { ... }
function New-AboutDialog { ... }
#endregion XAML LOADERS

#region SETTINGS I/O
# Read/write settings JSON
function Get-TrackSessionsSettings { ... }
function Save-TrackSessionsSettings { ... }
#endregion SETTINGS I/O

#region SESSION MANAGEMENT
# Track sessions, users, reservations
function Add-Session { ... }
function Get-Sessions { ... }
function Remove-Session { ... }
#endregion SESSION MANAGEMENT

#region DIALOG HANDLERS
# Event handlers for each dialog
function Show-SettingsDialog { ... }
function Show-AboutDialog { ... }
function Show-LogViewerDialog { ... }
#endregion DIALOG HANDLERS

#region MAIN WINDOW INITIALIZATION
# Build and show main window
$mainWindow = New-MainWindow
# Wire event handlers (all in same scope ✓)
$settingsButton.Add_Click({ Show-SettingsDialog })
$aboutButton.Add_Click({ Show-AboutDialog })
#endregion MAIN WINDOW INITIALIZATION
```

**Advantages**:
- VS Code shows region outline → click to fold/unfold sections
- All functions share same scope → event handlers work
- Easy to collapse Settings region while working on Session Management
- No import/export ceremony

#### VS Code Settings for Better Region Support

Add to `.vscode/settings.json`:
```json
{
  "[powershell]": {
    "editor.foldingStrategy": "indentation",
    "editor.showUnusedVariables": true,
    "editor.wordWrap": "on"
  }
}
```

---

### Pattern 2: XAML Extraction (Safe & Effective)

**Purpose**: Move UI markup to separate `.xaml` files instead of embedded strings.

**Benefits**:
- XAML syntax highlighting and validation
- Easier to edit complex UI without string escaping
- No scope issues (XAML is just XML, not code)
- Can be shared/reused across multiple scripts
- Much faster to iterate: change XAML → reload script, no scope fixes needed

#### Step 1: Create External XAML Files

**File**: `MainWindow.xaml`
```xml
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="MainWindow"
    Title="TrackSessions"
    Width="1200" Height="800"
    Background="#F0F0F0">
    <Grid>
        <DockPanel LastChildFill="True">
            <!-- Menu Bar -->
            <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="10">
                <Button x:Name="SettingsButton" Content="Settings" Width="100" Margin="5"/>
                <Button x:Name="AboutButton" Content="About" Width="100" Margin="5"/>
                <Button x:Name="ViewLogButton" Content="View Log" Width="100" Margin="5"/>
            </StackPanel>
            
            <!-- Data Grid -->
            <DataGrid x:Name="SessionGrid" DockPanel.Dock="Bottom">
                <DataGrid.Columns>
                    <DataGridTextColumn Header="Session ID" Binding="{Binding SessionId}"/>
                    <DataGridTextColumn Header="User" Binding="{Binding UserName}"/>
                    <DataGridTextColumn Header="Start Time" Binding="{Binding StartTime}"/>
                </DataGrid.Columns>
            </DataGrid>
        </DockPanel>
    </Grid>
</Window>
```

**File**: `SettingsDialog.xaml`
```xml
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="SettingsDialog"
    Title="Settings"
    Width="600" Height="500"
    WindowStartupLocation="CenterOwner"
    ResizeMode="CanResize">
    <Grid>
        <TabControl>
            <TabItem Header="General">
                <!-- Settings controls here -->
            </TabItem>
            <TabItem Header="Paths">
                <!-- Path controls here -->
            </TabItem>
        </TabControl>
    </Grid>
</Window>
```

#### Step 2: Load XAML in Code

```powershell
#region XAML LOADERS

function Load-XamlFile {
    param([string]$XamlPath)
    
    if (-not (Test-Path $XamlPath)) {
        throw "XAML file not found: $XamlPath"
    }
    
    $xamlContent = Get-Content $XamlPath -Raw
    $xamlReader = New-Object System.Xml.XmlNodeReader ([xml]$xamlContent)
    [System.Windows.Markup.XamlReader]::Load($xamlReader)
}

function New-MainWindow {
    $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
    Load-XamlFile $xamlPath
}

function New-SettingsDialog {
    $xamlPath = Join-Path $PSScriptRoot "SettingsDialog.xaml"
    Load-XamlFile $xamlPath
}

function New-AboutDialog {
    $xamlPath = Join-Path $PSScriptRoot "AboutDialog.xaml"
    Load-XamlFile $xamlPath
}

#endregion XAML LOADERS
```

**Advantages Over Embedded XAML**:
- Change XAML → save file → run script (immediate preview)
- No string concatenation or escape characters
- IDE/VS Code provides XAML validation
- Easier to see formatting issues

---

## Implementation Guide: Safe Refactoring Steps

### Phase 1: Add Regions to CR1 (Zero Risk)

1. **Keep CR1 completely functional**
2. Wrap existing code in regions without moving anything
3. Test after each region addition (should work unchanged)

```powershell
#region SESSION MANAGEMENT
# (existing code moved here, no changes)
function Add-Session { ... }
function Get-Sessions { ... }
#endregion SESSION MANAGEMENT
```

**Checkpoint**: Script works exactly as before ✓

### Phase 2: Extract XAML Files

1. **Pick one dialog**: Start with `AboutDialog.xaml` (least complex)
2. Create `AboutDialog.xaml` file in `$PSScriptRoot`
3. Update `New-AboutDialog` to use `Load-XamlFile`
4. Test About button → should work

```powershell
# Before (embedded):
$xamlString = @"
<Window ...>...</Window>
"@
$xamlReader = New-Object System.Xml.XmlNodeReader ([xml]$xamlString)
$aboutDialog = [System.Windows.Markup.XamlReader]::Load($xamlReader)

# After (extracted):
function New-AboutDialog {
    Load-XamlFile "$PSScriptRoot\AboutDialog.xaml"
}
```

**Test**: Click About button → dialog opens, all content displays ✓

5. **Repeat for remaining dialogs**:
   - SettingsDialog.xaml
   - LogViewerDialog.xaml
   - UsersDialog.xaml
   - ReservationsDialog.xaml

**Checkpoint**: All dialogs extracted, all buttons functional ✓

### Phase 3: Organize Functions into Regions

1. **Move related functions into regions**:
   - All Settings I/O functions → `#region SETTINGS I/O`
   - All Session functions → `#region SESSION MANAGEMENT`
   - All event handlers → `#region EVENT HANDLERS`

2. **Maintain single-scope execution**: No code moves to separate script files

3. **Keep dependencies near each other**:
   ```powershell
   #region USERS MANAGEMENT
   function Get-AllUsers { ... }
   function Add-User { ... }
   function Remove-User { ... }
   function Update-User { ... }
   #endregion USERS MANAGEMENT
   ```

**Checkpoint**: Code organized but functionality unchanged ✓

### Phase 4: Incremental Feature Additions

Now you can add new features safely:

```powershell
#region FEATURE: EXPORT TO EXCEL
function Export-SessionsToExcel {
    param([string]$FilePath)
    
    $sessions = Get-Sessions
    $excel = New-Object -ComObject Excel.Application
    # ... implementation
}
#endregion FEATURE: EXPORT TO EXCEL
```

**Each new feature**:
1. Add in appropriate region or new region if complex
2. Wire up event handlers in same script
3. Test incrementally
4. No module scope issues

---

## Pattern Examples: Safe Code Organization

### Example 1: Settings Dialog with Regions

```powershell
#region SETTINGS DIALOG

function Show-SettingsDialog {
    param([System.Windows.Window]$Owner)
    
    $dialog = New-SettingsDialog
    $dialog.Owner = $Owner
    
    # Wire event handlers (all in same scope ✓)
    $okButton = $dialog.FindName("OkButton")
    $cancelButton = $dialog.FindName("CancelButton")
    $browseButton = $dialog.FindName("BrowseButton")
    
    $okButton.Add_Click({
        Save-SettingsFromDialog $dialog
        $dialog.DialogResult = $true
    }.GetNewClosure())
    
    $cancelButton.Add_Click({
        $dialog.DialogResult = $false
    })
    
    $browseButton.Add_Click({
        Show-FolderBrowserDialog  # ✓ Function is in same scope
    }.GetNewClosure())
    
    [void]$dialog.ShowDialog()
}

function Show-FolderBrowserDialog {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $result = $dialog.ShowDialog()
    if ($result -eq "OK") {
        return $dialog.SelectedPath
    }
    return $null
}

function Save-SettingsFromDialog {
    param([System.Windows.Window]$Dialog)
    
    $settings = @{
        Window = @{
            Left = [int]$Dialog.Left
            Top = [int]$Dialog.Top
            Width = [int]$Dialog.Width
            Height = [int]$Dialog.Height
        }
    }
    
    Save-TrackSessionsSettings $settings
}

#endregion SETTINGS DIALOG
```

**Why this works**:
- All functions defined in same scope
- Event handlers can call any function in scope
- No module boundaries
- `.GetNewClosure()` captures outer scope correctly

### Example 2: Session Grid Population

```powershell
#region SESSION GRID

function Populate-SessionGrid {
    param([System.Windows.Controls.DataGrid]$Grid)
    
    $sessions = Get-Sessions
    $Grid.ItemsSource = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]$sessions
}

function Get-Sessions {
    if (-not (Test-Path $script:SettingsPath)) {
        return @()
    }
    
    $data = Get-Content $script:SettingsPath -Raw | ConvertFrom-Json
    $data.Sessions  # PowerShell automatically converts to objects
}

function Add-Session {
    param(
        [string]$UserId,
        [string]$UserName,
        [datetime]$StartTime,
        [string]$Status = "Active"
    )
    
    $sessions = Get-Sessions
    $newSession = @{
        SessionId = ([guid]::NewGuid()).ToString()
        UserId = $UserId
        UserName = $UserName
        StartTime = $StartTime.ToString("yyyy-MM-dd HH:mm:ss")
        EndTime = $null
        Status = $Status
    }
    
    $sessions += $newSession
    Save-Sessions $sessions
    
    return $newSession
}

function Remove-Session {
    param([string]$SessionId)
    
    $sessions = Get-Sessions
    $filtered = $sessions | Where-Object { $_.SessionId -ne $SessionId }
    Save-Sessions $filtered
}

function Save-Sessions {
    param([array]$Sessions)
    
    $settings = Get-TrackSessionsSettings
    $settings.Sessions = $Sessions
    Save-TrackSessionsSettings $settings
}

#endregion SESSION GRID
```

**Why this is safe**:
- All session functions in one region
- Called from main window and dialogs (all same scope)
- Easy to test each function independently
- No scope isolation issues

---

## Comparison: Modules vs. Regions

| Aspect | PowerShell Modules | PowerShell Regions |
|--------|-------------------|-------------------|
| **Scope Isolation** | ❌ Breaks event handlers | ✓ All functions in same scope |
| **WPF Compatibility** | ❌ Cannot call exported functions from event handlers | ✓ Event handlers work correctly |
| **Code Organization** | ✓ Logical separation | ✓ Logical separation with regions |
| **Testing** | Harder (scope issues) | ✓ Easier (same scope as main) |
| **Refactoring Speed** | Slow (debugging scope issues) | ✓ Fast (change code, test) |
| **XAML Extraction** | ✓ Works | ✓ Works (safer) |
| **Import/Export** | Complex ceremony | None needed |
| **Debugging** | Complex (multiple contexts) | ✓ Single context |

---

## Best Practices for Safe, Fast Refactoring

### 1. **Test After Each Logical Change**
```powershell
# Add region → test
# Add function → test
# Wire event handler → test
# DON'T make 10 changes then test
```

### 2. **Keep Event Handlers Simple**
```powershell
# ✓ Good: handler delegates to another function
$button.Add_Click({
    Show-SettingsDialog
}.GetNewClosure())

# ❌ Bad: complex logic in handler (harder to debug scope issues)
$button.Add_Click({
    try {
        $settings = Get-TrackSessionsSettings
        # ... 50 lines of logic ...
    } catch {
        # Error handling buried in handler
    }
}.GetNewClosure())
```

### 3. **Use Dot-Sourcing for Utility Scripts (If Needed)**
If you have helper utilities, dot-source them instead of importing:
```powershell
# ✓ Maintains scope
. "$PSScriptRoot\Utilities.ps1"

# ❌ Breaks scope
Import-Module "$PSScriptRoot\Utilities.psm1"
```

### 4. **Name Regions Consistently**
```powershell
#region FEATURE NAME
#region [NOUN] [VERB/PURPOSE]
```

Examples:
- `#region SETTINGS I/O`
- `#region SESSION MANAGEMENT`
- `#region DIALOG HANDLERS`
- `#region XAML LOADERS`
- `#region UTILITY FUNCTIONS`

### 5. **Keep XAML Changes Separate from Code Changes**
```powershell
# Session 1: Extract SettingsDialog.xaml
# Test button opens dialog
# Session 2: Add new controls to SettingsDialog.xaml
# Test new controls work
# Session 3: Add code to handle new controls
# Separation = easier debugging
```

### 6. **Maintain Backups of Each Stable State**
```
TrackSessions.CR1.Stable.ps1          ← Last known working version
TrackSessions.CR3.Working.ps1         ← After extracting dialogs
TrackSessions.CR3.WithNewFeature.ps1  ← After adding feature X
```

---

## Common Pitfalls to Avoid

### ❌ Pitfall 1: Calling Functions from Event Handlers Without Closure
```powershell
# WRONG: Function not in handler scope
$button.Add_Click({
    Show-SettingsDialog  # ERROR: might not find function
})

# RIGHT: Use .GetNewClosure()
$button.Add_Click({
    Show-SettingsDialog
}.GetNewClosure())
```

### ❌ Pitfall 2: Setting Window Properties Before ShowDialog()
```powershell
# WRONG: WPF closes window during initialization
$dialog.Left = 100
$dialog.Top = 100
$dialog.ShowDialog()

# RIGHT: Let WPF initialize, then set properties
$dialog.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
$dialog.Owner = $MainWindow
$dialog.ShowDialog()
```

### ❌ Pitfall 3: Using `Invoke-Item` in UI Handlers (Blocks UI)
```powershell
# WRONG: Freezes UI while folder opens
Invoke-Item $folder

# RIGHT: Non-blocking folder open
Start-Process explorer.exe -ArgumentList $folder
```

### ❌ Pitfall 4: Forgetting to Find Named Controls
```powershell
# WRONG: No error, but control is $null
$button = $dialog.FindName("NonExistentButton")
$button.Add_Click({...})  # Silently fails

# RIGHT: Validate control exists
$button = $dialog.FindName("OkButton")
if (-not $button) { throw "OkButton not found in XAML" }
$button.Add_Click({...})
```

---

## Implementation Roadmap for CR3

### Week 1: Foundation (Regions)
- [ ] Add regions to CR1.ps1 (no functional changes)
- [ ] Verify all buttons still work
- [ ] Commit: `CR3.WithRegions.ps1`

### Week 2: XAML Extraction
- [ ] Extract `AboutDialog.xaml`
- [ ] Extract `LogViewerDialog.xaml`
- [ ] Extract `SettingsDialog.xaml`
- [ ] Extract `UsersDialog.xaml`
- [ ] Extract `ReservationsDialog.xaml`
- [ ] Verify all dialogs open correctly
- [ ] Commit: `CR3.WithExtractedXAML.ps1`

### Week 3: Feature Development
- [ ] Add new session filter control
- [ ] Add session export to CSV
- [ ] Add session statistics panel
- [ ] Test incrementally after each feature
- [ ] Commit: `CR3.WithNewFeatures.ps1`

### Week 4: Polish
- [ ] Performance optimization
- [ ] UI/UX refinements
- [ ] Documentation
- [ ] Final testing
- [ ] Commit: `CR3.Production.ps1`

---

## FAQ: Safe Refactoring

**Q: Can I use regions with dot-sourcing?**
A: Yes. Dot-source utility scripts, then wrap everything in regions:
```powershell
. "$PSScriptRoot\Utilities.ps1"

#region MAIN WINDOW
# ...
#endregion MAIN WINDOW
```

**Q: What's the maximum file size before I should consider breaking into files?**
A: For PowerShell WPF apps, keep main script under 5000 lines. Use regions to organize. Beyond that, dot-source helper scripts (not modules).

**Q: Should I extract XAML as soon as I start CR3?**
A: Yes, do it early. Extracted XAML is zero-risk and much easier to iterate on.

**Q: Can I partially keep modules?**
A: Only if you dot-source them. Never `Import-Module` if you have event handlers that need to call functions.

**Q: How do I handle settings persistence with regions?**
A: Keep `SETTINGS I/O` region at the top level, call from any other region:
```powershell
#region SETTINGS I/O
function Save-TrackSessionsSettings { ... }
#endregion

#region SESSION MANAGEMENT
function Add-Session {
    # ... add logic
    Save-TrackSessionsSettings $data  # ✓ Same scope
}
#endregion
```

---

## Checklist: Safe Refactoring Process

Before making code changes:
- [ ] Current script runs without errors
- [ ] All buttons functional
- [ ] All dialogs open correctly
- [ ] Settings save/load works

When adding a feature:
- [ ] Create feature region
- [ ] Implement functions in that region
- [ ] Wire up event handlers (same region or parent scope)
- [ ] Test immediately
- [ ] Document region purpose in comment header

When extracting XAML:
- [ ] Create `.xaml` file in `$PSScriptRoot`
- [ ] Update XAML loader function
- [ ] Test control opening and interaction
- [ ] Verify all event handlers still work

Before committing:
- [ ] Test all buttons
- [ ] Test all dialogs
- [ ] Test new feature
- [ ] No errors in PowerShell console
- [ ] Settings persist correctly

---

## Conclusion

The failure of CR2's modular refactoring teaches us:
- **PowerShell modules break WPF event models**
- **Regions + XAML extraction = safe, fast refactoring**
- **Incremental testing prevents large failures**
- **Keep code inline and organized, not modularized**

CR3 should use:
1. **Regions** for code organization
2. **XAML files** for UI markup
3. **Single script** for all PowerShell code
4. **Incremental testing** after each change

This approach gives you code organization without scope issues, XAML ease-of-editing without module complications, and fast iteration without mysterious event handler failures.
