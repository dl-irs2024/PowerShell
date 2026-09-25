#Requires -Version 5.1
<#
.SYNOPSIS
    Email lookup module for resolving email addresses via Outlook GAL, Contacts, and ADSI.
    
.DESCRIPTION
    Provides functions to extract email recipients from Outlook MailItems, .msg files, and
    raw email text. Resolves user properties via Outlook Global Address List with fallback
    to local Contacts and Active Directory (ADSI).
    
.AUTHOR
    EmailLookup Module
    
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

# Module-level variables
$script:OutlookApp = $null
$script:OutlookAvailable = $false
$script:LastOutlookCheck = $null
$script:OutlookCheckInterval = 60  # seconds

# ============================================================================
# Outlook Connection Management
# ============================================================================

function Test-OutlookLegacyInstalled {
    <#
    .SYNOPSIS
        Tests if Outlook legacy (2013/2016/2019/365) is installed.
    
    .OUTPUTS
        [hashtable] with keys: Installed, Version, VersionName, Build
    #>
    $regPath = @(
        'HKLM:\Software\Microsoft\Office\16.0\Outlook',  # Office 2016+
        'HKLM:\Software\Microsoft\Office\15.0\Outlook',  # Office 2013
        'HKLM:\Software\Wow6432Node\Microsoft\Office\16.0\Outlook',
        'HKLM:\Software\Wow6432Node\Microsoft\Office\15.0\Outlook'
    )
    
    foreach ($path in $regPath) {
        if (Test-Path $path) {
            try {
                $version = (Get-ItemProperty $path -ErrorAction Stop).InstallRoot
                $build = (Get-ItemProperty "$path\InstallRoot" -ErrorAction Stop).BuildVersion
                
                if ($version) {
                    return @{
                        Installed = $true
                        Version = $version
                        Build = $build
                        VersionName = $(Get-OutlookVersionName $build)
                    }
                }
            } catch {
                continue
            }
        }
    }
    
    return @{
        Installed = $false
        Version = $null
        Build = $null
        VersionName = 'Not Installed'
    }
}

function Get-OutlookVersionName {
    <#
    .SYNOPSIS
        Maps Outlook build version to friendly name.
    
    .PARAMETER Build
        Build version string (e.g., "16.0.13127")
    
    .OUTPUTS
        [string] Friendly version name
    #>
    param([string]$Build)
    
    if (-not $Build) { return 'Unknown' }
    
    $major = $Build.Split('.')[0]
    switch ($major) {
        '16' { return 'Outlook 2016/365/2019' }
        '15' { return 'Outlook 2013' }
        '14' { return 'Outlook 2010' }
        '12' { return 'Outlook 2007' }
        '11' { return 'Outlook 2003' }
        default { return "Outlook v$Build" }
    }
}

function Initialize-OutlookConnection {
    <#
    .SYNOPSIS
        Creates Outlook COM object and caches it. Rate-limited to 60-second cooldown.
    
    .OUTPUTS
        [bool] Success/failure
    #>
    
    # Rate-limiting check
    if ($script:LastOutlookCheck -and ((Get-Date) - $script:LastOutlookCheck).TotalSeconds -lt $script:OutlookCheckInterval) {
        return $script:OutlookAvailable
    }
    
    $script:LastOutlookCheck = Get-Date
    
    if ($script:OutlookApp) {
        $script:OutlookAvailable = $true
        return $true
    }
    
    try {
        $script:OutlookApp = New-Object -ComObject Outlook.Application -ErrorAction Stop
        $version = $script:OutlookApp.Version
        
        Write-Verbose "Outlook initialized successfully. Version: $version"
        $script:OutlookAvailable = $true
        return $true
    } catch [System.Runtime.InteropServices.COMException] {
        Write-Warning "Outlook COM object unavailable. Will use Contacts/ADSI fallback."
        $script:OutlookAvailable = $false
        $script:OutlookApp = $null
        return $false
    } catch {
        Write-Warning "Error initializing Outlook: $_"
        $script:OutlookAvailable = $false
        $script:OutlookApp = $null
        return $false
    }
}

function Cleanup-OutlookConnection {
    <#
    .SYNOPSIS
        Releases Outlook COM object safely.
    #>
    if ($script:OutlookApp) {
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:OutlookApp) | Out-Null
            $script:OutlookApp = $null
            $script:OutlookAvailable = $false
            Write-Verbose "Outlook COM object released."
        } catch {
            Write-Verbose "Error during Outlook cleanup: $_"
        }
    }
}

# Register cleanup on script exit
if (-not (Get-EventSubscriber -SourceIdentifier 'PowerShell.Exiting' -ErrorAction SilentlyContinue)) {
    Register-EngineEvent -SourceIdentifier 'PowerShell.Exiting' -Action { Cleanup-OutlookConnection } -ErrorAction SilentlyContinue | Out-Null
}

# ============================================================================
# Recipient Extraction
# ============================================================================

function Extract-RecipientsFromMailItem {
    <#
    .SYNOPSIS
        Extracts recipient information from an Outlook.MailItem object.
    
    .PARAMETER MailItem
        Outlook.MailItem COM object
    
    .OUTPUTS
        [array] of hashtables with keys: Email, DisplayName, Type (To/Cc/Bcc)
    #>
    param([object]$MailItem)
    
    $recipients = @()
    
    try {
        # Add sender
        if ($MailItem.SenderEmailAddress) {
            $recipients += @{
                Email = $MailItem.SenderEmailAddress
                DisplayName = $MailItem.SenderName
                Type = 'Sender'
            }
        }
        
        # Add To/Cc/Bcc recipients
        $recipientTypes = @(
            @{ OlRecipientType = 1; Type = 'To' },
            @{ OlRecipientType = 2; Type = 'Cc' },
            @{ OlRecipientType = 3; Type = 'Bcc' }
        )
        
        foreach ($recType in $recipientTypes) {
            foreach ($recipient in $MailItem.Recipients) {
                if ($recipient.Type -eq $recType.OlRecipientType) {
                    try {
                        $email = $recipient.GetExchangeUser().PrimarySmtpAddress
                        if (-not $email) {
                            $email = $recipient.Address
                        }
                        
                        if ($email) {
                            $recipients += @{
                                Email = $email
                                DisplayName = $recipient.Name
                                Type = $recType.Type
                            }
                        }
                    } catch {
                        # Fallback to basic address
                        if ($recipient.Address) {
                            $recipients += @{
                                Email = $recipient.Address
                                DisplayName = $recipient.Name
                                Type = $recType.Type
                            }
                        }
                    }
                }
            }
        }
    } catch {
        Write-Warning "Error extracting recipients from MailItem: $_"
    }
    
    return $recipients
}

function Extract-RecipientsFromMsgFile {
    <#
    .SYNOPSIS
        Extracts recipients from a .msg email file.
    
    .PARAMETER MsgFilePath
        Path to .msg file
    
    .OUTPUTS
        [array] of hashtables with email information
    #>
    param([string]$MsgFilePath)
    
    if (-not (Test-Path $MsgFilePath)) {
        Write-Warning "MSG file not found: $MsgFilePath"
        return @()
    }
    
    if (-not (Initialize-OutlookConnection)) {
        Write-Warning "Cannot extract from MSG file: Outlook unavailable"
        return @()
    }
    
    try {
        $mailItem = $script:OutlookApp.CreateItemFromTemplate($MsgFilePath)
        $recipients = Extract-RecipientsFromMailItem $mailItem
        return $recipients
    } catch {
        Write-Warning "Error extracting from MSG file: $_"
        return @()
    }
}

function Extract-RecipientsFromRawEmail {
    <#
    .SYNOPSIS
        Parses email recipients from raw email text (RFC 2822 format).
    
    .PARAMETER EmailText
        Raw email text (headers + body)
    
    .OUTPUTS
        [array] of hashtables with email information
    #>
    param([string]$EmailText)
    
    $recipients = @()
    $emailPattern = '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    
    # Parse To, Cc, Bcc headers
    $headerTypes = @(
        @{ Pattern = 'To:\s*(.+?)(?=\r?\nCc:|Bcc:|Subject:|$)'; Type = 'To' },
        @{ Pattern = 'Cc:\s*(.+?)(?=\r?\nBcc:|Subject:|$)'; Type = 'Cc' },
        @{ Pattern = 'Bcc:\s*(.+?)(?=\r?\nSubject:|$)'; Type = 'Bcc' }
    )
    
    foreach ($header in $headerTypes) {
        if ($EmailText -match $header.Pattern) {
            $headerValue = $matches[1]
            $emails = [regex]::Matches($headerValue, $emailPattern)
            
            foreach ($email in $emails) {
                $recipients += @{
                    Email = $email.Value
                    DisplayName = $email.Value
                    Type = $header.Type
                }
            }
        }
    }
    
    # Deduplicate by email
    $uniqueRecipients = @()
    $emailsAdded = @{}
    
    foreach ($recipient in $recipients) {
        if (-not $emailsAdded.ContainsKey($recipient.Email)) {
            $uniqueRecipients += $recipient
            $emailsAdded[$recipient.Email] = $true
        }
    }
    
    return $uniqueRecipients
}

# ============================================================================
# User Resolution (GAL -> Contacts -> ADSI)
# ============================================================================

function Resolve-UserViaGAL {
    <#
    .SYNOPSIS
        Resolves user information via Outlook Global Address List.
    
    .PARAMETER Email
        Email address to resolve
    
    .OUTPUTS
        [hashtable] with user properties or $null if not found
    #>
    param([string]$Email)
    
    if (-not (Initialize-OutlookConnection)) {
        return $null
    }
    
    try {
        $namespace = $script:OutlookApp.GetNamespace('MAPI')
        $recipient = $namespace.CreateRecipient($Email)
        
        if (-not $recipient.Resolve()) {
            return $null
        }
        
        $exchangeUser = $recipient.GetExchangeUser()
        if (-not $exchangeUser) {
            return $null
        }
        
        $result = @{
            DisplayName = $exchangeUser.Name
            Email = $exchangeUser.PrimarySmtpAddress
            Title = $exchangeUser.JobTitle
            Department = $exchangeUser.Department
            Office = $exchangeUser.OfficeLocation
            StreetAddress = $exchangeUser.StreetAddress
            State = $exchangeUser.StateOrProvince
            ZipCode = $exchangeUser.PostalCode
            Phone = $exchangeUser.BusinessTelephoneNumber
            MobilePhone = $exchangeUser.MobileTelephoneNumber
            TimeZone = $exchangeUser.TimeZone
            Manager = $exchangeUser.Manager
            OutOfOfficeEnabled = $exchangeUser.OutOfOfficeReplyEnabled
            OutOfOfficeStart = $exchangeUser.OutOfOfficeReplyStartTime
            OutOfOfficeEnd = $exchangeUser.OutOfOfficeReplyEndTime
            Source = 'Outlook GAL'
        }
        
        return $result
    } catch {
        Write-Verbose "GAL lookup failed for $Email : $_"
        return $null
    }
}

function Get-UserFromContacts {
    <#
    .SYNOPSIS
        Searches Outlook local Contacts folder for user.
    
    .PARAMETER Email
        Email address to search for
    
    .OUTPUTS
        [hashtable] with contact properties or $null if not found
    #>
    param([string]$Email)
    
    if (-not (Initialize-OutlookConnection)) {
        return $null
    }
    
    try {
        $namespace = $script:OutlookApp.GetNamespace('MAPI')
        $contactsFolder = $namespace.GetDefaultFolder(10)  # olFolderContacts
        
        foreach ($contact in $contactsFolder.Items) {
            if ($contact.Email1Address -eq $Email -or $contact.Email1Address -like "*$Email*") {
                $result = @{
                    DisplayName = $contact.FullName
                    Email = $contact.Email1Address
                    Title = $contact.JobTitle
                    Department = $contact.Department
                    Office = $contact.OfficeLocation
                    Phone = $contact.BusinessTelephoneNumber
                    MobilePhone = $contact.MobileTelephoneNumber
                    Source = 'Outlook Contacts'
                }
                
                return $result
            }
        }
    } catch {
        Write-Verbose "Contacts lookup failed for $Email : $_"
    }
    
    return $null
}

function Get-UserFromADSI {
    <#
    .SYNOPSIS
        Resolves user via Active Directory LDAP (ADSI).
    
    .PARAMETER Email
        Email address to resolve
    
    .OUTPUTS
        [hashtable] with AD properties or $null if not found
    #>
    param([string]$Email)
    
    try {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.PropertiesToLoad.AddRange(@('displayName', 'mail', 'title', 'department', 
            'physicalDeliveryOfficeName', 'streetAddress', 'st', 'postalCode', 
            'telephoneNumber', 'mobile', 'manager', 'userPrincipalName'))
        
        # Try mail attribute first
        $searcher.Filter = "(&(objectClass=user)(mail=$Email))"
        Write-Verbose "[ADSI] Searching with filter: $($searcher.Filter)"
        
        $result = $searcher.FindOne()
        
        if ($result) {
            $props = $result.Properties
            Write-Verbose "[ADSI] Found user by mail attribute"
            
            return @{
                DisplayName = $props['displayName'][0]
                Email = $props['mail'][0]
                Title = $props['title'][0]
                Department = $props['department'][0]
                Office = $props['physicalDeliveryOfficeName'][0]
                StreetAddress = $props['streetAddress'][0]
                State = $props['st'][0]
                ZipCode = $props['postalCode'][0]
                Phone = $props['telephoneNumber'][0]
                MobilePhone = $props['mobile'][0]
                Manager = $props['manager'][0]
                Source = 'Active Directory (mail)'
            }
        }
        
        Write-Verbose "[ADSI] No match on mail attribute, trying userPrincipalName..."
        
        # Try userPrincipalName as fallback (extract before @)
        $upnFilter = "(&(objectClass=user)(userPrincipalName=$Email))"
        $searcher.Filter = $upnFilter
        Write-Verbose "[ADSI] Searching with filter: $upnFilter"
        
        $result = $searcher.FindOne()
        if ($result) {
            $props = $result.Properties
            Write-Verbose "[ADSI] Found user by userPrincipalName"
            
            return @{
                DisplayName = $props['displayName'][0]
                Email = $props['mail'][0]
                Title = $props['title'][0]
                Department = $props['department'][0]
                Office = $props['physicalDeliveryOfficeName'][0]
                StreetAddress = $props['streetAddress'][0]
                State = $props['st'][0]
                ZipCode = $props['postalCode'][0]
                Phone = $props['telephoneNumber'][0]
                MobilePhone = $props['mobile'][0]
                Manager = $props['manager'][0]
                Source = 'Active Directory (UPN)'
            }
        }
        
        Write-Verbose "[ADSI] No match found for $Email in any attribute"
    } catch {
        Write-Verbose "[ADSI] Exception during lookup for $Email : $_ | ErrorType: $($_.Exception.GetType().Name)"
    }
    
    return $null
}

function Lookup-User {
    <#
    .SYNOPSIS
        Orchestrator function that resolves user via fallback chain:
        GAL -> Contacts -> ADSI
    
    .PARAMETER Email
        Email address to resolve
    
    .OUTPUTS
        [hashtable] with user properties or $null if not found
    #>
    param([string]$Email)
    
    if (-not $Email) {
        return $null
    }
    
    # Try GAL
    $user = Resolve-UserViaGAL $Email
    if ($user) { return $user }
    
    # Try Contacts
    $user = Get-UserFromContacts $Email
    if ($user) { return $user }
    
    # Try ADSI
    $user = Get-UserFromADSI $Email
    if ($user) { return $user }
    
    return $null
}

# Export module functions
Export-ModuleMember -Function @(
    'Test-OutlookLegacyInstalled',
    'Get-OutlookVersionName',
    'Initialize-OutlookConnection',
    'Cleanup-OutlookConnection',
    'Extract-RecipientsFromMailItem',
    'Extract-RecipientsFromMsgFile',
    'Extract-RecipientsFromRawEmail',
    'Resolve-UserViaGAL',
    'Get-UserFromContacts',
    'Get-UserFromADSI',
    'Lookup-User'
)
