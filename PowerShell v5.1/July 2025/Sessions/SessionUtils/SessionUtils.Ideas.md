# SessionUtils Ideas and Enhancement Notes

**Created:** September 19, 2026  
**Purpose:** Track ideas, enhancements, and reference information for SessionUtils tools

---

## Teams Integration - URL Support

### Teams URL Formats

Microsoft Teams supports several URL formats for deep linking to conversations, channels, and meetings:

#### 1. Channel URL (Get Link to Channel)
```
https://teams.microsoft.com/l/channel/19%3a1203fd26b4cf4b06a8b51ae2b82c4a38%40thread.v2/General?groupId=abc123&tenantId=def456
```
**How to get:**
- Right-click on a channel name in Teams
- Select "Get link to channel"
- Paste the URL

**Parameters:**
- `19:...@thread.v2` - Channel thread ID
- `groupId` - Team ID
- `tenantId` - Organization tenant ID

#### 2. Group Chat URL
```
https://teams.microsoft.com/l/chat/19:1203fd26b4cf4b06a8b51ae2b82c4a38@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D
```
**How to get:**
- Right-click on a group chat in Teams chat list
- Select "Get link to chat"
- Paste the URL

**Parameters:**
- `19:...@thread.v2` - Chat thread ID
- `context` - JSON context (URL encoded)

#### 3. Meeting Chat URL
```
https://teams.microsoft.com/l/meetingchat/19:meeting_abc123@thread.v2?context=%7B%22Tid%22%3A%22def456%22%7D
```
**How to get:**
- In a meeting chat, click the "..." menu
- Select "Get link to conversation"
- Paste the URL

**Parameters:**
- `19:meeting_...@thread.v2` - Meeting chat thread ID
- `Tid` - Tenant ID

#### 4. 1:1 Chat (Deep Link Protocol)
```
msteams:/l/chat/0/0?users=john.doe@irs.gov&message=Hello
```
**Parameters:**
- `users` - Email address (URL encoded)
- `message` - Pre-filled message text (optional, URL encoded)

**Note:** This format is programmatically constructed, not obtained from Teams UI

#### 5. Group Chat with Multiple Users (Deep Link Protocol)
```
msteams:/l/chat/0/0?users=john.doe@irs.gov,jane.smith@irs.gov&message=Group chat
```
**Parameters:**
- `users` - Comma-separated email addresses (URL encoded)
- `message` - Pre-filled message text (optional)

**Use case:** Start group chats programmatically

---

## Implementation Notes

### Current Implementation (CreateEmailEventAndTeamsChat.Prototype.ps1)

**Dual-Mode Design:**
- **Email Mode**: Uses deep link protocol `msteams:/l/chat/0/0?users=email`
- **URL Mode**: Launches any `https://teams.microsoft.com/` URL directly

**Advantages:**
- Simple UI with radio buttons
- No complex URL parsing needed
- Supports all Teams URL types (channel, group chat, meeting)
- Message pre-fill only works in Email mode (by design)

**Limitations:**
- Message parameter not supported for https:// URLs
- User must manually obtain Teams URLs (right-click in Teams)
- No validation beyond basic URL prefix check

### Future Enhancement Ideas

#### 1. URL Validation
**Current:** Basic prefix check `^https://teams\.microsoft\.com/`  
**Enhancement:** Regex validation for specific URL patterns

```powershell
function Test-TeamsUrlValid {
    param([string]$Url)
    
    $patterns = @(
        '^https://teams\.microsoft\.com/l/channel/19%3a[^/]+/[^?]+\?groupId=',
        '^https://teams\.microsoft\.com/l/chat/19:[^/]+/conversations\?',
        '^https://teams\.microsoft\.com/l/meetingchat/19:meeting_[^?]+\?'
    )
    
    foreach ($pattern in $patterns) {
        if ($Url -match $pattern) {
            return $true
        }
    }
    return $false
}
```

#### 2. Auto-Detect Input Type
**Idea:** Single input field, automatically detect whether input is email or URL

```powershell
function Get-TeamsInputType {
    param([string]$Input)
    
    if ($Input -match '^https://teams\.microsoft\.com/') {
        return 'URL'
    }
    elseif ($Input -match '^[^@]+@[^@]+\.[^@]+$') {
        return 'Email'
    }
    else {
        return 'Unknown'
    }
}
```

**Pros:** Simpler UI (no radio buttons)  
**Cons:** Ambiguous inputs, less user control

#### 3. URL Parsing and Display
**Idea:** Parse Teams URLs and show friendly information

```powershell
function Get-TeamsUrlInfo {
    param([string]$Url)
    
    if ($Url -match '/l/channel/.*?/([^?]+)') {
        return "Channel: $($matches[1])"
    }
    elseif ($Url -match '/l/chat/') {
        return "Group Chat"
    }
    elseif ($Url -match '/l/meetingchat/') {
        return "Meeting Chat"
    }
    return "Teams Conversation"
}
```

**Display:** Show parsed info next to URL input field

#### 4. Teams API Integration
**Idea:** Use Microsoft Graph API to:
- List user's recent Teams conversations
- Search for channels by name
- Get channel URLs programmatically

**Requirements:**
- Graph API authentication (Azure AD app registration)
- `Chat.Read`, `Channel.ReadBasic.All` permissions
- More complex implementation

**Benefit:** No need to manually copy URLs from Teams

#### 5. Clipboard Monitoring
**Idea:** Auto-detect when Teams URL is copied to clipboard

```powershell
$clipboardWatcher = New-Object System.Windows.Forms.Timer
$clipboardWatcher.Interval = 500
$clipboardWatcher.Add_Tick({
    $clipText = [System.Windows.Forms.Clipboard]::GetText()
    if ($clipText -match '^https://teams\.microsoft\.com/') {
        $txtTeamsUrl.Text = $clipText
        $rbTeamsUrl.IsChecked = $true
    }
})
$clipboardWatcher.Start()
```

**Pros:** Seamless UX - just copy URL in Teams  
**Cons:** Continuous polling, privacy concerns

---

## Other Enhancement Ideas

### Email Tab Enhancements

#### 1. HTML Body Support
**Current:** Plain text body only  
**Enhancement:** Add checkbox to switch between plain text and HTML

```powershell
if ($chkHtmlBody.IsChecked) {
    $mail.HTMLBody = $txtEmailBody.Text
}
else {
    $mail.Body = $txtEmailBody.Text
}
```

#### 2. Email Templates
**Idea:** Save/load frequently used email templates

**Features:**
- Template dropdown
- Save current email as template
- Templates stored in JSON file
- Include To/CC/Subject/Body

#### 3. Attachment Support
**Enhancement:** Add file picker to attach files to email

```powershell
$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $mail.Attachments.Add($openFileDialog.FileName)
}
```

#### 4. Signature Detection
**Enhancement:** Auto-detect and append Outlook signature

```powershell
$signature = $outlook.Session.Accounts | Select-Object -First 1 | 
    Select-Object -ExpandProperty DefaultSignature
if ($signature) {
    $mail.Body += "`n`n$signature"
}
```

### Event Tab Enhancements

#### 1. Recurring Events
**Enhancement:** Add recurrence pattern options

**UI Elements:**
- Checkbox: "Make Recurring"
- Dropdown: Daily/Weekly/Monthly/Yearly
- End date picker

```powershell
$recurrencePattern = $appointment.GetRecurrencePattern()
$recurrencePattern.RecurrenceType = 1  # olRecursWeekly
$recurrencePattern.DayOfWeekMask = 2   # Monday
$recurrencePattern.PatternEndDate = $endDate
```

#### 2. Teams Meeting Button
**Enhancement:** Add "Make Teams Meeting" checkbox

```powershell
if ($chkTeamsMeeting.IsChecked) {
    $appointment.Location = "Microsoft Teams Meeting"
    # Add Teams meeting link (requires Graph API)
}
```

#### 3. Room Finder Integration
**Enhancement:** Query Exchange for available meeting rooms

**UI:** Dropdown populated with available rooms for selected time slot

#### 4. Event Templates
**Similar to email templates** - save/load common meeting configurations

### Teams Tab Enhancements

#### 1. Recent Conversations
**Enhancement:** Show list of recent Teams conversations

**UI:** Dropdown or list showing:
- Recent 1:1 chats
- Recent group chats
- Recently used channels

**Data Source:** Microsoft Graph API or local Teams cache

#### 2. Favorite Channels
**Enhancement:** Quick-access list of favorited channels

**Storage:** JSON file with channel names and URLs

#### 3. Teams Status Integration
**Enhancement:** Show current Teams status (Available/Busy/DND)

**API:** Microsoft Graph presence API

```powershell
# GET https://graph.microsoft.com/v1.0/me/presence
$presence = Invoke-RestMethod -Uri $presenceUrl -Headers $headers
$txtTeamsStatus.Text = "Status: $($presence.availability)"
```

### General UI Enhancements

#### 1. Dark Mode
**Enhancement:** Add theme toggle (Light/Dark)

**Implementation:**
- Define resource dictionaries for each theme
- Toggle Background/Foreground colors dynamically

#### 2. Window Size Persistence
**Enhancement:** Remember window size and position

**Storage:** Save to registry or JSON config file

```powershell
$config = @{
    WindowLeft = $window.Left
    WindowTop = $window.Top
    WindowWidth = $window.Width
    WindowHeight = $window.Height
}
$config | ConvertTo-Json | Set-Content 'config.json'
```

#### 3. Keyboard Shortcuts
**Enhancement:** Add hotkeys for common actions

**Examples:**
- `Ctrl+E` - Switch to Email tab
- `Ctrl+C` - Switch to Calendar tab
- `Ctrl+T` - Switch to Teams tab
- `Ctrl+S` - Create/Send (context-aware)

#### 4. Multi-Language Support
**Enhancement:** Localization for different languages

**Implementation:**
- Resource strings in separate files
- Language selector in settings

#### 5. Help Dialog
**Enhancement:** Add Help button with usage instructions

**Content:**
- How to get Teams URLs
- Keyboard shortcuts
- Troubleshooting tips

---

## Technical Improvements

### 1. Error Logging
**Enhancement:** Log errors to file for troubleshooting

```powershell
function Write-ErrorLog {
    param([string]$Message)
    
    $logPath = "$env:TEMP\CreateEmailEventAndTeamsChat.log"
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp - ERROR: $Message" | Add-Content $logPath
}
```

### 2. Async Operations
**Enhancement:** Make COM operations async to prevent UI freezing

**Pattern:** Use runspaces for Outlook COM calls

### 3. Configuration File
**Enhancement:** Centralized settings in JSON

**Settings:**
- Default email sender
- Default event duration
- Default reminder time
- Theme preference
- Window position/size

### 4. Unit Tests
**Enhancement:** Add Pester tests for functions

**Test Coverage:**
- URL validation
- User context detection
- Date/time parsing
- Input validation

### 5. Modular Architecture
**Enhancement:** Split into separate modules

**Modules:**
- `OutlookModule.psm1` - Email and event functions
- `TeamsModule.psm1` - Teams integration
- `UIModule.psm1` - WPF helpers
- `ConfigModule.psm1` - Settings management

---

## Integration Ideas

### 1. Outlook Add-in
**Idea:** Create Outlook add-in version of this tool

**Benefits:**
- Integrated into Outlook ribbon
- Access to Outlook context (selected messages, calendar)
- No separate window needed

### 2. PowerShell Module
**Idea:** Package as installable PowerShell module

```powershell
Install-Module -Name SessionUtils
Import-Module SessionUtils
Show-EmailEventTeamsCreator
```

### 3. System Tray Application
**Idea:** Run minimized in system tray

**Features:**
- Global hotkey to show window
- Quick create via context menu
- Notifications for created items

### 4. SharePoint Integration
**Idea:** Web-based version for SharePoint

**Benefits:**
- No installation needed
- Accessible from any browser
- Team-wide access

---

## Known Limitations

### Teams URL Limitations

1. **Message Pre-fill**: Only works with `msteams://` deep links, not `https://` URLs
2. **URL Format Changes**: Microsoft may change URL structure in future Teams versions
3. **Tenant Restrictions**: Some orgs block external Teams URLs
4. **Browser Handling**: Teams URLs may open in browser instead of app (browser default)

### Outlook COM Limitations

1. **Outlook Must Be Installed**: No web-based Outlook support
2. **COM Threading**: Single-threaded apartment model - can cause UI delays
3. **Security Prompts**: Outlook may show security warnings for programmatic access
4. **Version Differences**: COM object model varies across Outlook versions

### General Limitations

1. **Windows Only**: WPF limits to Windows platform
2. **PowerShell 5.1**: Desktop edition required (not Core/7+)
3. **Active Directory**: User context detection requires domain membership
4. **Network Dependency**: AD queries require network connectivity

---

## Future Roadmap

### Phase 1: Current Implementation ✅
- [x] Email creation via Outlook COM
- [x] Calendar event creation
- [x] Teams 1:1 chat via email
- [x] Basic UI with tabs

### Phase 2: Enhanced Teams Integration ✅ (In Progress)
- [x] Dual-mode Teams (email + URL)
- [x] User context display
- [x] Live status bar with date/time
- [ ] URL validation improvements
- [ ] Clipboard monitoring for URLs

### Phase 3: Rich Features
- [ ] Email templates
- [ ] Event templates
- [ ] HTML email support
- [ ] Attachment support
- [ ] Recurring events
- [ ] Teams meeting integration

### Phase 4: Polish & Performance
- [ ] Dark mode
- [ ] Keyboard shortcuts
- [ ] Window state persistence
- [ ] Error logging
- [ ] Async COM operations
- [ ] Configuration file

### Phase 5: Advanced Integration
- [ ] Microsoft Graph API integration
- [ ] Recent conversations list
- [ ] Room finder
- [ ] Presence status
- [ ] Outlook add-in version

---

## References

### Microsoft Documentation

- **Teams Deep Links**: https://learn.microsoft.com/en-us/microsoftteams/platform/concepts/build-and-test/deep-links
- **Outlook Object Model**: https://learn.microsoft.com/en-us/office/vba/api/overview/outlook/object-model
- **Microsoft Graph API**: https://learn.microsoft.com/en-us/graph/overview
- **Teams Graph API**: https://learn.microsoft.com/en-us/graph/api/resources/teams-api-overview

### Related Tools

- **Microsoft Teams Toolkit**: https://aka.ms/teams-toolkit
- **Graph Explorer**: https://developer.microsoft.com/en-us/graph/graph-explorer
- **Outlook Spy**: Tool for COM debugging

---

## Contributing

Ideas and enhancements are welcome! Consider:

1. **User Impact**: How many users benefit?
2. **Complexity**: Implementation effort vs. value
3. **Dependencies**: New libraries or APIs required?
4. **Compatibility**: Works across Windows versions and Outlook/Teams versions?
5. **Performance**: Impact on app startup and responsiveness?

---

**Last Updated:** September 19, 2026  
**Maintainer:** SessionUtils Team
