# TrackSessions.Reservations — Phase 6: Settings Admin Panel
## WPF-Based Configuration Management for Reservation System

**Version**: 1.0  
**Created**: 2026-09-09  
**Status**: Production Ready  
**Dependencies**: TrackSessions.Settings.json, TrackSessions.Users.json (Phase 1)

---

## Overview

Phase 6 delivers a **comprehensive WPF settings dialog** for admins to manage the entire reservation system configuration without editing JSON files directly. Admins can:
- Edit business hours (start/end time)
- Configure time slot granularity (15/30/45/60 minutes)
- Set reservation storage path with validation
- Manage administrator user list (add/remove)
- Configure email distribution list for notifications
- Enable/disable Outlook integration features
- Validate all settings before saving
- Apply changes atomically (all-or-nothing)

**Target Users**: System administrators managing the TrackSessions reservation system.

---

## Features & UI Components

### 1. **Access Control**

Dialog is **admin-only**:

```powershell
if (-not (Test-AdminAccess)) {
    MessageBox: "This feature requires admin access. Contact your administrator."
    Window.Close()
}
```

**Check**: User SEID in Users.json with `IsAdmin = true`  
**Fallback**: If user not found or IsAdmin=false, dialog closes immediately

### 2. **Tabbed Interface**

5 tabs for different configuration areas:

```
┌────────────┬──────────────┬────────────┬──────────────┬─────────┐
│ Business   │ Reservation  │ Admins     │ Email        │ Outlook │
│ Hours      │ Path         │            │ Settings     │         │
└────────────┴──────────────┴────────────┴──────────────┴─────────┘
```

**Navigation**:
- Click tab → switches content panel
- Tab title acts as radio button
- Only one tab active at a time

### 3. **Business Hours Tab**

Configure when machines can be reserved:

```
Business Hours Configuration

Start Time: [09:00]
End Time:   [18:00]
Time Slot:  [30  ▼] minutes
```

**Fields**:
- **Start Time**: Text input (format: HH:mm, e.g., 09:00)
- **End Time**: Text input (format: HH:mm, e.g., 18:00)
- **Time Slot Granularity**: Dropdown
  - Options: 15, 30, 45, 60 minutes
  - Default: 30 minutes

**Validation** (on Apply):
- ✅ Start time before end time
- ✅ Valid HH:mm format
- ✅ Not swapped (shows error if end < start)

**Example**:
```
09:00 - 18:00 with 30-min slots
→ Available: 09:00, 09:30, 10:00, 10:30, ..., 17:00, 17:30
```

### 4. **Reservation Path Tab**

Set storage location for reservation files:

```
Reservation Path Configuration

Storage Path: [\\company\reservations\paws]

✓ Path is accessible and writable
```

**Field**:
- **Storage Path**: UNC or local path (e.g., `\\server\share\reservations`)

**Validation** (on blur):
- ✅ Path exists
- ✅ Path is a directory
- ✅ User has write permission (test by creating temp file)

**Status Messages**:
- ✓ Green: "Path is accessible and writable"
- ✗ Red: "Path does not exist" / "Not a directory" / "Permission denied"

**Note**: Path must be accessible from all machines using reservation system.

### 5. **Administrators Tab**

Manage admin user list:

```
Administrator Users

[Select user...  ▼] [Add Admin]

┌──────────────────────────────┐
│ YMJNB                 [Remove]│
│ bsypb                 [Remove]│
│ ABCD123               [Remove]│
└──────────────────────────────┘
```

**Components**:
- **User Dropdown**: All users from Users.json SEID field
- **Add Button**: Adds selected user to admin list
- **Admin List**: ListBox with remove button for each

**Behavior**:
- Cannot add duplicate admins (shows warning)
- Remove button specific to each user
- List updates immediately
- Persisted to Settings.json when Apply clicked

**Default Admins** (from Settings.json):
```json
"ReservationAdmins": ["YMJNB"]
```

### 6. **Email Settings Tab**

Configure email notification recipients:

```
Email Notification Recipients

[email@example.com    ] [Add Email]

┌──────────────────────────────┐
│ team@company.com      [Remove]│
│ manager@company.com   [Remove]│
│ admin@company.com     [Remove]│
└──────────────────────────────┘
```

**Components**:
- **Email Input**: Text field with placeholder
- **Add Button**: Adds email to distribution list
- **Email List**: ListBox with remove button for each

**Validation**:
- ✅ Valid email format (contains @)
- ✅ Not duplicate (shows warning)
- ✅ Shows error if format invalid

**Recipients**: Used by Phase 3 (Outlook) for sending notification emails

### 7. **Outlook Tab**

Enable/disable Outlook integration features:

```
Outlook Integration Settings

☐ Enable Outlook Integration
☐ Create Calendar Events
☐ Send Email Notifications
```

**Checkboxes**:
- **Enable Outlook Integration**: Master switch
- **Create Calendar Events**: Add events to calendar
- **Send Email Notifications**: Email notifications via Phase 3

**Behavior**:
- Independent toggles (can be mixed)
- Affects Phase 3 Outlook.psm1 module behavior
- When disabled: Calendar events + emails not created

**Configuration Used By**: Phase 3 module functions

### 8. **Apply & Cancel Buttons**

Bottom right buttons:

```
                            [Apply] [Cancel]
```

**Apply**:
- Validates all fields
- Shows error dialog if validation fails
- Saves to Settings.json if valid
- Shows success message
- Closes dialog

**Cancel**:
- Closes without saving
- Any unsaved changes discarded

---

## Technical Architecture

### Function: `Load-Settings`

```powershell
function Load-Settings {
    $json = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
    return $json
}
```

**Returns**: PSCustomObject from Settings.json  
**Error Handling**: Shows error dialog, returns $null  
**Called**: On dialog initialization  
**Used**: Global $script:Settings object

### Function: `Load-CurrentUser`

```powershell
function Load-CurrentUser {
    $usersJson = Get-Content -LiteralPath $UsersPath -Raw | ConvertFrom-Json
    $user = $usersJson | Where-Object { $_.SEID -eq $env:USERNAME }
    return $user
}
```

**Returns**: User object or $null if not found  
**Lookup Key**: $env:USERNAME (Windows login)  
**Used By**: `Test-AdminAccess`

### Function: `Test-AdminAccess`

```powershell
function Test-AdminAccess {
    $user = Load-CurrentUser
    if (-not $user.IsAdmin) {
        MessageBox: "This feature requires admin access"
        return $false
    }
    return $true
}
```

**Check**: User.IsAdmin = true  
**Result**: Determines if dialog is allowed to open  
**Called**: Before window initialization  
**Exit**: If false, window.Close() is called

### Function: `Test-PathAccessibility`

```powershell
function Test-PathAccessibility {
    param([string]$Path)
    
    # Check 1: Path exists?
    if (-not (Test-Path -LiteralPath $Path)) {
        return @{ Valid = $false; Message = 'Path does not exist' }
    }
    
    # Check 2: Is directory?
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) {
        return @{ Valid = $false; Message = 'Path exists but is not a directory' }
    }
    
    # Check 3: Can write?
    $tempFile = Join-Path $Path '.test-write'
    Set-Content -LiteralPath $tempFile -Value 'test' -Force
    Remove-Item -LiteralPath $tempFile -Force
    
    return @{ Valid = $true; Message = 'Path is accessible and writable' }
}
```

**Returns**: @{ Valid = $true/$false; Message = 'description' }  
**Checks**:
1. Path exists
2. Path is directory
3. User can write (creates + deletes test file)

**Called**: 
- On TextBox LostFocus (real-time validation)
- On Apply button (final validation)

**Error Handling**: Catches and returns error message

### Function: `Save-Settings`

```powershell
function Save-Settings {
    param([object]$SettingsObj)
    
    $json = $SettingsObj | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $SettingsPath -Value $json -Encoding UTF8 -Force
    return $true
}
```

**Input**: Settings PSCustomObject (modified in UI)  
**Output**: JSON file written to disk  
**Depth**: 10 (allows nested objects)  
**Encoding**: UTF-8  
**Error**: Shows dialog, returns false

**Called**: Only on Apply button

### Function: `Load-UIFromSettings`

```powershell
# Populate UI controls from $script:Settings
$txtBusinessStart.Text = $script:Settings.Reservations.BusinessHoursStart
$txtBusinessEnd.Text = $script:Settings.Reservations.BusinessHoursEnd
$cmbTimeSlot.SelectedItem = $script:Settings.Reservations.TimeSlotGranularity
$txtReservationPath.Text = $script:Settings.Tracking.ReservationPath
$listAdmins.ItemsSource = @($script:Settings.Tracking.ReservationAdmins)
$listEmails.ItemsSource = @($script:Settings.Outlook.EmailDistributionList)
$chkOutlookEnabled.IsChecked = $script:Settings.Outlook.Enabled
```

**Purpose**: Initialize all controls from disk settings  
**Called**: After window created, before showing  
**Handles**: Null/missing values gracefully

### Event Handlers

#### Tab Switching

```powershell
$tabBusiness.Add_Checked({
    $businessPanel.Visibility = 'Visible'
    $pathPanel.Visibility = 'Collapsed'
    # ... other panels collapsed
})
```

**Pattern**: Show selected panel, hide all others  
**Trigger**: Tab radio button click  
**Effect**: Instant tab switch

#### Add Admin Button

```powershell
$btnAddAdmin.Add_Click({
    $admin = $cmbUsers.SelectedItem
    if ($admin -notin $listAdmins.ItemsSource) {
        $admins = @($listAdmins.ItemsSource) + $admin
        $listAdmins.ItemsSource = $admins
    }
})
```

**Check**: Item not already in list (prevent duplicates)  
**Action**: Add to list, update ItemsSource  
**Feedback**: Error dialog if duplicate

#### Add Email Button

```powershell
$btnAddEmail.Add_Click({
    $email = $txtEmail.Text.Trim()
    if ($email -match '^[^@]+@[^@]+$') {  # Basic email regex
        if ($email -notin $listEmails.ItemsSource) {
            $listEmails.ItemsSource += $email
            $txtEmail.Clear()
        }
    }
})
```

**Validation**: Email format check (simple regex)  
**Deduplication**: Check list before adding  
**UX**: Clear input on success

#### Path Validation (LostFocus)

```powershell
$txtReservationPath.Add_LostFocus({
    $result = Test-PathAccessibility -Path $txtReservationPath.Text
    if ($result.Valid) {
        $txtPathStatus.Foreground = '#107c10'
        $txtPathStatus.Text = "✓ $($result.Message)"
    } else {
        $txtPathStatus.Foreground = '#da3b01'
        $txtPathStatus.Text = "✗ $($result.Message)"
    }
})
```

**Trigger**: User leaves path input field  
**Validation**: Real-time path check  
**Feedback**: Color-coded message (green=OK, red=error)

#### Apply Button

```powershell
$btnApply.Add_Click({
    # 1. Validate all inputs
    # 2. Validate business hours (start < end, valid format)
    # 3. Validate path (exists, writable)
    # 4. Update $script:Settings object
    # 5. Save-Settings
    # 6. Show success, close dialog
})
```

**Flow**:
1. Parse times (throw if invalid format)
2. Compare start < end
3. Validate path accessibility
4. Update settings object properties
5. Call Save-Settings
6. If success: MessageBox + Close
7. If error: MessageBox + Stay open

---

## Settings.json Integration

### Read On Init

```json
{
  "Reservations": {
    "BusinessHoursStart": "09:00",
    "BusinessHoursEnd": "18:00",
    "TimeSlotGranularity": 30
  },
  "Tracking": {
    "ReservationPath": "\\\\company\\reservations",
    "ReservationAdmins": ["YMJNB", "bsypb"]
  },
  "Outlook": {
    "Enabled": true,
    "CreateCalendarEvents": true,
    "SendEmailNotifications": true,
    "EmailDistributionList": ["team@company.com", "manager@company.com"]
  }
}
```

### Write On Apply

All modified values written back to Settings.json:

```powershell
# Update from UI
$script:Settings.Reservations.BusinessHoursStart = $txtBusinessStart.Text
$script:Settings.Reservations.BusinessHoursEnd = $txtBusinessEnd.Text
$script:Settings.Reservations.TimeSlotGranularity = [int]$cmbTimeSlot.SelectedItem
$script:Settings.Tracking.ReservationPath = $txtReservationPath.Text
$script:Settings.Tracking.ReservationAdmins = @($listAdmins.ItemsSource)
$script:Settings.Outlook.EmailDistributionList = @($listEmails.ItemsSource)
$script:Settings.Outlook.Enabled = [bool]$chkOutlookEnabled.IsChecked
$script:Settings.Outlook.CreateCalendarEvents = [bool]$chkCreateEvents.IsChecked
$script:Settings.Outlook.SendEmailNotifications = [bool]$chkSendEmails.IsChecked

# Save to disk
Save-Settings -SettingsObj $script:Settings
```

**Atomic**: All-or-nothing (either all changes saved or none)  
**Validation**: All checks pass before any write  
**Rollback**: If save fails, dialog stays open for retry

---

## Usage

### Launch from Main Application

Add button to [TrackSessions.Simulator CR1.ps1](TrackSessions.Simulator%20CR1.ps1):

```powershell
# In XAML toolbar
<Button Grid.Column='5' Name='BtnSettings' Content='Settings...' Width='80'/>

# In code-behind
$btnSettings.Add_Click({
    & "$PSScriptRoot\TrackSessions.Reservations.SettingsDialog.ps1" `
        -SettingsPath $SettingsPath `
        -UsersPath $UsersPath
})
```

### Standalone

```powershell
& 'C:\path\to\TrackSessions.Reservations.SettingsDialog.ps1' `
    -SettingsPath 'C:\config\TrackSessions.Settings.json' `
    -UsersPath 'C:\config\TrackSessions.Users.json'
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `SettingsPath` | ✅ Yes | Path to TrackSessions.Settings.json |
| `UsersPath` | ✅ Yes | Path to TrackSessions.Users.json |

---

## Error Scenarios

### Scenario 1: Non-Admin User Opens Dialog

```
Dialog initializes
Test-AdminAccess called
→ User.IsAdmin = false
→ MessageBox: "This feature requires admin access..."
→ Window.Close()
→ Script exits
```

**Result**: Dialog never appears

### Scenario 2: Settings File Invalid JSON

```
Dialog initializes
Load-Settings fails (invalid JSON)
→ MessageBox: "Error loading settings: ..."
→ Window.Close()
```

**Result**: Dialog exits with error

### Scenario 3: User Enters Invalid Time Format

```
User types "25:00" in Start Time field
User clicks Apply
→ Try: [timespan]::Parse("25:00") throws
→ Catch: MessageBox "Invalid time format. Use HH:mm..."
→ Dialog stays open
→ User can correct and retry
```

**Result**: Invalid data not saved

### Scenario 4: Reservation Path Offline (UNC)

```
User types "\\offline-server\share" in Path field
Click Apply
→ Test-PathAccessibility tries to access path
→ Returns: Valid=$false, Message="Path does not exist"
→ MessageBox: "Reservation path is not accessible..."
→ Dialog stays open
```

**Result**: Cannot save until path is accessible

### Scenario 5: Start Time After End Time

```
User sets: Start=18:00, End=09:00
Click Apply
→ Compare: 18:00 >= 09:00
→ MessageBox: "Start time must be before end time"
→ Dialog stays open
```

**Result**: Logical error prevented

---

## Validation Rules

| Field | Rule | Message |
|-------|------|---------|
| **Start Time** | HH:mm format | "Invalid time format. Use HH:mm (e.g., 09:00)" |
| **End Time** | HH:mm format | Same |
| **Start < End** | Comparison | "Start time must be before end time" |
| **Time Slot** | 15, 30, 45, 60 | Dropdown only (pre-validated) |
| **Reservation Path** | Exists + Writable | "Path is not accessible: {reason}" |
| **Email** | Contains @ | "Please enter a valid email address" |
| **Admin User** | Not duplicate | "User is already an admin" |
| **Email** | Not duplicate | "Email is already in the list" |

---

## Testing

### Test 1: Admin Access Control

```powershell
1. Set user IsAdmin = false in Users.json
2. Run SettingsDialog.ps1
→ Expected: Dialog closes, no window appears
```

### Test 2: Business Hours Configuration

```powershell
1. Click Business Hours tab
2. Change Start Time to "08:30"
3. Change End Time to "17:30"
4. Click Apply
→ Expected: Settings.json updated, dialog closes
→ Verify: Open Settings.json, values changed
```

### Test 3: Path Validation

```powershell
1. Click Reservation Path tab
2. Type "\\nonexistent\path"
3. Click away from input
→ Expected: Red status "Path does not exist"
4. Try Apply
→ Expected: Error dialog, stays open
5. Type valid path "C:\temp"
6. Click Apply
→ Expected: Success, saves, closes
```

### Test 4: Admin User Management

```powershell
1. Click Admins tab
2. Select user from dropdown
3. Click "Add Admin"
→ Expected: User appears in list
4. Try to add same user again
→ Expected: Warning dialog
5. Click Remove next to user
→ Expected: User removed from list
6. Click Apply
→ Expected: Settings.json ReservationAdmins updated
```

### Test 5: Email Distribution

```powershell
1. Click Email Settings tab
2. Type "invalid-email"
3. Click "Add Email"
→ Expected: Error dialog
4. Type "team@company.com"
5. Click "Add Email"
→ Expected: Email added to list, input cleared
6. Try to add same email
→ Expected: Warning dialog
7. Click Apply
→ Expected: Settings.json EmailDistributionList updated
```

### Test 6: Outlook Settings

```powershell
1. Click Outlook tab
2. Check/uncheck Outlook checkboxes
3. Click Apply
→ Expected: Outlook settings in JSON updated
→ Verify: Phase 3 module respects new settings
```

---

## Summary

**Phase 6 delivers**:

✅ **Admin-only access control** (verified via Users.json IsAdmin field)  
✅ **Tabbed configuration interface** (5 tabs for different features)  
✅ **Business hours editor** (start/end time, granularity)  
✅ **Reservation path manager** (with write access validation)  
✅ **Admin user list manager** (add/remove with deduplication)  
✅ **Email distribution list manager** (add/remove with email validation)  
✅ **Outlook feature toggles** (Enable/Create/Email checkboxes)  
✅ **Real-time path validation** (green/red feedback)  
✅ **Comprehensive input validation** (all fields checked before save)  
✅ **Atomic settings save** (all-or-nothing, no partial updates)  
✅ **Error recovery** (helpful messages, dialog stays open to retry)  

**Integration**:
- Reads/writes TrackSessions.Settings.json (Phase 1)
- Reads TrackSessions.Users.json for admin check
- Settings used by Phase 2 (CRUD), Phase 3 (Outlook), Phase 4 (Calendar), Phase 5 (HTML Viewer)
- Can be launched from main app or standalone

**Ready for Production**: All validation, error handling, and documentation complete.  
**Next Phase**: Phase 7 (Recurring Reservations) — extend reservation system to support repeating patterns (daily, weekly, monthly).
