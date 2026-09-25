# TrackSessions README

## Highlights
- PowerShell 5.1 WPF tooling for session tracking, simulation, and user editing.
- Main active editor flow: `TrackSessions.UserEditor.ps1` plus SEID lookup CLI companion.
- Current parser health: all discovered `.ps1` files in this folder tree parse successfully.
- Repository contains active scripts, docs, simulator variants, backups/copies, and shortcut files.

## Folder Coverage
This document covers all files currently under:
- `Sessions\`
- `Sessions\Sessions - PAWS\`

Inventory timestamp: 2026-09-08

## Status Legend
- Implemented: In place and currently usable.
- Unfinished: Usable foundation, but expected follow-up work exists.
- Legacy/Archive: Older copy, backup, or snapshot retained for reference.
- Broken: Known failing behavior verified by parser/runtime checks.

## Quick Usage
### 1) User Editor (WPF)
```powershell
Set-Location "c:\Users\YMJNB\OneDrive - Internal Revenue Service\Documents\PowerShell 2025\PowerShell v5.1\July 2025\Sessions"
.\TrackSessions.UserEditor.ps1
```

### 2) SEID Lookup CLI
```powershell
Set-Location "c:\Users\YMJNB\OneDrive - Internal Revenue Service\Documents\PowerShell 2025\PowerShell v5.1\July 2025\Sessions"
.\TrackSessions.UserEditor.Lookup-SEID.CLI.ps1 -SEID ABCD123
.\TrackSessions.UserEditor.Lookup-SEID.CLI.ps1 -SEID abcd123 -AsJson
```

### 3) Main Session Tracker (WPF)
```powershell
Set-Location "c:\Users\YMJNB\OneDrive - Internal Revenue Service\Documents\PowerShell 2025\PowerShell v5.1\July 2025\Sessions"
.\TrackSessions.ps1
```

### 4) Simulator (CR1)
```powershell
Set-Location "c:\Users\YMJNB\OneDrive - Internal Revenue Service\Documents\PowerShell 2025\PowerShell v5.1\July 2025\Sessions"
.\TrackSessions.Simulator CR1.ps1
```

## Implementation Health Snapshot
| Area | State | Notes |
| --- | --- | --- |
| User Editor (`TrackSessions.UserEditor.ps1`) | Implemented | WPF editor, local/external lookup flow, strict-mode-safe updates from recent session work. |
| SEID Lookup CLI (`TrackSessions.UserEditor.Lookup-SEID.CLI.ps1`) | Implemented | Local-first + CSV/AD/Graph fallback, object + JSON output. |
| Session Tracker (`TrackSessions.ps1`) | Implemented | Core WPF tracking flow present; historical change log captured in docs. |
| Simulator (`TrackSessions.Simulator CR1.ps1`) | Implemented | Latest simulator variant in this folder. |
| Documentation set | Implemented | Multiple markdown logs/plans/explain files in place. |
| Runtime hardening and feature backlog | Unfinished | See "Unfinished Work" section. |
| Known parser breakages | Broken: None found | Recursive parser scan on 2026-09-08 returned Parse OK for all `.ps1` files discovered. |

## File Catalog (Top Level)
| File | Type | Purpose | Status |
| --- | --- | --- | --- |
| `JenniferPowerShell.August2026.ps1` | Script | Standalone PowerShell utility script (general session tooling). | Implemented |
| `SettingsSecurityModel.md` | Doc | Security/settings model notes for session tooling. | Implemented |
| `TrackSessions - Copy (2).BeforeDialog.ps1` | Script (copy) | Pre-dialog historical snapshot of TrackSessions script. | Legacy/Archive |
| `TrackSessions - Copy (2).ps1` | Script (copy) | Historical duplicate copy. | Legacy/Archive |
| `TrackSessions - Copy (3).ps1` | Script (copy) | Historical duplicate copy. | Legacy/Archive |
| `TrackSessions - Copy.ps1` | Script (copy) | Early historical copy. | Legacy/Archive |
| `TrackSessions.Chat.md` | Doc | Compact chat/output summary and change log. | Implemented |
| `TrackSessions.DEMO.Aug2026.ps1` | Script | Demo variant of TrackSessions workflow. | Implemented |
| `TrackSessions.md` | Doc | Primary TrackSessions change summary documentation. | Implemented |
| `TrackSessions.Prompts.md` | Doc | Prompt/workflow notes for iterative development. | Implemented |
| `TrackSessions.ps1` | Script | Main WPF TrackSessions application. | Implemented |
| `TrackSessions.ps1.txt` | Text snapshot | Text export/copy of TrackSessions script. | Legacy/Archive |
| `TrackSessions.ReadMe.md` | Doc | This folder-level README and status matrix. | Implemented |
| `TrackSessions.Settings.json` | Config | Main settings data for TrackSessions flows. | Implemented |
| `TrackSessions.Simulator CR1 - Copy.ps1.txt` | Text snapshot | Text snapshot of simulator variant. | Legacy/Archive |
| `TrackSessions.Simulator CR1.ps1` | Script | Current CR1 simulator script. | Implemented |
| `TrackSessions.Simulator.ps1` | Script | Simulator baseline variant. | Implemented |
| `TrackSessions.Simulator.ps1.txt` | Text snapshot | Text snapshot of simulator baseline. | Legacy/Archive |
| `TrackSessions.UserEditor.Chat.md` | Doc | User editor conversation log and updates. | Implemented |
| `TrackSessions.UserEditor.Lookup-SEID.CLI.md` | Doc | Plan and implementation notes for CLI lookup. | Implemented |
| `TrackSessions.UserEditor.Lookup-SEID.CLI.ps1` | Script | CLI SEID resolver mirroring editor lookup chain. | Implemented |
| `TrackSessions.UserEditor.Lookup.Explain.md` | Doc | Detailed lookup behavior explanation. | Implemented |
| `TrackSessions.UserEditor.ps1` | Script | WPF user editor and lookup-enabled workflow. | Implemented |
| `TrackSessions.Users.json` | Data | User data store for editor and CLI local lookup. | Implemented |
| `Vp0wxsqm365as02 - Shortcut.lnk` | Shortcut | Local convenience shortcut file. | Implemented |

## File Catalog (Sub-Folder: Sessions - PAWS)
| File | Type | Purpose | Status |
| --- | --- | --- | --- |
| `Sessions - PAWS\TrackSessions.md` | Doc | PAWS subfolder copy of TrackSessions documentation. | Legacy/Archive |
| `Sessions - PAWS\TrackSessions.ps1` | Script | PAWS-specific copy/variant of TrackSessions app. | Implemented |
| `Sessions - PAWS\TrackSessions.Settings.json` | Config | PAWS-specific settings file. | Implemented |
| `Sessions - PAWS\Vp0wxsqm365as02 - Shortcut.lnk` | Shortcut | PAWS subfolder shortcut file. | Implemented |

## What Is Implemented
- WPF session tracking workflow (`TrackSessions.ps1`) with persisted settings.
- User editor workflow (`TrackSessions.UserEditor.ps1`) with local data and external lookup logic.
- Dedicated CLI SEID resolver (`TrackSessions.UserEditor.Lookup-SEID.CLI.ps1`) with `-AsJson` support.
- Simulator scripts for testing/validation scenarios.
- Supporting docs capturing changes, prompts, and lookup behavior.

## What Is Broken
- No parser-level breakages detected in current `.ps1` inventory.
- No active broken file has been confirmed in this scan.

## What Is Unfinished
- CLI enhancements documented but not yet implemented:
  - Provider skip switches (`-SkipCsv`, `-SkipAD`, `-SkipGraph`).
  - Explicit non-zero exit code for not-found lookups.
  - Optional email-based lookup mode for full editor parity.
- Repository cleanup remains pending:
  - Consolidate/archive duplicate `TrackSessions - Copy*` variants.
  - Clarify ownership of `.txt` script snapshots versus active `.ps1` files.

## Validation Notes
Parser health command used during this inventory:
```powershell
Set-Location "c:\Users\YMJNB\OneDrive - Internal Revenue Service\Documents\PowerShell 2025\PowerShell v5.1\July 2025\Sessions"
$files = Get-ChildItem -Recurse -File -Include *.ps1
$results = foreach ($f in $files) {
    $errors = $null; $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    [pscustomobject]@{
        Path = $f.FullName
        ParseOk = (-not $errors -or $errors.Count -eq 0)
        ErrorCount = if ($errors) { $errors.Count } else { 0 }
    }
}
$results | Sort-Object Path | Format-Table -AutoSize
```

## Recommended Next Maintenance Step
- Keep this README updated whenever a new script variant or major status change is introduced, especially for active vs legacy copy files.
