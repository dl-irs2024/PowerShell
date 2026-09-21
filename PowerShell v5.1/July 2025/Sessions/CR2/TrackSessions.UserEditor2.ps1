[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$script:BaseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:UsersPath = Join-Path -Path $script:BaseDir -ChildPath 'TrackSessions.Users.json'
$script:SettingsPath = Join-Path -Path $script:BaseDir -ChildPath 'TrackSessions.Settings.json'

$script:Statuses = @('FTE', 'Contractor')
$script:Products = @('SharePoint', 'Power Platform', 'OneDrive', 'Entra')
$script:TimezoneOptions = @(
	'Los Angeles, CA (PT) [UTC-08:00 / UTC-07:00]',
	'Phoenix, AZ (MT - no DST) [UTC-07:00]',
	'Denver, UT (MT) [UTC-07:00 / UTC-06:00]',
	'Ogden, UT (MT) [UTC-07:00 / UTC-06:00]',
	'Memphis, TN (CT) [UTC-06:00 / UTC-05:00]',
	'Austin, TX (CT) [UTC-06:00 / UTC-05:00]',
	'Washington, DC (ET) [UTC-05:00 / UTC-04:00]',
	'Martinsburg, WV (ET) [UTC-05:00 / UTC-04:00]',
	'San Juan, Puerto Rico (AST - no DST) [UTC-04:00]',
	'Halifax, Atlantic Canada (AT) [UTC-04:00 / UTC-03:00]'
)

$script:ExternalLookup = [ordered]@{
	Enabled     = $true
	EnableCsv   = $true
	CsvPath     = Join-Path -Path $script:BaseDir -ChildPath 'TrackSessions.Users.External.csv'
	EnableAD    = $true
	EnableGraph = $false
}

function Test-IsFiniteDouble {
	param($Value)
	if ($null -eq $Value) { return $false }
	try {
		$num = [double]$Value
		return (-not [double]::IsNaN($num) -and -not [double]::IsInfinity($num))
	}
	catch {
		return $false
	}
}

function Get-UserEditorZoomLevels {
	try {
		if (-not (Test-Path -LiteralPath $script:SettingsPath)) {
			return @{ GridZoom = 1.0; EditZoom = 1.0 }
		}

		$json = Get-Content -LiteralPath $script:SettingsPath -Raw | ConvertFrom-Json

		$gridZoom = 1.0
		$editZoom = 1.0

		if ($json.ZoomLevels) {
			if (Test-IsFiniteDouble -Value $json.ZoomLevels.UserEditor) {
				$gridZoom = [Math]::Max(0.70, [Math]::Min(3.00, [double]$json.ZoomLevels.UserEditor))
			}
			if (Test-IsFiniteDouble -Value $json.ZoomLevels.UserEditorEdit) {
				$editZoom = [Math]::Max(0.70, [Math]::Min(2.00, [double]$json.ZoomLevels.UserEditorEdit))
			}
		}

		return @{ GridZoom = $gridZoom; EditZoom = $editZoom }
	}
	catch {
		return @{ GridZoom = 1.0; EditZoom = 1.0 }
	}
}

function Save-UserEditorZoomLevel {
	param(
		[Parameter(Mandatory = $true)]
		[ValidateSet('Grid', 'Edit')]
		[string]$ZoomType,
		[Parameter(Mandatory = $true)]
		[double]$ZoomLevel
	)

	try {
		if (-not (Test-Path -LiteralPath $script:SettingsPath)) {
			return
		}

		$json = Get-Content -LiteralPath $script:SettingsPath -Raw | ConvertFrom-Json

		if (-not $json.ZoomLevels) {
			$json | Add-Member -NotePropertyName 'ZoomLevels' -NotePropertyValue ([PSCustomObject]@{
				MainContent = 1.0
				LogViewer = 1.0
				UserEditor = 1.0
				UserEditorEdit = 1.0
				Settings = 1.0
			}) -Force
		}

		if ($ZoomType -eq 'Grid') {
			$json.ZoomLevels.UserEditor = $ZoomLevel
		}
		else {
			$json.ZoomLevels.UserEditorEdit = $ZoomLevel
		}

		$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:SettingsPath -Force
	}
	catch {
		# Silently ignore save errors
	}
}

function Format-UserDateTime {
	param(
		[Parameter(Mandatory = $true)]
		[datetime]$Value
	)

	return $Value.ToString('ddd dd/MM/yyyy hh:mm')
}

function ConvertTo-UserDateTime {
	param(
		[string]$Value,
		[string]$FieldName
	)

	if ([string]::IsNullOrWhiteSpace($Value)) {
		return $null
	}

	$formats = @(
		'ddd dd/MM/yyyy hh:mm',
		'ddd d/M/yyyy hh:mm',
		'ddd dd/MM/yyyy HH:mm',
		'ddd d/M/yyyy HH:mm',
		'yyyy-MM-dd HH:mm',
		'MM/dd/yyyy HH:mm',
		'M/d/yyyy H:mm',
		'o'
	)

	foreach ($fmt in $formats) {
		try {
			return [datetime]::ParseExact($Value.Trim(), $fmt, [System.Globalization.CultureInfo]::InvariantCulture)
		}
		catch {
		}
	}

	try {
		return [datetime]::Parse($Value.Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
	}
	catch {
		throw "Invalid date/time in '$FieldName'. Use format ddd dd/MM/yyyy hh:mm (example: Mon 07/09/2026 09:15)."
	}
}

function Convert-ToUserObject {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$RawUser
	)

	$lastLoginDate = ConvertTo-UserDateTime -Value ([string]$RawUser.LastLogin) -FieldName 'Last Login'
	$lastModifiedDate = ConvertTo-UserDateTime -Value ([string]$RawUser.LastModified) -FieldName 'Last Modified'
	$createdDate = ConvertTo-UserDateTime -Value ([string]$RawUser.Created) -FieldName 'Created'

	if ($null -eq $createdDate) {
		$createdDate = Get-Date
	}
	if ($null -eq $lastModifiedDate) {
		$lastModifiedDate = $createdDate
	}

	$products = @()
	if ($RawUser.PSObject.Properties.Name -contains 'Products' -and $null -ne $RawUser.Products) {
		$products = @($RawUser.Products | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	}

	return [pscustomobject]@{
		SEID            = ([string]$RawUser.SEID).ToUpperInvariant()
		FirstName       = [string]$RawUser.FirstName
		LastName        = [string]$RawUser.LastName
		Status          = [string]$RawUser.Status
		IRSEmail        = [string]$RawUser.IRSEmail
		SEIDEmail       = [string]$RawUser.SEIDEmail
		Timezone        = [string]$RawUser.Timezone
		DaylightSavings = [bool]$RawUser.DaylightSavings
		Products        = $products
		ProductsDisplay = ($products -join ', ')
		LastLoginDate   = $lastLoginDate
		LastLogin       = if ($null -ne $lastLoginDate) { Format-UserDateTime -Value $lastLoginDate } else { '' }
		LastPawsUsed    = [string]$RawUser.LastPawsUsed
		LastModifiedDate = $lastModifiedDate
		LastModified    = Format-UserDateTime -Value $lastModifiedDate
		CreatedDate     = $createdDate
		Created         = Format-UserDateTime -Value $createdDate
		IsAdmin         = [bool]($RawUser.PSObject.Properties.Name -contains 'IsAdmin' -and $RawUser.IsAdmin -eq $true)
		NEmail          = if ($null -ne $RawUser.NEmail) { [bool]$RawUser.NEmail } else { $false }
		NEvent          = if ($null -ne $RawUser.NEvent) { [bool]$RawUser.NEvent } else { $false }
		NTeams          = if ($null -ne $RawUser.NTeams) { [bool]$RawUser.NTeams } else { $false }
		TeamsUrl        = if ($RawUser.TeamsUrl) { [string]$RawUser.TeamsUrl } else { '' }
	}
}

function Convert-FromUserObject {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$User
	)

	return [ordered]@{
		SEID            = ([string]$User.SEID).ToUpperInvariant()
		FirstName       = [string]$User.FirstName
		LastName        = [string]$User.LastName
		Status          = [string]$User.Status
		IRSEmail        = [string]$User.IRSEmail
		SEIDEmail       = [string]$User.SEIDEmail
		Timezone        = [string]$User.Timezone
		DaylightSavings = [bool]$User.DaylightSavings
		Products        = @($User.Products)
		LastLogin       = [string]$User.LastLogin
		LastPawsUsed    = [string]$User.LastPawsUsed
		LastModified    = [string]$User.LastModified
		Created         = [string]$User.Created
		IsAdmin         = [bool]$User.IsAdmin
		NEmail          = [bool]$User.NEmail
		NEvent          = [bool]$User.NEvent
		NTeams          = [bool]$User.NTeams
		TeamsUrl        = [string]$User.TeamsUrl
	}
}

function Split-ProductsValue {
	param([string]$Value)

	if ([string]::IsNullOrWhiteSpace($Value)) {
		return @()
	}

	$parts = $Value -split '[,;|]'
	$clean = @($parts | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	return $clean
}

function New-ExternalUserLookupResult {
	param(
		[Parameter(Mandatory = $true)][string]$Source,
		[Parameter(Mandatory = $true)][string]$SEID,
		[string]$FirstName,
		[string]$LastName,
		[string]$Status,
		[string]$IRSEmail,
		[string]$SEIDEmail,
		[string]$Timezone,
		[bool]$DaylightSavings = $true,
		[string[]]$Products = @(),
		[Nullable[datetime]]$LastLoginDate,
		[string]$LastPawsUsed,
		[Nullable[datetime]]$CreatedDate,
		[Nullable[datetime]]$LastModifiedDate
	)

	$created = if ($CreatedDate.HasValue) { $CreatedDate.Value } else { Get-Date }
	$modified = if ($LastModifiedDate.HasValue) { $LastModifiedDate.Value } else { Get-Date }

	if ([string]::IsNullOrWhiteSpace($Status)) {
		$Status = 'FTE'
	}
	if ([string]::IsNullOrWhiteSpace($Timezone)) {
		$Timezone = 'Washington, DC (ET) [UTC-05:00 / UTC-04:00]'
	}
	if ([string]::IsNullOrWhiteSpace($SEIDEmail) -and -not [string]::IsNullOrWhiteSpace($SEID)) {
		$SEIDEmail = '{0}@ds.irsnet.gov' -f $SEID
	}

	return [pscustomobject]@{
		Source           = $Source
		SEID             = ([string]$SEID).ToUpperInvariant()
		FirstName        = [string]$FirstName
		LastName         = [string]$LastName
		Status           = [string]$Status
		IRSEmail         = [string]$IRSEmail
		SEIDEmail        = [string]$SEIDEmail
		Timezone         = [string]$Timezone
		DaylightSavings  = [bool]$DaylightSavings
		Products         = @($Products)
		LastLoginDate    = if ($LastLoginDate.HasValue) { $LastLoginDate.Value } else { $null }
		LastPawsUsed     = [string]$LastPawsUsed
		CreatedDate      = $created
		LastModifiedDate = $modified
	}
}

function ConvertFrom-IrsEmailInput {
	param([string]$InputText)

	$result = [ordered]@{
		RawInput       = [string]$InputText
		Email          = ''
		FirstName      = ''
		LastName       = ''
		SeidCandidate  = ''
	}

	if ([string]::IsNullOrWhiteSpace($InputText)) {
		return [pscustomobject]$result
	}

	$work = $InputText.Trim()
	$mailMatch = [regex]::Match($work, '(?i)\b([A-Z0-9._%+-]+@irs\.gov)\b')
	if ($mailMatch.Success) {
		$result.Email = $mailMatch.Groups[1].Value
		$work = $work.Replace($mailMatch.Value, '').Trim(' ', ';', ',', '-', '(', ')', '[', ']')
	}

	$parts = @($work -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	if ($parts.Count -ge 2) {
		$result.LastName = [string]$parts[0]
		$result.FirstName = [string]$parts[1]
	}

	if ([string]::IsNullOrWhiteSpace($result.Email) -and ($parts.Count -eq 1) -and ($parts[0] -match '(?i)@irs\.gov$')) {
		$result.Email = [string]$parts[0]
	}

	if (-not [string]::IsNullOrWhiteSpace($result.Email)) {
		$localPart = $result.Email.Split('@')[0]
		if ($localPart -match '^[A-Za-z0-9._-]+$') {
			$candidate = ($localPart -replace '[._-]', '')
			if ($candidate.Length -ge 4 -and $candidate.Length -le 12) {
				$result.SeidCandidate = $candidate
			}
		}
	}

	return [pscustomobject]$result
}

function Find-ExternalUserFromCsv {
	param(
		[Parameter(Mandatory = $true)][string]$Seid,
		[Parameter(Mandatory = $true)][string]$CsvPath
	)

	if (-not (Test-Path -LiteralPath $CsvPath)) {
		return $null
	}

	try {
		$rows = Import-Csv -LiteralPath $CsvPath -ErrorAction Stop
	}
	catch {
		Write-Warning ("CSV lookup failed at {0}: {1}" -f $CsvPath, $_.Exception.Message)
		return $null
	}

	$match = $rows | Where-Object {
		[string]::Equals(([string]$_.SEID).Trim(), $Seid, [System.StringComparison]::OrdinalIgnoreCase)
	} | Select-Object -First 1

	if ($null -eq $match) {
		return $null
	}

	$lastLogin = $null
	if (-not [string]::IsNullOrWhiteSpace([string]$match.LastLogin)) {
		try {
			$lastLogin = ConvertTo-UserDateTime -Value ([string]$match.LastLogin) -FieldName 'Last Login'
		}
		catch {
			$lastLogin = $null
		}
	}

	$created = $null
	if (-not [string]::IsNullOrWhiteSpace([string]$match.Created)) {
		try {
			$created = ConvertTo-UserDateTime -Value ([string]$match.Created) -FieldName 'Created'
		}
		catch {
			$created = $null
		}
	}

	$modified = $null
	if (-not [string]::IsNullOrWhiteSpace([string]$match.LastModified)) {
		try {
			$modified = ConvertTo-UserDateTime -Value ([string]$match.LastModified) -FieldName 'Last Modified'
		}
		catch {
			$modified = $null
		}
	}

	$dst = $true
	if (-not [string]::IsNullOrWhiteSpace([string]$match.DaylightSavings)) {
		[void][bool]::TryParse([string]$match.DaylightSavings, [ref]$dst)
	}

	return New-ExternalUserLookupResult -Source 'CSV' -SEID ([string]$match.SEID) -FirstName ([string]$match.FirstName) -LastName ([string]$match.LastName) -Status ([string]$match.Status) -IRSEmail ([string]$match.IRSEmail) -SEIDEmail ([string]$match.SEIDEmail) -Timezone ([string]$match.Timezone) -DaylightSavings $dst -Products (Split-ProductsValue -Value ([string]$match.Products)) -LastLoginDate $lastLogin -LastPawsUsed ([string]$match.LastPawsUsed) -CreatedDate $created -LastModifiedDate $modified
}

function Find-ExternalUserFromCsvByEmail {
	param(
		[Parameter(Mandatory = $true)][string]$Email,
		[Parameter(Mandatory = $true)][string]$CsvPath
	)

	if (-not (Test-Path -LiteralPath $CsvPath)) {
		return $null
	}

	try {
		$rows = Import-Csv -LiteralPath $CsvPath -ErrorAction Stop
	}
	catch {
		Write-Warning ("CSV email lookup failed at {0}: {1}" -f $CsvPath, $_.Exception.Message)
		return $null
	}

	$match = $rows | Where-Object {
		[string]::Equals(([string]$_.IRSEmail).Trim(), $Email, [System.StringComparison]::OrdinalIgnoreCase)
	} | Select-Object -First 1

	if ($null -eq $match) {
		return $null
	}

	return Find-ExternalUserFromCsv -Seid ([string]$match.SEID) -CsvPath $CsvPath
}

function Find-ExternalUserFromAd {
	param([Parameter(Mandatory = $true)][string]$Seid)

	$adCmd = Get-Command -Name Get-ADUser -ErrorAction SilentlyContinue
	if ($null -eq $adCmd) {
		return $null
	}

	try {
		$adUser = Get-ADUser -Filter "SamAccountName -eq '$Seid'" -Properties GivenName, Surname, Mail, UserPrincipalName, LastLogonDate, WhenCreated, whenChanged -ErrorAction Stop
	}
	catch {
		Write-Verbose ("AD lookup failed for {0}: {1}" -f $Seid, $_.Exception.Message)
		return $null
	}

	if ($null -eq $adUser) {
		return $null
	}

	return New-ExternalUserLookupResult -Source 'AD' -SEID ([string]$adUser.SamAccountName) -FirstName ([string]$adUser.GivenName) -LastName ([string]$adUser.Surname) -Status 'FTE' -IRSEmail ([string]$adUser.Mail) -SEIDEmail ([string]$adUser.UserPrincipalName) -Timezone 'Washington, DC (ET) [UTC-05:00 / UTC-04:00]' -DaylightSavings $true -Products @() -LastLoginDate $adUser.LastLogonDate -LastPawsUsed '' -CreatedDate $adUser.WhenCreated -LastModifiedDate $adUser.whenChanged
}

function Find-ExternalUserFromAdByEmail {
	param([Parameter(Mandatory = $true)][string]$Email)

	$adCmd = Get-Command -Name Get-ADUser -ErrorAction SilentlyContinue
	if ($null -eq $adCmd) {
		return $null
	}

	try {
		$adUser = Get-ADUser -Filter "mail -eq '$Email'" -Properties GivenName, Surname, Mail, SamAccountName, UserPrincipalName, LastLogonDate, WhenCreated, whenChanged -ErrorAction Stop
	}
	catch {
		Write-Verbose ("AD email lookup failed for {0}: {1}" -f $Email, $_.Exception.Message)
		return $null
	}

	if ($null -eq $adUser) {
		return $null
	}

	return New-ExternalUserLookupResult -Source 'AD' -SEID ([string]$adUser.SamAccountName) -FirstName ([string]$adUser.GivenName) -LastName ([string]$adUser.Surname) -Status 'FTE' -IRSEmail ([string]$adUser.Mail) -SEIDEmail ([string]$adUser.UserPrincipalName) -Timezone 'Washington, DC (ET) [UTC-05:00 / UTC-04:00]' -DaylightSavings $true -Products @() -LastLoginDate $adUser.LastLogonDate -LastPawsUsed '' -CreatedDate $adUser.WhenCreated -LastModifiedDate $adUser.whenChanged
}

function Find-ExternalUserFromGraph {
	param([Parameter(Mandatory = $true)][string]$Seid)

	$graphCmd = Get-Command -Name Get-MgUser -ErrorAction SilentlyContinue
	if ($null -eq $graphCmd) {
		return $null
	}

	try {
		$graphUser = Get-MgUser -Filter "mailNickname eq '$Seid'" -Top 1 -Property GivenName,Surname,Mail,UserPrincipalName,CreatedDateTime -ErrorAction Stop
	}
	catch {
		try {
			$graphUser = Get-MgUser -Filter "startsWith(userPrincipalName,'$Seid@')" -Top 1 -Property GivenName,Surname,Mail,UserPrincipalName,CreatedDateTime -ErrorAction Stop
		}
		catch {
			Write-Verbose ("Graph lookup failed for {0}: {1}" -f $Seid, $_.Exception.Message)
			return $null
		}
	}

	if ($null -eq $graphUser) {
		return $null
	}

	return New-ExternalUserLookupResult -Source 'Graph' -SEID $Seid -FirstName ([string]$graphUser.GivenName) -LastName ([string]$graphUser.Surname) -Status 'FTE' -IRSEmail ([string]$graphUser.Mail) -SEIDEmail ([string]$graphUser.UserPrincipalName) -Timezone 'Washington, DC (ET) [UTC-05:00 / UTC-04:00]' -DaylightSavings $true -Products @() -LastLoginDate $null -LastPawsUsed '' -CreatedDate $graphUser.CreatedDateTime -LastModifiedDate $null
}

function Find-ExternalUserFromGraphByEmail {
	param([Parameter(Mandatory = $true)][string]$Email)

	$graphCmd = Get-Command -Name Get-MgUser -ErrorAction SilentlyContinue
	if ($null -eq $graphCmd) {
		return $null
	}

	try {
		$graphUser = Get-MgUser -Filter "mail eq '$Email'" -Top 1 -Property GivenName,Surname,Mail,UserPrincipalName,CreatedDateTime -ErrorAction Stop
	}
	catch {
		Write-Verbose ("Graph email lookup failed for {0}: {1}" -f $Email, $_.Exception.Message)
		return $null
	}

	if ($null -eq $graphUser) {
		return $null
	}

	$seid = ''
	if (-not [string]::IsNullOrWhiteSpace([string]$graphUser.UserPrincipalName)) {
		$seid = [string]$graphUser.UserPrincipalName.Split('@')[0]
	}

	return New-ExternalUserLookupResult -Source 'Graph' -SEID $seid -FirstName ([string]$graphUser.GivenName) -LastName ([string]$graphUser.Surname) -Status 'FTE' -IRSEmail ([string]$graphUser.Mail) -SEIDEmail ([string]$graphUser.UserPrincipalName) -Timezone 'Washington, DC (ET) [UTC-05:00 / UTC-04:00]' -DaylightSavings $true -Products @() -LastLoginDate $null -LastPawsUsed '' -CreatedDate $graphUser.CreatedDateTime -LastModifiedDate $null
}

function Resolve-ExternalUserBySeid {
	param([Parameter(Mandatory = $true)][string]$Seid)

	if (-not $script:ExternalLookup.Enabled) {
		return $null
	}

	if ($script:ExternalLookup.EnableCsv) {
		$csvResult = Find-ExternalUserFromCsv -Seid $Seid -CsvPath ([string]$script:ExternalLookup.CsvPath)
		if ($null -ne $csvResult) {
			return $csvResult
		}
	}

	if ($script:ExternalLookup.EnableAD) {
		$adResult = Find-ExternalUserFromAd -Seid $Seid
		if ($null -ne $adResult) {
			return $adResult
		}
	}

	if ($script:ExternalLookup.EnableGraph) {
		$graphResult = Find-ExternalUserFromGraph -Seid $Seid
		if ($null -ne $graphResult) {
			return $graphResult
		}
	}

	return $null
}

function Resolve-ExternalUserByEmail {
	param([Parameter(Mandatory = $true)][string]$Email)

	if (-not $script:ExternalLookup.Enabled) {
		return $null
	}

	if ($script:ExternalLookup.EnableCsv) {
		$csvResult = Find-ExternalUserFromCsvByEmail -Email $Email -CsvPath ([string]$script:ExternalLookup.CsvPath)
		if ($null -ne $csvResult) {
			return $csvResult
		}
	}

	if ($script:ExternalLookup.EnableAD) {
		$adResult = Find-ExternalUserFromAdByEmail -Email $Email
		if ($null -ne $adResult) {
			return $adResult
		}
	}

	if ($script:ExternalLookup.EnableGraph) {
		$graphResult = Find-ExternalUserFromGraphByEmail -Email $Email
		if ($null -ne $graphResult) {
			return $graphResult
		}
	}

	return $null
}

function Get-TrackedPawsFqdns {
	$result = New-Object System.Collections.Generic.List[string]

	if (-not (Test-Path -LiteralPath $script:SettingsPath)) {
		return $result
	}

	try {
		$raw = Get-Content -LiteralPath $script:SettingsPath -Raw -ErrorAction Stop
		$settings = $raw | ConvertFrom-Json -ErrorAction Stop
		$machines = @($settings.Tracking.Machines)
		foreach ($machine in $machines) {
			$fqdn = [string]$machine.FQDN
			if (-not [string]::IsNullOrWhiteSpace($fqdn)) {
				[void]$result.Add($fqdn.Trim())
			}
		}
	}
	catch {
		Write-Warning ("Unable to load PAWS list from settings: {0}" -f $_.Exception.Message)
	}

	return $result
}

function Import-Users {
	if (-not (Test-Path -LiteralPath $script:UsersPath)) {
		@() | ConvertTo-Json | Set-Content -LiteralPath $script:UsersPath -Encoding UTF8
	}

	$rawJson = Get-Content -LiteralPath $script:UsersPath -Raw -ErrorAction Stop
	if ([string]::IsNullOrWhiteSpace($rawJson)) {
		return ,([System.Collections.ObjectModel.ObservableCollection[object]]::new())
	}

	$parsed = $rawJson | ConvertFrom-Json -ErrorAction Stop
	$collection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	foreach ($item in @($parsed)) {
		$collection.Add((Convert-ToUserObject -RawUser $item))
	}

	return ,$collection
}

function Save-Users {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IEnumerable]$Users
	)

	$payload = New-Object System.Collections.Generic.List[object]
	foreach ($user in $Users) {
		[void]$payload.Add((Convert-FromUserObject -User $user))
	}

	$json = $payload | ConvertTo-Json -Depth 6
	Set-Content -LiteralPath $script:UsersPath -Value $json -Encoding UTF8
}

function Show-ValidationError {
	param(
		[string]$Message,
		[System.Windows.Window]$Owner
	)

	[void][System.Windows.MessageBox]::Show(
		$Owner,
		$Message,
		'Validation Error',
		[System.Windows.MessageBoxButton]::OK,
		[System.Windows.MessageBoxImage]::Warning
	)
}

function Show-EditUserDialog {
	param(
		[Parameter(Mandatory = $true)]
		[System.Windows.Window]$Owner,

		[psobject]$User,

		[Parameter(Mandatory = $true)]
		[bool]$IsNew,

		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[string[]]$PawsChoices,

		[System.Collections.IEnumerable]$LookupUsers
	)

	[xml]$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
		xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
		Title='Edit User'
		Width='640'
		Height='760'
		MinWidth='620'
		MinHeight='720'
		WindowStartupLocation='CenterOwner'
		ResizeMode='CanResize'>
	<Grid Margin='12'>
		<Grid.RowDefinitions>
			<RowDefinition Height='*'/>
			<RowDefinition Height='Auto'/>
			<RowDefinition Height='Auto'/>
		</Grid.RowDefinitions>

		<ScrollViewer Grid.Row='0' VerticalScrollBarVisibility='Auto'>
			<Grid x:Name='FormGrid' Margin='0,0,8,0'>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width='170'/>
					<ColumnDefinition Width='*'/>
				</Grid.ColumnDefinitions>
				<Grid.RowDefinitions>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
					<RowDefinition Height='Auto'/>
				</Grid.RowDefinitions>

				<TextBlock Grid.Row='0' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' FontWeight='Bold'><Run Foreground='Red'>* </Run><Run>SEID</Run></TextBlock>
				<Grid Grid.Row='0' Grid.Column='1' Margin='0,0,0,8'>
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width='*'/>
						<ColumnDefinition Width='Auto'/>
						<ColumnDefinition Width='Auto'/>
					</Grid.ColumnDefinitions>
					<TextBox x:Name='txtSeid' Grid.Column='0' Margin='0,0,8,0' MinWidth='240' Foreground='#6A0DAD' BorderBrush='Red' BorderThickness='2' FontWeight='Bold' ToolTip='Unique user identifier (case-insensitive). Required unless SEID Unknown is checked.'/>
					<CheckBox x:Name='chkSeidUnknown' Grid.Column='1' Margin='0,0,8,0' VerticalAlignment='Center' Content='SEID Unknown' ToolTip='Check if SEID is not known and will be looked up via IRS Email'/>
					<Button x:Name='btnLoadBySeid' Grid.Column='2' Width='72' Height='26' Content='Load' ToolTip='Load user data from external directory by SEID'/>
				</Grid>

				<TextBlock Grid.Row='1' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center'><Run Foreground='Red'>* </Run><Run>First Name</Run></TextBlock>
				<TextBox x:Name='txtFirstName' Grid.Row='1' Grid.Column='1' Margin='0,0,0,8' BorderBrush='Red' BorderThickness='2' ToolTip='User first name'/>

				<TextBlock Grid.Row='2' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center'><Run Foreground='Red'>* </Run><Run>Last Name</Run></TextBlock>
				<TextBox x:Name='txtLastName' Grid.Row='2' Grid.Column='1' Margin='0,0,0,8' BorderBrush='Red' BorderThickness='2' ToolTip='User last name'/>

				<TextBlock Grid.Row='3' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center'><Run Foreground='Red'>* </Run><Run>Status</Run></TextBlock>
				<ComboBox x:Name='cmbStatus' Grid.Row='3' Grid.Column='1' Margin='0,0,0,8' BorderBrush='Red' BorderThickness='2' ToolTip='Employment status: FTE (Full-Time Employee) or Contractor'/>

				<TextBlock Grid.Row='4' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' FontWeight='Bold'><Run Foreground='Red'>* </Run><Run>IRS Email</Run></TextBlock>
				<TextBox x:Name='txtIrsEmail' Grid.Row='4' Grid.Column='1' Margin='0,0,0,8' Foreground='#6A0DAD' BorderBrush='Red' BorderThickness='2' FontWeight='Bold' ToolTip='Internal IRS email address (@irs.gov). Required for email notifications.'/>

				<TextBlock Grid.Row='5' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' Text='SEID Email'/>
				<TextBox x:Name='txtSeidEmail' Grid.Row='5' Grid.Column='1' Margin='0,0,0,8' ToolTip='SEID-based email address (@ds.irsnet.gov)'/>

				<TextBlock Grid.Row='6' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center'><Run Foreground='Red'>* </Run><Run>Timezone</Run></TextBlock>
				<ComboBox x:Name='cmbTimezone' Grid.Row='6' Grid.Column='1' Margin='0,0,0,8' BorderBrush='Red' BorderThickness='2' ToolTip='User timezone for scheduling and reservations'/>

				<TextBlock Grid.Row='7' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' Text='Daylight Savings'/>
				<CheckBox x:Name='chkDst' Grid.Row='7' Grid.Column='1' Margin='0,0,0,8' VerticalAlignment='Center' Content='Observe DST' ToolTip='Check if this timezone observes Daylight Saving Time' Panel.ZIndex='100' Background='Transparent'/>

				<TextBlock Grid.Row='8' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Top' Text='Products'/>
				<Border Grid.Row='8' Grid.Column='1' Margin='0,0,0,8' BorderThickness='1' BorderBrush='#CCCCCC' Padding='0' ToolTip='Assigned products for this user'>
					<DockPanel>
						<ToggleButton x:Name='btnProductsDropDown' DockPanel.Dock='Top' Height='28' HorizontalContentAlignment='Left' Content='Select products...' ToolTip='Click to select products (SharePoint, Power Platform, OneDrive, Entra)'/>
						<Popup x:Name='popProducts' Placement='Bottom' PlacementTarget='{Binding ElementName=btnProductsDropDown}' StaysOpen='False' AllowsTransparency='True'>
							<Border Background='White' BorderThickness='1' BorderBrush='#BBBBBB' Padding='8' MinWidth='260'>
								<StackPanel x:Name='productsPanel'/>
							</Border>
						</Popup>
					</DockPanel>
				</Border>

				<TextBlock Grid.Row='9' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' Text='Last Login (ddd dd/MM/yyyy hh:mm)'/>
				<TextBox x:Name='txtLastLogin' Grid.Row='9' Grid.Column='1' Margin='0,0,0,8' ToolTip='Last login date and time in format: Fri 24/01/2025 14:30 (auto-managed, optional)'/>

				<TextBlock Grid.Row='10' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center'><Run Foreground='Red'>* </Run><Run>Last PAWS Used (FQDN)</Run></TextBlock>
				<ComboBox x:Name='cmbLastPaws' Grid.Row='10' Grid.Column='1' Margin='0,0,0,8' IsEditable='True' BorderBrush='Red' BorderThickness='2' ToolTip='Last PAWS machine used (Fully Qualified Domain Name)'/>

				<TextBlock Grid.Row='11' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' Text='Created/Modified are auto-managed.'/>
				<TextBlock x:Name='txtMetaInfo' Grid.Row='11' Grid.Column='1' Margin='0,0,0,8' Foreground='#555555' TextWrapping='Wrap' ToolTip='Displays creation and last modification timestamps'/>

				<TextBlock Grid.Row='12' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' Text='Administrator'/>
				<CheckBox x:Name='chkIsAdmin' Grid.Row='12' Grid.Column='1' Margin='0,0,0,8' VerticalAlignment='Center' Content='Is Admin (can manage reservations)' ToolTip='Check to grant admin privileges for managing reservations' Panel.ZIndex='100' Background='Transparent'/>

				<TextBlock Grid.Row='13' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' Text='Notify via Email' FontWeight='SemiBold' ToolTip='Enable email notifications for this user.'/>
				<CheckBox x:Name='chkNEmail' Grid.Row='13' Grid.Column='1' Margin='0,0,0,8' VerticalAlignment='Center' Content='Enable email notifications' ToolTip='Check to enable email notifications for session changes and alerts.' Panel.ZIndex='100' Background='Transparent'/>

				<TextBlock Grid.Row='14' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' Text='Notify via Event' FontWeight='SemiBold' ToolTip='Enable calendar event notifications for this user.'/>
				<CheckBox x:Name='chkNEvent' Grid.Row='14' Grid.Column='1' Margin='0,0,0,8' VerticalAlignment='Center' Content='Enable calendar events' ToolTip='Check to enable calendar event creation for session reservations.' Panel.ZIndex='100' Background='Transparent'/>

				<TextBlock Grid.Row='15' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Center' Text='Notify via Teams' FontWeight='SemiBold' ToolTip='Enable Microsoft Teams notifications for this user.'/>
				<CheckBox x:Name='chkNTeams' Grid.Row='15' Grid.Column='1' Margin='0,0,0,8' VerticalAlignment='Center' Content='Enable Teams chat' ToolTip='Check to enable Teams chat notifications for session changes.' Panel.ZIndex='100' Background='Transparent'/>

				<TextBlock Grid.Row='16' Grid.Column='0' Margin='0,0,10,8' VerticalAlignment='Top' Text='Teams URL' ToolTip='Direct link to Teams chat or channel for notifications.'/>
				<TextBox x:Name='txtTeamsUrl' Grid.Row='16' Grid.Column='1' Margin='0,0,0,8' TextWrapping='Wrap' VerticalAlignment='Top' MinHeight='24' ToolTip='Enter the full Teams chat URL (e.g., https://teams.microsoft.com/l/chat/...).'/>
			</Grid>
		</ScrollViewer>

		<Border Grid.Row='1' Margin='0,10,0,0' BorderBrush='#CFCFCF' BorderThickness='1' Background='#FAFAFA' Padding='6'>
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width='80'/>
					<ColumnDefinition Width='*'/>
				</Grid.ColumnDefinitions>
				<TextBlock Grid.Column='0' VerticalAlignment='Top' Margin='0,2,8,0' Text='Lookup Log:' FontWeight='SemiBold' Foreground='#444444'/>
				<TextBox x:Name='txtLookupConsole' Grid.Column='1' Height='54' MinHeight='54' IsReadOnly='True' TextWrapping='Wrap' VerticalScrollBarVisibility='Auto' FontFamily='Consolas' FontSize='12' Background='#F7F7F7' ToolTip='Real-time log of external directory lookups and validation results'/>
			</Grid>
		</Border>

		<Grid Grid.Row='2' Margin='0,12,0,0'>
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width='*'/>
				<ColumnDefinition Width='Auto'/>
			</Grid.ColumnDefinitions>

			<StackPanel Grid.Column='0' Orientation='Horizontal' HorizontalAlignment='Left'>
				<Button x:Name='btnZoomOutEdit' Width='28' Height='26' Margin='0,0,6,0' Content='-' ToolTip='Zoom out (decrease font size).'/>
				<Button x:Name='btnZoomInEdit' Width='28' Height='26' Margin='0,0,6,0' Content='+' ToolTip='Zoom in (increase font size).'/>
				<TextBlock x:Name='txtEditFontSize' VerticalAlignment='Center' Text='Font: 11.0' FontWeight='SemiBold' Foreground='#24415F' ToolTip='Current font size for form fields.'/>
			</StackPanel>

			<StackPanel Grid.Column='1' Orientation='Horizontal' HorizontalAlignment='Right'>
				<Button x:Name='btnClear' Width='90' Height='30' Margin='0,0,8,0' Content='Clear' ToolTip='Clear all form fields'/>
				<Button x:Name='btnSave' Width='90' Height='30' Margin='0,0,8,0' IsDefault='True' Content='Save' ToolTip='Save user record and close dialog'/>
				<Button x:Name='btnCancel' Width='90' Height='30' IsCancel='True' Content='Cancel' ToolTip='Discard changes and close dialog'/>
			</StackPanel>
		</Grid>
	</Grid>
</Window>
"@

	$reader = New-Object System.Xml.XmlNodeReader $xaml
	$dialog = [Windows.Markup.XamlReader]::Load($reader)
	$dialog.Owner = $Owner

	# Retrieve all dialog controls with null checks
	$txtSeid = $dialog.FindName('txtSeid')
	$chkSeidUnknown = $dialog.FindName('chkSeidUnknown')
	$btnLoadBySeid = $dialog.FindName('btnLoadBySeid')
	$txtFirstName = $dialog.FindName('txtFirstName')
	$txtLastName = $dialog.FindName('txtLastName')
	$cmbStatus = $dialog.FindName('cmbStatus')
	$txtIrsEmail = $dialog.FindName('txtIrsEmail')
	$txtSeidEmail = $dialog.FindName('txtSeidEmail')
	$cmbTimezone = $dialog.FindName('cmbTimezone')
	$chkDst = $dialog.FindName('chkDst')
	$chkIsAdmin = $dialog.FindName('chkIsAdmin')
	$chkNEmail = $dialog.FindName('chkNEmail')
	$chkNEvent = $dialog.FindName('chkNEvent')
	$chkNTeams = $dialog.FindName('chkNTeams')
	$txtTeamsUrl = $dialog.FindName('txtTeamsUrl')
	$productsPanel = $dialog.FindName('productsPanel')

	# Debug: Check if notification checkboxes were found
	if ($null -eq $chkNEmail) { Write-Host "WARNING: chkNEmail not found!" -ForegroundColor Yellow }
	if ($null -eq $chkNEvent) { Write-Host "WARNING: chkNEvent not found!" -ForegroundColor Yellow }
	if ($null -eq $chkNTeams) { Write-Host "WARNING: chkNTeams not found!" -ForegroundColor Yellow }
	$btnProductsDropDown = $dialog.FindName('btnProductsDropDown')
	$popProducts = $dialog.FindName('popProducts')
	$txtLastLogin = $dialog.FindName('txtLastLogin')
	$cmbLastPaws = $dialog.FindName('cmbLastPaws')
	$txtMetaInfo = $dialog.FindName('txtMetaInfo')
	$txtLookupConsole = $dialog.FindName('txtLookupConsole')
	$formGrid = $dialog.FindName('FormGrid')
	$btnZoomOutEdit = $dialog.FindName('btnZoomOutEdit')
	$btnZoomInEdit = $dialog.FindName('btnZoomInEdit')
	$txtEditFontSize = $dialog.FindName('txtEditFontSize')
	$btnSave = $dialog.FindName('btnSave')
	$btnClear = $dialog.FindName('btnClear')
	$btnCancel = $dialog.FindName('btnCancel')

	# Verify critical controls exist
	if ($null -eq $txtLookupConsole) {
		throw 'Failed to load dialog: txtLookupConsole control not found'
	}
	if ($null -eq $txtSeid) {
		throw 'Failed to load dialog: txtSeid control not found'
	}
	if ($null -eq $txtFirstName) {
		throw 'Failed to load dialog: txtFirstName control not found'
	}
	if ($null -eq $cmbStatus) {
		throw 'Failed to load dialog: cmbStatus control not found'
	}
	if ($null -eq $cmbTimezone) {
		throw 'Failed to load dialog: cmbTimezone control not found'
	}

	$lookupLogLines = New-Object System.Collections.Generic.List[string]
	$writeLookupLog = {
		param([string]$Message)
		$line = "[{0}] {1}" -f (Get-Date).ToString('HH:mm:ss'), $Message
		[void]$lookupLogLines.Add($line)
		while ($lookupLogLines.Count -gt 3) {
			$lookupLogLines.RemoveAt(0)
		}
		if ($null -ne $txtLookupConsole) {
			$txtLookupConsole.Text = ($lookupLogLines -join [Environment]::NewLine)
			$txtLookupConsole.ScrollToEnd()
		}
	}

	& $writeLookupLog 'Ready. Enter SEID and click Load, or enter IRS email for lookup.'

	if ($null -ne $cmbStatus) {
		foreach ($status in $script:Statuses) {
			[void]$cmbStatus.Items.Add($status)
		}
	}
	if ($null -ne $cmbTimezone) {
		foreach ($tz in $script:TimezoneOptions) {
			[void]$cmbTimezone.Items.Add($tz)
		}
	}
	if ($null -ne $cmbLastPaws) {
		foreach ($fqdn in $PawsChoices | Sort-Object -Unique) {
			[void]$cmbLastPaws.Items.Add($fqdn)
		}
	}

	$productCheckboxes = @{}
	$updateProductsCaption = {
		$selectedProducts = @()
		foreach ($product in $script:Products) {
			if ($productCheckboxes.ContainsKey($product) -and [bool]$productCheckboxes[$product].IsChecked) {
				$selectedProducts += $product
			}
		}

		if ($selectedProducts.Count -eq 0) {
			$btnProductsDropDown.Content = 'Select products...'
		}
		else {
			$btnProductsDropDown.Content = ($selectedProducts -join ', ')
		}
	}

	foreach ($product in $script:Products) {
		$check = New-Object System.Windows.Controls.CheckBox
		$check.Content = $product
		$check.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
		$check.Add_Click($updateProductsCaption)
		[void]$productsPanel.Children.Add($check)
		$productCheckboxes[$product] = $check
	}

	$btnProductsDropDown.Add_Click({
		$popProducts.IsOpen = -not $popProducts.IsOpen
	}.GetNewClosure())

	$now = Get-Date
	$working = if ($null -ne $User) {
		[pscustomobject]@{
			SEID             = ([string]$User.SEID).ToUpperInvariant()
			FirstName        = [string]$User.FirstName
			LastName         = [string]$User.LastName
			Status           = [string]$User.Status
			IRSEmail         = [string]$User.IRSEmail
			SEIDEmail        = [string]$User.SEIDEmail
			Timezone         = [string]$User.Timezone
			DaylightSavings  = [bool]$User.DaylightSavings
			Products         = @($User.Products)
			LastLoginDate    = $User.LastLoginDate
			LastPawsUsed     = [string]$User.LastPawsUsed
			CreatedDate      = $User.CreatedDate
			LastModifiedDate = $User.LastModifiedDate
		}
	}
	else {
		[pscustomobject]@{
			SEID             = ''
			FirstName        = ''
			LastName         = ''
			Status           = 'FTE'
			IRSEmail         = ''
			SEIDEmail        = ''
			Timezone         = 'Washington, DC (ET) [UTC-05:00 / UTC-04:00]'
			DaylightSavings  = $true
			Products         = @()
			LastLoginDate    = $null
			LastPawsUsed     = ''
			CreatedDate      = $now
			LastModifiedDate = $now
		}
	}

	$applyUserToDialog = {
		param([psobject]$source)

		$sourceLastLoginText = if ($source.PSObject.Properties.Name -contains 'LastLogin') { [string]$source.LastLogin } else { '' }
		$sourceCreatedText = if ($source.PSObject.Properties.Name -contains 'Created') { [string]$source.Created } else { '' }
		$sourceLastModifiedText = if ($source.PSObject.Properties.Name -contains 'LastModified') { [string]$source.LastModified } else { '' }

		if ($null -ne $txtSeid) { $txtSeid.Text = [string]$source.SEID }
		if ($null -ne $txtFirstName) { $txtFirstName.Text = [string]$source.FirstName }
		if ($null -ne $txtLastName) { $txtLastName.Text = [string]$source.LastName }
		if ($null -ne $cmbStatus) { $cmbStatus.SelectedItem = if ($script:Statuses -contains [string]$source.Status) { [string]$source.Status } else { 'FTE' } }
		if ($null -ne $txtIrsEmail) { $txtIrsEmail.Text = [string]$source.IRSEmail }
		if ($null -ne $txtSeidEmail) { $txtSeidEmail.Text = [string]$source.SEIDEmail }
		if ($null -ne $cmbTimezone) { $cmbTimezone.SelectedItem = if ($script:TimezoneOptions -contains [string]$source.Timezone) { [string]$source.Timezone } else { 'Washington, DC (ET) [UTC-05:00 / UTC-04:00]' } }
		if ($null -ne $chkDst) { $chkDst.IsChecked = [bool]$source.DaylightSavings }
		if ($null -ne $chkIsAdmin) { $chkIsAdmin.IsChecked = if ($source.PSObject.Properties.Name -contains 'IsAdmin') { [bool]$source.IsAdmin } else { $false } }
		if ($null -ne $chkNEmail) { $chkNEmail.IsChecked = if ($source.PSObject.Properties.Name -contains 'NEmail') { [bool]$source.NEmail } else { $false } }
		if ($null -ne $chkNEvent) { $chkNEvent.IsChecked = if ($source.PSObject.Properties.Name -contains 'NEvent') { [bool]$source.NEvent } else { $false } }
		if ($null -ne $chkNTeams) { $chkNTeams.IsChecked = if ($source.PSObject.Properties.Name -contains 'NTeams') { [bool]$source.NTeams } else { $false } }
		if ($null -ne $txtTeamsUrl) { $txtTeamsUrl.Text = if ($source.PSObject.Properties.Name -contains 'TeamsUrl') { [string]$source.TeamsUrl } else { '' } }
		if ($null -ne $txtLastLogin) { $txtLastLogin.Text = if ($null -ne $source.LastLoginDate) { Format-UserDateTime -Value $source.LastLoginDate } elseif (-not [string]::IsNullOrWhiteSpace($sourceLastLoginText)) { $sourceLastLoginText } else { '' } }
		if ($null -ne $cmbLastPaws) { 
			$cmbLastPaws.SelectedItem = $null
			$cmbLastPaws.Text = [string]$source.LastPawsUsed 
		}

		foreach ($product in $script:Products) {
			if ($productCheckboxes.ContainsKey($product)) {
				$productCheckboxes[$product].IsChecked = $false
			}
		}

		foreach ($selectedProduct in @($source.Products)) {
			if ($productCheckboxes.ContainsKey($selectedProduct)) {
				$productCheckboxes[$selectedProduct].IsChecked = $true
			}
		}
		& $updateProductsCaption

		$createdDateLocal = $source.CreatedDate
		$lastModifiedDateLocal = $source.LastModifiedDate
		if ($null -eq $createdDateLocal -and -not [string]::IsNullOrWhiteSpace($sourceCreatedText)) {
			$createdDateLocal = ConvertTo-UserDateTime -Value $sourceCreatedText -FieldName 'Created'
		}
		if ($null -eq $lastModifiedDateLocal -and -not [string]::IsNullOrWhiteSpace($sourceLastModifiedText)) {
			$lastModifiedDateLocal = ConvertTo-UserDateTime -Value $sourceLastModifiedText -FieldName 'Last Modified'
		}
		if ($null -eq $createdDateLocal) {
			$createdDateLocal = Get-Date
		}
		if ($null -eq $lastModifiedDateLocal) {
			$lastModifiedDateLocal = $createdDateLocal
		}

		$working.CreatedDate = $createdDateLocal
		$working.LastModifiedDate = $lastModifiedDateLocal
		if ($null -ne $txtMetaInfo) {
			$txtMetaInfo.Text = "Created: {0}`nLast Modified: {1}" -f (Format-UserDateTime -Value $working.CreatedDate), (Format-UserDateTime -Value $working.LastModifiedDate)
		}
	}

	& $applyUserToDialog $working

	$autoPopulateSeidEmail = {
		if ($null -eq $chkSeidUnknown -or $null -eq $txtSeid) {
			return
		}

		if ([bool]$chkSeidUnknown.IsChecked) {
			return
		}

		if ($null -ne $txtSeid) {
			$seid = $txtSeid.Text.Trim()
			if (-not [string]::IsNullOrWhiteSpace($seid)) {
				if ($null -ne $txtSeidEmail) { $txtSeidEmail.Text = "{0}@ds.irsnet.gov" -f $seid }
			}
			else {
				if ($null -ne $txtSeidEmail) { $txtSeidEmail.Text = '' }
			}
		}
	}

	$isNormalizingSeidText = $false
	$normalizeSeidText = {
		if ($null -eq $txtSeid -or $isNormalizingSeidText) { return }
		if ($null -ne $chkSeidUnknown -and [bool]$chkSeidUnknown.IsChecked) {
			return
		}

		$current = [string]$txtSeid.Text
		$upper = $current.ToUpperInvariant()
		if ($current -ne $upper) {
			$isNormalizingSeidText = $true
			$caretIndex = $txtSeid.CaretIndex
			$txtSeid.Text = $upper
			$txtSeid.CaretIndex = [Math]::Min($caretIndex, $txtSeid.Text.Length)
			$isNormalizingSeidText = $false
		}
	}

	$updateSeidUnknownUi = {
		if ($null -eq $chkSeidUnknown) { return }
		$isUnknown = [bool]$chkSeidUnknown.IsChecked
		if ($null -ne $txtSeid) { $txtSeid.IsEnabled = -not $isUnknown }
		if ($null -ne $btnLoadBySeid) { $btnLoadBySeid.IsEnabled = -not $isUnknown }

		if ($isUnknown) {
			if ($null -ne $txtSeid) { $txtSeid.Text = '' }
			if ($null -ne $txtSeidEmail -and -not [string]::IsNullOrWhiteSpace($txtSeidEmail.Text) -and ($txtSeidEmail.Text -match '@ds\.irsnet\.gov$')) {
				$txtSeidEmail.Text = ''
			}
		}
	}

	if ($null -ne $txtSeidEmail -and $null -ne $txtSeid -and [string]::IsNullOrWhiteSpace($txtSeidEmail.Text) -and -not [string]::IsNullOrWhiteSpace($txtSeid.Text)) {
		& $autoPopulateSeidEmail
	}

	if ($null -ne $chkSeidUnknown -and $null -ne $txtSeid) {
		$chkSeidUnknown.IsChecked = [string]::IsNullOrWhiteSpace($txtSeid.Text)
	}
	& $updateSeidUnknownUi

	if ($null -ne $txtSeid) {
		$txtSeid.Add_TextChanged($normalizeSeidText)
	}
	if ($null -ne $txtSeid) {
		$txtSeid.Add_LostFocus({
			& $normalizeSeidText
			& $autoPopulateSeidEmail
		}.GetNewClosure())
	}
	if ($null -ne $chkSeidUnknown) {
		$chkSeidUnknown.Add_Click($updateSeidUnknownUi)
	}

	if ($null -ne $txtIrsEmail) {
		$txtIrsEmail.Add_LostFocus({
			try {
				if ($null -eq $chkSeidUnknown -or $null -eq $txtSeid) {
					return
				}

				$seidUnknownMode = [bool]$chkSeidUnknown.IsChecked
				$canLookupFromEmail = $seidUnknownMode -or [string]::IsNullOrWhiteSpace($txtSeid.Text)
				if (-not $canLookupFromEmail) {
					& $writeLookupLog 'Email lookup skipped: SEID is already populated.'
					return
				}

				$parsed = ConvertFrom-IrsEmailInput -InputText $txtIrsEmail.Text
				& $writeLookupLog ("Email input parsed. Email='{0}' Name='{1} {2}' CandidateSEID='{3}'" -f [string]$parsed.Email, [string]$parsed.FirstName, [string]$parsed.LastName, [string]$parsed.SeidCandidate)
				if (-not [string]::IsNullOrWhiteSpace([string]$parsed.Email)) {
					if ($null -ne $txtIrsEmail) { $txtIrsEmail.Text = [string]$parsed.Email }
				}

				if ($null -ne $txtFirstName -and [string]::IsNullOrWhiteSpace($txtFirstName.Text) -and -not [string]::IsNullOrWhiteSpace([string]$parsed.FirstName)) {
					$txtFirstName.Text = [string]$parsed.FirstName
				}
				if ($null -ne $txtLastName -and [string]::IsNullOrWhiteSpace($txtLastName.Text) -and -not [string]::IsNullOrWhiteSpace([string]$parsed.LastName)) {
					$txtLastName.Text = [string]$parsed.LastName
				}

		# Fast path: try local lookups first (synchronous on UI thread)
		$foundByEmail = $null
		$foundByEmailSource = ''
		if (-not [string]::IsNullOrWhiteSpace([string]$parsed.Email)) {
			foreach ($candidate in @($LookupUsers)) {
				if ([string]::Equals(([string]$candidate.IRSEmail).Trim(), [string]$parsed.Email, [System.StringComparison]::OrdinalIgnoreCase)) {
					$foundByEmail = $candidate
					$foundByEmailSource = 'Local by IRS Email'
					break
				}
			}
		}

		# Name-based local fallback for patterns like: "Last First M First.Last@irs.gov".
		if ($null -eq $foundByEmail -and -not [string]::IsNullOrWhiteSpace([string]$parsed.FirstName) -and -not [string]::IsNullOrWhiteSpace([string]$parsed.LastName)) {
			& $writeLookupLog ("Trying local lookup by name: {0} {1}" -f [string]$parsed.FirstName, [string]$parsed.LastName)
			foreach ($candidate in @($LookupUsers)) {
				$candidateFirst = if ($candidate.PSObject.Properties.Name -contains 'FirstName') { [string]$candidate.FirstName } else { '' }
				$candidateLast = if ($candidate.PSObject.Properties.Name -contains 'LastName') { [string]$candidate.LastName } else { '' }
				if (
					[string]::Equals($candidateFirst.Trim(), [string]$parsed.FirstName, [System.StringComparison]::OrdinalIgnoreCase) -and
					[string]::Equals($candidateLast.Trim(), [string]$parsed.LastName, [System.StringComparison]::OrdinalIgnoreCase)
				) {
					$foundByEmail = $candidate
					$foundByEmailSource = 'Local by Name'
					break
				}
			}
		}

		if ($null -eq $foundByEmail -and -not [string]::IsNullOrWhiteSpace([string]$parsed.SeidCandidate)) {
			& $writeLookupLog ("Trying local lookup by candidate SEID: {0}" -f [string]$parsed.SeidCandidate)
			foreach ($candidate in @($LookupUsers)) {
				if ([string]::Equals(([string]$candidate.SEID).Trim(), [string]$parsed.SeidCandidate, [System.StringComparison]::OrdinalIgnoreCase)) {
					$foundByEmail = $candidate
					$foundByEmailSource = 'Local by Candidate SEID'
					break
				}
			}
		}

		if ($null -ne $foundByEmail) {
			& $applyUserToDialog $foundByEmail
			if ($null -ne $txtSeidEmail -and [string]::IsNullOrWhiteSpace($txtSeidEmail.Text)) {
				& $autoPopulateSeidEmail
			}
			& $writeLookupLog ("Lookup success: SEID '{0}' via {1}." -f [string]$foundByEmail.SEID, $foundByEmailSource)
			return
		}

		# FIX FOR UI LOCKUP: Move external lookups to background thread (async)
		# External lookups (AD/CSV/Graph) can take 5-30+ seconds and were blocking the UI thread.
		# Now they run on a background thread to keep UI responsive.
		if ((-not [string]::IsNullOrWhiteSpace([string]$parsed.Email)) -or (-not [string]::IsNullOrWhiteSpace([string]$parsed.SeidCandidate))) {
			& $writeLookupLog 'External lookup started (async, UI remains responsive)...'
			
			# Capture current dispatcher for UI updates
			$uiDispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
			
			# Run external lookups on background thread
			[System.Threading.Tasks.Task]::Run({
				try {
					$externalEmail = $null
					$externalSeid = $null
					$lookupSource = ''
					
					# Try external email lookup
					if (-not [string]::IsNullOrWhiteSpace([string]$parsed.Email)) {
						$externalEmail = Resolve-ExternalUserByEmail -Email ([string]$parsed.Email)
						if ($null -ne $externalEmail) {
							$lookupSource = ("External by IRS Email ({0})" -f [string]$externalEmail.Source)
						}
					}
					
					# Try external SEID lookup as fallback
					if ($null -eq $externalEmail -and -not [string]::IsNullOrWhiteSpace([string]$parsed.SeidCandidate)) {
						$externalSeid = Resolve-ExternalUserBySeid -Seid ([string]$parsed.SeidCandidate)
						if ($null -ne $externalSeid) {
							$lookupSource = ("External by Candidate SEID ({0})" -f [string]$externalSeid.Source)
						}
					}
					
					# Update UI via dispatcher callback
					[void]$uiDispatcher.BeginInvoke({
						try {
							$result = if ($null -ne $externalEmail) { $externalEmail } else { $externalSeid }
							if ($null -ne $result) {
								$foundByEmailConverted = [pscustomobject]@{
									SEID             = ([string]$result.SEID).ToUpperInvariant()
									FirstName        = [string]$result.FirstName
									LastName         = [string]$result.LastName
									Status           = [string]$result.Status
									IRSEmail         = [string]$result.IRSEmail
									SEIDEmail        = [string]$result.SEIDEmail
									Timezone         = [string]$result.Timezone
									DaylightSavings  = [bool]$result.DaylightSavings
									Products         = @($result.Products)
									LastLoginDate    = $result.LastLoginDate
									LastLogin        = if ($null -ne $result.LastLoginDate) { Format-UserDateTime -Value $result.LastLoginDate } else { '' }
									LastPawsUsed     = [string]$result.LastPawsUsed
									CreatedDate      = $result.CreatedDate
									Created          = if ($null -ne $result.CreatedDate) { Format-UserDateTime -Value $result.CreatedDate } else { '' }
									LastModifiedDate = $result.LastModifiedDate
									LastModified     = if ($null -ne $result.LastModifiedDate) { Format-UserDateTime -Value $result.LastModifiedDate } else { '' }
								}
								& $applyUserToDialog $foundByEmailConverted
								if ($null -ne $txtSeidEmail -and [string]::IsNullOrWhiteSpace($txtSeidEmail.Text)) {
									& $autoPopulateSeidEmail
								}
								& $writeLookupLog ("Lookup success: SEID '{0}' via {1}." -f [string]$foundByEmailConverted.SEID, $lookupSource)
							} else {
								# If no record found, populate candidate SEID
								if ($null -ne $txtSeid -and [string]::IsNullOrWhiteSpace($txtSeid.Text) -and -not [string]::IsNullOrWhiteSpace([string]$parsed.SeidCandidate)) {
									$txtSeid.Text = ([string]$parsed.SeidCandidate).ToUpperInvariant()
									if ($null -ne $txtSeidEmail -and [string]::IsNullOrWhiteSpace($txtSeidEmail.Text)) {
										& $autoPopulateSeidEmail
									}
									& $writeLookupLog ("No directory match. Filled candidate SEID '{0}' from IRS email." -f [string]$parsed.SeidCandidate)
								} else {
									& $writeLookupLog 'Lookup result: no match found from email input.'
								}
							}
						} catch {
							& $writeLookupLog ("Lookup error: {0}" -f $_.Exception.Message)
						}
					}, [System.Windows.Threading.DispatcherPriority]::Normal) | Out-Null
				} catch {
					# Log background thread errors
					[void]$uiDispatcher.BeginInvoke({
						& $writeLookupLog ("Background lookup error: {0}" -f $_.Exception.Message)
					}, [System.Windows.Threading.DispatcherPriority]::Normal) | Out-Null
				}
			}) | Out-Null
		}
		}
		catch {
			# Silently ignore errors in email lookup to prevent dialog initialization failures
		}
	}.GetNewClosure())
	}

	# Quick parse on TextChanged for immediate name population when email is pasted
	if ($null -ne $txtIrsEmail) {
		$txtIrsEmail.Add_TextChanged({
			try {
				if ($null -eq $txtIrsEmail -or $null -eq $txtFirstName -or $null -eq $txtLastName) {
					return
				}

				$emailText = [string]$txtIrsEmail.Text

			# Only process if there's actual text and the field is not being cleared
			if (-not [string]::IsNullOrWhiteSpace($emailText) -and $emailText.Length -gt 3) {
				$parsed = ConvertFrom-IrsEmailInput -InputText $emailText

				# Populate FirstName if blank and we have a parsed value
				if (([string]::IsNullOrWhiteSpace($txtFirstName.Text)) -and (-not [string]::IsNullOrWhiteSpace([string]$parsed.FirstName))) {
					$txtFirstName.Text = [string]$parsed.FirstName
				}

				# Populate LastName if blank and we have a parsed value
				if (([string]::IsNullOrWhiteSpace($txtLastName.Text)) -and (-not [string]::IsNullOrWhiteSpace([string]$parsed.LastName))) {
					$txtLastName.Text = [string]$parsed.LastName
				}

				# If no names extracted yet, try parsing from email local part (e.g., "john.smith@irs.gov")
				if ((([string]::IsNullOrWhiteSpace($txtFirstName.Text)) -or ([string]::IsNullOrWhiteSpace($txtLastName.Text))) -and (-not [string]::IsNullOrWhiteSpace([string]$parsed.Email))) {
					if ($null -ne $parsed.Email -and $parsed.Email.Contains('@')) {
						$localPart = $parsed.Email.Split('@')[0]
						if (-not [string]::IsNullOrWhiteSpace($localPart)) {
							$nameParts = @($localPart -split '[._-]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
							
							if ($nameParts.Count -ge 2) {
								if ([string]::IsNullOrWhiteSpace($txtFirstName.Text)) {
									try {
										$txtFirstName.Text = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ToTitleCase($nameParts[0].ToLower())
									}
									catch { }
								}
								if ([string]::IsNullOrWhiteSpace($txtLastName.Text)) {
									try {
										$txtLastName.Text = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ToTitleCase($nameParts[1].ToLower())
									}
									catch { }
								}
							}
						}
					}
				}
			}
		}
		catch {
			# Silently ignore errors during auto-population to prevent dialog initialization failures
		}
	}.GetNewClosure())
	}

	if ($null -ne $btnLoadBySeid) {
		$btnLoadBySeid.Add_Click({
			if ($null -eq $txtSeid) {
				return
			}

			$lookupSeid = $txtSeid.Text.Trim()
			if ([string]::IsNullOrWhiteSpace($lookupSeid)) {
				& $writeLookupLog 'SEID Load skipped: SEID is blank.'
				Show-ValidationError -Message 'Enter a SEID first, then click Load.' -Owner $dialog
				return
			}

			& $writeLookupLog ("Trying local/external lookup for SEID '{0}'..." -f $lookupSeid)

		$found = $null
		$candidates = @($LookupUsers)
		foreach ($candidate in $candidates) {
			if ([string]::Equals(([string]$candidate.SEID).Trim(), $lookupSeid, [System.StringComparison]::OrdinalIgnoreCase)) {
				$found = $candidate
				break
			}
		}

		if ($null -eq $found) {
			$external = Resolve-ExternalUserBySeid -Seid $lookupSeid
			if ($null -eq $external) {
				& $writeLookupLog ("No match found for SEID '{0}' in local or external sources." -f $lookupSeid)
				[void][System.Windows.MessageBox]::Show(
					$dialog,
					("No user found for SEID '{0}' in local or enabled external sources." -f $lookupSeid),
					'Load User',
					[System.Windows.MessageBoxButton]::OK,
					[System.Windows.MessageBoxImage]::Information
				)
				return
			}

			$found = [pscustomobject]@{
				SEID             = ([string]$external.SEID).ToUpperInvariant()
				FirstName        = [string]$external.FirstName
				LastName         = [string]$external.LastName
				Status           = [string]$external.Status
				IRSEmail         = [string]$external.IRSEmail
				SEIDEmail        = [string]$external.SEIDEmail
				Timezone         = [string]$external.Timezone
				DaylightSavings  = [bool]$external.DaylightSavings
				Products         = @($external.Products)
				LastLoginDate    = $external.LastLoginDate
				LastLogin        = if ($null -ne $external.LastLoginDate) { Format-UserDateTime -Value $external.LastLoginDate } else { '' }
				LastPawsUsed     = [string]$external.LastPawsUsed
				CreatedDate      = $external.CreatedDate
				Created          = if ($null -ne $external.CreatedDate) { Format-UserDateTime -Value $external.CreatedDate } else { '' }
				LastModifiedDate = $external.LastModifiedDate
				LastModified     = if ($null -ne $external.LastModifiedDate) { Format-UserDateTime -Value $external.LastModifiedDate } else { '' }
				LookupSource     = [string]$external.Source
			}
		}

		$loaded = [pscustomobject]@{
			SEID             = ([string]$found.SEID).ToUpperInvariant()
			FirstName        = [string]$found.FirstName
			LastName         = [string]$found.LastName
			Status           = [string]$found.Status
			IRSEmail         = [string]$found.IRSEmail
			SEIDEmail        = [string]$found.SEIDEmail
			Timezone         = [string]$found.Timezone
			DaylightSavings  = [bool]$found.DaylightSavings
			Products         = @($found.Products)
			LastLoginDate    = $found.LastLoginDate
			LastLogin        = [string]$found.LastLogin
			LastPawsUsed     = [string]$found.LastPawsUsed
			CreatedDate      = $found.CreatedDate
			Created          = [string]$found.Created
			LastModifiedDate = $found.LastModifiedDate
			LastModified     = [string]$found.LastModified
		}

		& $applyUserToDialog $loaded
		if ($null -ne $txtSeidEmail -and [string]::IsNullOrWhiteSpace($txtSeidEmail.Text)) {
			& $autoPopulateSeidEmail
		}
		$lookupSourceText = if ($found.PSObject.Properties.Name -contains 'LookupSource') { [string]$found.LookupSource } else { '' }
		& $writeLookupLog ("Load success: SEID '{0}'{1}." -f $lookupSeid, $(if (-not [string]::IsNullOrWhiteSpace($lookupSourceText)) { " from $lookupSourceText" } else { ' from local list' }))
		[void][System.Windows.MessageBox]::Show(
			$dialog,
			("Loaded details for SEID '{0}'{1}." -f $lookupSeid, $(if (-not [string]::IsNullOrWhiteSpace($lookupSourceText)) { " from $lookupSourceText" } else { '' })),
			'Load User',
			[System.Windows.MessageBoxButton]::OK,
			[System.Windows.MessageBoxImage]::Information
		)
	}.GetNewClosure())
	}

	# Zoom controls for form grid - load from settings
	$zoomLevels = Get-UserEditorZoomLevels
	$editZoomLevel = $zoomLevels.EditZoom

	$applyEditZoom = {
		param([double]$Zoom)
		$zoomClamped = [Math]::Max(0.70, [Math]::Min(2.00, $Zoom))
		$script:editZoomLevel = [Math]::Round($zoomClamped, 2)
		$fontSize = [Math]::Round(11.0 * $script:editZoomLevel, 1)

		# Apply font size to form grid
		if ($null -ne $formGrid) {
			$formGrid.FontSize = $fontSize
		}

		# Update label
		if ($null -ne $txtEditFontSize) {
			$txtEditFontSize.Text = "Font: $fontSize"
		}

		# Save zoom level to settings
		Save-UserEditorZoomLevel -ZoomType 'Edit' -ZoomLevel $script:editZoomLevel
	}

	# Initialize zoom
	& $applyEditZoom -Zoom $editZoomLevel

	# Zoom button handlers
	if ($null -ne $btnZoomOutEdit) {
		$btnZoomOutEdit.Add_Click({
			& $applyEditZoom -Zoom ($script:editZoomLevel - 0.10)
		}.GetNewClosure())
	}

	if ($null -ne $btnZoomInEdit) {
		$btnZoomInEdit.Add_Click({
			& $applyEditZoom -Zoom ($script:editZoomLevel + 0.10)
		}.GetNewClosure())
	}

	if ($null -ne $btnClear) {
		$btnClear.Add_Click({
			# Clear all form fields
			if ($null -ne $txtSeid) { $txtSeid.Text = '' }
			if ($null -ne $chkSeidUnknown) { $chkSeidUnknown.IsChecked = $false }
			if ($null -ne $txtFirstName) { $txtFirstName.Text = '' }
			if ($null -ne $txtLastName) { $txtLastName.Text = '' }
			if ($null -ne $cmbStatus) { $cmbStatus.SelectedItem = 'FTE' }
			if ($null -ne $txtIrsEmail) { $txtIrsEmail.Text = '' }
			if ($null -ne $txtSeidEmail) { $txtSeidEmail.Text = '' }
			if ($null -ne $cmbTimezone) { $cmbTimezone.SelectedItem = 'Washington, DC (ET) [UTC-05:00 / UTC-04:00]' }
			if ($null -ne $chkDst) { $chkDst.IsChecked = $true }
			if ($null -ne $chkIsAdmin) { $chkIsAdmin.IsChecked = $false }
			if ($null -ne $chkNEmail) { $chkNEmail.IsChecked = $false }
			if ($null -ne $chkNEvent) { $chkNEvent.IsChecked = $false }
			if ($null -ne $chkNTeams) { $chkNTeams.IsChecked = $false }
			if ($null -ne $txtTeamsUrl) { $txtTeamsUrl.Text = '' }
			if ($null -ne $txtLastLogin) { $txtLastLogin.Text = '' }
			if ($null -ne $cmbLastPaws) { $cmbLastPaws.Text = ''; $cmbLastPaws.SelectedItem = $null }
			
			# Clear all product checkboxes
			foreach ($product in $script:Products) {
				if ($productCheckboxes.ContainsKey($product)) {
					$productCheckboxes[$product].IsChecked = $false
				}
			}
			& $updateProductsCaption
			
			& $writeLookupLog 'Form cleared.'
			if ($null -ne $txtSeid) { $txtSeid.Focus() }
		}.GetNewClosure())
	}

	if ($null -ne $btnSave) {
		$btnSave.Add_Click({
		$seid = if ($null -ne $txtSeid) { $txtSeid.Text.Trim() } else { '' }
		$seidUnknown = if ($null -ne $chkSeidUnknown) { [bool]$chkSeidUnknown.IsChecked } else { $false }
		$firstName = if ($null -ne $txtFirstName) { $txtFirstName.Text.Trim() } else { '' }
		$lastName = if ($null -ne $txtLastName) { $txtLastName.Text.Trim() } else { '' }
		$status = if ($null -ne $cmbStatus) { [string]$cmbStatus.SelectedItem } else { '' }
		$irsEmail = if ($null -ne $txtIrsEmail) { $txtIrsEmail.Text.Trim() } else { '' }
		$seidEmail = if ($null -ne $txtSeidEmail) { $txtSeidEmail.Text.Trim() } else { '' }
		$timezone = if ($null -ne $cmbTimezone) { [string]$cmbTimezone.SelectedItem } else { '' }
		$dst = if ($null -ne $chkDst) { [bool]$chkDst.IsChecked } else { $false }
		$lastPaws = if ($null -ne $cmbLastPaws) { if ($cmbLastPaws.SelectedItem) { [string]$cmbLastPaws.SelectedItem } else { $cmbLastPaws.Text.Trim() } } else { '' }

		if ((-not $seidUnknown) -and [string]::IsNullOrWhiteSpace($seid)) {
			Show-ValidationError -Message 'SEID is required.' -Owner $dialog
			return
		}
		if ([string]::IsNullOrWhiteSpace($firstName)) {
			Show-ValidationError -Message 'First Name is required.' -Owner $dialog
			return
		}
		if ([string]::IsNullOrWhiteSpace($lastName)) {
			Show-ValidationError -Message 'Last Name is required.' -Owner $dialog
			return
		}
		if (-not ($script:Statuses -contains $status)) {
			Show-ValidationError -Message 'Status must be FTE or Contractor.' -Owner $dialog
			return
		}
		if ([string]::IsNullOrWhiteSpace($irsEmail) -or -not $irsEmail.EndsWith('@irs.gov', [System.StringComparison]::OrdinalIgnoreCase)) {
			Show-ValidationError -Message 'IRS Email must end with @irs.gov.' -Owner $dialog
			return
		}
		if ([string]::IsNullOrWhiteSpace($seidEmail) -and -not [string]::IsNullOrWhiteSpace($seid)) {
			$seidEmail = "{0}@ds.irsnet.gov" -f $seid
		}
		if ((-not [string]::IsNullOrWhiteSpace($seidEmail)) -and (-not ($seidEmail -match '^[^@\s]+@ds\.irsnet\.gov$'))) {
			Show-ValidationError -Message 'SEID Email must use @ds.irsnet.gov domain.' -Owner $dialog
			return
		}
		if (-not ($script:TimezoneOptions -contains $timezone)) {
			Show-ValidationError -Message 'Please select a valid timezone.' -Owner $dialog
			return
		}
		if ([string]::IsNullOrWhiteSpace($lastPaws) -or -not ($lastPaws -match '^[A-Za-z0-9][A-Za-z0-9\.-]*\.[A-Za-z]{2,}$')) {
			Show-ValidationError -Message 'Last PAWS Used must be an FQDN (for example: mtb012vp0030366.ds.irsnet.gov).' -Owner $dialog
			return
		}

		$selectedProducts = @()
		foreach ($product in $script:Products) {
			if ($productCheckboxes.ContainsKey($product) -and [bool]$productCheckboxes[$product].IsChecked) {
				$selectedProducts += $product
			}
		}

		$lastLoginDate = $null
		if ($null -ne $txtLastLogin -and [string]::IsNullOrWhiteSpace($txtLastLogin.Text)) {
			# Last Login is optional - will be set to current time if new user
			$lastLoginDate = $null
		}
		elseif ($null -ne $txtLastLogin) {
			try {
				$lastLoginDate = ConvertTo-UserDateTime -Value $txtLastLogin.Text.Trim() -FieldName 'Last Login'
			}
			catch {
				Show-ValidationError -Message $_.Exception.Message -Owner $dialog
				return
			}
		}

		$createdDate = if ($IsNew) { Get-Date } else { $working.CreatedDate }
		if ($null -eq $createdDate) {
			$createdDate = Get-Date
		}
		$lastModifiedDate = Get-Date

		$dialog.Tag = [pscustomobject]@{
			SEID             = $seid.ToUpperInvariant()
			FirstName        = $firstName
			LastName         = $lastName
			Status           = $status
			IRSEmail         = $irsEmail
			SEIDEmail        = $seidEmail
			Timezone         = $timezone
			DaylightSavings  = $dst
			Products         = $selectedProducts
			ProductsDisplay  = ($selectedProducts -join ', ')
			LastLoginDate    = $lastLoginDate
			LastLogin        = if ($null -ne $lastLoginDate) { Format-UserDateTime -Value $lastLoginDate } else { '' }
			LastPawsUsed     = $lastPaws
			LastModifiedDate = $lastModifiedDate
			LastModified     = Format-UserDateTime -Value $lastModifiedDate
			CreatedDate      = $createdDate
			Created          = Format-UserDateTime -Value $createdDate
			IsAdmin          = [bool]$chkIsAdmin.IsChecked
			NEmail           = [bool]$chkNEmail.IsChecked
			NEvent           = [bool]$chkNEvent.IsChecked
			NTeams           = [bool]$chkNTeams.IsChecked
			TeamsUrl         = [string]$txtTeamsUrl.Text
		}

		$dialog.DialogResult = $true
		$dialog.Close()
	}.GetNewClosure())
	}

	$result = $dialog.ShowDialog()
	if ($result -eq $true -and $null -ne $dialog.Tag) {
		return $dialog.Tag
	}

	return $null
}

[xml]$mainXaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
		xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
		Title='TrackSessions User Editor'
		Width='1560'
		Height='700'
		MinWidth='1200'
		MinHeight='500'
		WindowStartupLocation='CenterScreen'
		Topmost='True'>
	<DockPanel Margin='10'>
		<StackPanel Orientation='Horizontal' DockPanel.Dock='Top' Margin='0,0,0,10'>
		<Button x:Name='btnNew' Width='95' Height='30' Margin='0,0,8,0' Content='New...' ToolTip='Create a new user record'/>
		<Button x:Name='btnEdit' Width='95' Height='30' Margin='0,0,8,0' Content='Edit...' ToolTip='Edit the selected user (select a row first)' IsEnabled='False'/>
		<Button x:Name='btnDelete' Width='95' Height='30' Margin='0,0,8,0' Content='Delete' ToolTip='Delete the selected user (select a row first)'/>
		<Button x:Name='btnSaveAll' Width='120' Height='30' Margin='0,0,8,0' Content='Save All' ToolTip='Save all user records to file (TrackSessions.Users.json)'/>
		<Button x:Name='btnRefresh' Width='95' Height='30' Margin='0,0,16,0' Content='Refresh' ToolTip='Reload all users from file (discards unsaved changes)'/>
		<Button x:Name='btnZoomOutGrid' Width='28' Height='30' Margin='0,0,6,0' Content='-' ToolTip='Zoom out (decrease grid font size)'/>
		<Button x:Name='btnZoomInGrid' Width='28' Height='30' Margin='0,0,6,0' Content='+' ToolTip='Zoom in (increase grid font size)'/>
		<TextBlock x:Name='txtGridFontSize' VerticalAlignment='Center' Text='Font: 12.0' FontWeight='SemiBold' Foreground='#24415F' ToolTip='Current font size for grid'/>
		</StackPanel>

		<Border DockPanel.Dock='Bottom' Background='#F0F4F8' BorderBrush='#BED8FA' BorderThickness='0,1,0,0' Padding='10,6' Margin='0,10,0,0'>
			<TextBlock x:Name='txtStatus' Text='Ready' Foreground='#325275' FontSize='12' ToolTip='Status information and user count'/>
		</Border>

		<DataGrid x:Name='gridUsers'
				  AutoGenerateColumns='False'
				  IsReadOnly='False'
				  CanUserAddRows='False'
				  CanUserDeleteRows='False'
				  SelectionMode='Single'
				  SelectionUnit='FullRow'
				  GridLinesVisibility='Horizontal'
				  AlternatingRowBackground='#F5F7FA'
				  ToolTip='Click to select a user. Double-click to edit. Use buttons above for other actions.'>
			<DataGrid.Columns>
				<DataGridTextColumn Binding='{Binding SEID}' Width='110' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='SEID' ToolTip='Unique user identifier (case-insensitive)' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding FirstName}' Width='120' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='First Name' ToolTip='User first name' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding LastName}' Width='120' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='Last Name' ToolTip='User last name' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding Status}' Width='95' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='Status' ToolTip='FTE (Full-Time Employee) or Contractor' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding IRSEmail}' Width='190' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='IRS Email' ToolTip='Internal IRS email address (@irs.gov)' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding SEIDEmail}' Width='205' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='SEID Email' ToolTip='SEID-based email (@ds.irsnet.gov)' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding Timezone}' Width='240' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='Timezone' ToolTip='User timezone and DST rules' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridCheckBoxColumn Binding='{Binding DaylightSavings}' Width='60'>
					<DataGridCheckBoxColumn.Header>
						<TextBlock Text='DST' ToolTip='Observe Daylight Saving Time' TextWrapping='Wrap'/>
					</DataGridCheckBoxColumn.Header>
				</DataGridCheckBoxColumn>
				<DataGridTextColumn Binding='{Binding ProductsDisplay}' Width='170' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='Products' ToolTip='Assigned products (SharePoint, Power Platform, OneDrive, Entra)' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding LastLogin}' Width='145' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='Last Login' ToolTip='Last login date and time' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding LastPawsUsed}' Width='220' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='Last PAWS Used' ToolTip='Last PAWS machine used (FQDN)' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding LastModified}' Width='160' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='Last Modified' ToolTip='Last modification date and time (auto-managed)' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridTextColumn Binding='{Binding Created}' Width='160' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='Created' ToolTip='User creation date and time (auto-managed)' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
				<DataGridCheckBoxColumn Binding='{Binding NEmail}' Width='70'>
					<DataGridCheckBoxColumn.Header>
						<TextBlock Text='Email' ToolTip='Enable email notifications for this user' TextWrapping='Wrap'/>
					</DataGridCheckBoxColumn.Header>
				</DataGridCheckBoxColumn>
				<DataGridCheckBoxColumn Binding='{Binding NEvent}' Width='70'>
					<DataGridCheckBoxColumn.Header>
						<TextBlock Text='Event' ToolTip='Enable calendar event notifications for this user' TextWrapping='Wrap'/>
					</DataGridCheckBoxColumn.Header>
				</DataGridCheckBoxColumn>
				<DataGridCheckBoxColumn Binding='{Binding NTeams}' Width='70'>
					<DataGridCheckBoxColumn.Header>
						<TextBlock Text='Teams' ToolTip='Enable Teams chat notifications for this user' TextWrapping='Wrap'/>
					</DataGridCheckBoxColumn.Header>
				</DataGridCheckBoxColumn>
				<DataGridTextColumn Binding='{Binding TeamsUrl}' Width='280' IsReadOnly='True'>
					<DataGridTextColumn.Header>
						<TextBlock Text='Teams URL' ToolTip='Direct link to Teams chat or channel' TextWrapping='Wrap'/>
					</DataGridTextColumn.Header>
				</DataGridTextColumn>
			</DataGrid.Columns>
		</DataGrid>
	</DockPanel>
</Window>
"@

$mainReader = New-Object System.Xml.XmlNodeReader $mainXaml
$window = [Windows.Markup.XamlReader]::Load($mainReader)

$btnNew = $window.FindName('btnNew')
$btnEdit = $window.FindName('btnEdit')
$btnDelete = $window.FindName('btnDelete')
$btnSaveAll = $window.FindName('btnSaveAll')
$btnRefresh = $window.FindName('btnRefresh')
$btnZoomOutGrid = $window.FindName('btnZoomOutGrid')
$btnZoomInGrid = $window.FindName('btnZoomInGrid')
$txtGridFontSize = $window.FindName('txtGridFontSize')
$txtStatus = $window.FindName('txtStatus')
$gridUsers = $window.FindName('gridUsers')

$users = Import-Users
$gridUsers.ItemsSource = $users

# Grid zoom functionality - load from settings
$zoomLevels = Get-UserEditorZoomLevels
$gridZoomLevel = $zoomLevels.GridZoom

$applyGridZoom = {
	param([double]$Zoom)
	$zoomClamped = [Math]::Max(0.70, [Math]::Min(3.00, $Zoom))
	$script:gridZoomLevel = [Math]::Round($zoomClamped, 2)
	$fontSize = [Math]::Round(12.0 * $script:gridZoomLevel, 1)

	if ($null -ne $gridUsers) {
		$gridUsers.FontSize = $fontSize
	}

	if ($null -ne $txtGridFontSize) {
		$txtGridFontSize.Text = "Font: $fontSize"
	}

	# Save zoom level to settings
	Save-UserEditorZoomLevel -ZoomType 'Grid' -ZoomLevel $script:gridZoomLevel
}

& $applyGridZoom -Zoom $gridZoomLevel

if ($null -ne $btnZoomOutGrid) {
	$btnZoomOutGrid.Add_Click({
		& $applyGridZoom -Zoom ($script:gridZoomLevel - 0.10)
	}.GetNewClosure())
}

if ($null -ne $btnZoomInGrid) {
	$btnZoomInGrid.Add_Click({
		& $applyGridZoom -Zoom ($script:gridZoomLevel + 0.10)
	}.GetNewClosure())
}

$setStatus = {
	param([string]$message)
	if ($null -ne $txtStatus) {
		$txtStatus.Text = $message
	}
}

$refreshUsers = {
	$script:users = Import-Users
	$gridUsers.ItemsSource = $script:users
	$userCount = @($script:users).Count
	& $setStatus ("Refreshed {0} user(s) from {1}" -f $userCount, $script:UsersPath)
}

$saveUsers = {
	try {
		Save-Users -Users $users
		& $setStatus ("Saved {0} users to {1}" -f @($users).Count, $script:UsersPath)
	}
	catch {
		[void][System.Windows.MessageBox]::Show(
			$window,
			"Failed to save users: $($_.Exception.Message)",
			'Save Error',
			[System.Windows.MessageBoxButton]::OK,
			[System.Windows.MessageBoxImage]::Error
		)
	}
}

$openEditForSelected = {
	if ($null -eq $gridUsers) { return }
	$selected = $gridUsers.SelectedItem
	if ($null -eq $selected) {
		[void][System.Windows.MessageBox]::Show(
			$window,
			'Select a user first.',
			'Edit User',
			[System.Windows.MessageBoxButton]::OK,
			[System.Windows.MessageBoxImage]::Information
		)
		return
	}

	$pawsChoices = Get-TrackedPawsFqdns
	$edited = Show-EditUserDialog -Owner $window -User $selected -IsNew $false -PawsChoices @($pawsChoices) -LookupUsers $users
	if ($null -ne $edited) {
		$index = $users.IndexOf($selected)
		if ($index -ge 0) {
			$users[$index] = $edited
			# Suppress selection change events during refresh
			$isProcessingSelectionChange = $true
			try {
				$gridUsers.Items.Refresh()
				$gridUsers.SelectedIndex = $index
			}
			finally {
				$isProcessingSelectionChange = $false
			}
			& $setStatus ("Updated user {0}." -f $edited.SEID)
		}
	}
}

$btnNew.Add_Click({
	if ($null -eq $gridUsers) { return }
	$pawsChoices = Get-TrackedPawsFqdns
	$newUser = Show-EditUserDialog -Owner $window -User $null -IsNew $true -PawsChoices @($pawsChoices) -LookupUsers $users
	if ($null -ne $newUser) {
		$existing = @($users | Where-Object { $_.SEID -eq $newUser.SEID })
		if ($existing.Count -gt 0) {
			[void][System.Windows.MessageBox]::Show(
				$window,
				"A user with SEID '$($newUser.SEID)' already exists.",
				'Duplicate SEID',
				[System.Windows.MessageBoxButton]::OK,
				[System.Windows.MessageBoxImage]::Warning
			)
			return
		}

		$users.Add($newUser)
		$gridUsers.SelectedItem = $newUser
		& $setStatus ("Added user {0}." -f $newUser.SEID)
	}
}.GetNewClosure())

if ($null -ne $btnEdit) {
	$btnEdit.Add_Click($openEditForSelected)
}

if ($null -ne $gridUsers) {
	$gridUsers.Add_MouseDoubleClick({
		try {
			if ($null -ne $gridUsers.SelectedItem) {
				& $openEditForSelected
			}
		}
		catch {
			# Silently ignore errors in double-click handler
		}
	}.GetNewClosure())
}

$btnDelete.Add_Click({
	if ($null -eq $gridUsers) { return }
	$selected = $gridUsers.SelectedItem
	if ($null -eq $selected) {
		[void][System.Windows.MessageBox]::Show(
			$window,
			'Select a user first.',
			'Delete User',
			[System.Windows.MessageBoxButton]::OK,
			[System.Windows.MessageBoxImage]::Information
		)
		return
	}

	$confirm = [System.Windows.MessageBox]::Show(
		$window,
		"Delete user '$($selected.SEID)'?",
		'Confirm Delete',
		[System.Windows.MessageBoxButton]::YesNo,
		[System.Windows.MessageBoxImage]::Question
	)
	if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
		return
	}

	[void]$users.Remove($selected)
	& $setStatus ("Deleted user {0}." -f $selected.SEID)
}.GetNewClosure())

if ($null -ne $btnSaveAll) {
	$btnSaveAll.Add_Click($saveUsers)
}
if ($null -ne $btnRefresh) {
	$btnRefresh.Add_Click($refreshUsers)
}

# Guard against recursive event handling
$isProcessingSelectionChange = $false

# Enable/disable Edit button based on grid selection
if ($null -ne $gridUsers) {
	$gridUsers.Add_SelectionChanged({
		if ($isProcessingSelectionChange) { return }
		$isProcessingSelectionChange = $true
		try {
			if ($null -ne $btnEdit -and $null -ne $gridUsers) {
				$btnEdit.IsEnabled = ($null -ne $gridUsers.SelectedItem)
			}
		}
		catch {
			# Silently ignore errors in selection change handler
		}
		finally {
			$isProcessingSelectionChange = $false
		}
	}.GetNewClosure())

	# Auto-save when checkboxes are toggled in the grid
	$gridUsers.Add_CellEditEnding({
		param($sender, $e)
		try {
			# Wait for the edit to commit, then save
			$window.Dispatcher.BeginInvoke([Action]{
				try {
					Save-Users -Users $users
					& $setStatus ("Auto-saved {0} users after checkbox change" -f @($users).Count)
				}
				catch {
					& $setStatus ("ERROR: Failed to auto-save: $($_.Exception.Message)")
				}
			}, [System.Windows.Threading.DispatcherPriority]::Background)
		}
		catch {
			# Silently ignore errors
		}
	}.GetNewClosure())
}

$window.Add_Closing({
	try {
		Save-Users -Users $users
	}
	catch {
		[void][System.Windows.MessageBox]::Show(
			$window,
			"Failed to save users on exit: $($_.Exception.Message)",
			'Save Error',
			[System.Windows.MessageBoxButton]::OK,
			[System.Windows.MessageBoxImage]::Error
		)
	}
})

# Set initial status with user count
$userCount = @($users).Count
& $setStatus ("Ready - Total Users: {0}" -f $userCount)

[void]$window.ShowDialog()
