# WpfTouchFiles5ChatGPT v6 Icons - June 2026 Changes

## Overview

This document summarizes the Icons variant updates for the Touch Files WPF application.

The Icons build keeps the responsive table/card behavior and icon-forward command row, and now includes a centered hover metrics badge that mirrors live window coordinates.

**Last Updated:** 2026-06-24

---

## Last Two Days - Summary

### UI and Visual Design

- Updated command buttons to use a pastel motif at rest and solid colors on hover/press.
- Applied color mapping for key actions:

  - Encryption: green (Windows-aligned)
  - Compression: blue
  - Hidden: gray

- Fixed command button clipping at the bottom edge by adjusting top-row layout measurement.
- Added a top branding panel using the same app icon resource with:

  - Title: **Touch Files**
  - Subtitle: **June 2026 Icons**

- Reworked layout so branding and command buttons are in separate rows and no longer overlap.
- Centered both the branding panel and the command button group.

### App Icon and Branding

- Replaced generic app icon behavior with a Windows shell-based folder icon.
- Composed an update/touch clock overlay on top of the folder icon for meaningful small-size recognition.
- Reused the same generated icon for:

  - Window icon (upper-left title bar)
  - Large branding icon in the top panel

- Fixed PowerShell/WPF runtime issues in custom icon drawing:

  - Point constructor parsing in PowerShell 5.1
  - Correct `DrawEllipse` overload usage

### Diagnostics and Error Dialog

- Changed diagnostics popup to a two-pane layout:

  - Top pane: error list
  - Bottom pane: PowerShell session output

- Updated open behavior to anchor on the first error entry instead of scrolling to the end.
- Added refresh support for diagnostics content.
- Extended diagnostics capture to include full-session output content.
- Added in-memory session output fallback so the bottom pane is not blank when transcript capture is unavailable.

### Documentation and Comments

- Added expanded script-level comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.NOTES`, `.EXAMPLE`).
- Added function-level help comments for reusable functions.
- Added clearer structural comments in XAML for reusable/interactive sections.

---

## Last Two Days - Change Log

### 2026-06-12

- Introduced themed command button interactions (pastel idle + solid hover/pressed).
- Implemented action-color mapping (green encryption, blue compression, gray hidden).
- Expanded diagnostics popup to include session output content.
- Added transcript-based diagnostics readout and refresh behavior.
- Converted diagnostics view to split panes (Errors / PowerShell Output).
- Anchored diagnostics error list to the first error entry on open and refresh.

### 2026-06-13

- Fixed button bottom-edge clipping by removing fixed wrap item height constraints.
- Added missing checkbox tooltips for row-level selection checkboxes in table and card views.
- Added shell-based folder icon with clock overlay; applied as window icon.
- Added top branding panel with large reused app icon and responsive title/subtitle.
- Moved branding into its own panel above commands to prevent overlap.
- Centered branding panel and centered command button group.
- Fixed icon drawing runtime issues (`Point` constructor parsing and `DrawEllipse` overload).
- Added in-memory diagnostics output stream so lower diagnostics pane always shows content.
- Expanded code comments and help metadata in script and XAML.

---

## Latest Update

### Centered Hover Arrows Coordinate Badge

- Added a floating, transparent overlay badge that stays centered over the main window.
- Badge includes a 4-direction arrows icon and live metrics text.
- Metrics are shown as comma-delimited values in this exact order:

  - `width,height,x,y`

- Values update during:

  - Window resize (`SizeChanged`)
  - Window move (`LocationChanged`)
  - Initial render (`ContentRendered`)
  - Clock timer tick (1-second refresh)

- Overlay is non-interactive (`IsHitTestVisible=False`) so it does not block clicks on the main UI.
- Overlay closes automatically when the main dialog closes.

### Follow-up: Metrics Dialog Width and Window Placement

- Fixed clipping on the right side of the metrics dialog so X/Y values remain visible.
- Startup width is now calculated from a percentage of the main window width.
- Startup sizing constants were tuned to:

  - Width percent: 35%
  - Minimum width: 190
  - Maximum width: 420

- After startup, the metrics dialog width is locked and stays the same while the main window is resized.
- Added a new checkbox: **Remember window size/location**.
- When enabled, the app saves and restores main window width, height, left, and top values between runs.
- Restored bounds are clamped to the current desktop work area to avoid off-screen placement.

### Persistence Location and Stored Values

- Persistent screen position is stored in:

  - `WpfTouchFiles5ChatGPT.v6.June2026.window.json`

- The settings file path is built in script code as:

  - `$script:windowSettingsPath = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.window.json'`

- Settings are saved by `Save-WindowSettings` and loaded by `Get-WindowSettings`.
- Window placement is applied by `Restore-WindowSettings` only when remember mode is enabled.
- Persisted fields include:

  - `RememberWindow`
  - `Width`
  - `Height`
  - `Left`
  - `Top`

- The JSON write uses `Set-Content -Encoding UTF8`.

---

## Display Units: DIP vs DPI

- **DIP (Device-Independent Pixel)** is WPF's logical unit for layout and coordinates.
- **DPI (Dots Per Inch)** is the monitor's physical pixel density/scaling context.
- In WPF, `Width`, `Height`, `Left`, and `Top` are stored and reported in **DIP**, not raw hardware pixels.
- Baseline mapping is:

  - 1 DIP = 1 physical pixel at 100% scaling (96 DPI)

- At higher scaling (for example 150%), one DIP maps to more physical pixels.
- This is why saved window bounds and hover metrics can look different from pixel values reported by some screen-capture or low-level tools.
- This behavior is expected and is what keeps WPF UI sizing visually consistent across monitors with different DPI settings.

---

## Files

- Script: `WpfTouchFiles5ChatGPT.v6.June2026.Icons.ps1`
- Layout: `WpfTouchFiles5ChatGPT.v6.June2026.Icons.xaml`
- Baseline v6 notes: `WpfTouchFiles5ChatGPT.v6.June2026.md`

---

## Notes

- Existing footer metrics (`W: H: X: Y:`) are preserved.
- The overlay mirrors the same coordinate values in the new comma format.
- The overlay is owner-bound to the main window and remains visually centered as the window moves.

---

## 2026-06-15 Update

### Footer Status and Selection Summary

- Added a new footer status value: **Files selected: N**.
- Positioned selected count between **Files loaded: N** and the diagnostics/error icon.
- Updated `Update-UiState` so selected count refreshes continuously with selection changes.

### Additional Settings Persistence

- Extended existing JSON settings persistence to include:

  - `CompactMode`
  - `ClearBeforeDrop`

- Both values are now saved into the same existing settings file:

  - `WpfTouchFiles5ChatGPT.v6.June2026.window.json`

- Restore logic now reapplies both toggles at startup.
- Compact mode path visibility is reapplied during restore.

### About Dialog

- Added an **About Touch Files** dialog that displays:

  - PS1 file last modified timestamp
  - XAML file last modified timestamp
  - PowerShell version
  - Windows version/build
  - WPF version
  - .NET version/runtime
  - Free system memory
  - PowerShell memory usage (working set + private)
  - Memory available to PowerShell

- Added a read-only text area showing **changes in the last 7 days**.
- Version history uses git log when available; otherwise it falls back to filesystem timestamp summary.

### About Dialog Entry Points

- Added a header **?** button that opens About.
- Added click-to-open behavior on the top branding area (Touch Files logo/title block).

### About Dialog Clipboard Export

- Added **Copy to Clipboard** button in About.
- Copy output is plain text and includes:

  - A top timestamp with day-of-week and date/time
  - All key/value system/runtime details from the upper section
  - The 7-day version history at the bottom

- Included friendly emoji/title line in copied output (`📋 Touch Files About Report`).
- Added clipboard fallback behavior:

  - Uses `Set-Clipboard` when available
  - Falls back to `[System.Windows.Clipboard]::SetText(...)`

---

## 2026-06-15 (Later) - Docking Controls and Bug Fix

### New Header Dock Buttons

- Added three compact buttons to the right of the top Touch Files logo/title area:

  - **300px dock toggle**: docks left at 300px width, then right at 300px on next click.
  - **Half-screen dock toggle**: docks left half, then right half on next click.
  - **Next monitor**: moves to the next monitor while preserving the active dock mode.

### Monitor-Aware Docking Behavior

- Added monitor helpers based on `System.Windows.Forms.Screen`.
- Implemented explicit dock modes to preserve intent across actions:

  - `narrow-left`
  - `narrow-right`
  - `half-left`
  - `half-right`

- Next-monitor behavior now reapplies the current dock mode on the destination monitor.
- If not currently docked, next-monitor move preserves relative on-screen position and current size as closely as possible.

### Bug Fix: 300px Left Dock Could Hide the App

- Fixed a DPI coordinate mismatch that could push the app off-screen (appearing permanently minimized) when using 300px left dock.
- Root cause: monitor working-area coordinates were in physical pixels while WPF window geometry uses DIPs.
- Fix details:

  - Added DPI scale detection (`VisualTreeHelper.GetDpi`).
  - Added conversion helpers for screen rectangle pixels -> WPF DIPs.
  - Added conversion helper for target dock width pixels -> WPF DIPs.
  - Updated both dock and next-monitor placement logic to use DPI-correct coordinates.

### Validation

- No PowerShell syntax or analyzer errors introduced by these changes.
- No XAML errors introduced by these changes.

---

## 2026-06-23 Update - Persistent File Comments

### Comment Field Added to Grid and Card Views

- Added a new **Comment** column to the main table (GridView).
- Added a new **Comment** field to each card in the card view for narrow windows.
- Comment fields are visibly editable with a light cream background and gray border for clarity.
- Comments are in-place editable; changes auto-save when focus leaves the field.

### Comment Persistence via NTFS Alternate Data Streams

- Comments are automatically saved to a file's `:TouchFileComment` alternate data stream (ADS).
- When files are added to the list, existing comments are automatically loaded from the ADS.
- Comment save logic uses silent-fail behavior:
  - Works on any NTFS volume
  - Gracefully skips non-NTFS volumes (FAT32, exFAT, etc.)
  - Silently handles access-denied or read-only file scenarios

### Auto-Save on Focus Loss

- Grid view: `PreviewLostKeyboardFocus` event on TextBox saves to ADS
- Card view: `PreviewLostKeyboardFocus` event on TextBox saves to ADS
- No explicit Write/Save button needed; changes persist immediately when you click away

### File Type Support Documentation

Added two new helper functions:
- `Get-FileComment` - retrieves comment from file's `:TouchFileComment` stream
- `Set-FileComment` - writes comment to file's `:TouchFileComment` stream

#### About Dialog Enhancement

Added a new **"Comment File Types"** tab in the About dialog that documents:

**Universal Support:**
- ✓ All files on NTFS volumes support comment storage via ADS

**Native Metadata Support by File Type:**

**Office Documents:**
- .docx, .xlsx, .pptx - Title, Subject, Comments, Author, Category
- .odt (LibreOffice) - Author, Title, Subject

**Document Formats:**
- .pdf - PDF metadata (Creator, Producer, Subject, Keywords)
- .rtf - Embedded properties

**Images:**
- .jpg, .jpeg - EXIF, IPTC, XMP metadata
- .png - PNG metadata (Title, Description, Comment)
- .gif, .bmp - Limited native support

**Audio Files:**
- .mp3 - ID3 tags (Title, Artist, Album, Comment)
- .wav - LIST INFO chunk (Title, Subject, Comment)
- .flac - Vorbis comments
- .m4a - iTunes/MP4 metadata

**Video Files:**
- .mp4 - MP4 metadata atoms (Title, Comment)
- .mkv - Matroska tags (Title, Comments)
- .avi - AVI metadata

**Not Supported (No Native Metadata):**
- .txt - Plain text files
- .ps1, .py, .js, .cs, etc. - Code/script files
- .exe, .dll - Executables (security/signature concerns)
- .zip, .rar, .7z - Archive formats
- Other binary files without defined metadata standards

### Recommendation

Use ADS-based comments for universal compatibility. They persist with the file on NTFS volumes and work with any file type. For file types with native metadata, both storage methods can coexist without conflict.

### Implementation Details

- Comment field is two-way bound to `TouchFileItem.Comment` property
- `UpdateSourceTrigger=LostFocus` ensures changes commit only after editing is complete
- Both grid and card templates use the same binding strategy
- No persistence settings file needed; comments live only in the file's ADS stream

---

## 2026-06-24 Update - Comment Metadata Reliability and Diagnostics

### Change Log

#### 1) Excel comment read/write reliability improvements (.xlsx and related)

- Updated Excel COM metadata reads to prefer numeric BuiltinDocumentProperties indexes before name lookups:
  - `6` (Comments)
  - `2` (Subject)
- Kept property-name fallback probes for compatibility (`Comments`, `Comment`, `Subject`).
- Updated Excel COM metadata writes to set both numeric indexes and name-based properties where available.
- This addresses localized Office environments where English property names are not stable.

#### 2) OpenXML metadata coverage expanded for comment retrieval

- Expanded OpenXML read path from a single field to multiple fields in `docProps/core.xml`:
  - `dc:description`
  - `dc:subject`
  - `cp:keywords`
- Updated OpenXML write logic to populate both `dc:description` and `dc:subject` with the app comment value.
- Updated comment source status text to reflect broader OpenXML sources.

#### 3) Editable comment textbox color adjustment

- Changed editable comment textbox background from prior green tint to a clearer light green:
  - `#FFDDF5DD`
- Applied in both views:
  - Grid/table comment editor
  - Card view comment editor

#### 4) OpenXML extension support expanded beyond Excel-only

- Extended OpenXML detection to include Word and PowerPoint OpenXML families in addition to Excel:
  - Word: `.docx`, `.docm`, `.dotx`, `.dotm`
  - Excel: `.xlsx`, `.xlsm`, `.xltx`, `.xltm`
  - PowerPoint: `.pptx`, `.pptm`, `.potx`, `.potm`
- Result: Word files now enter OpenXML comment read/write flow instead of being skipped.

#### 5) Targeted Word shell metadata fallback

- Added targeted fallback logic in shell comment retrieval for Word OpenXML files.
- Added additional property probes used by Explorer/property handlers on some systems:
  - `System.Document.Comment`
  - `System.Subject`
  - `System.Document.Subject`
  - `System.Keywords`
  - `System.Document.Keywords`
  - `System.Title`
- Added Word-only fallback scan for populated Explorer columns when standard comment columns are empty:
  - `Subject`, `Tag`, `Tags`, `Keyword`, `Keywords`

#### 6) New one-file Comment Diagnostics button and report window

- Added new button at end of checkbox row:
  - **Comment Diagnostics**
- Visibility rule:
  - Button is visible only when exactly one file is selected.
  - Hidden for zero or multiple selections.
- Added click behavior:
  - Generates diagnostics report for selected file.
  - Opens a dedicated diagnostics window.
  - Supports **Copy Report** to clipboard.

#### 7) New diagnostics report content

- Added report generator that includes:
  - File path and timestamp
  - OpenXML comment read result
  - Shell comment read result
  - App-selected comment value
  - Last comment source used by app
- Added targeted Shell metadata dump:
  - ExtendedProperty probes for comment-related property keys
  - Explorer column scan (first 320 columns) for non-empty comment-related fields

### Summary

- Comment reliability was substantially improved across Excel and Word scenarios by broadening metadata read/write paths and adding locale-safe property handling.
- Word comment visibility issues (Explorer shows comment, app does not) were addressed with both OpenXML extension enablement and targeted shell fallbacks.
- Comment editing UX was refined with an explicit light-green editable state.
- A new built-in diagnostics workflow is now available for single-file troubleshooting without leaving the app.

---

## 2026-06-24 Update - Startup Helper Verification and Load-Order Guard

### Change Log

#### 1) Fixed runtime helper load order (prevents "term not recognized" during UI session)

- Moved OpenXML helper function definitions to execute before the main window opens:
  - `Test-OpenXmlCommentExtension`
  - `Get-OpenXmlCoreComment`
  - `Set-OpenXmlCoreComment`
- Removed duplicate late definitions that previously appeared after `ShowDialog()`.
- Root cause fixed: helper definitions below `ShowDialog()` are not executed until dialog close, so click handlers could reference functions not yet loaded.

#### 2) Added defensive startup helper verification before UI launch

- Added new startup gate function:
  - `Test-StartupHelperFunctions`
- The check runs immediately before opening the main window.
- If required helpers are missing, startup now:
  - Logs a clear failure message (with function names)
  - Updates footer status to indicate startup check failure
  - Shows a blocking error message box
  - Aborts launch before `ShowDialog()`

#### 3) Expanded required helper list to critical app functions

Startup verification now checks all of the following:

- `Write-SessionOutput`
- `Add-ErrorLog`
- `Get-SelectedItems`
- `Update-ErrorIndicator`
- `Update-UiState`
- `Test-OpenXmlCommentExtension`
- `Get-OpenXmlCoreComment`
- `Set-OpenXmlCoreComment`
- `Get-FileComment`
- `Get-ShellExplorerComment`
- `Get-FileCommentDiagnosticsReport`
- `Show-CommentDiagnosticsWindow`

#### 4) Hardened startup failure logging path

- Startup verification no longer assumes logging helpers exist.
- Failure logging fallback sequence:
  - Use `Add-ErrorLog` when available
  - Else use `Write-SessionOutput` with `ERROR` level
  - Else use `Write-Error`

### Summary

- Added a fail-fast startup safety check that prevents opening a partially loaded UI.
- Improved error clarity when helper wiring is broken.
- Eliminated the specific runtime path that produced:
  - `The term 'Test-OpenXmlCommentExtension' is not recognized...`

### Known Failure Signature

Use the text below as copy/paste signatures for rapid troubleshooting.

Primary signature:

```text
TerminatingError(): "The term 'Test-OpenXmlCommentExtension' is not recognized as a name of a cmdlet, function, script file, or executable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again."
```

Startup guard signature:

```text
Startup verification failed. Missing helper function(s):
```

Quick triage checklist:

```text
1) Confirm helper functions are declared before ShowDialog().
2) Search for duplicate helper definitions below ShowDialog() and remove/move them.
3) Re-run startup and verify the helper check passes.
```

---

## 2026-06-29 Update - About Dialog Lock-Up Fix

### Issue Reported

The About dialog was locking up when opened, causing the entire application UI to freeze.

### Root Causes Identified

#### 1) Git operations could hang indefinitely

- `Get-RecentChangesText` function called Git synchronously to retrieve version history
- No timeout protection if Git was slow, unresponsive, or the repository was in an unusual state
- Blocking Git calls would freeze the UI thread

#### 2) Missing closure on clipboard text variable

- Event handler for Copy to Clipboard button referenced `$clipboardText` from parent scope
- Variable was captured without proper closure, potentially causing scope-related issues

#### 3) No re-entrancy protection

- Multiple clicks on About button could attempt to open multiple dialogs simultaneously
- No guard to prevent overlapping dialog instances

### Changes Made

#### 1) Added timeout protection to Git operations (lines 782-835)

- Wrapped Git calls in a background job with a 3-second timeout
- Job-based execution prevents UI thread blocking
- Gracefully falls back to file timestamp summary if Git times out or is unavailable
- Uses `Start-Job` with `Wait-Job -Timeout 3` for controlled execution

#### 2) Added re-entrancy protection (line 384)

- New script-level flag: `$script:aboutDialogShowing`
- Dialog function checks flag on entry and returns early if already showing
- Flag is set to `$true` when dialog opens
- Flag is reset to `$false` in the dialog's `Closed` event handler

#### 3) Improved error handling and closure management (lines 854-859, 1053-1071)

- Added early return check if dialog is already showing
- Clipboard button event handler now uses `.GetNewClosure()` to properly capture `$clipboardText`
- Added `Closed` event handler to reset the re-entrancy flag
- Wrapped entire function in comprehensive try-catch with user-friendly error message
- Error message box displays if dialog creation fails

### Technical Details

**Background Job Pattern:**
```powershell
$gitJob = Start-Job -ScriptBlock {
    param($dir, $sinceStamp, $scriptFile, $xamlFile)
    # Git operations here
} -ArgumentList $scriptDir, $sinceStamp, $ScriptFile, $XamlFile

$gitJob | Wait-Job -Timeout 3 | Out-Null
if ($gitJob.State -eq 'Completed') {
    $result = Receive-Job -Job $gitJob -ErrorAction SilentlyContinue
}
Remove-Job -Job $gitJob -Force -ErrorAction SilentlyContinue
```

**Re-entrancy Guard Pattern:**
```powershell
if ($script:aboutDialogShowing) {
    Write-SessionOutput -Level WARN -Message 'About dialog is already showing.'
    return
}
$script:aboutDialogShowing = $true
# ... dialog code ...
$aboutWindow.Add_Closed({
    $script:aboutDialogShowing = $false
})
```

### Result

The About dialog now:
- Opens reliably without freezing the UI
- Handles slow or unavailable Git gracefully with automatic timeout
- Prevents multiple instances from opening simultaneously
- Shows file timestamps as fallback when Git history is unavailable
- Displays clear error messages if dialog creation fails entirely

### Files Modified

- `WpfTouchFiles5ChatGPT.v6.June2026.Icons.ps1`
  - Line 384: Added `$script:aboutDialogShowing` flag initialization
  - Lines 782-835: Rewrote `Get-RecentChangesText` with job-based timeout
  - Lines 854-859: Added re-entrancy check and `$osInfo` declaration fix
  - Lines 1053-1071: Added proper closure and cleanup event handlers

---

## 2026-06-29 Update (Later) - About Dialog Simplified and Read-Only Button Added

### About Dialog Git Operations Simplified

#### Issue
The background job approach with `Start-Job` for Git operations was causing parsing errors and compatibility issues in the WPF STA thread context.

#### Solution - Git History Disabled
- Removed Git command execution entirely from `Get-RecentChangesText`
- Function now shows only file timestamp information
- Fast, reliable, no risk of hanging
- Message updated to: "File timestamp summary (git history disabled for performance)"

#### Benefits
- Eliminates all potential hang scenarios from Git operations
- No dependency on Git availability or repository state
- Instant About dialog opening
- Simpler, more maintainable code

### WMI Query Timeout Protection

Added 2-second timeouts to both `Get-CimInstance` calls in `Show-AboutDialog`:
- OS information query (line 1207)
- Memory information query (line 1244)

This prevents WMI/CIM queries from hanging if WMI service is slow or unresponsive.

### New Feature: Read-Only Attribute Toggle Button

#### UI Changes (XAML)

Added new **Read-Only** toggle button after the Encryption button:
- Icon: Lock symbol (`&#xE72E;`)
- Color scheme: Orange/amber theme
  - Background: `#FFF4E6` (light cream)
  - Border: `#F5C88D` (soft orange)
  - Foreground: `#6B4423` (brown text)
  - Hover background: `#F59E00` (bright orange)
  - Pressed background: `#D58700` (darker orange)
- Tooltip: "Toggle the Read-Only attribute on selected files"
- Positioned between Encryption and Hidden buttons

#### Functionality (PowerShell)

**Button Reference:**
- Line 404: Added `$btnReadOnly` variable cached from XAML

**Toggle Handler (lines 3902-3929):**
- Uses XOR operation to toggle ReadOnly flag: `$currentAttributes -bxor [System.IO.FileAttributes]::ReadOnly`
- Works on all selected files
- Updates attribute display immediately after toggle
- Logs each toggle operation to session output
- Error handling for access-denied scenarios

**UI State Management:**
- Line 2190: Added to button list for icon-only mode support
- Line 2339: Added enable/disable logic - button enables only when files are selected

#### Attribute Display

The Read-Only attribute 'R' is now visible in both views:

**Table View (line 356):**
- Attributes column shows letter combinations (e.g., "AR", "ARC", "ARCH")
- 'R' appears when ReadOnly flag is set

**Card View (line 440):**
- Shows "Attr: " followed by attribute letters
- Read-Only files display 'R' in the attribute string

#### Attribute Letter Mapping

Existing `Get-AttributeLetters` function (line 228) already included:
- **A** = Archive
- **R** = ReadOnly ✓
- **H** = Hidden
- **S** = System
- **C** = Compressed
- **E** = Encrypted
- **N** = None (when no flags are set)

### Usage

1. Select one or more files in the list
2. Click the **Read-Only** button (orange with lock icon)
3. The ReadOnly attribute toggles for all selected files
4. Attribute column updates to show/hide 'R' flag
5. Status bar confirms: "Toggled read-only on N file(s)"

### Files Modified

- `WpfTouchFiles5ChatGPT.v6.June2026.Icons.xaml`
  - Lines 224-246: Added BtnToggleReadOnly button definition
- `WpfTouchFiles5ChatGPT.v6.June2026.Icons.ps1`
  - Line 404: Added button variable caching
  - Lines 1138-1162: Simplified `Get-RecentChangesText` (removed Git, timestamps only)
  - Lines 1207, 1244: Added CIM query timeouts
  - Lines 2190: Added to button list
  - Lines 2339: Added enable/disable logic
  - Lines 3902-3929: Added Read-Only toggle click handler

---

## 2026-06-29 Update (Final) - Date Stamp Button Added

### New Feature: Date Stamp File Names

Added a new **Date Stamp** button that appends the current date to selected file names before the file extension.

#### UI Changes (XAML)

Added new **Date Stamp** button after the Read-Only button:
- Icon: Calendar symbol (`&#xE787;`)
- Color scheme: Purple/violet theme
  - Background: `#F3E5F5` (light lavender)
  - Border: `#CE93D8` (medium purple)
  - Foreground: `#4A148C` (dark purple text)
  - Hover background: `#9C27B0` (bright purple)
  - Pressed background: `#7B1FA2` (darker purple)
- Tooltip: "Add date stamp (YYYY-MM-DD-DayOfWeek) to selected file names before the extension"
- Positioned between Read-Only and Hidden buttons

#### Functionality (PowerShell)

**Button Reference:**
- Line 405: Added `$btnDateStamp` variable cached from XAML

**Date Stamp Handler (lines 3933-3997):**
- Generates date stamp in format: `yyyy-MM-dd-ddd` (e.g., `2026-06-29-Mon`)
- Inserts date stamp before file extension
- Uses `Rename-Item` to perform the rename operation
- Updates item properties to reflect new path after rename

**Smart Skip Logic:**
1. **Already stamped files**: Skips files that already have a date stamp pattern at the end of the base name (regex: `\d{4}-\d{2}-\d{2}-\w{3}$`)
2. **Existing target files**: Checks if target filename already exists and skips to prevent overwriting
3. **Missing files**: Skips files that no longer exist on disk

**Error Handling:**
- Tracks success count and fail/skip count separately
- Logs each operation to session output with appropriate level (INFO, WARN, ERROR)
- Displays detailed error context for failures
- Shows combined status in status bar: "Date stamped X file(s) (Y failed/skipped)"

**UI State Management:**
- Line 2191: Added to button list for icon-only mode support
- Line 2340: Added enable/disable logic - button enables only when files are selected

#### Examples

**Before → After:**
- `MyDocument.docx` → `MyDocument-2026-06-29-Sun.docx`
- `Report.xlsx` → `Report-2026-06-29-Sun.xlsx`
- `Photo.jpg` → `Photo-2026-06-29-Sun.jpg`
- `Script.ps1` → `Script-2026-06-29-Sun.ps1`

**Already stamped (skipped):**
- `File-2026-06-28-Sat.txt` → *(no change, already has date stamp)*

**Target exists (skipped):**
- If `Document-2026-06-29-Sun.docx` already exists, the original `Document.docx` won't be renamed

#### Usage

1. Select one or more files in the list
2. Click the **Date Stamp** button (purple with calendar icon)
3. Files are renamed with current date before extension
4. Display updates to show new file names
5. Status bar shows success/failure summary

#### Date Format Details

- **Format**: `yyyy-MM-dd-ddd`
- **Year**: 4-digit year (2026)
- **Month**: 2-digit month with leading zero (06)
- **Day**: 2-digit day with leading zero (29)
- **Day of week**: 3-letter abbreviation (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
- **Separator**: Hyphen (-) between date components

The format is designed to:
- Sort chronologically when files are listed alphabetically
- Be human-readable with day-of-week context
- Be filesystem-safe (no special characters)
- Match common date stamping conventions

### Files Modified

- `WpfTouchFiles5ChatGPT.v6.June2026.Icons.xaml`
  - Lines 248-258: Added BtnDateStamp button definition with calendar icon and purple theme
- `WpfTouchFiles5ChatGPT.v6.June2026.Icons.ps1`
  - Line 405: Added `$btnDateStamp` button variable caching
  - Line 2191: Added to button list for icon-only mode
  - Line 2340: Added enable/disable logic
  - Lines 3933-3997: Added Date Stamp click handler with rename logic, skip detection, and error handling

---

## 2026-06-29 Additional Updates

### Grid View: BaseName Text Wrapping

#### Issue
Long file names in the Grid View's Path column were being clipped on the right side, making it difficult to read the full file name.

#### Solution
Added `TextWrapping="Wrap"` to the bold BaseName TextBlock in the Path column.

#### Change
- `WpfTouchFiles5ChatGPT.v6.June2026.Icons.xaml`
  - Line 366: Added `TextWrapping="Wrap"` to BaseName TextBlock

#### Result
Long file names now wrap to multiple lines within the Path column width, matching the behavior of the DisplayPath below it. The full file name is always visible without horizontal scrolling.

---

### Date Stamp Toggle Mode (Single File)

#### Enhancement
Modified the Date Stamp button to work as a toggle when exactly one file is selected, allowing users to both add and remove date stamps.

#### New Behavior

**When ONE file is selected:**
- **File has date stamp**: Clicking the button **REMOVES** the date stamp
  - Example: `Document-2026-06-28-Sat.txt` → `Document.txt`
  - Works with any date, not just today's date
- **File has NO date stamp**: Clicking the button **ADDS** today's date stamp
  - Example: `Document.txt` → `Document-2026-06-29-Sun.txt`

**When MULTIPLE files are selected:**
- Original behavior preserved: **ADDS** date stamp to all files
- Skips files that already have date stamps
- Prevents overwriting existing files

#### Implementation Details

**Date Stamp Detection:**
- Uses regex pattern: `^(.+)-\d{4}-\d{2}-\d{2}-\w{3}$`
- Captures the base name before the date stamp: `$matches[1]`
- Matches any valid date pattern at the end of the filename

**Remove Logic (Single File with Date Stamp):**
1. Extract base name before the date stamp
2. Check if target filename (without date) already exists
3. If target doesn't exist, rename file to remove date stamp
4. Update item display properties
5. Log operation and show status: "Date stamp removed from file"

**Add Logic (Single File without Date Stamp):**
1. Generate today's date stamp in format `yyyy-MM-dd-ddd`
2. Append date stamp to base name
3. Check if target filename (with date) already exists
4. If target doesn't exist, rename file to add date stamp
5. Update item display properties
6. Log operation and show status: "Date stamp added to file"

**Safety Checks:**
- Verifies file exists before attempting rename
- Checks if target filename exists (prevents overwriting)
- Comprehensive error handling with logging
- Status messages reflect success/failure

#### UI Updates

**Tooltip Updated:**
- Old: "Add date stamp (YYYY-MM-DD-DayOfWeek) to selected file names before the extension"
- New: "Add/Remove date stamp: Multiple files = add stamp. One file = toggle (add if missing, remove if present)"

**Status Bar Messages:**
- Single file add: "Date stamp added to file"
- Single file remove: "Date stamp removed from file"
- Multiple files: "Date stamped X file(s) (Y failed/skipped)"

#### Usage Examples

**Toggle Scenario:**
1. User selects `Report-2026-06-25-Thu.docx`
2. Clicks Date Stamp button
3. File renamed to: `Report.docx`
4. User clicks Date Stamp button again (same file still selected)
5. File renamed to: `Report-2026-06-29-Sun.docx` (today's date)

**Batch Add Scenario:**
1. User selects 5 files (mix of dated and undated)
2. Clicks Date Stamp button
3. Undated files get today's stamp
4. Already-dated files are skipped
5. Status: "Date stamped 3 file(s) (2 failed/skipped)"

**Error Scenario:**
1. User tries to remove date stamp from `File-2026-06-28-Sat.txt`
2. But `File.txt` already exists in same directory
3. Operation skipped with warning
4. Status: "Date stamp removal failed: target exists"

#### Benefits

- **Intuitive toggle behavior** for single-file operations
- **Batch add capability** preserved for multiple files
- **Works with any date** (not just today's) when removing
- **Safe operations** with existence checks
- **Clear feedback** via status bar and logging
- **Flexible workflow** - add stamps in bulk, remove individually

### Files Modified

- `WpfTouchFiles5ChatGPT.v6.June2026.Icons.xaml`
  - Line 249: Updated tooltip to explain toggle behavior
  - Line 366: Added TextWrapping="Wrap" to BaseName TextBlock in Grid View
- `WpfTouchFiles5ChatGPT.v6.June2026.Icons.ps1`
  - Lines 3933-4054: Enhanced Date Stamp handler with toggle logic for single-file mode
    - Added detection of existing date stamps
    - Added remove logic with regex pattern matching
    - Added mode detection (single vs. multiple files)
    - Preserved original batch-add behavior for multiple files
