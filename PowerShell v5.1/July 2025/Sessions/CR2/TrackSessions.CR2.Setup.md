# TrackSessions CR2 - Self-Contained Setup

**Date**: 2026-09-20  
**Purpose**: Make TrackSessions.Refactor.CR2.ps1 fully self-contained without dependencies on parent or sibling folders

## Files Copied to CR2 Folder

All dependencies have been copied from the parent `Sessions\` folder into `Sessions\CR2\` to make this version independent.

### Core Dependencies

1. **TrackSessions.Settings.json** (43 KB)
   - Configuration file containing tracked machines, paths, and UI settings
   - SharedPath: `\\Vp0wxsqm365as02\SPS\PAWS-Sessions\TestSimulate`
   - Already existed in CR2 folder

2. **TrackSessions.Users.json** (4 KB)
   - User database with SEID, names, email addresses
   - Used by User Editor and Reservations dialogs
   - Already existed in CR2 folder

### User Management Module

3. **TrackSessions.UserEditor.ps1** (67 KB)
   - WPF dialog for managing user records
   - Referenced by "Manage Users" button (line 2886 of main script)
   - Copied from parent folder

### Reservations Module

4. **TrackSessions.Reservations.CalendarDialog.ps1** (30 KB)
   - WPF calendar dialog for managing reservations
   - Referenced by "Reservations" button (lines 2901-2902 of main script)
   - Copied from parent folder

5. **TrackSessions.Reservations.psm1** (34 KB)
   - PowerShell module with reservation CRUD functions
   - Imported by CalendarDialog.ps1 (line 25)
   - Functions: `Get-ReservationSettings`, `Get-UserDatabase`, `New-Reservation`, `Update-Reservation`, `Cancel-Reservation`, `Get-Reservations`
   - Copied from parent folder

6. **TrackSessions.Reservations.Schema.json** (6.4 KB)
   - JSON schema for reservation data validation
   - Referenced by Reservations module
   - Copied from parent folder

### Subfolder Structure

7. **Reservations/** (subfolder)
   - Created for storing reservation JSON files
   - Default path when ReservationPath not specified in Settings.json
   - Empty folder ready for use

## Folder Structure

```
Sessions\CR2\
├── TrackSessions.Refactor.CR2.ps1         (main script)
├── TrackSessions.Settings.json             (configuration)
├── TrackSessions.Users.json                (user database)
├── TrackSessions.UserEditor.ps1            (user dialog)
├── TrackSessions.Reservations.CalendarDialog.ps1
├── TrackSessions.Reservations.psm1         (module)
├── TrackSessions.Reservations.Schema.json  (schema)
└── Reservations\                           (data folder)
```

## Script References

### User Editor Button (Line 2886)
```powershell
& "$PSScriptRoot\TrackSessions.UserEditor.ps1"
```
✅ Resolves to: `Sessions\CR2\TrackSessions.UserEditor.ps1`

### Reservations Button (Lines 2901-2902)
```powershell
$dialogCandidates = @(
    (Join-Path $PSScriptRoot 'TrackSessions.Reservations.CalendarDialog.ps1')
    (Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Reservations.CalendarDialog.ps1')
) | Select-Object -Unique
```
✅ Resolves to: `Sessions\CR2\TrackSessions.Reservations.CalendarDialog.ps1`

### Module Import (CalendarDialog.ps1 Line 25)
```powershell
$reservationModulePath = Join-Path $modulePath 'TrackSessions.Reservations.psm1'
```
✅ Resolves to: `Sessions\CR2\TrackSessions.Reservations.psm1`

## Verification Checklist

- ✅ All scripts reference `$PSScriptRoot` which resolves to CR2 folder
- ✅ Settings.json exists in CR2 folder
- ✅ Users.json exists in CR2 folder
- ✅ UserEditor.ps1 exists in CR2 folder
- ✅ CalendarDialog.ps1 exists in CR2 folder
- ✅ Reservations.psm1 module exists in CR2 folder
- ✅ Reservations.Schema.json exists in CR2 folder
- ✅ Reservations subfolder created for data storage
- ✅ No dependencies on parent `Sessions\` folder
- ✅ No dependencies on sibling folders

## Running the Script

From PowerShell, run:
```powershell
cd "C:\Users\YMJNB\OneDrive - Internal Revenue Service\Documents\PowerShell 2025\PowerShell v5.1\July 2025\Sessions\CR2"
.\TrackSessions.Refactor.CR2.ps1
```

All dependencies are now self-contained within the CR2 folder!

## Notes

- **SharedPath** in Settings.json points to network UNC path: `\\Vp0wxsqm365as02\SPS\PAWS-Sessions\TestSimulate`
- **ReservationPath** not yet configured in Settings.json, will default to `Reservations\` subfolder
- **User database** contains user records that can be edited via "Manage Users" button
- **Settings dialog** is built into main script (function at line 1842), no external file needed
