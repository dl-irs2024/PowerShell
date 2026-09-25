# CompressSafeZip and CompressSafeZip.Wpf

## Overview
This package provides two workflows:

1. Forward operation (Create Safe Zip)
- Compress files from a folder into a zip archive.
- Inside the zip, script-like files are made safer by appending .txt:
  - file.ps1 becomes file.ps1.txt
  - file.cmd becomes file.cmd.txt
  - file.vbs becomes file.vbs.txt
  - file.vmbs becomes file.vmbs.txt

2. Inverse operation (Unzip and Restore)
- Extract a safe zip to a destination folder.
- Restore script-like extensions by removing trailing .txt:
  - file.ps1.txt becomes file.ps1
  - file.cmd.txt becomes file.cmd
  - file.vbs.txt becomes file.vbs
  - file.vmbs.txt becomes file.vmbs
- After restore, files are unblocked using Unblock-File.

Both scripts target Windows PowerShell 5.1.

## Files
- CompressSafeZip.ps1
- CompressSafeZip.Wpf.ps1
- CompressSafeZip.Wpf.Settings.json
- Logs folder (created automatically by the WPF app when operations run)

## Main Script: CompressSafeZip.ps1
Supports two parameter sets.

### Compress mode
Parameters:
- SourcePath (aliases: FolderPath, Folder, Path)
- OutputZipPath
- Recurse
- WhatIf

Behavior:
- Builds a safe zip from SourcePath.
- Skips zipping the output zip itself.
- Uses staging to rename script-like extensions to .txt-suffixed names.

### Expand mode
Parameters:
- ZipPath (alias: InputZip)
- DestinationPath (alias: OutputFolder)
- WhatIf

Behavior:
- Extracts archive to temporary folder.
- Restores script-like extensions from .txt-suffixed names.
- Writes restored files to DestinationPath.
- Runs Unblock-File on restored output files.

### WhatIf support
- Built using SupportsShouldProcess.
- Works for both Compress and Expand modes.

## WPF App: CompressSafeZip.Wpf.ps1
The WPF app provides two sections:

1. Create Safe Zip section
- Source folder
- Output zip
- Auto Name
- Recurse
- Open output folder after success
- Create Safe Zip button

2. Unzip and Restore (Inverse Operation) section
- Input safe zip
- Destination folder
- Auto Name
- Open destination folder after success
- Unzip and Restore button

Shared option:
- WhatIf checkbox

### Tooltips and screen tips
Screen tips are provided across key controls, with special focus on Auto Name:
- Zip Auto Name explains it generates a timestamped safe zip path from Source folder and overwrites the output field.
- Unzip Auto Name explains it generates a timestamped restore destination from input zip and overwrites the destination field.

## Logging
The WPF app writes a log for each run.

### Log location
- Logs are written under:
  - Logs
- File naming pattern:
  - zip.YYYYMMDD-HHMMSS.log.txt
  - unzip-restore.YYYYMMDD-HHMMSS.log.txt

### Log content
Each log includes:
- Timestamp
- Operation name
- Parameters used
- Result (SUCCESS or FAILED)
- Output/error stream content

### Log viewer UI
- Log Output button is available in the WPF app.
- Opens a log dialog with:
  - Full text log content
  - Log path display
  - Open Log Folder button
  - Close button

## Settings
Settings are stored in:
- CompressSafeZip.Wpf.Settings.json

Saved fields include:
- SourcePath
- OutputZipPath
- Recurse
- OpenOutputFolder
- UnzipZipPath
- UnzipDestinationPath
- OpenUnzipFolder
- WhatIf
- LastLogPath
- WindowLeft
- WindowTop
- WindowWidth
- WindowHeight

Window size and location are restored on startup.

## Usage Examples

### CLI: create safe zip in current folder
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CompressSafeZip.ps1

### CLI: create safe zip from a selected folder with recurse
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CompressSafeZip.ps1 -FolderPath C:\Data\MyFolder -OutputZipPath C:\Data\MyFolder.safe.zip -Recurse

### CLI: preview create safe zip (no changes)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CompressSafeZip.ps1 -FolderPath C:\Data\MyFolder -OutputZipPath C:\Data\MyFolder.safe.zip -WhatIf

### CLI: unzip and restore to destination
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CompressSafeZip.ps1 -ZipPath C:\Data\MyFolder.safe.zip -DestinationPath C:\Data\MyFolder.Restored

### CLI: preview unzip and restore (no changes)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CompressSafeZip.ps1 -ZipPath C:\Data\MyFolder.safe.zip -DestinationPath C:\Data\MyFolder.Restored -WhatIf

### WPF app
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CompressSafeZip.Wpf.ps1

## Change Summary (All Implemented)
- Added safe zip creation for script-like files with .txt suffixing.
- Added folder-path aliases for compress input.
- Added SupportsShouldProcess and WhatIf support.
- Added inverse unzip/restore operation in CLI.
- Added Unblock-File during restore.
- Added WPF UI for both forward and inverse operations.
- Added broad screen tips, especially for Auto Name controls.
- Added persistent settings including window geometry.
- Added per-run logging, persisted LastLogPath, Log Output button, and log dialog viewer.

## Possible Errors and Troubleshooting

### Error: SourcePath folder not found
Symptom:
- SourcePath folder not found: <path>

Cause:
- Invalid folder path or no access.

Fix:
- Confirm path exists.
- Use Browse button in WPF.
- Run shell with permissions needed.

### Error: ZipPath file not found
Symptom:
- ZipPath file not found: <path>

Cause:
- Input zip path is wrong or file moved.

Fix:
- Verify file exists.
- Select zip with Browse in Unzip section.

### Error: TrimChars conversion during Auto Name
Symptom:
- Cannot convert argument trimChars...

Cause:
- Path-trim code used invalid trim argument type.

Fix:
- Script now uses single-character trim arguments in path normalization.

### Error: File is blocked by Windows
Symptom:
- Script execution prompts or security warning.

Cause:
- Mark-of-the-web on downloaded files.

Fix:
- Inverse restore now calls Unblock-File on output files.
- If needed, run Unblock-File manually on target files.

### WhatIf shows actions but no output files
Symptom:
- Operation appears to run but no files are created.

Cause:
- WhatIf is enabled.

Fix:
- Uncheck WhatIf in WPF or remove -WhatIf from CLI.

### Log Output says no log yet
Symptom:
- No log file found yet.

Cause:
- No zip/unzip run has completed in current session/settings.

Fix:
- Run Create Safe Zip or Unzip and Restore once.
- Then click Log Output.

## Notes
- The safe extension list is currently fixed to: .ps1, .cmd, .vbs, .vmbs.
- Compression and extraction use temporary staging folders and clean them up automatically.
- If operation fails, review the latest log under the Logs folder.
