# TrackSessions.UserEditor Chat Log

## 2026-09-08 Transcript

### User
Create new WPF PowerShell 5.1 in Sessions\TrackSessions.UserEditor.ps1 to show list of users stored in new users file TrackSessions.Users.json. 
A user grid should display: SEID, First Name, last name, Status, IRS Email, SEID Email, Timezone, Products, Last Login, Last PAWS Used, Last Modified, Created.
Then when row clicked (single select), and Edit... button or double-clicked, an Edit User dialog pops up (that is modal).
SEID, First Name, Last name should be string.
Status should be combobox: FTE, Contractor.
IRS Email should end in @irs.gov
SEID Email should prefill SEID field and append @ds.irsnet.gov.
Timezone should be combbox:  include CA time and also Atlantic, Puerto Rico time, Texas, Utah, and Washington DC named cities and time zone codes.
Have a check box for Daylight savings time.
Products should be multi-select combo: SharePoint, Power Platform, OneDrive, Entra.
Last Login is date time field, formatted as www dd/mm/yyyy hh:mm
where www is day of week.
Last PAWS is FQDN of the last PAWS used from the shared settings???
Last modified is this entry last modified date time field, formatted as www dd/mm/yyyy hh:mm
where www is day of week.
Date created is date this entry created date time field, formatted as www dd/mm/yyyy hh:mm
where www is day of week.

### Assistant
Implemented a brand-new PowerShell 5.1 WPF user editor with modal edit workflow and JSON persistence.

### What I created
1. New users file: [Sessions/TrackSessions.Users.json](Sessions/TrackSessions.Users.json)
2. Full editor app: [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

### What the new UI does
1. Main grid shows exactly these columns:
   - SEID
   - First Name
   - Last Name
   - Status
   - IRS Email
   - SEID Email
   - Timezone
   - Products
   - Last Login
   - Last PAWS Used
   - Last Modified
   - Created

2. Single-select row behavior:
   - Click row to select
   - `Edit...` button opens modal Edit User dialog
   - Double-click row also opens the same modal dialog

3. Field rules in Edit User dialog:
   - SEID, First Name, Last Name are strings and required
   - Status is ComboBox: `FTE`, `Contractor`
   - IRS Email must end with `@irs.gov`
   - SEID Email auto-prefills from SEID as `SEID@ds.irsnet.gov`
   - Timezone is ComboBox with:
     - Los Angeles, CA (PT)
     - Halifax, Atlantic
     - San Juan, Puerto Rico
     - Austin, TX
     - Denver, UT
     - Washington, DC
     - Phoenix, AZ (included as common AZ/no-DST option)
   - Daylight Savings checkbox included
   - Products implemented as multi-select combo-style dropdown with checkboxes:
     - SharePoint
     - Power Platform
     - OneDrive
     - Entra
   - Last Login accepts and displays format `www dd/mm/yyyy hh:mm`
   - Last PAWS Used is validated as FQDN
   - Last PAWS choices are loaded from [Sessions/TrackSessions.Settings.json](Sessions/TrackSessions.Settings.json) `Tracking.Machines[].FQDN` values
   - Last Modified auto-updates on save
   - Created auto-set on creation and preserved on edit
   - Date display format is `ddd dd/MM/yyyy hh:mm` (matching your requested day + dd/mm/yyyy + hh:mm layout)

4. Persistence:
   - Reads/writes [Sessions/TrackSessions.Users.json](Sessions/TrackSessions.Users.json)
   - `Save All` button included
   - Saves automatically on window close
   - `Refresh` button reloads from disk

### Validation status
1. Script parser check: passed (`Parse OK`)
2. Diagnostics for [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1): no errors found

If you want, next I can add sorting/filter boxes above the grid (for SEID, status, product, and timezone) to make user lookup faster.

---

## 2026-09-08 Transcript (Appended)

### User
Append to TrackSessions.UserEditor.Chat.md above verbatim chat with formatting. Preserve file changes.

### Assistant
Appended transcript log created at [Sessions/TrackSessions.UserEditor.Chat.md](Sessions/TrackSessions.UserEditor.Chat.md) with preserved markdown formatting and the verbatim user request plus assistant response content.

No existing code files were modified.

### User
TrackSessions.UserEditor.ps1'
C:\Users\YMJNB\OneDrive - Internal Revenue
Service\Documents\PowerShell 2025\PowerShell v5.1\July
2025\Sessions\TrackSessions.UserEditor.ps1 : Exception setting
"ItemsSource": "Cannot convert the "@{SEID=ABCD123; FirstName=Sample;
LastName=User; Status=FTE; IRSEmail=sample.user@irs.gov; 
SEIDEmail=ABCD123@ds.irsnet.gov; Timezone=Washington, DC (ET) 
[UTC-05:00 / UTC-04:00]; DaylightSavings=True; 
Products=System.Object[]; ProductsDisplay=SharePoint, OneDrive; 
LastLoginDate=9/7/2026 9:15:00 AM; LastLogin=Mon 07/09/2026 09:15; 
LastPawsUsed=mtb012vp0030366.ds.irsnet.gov; LastModifiedDate=9/7/2026 
9:15:00 AM; LastModified=Mon 07/09/2026 09:15; CreatedDate=9/7/2026 
9:15:00 AM; Created=Mon 07/09/2026 09:15}" value of type 
"System.Management.Automation.PSCustomObject" to type 
"System.Collections.IEnumerable"."
At line:1 char:1
+ . 'C:\Users\YMJNB\OneDrive - Internal Revenue 
Service\Documents\Power ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [TrackSessions.UserEdi 
   tor.ps1], SetValueInvocationException
    + FullyQualifiedErrorId : ExceptionWhenSetting,TrackSessions.UserE 
   ditor.ps1

### Assistant
Fixed. The `ItemsSource` crash came from PowerShell pipeline unrolling in `Import-Users`.

### Root cause
When `Import-Users` returned an `ObservableCollection`, PowerShell enumerated it on return.
With one user, that became a single `PSCustomObject`, and WPF `DataGrid.ItemsSource` rejected it because it expects an `IEnumerable`.

### Change made
In [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1), `Import-Users` now returns the collection as a single object:

- Empty case:
  - `return ,([System.Collections.ObjectModel.ObservableCollection[object]]::new())`
- Normal case:
  - `return ,$collection`

The unary comma prevents PowerShell from unrolling the collection.

### Verification
1. Parse check: `Parse OK`
2. Runtime smoke test for `Import-Users`:
   - Type is `ObservableCollection[object]`
   - `IsEnumerable=True`
   - `Count=1`
3. Diagnostics: no errors found in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

You can run the script again; the grid should now bind correctly even with a single user record.

### User
in New / Edit dialog add a Load button that takes the SEID and tries to find the rest of the row information.

### Assistant
Added the new `Load` button in the New/Edit dialog and wired it to SEID lookup.

### What changed
1. In [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1), the SEID row now has:
   - SEID textbox
   - `Load` button (`btnLoadBySeid`)

2. `Show-EditUserDialog` now accepts a lookup collection:
   - New parameter: `-LookupUsers`

3. Load behavior:
   - Takes SEID from the textbox
   - Searches the current users list case-insensitively by `SEID`
   - If found, populates:
     - First Name, Last Name, Status
     - IRS Email, SEID Email
     - Timezone, DST
     - Products selection
     - Last Login, Last PAWS Used
     - Created/Last Modified metadata display
   - If not found, shows a “No user found” message

4. Both dialog entry points now pass the lookup list:
   - Edit flow passes `-LookupUsers $users`
   - New flow passes `-LookupUsers $users`

### Validation
1. Parser check: `Parse OK`
2. Diagnostics: no errors in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

If you want, I can also make `Load` optionally query an external source (AD/Graph/CSV) when no local SEID match exists.

### User
`Load` optionally query an external source (AD/Graph/CSV) when no local SEID match exists.

### Assistant
Added optional external fallback lookup to the dialog `Load` workflow in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1).

### What’s implemented
When `Load` is clicked in New/Edit dialog:

1. Try local users list first (existing behavior).
2. If not found, try enabled external providers in order:
   1. CSV
   2. Active Directory
   3. Microsoft Graph

If a provider returns a match, the dialog auto-populates fields and shows the source in the success message.

### External provider configuration
In script-level config:

- `Enabled` overall switch
- `EnableCsv` toggle
- `CsvPath` default: [Sessions/TrackSessions.Users.External.csv](Sessions/TrackSessions.Users.External.csv) (optional file)
- `EnableAD` toggle
- `EnableGraph` toggle

Current defaults:
- CSV: enabled
- AD: enabled
- Graph: disabled

### New helper functions added
- `Split-ProductsValue`
- `New-ExternalUserLookupResult`
- `Find-ExternalUserFromCsv`
- `Find-ExternalUserFromAd`
- `Find-ExternalUserFromGraph`
- `Resolve-ExternalUserBySeid`

### Notes on provider behavior
- CSV expects `SEID` plus optional columns like `FirstName`, `LastName`, `Status`, `IRSEmail`, `SEIDEmail`, `Timezone`, `DaylightSavings`, `Products`, `LastLogin`, `LastPawsUsed`, `Created`, `LastModified`.
- AD uses `Get-ADUser` if available.
- Graph uses `Get-MgUser` if available and authenticated.
- Missing provider/module/auth quietly falls through to next source.

### Validation
- Parse check: `Parse OK`
- Diagnostics: no errors in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

If you want, I can add a small tooltip/help label in the dialog showing which external sources are currently enabled and the CSV path being used.

### User
TrackSessions.UserEditor.ps1'
C:\Users\YMJNB\OneDrive - Internal Revenue 
Service\Documents\PowerShell 2025\PowerShell v5.1\July 
2025\Sessions\TrackSessions.UserEditor.ps1 : Exception calling 
"ShowDialog" with "0" argument(s): "The property 'LastLogin' cannot be 
found on this object. Verify that the property exists."
At line:1 char:1
+ . 'C:\Users\YMJNB\OneDrive - Internal Revenue 
Service\Documents\Power ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [TrackSessions.UserEdi 
   tor.ps1], MethodInvocationException
    + FullyQualifiedErrorId : CmdletInvocationException,TrackSessions. 
   UserEditor.ps1

### Assistant
Fixed the `ShowDialog` crash.

### Root cause
Under `Set-StrictMode -Version Latest`, accessing a missing property throws.  
In the dialog fill helper, code referenced `source.LastLogin` (and similar metadata fields) directly; some loaded objects did not include all those properties.

### Fix applied
In [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1):

1. Added safe optional-property reads inside `$applyUserToDialog`:
   - `LastLogin`
   - `Created`
   - `LastModified`
2. Switched later logic to use those safe local variables instead of direct property access.

This prevents strict-mode exceptions when a lookup result or external source object is missing one of those fields.

### Validation
1. Parse check: `Parse OK`
2. Diagnostics: no errors in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

---

## 2026-09-08 Transcript (Appended 2)

### User
if I enter Last First [First.Last@irs.gov](mailto:First.Last@irs.gov) -- or similar into IRS email - including look up the SEID.

### Assistant
Updated in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1): IRS-email smart entry now explicitly includes SEID population.

### New behavior
When IRS Email loses focus and target fields are blank:

1. It still parses formats like:
   - `Last First First.Last@irs.gov`
   - `First.Last@irs.gov`
2. It tries local/external lookup by email, then inferred SEID.
3. If a record is found, dialog is populated (including SEID).
4. If no record is found, it now still sets SEID from inferred candidate (email local-part cleanup), then auto-fills SEID Email.

So even without a lookup hit, entering `First.Last@irs.gov` can populate SEID (e.g., `FirstLast`) and `FirstLast@ds.irsnet.gov`.

### Validation
1. Parse check: `Parse OK`
2. Diagnostics: no errors in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

### User
It still wants SEID first - maybe have SEID unknown checkbox or disable SEID  and then lookup vira email as above. Email partial lookup working.

### Assistant
Implemented your request with a new `SEID Unknown` mode in the dialog.

### What changed in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

1. Added `SEID Unknown` checkbox beside SEID in New/Edit dialog.
2. When checked:
   - SEID textbox is disabled
   - `Load` button (SEID-based) is disabled
   - SEID value is cleared
   - Auto-generated `@ds.irsnet.gov` value is cleared if it came from SEID
3. Save validation updated:
   - SEID is required only when `SEID Unknown` is **not** checked
   - SEID Email is optional when SEID is unknown
   - If provided, SEID Email still must match `@ds.irsnet.gov`
4. Existing IRS-email smart lookup continues to work for email-first workflow and can fill SEID if found/inferred.

### Resulting workflow
1. Check `SEID Unknown`.
2. Enter IRS email text in the supported format (including `Last First First.Last@irs.gov`).
3. Email-driven lookup/fill proceeds without needing SEID first.

### Validation
1. Parse check: `Parse OK`
2. Diagnostics: no blocking errors in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

One diagnostics message still appears with stale text about an unapproved verb, but the current function name in the file is already updated and parsing is clean.

This should remove the runtime error you posted and allow `Load`/dialog open paths to proceed even with partial external data.

### User
TrackSessions.UserEditor.ps1'
C:\Users\YMJNB\OneDrive - Internal Revenue 
Service\Documents\PowerShell 2025\PowerShell v5.1\July 
2025\Sessions\TrackSessions.UserEditor.ps1 : Exception calling 
"ShowDialog" with "0" argument(s): "Exception calling "ShowDialog" 
with "0" argument(s): "The property 'LookupSource' cannot be found on 
this object. Verify that the property exists.""
At line:1 char:1
+ . 'C:\Users\YMJNB\OneDrive - Internal Revenue 
Service\Documents\Power ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [TrackSessions.UserEdi 
   tor.ps1], MethodInvocationException
    + FullyQualifiedErrorId : CmdletInvocationException,TrackSessions. 
   UserEditor.ps1

### Assistant
Fixed that crash as well.

### Root cause
`Set-StrictMode -Version Latest` throws when reading missing properties.  
`LookupSource` only exists for external lookup results, but local matches didn’t have it.

### Fix
In [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1), I changed the Load success message code to:

1. Safely detect if `LookupSource` exists on `$found`
2. Use it only when present
3. Otherwise use empty text

So local loads now work without trying to read a non-existent property.

### Validation
1. Parse check: `Parse OK`
2. Diagnostics: no errors in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

If another strict-mode property exception appears, send it and I’ll patch the same way quickly.

### User
Make Purple the SEID and also IRS email field - if I enter Last First [First.Last@irs.gov](mailto:First.Last@irs.gov) -- or similar into IRS email - look up rest of fields if all blank.

### Assistant
Implemented both requested behaviors in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1).

### 1) Purple SEID and IRS Email fields
In the New/Edit dialog XAML:
1. `txtSeid` now has purple foreground and border.
2. `txtIrsEmail` now has purple foreground and border.

### 2) Smart IRS Email entry auto-lookup when other fields are blank
Added a new `LostFocus` handler on `txtIrsEmail` that runs only when the rest of the target fields are blank.

Behavior:
1. Parses inputs like:
   - `Last First First.Last@irs.gov`
   - plain `First.Last@irs.gov`
2. Normalizes IRS email text to the extracted `@irs.gov` value when present.
3. Prefills First/Last from typed name tokens if available.
4. Attempts lookup by email in this order:
   1. Local users list (`LookupUsers`)
   2. External sources via new `Resolve-ExternalUserByEmail`:
      - CSV (if enabled)
      - AD (if enabled)
      - Graph (if enabled)
5. If still not found, tries inferred SEID from email local part (e.g., `first.last` -> `firstlast`) against:
   1. Local SEID
   2. External SEID lookup (`Resolve-ExternalUserBySeid`)
6. If found, it auto-populates the dialog fields (same as Load button behavior).

### New helper functions added
1. `Parse-IrsEmailInput`
2. `Find-ExternalUserFromCsvByEmail`
3. `Find-ExternalUserFromAdByEmail`
4. `Find-ExternalUserFromGraphByEmail`
5. `Resolve-ExternalUserByEmail`

### Validation
1. Parse check: `Parse OK`
2. Diagnostics: no errors in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

---

## 2026-09-10 Transcript (UI Polish & Screen Tips)

### User Request
1. Add Memphis TN, Ogden UT, Martinsburg WV to timezone list (keep geographical order and format)
2. Add screen tips (ToolTips) to all controls in main window and edit dialog
3. Make Edit button enabled only when a row is selected
4. Clarify what "Save All" does via button label and screen tip

### Assistant

#### Changes Applied to [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)

**1. Timezone List Enhanced** (Lines 18-28)
   - Added Memphis, TN (CT) [UTC-06:00 / UTC-05:00]
   - Added Ogden, UT (MT) [UTC-07:00 / UTC-06:00]
   - Added Martinsburg, WV (ET) [UTC-05:00 / UTC-04:00]
   - Maintained geographical order (West to East)
   - All entries follow consistent format with city, state, timezone code, and UTC offset

**2. Main Window - Button & Control Tooltips** (Lines 1287-1468)
   - **btnNew**: "Create a new user record"
   - **btnEdit**: "Edit the selected user (select a row first)" — **Now disabled by default (IsEnabled='False')**
   - **btnDelete**: "Delete the selected user (select a row first)"
   - **btnSaveAll**: "Save all user records to file (TrackSessions.Users.json)" — **Explicitly clarifies JSON file target**
   - **btnRefresh**: "Reload all users from file (discards unsaved changes)"
   - **gridUsers**: "Click to select a user. Double-click to edit. Use buttons above for other actions."

**3. DataGrid Column Headers - All With Tooltips** (Lines 1298-1323)
   - **SEID**: "Unique user identifier (case-insensitive)"
   - **First Name**: "User first name"
   - **Last Name**: "User last name"
   - **Status**: "FTE (Full-Time Employee) or Contractor"
   - **IRS Email**: "Internal IRS email address (@irs.gov)"
   - **SEID Email**: "SEID-based email (@ds.irsnet.gov)"
   - **Timezone**: "User timezone and DST rules"
   - **DST**: "Observe Daylight Saving Time"
   - **Products**: "Assigned products (SharePoint, Power Platform, OneDrive, Entra)"
   - **Last Login**: "Last login date and time"
   - **Last PAWS Used**: "Last PAWS machine used (FQDN)"
   - **Last Modified**: "Last modification date and time (auto-managed)"
   - **Created**: "User creation date and time (auto-managed)"

**4. Conditional Edit Button Behavior** (Lines 1452-1454)
   ```powershell
   # Enable/disable Edit button based on grid selection
   $gridUsers.Add_SelectionChanged({
       $btnEdit.IsEnabled = ($null -ne $gridUsers.SelectedItem)
   })
   ```
   - Edit button starts disabled
   - Becomes enabled when user selects a row
   - Disabled again when selection is cleared
   - Prevents accidental clicks without selection

**5. Edit Dialog - Complete Tooltip Coverage** (Lines 640-732)
   - **SEID textbox**: "Unique user identifier (case-insensitive). Required unless SEID Unknown is checked."
   - **SEID Unknown checkbox**: "Check if SEID is not known and will be looked up via IRS Email"
   - **Load button**: "Load user data from external directory by SEID"
   - **First Name**: "User first name"
   - **Last Name**: "User last name"
   - **Status combo**: "Employment status: FTE (Full-Time Employee) or Contractor"
   - **IRS Email**: "Internal IRS email address (@irs.gov). Required for email notifications."
   - **SEID Email**: "SEID-based email address (@ds.irsnet.gov)"
   - **Timezone combo**: "User timezone for scheduling and reservations"
   - **Daylight Savings**: "Check if this timezone observes Daylight Saving Time"
   - **Products dropdown**: "Click to select products (SharePoint, Power Platform, OneDrive, Entra)"
   - **Last Login**: "Last login date and time in format: Fri 24/01/2025 14:30 (auto-managed)"
   - **Last PAWS Used combo**: "Last PAWS machine used (Fully Qualified Domain Name)"
   - **Created/Modified info**: "Displays creation and last modification timestamps"
   - **Is Admin checkbox**: "Check to grant admin privileges for managing reservations"
   - **Lookup Log console**: "Real-time log of external directory lookups and validation results"
   - **Save button**: "Save user record and close dialog"
   - **Cancel button**: "Discard changes and close dialog"

#### Issue Encountered & Fixed
**Problem**: XAML XamlParseException — "'Header' property has already been set on 'DataGridTextColumn'"
- Root cause: Set `Header` attribute inline AND nested element simultaneously
- **Solution**: Removed all inline `Header` attributes, kept only nested `<DataGridTextColumn.Header>` elements with TextBlock containing tooltips
- **Result**: Script now loads without XAML parsing errors

### Validation
1. **XAML Syntax**: Fixed; no parsing errors
2. **Edit Button State**: Initially disabled (IsEnabled='False')
3. **Selection Handler**: `$gridUsers.Add_SelectionChanged` enables/disables Edit button correctly
4. **Tooltips Coverage**: 
   - Main window: All 5 buttons + DataGrid + 13 column headers = 19 tooltips
   - Edit dialog: 18 controls with descriptive tooltips
   - Total new tooltips: 37

### Unfinished Work & Recommendations

#### ✅ COMPLETED
- ✅ Timezone list expanded with 3 new US locations (Memphis TN, Ogden UT, Martinsburg WV)
- ✅ All main window controls have screen tips
- ✅ All edit dialog controls have screen tips
- ✅ DataGrid column headers have tooltips (via nested TextBlock elements)
- ✅ Edit button conditional on row selection
- ✅ "Save All" clarified to explicitly mention JSON file target

#### 🔴 NOT YET IMPLEMENTED
- [ ] **Confirmation dialog before saving user** — Show preview of changes with Save/Discard options
- [ ] **Display Outlook calendar name after reservation created** — Requires modification to `TrackSessions.Reservations.Outlook.psm1`
- [ ] **Show event link or open Outlook event** — Return EntryID from New-OutlookReservationEvent
- [ ] **In-app reservation list view** — Consider adding DataGrid to CalendarDialog showing user's reservations

#### 🟡 FUTURE ENHANCEMENTS
- Consider adding status bar showing "X users loaded" and "Last saved: [timestamp]"
- Add search/filter capability to main DataGrid
- Implement bulk operations (export/import users)
- Add user role/permission level field for admin segregation
- Persist main window position and column widths

---

## 2026-09-11 Transcript (SEID Uppercase Normalization)

### User Request
For User editor, always make SEID field upper case after entry and when reloading.

### Assistant
Implemented SEID uppercase normalization throughout the user editor workflow in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1).

### Changes Applied

Updated **10 key locations** to ensure SEID is always stored and displayed in uppercase:

1. **Loading users from JSON** — `Convert-ToUserObject` function (line 107)
   - `SEID = ([string]$RawUser.SEID).ToUpperInvariant()`

2. **Saving users to JSON** — `Convert-FromUserObject` function (line 135)
   - `SEID = ([string]$User.SEID).ToUpperInvariant()`

3. **External lookup results** — `New-ExternalUserLookupResult` function (line 197)
   - `SEID = ([string]$SEID).ToUpperInvariant()`

4. **Dialog initialization** — When loading existing user into working object (line 834)
   - `SEID = ([string]$User.SEID).ToUpperInvariant()`

5. **Email lookup** — When creating object from external email lookup (line 1043)
   - `SEID = ([string]$externalEmail.SEID).ToUpperInvariant()`

6. **SEID lookup** — When creating object from external SEID lookup (line 1097)
   - `SEID = ([string]$externalSeid.SEID).ToUpperInvariant()`

7. **Candidate SEID inference** — When populating SEID from email parse (line 1130)
   - `$txtSeid.Text = ([string]$parsed.SeidCandidate).ToUpperInvariant()`

8. **Load button handler** — When loading from local sources (line 1241)
   - `SEID = ([string]$external.SEID).ToUpperInvariant()`

9. **Load button handler** — When loading from external sources (line 1262)
   - `SEID = ([string]$found.SEID).ToUpperInvariant()`

10. **Save button handler** — When saving the final user record to file (line 1403)
    - `SEID = $seid.ToUpperInvariant()`

### How It Works

- **On entry**: The existing `$normalizeSeidText` function converts text to uppercase in real-time as the user types
- **On reload**: All functions that load or create user objects now apply `.ToUpperInvariant()` to ensure uppercase
- **On save**: The SEID is uppercased before being stored in the JSON file
- **On display**: All objects displayed in the dialog have uppercase SEID values

### Workflow Coverage

| Stage | Behavior |
|-------|----------|
| **Text input** | Real-time uppercase via TextChanged event |
| **Dialog initialization** | Uppercase applied when loading existing user |
| **IRS Email lookup** | SEID candidate inferred from email and uppercased |
| **Load button** | SEID from local or external sources uppercased |
| **Save to JSON** | Final SEID value uppercased before persistence |
| **Reload from file** | SEID immediately uppercased on import |

### Validation
1. **Parse check**: `Parse OK`
2. **Diagnostics**: No errors in [Sessions/TrackSessions.UserEditor.ps1](Sessions/TrackSessions.UserEditor.ps1)
   - (Two warnings exist for unused variables `btnCancel` and `isProcessingSelectionChange`, but these are non-blocking)

The SEID field is now guaranteed to be uppercase at every stage: entry, internal processing, external lookups, and storage.
