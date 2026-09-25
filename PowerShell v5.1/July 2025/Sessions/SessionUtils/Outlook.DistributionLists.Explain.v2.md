# Outlook Distribution Lists - Comprehensive Technical Reference v2.0

<a name="top"></a>

**Document Version**: 2.0  
**Last Updated**: 2026-09-19  
**For**: CreateEmailEventAndTeamsChat.Prototype.ps1 and Outlook Integration

---

## Executive Summary

This document provides a comprehensive technical reference for working with Outlook Distribution Lists (DLs) in email, calendar events, and Microsoft Teams. 

**Key Findings**:

- **Email vs Events**: Distribution lists work in both contexts but with important differences. In emails, DLs expand to individual recipients. In calendar events, each member receives an individual invitation and responds separately, allowing the organizer to track acceptance/decline status per person rather than per group.

- **Teams Integration**: Classic distribution lists have limited Microsoft Teams support. For Teams collaboration, use Microsoft 365 Groups instead of traditional DLs. Mail-enabled security groups offer better Teams integration than classic DLs.

- **Outdated Member Detection**: Three primary methods exist: (1) Non-Delivery Reports (NDRs) from emails (30+ minutes), (2) Meeting invitation tracking tab (5 minutes - faster), and (3) PowerShell health check scripts (instant verification requiring Exchange admin access).

- **Naming Conventions**: The ampersand (&) and asterisk (*) prefixes observed in your organization are non-standard but common for organization-specific purposes. Most likely they force groups to sort at the top of address books. Industry standard recommends type-based prefixes like `DL-`, `SG-`, `M365-`.

- **Legacy Outlook**: The Classic Outlook desktop application on Windows 11 provides full COM automation support for PowerShell scripting, including the CreateEmailEventAndTeamsChat tool. The New Outlook (PWA) has limited automation capabilities.

**Quick Reference**:
- Distribution lists work identically in Email (To/CC/BCC) and Events (Required/Optional) fields
- Use semicolons to separate multiple DLs: `DL-Finance@domain.com; DL-IT@domain.com`
- Test meeting invitations provide faster invalid member detection than email NDRs
- PowerShell COM automation: `$outlook.CreateItem(0)` for email, `$outlook.CreateItem(1)` for events
- Microsoft 365 Groups recommended for Teams integration

---

## Table of Contents

1. [Overview](#1-overview)
2. [Types of Groups in Microsoft 365/Exchange](#2-types-of-groups-in-microsoft-365exchange)
   - 2.1 [Distribution Lists (DLs)](#21-distribution-lists-dls)
   - 2.2 [Mail-Enabled Security Groups](#22-mail-enabled-security-groups)
   - 2.3 [Microsoft 365 Groups (Unified Groups)](#23-microsoft-365-groups-unified-groups)
   - 2.4 [Dynamic Distribution Groups](#24-dynamic-distribution-groups)
   - 2.5 [Room Lists (Special Distribution List)](#25-room-lists-special-distribution-list)
3. [Distribution Lists in Email](#3-distribution-lists-in-email)
   - 3.1 [How DLs Work in Email](#31-how-dls-work-in-email)
   - 3.2 [Email Field Usage](#32-email-field-usage)
   - 3.3 [Reply Behavior](#33-reply-behavior)
   - 3.4 [Nested Distribution Lists](#34-nested-distribution-lists)
   - 3.5 [Restrictions](#35-restrictions)
4. [Distribution Lists in Calendar Events](#4-distribution-lists-in-calendar-events)
   - 4.1 [How DLs Work in Calendar Events](#41-how-dls-work-in-calendar-events)
   - 4.2 [Event Field Usage](#42-event-field-usage)
   - 4.3 [Meeting Response Behavior](#43-meeting-response-behavior)
   - 4.4 [Calendar vs Email Differences](#44-calendar-vs-email-differences)
   - 4.5 [Nested DLs in Events](#45-nested-dls-in-events)
   - 4.6 [Meeting Restrictions](#46-meeting-restrictions)
5. [Distribution Lists in Teams](#5-distribution-lists-in-teams)
   - 5.1 [Can You Use DLs in Teams?](#51-can-you-use-dls-in-teams)
   - 5.2 [What Works](#52-what-works)
   - 5.3 [What Doesn't Work](#53-what-doesnt-work)
   - 5.4 [Microsoft 365 Groups in Teams](#54-microsoft-365-groups-in-teams)
   - 5.5 [Summary: Teams + Distribution Lists](#55-summary-teams--distribution-lists)
6. [Detecting Outdated Distribution Lists](#6-detecting-outdated-distribution-lists)
   - 6.1 [The Problem](#61-the-problem)
   - 6.2 [Non-Delivery Reports (NDRs)](#62-non-delivery-reports-ndrs)
   - 6.3 [Types of Delivery Failures](#63-types-of-delivery-failures)
   - 6.4 [Detecting Outdated Members Programmatically](#64-detecting-outdated-members-programmatically)
   - 6.5 [Automated DL Health Checks](#65-automated-dl-health-checks)
   - 6.6 [Best Practices for Detection](#66-best-practices-for-detection)
7. [Naming Conventions](#7-naming-conventions)
   - 7.1 [Your Organization's Conventions](#71-your-organizations-conventions)
   - 7.2 [Common Enterprise Naming Conventions](#72-common-enterprise-naming-conventions)
   - 7.3 [Ampersand (&) and Asterisk (*) Prefixes](#73-ampersand--and-asterisk--prefixes)
   - 7.4 [Standard Microsoft Recommendations](#74-standard-microsoft-recommendations)
   - 7.5 [Determining Your Organization's Convention](#75-determining-your-organizations-convention)
   - 7.6 [Recommended Naming Convention](#76-recommended-naming-convention)
8. [Legacy Outlook on Windows 11](#8-legacy-outlook-on-windows-11)
   - 8.1 [Outlook Versions on Windows 11](#81-outlook-versions-on-windows-11)
   - 8.2 [Distribution List Support in Legacy Outlook](#82-distribution-list-support-in-legacy-outlook)
   - 8.3 [Legacy Outlook COM Automation](#83-legacy-outlook-com-automation)
   - 8.4 [Legacy vs New Outlook Comparison](#84-legacy-vs-new-outlook-comparison)
9. [PowerShell Integration](#9-powershell-integration)
   - 9.1 [Adding DLs to Email (CreateEmailEventAndTeamsChat)](#91-adding-dls-to-email-createemailandeventsteamschat)
   - 9.2 [Adding DLs to Calendar Events](#92-adding-dls-to-calendar-events)
   - 9.3 [Multiple DLs in Same Field](#93-multiple-dls-in-same-field)
   - 9.4 [Validating DL Address](#94-validating-dl-address)
10. [Best Practices](#10-best-practices)
    - 10.1 [Email Best Practices](#101-email-best-practices)
    - 10.2 [Calendar Event Best Practices](#102-calendar-event-best-practices)
    - 10.3 [Distribution List Management](#103-distribution-list-management)
    - 10.4 [NDR Monitoring](#104-ndr-monitoring)
    - 10.5 [Teams Integration](#105-teams-integration)
11. [Summary and Quick Reference](#11-summary-and-quick-reference)
12. [Glossary](#12-glossary)

---

## 1. Overview

[↑ Top](#top)

Distribution lists (DLs) are email groups that allow you to send messages or meeting invitations to multiple recipients using a single address. In Microsoft Exchange and Microsoft 365 environments, there are several types of groups, each with different capabilities.

**Key Question**: Do distribution lists work the same in both Email and Events?

**Answer**: **Almost the same, but with important differences**:
- ✅ You can use DLs in both Email (To/CC/BCC) and Events (Required/Optional/Resources)
- ✅ The same DL address works in both contexts
- ⚠️ **Calendar event behavior differs**: Individual responses (Accept/Decline) from DL members
- ⚠️ **Delivery reports differ**: Email NDRs vs calendar meeting failures
- ⚠️ **Teams integration**: Only certain group types work in Teams

---

## 2. Types of Groups in Microsoft 365/Exchange

[↑ Top](#top)

### 2.1 Distribution Lists (DLs)

[↑ Top](#top)

**Classic Exchange Distribution Lists**

**Characteristics**:
- Email-only group
- No security permissions
- Managed by IT or designated owners
- Can include internal users, external contacts, other DLs
- Does **not** have a mailbox (cannot receive replies to the group)

**Naming Format**:
```
DL-TeamName@irs.gov
Sales-All@company.com
DIST-Engineering@org.gov
```

**Usage**:
- ✅ Email (To/CC/BCC fields)
- ✅ Calendar events (Required/Optional attendees)
- ❌ Teams channels/chats (not directly - members can be added individually)
- ❌ Cannot assign permissions to resources (SharePoint, folders)

**Example**:
```
DL-Finance-Team@irs.gov
  ├── alice.smith@irs.gov
  ├── bob.jones@irs.gov
  ├── carol.white@irs.gov
  └── DL-Finance-Managers@irs.gov (nested DL)
```

### 2.2 Mail-Enabled Security Groups

[↑ Top](#top)

**Security Group with Email Capability**

**Characteristics**:
- Active Directory security group with email address
- Can be used for **both** email and security permissions
- Managed by IT (typically)
- Membership synced from AD

**Naming Format**:
```
SG-ProjectName@irs.gov
SEC-Finance-ReadOnly@company.com
```

**Usage**:
- ✅ Email (To/CC/BCC fields)
- ✅ Calendar events (Required/Optional attendees)
- ✅ Security permissions (SharePoint, file shares, Azure resources)
- ⚠️ Teams (depends on configuration)

**Example**:
```
SG-Finance-Users@irs.gov
  ├── alice.smith@irs.gov (member)
  ├── bob.jones@irs.gov (member)
  └── Has Read access to \\fileserver\Finance\ share
```

### 2.3 Microsoft 365 Groups (Unified Groups)

[↑ Top](#top)

**Modern Collaboration Groups**

**Characteristics**:
- Has **shared mailbox** (group inbox)
- Has SharePoint site
- Has Planner, Calendar, OneNote
- Optionally has Teams team
- Members can reply to group emails (conversations)

**Naming Format**:
```
ProjectAlpha@company.com
Team-Marketing@irs.gov
```

**Usage**:
- ✅ Email (To/CC/BCC) - replies go to group mailbox
- ✅ Calendar events
- ✅ Teams (can be converted to/from Teams team)
- ✅ SharePoint site permissions
- ✅ Collaborative workspace

**Example**:
```
ProjectAlpha@company.com
  ├── Mailbox: group.projectalpha@company.com
  ├── SharePoint: https://company.sharepoint.com/sites/ProjectAlpha
  ├── Calendar: Shared group calendar
  ├── Teams: ProjectAlpha team (if enabled)
  └── Members: alice, bob, carol
```

### 2.4 Dynamic Distribution Groups

[↑ Top](#top)

**Membership Based on Query/Rules**

**Characteristics**:
- Membership auto-populated based on Active Directory attributes
- No manual member management
- Updated automatically when user attributes change

**Naming Format**:
```
DDL-AllManagers@irs.gov
DYN-SalesReps-EastRegion@company.com
```

**Usage**:
- ✅ Email (To/CC/BCC fields)
- ✅ Calendar events
- ⚠️ Teams (not recommended - membership changes unpredictably)

**Example**:
```
DDL-AllManagers@irs.gov
  Query: (Department = '*') AND (Title contains 'Manager')
  Auto-includes: Any user whose title contains "Manager"
```

### 2.5 Room Lists (Special Distribution List)

[↑ Top](#top)

**For Booking Conference Rooms**

**Characteristics**:
- Special DL containing room mailboxes
- Used in Outlook Room Finder
- Shows room availability

**Naming Format**:
```
RL-Building1-Rooms@irs.gov
RoomList-HQ-ConferenceRooms@company.com
```

**Usage**:
- ✅ Calendar events (Room Finder)
- ✅ Resource scheduling
- ❌ Regular email (not typically used for email)

---

## 3. Distribution Lists in Email

[↑ Top](#top)

### 3.1 How DLs Work in Email

[↑ Top](#top)

When you send an email to a distribution list:

1. **Expansion**: Exchange server expands the DL into individual recipient addresses
2. **Delivery**: Email is delivered to each member's mailbox individually
3. **Reply Behavior**: Depends on "Reply To" settings

### 3.2 Email Field Usage

[↑ Top](#top)

#### 3.2.1 To Field

[↑ Top](#top)

```
To: DL-Finance-Team@irs.gov
```
- All members receive the email in their **To** field
- Each member sees they are part of the group recipient
- Good for: Primary recipients who should take action

#### 3.2.2 CC Field

[↑ Top](#top)

```
To: alice.smith@irs.gov
CC: DL-Finance-Team@irs.gov
```
- All DL members receive as **CC** (for information only)
- Indicates "FYI" rather than requiring action
- Good for: Keeping teams informed

#### 3.2.3 BCC Field

[↑ Top](#top)

```
To: alice.smith@irs.gov
BCC: DL-Finance-Team@irs.gov
```
- All DL members receive the email
- **DL members cannot see they are BCC'd**
- **DL members cannot see each other** in the recipient list
- Good for: Privacy, large announcements, blind copies

#### 3.2.4 Email Expansion Details

[↑ Top](#top)

**What recipients see**:

Scenario 1: **Regular DL in To field**
```
From: alice.smith@irs.gov
To: DL-Finance-Team@irs.gov

Recipients see:
  To: DL-Finance-Team@irs.gov
  (They know they received via DL)
```

Scenario 2: **DL with "Hide membership" enabled**
```
From: alice.smith@irs.gov
To: DL-Finance-Team@irs.gov

Recipients see:
  To: bob.jones@irs.gov (their individual address)
  (They don't know they received via DL)
```

### 3.3 Reply Behavior

[↑ Top](#top)

**Default Reply Behavior**:
```
Original Email:
  From: alice.smith@irs.gov
  To: DL-Finance-Team@irs.gov

When bob.jones@irs.gov clicks "Reply":
  To: alice.smith@irs.gov (original sender only)

When bob.jones@irs.gov clicks "Reply All":
  To: alice.smith@irs.gov
  CC: DL-Finance-Team@irs.gov (entire group)
```

**Configured "Reply To" Address**:
If DL has "Reply To" configured:
```
DL-Finance-Team@irs.gov
  ReplyTo: finance-inbox@irs.gov

When recipient clicks "Reply":
  To: finance-inbox@irs.gov (custom reply address)
```

### 3.4 Nested Distribution Lists

[↑ Top](#top)

DLs can contain other DLs:

```
DL-AllStaff@irs.gov
  ├── DL-Engineering@irs.gov
  │     ├── alice.smith@irs.gov
  │     └── bob.jones@irs.gov
  ├── DL-Finance@irs.gov
  │     ├── carol.white@irs.gov
  │     └── dave.brown@irs.gov
  └── jane.doe@irs.gov (individual member)

Email to DL-AllStaff expands to:
  alice.smith@irs.gov
  bob.jones@irs.gov
  carol.white@irs.gov
  dave.brown@irs.gov
  jane.doe@irs.gov
```

**Maximum Nesting Depth**: Typically 10 levels (Exchange limit)

### 3.5 Restrictions

[↑ Top](#top)

**Send Restrictions**:
- **Open** (anyone can send): `DL-Announcements@irs.gov`
- **Internal only** (only organization members): `DL-Internal-Staff@irs.gov`
- **Approved senders only** (whitelist): `DL-Executives@irs.gov`
- **Owner approval required** (moderated): `DL-PublicAnnouncements@irs.gov`

**Size Restrictions**:
- **Message size limit**: Inherited from Exchange org (e.g., 25 MB)
- **Recipient limit**: Typically 5,000 recipients per DL
- **Expansion limit**: Total recipients after nested expansion (e.g., 10,000)

---

## 4. Distribution Lists in Calendar Events

[↑ Top](#top)

### 4.1 How DLs Work in Calendar Events

[↑ Top](#top)

When you invite a distribution list to a meeting:

1. **Expansion**: Exchange expands DL to individual members
2. **Invitations Sent**: Each member receives individual calendar invitation
3. **Individual Responses**: Each member can Accept/Decline/Tentative separately
4. **Organizer Tracking**: Organizer sees each member's response individually

### 4.2 Event Field Usage

[↑ Top](#top)

#### 4.2.1 Required Attendees

[↑ Top](#top)

```
Required Attendees: DL-Finance-Team@irs.gov
```
- All members receive meeting invitation
- Marked as **required** (busy time blocked)
- Their responses affect meeting quorum/attendance count

#### 4.2.2 Optional Attendees

[↑ Top](#top)

```
Optional Attendees: DL-Marketing-Team@irs.gov
```
- All members receive meeting invitation
- Marked as **optional** (free time, can decline without guilt)
- Responses tracked but not critical

#### 4.2.3 Resources (Room/Equipment)

[↑ Top](#top)

```
Resources: RL-Building1-Rooms@irs.gov
```
- Room list DL for booking conference rooms
- Can auto-accept if configured
- Shows availability in Room Finder

### 4.3 Meeting Response Behavior

[↑ Top](#top)

**Individual Responses**:

```
Meeting Invitation:
  Organizer: alice.smith@irs.gov
  Required: DL-Finance-Team@irs.gov (3 members)

DL expands to:
  - bob.jones@irs.gov → Accepts
  - carol.white@irs.gov → Declines
  - dave.brown@irs.gov → Tentative

Organizer sees:
  Accepted: bob.jones@irs.gov (1)
  Declined: carol.white@irs.gov (1)
  Tentative: dave.brown@irs.gov (1)
  No Response: 0
```

**Important**: The organizer sees **individual responses**, not the DL as a single entity.

### 4.4 Calendar vs Email Differences

[↑ Top](#top)

| Feature | Email | Calendar Event |
|---------|-------|----------------|
| **Recipient field** | To/CC/BCC | Required/Optional/Resources |
| **Expansion** | Expanded at send time | Expanded at send time |
| **Responses** | N/A (no response tracking) | Individual Accept/Decline/Tentative |
| **Visibility** | Recipients see DL name (unless hidden) | Recipients see individual invites |
| **Reply behavior** | Reply/Reply All | Accept/Decline/Propose New Time |
| **Tracking** | Delivery receipt (if requested) | Meeting tracking tab (individual responses) |

### 4.5 Nested DLs in Events

[↑ Top](#top)

```
Meeting Invitation:
  Required: DL-AllStaff@irs.gov
    └── Contains DL-Engineering@irs.gov (50 people)
        └── Contains DL-Engineering-Backend@irs.gov (20 people)

Result:
  - All 50+ individuals receive calendar invitation
  - Each can respond independently
  - Organizer sees 50+ separate response lines
```

**Caution**: Large nested DLs can result in hundreds of meeting responses flooding the organizer's inbox.

### 4.6 Meeting Restrictions

[↑ Top](#top)

**Forwarding**:
- Attendees can forward meeting invitations
- Forwarded recipients are **not tracked** by organizer
- Can cause confusion about who is actually attending

**Delegation**:
- Attendees can delegate to colleagues
- Delegate responses show as "Accepted on behalf of [original attendee]"

**Out of Office**:
- If DL member has OOO auto-reply enabled, organizer receives OOO message
- With large DLs, organizer can receive dozens of OOO replies

---

## 5. Distribution Lists in Teams

[↑ Top](#top)

### 5.1 Can You Use DLs in Teams?

[↑ Top](#top)

**Short Answer**: **Sort of, but with limitations.**

### 5.2 What Works

[↑ Top](#top)

#### 5.2.1 Mentioning Distribution Lists in Chat

[↑ Top](#top)

**In Teams Chat/Channel**:
```
@DL-Finance-Team
```

**Behavior**:
- ✅ Works if DL is **mail-enabled security group**
- ⚠️ May work for classic DLs (depends on tenant settings)
- ❌ Does NOT work for regular distribution lists (most common)
- Notification sent to all members of the group

**Limitation**: Cannot @mention a DL that is not mail-enabled security group in most tenants.

#### 5.2.2 Starting Group Chat with DL Members

[↑ Top](#top)

**Not Directly**:
- ❌ Cannot add `DL-Finance-Team@irs.gov` to a Teams chat
- ✅ Workaround: Add members individually (tedious)

**Alternative**:
- Create a **Teams Channel** and add members
- Convert Microsoft 365 Group to Teams team

#### 5.2.3 Email to Teams Channel

[↑ Top](#top)

**Email-to-Channel Feature**:
```
Channel Email Address: finance-team-general@company.com
```

- Each Teams channel can have an email address
- Send email to channel address → appears as post in Teams
- Can CC/BCC distribution lists → all members receive email → can view in Teams

**Workflow**:
```
Email:
  To: finance-team-general@company.com
  CC: DL-External-Partners@company.com

Result:
  - Post appears in Finance Team > General channel
  - DL members receive email (can reply via email or Teams)
```

### 5.3 What Doesn't Work

[↑ Top](#top)

❌ **Cannot add DL as a Teams member**:
```
Team: Finance Team
Members: 
  ✅ alice.smith@irs.gov (individual)
  ✅ SG-Finance-Admins@irs.gov (mail-enabled security group)
  ❌ DL-Finance-Team@irs.gov (distribution list - not allowed)
```

❌ **Cannot schedule Teams meeting with DL**:
- When you add DL to Teams meeting, it expands to individuals
- Individuals are invited, not the DL entity
- Same behavior as Outlook calendar (individual invites)

### 5.4 Microsoft 365 Groups in Teams

[↑ Top](#top)

**Best Integration**:

Microsoft 365 Groups are the **preferred** group type for Teams:

```
Microsoft 365 Group: ProjectAlpha@company.com
  ├── Email: projectalpha@company.com
  ├── SharePoint: https://company.sharepoint.com/sites/ProjectAlpha
  └── Teams: ProjectAlpha team (linked)

Workflow:
  1. Create Microsoft 365 Group
  2. Enable Teams for the group
  3. Email to projectalpha@company.com → goes to group mailbox
  4. Members see email in Outlook and Teams
  5. Can chat, meet, collaborate in Teams
```

### 5.5 Summary: Teams + Distribution Lists

[↑ Top](#top)

| Group Type | Add to Team | @Mention in Chat | Schedule Meeting | Email to Channel |
|------------|-------------|------------------|------------------|------------------|
| **Classic Distribution List** | ❌ | ❌ (usually) | ⚠️ Expands to individuals | ✅ Via email |
| **Mail-Enabled Security Group** | ✅ | ✅ | ⚠️ Expands to individuals | ✅ Via email |
| **Microsoft 365 Group** | ✅ | ✅ | ✅ | ✅ |
| **Dynamic Distribution Group** | ❌ | ❌ | ⚠️ Expands to individuals | ✅ Via email |

**Recommendation**: For Teams integration, use **Microsoft 365 Groups** or **mail-enabled security groups**, not classic distribution lists.

---

## 6. Detecting Outdated Distribution Lists

[↑ Top](#top)

### 6.1 The Problem

[↑ Top](#top)

Distribution lists can become outdated when:
- Members leave the organization (mailboxes disabled/deleted)
- Members change roles (no longer relevant to the group)
- DL contains invalid email addresses
- Nested DLs are deleted but still referenced

**Symptoms**:
- ✅ Non-Delivery Reports (NDRs) / bounce-back emails
- ⚠️ Meeting invitation failures (attendee not found)
- ⚠️ Silent failures (email delivered to some, not all)

### 6.2 Non-Delivery Reports (NDRs)

[↑ Top](#top)

**What is an NDR?**

An NDR (Non-Delivery Report) is an automatic email notification sent when message delivery fails.

**Example NDR**:
```
From: postmaster@irs.gov
To: alice.smith@irs.gov
Subject: Undeliverable: Q4 Planning Meeting

Your message to the following recipients could not be delivered:

  bob.jones@irs.gov
    Reason: Mailbox does not exist (5.1.1)
    
  carol.white@external.com
    Reason: Recipient address rejected (5.7.1)
```

**NDR for Distribution List**:

When you email `DL-Finance-Team@irs.gov` and it contains invalid members:

```
Original Email:
  To: DL-Finance-Team@irs.gov

NDR Received:
  bob.jones@irs.gov - Mailbox does not exist
  (Other members received the email successfully)
```

**Key Point**: You receive NDRs for **individual failed members**, not the DL itself.

### 6.3 Types of Delivery Failures

[↑ Top](#top)

#### 6.3.1 Permanent Failures (5.x.x codes)

[↑ Top](#top)

**5.1.1 - Mailbox does not exist**:
- User left organization, mailbox deleted
- Email address never existed (typo)

**5.1.2 - Host not found**:
- Domain does not exist
- External recipient domain invalid

**5.7.1 - Sender denied**:
- Your organization not allowed to send to recipient
- Recipient's org blocks your domain

**5.4.1 - Recipient no longer exists**:
- Mailbox disabled
- User account deleted

#### 6.3.2 Temporary Failures (4.x.x codes)

[↑ Top](#top)

**4.4.1 - Connection timed out**:
- Recipient's mail server temporarily unavailable
- Network issue

**4.2.2 - Mailbox full**:
- Recipient's mailbox over quota
- Will bounce until user clears space

#### 6.3.3 Silent Failures

[↑ Top](#top)

**No NDR received**:
- Recipient's server accepts email but discards it (spam filter)
- Email forwarded to invalid address (forwarding breaks)
- Distribution list has "suppress NDRs" enabled (rare)

### 6.4 Detecting Outdated Members Programmatically

[↑ Top](#top)

#### 6.4.1 Method 1: Parse NDRs in Outlook

[↑ Top](#top)

**Manual Process**:
1. Send test email to DL
2. Wait for NDRs (5-30 minutes)
3. Review NDR messages
4. Identify failed recipients

**PowerShell Script to Check Mailbox for NDRs**:

```powershell
# Connect to Outlook
$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")
$inbox = $namespace.GetDefaultFolder(6) # 6 = olFolderInbox

# Find NDRs (typically have "Undeliverable" in subject)
$ndrs = $inbox.Items | Where-Object {
    $_.Subject -match "Undeliverable|Delivery.*fail|Non-Delivery"
}

foreach ($ndr in $ndrs) {
    Write-Host "NDR Received: $($ndr.Subject)"
    Write-Host "Body: $($ndr.Body)"
    Write-Host "---"
}
```

#### 6.4.2 Method 2: Use Exchange PowerShell

[↑ Top](#top)

**Check DL Members Exist** (requires Exchange admin access):

```powershell
# Connect to Exchange Online
Connect-ExchangeOnline

# Get DL members
$dlName = "DL-Finance-Team@irs.gov"
$members = Get-DistributionGroupMember -Identity $dlName

# Check each member's mailbox exists
foreach ($member in $members) {
    try {
        $mailbox = Get-Mailbox -Identity $member.PrimarySmtpAddress -ErrorAction Stop
        Write-Host "✅ Valid: $($member.PrimarySmtpAddress)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ INVALID: $($member.PrimarySmtpAddress) - Mailbox does not exist" -ForegroundColor Red
    }
}
```

#### 6.4.3 Method 3: Test with Meeting Invitation

[↑ Top](#top)

**Send Test Meeting Invitation**:

1. Create calendar event
2. Invite the DL
3. Review "Tracking" tab for failures

**Tracking Tab Shows**:
```
Attendee                Status
alice.smith@irs.gov     Accepted
bob.jones@irs.gov       ⚠️ Not Delivered (mailbox not found)
carol.white@irs.gov     Declined
```

**Failures appear immediately** (within minutes) vs email NDRs (can take 30+ minutes).

### 6.5 Automated DL Health Checks

[↑ Top](#top)

**Script to Validate DL Health**:

```powershell
function Test-DistributionListHealth {
    param(
        [Parameter(Mandatory)][string]$DistributionListEmail
    )
    
    # Connect to Exchange (requires admin)
    Connect-ExchangeOnline -ErrorAction Stop
    
    # Get DL
    $dl = Get-DistributionGroup -Identity $DistributionListEmail -ErrorAction Stop
    $members = Get-DistributionGroupMember -Identity $DistributionListEmail
    
    $report = @{
        TotalMembers = $members.Count
        ValidMembers = 0
        InvalidMembers = @()
        ExternalMembers = @()
    }
    
    foreach ($member in $members) {
        $email = $member.PrimarySmtpAddress
        
        # Check if internal mailbox exists
        if ($email -like "*@irs.gov") {
            try {
                Get-Mailbox -Identity $email -ErrorAction Stop | Out-Null
                $report.ValidMembers++
            }
            catch {
                $report.InvalidMembers += [PSCustomObject]@{
                    Email = $email
                    Reason = "Mailbox does not exist"
                }
            }
        }
        else {
            $report.ExternalMembers += $email
            $report.ValidMembers++ # Assume external emails are valid (can't verify)
        }
    }
    
    # Output report
    Write-Host "`n=== Distribution List Health Report ===" -ForegroundColor Cyan
    Write-Host "DL: $DistributionListEmail"
    Write-Host "Total Members: $($report.TotalMembers)"
    Write-Host "Valid Members: $($report.ValidMembers)" -ForegroundColor Green
    Write-Host "Invalid Members: $($report.InvalidMembers.Count)" -ForegroundColor Red
    Write-Host "External Members: $($report.ExternalMembers.Count)" -ForegroundColor Yellow
    
    if ($report.InvalidMembers.Count -gt 0) {
        Write-Host "`n❌ INVALID MEMBERS:" -ForegroundColor Red
        $report.InvalidMembers | Format-Table -AutoSize
    }
    
    if ($report.ExternalMembers.Count -gt 0) {
        Write-Host "`n⚠️ EXTERNAL MEMBERS (unverified):" -ForegroundColor Yellow
        $report.ExternalMembers | ForEach-Object { Write-Host "  - $_" }
    }
    
    return $report
}

# Usage
Test-DistributionListHealth -DistributionListEmail "DL-Finance-Team@irs.gov"
```

### 6.6 Best Practices for Detection

[↑ Top](#top)

1. **Regular Audits**: Schedule quarterly reviews of DLs
2. **Monitor NDRs**: Set up inbox rule to flag NDRs for review
3. **Test Invitations**: Send test meetings and check tracking tab
4. **Automated Scripts**: Run health check scripts monthly
5. **DL Owner Responsibility**: Assign owners to maintain membership
6. **Expiration Policies**: Set DL expiration dates (require renewal)

---

## 7. Naming Conventions

[↑ Top](#top)

### 7.1 Your Organization's Conventions

[↑ Top](#top)

You mentioned two prefixes:
- **& (Ampersand)** prefix: `&SomeGroupName`
- **\* (Asterisk)** prefix: `*SomeGroupName`

**Question**: Is this a common naming convention?

**Answer**: **Not standard**, but **organization-specific conventions are very common**.

### 7.2 Common Enterprise Naming Conventions

[↑ Top](#top)

#### 7.2.1 Prefix by Group Type

[↑ Top](#top)

**Most Common Pattern**:

| Prefix | Type | Example |
|--------|------|---------|
| `DL-` | Distribution List | `DL-Finance-Team@irs.gov` |
| `SG-` | Security Group | `SG-Admins-Network@irs.gov` |
| `M365-` | Microsoft 365 Group | `M365-ProjectAlpha@irs.gov` |
| `DDL-` | Dynamic Distribution List | `DDL-AllManagers@irs.gov` |
| `RL-` | Room List | `RL-Building1-Rooms@irs.gov` |
| `DIST-` | Distribution List | `DIST-Engineering@company.com` |

#### 7.2.2 Prefix by Department/Function

[↑ Top](#top)

**Organizational Structure**:

| Prefix | Department | Example |
|--------|------------|---------|
| `FIN-` | Finance | `FIN-Accounting@irs.gov` |
| `HR-` | Human Resources | `HR-Recruiting@irs.gov` |
| `IT-` | Information Technology | `IT-Helpdesk@irs.gov` |
| `SALES-` | Sales | `SALES-Northeast@company.com` |
| `ENG-` | Engineering | `ENG-Backend@company.com` |

#### 7.2.3 Prefix by Scope/Audience

[↑ Top](#top)

**Scope Indicators**:

| Prefix | Scope | Example |
|--------|-------|---------|
| `ALL-` | Everyone | `ALL-Staff@irs.gov` |
| `EXEC-` | Executives | `EXEC-Leadership@irs.gov` |
| `MGR-` | Managers | `MGR-AllManagers@irs.gov` |
| `TEAM-` | Specific team | `TEAM-Finance@irs.gov` |

### 7.3 Ampersand (&) and Asterisk (*) Prefixes

[↑ Top](#top)

**Likely Meanings in Your Organization**:

#### 7.3.1 Scenario A: Special Purpose Indicators

[↑ Top](#top)

**& Ampersand** = **Shared/Public Resources**:
- `&PublicAnnouncements` - Open to all staff
- `&CompanyWide` - Entire organization
- `&GeneralResources` - Public/shared resources

**\* Asterisk** = **Restricted/Admin Groups**:
- `*AdminTeam` - Administrators only
- `*ExecutiveStaff` - Executive access
- `*PrivateList` - Restricted membership

#### 7.3.2 Scenario B: Address Book Sorting

[↑ Top](#top)

**Purpose**: Force groups to sort at **top** or **bottom** of address book

**Address Book Sorting**:
```
Outlook Address Book (sorted alphabetically):
  &CompanyWideAnnouncements  ← Appears at top (& sorts before A-Z)
  *ITAdmins                  ← Appears at top (* sorts before A-Z)
  DL-Finance-Team
  DL-HR-Team
  DL-IT-Support
```

**Why This Works**:
- Special characters sort before letters
- Forces important/frequently-used DLs to top of address book
- Easier to find in Outlook's "To" field dropdown

**Common Characters for Sorting**:
- `!` - Exclamation (sorts first)
- `#` - Hash
- `&` - Ampersand
- `*` - Asterisk
- `_` - Underscore

#### 7.3.3 Scenario C: Functional Indicators

[↑ Top](#top)

**& = Active/Live Groups**:
- Currently in use
- Actively maintained

**\* = Legacy/Deprecated Groups**:
- Old groups kept for reference
- Should not be used for new emails
- Pending deletion

#### 7.3.4 Scenario D: Visibility Flags

[↑ Top](#top)

**& = Visible in Global Address List (GAL)**:
- Appears in Outlook address book
- Anyone can see and use

**\* = Hidden from GAL**:
- Does not appear in address book search
- Must know exact address to use
- Private/internal use only

### 7.4 Standard Microsoft Recommendations

[↑ Top](#top)

**Microsoft Best Practices**:

1. **Use descriptive names**: `DL-Finance-Accounting-Team`
2. **Avoid special characters**: Stick to letters, numbers, hyphens
3. **Include type prefix**: `DL-`, `SG-`, `M365-`
4. **Include department**: `DL-Finance-...`
5. **Include purpose**: `DL-Finance-Payroll-Approvers`

**Format**:
```
[Type]-[Department]-[Purpose]-[Audience]
DL-Finance-Payroll-Approvers
SG-IT-Network-Admins
M365-Marketing-Campaign-Team
```

### 7.5 Determining Your Organization's Convention

[↑ Top](#top)

**How to Find Out**:

1. **Check Existing DLs**:
   - Open Outlook
   - Search address book for `&*` or `*`
   - Look for patterns

2. **Ask IT/Exchange Admins**:
   - They defined the naming convention
   - May have documented standards

3. **Review Internal Documentation**:
   - IT wiki, SharePoint, knowledge base
   - Email naming standards document

4. **Examine Distribution List Properties**:
   - Right-click DL in address book → Properties
   - Look at "Display Name" vs "Email Address"
   - Check "Notes" field for purpose description

### 7.6 Recommended Naming Convention

[↑ Top](#top)

**If starting fresh or standardizing**:

```
Format: [TYPE]-[DEPT]-[PURPOSE]

Examples:
  DL-Finance-AllStaff
  DL-Finance-Managers
  DL-IT-Helpdesk
  DL-HR-Recruiting
  
  SG-Finance-SharePointAdmins
  SG-IT-NetworkAdmins
  
  M365-ProjectAlpha-Team
  M365-Marketing-Campaign
```

**Avoid**:
- Special characters (`&`, `*`, `!`, `#`) - causes confusion
- Spaces (use hyphens instead)
- Generic names (`Team`, `Group`, `List`) - not descriptive
- Abbreviations only insiders know

---

## 8. Legacy Outlook on Windows 11

[↑ Top](#top)

### 8.1 Outlook Versions on Windows 11

[↑ Top](#top)

**Two Versions Available**:

1. **Outlook (Classic)** - Legacy desktop app
   - Full feature set
   - COM automation support (PowerShell)
   - Offline capability
   - Plugin/add-in support

2. **New Outlook (PWA)** - Progressive Web App
   - Modern UI
   - Simplified features
   - Cloud-first
   - Limited COM support

**Your Environment**: "Legacy Outlook on Windows 11" = **Outlook Classic**

### 8.2 Distribution List Support in Legacy Outlook

[↑ Top](#top)

#### 8.2.1 Email

[↑ Top](#top)

✅ **Full Support**:
- Add DLs to To/CC/BCC
- Expand DL to see members (optional)
- Reply to DL emails
- Track delivery

**How to Check DL Members**:
```
In Outlook:
1. Type DL name in To field: DL-Finance-Team
2. Click "+" icon or right-click → "Expand Distribution List"
3. See all members listed individually
```

#### 8.2.2 Calendar Events

[↑ Top](#top)

✅ **Full Support**:
- Add DLs to Required/Optional/Resources
- Track responses individually
- Room Finder with room lists

**Behavior**:
- DL expands automatically when you send meeting invitation
- Each member receives individual invite
- Organizer sees individual response tracking

### 8.3 Legacy Outlook COM Automation

[↑ Top](#top)

**PowerShell Integration**:

Your `CreateEmailEventAndTeamsChat.Prototype.ps1` uses COM to automate Outlook:

```powershell
# Create email with DL
$outlook = New-Object -ComObject Outlook.Application
$mail = $outlook.CreateItem(0) # olMailItem
$mail.To = "DL-Finance-Team@irs.gov"
$mail.Subject = "Test Email"
$mail.Body = "This goes to all DL members"
$mail.Display() # Show in Outlook for user to send
```

**Create Calendar Event with DL**:

```powershell
# Create meeting invitation with DL
$outlook = New-Object -ComObject Outlook.Application
$appointment = $outlook.CreateItem(1) # olAppointmentItem
$appointment.Subject = "Q4 Planning Meeting"
$appointment.Location = "Conference Room A"
$appointment.Start = (Get-Date).AddDays(7).Date.AddHours(10) # Next week, 10 AM
$appointment.Duration = 60 # minutes
$appointment.RequiredAttendees = "DL-Finance-Team@irs.gov"
$appointment.OptionalAttendees = "DL-Marketing-Team@irs.gov"
$appointment.Body = "Agenda: Q4 planning and review"
$appointment.Display() # Show in Outlook for user to send
```

#### 8.3.1 Distribution List Expansion in COM

[↑ Top](#top)

**Check if Address is a DL**:

```powershell
function Test-IsDistributionList {
    param([string]$EmailAddress)
    
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")
    
    try {
        # Try to resolve the address
        $recipient = $namespace.CreateRecipient($EmailAddress)
        $resolved = $recipient.Resolve()
        
        if ($resolved) {
            # Check address entry type
            $addressEntry = $recipient.AddressEntry
            if ($addressEntry.AddressEntryUserType -eq 1) { # olExchangeDistributionListAddressEntry
                return $true
            }
        }
        return $false
    }
    catch {
        return $false
    }
}

# Usage
$isDL = Test-IsDistributionList -EmailAddress "DL-Finance-Team@irs.gov"
Write-Host "Is Distribution List: $isDL"
```

**Expand DL Programmatically**:

```powershell
function Expand-DistributionList {
    param([string]$DistributionListEmail)
    
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")
    
    try {
        $recipient = $namespace.CreateRecipient($DistributionListEmail)
        $resolved = $recipient.Resolve()
        
        if ($resolved) {
            $addressEntry = $recipient.AddressEntry
            
            if ($addressEntry.AddressEntryUserType -eq 1) { # DL
                $members = $addressEntry.Members
                
                $memberList = @()
                foreach ($member in $members) {
                    $memberList += [PSCustomObject]@{
                        Name = $member.Name
                        Email = $member.Address
                        Type = $member.AddressEntryUserType
                    }
                }
                return $memberList
            }
        }
    }
    catch {
        Write-Error "Failed to expand DL: $_"
    }
    
    return @()
}

# Usage
$members = Expand-DistributionList -DistributionListEmail "DL-Finance-Team@irs.gov"
$members | Format-Table -AutoSize
```

### 8.4 Legacy vs New Outlook Comparison

[↑ Top](#top)

| Feature | Legacy Outlook (Classic) | New Outlook (PWA) |
|---------|-------------------------|-------------------|
| **Distribution Lists** | ✅ Full support | ✅ Full support |
| **DL Expansion** | ✅ Click "+" to expand | ✅ Click "+" to expand |
| **COM Automation** | ✅ Full support | ❌ Limited/none |
| **PowerShell Scripting** | ✅ Create emails/events | ❌ API only |
| **Meeting Tracking** | ✅ Full tracking tab | ✅ Full tracking tab |
| **NDR Detection** | ✅ Inbox NDR messages | ✅ Inbox NDR messages |
| **Offline Mode** | ✅ Full offline support | ⚠️ Limited offline |
| **Add-ins** | ✅ Full add-in support | ⚠️ Limited add-ins |

**Recommendation**: For PowerShell automation with CreateEmailEventAndTeamsChat, **use Legacy Outlook (Classic)**. COM automation does not work with New Outlook.

---

## 9. PowerShell Integration

[↑ Top](#top)

### 9.1 Adding DLs to Email (CreateEmailEventAndTeamsChat)

[↑ Top](#top)

**Your Current Code** (Email tab):

```powershell
function New-OutlookEmail {
    param(
        [string]$To,
        [string]$CC,
        [string]$BCC,
        [string]$Subject,
        [string]$Body
    )
    
    $outlook = New-Object -ComObject Outlook.Application
    $mail = $outlook.CreateItem(0)
    
    # Distribution lists work the same as individual addresses
    $mail.To = $To    # Can be "DL-Finance-Team@irs.gov"
    $mail.CC = $CC    # Can be "DL-Marketing-Team@irs.gov"
    $mail.BCC = $BCC  # Can be "DL-Executives@irs.gov"
    
    $mail.Subject = $Subject
    $mail.Body = $Body
    $mail.Display($false)
}
```

**Example Usage**:
```powershell
New-OutlookEmail `
    -To "DL-Finance-Team@irs.gov" `
    -CC "DL-Executives@irs.gov" `
    -Subject "Q4 Financial Report" `
    -Body "Please review the attached Q4 report."
```

### 9.2 Adding DLs to Calendar Events

[↑ Top](#top)

**Your Current Code** (Event tab):

```powershell
function New-OutlookEvent {
    param(
        [datetime]$StartTime,
        [int]$DurationMinutes,
        [string]$Subject,
        [string]$Location,
        [string]$RequiredAttendees,
        [string]$OptionalAttendees,
        [string]$Body,
        [bool]$ReminderSet,
        [int]$ReminderMinutesBeforeStart
    )
    
    $outlook = New-Object -ComObject Outlook.Application
    $appointment = $outlook.CreateItem(1)
    
    $appointment.Start = $StartTime
    $appointment.Duration = $DurationMinutes
    $appointment.Subject = $Subject
    $appointment.Location = $Location
    
    # Distribution lists work the same as individual addresses
    $appointment.RequiredAttendees = $RequiredAttendees  # Can be "DL-Finance-Team@irs.gov"
    $appointment.OptionalAttendees = $OptionalAttendees  # Can be "DL-Marketing-Team@irs.gov"
    
    $appointment.Body = $Body
    $appointment.ReminderSet = $ReminderSet
    if ($ReminderSet) {
        $appointment.ReminderMinutesBeforeStart = $ReminderMinutesBeforeStart
    }
    
    $appointment.Display($false)
}
```

**Example Usage**:
```powershell
New-OutlookEvent `
    -StartTime (Get-Date).AddDays(7).Date.AddHours(14) `
    -DurationMinutes 60 `
    -Subject "Q4 Planning Meeting" `
    -Location "Conference Room A" `
    -RequiredAttendees "DL-Finance-Team@irs.gov; DL-Management@irs.gov" `
    -OptionalAttendees "DL-Marketing-Team@irs.gov" `
    -Body "Agenda: Review Q4 goals and budget" `
    -ReminderSet $true `
    -ReminderMinutesBeforeStart 15
```

### 9.3 Multiple DLs in Same Field

[↑ Top](#top)

**Semicolon-separated**:
```powershell
$mail.To = "DL-Finance-Team@irs.gov; DL-HR-Team@irs.gov; alice.smith@irs.gov"
$appointment.RequiredAttendees = "DL-Engineering@irs.gov; DL-Product@irs.gov"
```

### 9.4 Validating DL Address

[↑ Top](#top)

**Check if DL exists before sending**:

```powershell
function Test-OutlookAddress {
    param([string]$EmailAddress)
    
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")
    
    try {
        $recipient = $namespace.CreateRecipient($EmailAddress)
        $resolved = $recipient.Resolve()
        
        if ($resolved) {
            return @{
                Valid = $true
                DisplayName = $recipient.Name
                Type = $recipient.AddressEntry.AddressEntryUserType
            }
        }
        else {
            return @{
                Valid = $false
                DisplayName = $null
                Type = $null
            }
        }
    }
    catch {
        return @{
            Valid = $false
            DisplayName = $null
            Type = $null
        }
    }
}

# Usage
$result = Test-OutlookAddress -EmailAddress "DL-Finance-Team@irs.gov"
if ($result.Valid) {
    Write-Host "✅ Valid: $($result.DisplayName)"
}
else {
    Write-Host "❌ Invalid address"
}
```

---

## 10. Best Practices

[↑ Top](#top)

### 10.1 Email Best Practices

[↑ Top](#top)

1. **Use To for primary recipients**: People who need to act
2. **Use CC for informational copies**: Keep teams informed
3. **Use BCC sparingly**: Only for privacy (large announcements)
4. **Don't Reply All to large DLs**: Avoid email storms
5. **Check DL size before sending**: Large DLs take time to expand
6. **Include context in subject line**: DL members may not know why they received

### 10.2 Calendar Event Best Practices

[↑ Top](#top)

1. **Use Required for must-attend members**: Critical stakeholders
2. **Use Optional for FYI attendees**: People who can decline guilt-free
3. **Don't invite large DLs to recurring meetings**: Creates hundreds of calendar entries
4. **Include agenda in body**: DL members need context
5. **Set appropriate reminder time**: Consider DL members' schedules
6. **Monitor tracking tab**: Watch for high decline rates (maybe DL is wrong audience)

### 10.3 Distribution List Management

[↑ Top](#top)

1. **Review membership quarterly**: Remove inactive members
2. **Test DLs with meeting invitations**: Faster failure detection than email
3. **Document DL purpose**: Add description to DL properties
4. **Assign DL owners**: Responsible for maintaining accuracy
5. **Set expiration dates**: Force periodic review
6. **Use nested DLs carefully**: Deep nesting slows expansion
7. **Avoid overly large DLs**: >500 members can cause delays

### 10.4 NDR Monitoring

[↑ Top](#top)

1. **Set up inbox rule**: Flag emails from `postmaster@` or with "Undeliverable" in subject
2. **Review NDRs weekly**: Identify patterns (same invalid member repeatedly)
3. **Create NDR response process**: 
   - Document invalid member
   - Notify DL owner
   - Remove invalid member
   - Retest DL

### 10.5 Teams Integration

[↑ Top](#top)

1. **Use Microsoft 365 Groups for Teams**: Better integration than DLs
2. **Convert DLs to M365 Groups**: When Teams collaboration needed
3. **Don't rely on DL @mentions in Teams**: Inconsistent behavior
4. **Use email-to-channel for DL notifications**: Reliable delivery

---

## 11. Summary and Quick Reference

[↑ Top](#top)

### Key Takeaways

1. **Email vs Events**: DLs work similarly in both, but events show individual responses
2. **Teams**: Classic DLs have limited Teams support; use M365 Groups instead
3. **Outdated DLs**: Detect via NDRs (email) or meeting tracking tab (faster)
4. **Naming Conventions**: `&` and `*` prefixes are organization-specific; check with IT
5. **Legacy Outlook**: Full COM automation support for PowerShell scripts
6. **Best Practice**: Regular audits, assign owners, test with meeting invitations

### Quick Reference Table

| Task | Tool | Method |
|------|------|--------|
| Send email to DL | Outlook | To: `DL-Name@domain.com` |
| Send meeting to DL | Outlook | Required: `DL-Name@domain.com` |
| Check DL members | Outlook | Right-click → Expand Distribution List |
| Detect invalid members | Email | Wait for NDRs (30 mins) |
| Detect invalid members | Meeting | Check Tracking tab (5 mins) |
| Validate DL health | PowerShell | `Test-DistributionListHealth` script |
| Use DL in Teams | Teams | Limited - use M365 Groups instead |
| Automate with PowerShell | COM | `New-Object -ComObject Outlook.Application` |

### NDR Error Code Quick Reference

| Code | Meaning | Action |
|------|---------|--------|
| `5.1.1` | Mailbox doesn't exist | Remove from DL |
| `5.1.2` | Domain not found | Fix email address |
| `5.7.1` | Sender denied | Check permissions |
| `5.4.1` | Recipient no longer exists | Remove from DL |
| `4.4.1` | Connection timeout (temporary) | Monitor, may resolve |
| `4.2.2` | Mailbox full (temporary) | Contact member |

---

## 12. Glossary

[↑ Top](#top)

**Active Directory (AD)**: Microsoft's directory service for Windows domain networks. Stores user accounts, groups, and security information.

**Address Entry Type**: A numeric value indicating the type of recipient (user, distribution list, contact, etc.) in Outlook's address book.

**Address Book Sorting**: The alphabetical ordering of entries in Outlook's address book. Special characters typically sort before letters.

**BCC (Blind Carbon Copy)**: Email field where recipients receive the message but cannot see other BCC recipients or that they were BCC'd.

**CC (Carbon Copy)**: Email field for recipients who receive a copy of the message for informational purposes, not requiring action.

**Classic Distribution List**: Traditional email-only group in Exchange without security permissions or shared resources.

**COM (Component Object Model)**: Microsoft's binary interface standard allowing inter-process communication and automation (e.g., PowerShell controlling Outlook).

**COM Automation**: Using COM to programmatically control applications like Outlook from scripts or other programs.

**DDL (Dynamic Distribution List)**: Distribution list whose membership is automatically determined by Active Directory query rules.

**Distribution List (DL)**: An email group that expands to individual recipient addresses when used in email or calendar events.

**DL Expansion**: The process of Exchange converting a distribution list address into individual member email addresses.

**DL Owner**: Person or group responsible for managing distribution list membership and settings.

**Exchange**: Microsoft's email server platform that hosts mailboxes, distribution lists, and calendar resources.

**Exchange PowerShell**: Command-line interface for administering Exchange servers and mailboxes.

**GAL (Global Address List)**: The organization-wide address book visible in Outlook containing all users, groups, and contacts.

**Group Inbox**: Shared mailbox associated with Microsoft 365 Groups where group email conversations are stored.

**Hide Membership**: Distribution list setting that prevents recipients from seeing the DL name or other members.

**IRS**: Internal Revenue Service (used in examples as the domain: @irs.gov).

**M365 (Microsoft 365)**: Cloud-based subscription service combining Office applications, Exchange Online, SharePoint, Teams, and more.

**Mail-Enabled Security Group**: Active Directory security group with an email address, usable for both permissions and email.

**MAPI (Messaging Application Programming Interface)**: Microsoft's protocol for email clients to access mailboxes on Exchange.

**Meeting Invitation**: Calendar event sent via email that recipients can accept, decline, or mark tentative.

**Meeting Tracking Tab**: Outlook interface showing individual attendee responses (Accepted, Declined, Tentative, No Response) for a calendar event.

**Microsoft 365 Group**: Modern collaboration group with shared mailbox, SharePoint site, calendar, and optional Teams team.

**NDR (Non-Delivery Report)**: Automatic email notification sent when message delivery fails, containing error codes and failure reasons.

**Nested Distribution List**: A distribution list that contains other distribution lists as members.

**New Outlook**: Progressive Web App version of Outlook with modern UI but limited automation capabilities.

**OOO (Out of Office)**: Auto-reply message sent when a user is unavailable (vacation, sick leave, etc.).

**Optional Attendees**: Meeting invitation field for recipients who can attend but are not required.

**Organizer**: Person who creates and sends a meeting invitation, responsible for tracking responses.

**Outlook Classic**: Traditional desktop version of Outlook with full COM automation support.

**Permanent Failure**: Email delivery error (5.x.x codes) indicating the problem is not temporary and will not resolve automatically.

**PWA (Progressive Web App)**: Web-based application that runs in a browser but provides app-like experience.

**Recipient Limit**: Maximum number of individual email addresses that can be in a distribution list or email message.

**Reply All**: Email action that responds to the original sender and all recipients (To and CC).

**Reply To**: Custom email address where replies should be sent instead of the original sender.

**Required Attendees**: Meeting invitation field for recipients who must attend.

**Resources**: Calendar field for booking rooms, equipment, or other shared resources.

**Room Finder**: Outlook feature that shows available conference rooms when scheduling meetings.

**Room List**: Special distribution list containing room mailboxes, used by Room Finder.

**Security Group**: Active Directory group used to assign permissions to files, folders, and applications.

**Send Restrictions**: Rules limiting who can send email to a distribution list (internal only, approved senders, etc.).

**SharePoint**: Microsoft's web-based collaboration platform for document storage and team sites.

**Silent Failure**: Email delivery failure that does not generate an NDR, often due to spam filters or forwarding issues.

**SMTP (Simple Mail Transfer Protocol)**: Standard protocol for sending email over the Internet.

**Teams Channel**: Discussion area within a Microsoft Teams team, can have dedicated email address.

**Teams Meeting**: Video/audio meeting scheduled through Microsoft Teams, can be hybrid with Outlook calendar.

**Temporary Failure**: Email delivery error (4.x.x codes) that may resolve automatically with retry.

**To Field**: Primary email recipients who are expected to act on the message.

**Tracking Tab**: See Meeting Tracking Tab.

**Unified Groups**: See Microsoft 365 Groups.

**UPN (User Principal Name)**: Active Directory attribute formatted like an email address (e.g., john.doe@irs.gov), used for user login.

**WinRT (Windows Runtime)**: Microsoft's API for Windows apps, includes toast notification capabilities.

**XAML (Extensible Application Markup Language)**: XML-based language for defining user interfaces in WPF applications.

**@Mention**: Teams/Outlook feature to notify specific people or groups by typing @ followed by their name.

---

**End of Document**

[↑ Top](#top)

**Document Version**: 2.0  
**Last Updated**: 2026-09-19  
**For**: CreateEmailEventAndTeamsChat.Prototype.ps1 and Outlook Integration
