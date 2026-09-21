# TrackSessions Testing Ideas and Recommendations

**Document Version:** 1.0  
**Last Updated:** 2026-09-20  
**Related Files:** TrackSessions.Refactor.CR2.ps1, TrackSessions.UserEditor2.ps1, TrackSessions.Settings.json

---

## Recent Feature Testing (2026-09-20)

### Settings Persistence Features

All persistence features save immediately on change, so no data loss even if app crashes.

#### 1. Log Viewer Zoom Persistence

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Lines 4174-4196

**Test Steps:**
1. Launch main application
2. Click "Log..." button to open Debug Log Viewer
3. Note the current font size (default should be Font: 11.0)
4. Click "+" button several times to zoom in (e.g., to Font: 15.4)
5. Close the Log Viewer window
6. Reopen Log Viewer via "Log..." button
7. **Expected:** Font size should be Font: 15.4 (persisted from previous session)
8. Click "-" button to zoom out to a different level (e.g., Font: 9.9)
9. Close and reopen
10. **Expected:** Font size should be Font: 9.9

**Edge Cases:**
- Test minimum zoom (70% = Font: 7.7)
- Test maximum zoom (600% = Font: 66.0)
- Test behavior if settings file is read-only
- Test behavior if settings file is corrupted

**Settings File Impact:**
- Modifies: `Settings.ZoomLevels.LogViewer`
- Range: 0.7 to 6.0

---

#### 2. User Editor Grid Zoom Persistence

**Feature Location:** TrackSessions.UserEditor2.ps1, Lines 1780+

**Test Steps:**
1. Launch main application
2. Click "Users..." button to open User Editor
3. Note the current grid font size (default should be Font: 12.0)
4. Click "+" button in header area to zoom in (e.g., to Font: 16.8)
5. Close the User Editor window
6. Reopen User Editor via "Users..." button
7. **Expected:** Grid font size should be Font: 16.8
8. Click "-" button to zoom out (e.g., to Font: 10.8)
9. Close and reopen
10. **Expected:** Grid font size should be Font: 10.8

**Edge Cases:**
- Test with large user list (20+ users) - ensure grid performance
- Test minimum zoom (70% = Font: 8.4)
- Test maximum zoom (300% = Font: 36.0)
- Test zoom with grid scrollbars visible vs. hidden

**Settings File Impact:**
- Modifies: `Settings.ZoomLevels.UserEditor`
- Range: 0.7 to 3.0

---

#### 3. User Editor Edit Dialog Zoom Persistence

**Feature Location:** TrackSessions.UserEditor2.ps1, Lines 1451+

**Test Steps:**
1. Launch main application
2. Click "Users..." button to open User Editor
3. Select a user and click "Edit" (or click "Add New User")
4. Note the current form font size in edit dialog (default should be Font: 11.0)
5. Click "+" button in dialog header to zoom in (e.g., to Font: 14.3)
6. Click "Save" or "Cancel" to close dialog
7. Open another user for editing (or open same user)
8. **Expected:** Form font size should be Font: 14.3
9. Adjust zoom to different level (e.g., Font: 9.9)
10. Save/Cancel and reopen
11. **Expected:** Form font size should be Font: 9.9

**Edge Cases:**
- Test zoom with validation errors showing (does font size apply to error messages?)
- Test with external lookup fields populated (long text in small font)
- Test minimum zoom (70% = Font: 7.7)
- Test maximum zoom (200% = Font: 22.0)
- Test interaction between grid zoom and edit zoom (should be independent)

**Settings File Impact:**
- Modifies: `Settings.ZoomLevels.UserEditorEdit`
- Range: 0.7 to 2.0

---

#### 4. Splash Window Position/Size Persistence

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Lines 1504 (XAML), 1666-1684 (Load), 4502-4572 (Drag/Save)

**Test Steps:**

**Position Persistence:**
1. Launch application (splash overlay appears centered by default on first run)
2. Click and drag the splash window to the upper-left corner
3. Click "Close" button on splash
4. Close main application
5. Relaunch application
6. **Expected:** Splash window should appear in upper-left corner (where you moved it)

**Size Persistence:**
1. Launch application
2. Note splash window size (default Width: 700, Height: 400)
3. Currently splash size is fixed (no resize grip) - **Future Enhancement:** Add resize capability
4. Close splash and restart
5. **Expected:** Splash remembers size (future when resize is implemented)

**Drag Boundaries:**
1. Launch application
2. Try to drag splash outside window bounds (left/right/top/bottom)
3. **Expected:** Splash should be clamped to stay within main window
4. Resize main window to be smaller than splash position
5. Relaunch application
6. **Expected:** Splash should reposition to stay visible (clamped to new bounds)

**Edge Cases:**
- Test on multi-monitor setup (move splash to second monitor, close, reopen - should clamp to main window on primary monitor)
- Test with very small main window size
- Test with maximized main window
- Test rapid dragging (drag quickly to corners and edges)
- Test drag while window is being resized simultaneously

**Settings File Impact:**
- Modifies: `Settings.Layout.SplashLeft`, `Settings.Layout.SplashTop`, `Settings.Layout.SplashWidth`, `Settings.Layout.SplashHeight`
- Saved on every drag completion
- Saved on splash close

---

### 5. Notify Others Dialog Position/Size Persistence

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Lines 3315+ (Load), 3335+ (Save)

**Test Steps:**

**Position Persistence:**
1. Close splash screen (triggers Notify Others dialog)
2. Note default position (should be centered over main window)
3. Drag dialog to bottom-right corner of screen
4. Close dialog with "Close" button
5. Reopen dialog via "Send..." button on main toolbar
6. **Expected:** Dialog appears in bottom-right corner (where you moved it)

**Size Persistence:**
1. Open Notify Others dialog
2. Resize dialog to be wider and taller (drag edges or corners)
3. Close dialog
4. Reopen dialog
5. **Expected:** Dialog appears with the size you set

**Keep on Top Feature:**
1. Open Notify Others dialog
2. Check "Keep on Top" checkbox
3. Click on main window
4. **Expected:** Notify dialog stays on top of main window
5. Uncheck "Keep on Top"
6. Click on main window
7. **Expected:** Notify dialog can be hidden behind main window

**Edge Cases:**
- Test minimum dialog size constraints (MinWidth: 900, MinHeight: 600)
- Test position with multiple monitors
- Test with very large dialog size (e.g., 1920x1080)
- Test closing dialog with X button vs. Cancel button (both should save)
- Test closing dialog with Send Notifications button (should save before close)

**Settings File Impact:**
- Modifies: `Settings.NotifyDialog.Left`, `Settings.NotifyDialog.Top`, `Settings.NotifyDialog.Width`, `Settings.NotifyDialog.Height`
- Saved only on dialog close (not during resize)

---

### 6. Main Content Zoom Persistence

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Lines 3495+ (Save logic)

**Test Steps:**
1. Launch application
2. Note main content area font sizes (labels, values, grid)
3. Click "+" button in main toolbar (below legend)
4. **Expected:** All labels, values, and session grid text increases in size
5. Close application
6. Relaunch application
7. **Expected:** Main content zoom level persisted

**Edge Cases:**
- Test interaction with responsive layout (narrow window vs. wide window)
- Test minimum zoom (50% = 0.5x)
- Test maximum zoom (300% = 3.0x)
- Test grid scrolling with different zoom levels
- Test grid column widths with zoom (do they adapt?)

**Settings File Impact:**
- Modifies: `Settings.ZoomLevels.MainContent`
- Range: 0.5 to 3.0

---

## Cloud Services & Network Reliability Testing

### 7. Cloud Machine List Loading (3-Tier Fallback)

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Get-CloudMachines function

**Test Scenarios:**

**Tier 1: Shared Path Available**
1. Configure `Settings.MachineList.SharedPath` to valid UNC path
2. Place `TrackSessions.CloudMachines.json` on shared path with 5 machines
3. Launch application
4. **Expected:** Status bar or debug log shows "Loaded machines from: Shared Path (\\server\share\...)"
5. **Expected:** No cloud status banner appears
6. Grid should show all 5 machines from shared file

**Tier 2: Shared Path Timeout/Unavailable (Local Fallback)**
1. Configure `Settings.MachineList.SharedPath` to inaccessible UNC path (e.g., disconnected network)
2. Place `TrackSessions.CloudMachines.json` in local script directory
3. Launch application
4. **Expected:** Application waits 3 seconds for network timeout
5. **Expected:** Cloud status banner appears: "⚠ Cloud services unavailable. Using offline mode with local data."
6. **Expected:** Application loads machines from local file
7. **Expected:** "Retry" button appears in banner

**Tier 3: All Files Unavailable (Hardcoded Fallback)**
1. Configure invalid shared path
2. Delete or rename local `TrackSessions.CloudMachines.json`
3. Launch application
4. **Expected:** Cloud status banner appears
5. **Expected:** Application loads 3 hardcoded machines:
   - PAWS 66: mtb012vp0030366.ds.irsnet.gov
   - PAWS 67: mtb012vp0030367.ds.irsnet.gov
   - PAWS 68: mtb012vp0030368.ds.irsnet.gov
6. Debug log shows: "Loaded machines from: Hardcoded Defaults"

**Retry Cloud Connection:**
1. Trigger Tier 2 or Tier 3 scenario (cloud banner visible)
2. Fix network issue or restore shared path access
3. Click "Retry" button in cloud status banner
4. **Expected:** Application attempts reconnection with 5-second timeout
5. If successful: Banner shows success message or dismisses
6. If still failed: Banner updates with new error message
7. If successful: Main grid refreshes with newly loaded machines

**Dismiss Cloud Banner:**
1. Trigger cloud status banner
2. Click "✕" (Dismiss) button
3. **Expected:** Banner disappears
4. **Expected:** Application continues using fallback machines
5. **Expected:** No automatic retry (user dismissed notification)

**Edge Cases:**
- Test with very slow network (2.5 second response time - should succeed within 3s timeout)
- Test with completely offline machine (no network adapter)
- Test with corrupted CloudMachines.json (invalid JSON syntax)
- Test with empty machine list in CloudMachines.json
- Test with CloudMachines.json containing 100+ machines (performance)
- Test shared path with special characters in UNC path
- Test shared path requiring authentication (different credentials)

**Settings File Impact:**
- Reads: `Settings.MachineList.SharedPath`
- Reads: `Settings.MachineList.Mode` ("Shared" or "Local")

---

## Timestamp Format Testing

### 8. Email and Event Subject Timestamps

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Lines 2971 (Email), 3006 (Event)

**Test Steps:**

**Email Test:**
1. Open Notify Others dialog
2. Enable Email Notifications
3. Select your user
4. Click "Test Email to Me" button
5. Check Outlook inbox
6. **Expected:** Email subject format: `Test Email from Session Tracker - Fri 2026-09-20 14:35:22 Eastern Daylight Time`
7. **Expected:** Timestamp is at the END, not beginning

**Event Test:**
1. Open Notify Others dialog
2. Enable Calendar Event Creation
3. Select your user
4. Click "Test Event to Me" button
5. Check Outlook calendar
6. **Expected:** Event subject format: `Test Event from Session Tracker - Fri 2026-09-20 14:35:22 Eastern Daylight Time`
7. **Expected:** Timestamp is at the END, not beginning

**Edge Cases:**
- Test with different time zones (change system timezone and retest)
- Test during daylight saving time transition
- Test at midnight (edge case for date formatting)
- Test with very long custom message prefixes (does timestamp wrap?)

---

## Font Size Increase Testing

### 9. Notify Others Dialog Font Sizes (30% Increase)

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Lines 2584-2805

**Visual Inspection Test:**
1. Open Notify Others dialog (close splash screen)
2. Verify the following font sizes:

| Element | Expected Size | Notes |
|---------|--------------|-------|
| "Create Notifications" header | 21pt | Was 16pt |
| "Select users..." description | 16pt | Was 12pt |
| "Keep on Top" checkbox | 14pt | Was default (~11pt) |
| Tab headers (Email/Event/Teams) | 14pt | Was default |
| Enable checkboxes | 14pt | Was default |
| "Test Email to Me" button | 14pt | Was default |
| DataGrid text (user rows) | 14pt | Was default (~11pt) |
| DataGrid column headers | 32px height | Was default (~24px) |
| DataGrid rows | 28px height | Was default (~22px) |
| Status badges (Outlook/Graph) | 14pt | Was 11pt |
| Selection summary | 14pt | Was 11pt |
| "Send Notifications" button | 14pt, 180×36 | Was smaller |

3. Compare with old version screenshot if available
4. **Expected:** All text should be 30% larger (minimum 12pt, actual minimum 14pt)
5. **Expected:** Dialog should feel more readable and accessible

**Accessibility Test:**
- Test with Windows Display Scaling at 100%, 125%, 150%
- Test with high-contrast themes
- Test with screen reader (should announce larger text correctly)

**Edge Cases:**
- Test with very long user names (does text wrap or truncate?)
- Test with 50+ users in list (does scrolling still work smoothly?)
- Test with email addresses longer than 60 characters

---

## Main Window Position Persistence

### 10. Main Window Bounds Persistence

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Lines 1650-1665 (Load), Save-MainWindowBounds function

**Test Steps:**
1. Launch application in default position/size
2. Resize main window to a custom size (e.g., 1200×800)
3. Move main window to a different screen position
4. Close application
5. Relaunch application
6. **Expected:** Main window appears in the same position and size

**Edge Cases:**
- Test with multi-monitor setup (move to second monitor, disconnect second monitor, relaunch)
- Test with maximized window state
- Test with minimized window state on close
- Test with very small window size (near minimum constraints)
- Test with window partially off-screen

---

## Splitter Position Persistence

### 11. Bottom Pane Height Persistence

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Lines 1647-1649 (Load), 4668-4670 (Save on drag)

**Test Steps:**
1. Launch application
2. Note the current splitter position (between top info panel and bottom grid)
3. Drag splitter up to make bottom grid larger
4. Close application
5. Relaunch application
6. **Expected:** Splitter position persisted (bottom grid is larger)
7. Drag splitter down to make bottom grid smaller
8. Close and relaunch
9. **Expected:** New splitter position persisted

**Edge Cases:**
- Test dragging splitter to extreme positions (very top, very bottom)
- Test with minimum height constraints (can't make panels too small)
- Test rapid splitter dragging
- Test resizing window after adjusting splitter

---

## Mini Window Testing

### 12. Mini Window Position Persistence

**Feature Location:** TrackSessions.Refactor.CR2.ps1, Lines 1642-1643 (Load), Save-MiniWindowPosition function

**Test Steps:**
1. Launch application
2. Click "_" (minimize) button to show mini window
3. Note mini window appears in bottom-right corner by default
4. Drag mini window to top-left corner
5. Double-click mini window to restore main window
6. Click "_" again to minimize
7. **Expected:** Mini window appears in top-left corner (where you moved it)
8. Move mini window to a different position
9. Close application (mini window visible)
10. Relaunch application and minimize
11. **Expected:** Mini window appears in the last saved position

**Edge Cases:**
- Test mini window on second monitor (disconnect monitor, relaunch)
- Test mini window near screen edges (should clamp to work area)
- Test with taskbar on different edges (top/bottom/left/right)
- Test mini window auto-hide behavior (fades after 4 seconds)

---

## Settings Schema Migration Testing

### 13. Settings v1.0 to v1.1 Migration

**Test Steps:**

**Clean Upgrade (v1.0 → v1.1):**
1. Create a backup of current `TrackSessions.Settings.json`
2. Manually edit settings file to have `"SchemaVersion": "1.0"`
3. Remove `NotifyDialog` section (if present)
4. Remove `ZoomLevels` section (if present)
5. Remove `SplashLeft/Top/Width/Height` fields from `Layout` section
6. Save file
7. Launch application
8. **Expected:** Application loads without errors
9. **Expected:** Missing sections/fields are created with default values
10. Close application
11. Open settings file
12. **Expected:** `"SchemaVersion": "1.1"`
13. **Expected:** `NotifyDialog` section exists with null values
14. **Expected:** `ZoomLevels` section exists with 1.0 defaults
15. **Expected:** `Layout` section has `SplashLeft/Top/Width/Height` fields

**Corrupted Settings:**
1. Delete `TrackSessions.Settings.json`
2. Launch application
3. **Expected:** Application creates new settings file with schema v1.1
4. **Expected:** All default values applied

**Invalid JSON:**
1. Edit settings file to have invalid JSON (e.g., missing closing brace)
2. Launch application
3. **Expected:** Application shows error OR regenerates default settings
4. **Expected:** No crash

---

## Simulation Mode Testing

### 14. Simulation Mode with Cloud Machines

**Test Steps:**
1. Ensure 5+ machines loaded (from shared path or local)
2. Launch application
3. Check "Simulation" checkbox
4. **Expected:** Simulator adds random activity rows every 5-7 seconds
5. **Expected:** Simulated rows use machine names from loaded machine list
6. Observe grid for 30+ seconds
7. **Expected:** Rows cycle through all available machines
8. Uncheck "Simulation" checkbox
9. **Expected:** Simulation stops immediately
10. **Expected:** Simulated rows remain in grid (not cleared)

**Edge Cases:**
- Test simulation with only 1 machine loaded (fallback scenario)
- Test simulation with 100+ machines
- Test simulation while manually refreshing grid
- Test simulation while changing settings (does it continue?)

---

## Performance & Stress Testing

### 15. Large Data Volume Testing

**Session Files:**
- Test with 100+ JSON session files in output folder
- Test with JSON files larger than 1MB each
- Test with corrupted JSON files mixed in with valid files
- Test with very old session files (timestamps from years ago)

**User List:**
- Test with 100+ users in Users.json
- Test with users having very long names (100+ characters)
- Test with users having special characters in SEID (unicode, emoji)

**Machine List:**
- Test with 200+ machines in CloudMachines.json
- Test with machine names containing special characters
- Test with duplicate machine FQDNs

**Activity Grid:**
- Test with 500+ rows in activity grid (scroll performance)
- Test sorting by each column with large dataset
- Test filtering/searching with large dataset

---

## Integration Testing

### 16. Outlook Integration

**Email Notifications:**
1. Ensure Outlook is running and logged in
2. Test sending email to single user
3. Test sending email to 10+ users
4. Test sending email when Outlook is closed (should auto-launch?)
5. Test with Outlook in offline mode

**Calendar Events:**
1. Test creating event for single user
2. Test creating events for multiple users
3. Test event date/time formatting
4. Test recurring events (if supported)

---

## Error Handling Testing

### 17. Network Timeout Scenarios

**Slow Network:**
1. Use network simulator to add 2.5 second latency
2. Launch application
3. **Expected:** Loads within 3-second timeout (should succeed)

**Very Slow Network:**
1. Add 5 second latency
2. Launch application
3. **Expected:** Times out after 3 seconds, falls back to local file

**Intermittent Network:**
1. Configure shared path
2. Launch application (loads from shared path)
3. Disconnect network
4. Click "Retry" button
5. **Expected:** Times out, shows error
6. Reconnect network
7. Click "Retry" again
8. **Expected:** Succeeds, loads from shared path

---

## UI/UX Testing

### 18. Responsive Layout Testing

**Window Width Changes:**
1. Launch application in wide window (1200px+)
2. **Expected:** Labels and values in side-by-side layout
3. Resize window to narrow (< 620px)
4. **Expected:** Labels and values stack vertically
5. Resize back to wide
6. **Expected:** Layout returns to side-by-side

**Zoom + Responsive:**
1. Set main content zoom to 200%
2. Resize window to narrow
3. **Expected:** Stacked layout still readable with large fonts
4. **Expected:** No text overflow or clipping

---

## Accessibility Testing

### 19. Keyboard Navigation

1. Launch application
2. Press Tab repeatedly
3. **Expected:** Focus moves through all interactive elements in logical order
4. Press Shift+Tab
5. **Expected:** Focus moves backward
6. Press Enter on focused button
7. **Expected:** Button action triggers
8. Press Escape in dialog
9. **Expected:** Dialog closes (if applicable)

### 20. Screen Reader Testing

1. Enable Windows Narrator
2. Launch application
3. Navigate through UI with keyboard
4. **Expected:** All labels, buttons, and controls are announced
5. **Expected:** Tooltips are read when focused
6. **Expected:** Grid columns and rows are navigable

---

## Security Testing

### 21. Settings File Validation

1. Edit settings file with malicious values:
   - Very large zoom levels (e.g., 999999.0)
   - Negative window positions (e.g., -5000)
   - Invalid data types (strings instead of numbers)
2. Launch application
3. **Expected:** Invalid values are clamped or ignored
4. **Expected:** No crash or code execution

### 22. JSON Injection Testing

1. Edit Users.json with script injection attempts:
   - `<script>alert('xss')</script>` in name fields
   - PowerShell command strings in SEID field
2. Launch application and view Users
3. **Expected:** Malicious content rendered as plain text
4. **Expected:** No script execution

---

## Regression Testing Checklist

After any code change, verify these core functions still work:

- [ ] Application launches without errors
- [ ] Main grid populates with session data
- [ ] Refresh button updates grid
- [ ] Settings dialog opens and saves
- [ ] Users dialog opens and saves
- [ ] Log viewer opens and displays messages
- [ ] Notify Others dialog opens and sends test messages
- [ ] Simulation mode adds rows
- [ ] Mini window minimizes and restores
- [ ] Zoom buttons work in all contexts
- [ ] All persistence features save and load correctly
- [ ] Cloud retry button works
- [ ] Application closes cleanly (no orphaned processes)

---

## Future Testing Considerations

### Features Not Yet Implemented:
- Splash window resize capability (currently fixed size)
- Microsoft Teams notifications (placeholder)
- Active Directory lookup integration
- Microsoft Graph API integration
- Machine reservation dialog functionality
- File system watcher (currently disabled)

### Recommended Additions:
- Automated unit tests for core functions
- Integration tests for Outlook COM automation
- Performance benchmarks for grid rendering
- Memory leak testing (long-running sessions)
- Multi-user concurrent access testing (shared UNC path)

---

## Bug Reporting Template

When reporting issues, include:

```
**Issue Title:** [Brief description]

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Behavior:**

**Actual Behavior:**

**Environment:**
- Windows Version: 
- PowerShell Version: 
- Settings Schema Version: 
- Cloud Machine Source: [Shared/Local/Hardcoded]

**Settings File Snippet:**
```json
{
  "SchemaVersion": "1.1",
  ...
}
```

**Debug Log Excerpt:**
```
[14:35:22.123] ...
```

**Screenshots:**
[Attach if applicable]
```

---

**End of Testing Document**
