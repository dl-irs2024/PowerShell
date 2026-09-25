# TrackSessions User Editor Lookup Logic (Detailed)

This document explains all lookup-related logic implemented in:

- `Sessions/TrackSessions.UserEditor.ps1`

It covers:

1. What lookups exist
2. Data sources and provider order
3. How SEID and IRS Email driven lookups work
4. How parsing and fallback behave
5. UI behavior in New/Edit dialog
6. Validation and edge cases

---

## 1. Lookup Scope Overview

The New/Edit dialog supports two primary lookup entry points:

1. SEID-driven lookup (explicit):
   - User enters SEID and clicks `Load`
2. IRS Email-driven lookup (implicit):
   - User enters IRS email text (for example `Patterson Richard L Richard.Patterson@irs.gov`)
   - Lookup runs on IRS Email `LostFocus`

Both entry points can search:

1. Local in-memory user list (`$LookupUsers`)
2. External providers (CSV, AD, Graph) based on configuration

A 3-line lookup status console in the dialog footer logs attempts and outcomes.

---

## 2. External Lookup Configuration

Script config object:

```powershell
$script:ExternalLookup = [ordered]@{
    Enabled     = $true
    EnableCsv   = $true
    CsvPath     = Join-Path -Path $script:BaseDir -ChildPath 'TrackSessions.Users.External.csv'
    EnableAD    = $true
    EnableGraph = $false
}
```

Meaning:

1. `Enabled`:
   - Master switch for external lookups
2. `EnableCsv`:
   - Enables CSV provider
3. `CsvPath`:
   - Path to external CSV source
4. `EnableAD`:
   - Enables Active Directory provider (`Get-ADUser`)
5. `EnableGraph`:
   - Enables Microsoft Graph provider (`Get-MgUser`)

If a provider is disabled or unavailable, logic continues to the next provider.

---

## 3. Core Lookup Helper Functions

## 3.1 Input Parsing

### `ConvertFrom-IrsEmailInput`

Purpose:

1. Parse free-form IRS email input text
2. Extract structured values for lookup pipeline

Returns object with:

1. `RawInput`
2. `Email`
3. `FirstName`
4. `LastName`
5. `SeidCandidate`

Behavior details:

1. Extracts `@irs.gov` email via regex
2. Removes extracted email from the input residue
3. Splits remaining text by whitespace
4. Treats first token as `LastName`, second token as `FirstName` when at least two tokens exist
5. Builds SEID candidate from email local-part by stripping `.`, `_`, `-`
6. Candidate accepted only if length is between 4 and 12

Example:

Input:

`Patterson Richard L Richard.Patterson@irs.gov`

Likely parsed result:

1. `Email = Richard.Patterson@irs.gov`
2. `LastName = Patterson`
3. `FirstName = Richard`
4. `SeidCandidate = RichardPatterson`

---

## 3.2 External Resolver Entry Points

### `Resolve-ExternalUserBySeid`

Provider order:

1. CSV (`Find-ExternalUserFromCsv`)
2. AD (`Find-ExternalUserFromAd`)
3. Graph (`Find-ExternalUserFromGraph`)

Stops at first hit.

### `Resolve-ExternalUserByEmail`

Provider order:

1. CSV (`Find-ExternalUserFromCsvByEmail`)
2. AD (`Find-ExternalUserFromAdByEmail`)
3. Graph (`Find-ExternalUserFromGraphByEmail`)

Stops at first hit.

---

## 3.3 Provider Functions

### CSV

1. `Find-ExternalUserFromCsv`:
   - Matches row by `SEID`
2. `Find-ExternalUserFromCsvByEmail`:
   - Matches row by `IRSEmail`
   - Then resolves full row via `Find-ExternalUserFromCsv`

### Active Directory

1. `Find-ExternalUserFromAd`:
   - Query by `SamAccountName`
2. `Find-ExternalUserFromAdByEmail`:
   - Query by `mail`

### Graph

1. `Find-ExternalUserFromGraph`:
   - Query by `mailNickname`
   - fallback `startsWith(userPrincipalName,'SEID@')`
2. `Find-ExternalUserFromGraphByEmail`:
   - Query by `mail`

All provider outputs normalize through `New-ExternalUserLookupResult`.

---

## 3.4 Result Normalization

### `New-ExternalUserLookupResult`

Creates a consistent result object:

1. `Source`
2. `SEID`
3. `FirstName`
4. `LastName`
5. `Status`
6. `IRSEmail`
7. `SEIDEmail`
8. `Timezone`
9. `DaylightSavings`
10. `Products`
11. `LastLoginDate`
12. `LastPawsUsed`
13. `CreatedDate`
14. `LastModifiedDate`

Defaults include:

1. `Status = FTE` when missing
2. `Timezone = Washington, DC ...` when missing
3. `SEIDEmail = <SEID>@ds.irsnet.gov` when missing and SEID exists

---

## 4. New/Edit Dialog Lookup UX

## 4.1 Controls Involved

In `Show-EditUserDialog`:

1. `txtSeid`
2. `btnLoadBySeid`
3. `chkSeidUnknown`
4. `txtIrsEmail`
5. `txtLookupConsole` (3-line status console)

---

## 4.2 Lookup Log Console

The dialog creates:

1. `List[string] $lookupLogLines`
2. Writer scriptblock `$writeLookupLog`

Rules:

1. Prefix each line with timestamp `[HH:mm:ss]`
2. Keep only latest 3 lines
3. Show in footer textbox `txtLookupConsole`

Initial message:

`Ready. Enter SEID and click Load, or enter IRS email for lookup.`

---

## 4.3 SEID Unknown Mode

`chkSeidUnknown` behavior:

1. Disables SEID textbox and SEID Load button
2. Clears SEID value when enabled
3. Clears generated SEID email if it is a DS domain value

Validation behavior on Save:

1. SEID required only when `SEID Unknown` is unchecked
2. SEID email optional when SEID unknown

---

## 5. SEID-Driven Lookup Flow (Load Button)

Trigger:

1. `btnLoadBySeid.Add_Click`

Pipeline:

1. If SEID blank:
   - log skip
   - show validation message
2. Search local users by SEID (case-insensitive)
3. If not found, call `Resolve-ExternalUserBySeid`
4. If still not found:
   - log no match
   - show informational message
5. If found:
   - map result into dialog object
   - apply to UI (`$applyUserToDialog`)
   - auto-generate SEID email if empty
   - log success including source

---

## 6. IRS Email-Driven Lookup Flow (LostFocus)

Trigger:

1. `txtIrsEmail.Add_LostFocus`

Precondition gate:

1. Allow email lookup when either:
   - `SEID Unknown` is checked, or
   - SEID textbox is empty
2. Otherwise:
   - log: lookup skipped because SEID already populated

Detailed pipeline:

1. Parse input via `ConvertFrom-IrsEmailInput`
2. Normalize displayed IRS email if extracted
3. Pre-fill first and last name from parsed tokens if current fields are blank
4. Try local lookup by IRS email
5. If not found, try external lookup by IRS email
6. If not found, try local name-based match (`FirstName` + `LastName`)
7. If not found, try local lookup by candidate SEID
8. If not found, try external lookup by candidate SEID
9. If found at any step:
   - apply result to dialog
   - auto-populate SEID email if empty
   - log success with source detail
10. If no record found but candidate SEID exists:
   - fill SEID with candidate
   - auto-populate SEID email
   - log candidate fallback
11. If nothing usable found:
   - log no match

---

## 7. Candidate SEID Fallback Logic

Candidate SEID creation from IRS email local-part:

1. Take text before `@`
2. Remove `.`, `_`, `-`
3. Keep if length 4-12

Purpose:

1. Give operator a usable SEID guess even when no local/external record exists

Example:

1. `Richard.Patterson@irs.gov` -> `RichardPatterson`

---

## 8. Local vs External Data Priority

For both SEID and email workflows:

1. Local match has priority over external match
2. External lookup only runs if local lookup does not match
3. External provider order is deterministic and configurable

---

## 9. StrictMode Safety Notes

The script runs with:

```powershell
Set-StrictMode -Version Latest
```

Lookup mappings and dialog application logic use guarded property access in several places to avoid runtime exceptions when a source object lacks optional properties.

---

## 10. Troubleshooting Guide

## 10.1 No external lookups happen

Check:

1. `$script:ExternalLookup.Enabled`
2. Per-provider flags (`EnableCsv`, `EnableAD`, `EnableGraph`)
3. CSV path exists and has expected headers
4. AD module availability (`Get-ADUser`)
5. Graph module + auth (`Get-MgUser`)

## 10.2 Email entered but no SEID appears

Check:

1. `SEID Unknown` mode or empty SEID precondition
2. Input contains valid `@irs.gov` address
3. Candidate SEID length must be 4-12 after cleanup
4. Provider data actually contains matching user

## 10.3 SEID auto-generation conflicts

SEID email auto-population (`<SEID>@ds.irsnet.gov`) is disabled when `SEID Unknown` is checked.

---

## 11. Suggested CSV Schema for External Lookup

Recommended columns in `TrackSessions.Users.External.csv`:

1. `SEID`
2. `FirstName`
3. `LastName`
4. `Status`
5. `IRSEmail`
6. `SEIDEmail`
7. `Timezone`
8. `DaylightSavings`
9. `Products`
10. `LastLogin`
11. `LastPawsUsed`
12. `Created`
13. `LastModified`

---

## 12. Summary

The dialog currently supports robust lookup behavior:

1. Direct SEID lookup via button
2. Smart IRS email string parsing
3. Local-first then external fallback
4. Name and candidate SEID fallback paths
5. `SEID Unknown` mode for email-first workflows
6. Real-time 3-line lookup result console for operator visibility
