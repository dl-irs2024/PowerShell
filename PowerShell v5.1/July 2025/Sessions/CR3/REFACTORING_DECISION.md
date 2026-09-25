# Refactoring Decision - CR2 Reverted to CR1

## Summary
After 6+ hours of refactoring, the modular structure (**CR2**) introduced critical scope issues that broke all dialog functionality. **CR1** has been restored as the working baseline.

---

## What Happened

### CR2 Refactor (Failed ❌)
Split application into modules:
- `TrackSessions.Core.psm1` - Settings/IO
- `TrackSessions.Notifications.psm1` - Message boxes
- `TrackSessions.UI.psm1` - Utility functions
- `TrackSessions.Dialogs.psm1` - Dialog implementations

**Result**: PowerShell module scope isolation prevented dialog functions from being accessible in button click handler scriptblocks.

**Errors Encountered**:
```
Settings Error: "Cannot set Visibility or call Show, ShowDialog..."
About Error: "The term 'Show-AboutDialog' is not recognized as the name of a cmdlet..."
Log Viewer Error: "The term 'Show-LogViewerDialog' is not recognized..."
Users Error: "The term 'Show-UsersDialog' is not recognized..."
Reservations Error: "The term 'Show-ReservationsDialog' is not recognized..."
```

### CR1 (Restored ✅)
Everything inline, no module scope issues. All 5 dialogs functional.

---

## Files & Status

| File | Status | Use For |
|------|--------|---------|
| **TrackSessions.Main.ps1** | ✅ WORKING | **USE THIS** - Main application |
| TrackSessions.Simulator CR1.ps1 | ✅ Same as Main | Reference/backup |
| Sessions/CR2/ | ❌ BROKEN | Archive only |
| Sessions/CR2/TrackSessions.CR2.Main.BROKEN.ps1 | ❌ Broken backup | Reference |

---

## What Works (CR1/Main)

✅ Main window displays correctly  
✅ Settings dialog (DataGrid, zoom, UNC paths)  
✅ About dialog (system info, 9 tabs)  
✅ Log Viewer dialog (trace logs with search/filter)  
✅ Users dialog (user management)  
✅ Reservations dialog (calendar view)  
✅ JSON persistence  
✅ Session tracking  
✅ All button handlers functional  

---

## Path Forward

### DO NOT
- ❌ Refactor into modules without incremental testing
- ❌ Use PowerShell modules for WPF dialog code
- ❌ Major refactoring without backups

### DO
- ✅ Keep dialog code inline (no modules)
- ✅ Test incrementally after each change
- ✅ Add features to CR1 without refactoring structure
- ✅ Use version control branches for experimental changes

---

## How to Run

```powershell
cd 'Sessions'
. './TrackSessions.Main.ps1'
```

## Lesson Learned

**PowerShell module scope isolation** is problematic for WPF applications where event handlers need to call functions. In PowerShell:

- ❌ Click handlers can't access module-exported functions reliably
- ✅ Inline code works perfectly
- ✅ Dot-sourcing works (but not as clean)

For future refactoring: Keep WPF dialog code inline, or use proper scope qualification.

---

## What's Preserved

All the hours of work aren't lost:
- CR2 contains the architecture/design (reference)
- Lesson learned about PowerShell + WPF scope
- Working dialogs (can be copied back if needed)
- CR2 backup saved for reference

**But**: CR1 (inline) is the stable, working version to build from.
