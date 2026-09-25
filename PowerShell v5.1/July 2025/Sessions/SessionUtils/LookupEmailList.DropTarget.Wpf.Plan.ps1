# SessionUtils Plan: LookupEmailList.DropTarget.Wpf.ps1 - Outlook Email Resolver

## TL;DR

Build a PowerShell 5.1 WPF utility that accepts drag-dropped .msg files or pasted email text, extracts recipient email addresses, resolves them against Outlook's Global Address List (with fallback to local Contacts and ADSI), and displays user profile data in a DataGrid. Includes status bar showing Outlook legacy version detection, settings persistence for window position and lookup history.

**Key architecture**: Two-file solution — `EmailLookup.psm1` (reusable COM module) + `LookupEmailList.DropTarget.Wpf.ps1` (WPF UI wrapper).

---

## Requirements Summary

**Input Sources**:
- Drag-drop .msg email files or .eml format files
- Paste raw email text (extracted recipient list, CC, BCC fields from Outlook)

**Data Source** (fallback chain):
1. Outlook Global Address List (GAL) via Exchange Server
2. Outlook local Contacts folder
3. Active Directory LDAP via ADSI (offline/no Exchange)

**Output Properties** (DataGrid columns):
- Display Name, Email Address (guaranteed)
- SEID / User ID, Title, Department, Office Location
- Street Address, State, Zip Code, Time Zone, Area Code
- Manager Name, Manager Email, Manager Time Zone
- Desk Phone, Mobile Phone
- Out-of-Office Status (Yes/No + message)
- User Presence Status (Available, Busy, etc.)
- Teams Chat URL / User Profile Link
- Any other available contact properties

**UI Features**:
- Drag-drop zone (accepts files or text)
- DataGrid with all resolved properties (sortable, resizable columns)
- Status bar showing Outlook legacy version & connection status
- Lookup button (click to resolve all extracted addresses)
- Clear button (reset grid & input)
- Export button (save results to CSV/Excel)
- Settings persistence: window position, lookup history, Outlook COM cache

---

## Implementation Phases

### Phase 1: Foundation Setup (EmailLookup.psm1)
- Step 1: Module structure, assemblies, variables
- Step 2: Outlook COM initialization, version detection, cleanup

### Phase 2: Recipient Extraction (EmailLookup.psm1)
- Step 3: Extract from MailItem, .msg files, raw email text

### Phase 3: User Lookups (EmailLookup.psm1)
- Step 4: Resolve-UserViaGAL, Get-UserFromContacts, Get-UserFromADSI, Lookup-User

### Phase 4: WPF UI (LookupEmailList.DropTarget.Wpf.ps1)
- Step 5: XAML design with drop zone, DataGrid, status bar, buttons
- Step 6: Drag-drop handlers
- Step 7: Lookup button handler
- Step 8: Utility buttons (Clear, Export)
- Step 9: Settings persistence
- Step 10: Finalization & error handling

---

## Files to Create
- SessionUtils\EmailLookup.psm1 — Core module (350+ lines)
- SessionUtils\LookupEmailList.DropTarget.Wpf.ps1 — WPF UI (400+ lines)
- SessionUtils\LookupEmailList.Settings.json — Settings template

---

## Reference Patterns
- WpfFolderSizeBrowser.v3.ps1 — Window creation, DataGrid binding, JSON settings
- WpfJpegCommentEditor.ps1 — Drag-drop handlers
- TrackSessions.Reservations.Outlook.psm1 — Outlook COM patterns
- TrackSessions.ps1 — ADSI DirectorySearcher pattern

---

## Verification Steps
1. Outlook detection → status bar shows version
2. Drag .msg file → recipients extracted
3. Paste email text → recipients parsed
4. Click Lookup → DataGrid populated with all properties
5. Fallback chain works (Contacts/ADSI when Outlook unavailable)
6. Export CSV with all columns
7. Settings restored on restart