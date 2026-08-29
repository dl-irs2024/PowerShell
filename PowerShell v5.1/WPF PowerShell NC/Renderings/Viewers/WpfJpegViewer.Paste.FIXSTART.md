# WpfJpegViewer Startup Fix Documentation

## Problem Identified
**File:** WpfJpegViewer.BrokenStartup.PasteDialog.BROKEN.ps1  
**Symptom:** Main window never displays; only modeless dialogs (splash About + Debug window) appear

## Root Cause
**Line 3088:** `Show-AboutDialog -Owner $window -AutoCloseSeconds 5`

This line calls the splash dialog **BEFORE** `$window.ShowDialog()` (line 3135).

When `Show-AboutDialog` is called with `-AutoCloseSeconds`, it:
1. Creates a modeless window using `.Show()` (not `.ShowDialog()`)
2. Starts a dispatcher timer
3. Returns immediately **without blocking**

The problem sequence:
1. Line 3088: About dialog opens modeless, returns immediately
2. Line 3135: Main window tries to show via `ShowDialog()`
3. **But** the window was already manipulated before entering its message loop
4. The debug window (line 3046) also opens modeless via `$debugWindow.Show()`
5. Result: Main window's ShowDialog() fails to display properly

## Working Version Analysis
**File:** WpfJpegViewer.NoPaste.DEMO.ps1  
**Line 2243:** Same `Show-AboutDialog -Owner $window -AutoCloseSeconds 5`  
**Line 2289:** Same `[void]$window.ShowDialog()`

**Key difference:** The DEMO version doesn't have the paste functionality, but the critical difference is timing or window initialization state.

## Additional Issues Found
1. **Debug window auto-show:** Line 3046 in SourceInitialized event shows debug window automatically
2. **Window activation timing:** Lines 3067-3069 try to activate window in Loaded event, which may conflict

## Fix Approaches

### Approach 1: Defer Splash Until After Main Window Shows (RECOMMENDED)
Move the splash dialog call to **after** the window is shown:
- Use `$window.Add_ContentRendered()` event
- Or use `$window.Dispatcher.BeginInvoke()` with low priority after ShowDialog

**Pros:** Guaranteed main window displays first  
**Cons:** Brief delay before splash appears

### Approach 2: Make Splash Truly Async
Keep splash before ShowDialog, but ensure it doesn't interfere:
- Remove the Owner relationship during splash
- Use `$window.Dispatcher.BeginInvoke()` to delay splash slightly

**Pros:** Splash can appear during initialization  
**Cons:** More complex timing coordination

### Approach 3: Remove Auto-Show Debug Window
Remove line 3046 `$debugWindow.Show()` from SourceInitialized:
- Only show debug via button click
- Reduces startup window confusion

**Pros:** Simpler startup, fewer windows  
**Cons:** Loses auto-debug feature

### Approach 4: Block Until Main Window Visible
Add explicit wait for main window before splash:
```powershell
$window.Show()  # Non-modal first
$window.UpdateLayout()
$window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Loaded)
Show-AboutDialog -Owner $window -AutoCloseSeconds 5
$window.ShowDialog()  # Now modal
```

**Pros:** Full control over timing  
**Cons:** Complex double-show pattern

## Implementation Plan

### Phase 1: Critical Fix
1. Move `Show-AboutDialog` call to `$window.Add_ContentRendered()` event
2. Comment out auto-show debug window (line 3046)
3. Test startup with no files loaded
4. Test startup with command-line file
5. Test startup with restored session files

### Phase 2: Refinement
1. Add configurable option for splash auto-display
2. Add configurable option for debug window auto-display
3. Test on multi-monitor setups
4. Test window positioning edge cases

### Phase 3: Enhancement
1. Add splash progress indicator for slow file loads
2. Add startup performance metrics
3. Consider async file loading during splash
4. Add error recovery for splash dialog failures

## Test Scenarios
- [ ] Fresh start (no settings file)
- [ ] Start with no parameters
- [ ] Start with single file parameter
- [ ] Start with folder parameter
- [ ] Start with restored session (LastFiles populated)
- [ ] Start minimized (if supported)
- [ ] Start on secondary monitor
- [ ] Start with debug window already visible
- [ ] Start with paste dialog invoked immediately

## Results Log

### Attempt 1: 2026-08-27 Initial Fix
**Approach:** #1 (Defer Splash Until After Main Window Shows)  
**Changes:**
1. Removed auto-show debug window from SourceInitialized (line 3045-3047)
2. Removed pre-ShowDialog splash call (line 3088)
3. Added ContentRendered event handler with deferred splash
4. Used Dispatcher.BeginInvoke with Background priority to show splash after main window renders

**Key Code Changes:**
```powershell
# In SourceInitialized: Commented out debug window auto-show
# REMOVED AUTO-SHOW: This was interfering with main window startup
# if (-not $debugWindow.IsVisible) {
# 	[void]$debugWindow.Show()
# }

# Before ShowDialog: Removed splash call
# REMOVED: Splash dialog moved to ContentRendered event to fix startup
# Show-AboutDialog -Owner $window -AutoCloseSeconds 5

# New ContentRendered event: Show splash AFTER main window renders
$window.Add_ContentRendered({
	$window.Dispatcher.BeginInvoke([Action]{
		Show-AboutDialog -Owner $window -AutoCloseSeconds 5
	}, [System.Windows.Threading.DispatcherPriority]::Background)
})
```

**Outcome:** READY FOR TESTING  
**Expected:** Main window displays first, then splash appears briefly  
**Notes:** Debug window auto-show is now optional (commented out code provided)

## References
- WPF Window Lifetime Events: SourceInitialized → Activated → Loaded → ContentRendered
- ShowDialog() blocks until window closes
- Show() returns immediately (modeless)
- Owner relationship requires owner window to be shown first

## Summary of Changes in WpfJpegViewer.Paste.FIXSTART.ps1

### Line 3045-3050 (SourceInitialized event)
**Before:**
```powershell
if (-not $debugWindow.IsVisible) {
	[void]$debugWindow.Show()
}
```

**After:**
```powershell
# REMOVED AUTO-SHOW: This was interfering with main window startup
# if (-not $debugWindow.IsVisible) {
# 	[void]$debugWindow.Show()
# }
```

### Line 3088 (before ShowDialog)
**Before:**
```powershell
Show-AboutDialog -Owner $window -AutoCloseSeconds 5
```

**After:**
```powershell
# REMOVED: Splash dialog moved to ContentRendered event to fix startup
# Show-AboutDialog -Owner $window -AutoCloseSeconds 5
```

### Lines 3073-3093 (NEW: ContentRendered event)
**Added:**
```powershell
# CRITICAL FIX: Defer splash and debug window to ContentRendered event
# This ensures main window is fully rendered before showing modeless dialogs
$window.Add_ContentRendered({
	try {
		# Show splash dialog AFTER main window is rendered
		$window.Dispatcher.BeginInvoke([Action]{
			try {
				Show-AboutDialog -Owner $window -AutoCloseSeconds 5
			} catch {
				$txtStatus.Text = "Splash dialog error: $($_.Exception.Message)"
			}
		}, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null

		# Optional debug window auto-show (commented out)
	} catch {
		$txtStatus.Text = "ContentRendered error: $($_.Exception.Message)"
	}
})
```

## Testing Instructions

1. **Run the fixed script:**
   ```powershell
   .\WpfJpegViewer.Paste.FIXSTART.ps1
   ```

2. **Expected behavior:**
   - Main window appears centered on screen
   - ~1 second later, splash About dialog appears
   - Splash auto-closes after 5 seconds (or on click)
   - Main window remains visible throughout
   - No debug window auto-shows (must click "Show Debug" button)

3. **Test scenarios:**
   - Fresh start (no settings)
   - With saved files (restart after loading images)
   - With command-line parameter
   - Click Paste button to verify paste functionality still works
   - Multi-monitor setup (if available)

## Related Files
- WpfJpegViewer.BrokenStartup.PasteDialog.BROKEN.ps1 (broken)
- WpfJpegViewer.NoPaste.DEMO.ps1 (working)
- WpfJpegViewer.ps1 (original/reference)
- WpfJpegViewer.Paste.FIXSTART.ps1 (this fix)
- WpfJpegViewer.Paste.FIXSTART.md (this document)
