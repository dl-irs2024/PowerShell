# How Outlook & External Apps Look Up Email Addresses & User Profiles

## Quick Answer
- **Outlook** primarily searches the **Global Address List (GAL)** which is synced from **Active Directory**
- **Search order**: Display Name first, then email alias, then full email address
- **Underscores in emails** are formatting substitutes for spaces in names (e.g., "Davis Lee" → `davis_lee@irs.gov`)
- **External apps** use **LDAP/ADSI** to query Active Directory directly with email as the primary attribute

---

## Part 1: How Outlook Itself Looks Up Email Addresses

### Outlook's Search Hierarchy

When you type in Outlook's recipient field (To:, Cc:, Bcc:), Outlook searches the **Global Address List (GAL)** in this order:

| Priority | Search Method | Example | Notes |
|----------|--------------|---------|-------|
| **1st** | **Display Name** (first/last name) | "Davis Lee" | Fastest, searches cached GAL |
| **2nd** | **Email Alias** (pre-@ part) | "davis_lee" or "dlee" | Matches beginning of alias |
| **3rd** | **Full Email Address** | "davis.s.lee@irs.gov" | Exact match required |
| **4th** | **Partial matches** | Type "dav" → suggests all "Dav*" | Autocomplete suggestions |

### What is the Global Address List (GAL)?

The **GAL is a synchronized copy of your Active Directory**:
- Updated periodically from on-premises AD or Azure AD
- Contains ~14 core attributes per user:
  - `displayName` (Full Name)
  - `mail` (Email address)
  - `mailNickname` (Alias)
  - `userPrincipalName` (UPN)
  - `telephoneNumber` (Phone)
  - `physicalDeliveryOfficeName` (Office)
  - `department`, `title`, `company`
  - `manager`, `homePhone`, `mobile`, `facsimileTelephoneNumber`
- Cached locally on your machine for offline lookup

### Why Outlook Doesn't Always Need "Email First"

Outlook searches **by what you type**, not by a fixed hierarchy:
- Type **"Davis"** → Finds anyone with first name Davis
- Type **"davis_lee"** → Finds the email alias
- Type **"davis.s.lee@irs.gov"** → Finds exact email match

**Key insight**: Outlook's search is smart and context-aware. It doesn't require you to type the email address format.

---

## Part 2: Understanding Underscores in Email Addresses

### Why Underscores?

Email addresses in corporate systems often use underscores when employee names contain spaces:

```
Employee Name        →  Mailbox Alias          →  Email Address
────────────────────     ────────────────────      ──────────────────────────
Davis Lee            →  davis_lee              →  davis_lee@irs.gov
John Smith Johnson   →  john_smith_johnson     →  john_smith_johnson@irs.gov
Mary-Anne O'Connor   →  maryanne_oconnor       →  maryanne_oconnor@irs.gov
```

### How Active Directory Stores These

In AD, the underscore format is stored in:
- **`mailNickname`** (Alias): `davis_lee` (what you see in Outlook recipient field)
- **`mail`** (Email): `davis_lee@irs.gov` (full email address)
- **`userPrincipalName`** (UPN): `davis_lee@irs.gov` or `davis_lee@agency.local`
- **`displayName`** (Human-readable): `Davis Lee` (what shows in directory)

### Underscore vs. Dot Format

Different organizations use different conventions:

| Format | Example | Used By | Notes |
|--------|---------|---------|-------|
| **Underscore** | `davis_lee@irs.gov` | IRS, many US agencies | Older convention, easier to read |
| **Dot** | `davis.lee@irs.gov` | Microsoft, Google, many corps | Modern standard, looks more professional |
| **No separator** | `davislee@irs.gov` | Some orgs | Compact but harder to parse |
| **FirstInitial.Last** | `d.lee@irs.gov` | Some large orgs | Saves characters, common in UK/EU |

**Your organization chose underscores**, so all AD attributes reflect that format.

---

## Part 3: How External Apps Look Up User Profiles

### The Two Methods

External applications (like your WPF EmailLookup app) use these methods:

#### **Method 1: Direct LDAP/ADSI Query (Most Common)**

```powershell
# What your app does:
$filter = "(&(objectClass=user)(mail=$email))"
# Searches: "Find users where email matches davis_lee@irs.gov"

$results = Get-ADUser -Filter "mail -eq '$email'" -Properties *
```

**How it works**:
1. App constructs LDAP filter: `(&(objectClass=user)(mail=davis_lee@irs.gov))`
2. Sends query directly to **Active Directory Domain Controller**
3. AD returns matching user object with all 14+ attributes
4. App displays results (name, department, phone, etc.)

**Attributes LDAP searches**:
- `mail` (Primary search) - Full email address
- `userPrincipalName` (Fallback) - If mail doesn't match
- `mailNickname` - Email alias
- `displayName` - Human name for display

#### **Method 2: Outlook COM Interop (What Your App Also Does)**

```powershell
# What your app does:
$outlook = New-Object -ComObject Outlook.Application
$gal = $outlook.Session.GetGlobalAddressList()
$entries = $gal.AddressEntries
$recipient = $entries.Item("davis_lee@irs.gov")  # Searches GAL
```

**How it works**:
1. App connects to Outlook application
2. Accesses the cached **Global Address List (GAL)**
3. Searches by email, alias, or name
4. Returns contact information from GAL cache

**Pros & Cons**:

| Method | Pros | Cons |
|--------|------|------|
| **LDAP/ADSI** | Real-time, no Outlook required, full AD attributes | Requires AD access, slower (network call) |
| **Outlook COM** | Fast (cached), includes local contacts | Requires Outlook installed, may be stale |

### Search Order in External Apps

Your WPF app implements the optimal search order:

```
1. GAL (Outlook) - Fast, cached, fresh-ish
   ↓ (if not found)
2. Outlook Contacts - Personal contacts folder
   ↓ (if not found)
3. Active Directory (LDAP) - Definitive source, all users
```

**Why this order?**
- **GAL first**: Fastest lookup, users expect Outlook search behavior
- **Contacts second**: Personal/team contact folders might have unlisted users
- **AD last**: Authoritative but slower, guarantees coverage of all org users

### The Lookup Chain Process

When you paste `davis_lee@irs.gov` into your app:

```
┌─────────────────────────────────────────────────────────────┐
│ User pastes: davis_lee@irs.gov                              │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
        ┌──────────────────────┐
        │ Extract Email Address │  (regex or parsing)
        │ Result: Valid email   │
        └──────────────┬───────┘
                       ↓
        ┌──────────────────────────┐
        │ [1] Query Outlook GAL    │  Via COM
        │ Lookup: mail = email     │
        │ Timeout: 1-2 seconds     │
        └──────────────┬───────────┘
                       ↓ (if not found)
        ┌──────────────────────────┐
        │ [2] Query Contacts Folder│  Via COM
        │ Lookup: email property   │
        │ Timeout: <1 second       │
        └──────────────┬───────────┘
                       ↓ (if not found)
        ┌──────────────────────────────────┐
        │ [3] Query Active Directory (LDAP)│  Via ADSI
        │ Filter 1: (&(objectClass=user)   │
        │           (mail=email))          │
        │ Filter 2: (&(objectClass=user)   │
        │           (userPrincipalName=   │
        │             email))              │
        │ Timeout: 2-3 seconds             │
        └──────────────┬────────────────────┘
                       ↓
        ┌──────────────────────────────────┐
        │ Results:                         │
        │ • Found → Display in grid        │
        │ • Not found → Show "No match"    │
        │ • Error → Show error message     │
        └──────────────────────────────────┘
```

---

## Part 4: Email Lookup Attributes & Their Purpose

### What Attributes Does Active Directory Use?

When an external app looks up a user by email, here's what AD provides:

```
Lookup Input:     davis_lee@irs.gov
                        ↓
            Active Directory Query:
            (&(objectClass=user)
              (mail=davis_lee@irs.gov))
                        ↓
            Returned Attributes (14 minimum):
            ┌─────────────────────────────────┐
            │ displayName     → Davis Lee      │
            │ mail            → davis_lee@...  │
            │ mailNickname    → davis_lee      │
            │ userPrincipalName → davis_lee@... │
            │ givenName       → Davis          │
            │ sn              → Lee            │
            │ department      → Finance        │
            │ title           → Accountant     │
            │ physicalDeliveryOfficeName → ... │
            │ telephoneNumber → 202-555-0123  │
            │ mobile          → 202-555-0456  │
            │ manager         → [manager DN]  │
            │ company         → IRS            │
            │ distinguishedName → CN=...       │
            │ (+ many more)                   │
            └─────────────────────────────────┘
```

### The Email Attribute (mail)

In Active Directory, the **`mail`** attribute:
- Contains the **full email address** (e.g., `davis_lee@irs.gov`)
- Is indexed for fast lookups
- Can be searched with LDAP filter: `(mail=*)`
- Is unique per user in a healthy AD forest
- Is the **primary** attribute for external lookups

### The UPN Attribute (userPrincipalName)

The **`userPrincipalName`** attribute:
- Format: `user@domain.com` (usually email format, but not always)
- Used by Windows logon (you type your UPN to log in)
- Is unique within the forest
- Alternative fallback if `mail` lookup fails
- Can differ from email (e.g., `davis_lee@agency.local` vs `davis_lee@irs.gov`)

---

## Part 5: Why Your App Implements This Way

### Your Implementation Strategy

Your WPF app (LookupEmailList.DropTarget.Wpf.ps1) implements:

```powershell
# 1. Outlook GAL via COM
Resolve-UserViaGAL -Email "davis_lee@irs.gov"

# 2. Outlook Contacts via COM
Get-UserFromContacts -Email "davis_lee@irs.gov"

# 3. Active Directory via LDAP/ADSI
Get-UserFromADSI -Email "davis_lee@irs.gov"
```

**Why this is the right approach**:
- ✅ **GAL first**: Matches user's Outlook search experience
- ✅ **Contacts second**: Finds team contacts not in GAL
- ✅ **ADSI fallback**: Authoritative source, never fails if user exists
- ✅ **Resilient**: If Outlook isn't installed, ADSI still works
- ✅ **Visible**: Status bar shows which method succeeded: `[GAL: 1, Contacts: 0, ADSI: 2]`

### The Underscore In Your Data

When your app displays results like:
```
Display Name: Davis S Lee
Email ID:     davis_lee@irs.gov
TimeZone:     Eastern Standard Time
```

The **`davis_lee`** part comes from:
- Your organization's email naming convention (underscores instead of dots)
- Stored in AD as `mail` attribute
- Retrieved by your lookup functions
- Displayed as-is in the grid

---

## Part 6: Common Lookup Issues & Solutions

### Issue 1: Email Found in AD but Not in GAL

**Why**: GAL is cached and synced periodically
**Solution**: 
- Outlook → File → Account Settings → Send/Receive → Send/Receive Groups → Download Address Book
- Or: Restart Outlook to refresh GAL cache
- Your app falls back to ADSI, so it still finds the user

### Issue 2: Email Format Inconsistency

**Why**: Some systems use dots (`davis.lee`), some use underscores (`davis_lee`)
**Solution**: Your app normalizes to what's in AD (the authoritative source)

### Issue 3: User Exists in AD but Not Found

**Why**: Usually because:
- `mail` attribute is empty or misspelled
- User account is disabled
- AD sync is delayed (if cloud-based)
**Solution**: Use ADSI verbose logging to see exact LDAP filter used (your app does this)

### Issue 4: Slow Lookups

**Why**: ADSI queries over network take 2-3 seconds
**Solution**:
- GAL/Contacts are instant (cached locally)
- ADSI is slower but authoritative
- Your app shows progress: `[LOOKUP]... [ADSI] Searching Active Directory...`

---

## Summary Table: Lookup Methods

| Method | Source | Speed | Coverage | When Used | Your App |
|--------|--------|-------|----------|-----------|----------|
| **Outlook GAL** | Local cache of AD | **<100ms** | ~95% of org | First choice | ✅ Resolve-UserViaGAL |
| **Outlook Contacts** | Local contact folder | **<50ms** | Personal subset | Second choice | ✅ Get-UserFromContacts |
| **Active Directory** | LDAP query, real-time | **2-3 sec** | **100% of org** | Fallback/authoritative | ✅ Get-UserFromADSI |

---

## Key Takeaways

1. **Outlook searches the GAL** (synced from AD), not the internet or external systems
2. **Email addresses with underscores** are your org's naming convention; AD stores in `mail` attribute
3. **External apps use LDAP/ADSI** to query AD directly for real-time, authoritative lookups
4. **Email is the primary lookup key** in AD (`mail` attribute)
5. **Your app implements the optimal strategy**: GAL → Contacts → ADSI
6. **Underscores are just formatting**: They replace spaces in names per company policy
