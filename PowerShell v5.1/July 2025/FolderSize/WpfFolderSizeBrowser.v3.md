# WpfFolderSizeBrowser.v3 - Change and Operations Log

Source script: WpfFolderSizeBrowser.v3.ps1

## Purpose

This document tracks:

- Key code changes made to WpfFolderSizeBrowser.v3.ps1
- Operational issues observed during edits/validation
- Possible enhancements for future improvements

## Update Policy

- This file is maintained as a living log.
- It should be updated on each prompt that changes behavior, fixes bugs, or adds analysis relevant to operations.

## Latest Snapshot

Date: 2026-08-05 (Latest Update - 2nd Pass)

### Key Changes (2nd Pass)

1. Added automatic window position clamping to visible monitor bounds after loading from settings.
   - Window Left/Top clamped to virtual screen minimum (top-left corner of all monitors).
   - Window Right/Bottom clamped to virtual screen maximum (bottom-right corner of all monitors).
   - Prevents app from appearing off-screen when monitor layout changes between sessions.
   - Window state normalized from Minimized to Normal on startup if needed.

2. Added health-status cell coloring to Disk Summary worksheet:
   - Healthy → Green background (0x00B050) with white bold text
   - Warning* → Yellow background (0xFFC000) with black bold text
   - Unhealthy* → Red background (0xFF0000) with white bold text
   - Unknown → Gray background (0xBBBBBB) with black text

Date: 2026-08-05 (Previous - 1st Pass)

### Key Changes (1st Pass)

1. Updated XLSX export to apply Excel row outlining/grouping based on folder depth (`Level` from report rows).
2. Defaulted worksheet outline presentation to show only up to outline level 2 (higher nested levels collapsed).
3. Added export metadata line in XLSX output to document outline behavior: `Outline View: Collapsed to Level 2`.
4. Added a new `Disk Summary` worksheet to XLSX exports.
5. Disk Summary now includes per-disk values for:
    - Disk number
    - Exported volume/drive letter
    - Brand/model name
    - Size (GB and bytes)
    - Bytes per sector
    - Total sectors
    - Health status (from `Get-Disk` when available, fallback `Unknown`)
6. Updated XLSX export invocation to pass source root paths into disk-summary collection logic.

Date: 2026-07-20 (Earlier Update)

### Key Changes

1. Added a responsive Export row below the main control row in the top toolbar:
        - Dynamic button text based on selection state:
            - Export Current Folder (no selection)
            - Export Selected Folder(s) (one or more selected rows)
        - Format selector: CSV, XLSX, Markdown, HTML
        - Optional export checkbox: Include Attribute Names

2. Implemented export report generation from selected folder (or current folder when none is selected):
    - Shared report columns across all formats:
      - File Name
      - Size KB
      - Size GB
      - Modified date/time (three-letter weekday included)
      - Created date/time (three-letter weekday included)
      - Attributes
      - Number of sub-folders

3. Implemented format-specific output behavior:
    - CSV includes Absolute Path per row for each folder.
    - XLSX exports a formatted Excel workbook (header styling, filter, number formats, freeze top row).
    - Markdown includes Absolute Path per row.
    - HTML includes Absolute Path, a numeric Level column, and visual indentation by hierarchy depth.

4. Recurse checkbox now controls export depth as well as scan behavior:
    - Recurse checked: export full folder hierarchy recursively.
    - Recurse unchecked: export root folder and immediate child folders only.

5. Added post-export app launch behavior:
    - CSV: opens in Excel (fallback to default app if Excel is unavailable).
    - XLSX: opens in Excel (fallback to default app if Excel is unavailable).
    - Markdown: opens in Notepad.
    - HTML: opens in Microsoft Edge (fallback to default browser if Edge is unavailable).

6. Added Explorer-style attribute flags in export output (for example: RHSACE), including common Windows attributes.

7. Added optional second attribute column in exports for full descriptive names:
    - Example: ReadOnly, Hidden, System, Archive, Compressed, Encrypted

8. Added clickable folder links in export outputs:
    - XLSX: Absolute Path cells use explicit Excel HYPERLINK formulas so the path text is reliably clickable and opens folders in Windows Explorer.
    - Markdown: File Name and Absolute Path are file URI links.
    - HTML: File Name and Absolute Path are clickable file URI links.

9. Added an Excel-friendly hyperlink formula column to CSV exports:
    - Column: OpenInExplorerExcel
    - Value pattern: =HYPERLINK("file:///...","Open in Explorer")
    - Opening the CSV in Excel renders a clickable link per row that opens the folder.

10. Improved ListView selected-row contrast using a darker purple highlight for better readability over alternating row colors.

11. Hardened export path normalization to prevent TrimEnd runtime failures from scalar/string indexing edge cases.

12. Updated settings persistence target to `WpfFolderSizeBrowser.Settings.json` and retained legacy fallback load paths.

13. Persisted additional UI settings:
    - Selected export format (CSV/XLSX/Markdown/HTML)
    - Include Attribute Names checkbox
    - Recurse checkbox
    - Current folder path
    - Window location/size/state

14. Added recurse-state metadata to top of non-CSV exports:
    - Markdown: `Recurse Subfolders: Checked/Unchecked`
    - HTML: meta line for recurse state
    - XLSX: top metadata rows (Root Path, Generated, Recurse Subfolders)

15. Improved status bar behavior after export:
    - Shows full exported file path briefly (5 seconds)
    - Then reverts to concise completion message (`Finished 🏁💽`) to reduce crowding against right-side drive free-space display

16. Added screen tips (tooltips) across main controls including detailed Recurse checkbox guidance:
    - "Up button forces off; Refresh can take awhile. Chart and Export may take longer and Mouse wait cursor will show."

### Quick Export Usage

1. Open the app and browse to the folder you want to report on.
2. Optional: click a folder row to export that specific folder; otherwise the current path is used.
3. Set Recurse Subfolders:
    - Checked: include full folder hierarchy.
    - Unchecked: include only root and immediate child folders.
4. Choose export format from the combo box: CSV, XLSX, Markdown, or HTML.
5. Optional: check Include Attribute Names to add a second attributes column with descriptive names.
6. Click the export button (Current Folder or Selected Folder(s), depending on selection).
7. In the Save dialog, choose location and file name, then click Save.
8. After export completes, the file opens automatically:
    - CSV in Excel
    - XLSX in Excel
    - Markdown in Notepad
    - HTML in Edge
9. Export files include recurse behavior based on the Recurse checkbox:
    - Checked: recursive traversal
    - Unchecked: root and immediate child folders only

Date: 2026-07-11 (Latest Update)

### Key Changes

1. **Enhanced Progress Dialog with Real-time Metrics** (Current)
   - Enlarged progress dialog to 400x280 to accommodate detailed metrics display
   - Added three new metrics displayed in real-time:
     - Folders Found: Shows count of folders processed so far
     - Files Found: Shows cumulative count of all files found across all folders
     - Total Size: Shows accumulated total size with intelligent unit formatting (bytes/KB/MB/GB)
   - Added progress percentage display below progress bar
   - Progress metrics update on dispatcher thread for thread-safe UI updates

2. Modified Update-Display function to track and accumulate metrics:
   - Added counters for total files found and total bytes
   - Files are counted per folder (respecting recurse setting) and accumulated
   - Total size is accumulated across all folders as they're processed
   - Formatted size display intelligently selects units for human readability
   - Status bar now shows comprehensive summary: "Found X folders | Y files | Total: Z"

Date: 2026-07-11 (Previous)

### Key Changes (Previous Session)

1. Added persistent drive capacity status in the status bar.
2. Added a new green status bar item named VolumeStatusText to display drive total and free space.
3. Added helper function Format-ByteSize to present byte values in readable units (KB/MB/GB/TB).
4. Added function Update-VolumeStatus to resolve current path drive and show total/free values.
5. Wired Update-VolumeStatus into Update-Display so status updates on refresh/navigation.
6. Updated volume status rendering so available free space is bold while retaining green status styling.
7. Added JSON settings persistence file: WpfFolderSizeBrowser.v3.settings.json.
8. Added settings load on startup for last current path, recurse option, sort settings, and window geometry/state.
9. Added settings save on window close for current path, recurse option, sort settings, and window geometry/state.
10. Created initial settings file (WpfFolderSizeBrowser.v3.settings.json) with default values.
11. Reworked top toolbar into a two-row responsive layout so current path wraps cleanly on narrow windows.
12. Added dynamic GridView column sizing based on window/list width to better preserve visibility for all 4 columns.
13. Tuned responsive column ratios to emphasize Folder Name while keeping Has Subfolders more readable.
14. Switched settings persistence to same-base JSON file name: WpfFolderSizeBrowser.v3.json.
15. Added legacy fallback load from WpfFolderSizeBrowser.v3.settings.json when same-base JSON is missing.
16. Created initial WpfFolderSizeBrowser.v3.json from existing settings values.

### Operational Issues Observed

1. Static analysis warning: automatic variable name reuse in ListView double-click handler ($eventArgs).
2. Static analysis warning: assigned but unused variable in exception dialog ($errorTextBox).
3. Static analysis/style warning: null comparison style ($folderSize -eq $null should be $null -eq $folderSize).
4. Style warning: unapproved verb in function name Sort-FolderData.

### Known Runtime Considerations

1. If a path cannot be resolved to a drive root, volume status falls back to "Drive info unavailable".
2. Network/removable drives may return delayed or unavailable capacity info depending on connection state.
3. Saved window position may restore off-screen if monitor layout changes between sessions.
4. Settings file read/write errors are non-fatal and reported as warnings in console output.
5. On very narrow windows, minimum column widths are enforced so horizontal clipping can still occur, but widths are balanced automatically.
6. Legacy and same-base settings files can both exist; same-base JSON is now the authoritative save target.

## Enhancement Backlog

1. Add a status bar separator and optional alignment spacer for cleaner visual spacing.
2. Show percentage free (for example: Free 312 GB (42%)).
3. Color thresholds for free space (green/yellow/red) based on remaining percentage.
4. Cache drive info briefly to reduce repeated DriveInfo calls during rapid navigation.
5. Add optional toggle in UI to hide/show volume stats.
6. Add PSScriptAnalyzer cleanup pass to resolve style warnings.

## Change History

### 2026-07-11

- Introduced green status bar drive capacity display and supporting helper/update functions.
- Added fallback handling when drive information cannot be read.
- Made free disk space text bold in the status bar while preserving green color.
- Added persistent JSON settings for window size/location/state, current path, recurse setting, and sort preferences.
- Created a starter JSON settings file so persistence is active immediately.
- Updated top path section to wrap text responsively when the window narrows.
- Added window resize handling to rebalance all four folder columns for better visibility.
- Refined column width profile to approximately 50% (Folder Name), 16% (Size), 12% (Size MB), and remaining width for Has Subfolders.
- Changed settings persistence target from the .settings.json naming to same-base .json naming and retained backward-compatible loading.

### 2026-07-11 - Live Progress Dialog Postmortem and Reimplementation Paths

#### How live progress dialog was implemented

The live progress version used an asynchronous design with these parts:

1. A progress window was created from XAML and shown modelessly.
2. Folder scanning work ran in a background runspace (PowerShell BeginInvoke).
3. Shared state was stored in a synchronized hashtable (processed folders, files found, total bytes, status, error text).
4. A DispatcherTimer on the UI thread polled shared state every 100 ms.
5. On each timer tick, UI controls in the dialog were updated (progress bar, percent text, counters).
6. Completion path called EndInvoke, then bound results to ListView and closed the dialog.
7. Error path stopped timer, reported error, and also attempted dialog close and job cleanup.

#### Why errors happened

Primary runtime issue observed:

- Null-valued expression when calling dialog Close.

Contributing factors:

1. Cleanup was attempted from multiple code paths (success branch and catch branch), creating double-close risk.
2. Dialog object lifetime and async timer lifecycle were loosely coupled, so cleanup sometimes ran after object became unavailable.
3. Background completion, timer events, and exception handling could interleave, causing race-like cleanup ordering.
4. Resource cleanup for runspace/pipeline and UI cleanup were not fully isolated originally, so one failure could cascade.

#### What changed immediately

1. Null guards and try/catch wrappers were added around dialog close.
2. Runspace and pipeline dispose were guarded independently.
3. Then Update-Display was switched back to blocking mode to eliminate async/timer cleanup complexity.
4. Async helper functions were retained but renamed with ToImplement suffix and stubbed for future work.

#### Approaches for future reimplementation

Approach A: BackgroundWorker style wrapper (lowest risk for WPF script)

1. Use one worker object with ProgressChanged and RunWorkerCompleted handlers.
2. Report progress from worker in typed payloads (processed, files, bytes).
3. Open dialog once, close only in RunWorkerCompleted.
4. Keep a single cleanup function with idempotent guard flag.

Pros: Familiar WPF lifecycle, less manual polling.
Cons: Less flexible than task-based design.

Approach B: Task plus Dispatcher invoke (recommended long-term)

1. Run scan in Task or runspace job with CancellationToken-like control.
2. Publish progress through a thread-safe queue/channel.
3. UI consumes queue on dispatcher with one owned subscription loop.
4. Centralize terminal states (Completed, Failed, Canceled) and perform cleanup once.

Pros: Clean separation, good extensibility for cancel/retry.
Cons: Slightly higher implementation complexity in PowerShell 5.1.

Approach C: Keep blocking scan and add lightweight status text only (safest now)

1. Stay synchronous in Update-Display.
2. Update status bar text periodically (processed/total) without separate dialog.
3. Use wait cursor and final summary.

Pros: Very stable, minimal threading risk.
Cons: UI remains less responsive during long scans.

#### Guardrails required for any async return

1. Single-owner cleanup method with a has-cleaned-up flag.
2. Never close dialog from more than one place.
3. Separate UI cleanup from backend disposal and wrap each independently.
4. Ensure EndInvoke is called at most once.
5. Add cancellation and window-closed handling to stop timers/work safely.
6. Add stress tests for rapid refresh clicks, inaccessible paths, and long network folders.

#### Async Reimplementation Checklist (Validation Gate)

Implementation checklist:

1. Define one terminal-state owner (Completed, Failed, Canceled).
2. Implement one cleanup function with idempotent guard (for example, hasCleanedUp).
3. Ensure dialog open/close happens only on dispatcher thread.
4. Ensure EndInvoke (or equivalent completion join) executes at most once.
5. Separate and guard cleanup of UI, timer/subscription, runspace, and pipeline.
6. Add cancellation path and window-close path that both converge into shared cleanup.
7. Add structured status payload for progress updates (processed, total, files, bytes, status).

Acceptance criteria:

1. No null-reference exceptions during 20 repeated refresh actions.
2. No duplicate cleanup calls observed in logs (cleanup count exactly 1 per run).
3. No UI-thread access exceptions during progress updates.
4. Cancel during scan exits cleanly and returns cursor/status to idle state.
5. Closing main window during active scan exits without hang or orphaned runspace.
6. On error path, user sees one error report and app remains interactive.
7. After completion or cancel, memory usage and active runspace count return to baseline.

### 2026-07-11 - UI Refinements and Async Rollback Session

#### Changes Made

1. **Fixed null-close exception** on progress dialog by adding null guards and isolated try/catch blocks.
2. **Hardened background job cleanup** with independent guards for Runspace and Pipeline disposal.
3. **Restored blocking scan mode** instead of async; removed DispatcherTimer polling pattern.
4. **Stubbed async helpers** with `ToImplement` suffix: Show-ProgressDialogToImplement, Invoke-BackgroundRunspaceToImplement.
5. **Smart column hiding** when window is too narrow:
   - If available width cannot fit all four columns' minimum widths, the `Size` column hides (width=0).
   - Remaining three columns rebalance while minimum sizes are respected.
   - When width increases again, full four-column layout is restored.
6. **Bold row styling** for folders with subfolders:
   - Entire row renders in bold FontWeight when HasSubfolders="Yes".
   - Applied via ListView.ItemContainerStyle with DataTrigger.
7. **Alternating row backgrounds**:
   - Implemented via AlternationCount=2 with light grey (#f0f0f0) on even rows.
   - White on odd rows for clean zebra-stripe readability.
8. **Folder name tooltip enrichment**:
   - Shows full folder name at top (bold).
   - Displays total size (human-readable unit).
   - Shows immediate child folder count.
   - Wrapped absolute path at bottom (grey, small font).
   - StackPanel width set to 300 for readable layout.

#### Performance and UX Improvements Implemented

- Blocking scan is faster and simpler than async for typical folder sizes (<10K folders).
- Column hiding prevents UI clipping on narrow windows without losing essential info (Size MB retained).
- Bold + alternating backgrounds improve visual scanning and row identification.
- Tooltip provides quick access to full path and subfolder structure without extra UI.

#### Ideas for Future Enhancements

1. **Caching and incremental updates**:
   - Cache folder sizes with timestamp and skip recalc if folder hasn't changed.
   - Delta-update only modified paths on refresh.
   - Reduces scan time on large directory trees.

2. **Async return (when ready)**:
   - Use BackgroundWorker or Task-based approach with proper cleanup (see Guardrails section).
   - Keep blocking as safe fallback, add preference toggle in settings.
   - Would improve UI responsiveness on very large scans (>10K folders or slow network paths).

3. **Multi-column sorting and secondary sort**:
   - Hold Shift+click to add secondary sort level (e.g., sort by Size, then by Name within same size).
   - Useful for identifying duplicate-sized folders.

4. **Search and filter box**:
   - Filter ListView by folder name, size range, or subfolder count.
   - Live search as user types.

5. **Size distribution visualization**:
   - Add optional pie chart or bar chart showing top N folders by size.
   - Toggle view between table and chart.

6. **Export to CSV/JSON**:
   - Save current folder data and metrics to file.
   - Useful for capacity planning and documentation.

7. **Keyboard shortcuts**:
   - Ctrl+U for Up, Ctrl+R for Refresh, Ctrl+E for Reveal in Explorer.
   - Better accessibility.

8. **Drag-and-drop navigation**:
   - Drag folder from ListView to path bar to navigate directly.
   - Drag folder to explorer for external operations.

9. **Performance optimization checklist**:
   - Use `Get-Item -Force` when possible to avoid recurse bottleneck.
   - Parallelize file counting across folders (if runspace budget permits).
   - Implement read-ahead caching for frequently accessed paths.

10. **Settings UI panel**:
    - Interactive settings dialog in-app instead of manual JSON editing.
    - Toggles for column visibility, alternating backgrounds, tooltip detail level.

#### Pie Chart Visualization Feature

**Implementation Summary:**

Added an interactive Charts button to the toolbar that opens a modal window with two synchronized pie charts:

1. **Left chart (Volume Space Distribution)**:
   - Shows current folder size vs. other data vs. free space on the volume.
   - Uses blue (current path), grey (other data), and green (free space) slices.
   - Provides quick visual understanding of disk utilization.

2. **Right chart (Current Path Contents)**:
   - Shows each immediate subfolder as a distinct colored slice.
   - Includes "Files in [FolderName]" slice if loose files exist in current path.
   - Helps identify which subfolder consumes the most space at a glance.

**How it works:**

- `Draw-PieChart` function handles all pie rendering:
  - Calculates slice angles based on percentage of total.
  - Draws SVG-like paths using WPF Canvas and Geometry objects.
  - Automatically colors slices (8-color palette for folders, 3-color for volume).
  - Places percentage labels centered on each slice.
  - Builds legend with folder names and byte counts below chart.
  
- Charts button click handler:
  - Gathers folder data (recursively) and immediate child folder count.
  - Queries drive info for total/free/used space.
  - Creates a modal XAML window with two Canvas elements side-by-side.
  - Calls Draw-PieChart twice (once per canvas).
  - Shows dialog modally (user must close before interacting with main window).

**Chart Window Layout:**
- Resizable (default 850×550).
- Two 50% columns, each with a Canvas.
- Light grey background for contrast.
- Legends show byte counts in human-readable format.

**Ideas for future pie chart enhancements:**

1. **Interactive tooltips on slices**:
   - Hover over slice to show folder name and size in tooltip.
   - Click slice to navigate to that folder.

2. **Donut chart mode**:
   - Option to toggle between pie and donut chart (donut shows hierarchy better).
   - Center text in donut shows total folder size.

3. **Drill-down capability**:
   - Double-click a slice to zoom into that folder and redraw charts.
   - Breadcrumb navigation to drill back up.

4. **Export charts as image**:
   - Right-click to save pie chart as PNG/SVG.
   - Useful for reports and documentation.

5. **Time-series history**:
   - Store folder size snapshots and plot them over time.
   - Show growth trend in a line chart overlay.

6. **Comparison mode**:
   - Open two Chart windows side-by-side to compare different folders.
   - Highlight similar-sized folders across paths.

---

## Code Refactoring and Modularization Strategy

As PowerShell scripts grow beyond 1000 lines, maintainability and testability suffer. This section outlines strategies to break WpfFolderSizeBrowser into manageable, reusable components.

### Current State

The script is a monolithic (~1100 lines) single-file WPF application:
- XAML inline in PowerShell string.
- Event handlers mixed with helper functions.
- UI state and business logic tightly coupled.
- Hard to unit test, difficult to reuse functions in other scripts.

### Refactoring Strategy: Multi-Module Approach

#### Phase 1: Separate Concerns into Modules

Create the following module structure:

```
WpfFolderSizeBrowser/
├── WpfFolderSizeBrowser.psd1      # Module manifest
├── src/
│   ├── Core.psm1                  # Core folder scanning, caching, size calc
│   ├── UI.psm1                    # XAML, window creation, layout helpers
│   ├── Charts.psm1                # Pie chart rendering (Draw-PieChart, etc.)
│   ├── Settings.psm1              # JSON persistence, config loading/saving
│   └── Events.psm1                # Event handlers for buttons, window events
├── Main.ps1                       # Entry point, orchestrates modules
└── README.md                       # Module documentation
```

#### Phase 2: Module Breakdown

**Core.psm1** (Business Logic)
```powershell
function Get-FolderSizes {
    # Scans folder tree, returns folder objects with sizes
    # Pure PowerShell, no UI dependencies
    # Cacheable and testable
}

function Get-VolumeSpace {
    # Returns drive info for given path
}

function Sort-FolderData {
    # Sorts folder data by column/direction
}

function Format-ByteSize {
    # Formats bytes to human-readable units
}
```

**UI.psm1** (User Interface)
```powershell
function New-MainWindow {
    # Creates and returns main window object
    # Pure XAML/WPF, no business logic
}

function Update-ColumnWidths {
    # Rebalances ListView columns on resize
}

function New-ChartWindow {
    # Creates and returns charts modal window
}
```

**Charts.psm1** (Visualization)
```powershell
function Draw-PieChart {
    # (Current implementation)
    # Self-contained, only depends on WPF Canvas
}

function Get-PieChartData {
    # Aggregates folder data for charts
}
```

**Settings.psm1** (Configuration)
```powershell
function Load-AppSettings {
    # (Current implementation)
    # Returns $PSCustomObject with all settings
}

function Save-AppSettings {
    # (Current implementation)
    # Persists object to JSON
}
```

**Events.psm1** (Event Handlers)
```powershell
function Register-ButtonEvents {
    # Wire all button Click handlers
    # Takes window and data objects as parameters
}

function Register-WindowEvents {
    # Wire window SizeChanged, Closing, etc.
}
```

#### Phase 3: Dependency Injection Pattern

Main.ps1 becomes the orchestrator:

```powershell
# Load modules
Import-Module ./src/Core.psm1
Import-Module ./src/UI.psm1
Import-Module ./src/Charts.psm1
Import-Module ./src/Settings.psm1
Import-Module ./src/Events.psm1

# Initialize state
$appState = @{
    CurrentPath = Get-Location
    FolderData = @()
    Settings = Load-AppSettings
    Window = $null
    Controls = @{}
}

# Create UI
$appState.Window = New-MainWindow
$appState.Controls = Get-ControlReferences -Window $appState.Window

# Register events (pass state by reference)
Register-ButtonEvents -Window $appState.Window -Controls $appState.Controls -State $appState
Register-WindowEvents -Window $appState.Window -State $appState

# Initial load
Update-Display -Path $appState.CurrentPath -State $appState

# Show window
$appState.Window.ShowDialog()
```

### Benefits of Modularization

1. **Testability**: Core module functions can be unit tested without UI.
2. **Reusability**: Use Core.psm1 and Charts.psm1 in other scripts.
3. **Maintainability**: Each module <300 lines, clear responsibility.
4. **Parallel Development**: Multiple developers can work on different modules.
5. **Version Control**: Easier to track changes, fewer merge conflicts.
6. **Distribution**: Create PSGallery package for easy reuse.

### Implementation Roadmap

**Step 1: Extract Core Functions**
- Move folder scanning and size calculation to Core.psm1.
- Test independently with Pester.

**Step 2: Extract UI Functions**
- Move XAML and window creation to UI.psm1.
- Parameterize hardcoded values (colors, sizes, margins).

**Step 3: Extract Charts**
- Move Draw-PieChart and related functions to Charts.psm1.
- Create reusable helper (Get-PieChartData) for data aggregation.

**Step 4: Create Orchestrator**
- Refactor Main.ps1 to use dependency injection.
- Replace global variables with $appState object passed to all functions.

**Step 5: Add Tests**
- Create Pester test files for Core.psm1 functions.
- Mock WPF and file system for unit tests.

### Code Quality Checklist

- [ ] No global variables in modules (use parameters or $appState).
- [ ] All functions have help comments (Get-Help compatible).
- [ ] Core functions have no UI dependency (no WPF/XAML types).
- [ ] Each module exports only public functions (prefix private with _).
- [ ] Module manifest (.psd1) declares all dependencies.
- [ ] README documents module purpose and public functions.

## Change History Addendum

### 2026-07-20

- Added responsive export controls to the top toolbar (export button plus format combo box).
- Implemented export output generation in CSV, XLSX, Markdown, and HTML.
- Standardized report schema for all formats with size, timestamps, attributes, and sub-folder count.
- Added absolute path to CSV and Markdown exports for folder traceability.
- Added hierarchy indentation for HTML output to improve visual parent-child readability.
- Bound export recursion depth to Recurse checkbox state (recursive vs immediate-only).
- Added post-export app launching (Excel, Notepad, Edge with fallback handling).
- Added Explorer-style attribute flag output (for example: RHSACE).
- Added optional Include Attribute Names setting to export a second descriptive attributes column.
- Added clickable folder hyperlinks in XLSX, Markdown, and HTML exports.
- Improved selected-row contrast with darker purple highlight to stand out over alternating row colors.
- Fixed export path normalization issues that could cause TrimEnd runtime failures.
- Updated primary settings file naming to WpfFolderSizeBrowser.Settings.json with backward-compatible fallback loading.
- Persisted selected export format and both export-related checkboxes in settings.
- Added recurse-state metadata at the top of XLSX/Markdown/HTML outputs (not CSV).
- Added timed post-export status behavior: full path for 5 seconds, then compact finished message.
- Added tooltips across controls including detailed recurse usage guidance.
- [ ] Pester tests cover Core and Settings modules.

### Example: Testable Core Module

```powershell
# Core.psm1
<#
.SYNOPSIS
    Scans directory and returns folder size data.

.DESCRIPTION
    Pure PowerShell function, no UI dependencies.
    Can be unit tested and reused in other scripts.
#>
function Get-FolderSizes {
    param(
        [string]$Path = (Get-Location),
        [switch]$Recurse,
        [scriptblock]$ProgressCallback
    )
    
    $folders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
    $result = @()
    
    foreach ($folder in $folders) {
        if ($ProgressCallback) { & $ProgressCallback -FolderName $folder.Name }
        
        $files = if ($Recurse) {
            Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue
        } else {
            Get-ChildItem -Path $folder.FullName -File -ErrorAction SilentlyContinue
        }
        
        $size = if ($files) { ($files | Measure-Object -Sum -Property Length).Sum } else { 0 }
        $subfolderCount = (Get-ChildItem -Path $folder.FullName -Directory -ErrorAction SilentlyContinue).Count
        
        $result += [PSCustomObject]@{
            Name = $folder.Name
            FullPath = $folder.FullName
            SizeBytes = $size
            FileCount = $files.Count
            SubfolderCount = $subfolderCount
        }
    }
    
    return $result
}

Export-ModuleMember -Function Get-FolderSizes
```

This approach scales to 5000+ lines while remaining maintainable and testable.
