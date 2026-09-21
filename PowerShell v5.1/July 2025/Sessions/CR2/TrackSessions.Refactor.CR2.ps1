# Sessions\TrackSessions.Simulator CR1.ps1
# ▶️▶️▶️ CURRENT
# 9:48 AM 9/19/2026 
# merged back to Sessions\TrackSessions.Simulator CR1.ps1
# by copyng
# Candidate Release 1
# Fri 9-18-2026 merge 
# changes between
# Sessions\PAWS-Candidates\TrackSessions.Simulator CR1.PreReserve.2026-09-07.ps1
# and 
# Sessions\PAWS-Candidates\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1
# ...
# Release for Rizu, Ben, Ron, Efrain, Carlos
# 9:48 AM 9/19/2026 
# merged back to Sessions\TrackSessions.Simulator CR1.ps1
# by copyng
# Candidate Release 1
# Fri 9-18-2026 merge 

# changes between
# Sessions\PAWS-Candidates\TrackSessions.Simulator CR1.PreReserve.2026-09-07.ps1
# and 
# Sessions\PAWS-Candidates\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1



[CmdletBinding()]
param(
	[string]$OutputFolder = "$env:ProgramData\SessionTracker\Json",
	[switch]$RegisterLogonTask,
	[string]$TaskName = "TrackSessionsWpf",
	[string]$SettingsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Background loading state
$script:BackgroundLoadingState = @{
	UserContextLoaded = $false
	SessionsLoaded = $false
	LoadingInProgress = $true
	UserContext = $null
	SessionData = @()
}

# Background job variables (initialized to null)
$script:userContextJob = $null
$script:sessionLoadJob = $null
$script:pollTimer = $null
$script:refreshJob = $null
$script:refreshPollTimer = $null

# Global admin mode flag (set during initialization)
$script:isCurrentUserAdmin = $false

$script:LayoutConstraintTuning = [ordered]@{
	TopVisibleRows = 4
	BottomVisibleRows = 4
	TopRowBaseMinHeight = 24.0
	TopRowFontMultiplier = 2.1
	TopPanePadding = 24.0
	GridHeaderBaseMinHeight = 24.0
	GridRowBaseMinHeight = 20.0
	GridRowsBottomPadding = 8.0
	HistoryLabelBaseMinHeight = 20.0
	HistoryLabelFontMultiplier = 1.9
	BottomPanePadding = 14.0
	WindowFrameBaseMinHeight = 200.0
}

$script:UiAdminAccentColorHex = '#0B3D91'
$script:UiDebugAccentColorHex = '#1B5E20'

function Get-UserDisplayName {
	param(
		[Parameter(Mandatory = $true)][string]$UserId,
		$UsersList
	)

	if ([string]::IsNullOrWhiteSpace($UserId)) {
		return ''
	}

	# Extract username from "DOMAIN\USERNAME" format if present
	$usernamePart = $UserId
	if ($UserId.IndexOf('\') -ge 0) {
		$usernamePart = $UserId.Split('\')[1]
	}

	# Look up user in users list by SEID (case-insensitive)
	if ($UsersList -and $UsersList.Count -gt 0) {
		foreach ($user in @($UsersList)) {
			$seid = [string]$user.SEID
			if (-not [string]::IsNullOrWhiteSpace($seid) -and $seid -eq $usernamePart) {
				$firstName = [string]$user.FirstName
				$lastName = [string]$user.LastName
				if (-not [string]::IsNullOrWhiteSpace($firstName) -and -not [string]::IsNullOrWhiteSpace($lastName)) {
					return "{0} {1}" -f $firstName, $lastName
				}
			}
		}
	}

	# Fall back to SEID if no match found
	if ($usernamePart -ne $UserId) {
		return $usernamePart
	}

	return $UserId
}

function Convert-ToSafeFileToken {
	param([Parameter(Mandatory = $true)][string]$Value)

	$safe = $Value -replace '[^A-Za-z0-9._-]', '-'
	$safe = $safe.Trim('-')
	if ([string]::IsNullOrWhiteSpace($safe)) {
		return 'Unknown'
	}
	return $safe
}

#region Background Job Helper Functions

function Start-BackgroundUserContextJob {
	<#
	.SYNOPSIS
	Starts background job to get user context with timeout
	.DESCRIPTION
	Non-blocking version of Get-CurrentUserContext using PowerShell job
	Returns immediately with job object, caller polls for completion
	#>
	param([int]$TimeoutSeconds = 3)

	$jobScript = {
		param($Username)

		$result = @{
			UserId = $null
			SamAccountName = $null
			Email = $null
			DisplayName = $null
			Success = $false
			Error = $null
		}

		try {
			# Get Windows identity
			$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
			$result.UserId = $identity.Name

			if ($identity.Name -match '\\') {
				$result.SamAccountName = $identity.Name.Split('\')[1]
			} else {
				$result.SamAccountName = $identity.Name
			}

			# Get email via whoami
			try {
				$upn = (whoami /upn 2>$null)
				if ($upn -and $upn -like '*@*') {
					$result.Email = $upn.Trim()
				}
			} catch {}

			# Get display name via LDAP (blocking operation isolated to job)
			try {
				$root = [ADSI]"LDAP://RootDSE"
				$defaultNamingContext = $root.defaultNamingContext
				if ($defaultNamingContext) {
					$searchRoot = [ADSI]("LDAP://{0}" -f $defaultNamingContext)
					$searcher = New-Object System.DirectoryServices.DirectorySearcher($searchRoot)
					$searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName={0}))" -f $Username
					[void]$searcher.PropertiesToLoad.Add('displayName')
					[void]$searcher.PropertiesToLoad.Add('mail')
					[void]$searcher.PropertiesToLoad.Add('userPrincipalName')
					$ldapResult = $searcher.FindOne()

					if ($ldapResult) {
						if ($ldapResult.Properties['displayname'].Count -gt 0) {
							$result.DisplayName = [string]$ldapResult.Properties['displayname'][0]
						}
						if ($ldapResult.Properties['mail'].Count -gt 0 -and -not $result.Email) {
							$result.Email = [string]$ldapResult.Properties['mail'][0]
						}
						if ($ldapResult.Properties['userprincipalname'].Count -gt 0 -and -not $result.Email) {
							$result.Email = [string]$ldapResult.Properties['userprincipalname'][0]
						}
					}
				}
			} catch {
				# LDAP failure is non-fatal, use fallback
			}

			# Fallback display name
			if (-not $result.DisplayName) {
				if ($env:USERNAME) {
					$result.DisplayName = $env:USERNAME
				} else {
					$result.DisplayName = $result.SamAccountName
				}
			}

			# Fallback email
			if (-not $result.Email) {
				if ($env:USERDNSDOMAIN) {
					$result.Email = "{0}@{1}" -f $result.SamAccountName, $env:USERDNSDOMAIN
				} else {
					$result.Email = 'unknown@local'
				}
			}

			$result.Success = $true
		}
		catch {
			$result.Error = $_.Exception.Message
		}

		return $result
	}

	return Start-Job -ScriptBlock $jobScript -ArgumentList $env:USERNAME
}

function Wait-BackgroundJobWithTimeout {
	<#
	.SYNOPSIS
	Waits for job completion with timeout
	.DESCRIPTION
	Non-blocking wait with timeout, returns result or null
	#>
	param(
		[Parameter(Mandatory)][System.Management.Automation.Job]$Job,
		[int]$TimeoutSeconds = 3
	)

	$completed = Wait-Job -Job $Job -Timeout $TimeoutSeconds

	if ($completed) {
		$result = Receive-Job -Job $Job
		Remove-Job -Job $Job -Force
		return $result
	} else {
		# Timeout - stop and remove job
		Stop-Job -Job $Job -ErrorAction SilentlyContinue
		Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue
		return $null
	}
}

function Start-BackgroundSessionLoadJob {
	<#
	.SYNOPSIS
	Loads session JSON files in background
	.DESCRIPTION
	Non-blocking version of Get-SessionGridRows file enumeration
	#>
	param(
		[Parameter(Mandatory)][string]$SessionFolderPath,
		[int]$TimeoutSeconds = 10
	)

	$jobScript = {
		param($FolderPath)

		$results = @{
			Files = @()
			Success = $false
			Error = $null
		}

		try {
			if (Test-Path $FolderPath) {
				$allFiles = Get-ChildItem -LiteralPath $FolderPath -Filter '*.json' -File -ErrorAction SilentlyContinue |
					Sort-Object LastWriteTime -Descending

				foreach ($file in $allFiles) {
					try {
						$content = Get-Content $file.FullName -Raw -ErrorAction Stop
						$json = $content | ConvertFrom-Json

						$results.Files += @{
							FileName = $file.Name
							FullPath = $file.FullName
							LastWriteTime = $file.LastWriteTime
							Content = $json
						}
					}
					catch {
						# Skip malformed JSON files
					}
				}

				$results.Success = $true
			}
		}
		catch {
			$results.Error = $_.Exception.Message
		}

		return $results
	}

	return Start-Job -ScriptBlock $jobScript -ArgumentList $SessionFolderPath
}

#endregion

function Get-CurrentUserContext {
	$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
	$userId = $identity.Name
	$samAccountName = $env:USERNAME
	$email = $null
	$displayName = $null

	try {
		$upn = (& whoami /upn 2>$null)
		if ($upn -and $upn -match '@') {
			$email = $upn.Trim()
		}
	}
	catch {
	}

	try {
		$root = [ADSI]"LDAP://RootDSE"
		$defaultNamingContext = $root.defaultNamingContext
		if ($defaultNamingContext) {
			$searchRoot = [ADSI]("LDAP://{0}" -f $defaultNamingContext)
			$searcher = New-Object System.DirectoryServices.DirectorySearcher($searchRoot)
			$searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName={0}))" -f $samAccountName
			[void]$searcher.PropertiesToLoad.Add('displayName')
			[void]$searcher.PropertiesToLoad.Add('mail')
			[void]$searcher.PropertiesToLoad.Add('userPrincipalName')
			$result = $searcher.FindOne()

			if ($result) {
				if ($result.Properties['displayname'].Count -gt 0) {
					$displayName = [string]$result.Properties['displayname'][0]
				}
				if ($result.Properties['mail'].Count -gt 0 -and -not $email) {
					$email = [string]$result.Properties['mail'][0]
				}
				if ($result.Properties['userprincipalname'].Count -gt 0 -and -not $email) {
					$email = [string]$result.Properties['userprincipalname'][0]
				}
			}
		}
	}
	catch {
	}

	if (-not $displayName) {
		$displayName = $samAccountName
	}

	if (-not $email) {
		if ($env:USERDNSDOMAIN) {
			$email = "{0}@{1}" -f $samAccountName, $env:USERDNSDOMAIN
		}
		else {
			$email = 'unknown@local'
		}
	}

	[pscustomobject]@{
		UserId = $userId
		SamAccountName = $samAccountName
		Email = $email
		DisplayName = $displayName
	}
}

function Get-CurrentSessionName {
	param([Parameter(Mandatory = $true)][string]$SamAccountName)

	try {
		$quserOutput = (& quser 2>$null)
		foreach ($line in $quserOutput) {
			if ($line -match '^\s*(>|)\s*([^\s]+)\s+([^\s]+)\s+([0-9]+)\s+') {
				$user = $matches[2]
				$sessionName = $matches[3]
				if ($user -ieq $SamAccountName) {
					return $sessionName
				}
			}
		}
	}
	catch {
	}

	return 'Unknown'
}

function Test-IsCurrentUserAdmin {
	param(
		[Parameter(Mandatory = $true)][string]$UsersFilePath,
		[Parameter(Mandatory = $true)]$CurrentUserContext
	)

	if (-not (Test-Path -LiteralPath $UsersFilePath)) {
		return $false
	}

	try {
		$users = Get-Content -LiteralPath $UsersFilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
		$userRows = @($users)
		if ($userRows.Count -eq 0) {
			return $false
		}

		$candidateIds = @()
		if (-not [string]::IsNullOrWhiteSpace([string]$CurrentUserContext.SamAccountName)) {
			$candidateIds += [string]$CurrentUserContext.SamAccountName
		}
		if (-not [string]::IsNullOrWhiteSpace([string]$CurrentUserContext.UserId)) {
			$candidateIds += [string]$CurrentUserContext.UserId
		}
		if (-not [string]::IsNullOrWhiteSpace([string]$env:USERNAME)) {
			$candidateIds += [string]$env:USERNAME
		}

		$normalized = @{}
		foreach ($id in $candidateIds) {
			if ([string]::IsNullOrWhiteSpace($id)) { continue }
			$trimmed = $id.Trim()
			$normalized[$trimmed.ToUpperInvariant()] = $true
			if ($trimmed.Contains('\')) {
				$normalized[$trimmed.Split('\')[-1].ToUpperInvariant()] = $true
			}
		}

		foreach ($u in $userRows) {
			if ($null -eq $u) { continue }

			$keys = @()
			if ($u.PSObject.Properties.Name -contains 'SEID' -and $u.SEID) { $keys += [string]$u.SEID }
			if ($u.PSObject.Properties.Name -contains 'UserId' -and $u.UserId) { $keys += [string]$u.UserId }
			if ($u.PSObject.Properties.Name -contains 'SamAccountName' -and $u.SamAccountName) { $keys += [string]$u.SamAccountName }

			$matched = $false
			foreach ($key in $keys) {
				$testKey = $key.Trim().ToUpperInvariant()
				if ($normalized.ContainsKey($testKey)) {
					$matched = $true
					break
				}
				if ($testKey.Contains('\')) {
					$shortKey = $testKey.Split('\')[-1]
					if ($normalized.ContainsKey($shortKey)) {
						$matched = $true
						break
					}
				}
			}

			if (-not $matched) {
				continue
			}

			$isAdmin = $false
			if ($u.PSObject.Properties.Name -contains 'IsAdmin') {
				$isAdmin = [bool]$u.IsAdmin
			}

			return $isAdmin
		}
	}
	catch {
		return $false
	}

	return $false
}

function Register-TrackSessionsLogonTask {
	param(
		[Parameter(Mandatory = $true)][string]$ScriptPath,
		[Parameter(Mandatory = $true)][string]$TaskName,
		[Parameter(Mandatory = $true)][string]$OutputFolder
	)

	$safeScriptPath = $ScriptPath.Replace('"', '""')
	$safeOutputFolder = $OutputFolder.Replace('"', '""')
	$taskCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"{0}`" -OutputFolder `"{1}`"" -f $safeScriptPath, $safeOutputFolder
	$taskUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

	$arguments = @(
		'/Create',
		'/F',
		'/SC',
		'ONLOGON',
		'/TN',
		$TaskName,
		'/TR',
		$taskCommand,
		'/RU',
		$taskUser,
		'/RL',
		'LIMITED'
	)

	& schtasks.exe @arguments | Out-Null
}

if ($RegisterLogonTask) {
	if (-not $PSCommandPath) {
		throw 'Cannot register a logon task when script path is unavailable. Save and run the script from a file first.'
	}

	Register-TrackSessionsLogonTask -ScriptPath $PSCommandPath -TaskName $TaskName -OutputFolder $OutputFolder
	Write-Host ("Scheduled task '{0}' created or updated. It will launch this tracker at user logon." -f $TaskName) -ForegroundColor Green
	return
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

if (-not $SettingsPath) {
	$settingsBase = if ($PSCommandPath) { Split-Path -Path $PSCommandPath -Parent } else { (Get-Location).Path }
	$SettingsPath = Join-Path -Path $settingsBase -ChildPath 'TrackSessions.Settings.json'
}

function Get-DefaultTrackedMachines {
	return @(
		[ordered]@{ ShortName = 'PAWS 66'; FQDN = 'mtb012vp0030366.ds.irsnet.gov'; Comment = 'Fallback PAWS machine' }
		[ordered]@{ ShortName = 'PAWS 67'; FQDN = 'mtb012vp0030367.ds.irsnet.gov'; Comment = 'Fallback PAWS machine' }
		[ordered]@{ ShortName = 'PAWS 68'; FQDN = 'mtb012vp0030368.ds.irsnet.gov'; Comment = 'Fallback PAWS machine' }
	)
}

function Get-CloudMachines {
	<#
	.SYNOPSIS
		Loads cloud machine list from shared path with timeout and fallback support.

	.DESCRIPTION
		Attempts to load TrackSessions.CloudMachines.json from:
		1. Shared path (if configured and accessible within timeout)
		2. Local script directory (offline fallback)
		3. Hardcoded defaults (if all files unavailable)

	.PARAMETER SharedPath
		UNC path to shared folder (optional)

	.PARAMETER TimeoutSeconds
		Network timeout in seconds (default: 3)

	.OUTPUTS
		PSCustomObject with:
		- Machines: Array of machine objects
		- Source: String indicating where machines were loaded from
		- Success: Boolean indicating if load was successful
		- Error: String with error message if failed
	#>
	param(
		[string]$SharedPath = '',
		[int]$TimeoutSeconds = 3
	)

	$cloudMachinesFileName = 'TrackSessions.CloudMachines.json'
	$result = [PSCustomObject]@{
		Machines = @()
		Source = 'Hardcoded Defaults'
		Success = $false
		Error = $null
	}

	# Helper function to load from a path with timeout
	$loadFromPath = {
		param([string]$FilePath, [int]$Timeout)

		try {
			$job = Start-Job -ScriptBlock {
				param($Path)
				if (Test-Path -LiteralPath $Path) {
					$content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
					$data = $content | ConvertFrom-Json -ErrorAction Stop
					return $data
				}
				return $null
			} -ArgumentList $FilePath

			$completed = Wait-Job -Job $job -Timeout $Timeout
			if ($null -ne $completed) {
				$data = Receive-Job -Job $job
				Remove-Job -Job $job -Force
				return $data
			}
			else {
				Stop-Job -Job $job -ErrorAction SilentlyContinue
				Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
				return $null
			}
		}
		catch {
			return $null
		}
	}

	# Try 1: Load from shared path (if provided)
	if (-not [string]::IsNullOrWhiteSpace($SharedPath)) {
		$sharedFilePath = Join-Path $SharedPath $cloudMachinesFileName
		Add-DebugLog -Message "Attempting to load cloud machines from shared path: $sharedFilePath (timeout: ${TimeoutSeconds}s)"

		$sharedData = & $loadFromPath -FilePath $sharedFilePath -Timeout $TimeoutSeconds
		if ($null -ne $sharedData -and $sharedData.Machines) {
			$result.Machines = @($sharedData.Machines)
			$result.Source = "Shared Path: $SharedPath"
			$result.Success = $true
			Add-DebugLog -Message "Loaded $($result.Machines.Count) machines from shared path"
			return $result
		}
		else {
			Add-DebugLog -Message "Failed to load from shared path (timeout or file not found)"
		}
	}

	# Try 2: Load from local script directory
	$localFilePath = Join-Path $PSScriptRoot $cloudMachinesFileName
	Add-DebugLog -Message "Attempting to load cloud machines from local path: $localFilePath"

	$localData = & $loadFromPath -FilePath $localFilePath -Timeout 2
	if ($null -ne $localData -and $localData.Machines) {
		$result.Machines = @($localData.Machines)
		$result.Source = "Local File: $PSScriptRoot"
		$result.Success = $true
		Add-DebugLog -Message "Loaded $($result.Machines.Count) machines from local file"
		return $result
	}
	else {
		Add-DebugLog -Message "Failed to load from local path"
	}

	# Try 3: Use hardcoded defaults
	Add-DebugLog -Message "Using hardcoded default machines (fallback)"
	$result.Machines = @(Get-DefaultTrackedMachines)
	$result.Source = 'Hardcoded Defaults'
	$result.Success = $true
	$result.Error = 'Cloud machines file not accessible - using defaults'

	return $result
}

function Read-TrackSessionsSettings {
	param([Parameter(Mandatory = $true)][string]$Path)

	$defaultSettings = [ordered]@{
		SchemaVersion = '1.1'
		MiniWindow = [ordered]@{
			Left = $null
			Top = $null
		}
		Layout = [ordered]@{
			BottomPaneHeight = $null
			WindowLeft = $null
			WindowTop = $null
			WindowWidth = $null
			WindowHeight = $null
			SplashLeft = $null
			SplashTop = $null
			SplashWidth = $null
			SplashHeight = $null
		}
		NotifyDialog = [ordered]@{
			Left = $null
			Top = $null
			Width = $null
			Height = $null
		}
		ZoomLevels = [ordered]@{
			MainContent = 1.0
			LogViewer = 1.0
			UserEditor = 1.0
			UserEditorEdit = 1.0
			Settings = 1.0
		}
		Tracking = [ordered]@{
			SharedPath = ''
			Machines = @(Get-DefaultTrackedMachines)
		}
		StartupTrace = [ordered]@{
			Enabled = $true
			Events = @()
		}
	}

	if (-not (Test-Path -LiteralPath $Path)) {
		$dir = Split-Path -Path $Path -Parent
		if ($dir -and -not (Test-Path -LiteralPath $dir)) {
			New-Item -Path $dir -ItemType Directory -Force | Out-Null
		}
		$defaultSettings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding UTF8
		return $defaultSettings
	}

	try {
		$raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
		if ([string]::IsNullOrWhiteSpace($raw)) {
			return $defaultSettings
		}
		$loaded = $raw | ConvertFrom-Json -ErrorAction Stop
		if (-not $loaded -or -not $loaded.MiniWindow) {
			return $defaultSettings
		}

		$left = $null
		$top = $null
		if (Test-IsFiniteDouble -Value $loaded.MiniWindow.Left) {
			$left = [double]$loaded.MiniWindow.Left
		}
		if (Test-IsFiniteDouble -Value $loaded.MiniWindow.Top) {
			$top = [double]$loaded.MiniWindow.Top
		}

		$traceEnabled = $true
		if ($loaded.StartupTrace -and $null -ne $loaded.StartupTrace.Enabled) {
			$traceEnabled = [bool]$loaded.StartupTrace.Enabled
		}

		$traceEvents = @()
		if ($loaded.StartupTrace -and $loaded.StartupTrace.Events) {
			$traceEvents = @($loaded.StartupTrace.Events)
		}

		$bottomPaneHeight = $null
		if ($loaded.Layout -and (Test-IsFiniteDouble -Value $loaded.Layout.BottomPaneHeight)) {
			$bottomPaneHeight = [double]$loaded.Layout.BottomPaneHeight
		}

		$sharedPath = ''
		if ($loaded.Tracking -and $null -ne $loaded.Tracking.SharedPath) {
			$sharedPath = [string]$loaded.Tracking.SharedPath
		}

		$machines = @()
		if ($loaded.Tracking -and $loaded.Tracking.Machines) {
			foreach ($entry in @($loaded.Tracking.Machines)) {
				if ($null -eq $entry) {
					continue
				}
				$machines += [ordered]@{
					ShortName = [string]$entry.ShortName
					FQDN = [string]$entry.FQDN
					Comment = [string]$entry.Comment
				}
			}
		}
		if ($machines.Count -eq 0) {
			$machines = @(Get-DefaultTrackedMachines)
		}

		$windowLeft = $null
		$windowTop = $null
		$windowWidth = $null
		$windowHeight = $null
		if ($loaded.Layout -and (Test-IsFiniteDouble -Value $loaded.Layout.WindowLeft)) {
			$windowLeft = [double]$loaded.Layout.WindowLeft
		}
		if ($loaded.Layout -and (Test-IsFiniteDouble -Value $loaded.Layout.WindowTop)) {
			$windowTop = [double]$loaded.Layout.WindowTop
		}
		if ($loaded.Layout -and (Test-IsFiniteDouble -Value $loaded.Layout.WindowWidth)) {
			$windowWidth = [double]$loaded.Layout.WindowWidth
		}
		if ($loaded.Layout -and (Test-IsFiniteDouble -Value $loaded.Layout.WindowHeight)) {
			$windowHeight = [double]$loaded.Layout.WindowHeight
		}

		$splashLeft = $null
		$splashTop = $null
		$splashWidth = $null
		$splashHeight = $null
		if ($loaded.Layout -and (Test-IsFiniteDouble -Value $loaded.Layout.SplashLeft)) {
			$splashLeft = [double]$loaded.Layout.SplashLeft
		}
		if ($loaded.Layout -and (Test-IsFiniteDouble -Value $loaded.Layout.SplashTop)) {
			$splashTop = [double]$loaded.Layout.SplashTop
		}
		if ($loaded.Layout -and (Test-IsFiniteDouble -Value $loaded.Layout.SplashWidth)) {
			$splashWidth = [double]$loaded.Layout.SplashWidth
		}
		if ($loaded.Layout -and (Test-IsFiniteDouble -Value $loaded.Layout.SplashHeight)) {
			$splashHeight = [double]$loaded.Layout.SplashHeight
		}

		$notifyLeft = $null
		$notifyTop = $null
		$notifyWidth = $null
		$notifyHeight = $null
		if ($loaded.NotifyDialog -and (Test-IsFiniteDouble -Value $loaded.NotifyDialog.Left)) {
			$notifyLeft = [double]$loaded.NotifyDialog.Left
		}
		if ($loaded.NotifyDialog -and (Test-IsFiniteDouble -Value $loaded.NotifyDialog.Top)) {
			$notifyTop = [double]$loaded.NotifyDialog.Top
		}
		if ($loaded.NotifyDialog -and (Test-IsFiniteDouble -Value $loaded.NotifyDialog.Width)) {
			$notifyWidth = [double]$loaded.NotifyDialog.Width
		}
		if ($loaded.NotifyDialog -and (Test-IsFiniteDouble -Value $loaded.NotifyDialog.Height)) {
			$notifyHeight = [double]$loaded.NotifyDialog.Height
		}

		$zoomMain = 1.0
		$zoomLog = 1.0
		$zoomUserEditor = 1.0
		$zoomUserEditorEdit = 1.0
		$zoomSettings = 1.0
		if ($loaded.ZoomLevels -and (Test-IsFiniteDouble -Value $loaded.ZoomLevels.MainContent)) {
			$zoomMain = [Math]::Max(0.5, [Math]::Min(3.0, [double]$loaded.ZoomLevels.MainContent))
		}
		if ($loaded.ZoomLevels -and (Test-IsFiniteDouble -Value $loaded.ZoomLevels.LogViewer)) {
			$zoomLog = [Math]::Max(0.7, [Math]::Min(6.0, [double]$loaded.ZoomLevels.LogViewer))
		}
		if ($loaded.ZoomLevels -and (Test-IsFiniteDouble -Value $loaded.ZoomLevels.UserEditor)) {
			$zoomUserEditor = [Math]::Max(0.7, [Math]::Min(2.0, [double]$loaded.ZoomLevels.UserEditor))
		}
		if ($loaded.ZoomLevels -and (Test-IsFiniteDouble -Value $loaded.ZoomLevels.UserEditorEdit)) {
			$zoomUserEditorEdit = [Math]::Max(0.7, [Math]::Min(2.0, [double]$loaded.ZoomLevels.UserEditorEdit))
		}
		if ($loaded.ZoomLevels -and (Test-IsFiniteDouble -Value $loaded.ZoomLevels.Settings)) {
			$zoomSettings = [Math]::Max(0.8, [Math]::Min(1.8, [double]$loaded.ZoomLevels.Settings))
		}

		return [ordered]@{
			SchemaVersion = '1.1'
			MiniWindow = [ordered]@{
				Left = $left
				Top = $top
			}
			Layout = [ordered]@{
				BottomPaneHeight = $bottomPaneHeight
				WindowLeft = $windowLeft
				WindowTop = $windowTop
				WindowWidth = $windowWidth
				WindowHeight = $windowHeight
				SplashLeft = $splashLeft
				SplashTop = $splashTop
				SplashWidth = $splashWidth
				SplashHeight = $splashHeight
			}
			NotifyDialog = [ordered]@{
				Left = $notifyLeft
				Top = $notifyTop
				Width = $notifyWidth
				Height = $notifyHeight
			}
			ZoomLevels = [ordered]@{
				MainContent = $zoomMain
				LogViewer = $zoomLog
				UserEditor = $zoomUserEditor
				UserEditorEdit = $zoomUserEditorEdit
				Settings = $zoomSettings
			}
			Tracking = [ordered]@{
				SharedPath = $sharedPath
				Machines = $machines
			}
			StartupTrace = [ordered]@{
				Enabled = $traceEnabled
				Events = $traceEvents
			}
		}
	}
	catch {
		return $defaultSettings
	}
}

function Save-TrackSessionsSettings {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)]$Settings
	)

	$dir = Split-Path -Path $Path -Parent
	if ($dir -and -not (Test-Path -LiteralPath $dir)) {
		New-Item -Path $dir -ItemType Directory -Force | Out-Null
	}

	$Settings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Add-StartupTrace {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][string]$EventName,
		[string]$Detail = ''
	)

	try {
		$settings = Read-TrackSessionsSettings -Path $Path
		if (-not $settings.StartupTrace) {
			$settings.StartupTrace = [ordered]@{ Enabled = $true; Events = @() }
		}

		$enabled = $true
		if ($null -ne $settings.StartupTrace.Enabled) {
			$enabled = [bool]$settings.StartupTrace.Enabled
		}
		if (-not $enabled) {
			return
		}

		$events = @()
		if ($settings.StartupTrace.Events) {
			$events = @($settings.StartupTrace.Events)
		}

		$events += [ordered]@{
			TimestampUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
			Event = $EventName
			Detail = $Detail
		}

		$maxEvents = 120
		if ($events.Count -gt $maxEvents) {
			$events = $events[($events.Count - $maxEvents)..($events.Count - 1)]
		}

		$settings.StartupTrace.Events = $events
		Save-TrackSessionsSettings -Path $Path -Settings $settings
	}
	catch {
	}
}

function Test-IsFiniteDouble {
	param($Value)

	if ($null -eq $Value) {
		return $false
	}

	try {
		$number = [double]$Value
		return (-not [double]::IsNaN($number)) -and (-not [double]::IsInfinity($number))
	}
	catch {
		return $false
	}
}

if (-not (Test-Path -LiteralPath $OutputFolder)) {
	New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

# PERFORMANCE FIX: Use fast identity resolution for initial context (no LDAP blocking)
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$samAccountName = $env:USERNAME
$userContext = [pscustomobject]@{
	UserId = $identity.Name
	SamAccountName = $samAccountName
	Email = if ($env:USERDNSDOMAIN) { "{0}@{1}" -f $samAccountName, $env:USERDNSDOMAIN } else { 'unknown@local' }
	DisplayName = $samAccountName
}
# Full LDAP lookup will happen in background during ContentRendered event

$machineName = $env:COMPUTERNAME
$sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
$sessionName = Get-CurrentSessionName -SamAccountName $userContext.SamAccountName
$createdAtGmt = [DateTime]::UtcNow

$fileMachine = Convert-ToSafeFileToken -Value $machineName
$fileUser = Convert-ToSafeFileToken -Value $userContext.UserId
$fileDisplay = Convert-ToSafeFileToken -Value $userContext.DisplayName
$fileStamp = $createdAtGmt.ToString('yyyyMMdd_HHmmss') + 'Z'
$appVersion = "cr1 Sept 2026"

$jsonFileName = "Session.{0}.{1}.{2}.{3}.{4}.json" -f $appVersion, $fileMachine, $fileUser, $fileDisplay, $fileStamp

function Write-SessionSnapshot {
	param(
		[Parameter(Mandatory = $true)][datetime]$CreatedAt,
		[Parameter(Mandatory = $true)][string]$JsonPath,
		[Parameter(Mandatory = $true)][string]$MachineName,
		[Parameter(Mandatory = $true)][int]$SessionId,
		[Parameter(Mandatory = $true)][string]$SessionName,
		[Parameter(Mandatory = $true)][pscustomobject]$UserContext
	)

	$nowGmt = [DateTime]::UtcNow

	$snapshot = [ordered]@{
		SchemaVersion = '1.0'
		MachineName = $MachineName
		SessionId = $SessionId
		SessionName = $SessionName
		UserId = $UserContext.UserId
		UserDisplayName = $UserContext.DisplayName
		UserEmail = $UserContext.Email
		CreatedAtGmt = $CreatedAt.ToString('yyyy-MM-ddTHH:mm:ssZ')
		LastUpdatedAtGmt = $nowGmt.ToString('yyyy-MM-ddTHH:mm:ssZ')
		JsonFileName = [System.IO.Path]::GetFileName($JsonPath)
	}

	$snapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonPath -Encoding UTF8
	return $snapshot
}

function Write-SessionCloseArtifacts {
	param(
		[Parameter(Mandatory = $true)][string]$CurrentJsonPath,
		[Parameter(Mandatory = $true)][string]$SessionName,
		[Parameter(Mandatory = $true)][int]$SessionId,
		[Parameter(Mandatory = $true)][string]$MachineName,
		[Parameter(Mandatory = $true)][pscustomobject]$UserContext
	)

	if ($script:logoutArtifactsWritten) {
		return
	}
	$script:logoutArtifactsWritten = $true

	$closedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
	$payload = $null

	try {
		$payload = Get-Content -LiteralPath $CurrentJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
	}
	catch {
		$payload = [pscustomobject]@{}
	}

	$payload | Add-Member -NotePropertyName SchemaVersion -NotePropertyValue '1.0' -Force
	$payload | Add-Member -NotePropertyName MachineName -NotePropertyValue $MachineName -Force
	$payload | Add-Member -NotePropertyName SessionId -NotePropertyValue $SessionId -Force
	$payload | Add-Member -NotePropertyName SessionName -NotePropertyValue $SessionName -Force
	$payload | Add-Member -NotePropertyName UserId -NotePropertyValue $UserContext.UserId -Force
	$payload | Add-Member -NotePropertyName UserDisplayName -NotePropertyValue $UserContext.DisplayName -Force
	$payload | Add-Member -NotePropertyName UserEmail -NotePropertyValue $UserContext.Email -Force
	$payload | Add-Member -NotePropertyName SessionStatus -NotePropertyValue 'Closed' -Force
	$payload | Add-Member -NotePropertyName SessionCloseEvent -NotePropertyValue 'WindowClosed' -Force
	$payload | Add-Member -NotePropertyName SessionClosedAtGmt -NotePropertyValue $closedAt -Force
	$payload | Add-Member -NotePropertyName LastUpdatedAtGmt -NotePropertyValue $closedAt -Force

	$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $CurrentJsonPath -Encoding UTF8

	$logoutPath = Join-Path -Path ([System.IO.Path]::GetDirectoryName($CurrentJsonPath)) -ChildPath (([System.IO.Path]::GetFileNameWithoutExtension($CurrentJsonPath)) + '.Logout.json')
	$payload | Add-Member -NotePropertyName LogoutFileCreatedAtGmt -NotePropertyValue $closedAt -Force
	$payload | Add-Member -NotePropertyName LogoutFileName -NotePropertyValue ([System.IO.Path]::GetFileName($logoutPath)) -Force
	$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $logoutPath -Encoding UTF8
}

function Get-SessionGridRows {
	param(
		[Parameter(Mandatory = $true)][string]$FolderPath,
		$TrackedMachines,
		[string]$ExcludeMachineName
	)

	$rows = @()
	$allMachinesFound = @{}

	$excludeToken = ''
	if (-not [string]::IsNullOrWhiteSpace($ExcludeMachineName)) {
		$excludeToken = $ExcludeMachineName.Trim().ToUpperInvariant()
	}

	try {
		if (-not (Test-Path -LiteralPath $FolderPath)) {
			Add-DebugLog -Message "Session folder not found: $FolderPath"
			return @()
		}

		$jsonFiles = Get-ChildItem -LiteralPath $FolderPath -Filter '*.json' -File -ErrorAction Stop |
			Sort-Object LastWriteTime -Descending

		Add-DebugLog -Message "Found $($jsonFiles.Count) JSON session files in $FolderPath"
		Add-DebugLog -Message "Excluded machine (current): $ExcludeMachineName"

		foreach ($file in $jsonFiles) {
			try {
				Add-DebugLog -Message "Processing file: $($file.Name)"
				$obj = Get-CachedSessionData -File $file
				if ($null -eq $obj) {
					Add-DebugLog -Message "  -> JSON parsed but was null, skipping"
					continue
				}

				$machineValue = [string]$obj.MachineName
				$machineToken = $machineValue.Trim().ToUpperInvariant()
				$machineShortToken = if ($machineToken.Contains('.')) { $machineToken.Split('.')[0] } else { $machineToken }

				# Track all unique machines found
				$allMachinesFound[$machineToken] = $machineValue

				if (-not [string]::IsNullOrWhiteSpace($excludeToken) -and ($machineToken -eq $excludeToken -or $machineShortToken -eq $excludeToken)) {
					Add-DebugLog -Message "  -> Skipping excluded machine: $machineValue"
					continue
				}

				$statusTimestamp = [string]$obj.LastUpdatedAtGmt
				if ([string]::IsNullOrWhiteSpace($statusTimestamp)) {
					$statusTimestamp = [string]$obj.CreatedAtGmt
				}

				$computedStatus = Get-SessionStatusFromSnapshot -SnapshotObject $obj -SourceFilePath $file.FullName
				Add-DebugLog -Message "  -> File: $($file.Name) | Machine: $machineValue | User: $([string]$obj.UserId) | Status: $computedStatus | LastActivity: $statusTimestamp"

				$rows += [pscustomobject]@{
					MachineName = $machineValue
					UserId = [string]$obj.UserId
					UserDisplayName = [string]$obj.UserDisplayName
					LastLogin = [string]$obj.CreatedAtGmt
					LastActivity = [string]$obj.LastUpdatedAtGmt
					RowStatus = $computedStatus
					StatusTimestamp = $statusTimestamp
					StatusTimestampDisplay = ("Status changed at: {0}" -f $statusTimestamp)
				}
			}
			catch {
				Add-DebugLog -Message "  -> ERROR processing file: $($_.Exception.Message)"
			}
		}
	}
	catch {
	}

	# Log summary of all unique machines found in the folder
	if ($allMachinesFound.Count -gt 0) {
		Add-DebugLog -Message "=== SUMMARY: All unique machines found in folder ==="
		foreach ($machine in @($allMachinesFound.Values | Sort-Object)) {
			$machineToken = $machine.Trim().ToUpperInvariant()
			if ($machineToken -eq $excludeToken) {
				Add-DebugLog -Message "  * $machine (EXCLUDED - current machine)"
			}
			else {
				Add-DebugLog -Message "  * $machine"
			}
		}
		Add-DebugLog -Message "=== END SUMMARY ==="
	}

	# Deduplicate: keep only the most recent entry per machine + user combination
	$deduped = @{}
	foreach ($row in $rows) {
		$key = "{0}|{1}" -f $row.MachineName.ToUpperInvariant(), $row.UserId.ToUpperInvariant()
		if (-not $deduped.ContainsKey($key)) {
			$deduped[$key] = $row
			Add-DebugLog -Message "Added to final list: $key | Status: $($row.RowStatus)"
		}
		else {
			$existing = $deduped[$key]
			# Compare LastActivity timestamps, keep the more recent one
			try {
				$existingTime = [datetime]::Parse($existing.LastActivity, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
				$currentTime = [datetime]::Parse($row.LastActivity, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
				if ($currentTime -gt $existingTime) {
					Add-DebugLog -Message "Updating $key from Status: $($existing.RowStatus) to $($row.RowStatus) (newer timestamp)"
					$deduped[$key] = $row
				}
				else {
					Add-DebugLog -Message "Skipped duplicate $key - keeping existing Status: $($existing.RowStatus)"
				}
			}
			catch {
				Add-DebugLog -Message "Failed to parse timestamps for $key, keeping existing"
			}
		}
	}

	Add-DebugLog -Message "Deduplication complete: $($rows.Count) rows -> $($deduped.Values.Count) final entries"
	return @($deduped.Values)
}

function Get-SessionStatusFromSnapshot {
	param(
		[Parameter(Mandatory = $true)]$SnapshotObject,
		[Parameter(Mandatory = $true)][string]$SourceFilePath
	)

	$fileName = [System.IO.Path]::GetFileName($SourceFilePath)
	$sessionStatus = $SnapshotObject | Select-Object -ExpandProperty SessionStatus -ErrorAction SilentlyContinue
	$closeEvent = $SnapshotObject | Select-Object -ExpandProperty SessionCloseEvent -ErrorAction SilentlyContinue
	$closedAt = $SnapshotObject | Select-Object -ExpandProperty SessionClosedAtGmt -ErrorAction SilentlyContinue

	# Check if logged out (filename, status, or close timestamps)
	if ($fileName -like '*.Logout.json' -or $sessionStatus -eq 'Closed' -or -not [string]::IsNullOrWhiteSpace($closedAt) -or -not [string]::IsNullOrWhiteSpace($closeEvent)) {
		return 'Logged Out'
	}

	# Check LastUpdatedAtGmt from JSON content
	$lastUpdateRaw = $SnapshotObject | Select-Object -ExpandProperty LastUpdatedAtGmt -ErrorAction SilentlyContinue
	if (-not [string]::IsNullOrWhiteSpace($lastUpdateRaw)) {
		try {
			$lastUpdate = [datetime]::Parse($lastUpdateRaw, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
			$age = [DateTime]::UtcNow - $lastUpdate.ToUniversalTime()
			if ($age.TotalMinutes -ge 3) {
				return 'Disconnected'
			}
		}
		catch {
		}
	}

	return 'Logged In'
}

function New-OrangeCircleIconFrame {
	param(
		[Parameter(Mandatory = $true)][int]$Size,
		[Parameter(Mandatory = $true)][double]$Scale,
		[Parameter(Mandatory = $true)][byte]$GlowAlpha
	)

	$visual = New-Object System.Windows.Media.DrawingVisual
	$dc = $visual.RenderOpen()

	$center = [System.Windows.Point]::new($Size / 2.0, $Size / 2.0)
	$outerRadius = ($Size * 0.42) * $Scale
	$innerRadius = ($Size * 0.26) * $Scale

	$glowBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb($GlowAlpha, 255, 143, 38))
	$outerBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(255, 255, 145, 40))
	$innerBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(255, 255, 196, 77))

	$dc.DrawEllipse($glowBrush, $null, $center, $outerRadius + 1.5, $outerRadius + 1.5)
	$dc.DrawEllipse($outerBrush, $null, $center, $outerRadius, $outerRadius)
	$dc.DrawEllipse($innerBrush, $null, [System.Windows.Point]::new($center.X - 1, $center.Y - 1), $innerRadius, $innerRadius)
	$dc.Close()

	$bitmap = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($Size, $Size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
	$bitmap.Render($visual)
	$bitmap.Freeze()
	return $bitmap
}

# Initialize script-level variables BEFORE XAML loading to prevent undefined variable errors in event handlers
$script:lastNotificationEntries = @()
$script:debugLog = @()
$script:usersList = @()
$script:sessionCache = @{}
$script:userDisplayNameCache = @{}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Windows Session Tracker - cr2 Sept 2026 Notify"
		Height="600"
		Width="860"
		MinHeight="550"
		MinWidth="560"
		WindowStartupLocation="CenterScreen"
		ResizeMode="CanResizeWithGrip"
		SizeToContent="Manual"
		ShowInTaskbar="True"
		Background="#F4F8FC">
	<Window.Resources>
		<Style TargetType="Button">
			<Setter Property="FontWeight" Value="Bold"/>
		</Style>
	</Window.Resources>
	<Grid Margin="18">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<Border Grid.Row="0" Background="#1F5A8A" CornerRadius="8" Padding="12" Margin="0,0,0,12">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="*"/>
				</Grid.ColumnDefinitions>
				<Image Name="ImgAnimatedIcon" Grid.Column="0" Width="22" Height="22" Margin="0,0,10,0" VerticalAlignment="Center"/>
				<TextBlock Grid.Column="1" Text="Session Tracking Home" Foreground="White" FontSize="22" FontWeight="SemiBold" VerticalAlignment="Center"/>
			</Grid>
		</Border>

		<Border Grid.Row="1" Background="White" CornerRadius="8" Padding="0" BorderBrush="#D3DFEB" BorderThickness="1">
			<Grid x:Name="BodyGrid" Margin="12">
				<Grid.RowDefinitions>
					<RowDefinition x:Name="TopPaneRow" Height="*" MinHeight="100"/>
					<RowDefinition Height="6"/>
					<RowDefinition x:Name="BottomPaneRow" Height="*" MinHeight="180"/>
				</Grid.RowDefinitions>

				<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="4" ToolTip="Current session information panel. Scroll for more details if needed.">
					<Grid x:Name="InfoGrid">
						<Grid.ColumnDefinitions>
							<ColumnDefinition x:Name="LblCol" Width="230"/>
							<ColumnDefinition x:Name="ValCol" Width="*"/>
						</Grid.ColumnDefinitions>
						<Grid.RowDefinitions>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
						</Grid.RowDefinitions>

						<TextBlock Name="LblSession" Grid.Row="0" Grid.Column="0" Text="Session (Windows):" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="0" Grid.Column="1" Name="TxtSession" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True" ToolTip="Current Windows session name or RDP session identifier."/>

						<TextBlock Name="LblUserId" Grid.Row="1" Grid.Column="0" Text="User ID:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="1" Grid.Column="1" Name="TxtUserId" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True" ToolTip="Windows user identity (DOMAIN\USERNAME format)."/>

						<TextBlock Name="LblDisplayName" Grid.Row="2" Grid.Column="0" Text="User Display Name:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="2" Grid.Column="1" Name="TxtDisplayName" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True" ToolTip="Full display name from Active Directory or user database."/>

						<TextBlock Name="LblUserEmail" Grid.Row="3" Grid.Column="0" Text="User Email:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="3" Grid.Column="1" Name="TxtUserEmail" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True" ToolTip="Email address from Active Directory or user database."/>

						<TextBlock Name="LblMachine" Grid.Row="4" Grid.Column="0" Text="Machine Name:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="4" Grid.Column="1" Name="TxtMachine" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True" ToolTip="Computer name or FQDN of the current machine."/>

						<TextBlock Name="LblFolder" Grid.Row="5" Grid.Column="0" Text="JSON Output Folder (default):" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="5" Grid.Column="1" Name="TxtFolder" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True" ToolTip="Default folder path where session JSON files are stored (local or network path)."/>

						<TextBlock Name="LblJsonFile" Grid.Row="6" Grid.Column="0" Text="Current JSON File:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="6" Grid.Column="1" Name="TxtJsonFile" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True" ToolTip="Name of the current session JSON snapshot file."/>

						<TextBlock Name="LblLastUpdated" Grid.Row="7" Grid.Column="0" Text="Last Update (GMT):" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="7" Grid.Column="1" Name="TxtLastUpdated" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True" ToolTip="Timestamp (GMT/UTC) of the last session data update."/>
					</Grid>
				</ScrollViewer>

				<GridSplitter Name="MainRowSplitter" Grid.Row="1" Height="6" HorizontalAlignment="Stretch" VerticalAlignment="Center" ResizeDirection="Rows" ResizeBehavior="PreviousAndNext" Background="#D9E5EF" ToolTip="Drag to resize the top and bottom panes."/>

				<Grid Grid.Row="2" Margin="4,8,4,4">
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
					</Grid.RowDefinitions>
					<TextBlock Name="LblHistory" Grid.Row="0" Text="Activity on Other Machines" FontWeight="SemiBold" Margin="0,0,0,6" ToolTip="Shows session activity across all tracked PAWS machines."/>
					<DataGrid Name="GridSessionFiles"
							  Grid.Row="1"
							  MinHeight="120"
							  AutoGenerateColumns="False"
							  ToolTip="Session activity grid showing user sessions across tracked machines. Click rows to select."
							  CanUserAddRows="False"
							  CanUserDeleteRows="False"
							  IsReadOnly="True"
							  HeadersVisibility="Column"
							  SelectionMode="Single"
							  SelectionUnit="FullRow"
							  GridLinesVisibility="Horizontal"
							  ScrollViewer.VerticalScrollBarVisibility="Auto"
							  ScrollViewer.HorizontalScrollBarVisibility="Auto">
						<DataGrid.RowStyle>
							<Style TargetType="DataGridRow">
								<Style.Triggers>
									<DataTrigger Binding="{Binding RowStatus}" Value="Logged In">
										<Setter Property="Background" Value="#E7F7EC"/>
									</DataTrigger>
									<DataTrigger Binding="{Binding RowStatus}" Value="Logged Out">
										<Setter Property="Background" Value="#FDEBEC"/>
									</DataTrigger>
									<DataTrigger Binding="{Binding RowStatus}" Value="Disconnected">
										<Setter Property="Background" Value="#E8F3FF"/>
									</DataTrigger>
								</Style.Triggers>
							</Style>
						</DataGrid.RowStyle>
						<DataGrid.Columns>
							<DataGridTemplateColumn Header="Machine Name" Width="*">
								<DataGridTemplateColumn.CellTemplate>
									<DataTemplate>
										<StackPanel Orientation="Horizontal" VerticalAlignment="Center">
											<TextBlock Text="{Binding MachineName}" VerticalAlignment="Center"/>
											<Ellipse Width="8" Height="8" Fill="#0D7A2E" Margin="6,0,0,0" VerticalAlignment="Center">
												<Ellipse.Style>
													<Style TargetType="Ellipse">
														<Setter Property="Visibility" Value="Collapsed"/>
														<Setter Property="Opacity" Value="1.0"/>
														<Style.Triggers>
															<DataTrigger Binding="{Binding RowStatus}" Value="Logged In">
																<Setter Property="Visibility" Value="Visible"/>
															</DataTrigger>
														</Style.Triggers>
													</Style>
												</Ellipse.Style>
												<Ellipse.Triggers>
													<EventTrigger RoutedEvent="FrameworkElement.Loaded">
														<BeginStoryboard>
															<Storyboard RepeatBehavior="Forever" AutoReverse="True">
																<DoubleAnimation Storyboard.TargetProperty="Opacity" From="1.0" To="0.25" Duration="0:0:0.5"/>
															</Storyboard>
														</BeginStoryboard>
													</EventTrigger>
												</Ellipse.Triggers>
											</Ellipse>
										</StackPanel>
									</DataTemplate>
								</DataGridTemplateColumn.CellTemplate>
							</DataGridTemplateColumn>
							<DataGridTextColumn Header="User ID" Binding="{Binding UserId}" Width="*"/>
							<DataGridTextColumn Header="User Display Name" Binding="{Binding UserDisplayNameResolved}" Width="*"/>
							<DataGridTextColumn Header="Last Login" Binding="{Binding LastLogin}" Width="*"/>
							<DataGridTemplateColumn Header="Status" Width="*">
								<DataGridTemplateColumn.CellTemplate>
									<DataTemplate>
										<TextBlock Text="{Binding RowStatus}" ToolTip="{Binding StatusTimestampDisplay}" VerticalAlignment="Center"/>
									</DataTemplate>
								</DataGridTemplateColumn.CellTemplate>
							</DataGridTemplateColumn>
						</DataGrid.Columns>
					</DataGrid>
				</Grid>
			</Grid>
		</Border>

		<Grid Grid.Row="2" Margin="0,12,0,0">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="*"/>
			</Grid.ColumnDefinitions>
			<StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
				<TextBlock Text="Legend:" FontSize="16.5" Foreground="#365065" Margin="0,0,6,0" VerticalAlignment="Center"/>
				<Border Width="15" Height="15" Background="#E7F7EC" BorderBrush="#3F8E5A" BorderThickness="3" Margin="0,0,4,0" VerticalAlignment="Center"/>
				<TextBlock Text="Logged In" FontSize="16.5" Foreground="#365065" Margin="0,0,8,0" VerticalAlignment="Center"/>
				<Border Width="15" Height="15" Background="#FDEBEC" BorderBrush="#B45B66" BorderThickness="3" Margin="0,0,4,0" VerticalAlignment="Center"/>
				<TextBlock Text="Logged Out" FontSize="16.5" Foreground="#365065" Margin="0,0,8,0" VerticalAlignment="Center"/>
				<Border Width="15" Height="15" Background="#E8F3FF" BorderBrush="#4F7FAF" BorderThickness="3" Margin="0,0,4,0" VerticalAlignment="Center"/>
				<TextBlock Text="Disconnected" FontSize="16.5" Foreground="#365065" Margin="0,0,8,0" VerticalAlignment="Center"/>
				<Border Width="15" Height="15" Background="#F3E5F5" BorderBrush="#7B1FA2" BorderThickness="3" Margin="0,0,4,0" VerticalAlignment="Center"/>
				<TextBlock Text="Reservation" FontSize="16.5" Foreground="#365065" VerticalAlignment="Center"/>
			</StackPanel>
		</Grid>

		<Grid Grid.Row="3" Margin="0,12,0,0">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="*"/>
				<ColumnDefinition Width="Auto"/>
			</Grid.ColumnDefinitions>
			<StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
				<Button Name="BtnZoomOutMain" Content="-" Width="30" Height="28" Margin="0,0,6,0" ToolTip="Zoom out main details and session grid."/>
				<Button Name="BtnZoomInMain" Content="+" Width="30" Height="28" Margin="0,0,10,0" ToolTip="Zoom in main details and session grid."/>
				<TextBlock Text="Session JSON auto-updates every 3 minutes while this app is running." Foreground="#334E68" VerticalAlignment="Center" TextWrapping="Wrap" Margin="0,0,0,0"/>
			</StackPanel>
			<CheckBox Grid.Column="1" Name="ChkSimulationMode" Content="Simulation" VerticalAlignment="Center" Margin="10,0,0,0" HorizontalAlignment="Right" ToolTip="When enabled, simulator rows are added to the Activity Grid every 5-7 seconds."/>
		</Grid>

		<Grid Grid.Row="4" Margin="0,12,0,0">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
			</Grid.ColumnDefinitions>
			<Button Grid.Column="0" Name="BtnRefresh" Content="Refresh" Width="80" Height="30" Margin="0,0,8,0" ToolTip="Manually refresh the session activity data."/>
			<Button Grid.Column="1" Name="BtnSendNotifications" Content="Send..." Width="70" Height="30" Margin="0,0,8,0" ToolTip="Send notifications to users via email, events, or Teams."/>
			<Button Grid.Column="2" Name="BtnCopyMain" Content="Copy" Width="74" Height="30" Margin="0,0,8,0" ToolTip="Copies Session and Grid as PowerShell object format"/>
			<Button Grid.Column="3" Name="BtnEditSettings" Content="Settings..." Width="108" Height="30" Margin="0,0,8,0" ToolTip="Open the settings dialog to configure tracked machines and paths."/>
			<Button Grid.Column="4" Name="BtnLog" Content="Log..." Width="60" Height="30" Margin="0,0,8,0" ToolTip="Show debug and trace log output."/>
			<Button Grid.Column="5" Name="BtnManageUsers" Content="Users..." Width="90" Height="30" Margin="0,0,8,0" ToolTip="Edit user database and admin permissions."/>
			<Button Grid.Column="6" Name="BtnReservations" Content="Reserve..." Width="96" Height="30" Margin="0,0,8,0" ToolTip="View and manage machine reservations calendar."/>
			<Button Grid.Column="7" Name="BtnMinimize" Content="_" Width="34" Height="30" Margin="0,0,8,0" FontWeight="Bold" ToolTip="Minimize to system tray."/>
			<Button Grid.Column="7" Name="BtnCloseAfterSession" Content="Close After Session" Width="150" Height="30" ToolTip="Close the app after the current session ends."/>
		</Grid>

		<Border Grid.Row="5" Margin="0,12,0,0" Padding="8,6" CornerRadius="6" Background="#ECF3FB" BorderBrush="#BFD4E8" BorderThickness="1" ToolTip="Status bar showing current date/time, user, and machine information.">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="2*"/>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="*"/>
				</Grid.ColumnDefinitions>
				<TextBlock Name="TxtStatusDateTime" Grid.Column="0" VerticalAlignment="Center" Foreground="#24415F" FontSize="12" FontWeight="SemiBold" Text="Ready" ToolTip="Current date and time with timezone."/>
				<TextBlock Name="TxtStatusUser" Grid.Column="1" VerticalAlignment="Center" Foreground="#24415F" FontSize="12" TextTrimming="CharacterEllipsis" Margin="10,0,0,0" ToolTip="Current user display name and SEID."/>
				<TextBlock Name="TxtStatusMachine" Grid.Column="2" VerticalAlignment="Center" Foreground="#24415F" FontSize="12" TextTrimming="CharacterEllipsis" Margin="10,0,0,0" ToolTip="Current machine name or FQDN."/>
			</Grid>
		</Border>

		<!-- Cloud Connectivity Status Banner -->
		<Border Name="CloudStatusBanner" Grid.Row="5" Margin="0,4,0,0" Padding="8,6" CornerRadius="6" Background="#FFF3CD" BorderBrush="#F0AD4E" BorderThickness="1" Visibility="Collapsed" Panel.ZIndex="500">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<TextBlock Grid.Column="0" Text="⚠" FontSize="16" VerticalAlignment="Center" Margin="0,0,8,0" Foreground="#856404"/>
				<TextBlock Name="TxtCloudStatus" Grid.Column="1" VerticalAlignment="Center" Foreground="#856404" FontSize="11" TextWrapping="Wrap" Text="Cloud services unavailable. Using offline mode with local data." ToolTip="Network connectivity issue detected."/>
				<Button Name="BtnRetryCloud" Grid.Column="2" Content="Retry" Width="60" Height="24" Margin="8,0,0,0" ToolTip="Retry connecting to cloud services and reload machine list."/>
				<Button Name="BtnDismissCloud" Grid.Column="3" Content="✕" Width="24" Height="24" Margin="4,0,0,0" ToolTip="Dismiss this notification (cloud services will still attempt to reconnect automatically)."/>
			</Grid>
		</Border>

		<Grid Name="StartupOverlay" Grid.RowSpan="6" Background="#B3000000" Visibility="Visible" Panel.ZIndex="1000">
			<Canvas>
				<Border Name="SplashBorder" Width="700" Height="400" Padding="16" CornerRadius="10" Background="#FFFDF8F1" BorderBrush="#D9C7A9" BorderThickness="1" Cursor="SizeAll">
					<Grid>
						<Grid.RowDefinitions>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="*"/>
							<RowDefinition Height="Auto"/>
						</Grid.RowDefinitions>

						<TextBlock Grid.Row="0" Text="Session Tracker Startup Instructions" FontSize="20" FontWeight="SemiBold" Foreground="#2E4A66" Margin="0,0,0,10"/>
						<TextBlock Grid.Row="1" Name="TxtStartupInstructions" TextWrapping="Wrap" Foreground="#2E3A48" FontSize="14" LineHeight="21" Text="This PowerShell UI app monitors status of other Windows machines.&#x0a;This can be our own PAWS (Privileged) machines.&#x0a;Each Remote Desktop login will generate a JSON tracking file in a shared UNC.&#x0a;The GridView at bottom half will show the latest activity.&#x0a;This is mainly to show if someone else might be using the machine that you want to use.&#x0a;If you disconnect, this Session Tracker should be left running.&#x0a;If you log out this and other apps will shutdown and the JSON file is finalized."/>

						<StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
							<Button Name="BtnCloseStartupOverlay" Content="Close" Width="96" Height="32" ToolTip="Close startup instructions and continue to the main screen."/>
						</StackPanel>
					</Grid>
				</Border>
			</Canvas>
		</Grid>
	</Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

[xml]$miniXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Session Mini"
		Width="330"
		Height="150"
		MinWidth="300"
		MinHeight="140"
		WindowStartupLocation="Manual"
		ResizeMode="NoResize"
		WindowStyle="ToolWindow"
		ShowInTaskbar="False"
		Topmost="True"
		Background="#FFF8F0">
	<Window.Resources>
		<Style TargetType="Button">
			<Setter Property="FontWeight" Value="Bold"/>
		</Style>
	</Window.Resources>
	<Border Name="MiniRootBorder" Margin="8" CornerRadius="8" BorderThickness="1" BorderBrush="#F0C9A2" Background="#FFF3E8" Padding="10">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="*"/>
			</Grid.ColumnDefinitions>

			<Image Name="ImgMiniIcon" Grid.Row="0" Grid.Column="0" Width="18" Height="18" Margin="0,0,8,0" VerticalAlignment="Center"/>
			<TextBlock Grid.Row="0" Grid.Column="1" Text="Session Mini Panel" FontSize="14" FontWeight="SemiBold" Foreground="#8A4F12" VerticalAlignment="Center"/>

			<TextBlock Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" Name="TxtMiniMachine" Margin="0,8,0,2" FontSize="12" Foreground="#5E442A" TextWrapping="Wrap"/>
			<TextBlock Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="2" Name="TxtMiniUser" Margin="0,0,0,10" FontSize="12" Foreground="#5E442A" TextWrapping="Wrap"/>

			<Button Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="2" Name="BtnRestoreMini" HorizontalAlignment="Right" Width="118" Height="30">
				<StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
					<Image Name="ImgRestoreIcon" Width="14" Height="14" Margin="0,0,6,0"/>
					<TextBlock Text="Restore" VerticalAlignment="Center"/>
				</StackPanel>
			</Button>
		</Grid>
	</Border>
</Window>
"@

$miniReader = New-Object System.Xml.XmlNodeReader $miniXaml
$miniWindow = [Windows.Markup.XamlReader]::Load($miniReader)

$txtSession = $window.FindName('TxtSession')
$txtUserId = $window.FindName('TxtUserId')
$txtDisplayName = $window.FindName('TxtDisplayName')
$txtUserEmail = $window.FindName('TxtUserEmail')
$txtMachine = $window.FindName('TxtMachine')
$txtFolder = $window.FindName('TxtFolder')
$txtJsonFile = $window.FindName('TxtJsonFile')
$txtLastUpdated = $window.FindName('TxtLastUpdated')
$gridSessionFiles = $window.FindName('GridSessionFiles')
$btnZoomOutMain = $window.FindName('BtnZoomOutMain')
$btnZoomInMain = $window.FindName('BtnZoomInMain')
$chkSimulationMode = $window.FindName('ChkSimulationMode')
$btnRefresh = $window.FindName('BtnRefresh')
$btnSendNotifications = $window.FindName('BtnSendNotifications')
$btnCopyMain = $window.FindName('BtnCopyMain')
$btnEditSettings = $window.FindName('BtnEditSettings')
$btnLog = $window.FindName('BtnLog')
$btnManageUsers = $window.FindName('BtnManageUsers')
$btnReservations = $window.FindName('BtnReservations')
$btnMinimize = $window.FindName('BtnMinimize')
$btnCloseAfterSession = $window.FindName('BtnCloseAfterSession')
$startupOverlay = $window.FindName('StartupOverlay')
$splashBorder = $window.FindName('SplashBorder')
$btnCloseStartupOverlay = $window.FindName('BtnCloseStartupOverlay')
$imgAnimatedIcon = $window.FindName('ImgAnimatedIcon')
$lblSession = $window.FindName('LblSession')
$lblUserId = $window.FindName('LblUserId')
$lblDisplayName = $window.FindName('LblDisplayName')
$lblUserEmail = $window.FindName('LblUserEmail')
$lblMachine = $window.FindName('LblMachine')
$lblFolder = $window.FindName('LblFolder')
$lblJsonFile = $window.FindName('LblJsonFile')
$lblLastUpdated = $window.FindName('LblLastUpdated')
$lblHistory = $window.FindName('LblHistory')
$lblCol = $window.FindName('LblCol')
$valCol = $window.FindName('ValCol')
$topPaneRow = $window.FindName('TopPaneRow')
$bottomPaneRow = $window.FindName('BottomPaneRow')
$txtStatusDateTime = $window.FindName('TxtStatusDateTime')
$txtStatusUser = $window.FindName('TxtStatusUser')
$txtStatusMachine = $window.FindName('TxtStatusMachine')
$cloudStatusBanner = $window.FindName('CloudStatusBanner')
$txtCloudStatus = $window.FindName('TxtCloudStatus')
$btnRetryCloud = $window.FindName('BtnRetryCloud')
$btnDismissCloud = $window.FindName('BtnDismissCloud')

$txtMiniMachine = $miniWindow.FindName('TxtMiniMachine')
$txtMiniUser = $miniWindow.FindName('TxtMiniUser')
$btnRestoreMini = $miniWindow.FindName('BtnRestoreMini')
$imgMiniIcon = $miniWindow.FindName('ImgMiniIcon')
$imgRestoreIcon = $miniWindow.FindName('ImgRestoreIcon')
$miniRootBorder = $miniWindow.FindName('MiniRootBorder')

$settingsData = Read-TrackSessionsSettings -Path $SettingsPath
$script:effectiveOutputFolder = $OutputFolder
$script:trackedMachines = @()
$script:sharedPath = ''
$script:folderMode = 'Default'
$script:currentJsonFilePath = Join-Path -Path $script:effectiveOutputFolder -ChildPath $jsonFileName
$script:miniWindowLeft = $settingsData.MiniWindow.Left
$script:miniWindowTop = $settingsData.MiniWindow.Top
$script:zoomMainContent = $settingsData.ZoomLevels.MainContent
$script:zoomLogViewer = $settingsData.ZoomLevels.LogViewer
$script:bottomPaneHeight = $null
if ($settingsData.Layout -and (Test-IsFiniteDouble -Value $settingsData.Layout.BottomPaneHeight)) {
	$script:bottomPaneHeight = [double]$settingsData.Layout.BottomPaneHeight
}
$script:mainWindowLeft = $null
$script:mainWindowTop = $null
$script:mainWindowWidth = $null
$script:mainWindowHeight = $null
if ($settingsData.Layout -and (Test-IsFiniteDouble -Value $settingsData.Layout.WindowLeft)) {
	$script:mainWindowLeft = [double]$settingsData.Layout.WindowLeft
}
if ($settingsData.Layout -and (Test-IsFiniteDouble -Value $settingsData.Layout.WindowTop)) {
	$script:mainWindowTop = [double]$settingsData.Layout.WindowTop
}
if ($settingsData.Layout -and (Test-IsFiniteDouble -Value $settingsData.Layout.WindowWidth)) {
	$script:mainWindowWidth = [double]$settingsData.Layout.WindowWidth
}
if ($settingsData.Layout -and (Test-IsFiniteDouble -Value $settingsData.Layout.WindowHeight)) {
	$script:mainWindowHeight = [double]$settingsData.Layout.WindowHeight
}

# Splash overlay position/size
$script:splashLeft = $null
$script:splashTop = $null
$script:splashWidth = $null
$script:splashHeight = $null
if ($settingsData.Layout -and (Test-IsFiniteDouble -Value $settingsData.Layout.SplashLeft)) {
	$script:splashLeft = [double]$settingsData.Layout.SplashLeft
}
if ($settingsData.Layout -and (Test-IsFiniteDouble -Value $settingsData.Layout.SplashTop)) {
	$script:splashTop = [double]$settingsData.Layout.SplashTop
}
if ($settingsData.Layout -and (Test-IsFiniteDouble -Value $settingsData.Layout.SplashWidth)) {
	$script:splashWidth = [double]$settingsData.Layout.SplashWidth
}
if ($settingsData.Layout -and (Test-IsFiniteDouble -Value $settingsData.Layout.SplashHeight)) {
	$script:splashHeight = [double]$settingsData.Layout.SplashHeight
}

Add-StartupTrace -Path $SettingsPath -EventName 'Script.Start' -Detail ("PID={0};SettingsPath={1}" -f $PID, $SettingsPath)

function Add-DebugLog {
	param([string]$Message)
	$timestamp = [DateTime]::Now.ToString('HH:mm:ss.fff')
	$entry = "[$timestamp] $Message"
	$script:debugLog += $entry
	if ($script:debugLog.Count -gt 500) {
		$script:debugLog = @($script:debugLog | Select-Object -Last 500)
	}
}

function Update-SessionGridDataFromCache {
	<#
	.SYNOPSIS
	Updates session grid from pre-loaded background cache
	.DESCRIPTION
	Uses data from $script:BackgroundLoadingState.SessionData instead of file system
	#>
	param(
		[Parameter(Mandatory = $true)]$GridControl,
		[Parameter(Mandatory = $false)][string]$ExcludeMachineName = ''
	)

	try {
		Add-DebugLog -Message "Update-SessionGridDataFromCache: Starting with $($script:BackgroundLoadingState.SessionData.Count) cached files"
		$rows = @()

		$excludeToken = ''
		if (-not [string]::IsNullOrWhiteSpace($ExcludeMachineName)) {
			$excludeToken = $ExcludeMachineName.Trim().ToUpperInvariant()
		}
		Add-DebugLog -Message "Excluded machine (current): $excludeToken"

		foreach ($fileData in $script:BackgroundLoadingState.SessionData) {
			try {
				Add-DebugLog -Message "Processing cached file: $($fileData.FileName)"
				$obj = $fileData.Content
				if ($null -eq $obj) {
					Add-DebugLog -Message "  -> Content is null, skipping"
					continue
				}

				$machineValue = [string]$obj.MachineName
				$machineToken = $machineValue.Trim().ToUpperInvariant()
				$machineShortToken = if ($machineToken.Contains('.')) { $machineToken.Split('.')[0] } else { $machineToken }

				# Skip excluded machine (current machine)
				if (-not [string]::IsNullOrWhiteSpace($excludeToken) -and ($machineToken -eq $excludeToken -or $machineShortToken -eq $excludeToken)) {
					Add-DebugLog -Message "  -> Skipping excluded machine: $machineValue"
					continue
				}

				$statusTimestamp = [string]$obj.LastUpdatedAtGmt
				if ([string]::IsNullOrWhiteSpace($statusTimestamp)) {
					$statusTimestamp = [string]$obj.CreatedAtGmt
				}

				# Use Get-SessionStatusFromSnapshot if available, or compute status
				$computedStatus = 'Logged In'
				try {
					$computedStatus = Get-SessionStatusFromSnapshot -SnapshotObject $obj -SourceFilePath $fileData.FullPath
				} catch {}

				$rows += [pscustomobject]@{
					MachineName = $machineValue
					UserId = [string]$obj.UserId
					UserDisplayName = [string]$obj.UserDisplayName
					LastLogin = [string]$obj.CreatedAtGmt
					LastActivity = [string]$obj.LastUpdatedAtGmt
					RowStatus = $computedStatus
					StatusTimestamp = $statusTimestamp
					StatusTimestampDisplay = ("Status changed at: {0}" -f $statusTimestamp)
				}
				Add-DebugLog -Message "  -> Added row: $machineValue | $([string]$obj.UserId) | Status: $computedStatus"
			}
			catch {
				Add-DebugLog -Message "  -> ERROR processing cached file: $($_.Exception.Message)"
			}
		}

		Add-DebugLog -Message "Update-SessionGridDataFromCache: Processed $($script:BackgroundLoadingState.SessionData.Count) files, created $($rows.Count) rows"

		# Combine with simulated rows if simulation mode is enabled
		if ($script:isSimulationModeEnabled -and $script:simulatedRows.Count -gt 0) {
			$combinedRows = @($script:simulatedRows + $rows)
			Add-DebugLog -Message "Update-SessionGridDataFromCache: Combined simulation ($($script:simulatedRows.Count)) and real rows = $($combinedRows.Count)"
		}
		else {
			$combinedRows = $rows
		}

		# Deduplicate: keep only the latest entry for each machine+user combination
		$dedupedRows = @()
		$dedupLookup = @{}

		foreach ($row in @($combinedRows | Sort-Object -Property LastActivity -Descending)) {
			$key = "$($row.MachineName)|$($row.UserId)"
			if (-not $dedupLookup.ContainsKey($key)) {
				$dedupedRows += $row
				$dedupLookup[$key] = $true
				Add-DebugLog -Message "Dedup: Added latest entry for $key (Status: $($row.RowStatus))"
			}
			else {
				Add-DebugLog -Message "Dedup: Skipped duplicate $key (newer entry already added)"
			}
		}

		Add-DebugLog -Message "Update-SessionGridDataFromCache: Deduplicated $($combinedRows.Count) rows to $($dedupedRows.Count) final entries"

		# Sort deduplicated rows
		$finalRows = @($dedupedRows | Sort-Object -Property LastActivity -Descending)

		# Resolve user display names
		foreach ($row in $finalRows) {
			# Safely pass usersList, even if not initialized yet
			$usersList = if ($null -ne $script:usersList) { $script:usersList } else { @() }
			$resolvedName = Get-CachedUserDisplayName -UserId $row.UserId -UsersList $usersList
			if (-not [string]::IsNullOrWhiteSpace($resolvedName)) {
				$row | Add-Member -NotePropertyName 'UserDisplayNameResolved' -NotePropertyValue $resolvedName -Force
			}
			else {
				$row | Add-Member -NotePropertyName 'UserDisplayNameResolved' -NotePropertyValue $row.UserDisplayName -Force
			}
		}

		# Update grid
		if ($GridControl) {
			$GridControl.ItemsSource = $null
			$GridControl.ItemsSource = $finalRows

			$gridView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($GridControl.ItemsSource)
			if ($gridView) {
				$gridView.SortDescriptions.Clear()
				$gridView.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription('LastActivity', [System.ComponentModel.ListSortDirection]::Descending)))
				$gridView.Refresh()
			}
		}

		Add-DebugLog -Message "Update-SessionGridDataFromCache: Grid updated successfully with $($finalRows.Count) entries"
	}
	catch {
		Add-DebugLog -Message "Update-SessionGridDataFromCache ERROR: $($_.Exception.Message)"
		throw
	}
}

function Get-CachedSessionData {
	param([System.IO.FileInfo]$File)

	$key = $File.FullName
	$cached = $script:sessionCache[$key]

	# Cache miss or file modified
	if (-not $cached -or $cached.LastWriteTime -ne $File.LastWriteTime) {
		Add-DebugLog -Message "PERF: Cache miss for $($File.Name), parsing JSON"
		$obj = Get-Content -LiteralPath $File.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
		$script:sessionCache[$key] = @{
			Data = $obj
			LastWriteTime = $File.LastWriteTime
		}
		return $obj
	}

	Add-DebugLog -Message "PERF: Cache hit for $($File.Name)"
	return $cached.Data
}

function Get-CachedUserDisplayName {
	param(
		[Parameter(Mandatory = $true)][string]$UserId,
		$UsersList
	)

	if ($script:userDisplayNameCache.ContainsKey($UserId)) {
		return $script:userDisplayNameCache[$UserId]
	}

	$displayName = Get-UserDisplayName -UserId $UserId -UsersList $UsersList
	$script:userDisplayNameCache[$UserId] = $displayName
	return $displayName
}

function Show-WindowsNotification {
	param(
		[Parameter(Mandatory = $true)][string]$Title,
		[Parameter(Mandatory = $true)][string]$Message
	)

	try {
		[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
		[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
		[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

		$APP_ID = "Session.Tracker"
		$template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$Title</text>
            <text id="2">$Message</text>
        </binding>
    </visual>
</toast>
"@
		
		$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
		$xml.LoadXml($template)
		$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
		[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).Show($toast)
	}
	catch {
	}
}

function Save-MiniWindowPosition {
	param([Parameter(Mandatory = $true)]$MiniWindow)

	if ((Test-IsFiniteDouble -Value $MiniWindow.Left) -and (Test-IsFiniteDouble -Value $MiniWindow.Top)) {
		$script:miniWindowLeft = [Math]::Round($MiniWindow.Left, 2)
		$script:miniWindowTop = [Math]::Round($MiniWindow.Top, 2)
		$settings = Read-TrackSessionsSettings -Path $SettingsPath
		$settings.MiniWindow.Left = $script:miniWindowLeft
		$settings.MiniWindow.Top = $script:miniWindowTop
		Save-TrackSessionsSettings -Path $SettingsPath -Settings $settings
	}
}

function Save-SplitterPosition {
	param(
		[Parameter(Mandatory = $true)]$BottomRow,
		[Parameter(Mandatory = $true)][double]$Height
	)

	if (-not (Test-IsFiniteDouble -Value $Height)) {
		return
	}

	$newHeight = [Math]::Round($Height, 2)
	$script:bottomPaneHeight = $newHeight

	$settings = Read-TrackSessionsSettings -Path $SettingsPath
	if (-not $settings.Layout) {
		$settings.Layout = [ordered]@{ BottomPaneHeight = $null }
	}
	$settings.Layout.BottomPaneHeight = $newHeight
	Save-TrackSessionsSettings -Path $SettingsPath -Settings $settings
}

function Save-MainWindowBounds {
	param([Parameter(Mandatory = $true)]$MainWindow)

	if ($MainWindow.WindowState -eq [System.Windows.WindowState]::Minimized) {
		return
	}

	$bounds = $MainWindow.RestoreBounds
	if (-not (Test-IsFiniteDouble -Value $bounds.Left)) { return }
	if (-not (Test-IsFiniteDouble -Value $bounds.Top)) { return }
	if (-not (Test-IsFiniteDouble -Value $bounds.Width)) { return }
	if (-not (Test-IsFiniteDouble -Value $bounds.Height)) { return }

	$left = [Math]::Round([double]$bounds.Left, 2)
	$top = [Math]::Round([double]$bounds.Top, 2)
	$width = [Math]::Round([double]$bounds.Width, 2)
	$height = [Math]::Round([double]$bounds.Height, 2)

	$settings = Read-TrackSessionsSettings -Path $SettingsPath
	if (-not $settings.Layout) {
		$settings.Layout = [ordered]@{
			BottomPaneHeight = $null
			WindowLeft = $null
			WindowTop = $null
			WindowWidth = $null
			WindowHeight = $null
		}
	}

	$settings.Layout.WindowLeft = $left
	$settings.Layout.WindowTop = $top
	$settings.Layout.WindowWidth = $width
	$settings.Layout.WindowHeight = $height

	Save-TrackSessionsSettings -Path $SettingsPath -Settings $settings
}

function Convert-ToSingleQuotedPsString {
	param([Parameter(Mandatory = $true)][string]$Value)

	return $Value.Replace("'", "''")
}

function Convert-TrackingSettingsToPsObjectText {
	param(
		[Parameter(Mandatory = $true)][string]$SharedPath,
		[Parameter(Mandatory = $true)]$Machines
	)

	$lines = @()
	$lines += '[ordered]@{'
	$lines += "    SharedPath = '{0}'" -f (Convert-ToSingleQuotedPsString -Value $SharedPath)
	$lines += '    Machines = @('

	foreach ($machine in @($Machines)) {
		$shortName = Convert-ToSingleQuotedPsString -Value ([string]$machine.ShortName)
		$fqdn = Convert-ToSingleQuotedPsString -Value ([string]$machine.FQDN)
		$comment = Convert-ToSingleQuotedPsString -Value ([string]$machine.Comment)
		$lines += "        [pscustomobject]@{ ShortName = '{0}'; FQDN = '{1}'; Comment = '{2}' }" -f $shortName, $fqdn, $comment
	}

	$lines += '    )'
	$lines += '}'
	return ($lines -join [Environment]::NewLine)
}

function Copy-TextToClipboard {
	param([Parameter(Mandatory = $true)][string]$Text)

	try {
		Set-Clipboard -Value $Text -ErrorAction Stop
		return
	}
	catch {
	}

	[System.Windows.Clipboard]::SetText($Text)
}

function Resolve-TrackingConfiguration {
	param(
		[Parameter(Mandatory = $true)]$SettingsData,
		[Parameter(Mandatory = $true)][string]$DefaultOutputFolder,
		[Parameter(Mandatory = $true)][string]$JsonFileName,
		[int]$NetworkTimeoutSeconds = 3
	)

	$sharedPath = ''
	if ($SettingsData.Tracking -and $null -ne $SettingsData.Tracking.SharedPath) {
		$sharedPath = [string]$SettingsData.Tracking.SharedPath
	}

	# Load cloud machines with timeout and fallback
	Add-DebugLog -Message "Resolving cloud machines configuration (timeout: ${NetworkTimeoutSeconds}s)"
	$cloudResult = Get-CloudMachines -SharedPath $sharedPath -TimeoutSeconds $NetworkTimeoutSeconds
	$trackedMachines = $cloudResult.Machines
	$machineSource = $cloudResult.Source
	$cloudError = $cloudResult.Error

	if ($cloudError) {
		Add-DebugLog -Message "Cloud machines warning: $cloudError"
	}

	Add-DebugLog -Message "Loaded $($trackedMachines.Count) machines from: $machineSource"

	$effectiveFolder = $DefaultOutputFolder
	$folderMode = 'Default'
	$sharedPathStatus = 'Not Configured'

	if (-not [string]::IsNullOrWhiteSpace($sharedPath)) {
		$candidate = $sharedPath.Trim()
		if ($candidate.StartsWith('\\')) {
			Add-DebugLog -Message "Testing shared path accessibility: $candidate"

			# Test shared path with timeout
			$job = Start-Job -ScriptBlock {
				param($Path)
				try {
					if (Test-Path -LiteralPath $Path) {
						return $true
					}
					else {
						New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop | Out-Null
						return $true
					}
				}
				catch {
					return $false
				}
			} -ArgumentList $candidate

			$completed = Wait-Job -Job $job -Timeout $NetworkTimeoutSeconds
			if ($null -ne $completed) {
				$accessible = Receive-Job -Job $job
				Remove-Job -Job $job -Force

				if ($accessible) {
					$effectiveFolder = $candidate
					$folderMode = 'Shared UNC'
					$sharedPathStatus = 'Accessible'
					Add-DebugLog -Message "Shared path accessible: $candidate"
				}
				else {
					$effectiveFolder = $DefaultOutputFolder
					$folderMode = 'Default (Shared UNC not accessible)'
					$sharedPathStatus = 'Not Accessible'
					Add-DebugLog -Message "Shared path not accessible, using default: $effectiveFolder"
				}
			}
			else {
				# Timeout
				Stop-Job -Job $job -ErrorAction SilentlyContinue
				Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
				$effectiveFolder = $DefaultOutputFolder
				$folderMode = 'Default (Shared UNC timeout)'
				$sharedPathStatus = 'Timeout'
				Add-DebugLog -Message "Shared path timeout after ${NetworkTimeoutSeconds}s, using default: $effectiveFolder"
			}
		}
	}

	$jsonPath = Join-Path -Path $effectiveFolder -ChildPath $JsonFileName

	return [ordered]@{
		EffectiveFolder = $effectiveFolder
		FolderMode = $folderMode
		TrackedMachines = $trackedMachines
		SharedPath = $sharedPath
		SharedPathStatus = $sharedPathStatus
		MachineSource = $machineSource
		MachineLoadError = $cloudError
		JsonPath = $jsonPath
	}
}

$trackingRuntime = Resolve-TrackingConfiguration -SettingsData $settingsData -DefaultOutputFolder $OutputFolder -JsonFileName $jsonFileName
$script:effectiveOutputFolder = [string]$trackingRuntime.EffectiveFolder
$script:trackedMachines = @($trackingRuntime.TrackedMachines)
$script:sharedPath = [string]$trackingRuntime.SharedPath
$script:folderMode = [string]$trackingRuntime.FolderMode
$script:currentJsonFilePath = [string]$trackingRuntime.JsonPath

# Show cloud status banner if there are connectivity issues
if ($trackingRuntime.SharedPathStatus -eq 'Timeout' -or $trackingRuntime.SharedPathStatus -eq 'Not Accessible') {
	if ($null -ne $cloudStatusBanner -and $null -ne $txtCloudStatus) {
		$statusMessage = "Cloud services unavailable"
		if ($trackingRuntime.SharedPathStatus -eq 'Timeout') {
			$statusMessage += " (connection timeout)"
		}
		$statusMessage += ". Using $($trackingRuntime.MachineSource) with $($trackingRuntime.TrackedMachines.Count) machines."

		$txtCloudStatus.Text = $statusMessage
		$cloudStatusBanner.Visibility = [System.Windows.Visibility]::Visible
		Add-DebugLog -Message "Showing cloud status banner: $statusMessage"
	}
}

# Retry Cloud Connection button
if ($null -ne $btnRetryCloud) {
	$btnRetryCloud.Add_Click({
		try {
			Add-DebugLog -Message "Retry Cloud button clicked - reloading tracking configuration"
			$cloudStatusBanner.Visibility = [System.Windows.Visibility]::Collapsed

			# Reload settings and reconfigure
			$settingsData = Read-TrackSessionsSettings -Path $SettingsPath
			$trackingRuntime = Resolve-TrackingConfiguration -SettingsData $settingsData -DefaultOutputFolder $OutputFolder -JsonFileName $jsonFileName -NetworkTimeoutSeconds 5

			$script:effectiveOutputFolder = [string]$trackingRuntime.EffectiveFolder
			$script:trackedMachines = @($trackingRuntime.TrackedMachines)
			$script:sharedPath = [string]$trackingRuntime.SharedPath
			$script:folderMode = [string]$trackingRuntime.FolderMode
			$script:currentJsonFilePath = [string]$trackingRuntime.JsonPath

			# Check if still having issues
			if ($trackingRuntime.SharedPathStatus -eq 'Timeout' -or $trackingRuntime.SharedPathStatus -eq 'Not Accessible') {
				$statusMessage = "Still unable to connect to cloud services"
				if ($trackingRuntime.SharedPathStatus -eq 'Timeout') {
					$statusMessage += " (timeout after 5 seconds)"
				}
				$statusMessage += ". Using $($trackingRuntime.MachineSource)."

				$txtCloudStatus.Text = $statusMessage
				$cloudStatusBanner.Visibility = [System.Windows.Visibility]::Visible
				Add-DebugLog -Message "Retry failed: $statusMessage"
			}
			else {
				# Success!
				[System.Windows.MessageBox]::Show("Successfully connected to cloud services!`n`nLoaded $($trackingRuntime.TrackedMachines.Count) machines from: $($trackingRuntime.MachineSource)", 'Cloud Connection Restored', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
				Add-DebugLog -Message "Retry successful: Connected to $($trackingRuntime.MachineSource)"
			}

			# Refresh the grid with new data
			& $refreshAction
		}
		catch {
			Add-DebugLog -Message "ERROR in Retry Cloud: $($_.Exception.Message)"
			[System.Windows.MessageBox]::Show("Error retrying cloud connection:`n`n$($_.Exception.Message)", 'Retry Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
		}
	}.GetNewClosure())
}

# Dismiss Cloud Status Banner button
if ($null -ne $btnDismissCloud) {
	$btnDismissCloud.Add_Click({
		$cloudStatusBanner.Visibility = [System.Windows.Visibility]::Collapsed
		Add-DebugLog -Message "Cloud status banner dismissed by user"
	}.GetNewClosure())
}

function Convert-MainViewToPsObjectText {
	param(
		[Parameter(Mandatory = $true)]$SessionInfo,
		[Parameter(Mandatory = $true)]$GridRows
	)

	$lines = @()
	$lines += '[ordered]@{'
	$lines += '    Session = [ordered]@{'
	$lines += "        SessionName = '{0}'" -f (Convert-ToSingleQuotedPsString -Value ([string]$SessionInfo.SessionName))
	$lines += "        SessionId = {0}" -f ([int]$SessionInfo.SessionId)
	$lines += "        UserId = '{0}'" -f (Convert-ToSingleQuotedPsString -Value ([string]$SessionInfo.UserId))
	$lines += "        UserDisplayName = '{0}'" -f (Convert-ToSingleQuotedPsString -Value ([string]$SessionInfo.UserDisplayName))
	$lines += "        UserEmail = '{0}'" -f (Convert-ToSingleQuotedPsString -Value ([string]$SessionInfo.UserEmail))
	$lines += "        MachineName = '{0}'" -f (Convert-ToSingleQuotedPsString -Value ([string]$SessionInfo.MachineName))
	$lines += "        OutputFolder = '{0}'" -f (Convert-ToSingleQuotedPsString -Value ([string]$SessionInfo.OutputFolder))
	$lines += "        CurrentJsonFile = '{0}'" -f (Convert-ToSingleQuotedPsString -Value ([string]$SessionInfo.CurrentJsonFile))
	$lines += '    }'
	$lines += '    GridRows = @('

	foreach ($row in @($GridRows)) {
		$machine = Convert-ToSingleQuotedPsString -Value ([string]$row.MachineName)
		$userId = Convert-ToSingleQuotedPsString -Value ([string]$row.UserId)
		$displayName = Convert-ToSingleQuotedPsString -Value ([string]$row.UserDisplayName)
		$lastLogin = Convert-ToSingleQuotedPsString -Value ([string]$row.LastLogin)
		$lastActivity = Convert-ToSingleQuotedPsString -Value ([string]$row.LastActivity)
		$status = Convert-ToSingleQuotedPsString -Value ([string]$row.RowStatus)
		$statusTimestamp = Convert-ToSingleQuotedPsString -Value ([string]$row.StatusTimestamp)
		$lines += "        [pscustomobject]@{ MachineName = '{0}'; UserId = '{1}'; UserDisplayName = '{2}'; LastLogin = '{3}'; LastActivity = '{4}'; Status = '{5}'; StatusTimestamp = '{6}' }" -f $machine, $userId, $displayName, $lastLogin, $lastActivity, $status, $statusTimestamp
	}

	$lines += '    )'
	$lines += '}'
	return ($lines -join [Environment]::NewLine)
}

function Show-EditSettingsDialog {
	param(
		[Parameter(Mandatory = $true)]$OwnerWindow,
		[Parameter(Mandatory = $true)][string]$SettingsFilePath
	)

	$settings = Read-TrackSessionsSettings -Path $SettingsFilePath
	if (-not $settings.Tracking) {
		$settings.Tracking = [ordered]@{
			SharedPath = ''
			Machines = @(Get-DefaultTrackedMachines)
		}
	}

	[xml]$settingsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Track Sessions Settings"
		Height="500"
		Width="900"
		MinHeight="420"
		MinWidth="760"
		WindowStartupLocation="CenterOwner"
		ResizeMode="CanResizeWithGrip"
		ShowInTaskbar="False"
		Background="#F6FAFF"
		ToolTip="Configure tracked machines, shared paths, and session tracking settings.">
	<Window.Resources>
		<Style TargetType="Button">
			<Setter Property="FontWeight" Value="Bold"/>
		</Style>
	</Window.Resources>
	<Grid Margin="14">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<Border Grid.Row="0" Background="#ECF4FF" BorderBrush="#BED8FA" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,0,0,10" ToolTip="Configure shared UNC path and tracked PAWS machines.">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="180"/>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<TextBlock Grid.Column="0" Text="Shared Path (UNC):" FontWeight="SemiBold" VerticalAlignment="Center" ToolTip="Enter a UNC path such as \\server\share\folder."/>
				<TextBox Grid.Column="1" Name="TxtSharedPath" MinHeight="28" VerticalContentAlignment="Center" ToolTip="UNC path used for shared session tracking output or reference."/>
				<Button Grid.Column="2" Name="BtnBrowseSharedPath" Content="Browse" Width="84" Height="28" Margin="8,0,8,0" ToolTip="Browse for a folder and place it in Shared Path."/>
				<Button Grid.Column="3" Name="BtnRevealSharedPath" Content="Reveal in Explorer" Width="136" Height="28" ToolTip="Open the Shared Path folder in Windows Explorer."/>
			</Grid>
		</Border>

		<Border Grid.Row="1" Background="White" BorderBrush="#D4E3F5" BorderThickness="1" CornerRadius="8" Padding="10" ToolTip="Edit machine tracking rows: ShortName, optional FQDN, and comments.">
			<Grid>
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="*"/>
				</Grid.RowDefinitions>
				<TextBlock Grid.Row="0" Text="Tracked Machines" FontWeight="SemiBold" Margin="0,0,0,8" ToolTip="Pre-set PAWS machines are editable. Add or remove rows as needed."/>
				<DataGrid Grid.Row="1"
						 Name="GridTrackedMachines"
						 AutoGenerateColumns="False"
						 CanUserAddRows="True"
						 CanUserDeleteRows="True"
						 CanUserReorderColumns="False"
						 IsReadOnly="False"
						 HeadersVisibility="Column"
						 SelectionMode="Single"
						 SelectionUnit="FullRow"
						 GridLinesVisibility="Horizontal"
						 ScrollViewer.VerticalScrollBarVisibility="Auto"
						 ScrollViewer.HorizontalScrollBarVisibility="Auto"
						 ToolTip="ShortName is required; FQDN is optional; Comment is optional.">
					<DataGrid.Columns>
						<DataGridTextColumn Header="ShortName" Binding="{Binding ShortName, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" Width="180"/>
						<DataGridTextColumn Header="FQDN (Optional)" Binding="{Binding FQDN, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" Width="260"/>
						<DataGridTextColumn Header="Comment" Binding="{Binding Comment, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" Width="*"/>
					</DataGrid.Columns>
				</DataGrid>
			</Grid>
		</Border>

		<Grid Grid.Row="2" Margin="0,10,0,0" ToolTip="Save changes, cancel changes, or copy configuration to clipboard.">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="*"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
			</Grid.ColumnDefinitions>
			<StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
				<Button Name="BtnZoomOutSettings" Content="-" Width="30" Height="28" Margin="0,0,6,0" ToolTip="Zoom out tracked machines grid only."/>
				<Button Name="BtnZoomInSettings" Content="+" Width="30" Height="28" Margin="0,0,6,0" ToolTip="Zoom in tracked machines grid only."/>
				<TextBlock Name="TxtSettingsFontSize" VerticalAlignment="Center" Foreground="#24415F" FontWeight="SemiBold" Text="Font: 11.0" Margin="0,0,16,0" ToolTip="Current font size for tracked machines grid."/>
				<TextBlock VerticalAlignment="Center" Foreground="#325275" Text="Tip: Use Copy to Clipboard for a PowerShell object snippet." ToolTip="Copy in PowerShell Object format."/>
			</StackPanel>
			<Button Grid.Column="1" Name="BtnCopySettings" Width="132" Height="30" Margin="0,0,8,0" Content="Copy to Clipboard" ToolTip="Copy in PowerShell Object format."/>
			<Button Grid.Column="2" Name="BtnCancelSettings" Width="92" Height="30" Margin="0,0,8,0" Content="Cancel" ToolTip="Close this dialog without saving changes."/>
			<Button Grid.Column="3" Name="BtnSaveCloseSettings" Width="122" Height="30" Content="Save &amp; Close" ToolTip="Save TrackSessions.Settings.json and close this dialog."/>
		</Grid>
	</Grid>
</Window>
"@

	$settingsReader = New-Object System.Xml.XmlNodeReader $settingsXaml
	$settingsWindow = [Windows.Markup.XamlReader]::Load($settingsReader)
	$settingsWindow.Owner = $OwnerWindow

	$txtSharedPathSettings = $settingsWindow.FindName('TxtSharedPath')
	$btnBrowseSharedPath = $settingsWindow.FindName('BtnBrowseSharedPath')
	$btnRevealSharedPath = $settingsWindow.FindName('BtnRevealSharedPath')
	$gridTrackedMachines = $settingsWindow.FindName('GridTrackedMachines')
	$btnZoomOutSettings = $settingsWindow.FindName('BtnZoomOutSettings')
	$btnZoomInSettings = $settingsWindow.FindName('BtnZoomInSettings')
	$txtSettingsFontSize = $settingsWindow.FindName('TxtSettingsFontSize')
	$btnCopySettings = $settingsWindow.FindName('BtnCopySettings')
	$btnCancelSettings = $settingsWindow.FindName('BtnCancelSettings')
	$btnSaveCloseSettings = $settingsWindow.FindName('BtnSaveCloseSettings')

	$dataTable = New-Object System.Data.DataTable
	[void]$dataTable.Columns.Add('ShortName', [string])
	[void]$dataTable.Columns.Add('FQDN', [string])
	[void]$dataTable.Columns.Add('Comment', [string])

	foreach ($machine in @($settings.Tracking.Machines)) {
		$row = $dataTable.NewRow()
		$row['ShortName'] = [string]$machine.ShortName
		$row['FQDN'] = [string]$machine.FQDN
		$row['Comment'] = [string]$machine.Comment
		[void]$dataTable.Rows.Add($row)
	}

	$txtSharedPathSettings.Text = [string]$settings.Tracking.SharedPath
	$gridTrackedMachines.ItemsSource = $dataTable.DefaultView

	$btnBrowseSharedPath.Add_Click({
		$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
		$dialog.Description = 'Select shared folder for Track Sessions JSON output'
		$dialog.ShowNewFolderButton = $true

		if (-not [string]::IsNullOrWhiteSpace($txtSharedPathSettings.Text)) {
			$selected = $txtSharedPathSettings.Text.Trim()
			if (Test-Path -LiteralPath $selected) {
				$dialog.SelectedPath = $selected
			}
		}

		$dialogResult = $dialog.ShowDialog()
		if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK -and -not [string]::IsNullOrWhiteSpace($dialog.SelectedPath)) {
			$txtSharedPathSettings.Text = $dialog.SelectedPath
		}
	}.GetNewClosure())

	$btnRevealSharedPath.Add_Click({
		$targetPath = [string]$txtSharedPathSettings.Text
		if ([string]::IsNullOrWhiteSpace($targetPath)) {
			[System.Windows.MessageBox]::Show('Shared Path is empty.', 'Reveal in Explorer', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
			return
		}

		$targetPath = $targetPath.Trim()
		if (-not (Test-Path -LiteralPath $targetPath)) {
			[System.Windows.MessageBox]::Show('The selected path does not exist.', 'Reveal in Explorer', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
			return
		}

		Start-Process -FilePath 'explorer.exe' -ArgumentList $targetPath
	}.GetNewClosure())

	$settingsZoomLevel = 1.0
	$applySettingsGridZoom = {
		param([double]$Zoom)
		$zoomClamped = [Math]::Max(0.80, [Math]::Min(1.80, $Zoom))
		$settingsZoomLevel = [Math]::Round($zoomClamped, 2)
		$fontSize = [Math]::Round(11.0 * $settingsZoomLevel, 1)
		$gridTrackedMachines.FontSize = $fontSize
		$gridTrackedMachines.ColumnHeaderHeight = [Math]::Round(26.0 * $settingsZoomLevel, 0)
		$gridTrackedMachines.RowHeight = [Math]::Round(24.0 * $settingsZoomLevel, 0)
		if ($txtSettingsFontSize) { $txtSettingsFontSize.Text = "Font: $fontSize" }
	}
	& $applySettingsGridZoom -Zoom $settingsZoomLevel

	$btnZoomOutSettings.Add_Click({
		& $applySettingsGridZoom -Zoom ($settingsZoomLevel - 0.10)
	}.GetNewClosure())

	$btnZoomInSettings.Add_Click({
		& $applySettingsGridZoom -Zoom ($settingsZoomLevel + 0.10)
	}.GetNewClosure())

	$collectMachines = {
		$machines = @()
		foreach ($row in $dataTable.Rows) {
			if ($row.RowState -eq [System.Data.DataRowState]::Deleted) {
				continue
			}

			$shortName = [string]$row['ShortName']
			$fqdn = [string]$row['FQDN']
			$comment = [string]$row['Comment']
			if ([string]::IsNullOrWhiteSpace($shortName) -and [string]::IsNullOrWhiteSpace($fqdn) -and [string]::IsNullOrWhiteSpace($comment)) {
				continue
			}

			if ([string]::IsNullOrWhiteSpace($shortName)) {
				throw 'Each machine entry requires a ShortName value.'
			}

			$machines += [ordered]@{
				ShortName = $shortName.Trim()
				FQDN = $fqdn.Trim()
				Comment = $comment.Trim()
			}
		}
		return $machines
	}

	$btnCopySettings.Add_Click({
		try {
			$gridTrackedMachines.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Cell, $true) | Out-Null
			$gridTrackedMachines.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Row, $true) | Out-Null
			$machines = & $collectMachines
			$text = Convert-TrackingSettingsToPsObjectText -SharedPath $txtSharedPathSettings.Text -Machines $machines
			Copy-TextToClipboard -Text $text
			[System.Windows.MessageBox]::Show('Settings copied to clipboard in PowerShell object format.', 'Track Sessions Settings', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
		}
		catch {
			[System.Windows.MessageBox]::Show($_.Exception.Message, 'Copy Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
		}
	}.GetNewClosure())

	$btnCancelSettings.Add_Click({
		$settingsWindow.DialogResult = $false
		$settingsWindow.Close()
	}.GetNewClosure())

	$btnSaveCloseSettings.Add_Click({
		try {
			$gridTrackedMachines.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Cell, $true) | Out-Null
			$gridTrackedMachines.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Row, $true) | Out-Null

			$sharedPath = [string]$txtSharedPathSettings.Text
			if (-not [string]::IsNullOrWhiteSpace($sharedPath)) {
				$sharedPath = $sharedPath.Trim()
				if (-not $sharedPath.StartsWith('\\')) {
					throw 'Shared Path must be a UNC path and start with \\ .'
				}
			}

			$machines = & $collectMachines
			$settingsToSave = Read-TrackSessionsSettings -Path $SettingsFilePath
			if (-not $settingsToSave.Tracking) {
				$settingsToSave.Tracking = [ordered]@{ SharedPath = ''; Machines = @() }
			}
			$settingsToSave.Tracking.SharedPath = $sharedPath
			$settingsToSave.Tracking.Machines = $machines
			Save-TrackSessionsSettings -Path $SettingsFilePath -Settings $settingsToSave

			$settingsWindow.DialogResult = $true
			$settingsWindow.Close()
		}
		catch {
			[System.Windows.MessageBox]::Show($_.Exception.Message, 'Save Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
		}
	}.GetNewClosure())

	$result = $settingsWindow.ShowDialog()
	return [bool]$result
}

function Test-OutlookInstalled {
	try {
		$outlook = New-Object -ComObject Outlook.Application -ErrorAction Stop
		$version = $outlook.Version
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
		return @{
			Installed = $true
			Version = $version
		}
	}
	catch {
		return @{
			Installed = $false
			Version = 'N/A'
		}
	}
}

function Test-TeamsInstalled {
	try {
		$teamsClassicPath = "$env:LOCALAPPDATA\Microsoft\Teams\current\Teams.exe"
		$teamsNewPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\ms-teams.exe"

		if (Test-Path $teamsClassicPath) {
			$versionInfo = (Get-Item $teamsClassicPath).VersionInfo
			return @{ Installed = $true; Version = $versionInfo.FileVersion }
		}
		elseif (Test-Path $teamsNewPath) {
			return @{ Installed = $true; Version = 'Teams 2.0' }
		}

		return @{ Installed = $false; Version = 'N/A' }
	}
	catch {
		return @{ Installed = $false; Version = 'N/A' }
	}
}

function Show-NotifyOthersDialog {
	param(
		[Parameter(Mandatory = $true)]$OwnerWindow,
		[Parameter(Mandatory = $true)][string]$UsersFilePath
	)

	# Import notification module with global scope so functions are accessible everywhere
	$modulePath = Join-Path $PSScriptRoot 'TrackSessions.EmailEventTeams.psm1'
	if (Test-Path -LiteralPath $modulePath) {
		try {
			Import-Module $modulePath -Force -Scope Global -ErrorAction Stop
		}
		catch {
			[System.Windows.MessageBox]::Show("Failed to load notification module: $($_.Exception.Message)", 'Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
			return $null
		}
	}
	else {
		[System.Windows.MessageBox]::Show("Notification module not found at: $modulePath", 'Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
		return $null
	}

	# Check Outlook and Teams installation
	$outlookInfo = Test-OutlookInstalled
	$teamsInfo = Test-TeamsInstalled

	# Load users
	$users = @()
	if (Test-Path -LiteralPath $UsersFilePath) {
		try {
			$usersJson = Get-Content -LiteralPath $UsersFilePath -Raw | ConvertFrom-Json
			$users = @($usersJson)
		}
		catch {
			[System.Windows.MessageBox]::Show("Failed to load users: $($_.Exception.Message)", 'Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
			return $null
		}
	}

	# Define XAML for dialog
	[xml]$notifyXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Notify Others"
		Height="700"
		Width="1000"
		MinHeight="600"
		MinWidth="900"
		WindowStartupLocation="CenterOwner"
		ResizeMode="CanResizeWithGrip"
		ShowInTaskbar="True"
		Background="#F6FAFF"
		Topmost="False"
		ToolTip="Select users to notify via email, calendar events, or Microsoft Teams.">
	<Window.Resources>
		<Style TargetType="Button">
			<Setter Property="FontWeight" Value="Bold"/>
		</Style>
	</Window.Resources>
	<Grid Margin="14">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<!-- Row 0: Header -->
		<Border Grid.Row="0" Background="#ECF4FF" BorderBrush="#BED8FA" BorderThickness="1"
				CornerRadius="8" Padding="12" Margin="0,0,0,10">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<StackPanel Grid.Column="0" Orientation="Vertical">
					<TextBlock Text="Create Notifications" FontSize="21" FontWeight="Bold"
							   Foreground="#24415F" Margin="0,0,0,4"
							   ToolTip="Select users and notification channels to send alerts."/>
					<TextBlock Text="Select users and channels to notify about session changes or reservations."
							   Foreground="#325275" FontSize="16"
							   ToolTip="Check the boxes next to users you want to notify, then click 'Send Notifications'."/>
				</StackPanel>
				<StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
					<CheckBox Name="chkPinWindow" Content="Keep on Top" Margin="0,0,10,0" FontSize="14"
							  ToolTip="Pin this window to stay on top of other windows."/>
					<Button Name="btnCloseNotify" Content="Close" Width="80" Height="32" FontSize="14"
							ToolTip="Close this dialog without sending notifications."/>
				</StackPanel>
			</Grid>
		</Border>

		<!-- Row 1: TabControl with 3 Groups -->
		<TabControl Grid.Row="1" Name="tabGroups" Margin="0,0,0,10"
					ToolTip="Switch between Email, Event, and Teams notification channels.">

			<!-- Tab 1: Email Notifications -->
			<TabItem Name="tabEmail">
				<TabItem.Header>
					<StackPanel Orientation="Horizontal">
						<TextBlock Text="[Email] Notifications" FontSize="14" Margin="0,0,8,0"/>
						<CheckBox Name="chkTabEmail" IsChecked="{Binding ElementName=chkEmailEnable, Path=IsChecked, Mode=OneWay}" IsHitTestVisible="False" ToolTip="Email notifications enabled"/>
					</StackPanel>
				</TabItem.Header>
				<Grid Margin="10">
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
					</Grid.RowDefinitions>

					<StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
						<CheckBox Name="chkEmailEnable" Content="Enable Email Notifications"
								  IsChecked="True" FontWeight="SemiBold" FontSize="14" Margin="0,0,16,0"
								  ToolTip="Check to enable email notifications for selected users."/>
						<Button Name="btnTestEmail" Content="Test Email to Me" Width="160" Height="32" FontSize="14"
								ToolTip="Send a test email to yourself using Outlook."/>
					</StackPanel>

					<DataGrid Grid.Row="1" Name="gridEmailUsers"
							  AutoGenerateColumns="False"
							  CanUserAddRows="False"
							  CanUserDeleteRows="False"
							  IsReadOnly="False"
							  SelectionMode="Extended"
							  HeadersVisibility="Column"
							  GridLinesVisibility="Horizontal"
							  FontSize="14"
							  ColumnHeaderHeight="32"
							  RowHeight="28"
							  IsEnabled="{Binding ElementName=chkEmailEnable, Path=IsChecked}"
							  ToolTip="Select users to receive email notifications. Click checkboxes to select/deselect.">
						<DataGrid.Columns>
							<DataGridTemplateColumn Width="60">
								<DataGridTemplateColumn.Header>
									<CheckBox Name="chkSelectAllEmail" Content="All" ToolTip="Select or deselect all users for email notifications."/>
								</DataGridTemplateColumn.Header>
								<DataGridTemplateColumn.CellTemplate>
									<DataTemplate>
										<CheckBox IsChecked="{Binding Selected, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" HorizontalAlignment="Center"/>
									</DataTemplate>
								</DataGridTemplateColumn.CellTemplate>
							</DataGridTemplateColumn>
							<DataGridTextColumn Header="SEID" Binding="{Binding SEID}" IsReadOnly="True" Width="100"/>
							<DataGridTextColumn Header="Name" Binding="{Binding FullName}" IsReadOnly="True" Width="200"/>
							<DataGridTextColumn Header="Email" Binding="{Binding IRSEmail}" IsReadOnly="True" Width="*"/>
							<DataGridCheckBoxColumn Header="Email Enabled" Binding="{Binding NEmail}" IsReadOnly="True" Width="100"/>
						</DataGrid.Columns>
					</DataGrid>
				</Grid>
			</TabItem>

			<!-- Tab 2: Event Notifications -->
			<TabItem Name="tabEvent">
				<TabItem.Header>
					<StackPanel Orientation="Horizontal">
						<TextBlock Text="[Event] Notifications" FontSize="14" Margin="0,0,8,0"/>
						<CheckBox Name="chkTabEvent" IsChecked="{Binding ElementName=chkEventEnable, Path=IsChecked, Mode=OneWay}" IsHitTestVisible="False" ToolTip="Event notifications enabled"/>
					</StackPanel>
				</TabItem.Header>
				<Grid Margin="10">
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
					</Grid.RowDefinitions>

					<StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
						<CheckBox Name="chkEventEnable" Content="Enable Calendar Event Creation"
								  IsChecked="True" FontWeight="SemiBold" FontSize="14" Margin="0,0,16,0"
								  ToolTip="Check to create calendar events for selected users."/>
						<Button Name="btnTestEvent" Content="Test Event for Me" Width="160" Height="32" FontSize="14"
								ToolTip="Create a test calendar event for yourself in Outlook."/>
					</StackPanel>

					<DataGrid Grid.Row="1" Name="gridEventUsers"
							  AutoGenerateColumns="False"
							  CanUserAddRows="False"
							  CanUserDeleteRows="False"
							  IsReadOnly="False"
							  SelectionMode="Extended"
							  HeadersVisibility="Column"
							  GridLinesVisibility="Horizontal"
							  FontSize="14"
							  ColumnHeaderHeight="32"
							  RowHeight="28"
							  IsEnabled="{Binding ElementName=chkEventEnable, Path=IsChecked}"
							  ToolTip="Select users to receive calendar event invitations. Click checkboxes to select/deselect.">
						<DataGrid.Columns>
							<DataGridTemplateColumn Width="60">
								<DataGridTemplateColumn.Header>
									<CheckBox Name="chkSelectAllEvent" Content="All" ToolTip="Select or deselect all users for event notifications."/>
								</DataGridTemplateColumn.Header>
								<DataGridTemplateColumn.CellTemplate>
									<DataTemplate>
										<CheckBox IsChecked="{Binding Selected, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" HorizontalAlignment="Center"/>
									</DataTemplate>
								</DataGridTemplateColumn.CellTemplate>
							</DataGridTemplateColumn>
							<DataGridTextColumn Header="SEID" Binding="{Binding SEID}" IsReadOnly="True" Width="100"/>
							<DataGridTextColumn Header="Name" Binding="{Binding FullName}" IsReadOnly="True" Width="200"/>
							<DataGridTextColumn Header="Email" Binding="{Binding IRSEmail}" IsReadOnly="True" Width="*"/>
							<DataGridCheckBoxColumn Header="Event Enabled" Binding="{Binding NEvent}" IsReadOnly="True" Width="100"/>
						</DataGrid.Columns>
					</DataGrid>
				</Grid>
			</TabItem>

			<!-- Tab 3: Teams Notifications -->
			<TabItem Name="tabTeams">
				<TabItem.Header>
					<StackPanel Orientation="Horizontal">
						<TextBlock Text="[Teams] Notifications" FontSize="14" Margin="0,0,8,0"/>
						<CheckBox Name="chkTabTeams" IsChecked="{Binding ElementName=chkTeamsEnable, Path=IsChecked, Mode=OneWay}" IsHitTestVisible="False" ToolTip="Teams notifications enabled"/>
					</StackPanel>
				</TabItem.Header>
				<Grid Margin="10">
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
					</Grid.RowDefinitions>

					<StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
						<CheckBox Name="chkTeamsEnable" Content="Enable Microsoft Teams Notifications"
								  IsChecked="True" FontWeight="SemiBold" FontSize="14" Margin="0,0,16,0"
								  ToolTip="Check to send Teams chat messages to selected users."/>
						<Button Name="btnTestTeams" Content="Test Teams to Me" Width="160" Height="32" FontSize="14"
								ToolTip="Open a test Teams chat to yourself."/>
					</StackPanel>

					<DataGrid Grid.Row="1" Name="gridTeamsUsers"
							  AutoGenerateColumns="False"
							  CanUserAddRows="False"
							  CanUserDeleteRows="False"
							  IsReadOnly="False"
							  SelectionMode="Extended"
							  HeadersVisibility="Column"
							  GridLinesVisibility="Horizontal"
							  FontSize="14"
							  ColumnHeaderHeight="32"
							  RowHeight="28"
							  IsEnabled="{Binding ElementName=chkTeamsEnable, Path=IsChecked}"
							  ToolTip="Select users to receive Teams notifications. Teams URL must be configured for each user.">
						<DataGrid.Columns>
							<DataGridTemplateColumn Width="60">
								<DataGridTemplateColumn.Header>
									<CheckBox Name="chkSelectAllTeams" Content="All" ToolTip="Select or deselect all users for Teams notifications."/>
								</DataGridTemplateColumn.Header>
								<DataGridTemplateColumn.CellTemplate>
									<DataTemplate>
										<CheckBox IsChecked="{Binding Selected, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" HorizontalAlignment="Center"/>
									</DataTemplate>
								</DataGridTemplateColumn.CellTemplate>
							</DataGridTemplateColumn>
							<DataGridTextColumn Header="SEID" Binding="{Binding SEID}" IsReadOnly="True" Width="100"/>
							<DataGridTextColumn Header="Name" Binding="{Binding FullName}" IsReadOnly="True" Width="180"/>
							<DataGridTextColumn Header="Teams URL" Binding="{Binding TeamsUrl}" IsReadOnly="True" Width="*"/>
							<DataGridCheckBoxColumn Header="Teams Enabled" Binding="{Binding NTeams}" IsReadOnly="True" Width="100"/>
						</DataGrid.Columns>
					</DataGrid>
				</Grid>
			</TabItem>
		</TabControl>

		<!-- Row 2: Application Status -->
		<Border Grid.Row="2" Background="#E8F4F8" BorderBrush="#B4D7E5" BorderThickness="1"
				CornerRadius="6" Padding="10,6" Margin="0,10,0,10">
			<StackPanel Orientation="Horizontal">
				<TextBlock Text="Status:" FontWeight="SemiBold" FontSize="14" Foreground="#24415F" Margin="0,0,12,0" VerticalAlignment="Center"/>
				<Border Name="borderOutlookStatus" Background="#27AE60" CornerRadius="4" Padding="8,4" Margin="0,0,8,0">
					<TextBlock Name="txtOutlookStatus" Text="Outlook: Ready" Foreground="White" FontSize="14" FontWeight="SemiBold"/>
				</Border>
				<Border Name="borderTeamsStatus" Background="#3498DB" CornerRadius="4" Padding="8,4">
					<TextBlock Name="txtTeamsStatus" Text="Teams: Ready" Foreground="White" FontSize="14" FontWeight="SemiBold"/>
				</Border>
			</StackPanel>
		</Border>

		<!-- Row 3: Action Buttons -->
		<Border Grid.Row="3" Background="#ECF3FB" BorderBrush="#BED8FA" BorderThickness="1"
				CornerRadius="8" Padding="10">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>

				<TextBlock Grid.Column="0" VerticalAlignment="Center" Name="txtSelectionSummary"
						   Text="No users selected" Foreground="#325275" FontSize="14"
						   ToolTip="Summary of selected users across all channels."/>

				<Button Grid.Column="1" Name="btnSendNotifications" Content="Send Notifications"
						Width="180" Height="36" FontSize="14" Margin="0,0,8,0"
						ToolTip="Send notifications to all selected users via enabled channels."/>
				<Button Grid.Column="2" Name="btnCancelNotify" Content="Cancel"
						Width="110" Height="36" FontSize="14"
						ToolTip="Close this dialog without sending notifications."/>
			</Grid>
		</Border>
	</Grid>
</Window>
"@

	# Load window
	$notifyReader = New-Object System.Xml.XmlNodeReader $notifyXaml
	$notifyWindow = [Windows.Markup.XamlReader]::Load($notifyReader)
	$notifyWindow.Owner = $OwnerWindow

	# Find controls
	$chkPinWindow = $notifyWindow.FindName('chkPinWindow')
	$btnCloseNotify = $notifyWindow.FindName('btnCloseNotify')
	$chkEmailEnable = $notifyWindow.FindName('chkEmailEnable')
	$chkEventEnable = $notifyWindow.FindName('chkEventEnable')
	$chkTeamsEnable = $notifyWindow.FindName('chkTeamsEnable')
	$btnTestEmail = $notifyWindow.FindName('btnTestEmail')
	$btnTestEvent = $notifyWindow.FindName('btnTestEvent')
	$btnTestTeams = $notifyWindow.FindName('btnTestTeams')
	$gridEmailUsers = $notifyWindow.FindName('gridEmailUsers')
	$gridEventUsers = $notifyWindow.FindName('gridEventUsers')
	$gridTeamsUsers = $notifyWindow.FindName('gridTeamsUsers')
	$txtSelectionSummary = $notifyWindow.FindName('txtSelectionSummary')
	$btnSendNotifications = $notifyWindow.FindName('btnSendNotifications')
	$btnCancelNotify = $notifyWindow.FindName('btnCancelNotify')

	# Disable Keep on Top checkbox and Close button for now
	if ($chkPinWindow) {
		$chkPinWindow.IsEnabled = $false
		$chkPinWindow.Opacity = 0.5
	}
	if ($btnCloseNotify) {
		$btnCloseNotify.IsEnabled = $false
		$btnCloseNotify.Opacity = 0.5
	}

	# Find "Select All" checkboxes in DataGrid column headers
	$chkSelectAllEmail = $notifyWindow.FindName('chkSelectAllEmail')
	$chkSelectAllEvent = $notifyWindow.FindName('chkSelectAllEvent')
	$chkSelectAllTeams = $notifyWindow.FindName('chkSelectAllTeams')

	# Find status controls
	$borderOutlookStatus = $notifyWindow.FindName('borderOutlookStatus')
	$txtOutlookStatus = $notifyWindow.FindName('txtOutlookStatus')
	$borderTeamsStatus = $notifyWindow.FindName('borderTeamsStatus')
	$txtTeamsStatus = $notifyWindow.FindName('txtTeamsStatus')

	# Update Outlook status
	if ($outlookInfo.Installed) {
		$txtOutlookStatus.Text = "Outlook: $($outlookInfo.Version)"
		$borderOutlookStatus.Background = [System.Windows.Media.Brushes]::MediumSeaGreen
		$borderOutlookStatus.ToolTip = "Outlook is installed and ready. Version: $($outlookInfo.Version)"
	}
	else {
		$txtOutlookStatus.Text = "Outlook: Not Found"
		$borderOutlookStatus.Background = [System.Windows.Media.Brushes]::Tomato
		$borderOutlookStatus.ToolTip = "Outlook is not installed or not accessible"
		$chkEmailEnable.IsChecked = $false
		$chkEmailEnable.IsEnabled = $false
		$chkEventEnable.IsChecked = $false
		$chkEventEnable.IsEnabled = $false
	}

	# Update Teams status
	if ($teamsInfo.Installed) {
		$txtTeamsStatus.Text = "Teams: $($teamsInfo.Version)"
		$borderTeamsStatus.Background = [System.Windows.Media.Brushes]::DodgerBlue
		$borderTeamsStatus.ToolTip = "Teams is installed and ready. Version: $($teamsInfo.Version)"
	}
	else {
		$txtTeamsStatus.Text = "Teams: Not Found"
		$borderTeamsStatus.Background = [System.Windows.Media.Brushes]::Orange
		$borderTeamsStatus.ToolTip = "Teams is not installed"
		$chkTeamsEnable.IsChecked = $false
		$chkTeamsEnable.IsEnabled = $false
	}

	# Prepare user data for grids
	$userDataList = New-Object System.Collections.ObjectModel.ObservableCollection[object]
	foreach ($user in $users) {
		$userRow = [PSCustomObject]@{
			Selected = $false
			SEID = [string]$user.SEID
			FullName = "{0} {1}" -f [string]$user.FirstName, [string]$user.LastName
			IRSEmail = [string]$user.IRSEmail
			NEmail = if ($null -ne $user.NEmail) { [bool]$user.NEmail } else { $false }
			NEvent = if ($null -ne $user.NEvent) { [bool]$user.NEvent } else { $false }
			NTeams = if ($null -ne $user.NTeams) { [bool]$user.NTeams } else { $false }
			TeamsUrl = if ($user.TeamsUrl) { [string]$user.TeamsUrl } else { '' }
		}
		[void]$userDataList.Add($userRow)
	}

	# Bind to all 3 grids (same data source)
	$gridEmailUsers.ItemsSource = $userDataList
	$gridEventUsers.ItemsSource = $userDataList
	$gridTeamsUsers.ItemsSource = $userDataList

	# Update selection summary
	$updateSummary = {
		$emailCount = @($userDataList | Where-Object { $_.Selected }).Count
		$txtSelectionSummary.Text = "Selected: $emailCount user(s)"
	}.GetNewClosure()

	# Subscribe to selection changes (CurrentCellChanged fires when checkboxes are clicked)
	$gridEmailUsers.Add_CurrentCellChanged($updateSummary)
	$gridEventUsers.Add_CurrentCellChanged($updateSummary)
	$gridTeamsUsers.Add_CurrentCellChanged($updateSummary)

	# Select All checkbox handlers
	if ($chkSelectAllEmail) {
		$chkSelectAllEmail.Add_Click({
			$isChecked = [bool]$chkSelectAllEmail.IsChecked
			foreach ($user in $userDataList) {
				$user.Selected = $isChecked
			}
			$gridEmailUsers.Items.Refresh()
			& $updateSummary
		}.GetNewClosure())
	}

	if ($chkSelectAllEvent) {
		$chkSelectAllEvent.Add_Click({
			$isChecked = [bool]$chkSelectAllEvent.IsChecked
			foreach ($user in $userDataList) {
				$user.Selected = $isChecked
			}
			$gridEventUsers.Items.Refresh()
			& $updateSummary
		}.GetNewClosure())
	}

	if ($chkSelectAllTeams) {
		$chkSelectAllTeams.Add_Click({
			$isChecked = [bool]$chkSelectAllTeams.IsChecked
			foreach ($user in $userDataList) {
				$user.Selected = $isChecked
			}
			$gridTeamsUsers.Items.Refresh()
			& $updateSummary
		}.GetNewClosure())
	}

	# Pin window handler
	$chkPinWindow.Add_Click({
		$notifyWindow.Topmost = [bool]$chkPinWindow.IsChecked
	}.GetNewClosure())

	# Close button
	$btnCloseNotify.Add_Click({
		$notifyWindow.Close()
	}.GetNewClosure())

	# Cancel button
	$btnCancelNotify.Add_Click({
		$notifyWindow.Close()
	}.GetNewClosure())

	# Test Email button
	if ($btnTestEmail) {
		$btnTestEmail.Add_Click({
			try {
				$currentUserEmail = $userContext.Email
				if ([string]::IsNullOrWhiteSpace($currentUserEmail)) {
					[System.Windows.MessageBox]::Show("Current user email not found. Cannot send test email.", 'Test Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
					return
				}

				$now = [DateTime]::Now
				$tz = [TimeZoneInfo]::Local
				$tzName = if ($tz.IsDaylightSavingTime($now)) { $tz.DaylightName } else { $tz.StandardName }
				$timestamp = "{0} {1} {2}" -f $now.ToString('ddd'), $now.ToString('yyyy-MM-dd HH:mm:ss'), $tzName

				$result = New-OutlookEmail `
					-To $currentUserEmail `
					-Subject "Test Email from Session Tracker - $timestamp" `
					-Body "This is a test email from the Session Tracker notification system. If you see this window, the email function is working correctly."

				if ($result.Success) {
					[System.Windows.MessageBox]::Show("Test email window opened successfully!", 'Test Success', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
				}
				else {
					[System.Windows.MessageBox]::Show("Failed to create test email:`n`n$($result.Message)", 'Test Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
				}
			}
			catch {
				[System.Windows.MessageBox]::Show("Error creating test email:`n`n$($_.Exception.Message)", 'Test Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
			}
		}.GetNewClosure())
	}

	# Test Event button
	if ($btnTestEvent) {
		$btnTestEvent.Add_Click({
			try {
				$currentUserEmail = $userContext.Email
				if ([string]::IsNullOrWhiteSpace($currentUserEmail)) {
					[System.Windows.MessageBox]::Show("Current user email not found. Cannot create test event.", 'Test Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
					return
				}

				$now = [DateTime]::Now
				$tz = [TimeZoneInfo]::Local
				$tzName = if ($tz.IsDaylightSavingTime($now)) { $tz.DaylightName } else { $tz.StandardName }
				$timestamp = "{0} {1} {2}" -f $now.ToString('ddd'), $now.ToString('yyyy-MM-dd HH:mm:ss'), $tzName

				$startTime = (Get-Date).AddHours(1)
				$result = New-OutlookCalendarEvent `
					-StartDateTime $startTime `
					-DurationMinutes 30 `
					-Subject "Test Event from Session Tracker - $timestamp" `
					-Body "This is a test calendar event from the Session Tracker notification system. If you see this window, the event function is working correctly." `
					-RequiredAttendees $currentUserEmail `
					-ReminderSet $true `
					-ReminderMinutesBeforeStart 15

				if ($result.Success) {
					[System.Windows.MessageBox]::Show("Test event window opened successfully!", 'Test Success', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
				}
				else {
					[System.Windows.MessageBox]::Show("Failed to create test event:`n`n$($result.Message)", 'Test Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
				}
			}
			catch {
				[System.Windows.MessageBox]::Show("Error creating test event:`n`n$($_.Exception.Message)", 'Test Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
			}
		}.GetNewClosure())
	}

	# Test Teams button
	if ($btnTestTeams) {
		$btnTestTeams.Add_Click({
			try {
				$currentUserEmail = $userContext.Email
				if ([string]::IsNullOrWhiteSpace($currentUserEmail)) {
					[System.Windows.MessageBox]::Show("Current user email not found. Cannot open test Teams chat.", 'Test Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
					return
				}

				$now = [DateTime]::Now
				$tz = [TimeZoneInfo]::Local
				$tzName = if ($tz.IsDaylightSavingTime($now)) { $tz.DaylightName } else { $tz.StandardName }
				$timestamp = "{0} {1} {2}" -f $now.ToString('ddd'), $now.ToString('yyyy-MM-dd HH:mm:ss'), $tzName

				$result = Open-TeamsChat `
					-UserEmail $currentUserEmail `
					-Message "$timestamp - Test message from Session Tracker notification system."

				if ($result.Success) {
					[System.Windows.MessageBox]::Show("Test Teams chat opened successfully!", 'Test Success', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
				}
				else {
					[System.Windows.MessageBox]::Show("Failed to open test Teams chat:`n`n$($result.Message)", 'Test Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
				}
			}
			catch {
				[System.Windows.MessageBox]::Show("Error opening test Teams chat:`n`n$($_.Exception.Message)", 'Test Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
			}
		}.GetNewClosure())
	}

	# Send Notifications button
	$btnSendNotifications.Add_Click({
		Add-DebugLog -Message "Send Notifications button clicked"

		# Get selected users or use current user as fallback
		$selectedUsers = @($userDataList | Where-Object { $_.Selected })

		if ($selectedUsers.Count -eq 0) {
			# No users selected - use current user like Test buttons
			Add-DebugLog -Message "No users selected - using current user as fallback"

			$currentUserEmail = $userContext.Email
			if ([string]::IsNullOrWhiteSpace($currentUserEmail)) {
				[System.Windows.MessageBox]::Show("Current user email not found. Cannot send notifications.`n`nPlease check user configuration.", 'Configuration Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
				return
			}

			# Create pseudo-user object for current user
			$selectedUsers = @([PSCustomObject]@{
				FullName = $userContext.DisplayName
				IRSEmail = $currentUserEmail
			})

			Add-DebugLog -Message "Using current user: $($userContext.DisplayName) <$currentUserEmail>"
		}
		else {
			Add-DebugLog -Message "Selected users count: $($selectedUsers.Count)"
		}

		# Collect notification targets - ONLY check master enable checkboxes, NOT individual preferences
		$emailTargets = @()
		$eventTargets = @()
		$teamsTargets = @()

		foreach ($user in $selectedUsers) {
			# Email: only check master enable
			if ([bool]$chkEmailEnable.IsChecked) {
				$emailTargets += $user
				Add-DebugLog -Message "Added to email targets: $($user.FullName)"
			}
			# Event: only check master enable
			if ([bool]$chkEventEnable.IsChecked) {
				$eventTargets += $user
				Add-DebugLog -Message "Added to event targets: $($user.FullName)"
			}
			# Teams: only check master enable (will use email if no TeamsUrl)
			if ([bool]$chkTeamsEnable.IsChecked) {
				$teamsTargets += $user
				Add-DebugLog -Message "Added to Teams targets: $($user.FullName)"
			}
		}

		Add-DebugLog -Message "Final targets - Email: $($emailTargets.Count), Event: $($eventTargets.Count), Teams: $($teamsTargets.Count)"

		# Check if any notifications enabled
		$totalTargets = $emailTargets.Count + $eventTargets.Count + $teamsTargets.Count
		if ($totalTargets -eq 0) {
			[System.Windows.MessageBox]::Show("No notification types are enabled.`n`nPlease enable at least one notification type (Email, Event, or Teams).", 'Nothing to Send', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
			return
		}

		# Build summary message
		$summary = "Notifications will be sent:`n`n"
		$summary += "[Email] {0} user(s)`n" -f $emailTargets.Count
		$summary += "[Calendar] {0} user(s)`n" -f $eventTargets.Count
		$summary += "[Teams] {0} user(s)`n`n" -f $teamsTargets.Count
		$summary += "Proceed with sending notifications?"

		Add-DebugLog -Message "Showing confirmation dialog"
		$result = [System.Windows.MessageBox]::Show($summary, 'Confirm Notifications', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
		Add-DebugLog -Message "User clicked: $result"

		if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
			try {
				# Show wait cursor
				$notifyWindow.Cursor = [System.Windows.Input.Cursors]::Wait
				$txtSelectionSummary.Text = "Processing notifications..."

				# Track successes and failures
				$errors = @()

				# Generate timestamp for subjects/messages
				$now = [DateTime]::Now
				$tz = [TimeZoneInfo]::Local
				$tzName = if ($tz.IsDaylightSavingTime($now)) { $tz.DaylightName } else { $tz.StandardName }
				$timestamp = "{0} {1} {2}" -f $now.ToString('ddd'), $now.ToString('yyyy-MM-dd HH:mm:ss'), $tzName

				Add-DebugLog -Message "User confirmed - starting notification sending: Email=$($emailTargets.Count), Event=$($eventTargets.Count), Teams=$($teamsTargets.Count)"

			# Create ONE email with all recipients (if any)
			if ($emailTargets.Count -gt 0) {
				Add-DebugLog -Message "Processing email notifications..."
				try {
					$toAddresses = ($emailTargets | ForEach-Object { $_.IRSEmail }) -join '; '
					$userNames = ($emailTargets | ForEach-Object { $_.FullName }) -join ', '

					Add-DebugLog -Message "Email recipients: $toAddresses"
					Add-DebugLog -Message "Calling New-OutlookEmail..."

					$emailBody = @"
Hello,

This is a notification regarding session activity.

Recipients: $userNames

Please check the shared drive for details.

Thank you.
"@

					$emailResult = New-OutlookEmail `
						-To $toAddresses `
						-Subject "$timestamp - Session Notification" `
						-Body $emailBody

					Add-DebugLog -Message "Email result: Success=$($emailResult.Success), Message=$($emailResult.Message)"

					if (-not $emailResult.Success) {
						$errors += "Email creation failed: $($emailResult.Message)"
					}
				}
				catch {
					Add-DebugLog -Message "Email exception: $($_.Exception.Message)"
					$errors += "Email creation failed: $($_.Exception.Message)"
				}
			}

			# Create ONE calendar event with all attendees (if any)
			if ($eventTargets.Count -gt 0) {
				Add-DebugLog -Message "Processing event notifications..."
				try {
					$requiredAttendees = ($eventTargets | ForEach-Object { $_.IRSEmail }) -join '; '
					$userNames = ($eventTargets | ForEach-Object { $_.FullName }) -join ', '

					Add-DebugLog -Message "Event attendees: $requiredAttendees"
					Add-DebugLog -Message "Calling New-OutlookCalendarEvent..."

					$eventBody = @"
Scheduled session review meeting.

Attendees: $userNames

Please join at the scheduled time to discuss session activity and updates.
"@

					$startTime = (Get-Date).AddDays(1).Date.AddHours(9) # Tomorrow at 9 AM
					$eventResult = New-OutlookCalendarEvent `
						-StartDateTime $startTime `
						-DurationMinutes 30 `
						-Subject "$timestamp - Session Review Meeting" `
						-Body $eventBody `
						-Location "Virtual/Teams" `
						-RequiredAttendees $requiredAttendees `
						-ReminderSet $true `
						-ReminderMinutesBeforeStart 15

					Add-DebugLog -Message "Event result: Success=$($eventResult.Success), Message=$($eventResult.Message)"

					if (-not $eventResult.Success) {
						$errors += "Calendar event creation failed: $($eventResult.Message)"
					}
				}
				catch {
					Add-DebugLog -Message "Event exception: $($_.Exception.Message)"
					$errors += "Calendar event creation failed: $($_.Exception.Message)"
				}
			}

			# Open Teams chats one at a time (if any)
			if ($teamsTargets.Count -gt 0) {
				Add-DebugLog -Message "Processing Teams notifications..."
			}
			$teamsSuccess = 0
			$teamsFailed = 0
			foreach ($user in $teamsTargets) {
				try {
					# If TeamsUrl is set, use it; otherwise use email
					if (-not [string]::IsNullOrWhiteSpace($user.TeamsUrl)) {
						Add-DebugLog -Message "Opening Teams chat for $($user.FullName) using TeamsUrl"
						$teamsResult = Open-TeamsChat -TeamsUrl $user.TeamsUrl
					}
					else {
						Add-DebugLog -Message "Opening Teams chat for $($user.FullName) using email: $($user.IRSEmail)"
						$teamsResult = Open-TeamsChat -UserEmail $user.IRSEmail -Message "$timestamp - Session notification from Session Tracker."
					}

					Add-DebugLog -Message "Teams result for $($user.FullName): Success=$($teamsResult.Success)"

					if ($teamsResult.Success) {
						$teamsSuccess++
					}
					else {
						$teamsFailed++
						$errors += "Teams for $($user.FullName): $($teamsResult.Message)"
					}

					# Add delay between Teams opens to avoid overwhelming the system
					Start-Sleep -Milliseconds 800
				}
				catch {
					$teamsFailed++
					$errors += "Teams for $($user.FullName): $($_.Exception.Message)"
				}
			}

			# Build result message
			Add-DebugLog -Message "Building result message - Errors: $($errors.Count)"
			$resultMsg = "Notification windows opened:`n`n"
			if ($emailTargets.Count -gt 0) {
				$resultMsg += "[Email] Draft created with $($emailTargets.Count) recipient(s)`n"
			}
			if ($eventTargets.Count -gt 0) {
				$resultMsg += "[Calendar] Event created with $($eventTargets.Count) attendee(s)`n"
			}
			if ($teamsTargets.Count -gt 0) {
				$resultMsg += "[Teams] Opened $teamsSuccess chat(s), Failed: $teamsFailed`n"
			}

			if ($errors.Count -gt 0) {
				$resultMsg += "`nErrors:`n"
				$resultMsg += ($errors -join "`n")
				Add-DebugLog -Message "Errors encountered: $($errors -join ' | ')"
			}
			else {
				$resultMsg += "`nPlease review the Outlook and Teams windows,`nthen send when ready."
				Add-DebugLog -Message "All notifications sent successfully"
			}

				$msgType = if ($errors.Count -eq 0) { [System.Windows.MessageBoxImage]::Information } else { [System.Windows.MessageBoxImage]::Warning }
				[System.Windows.MessageBox]::Show($resultMsg, 'Notification Windows Opened', [System.Windows.MessageBoxButton]::OK, $msgType) | Out-Null

				Add-DebugLog -Message "Send Notifications completed successfully"
				$notifyWindow.Close()
			}
			catch {
				Add-DebugLog -Message "CRITICAL ERROR in Send Notifications: $($_.Exception.Message)"
				[System.Windows.MessageBox]::Show("Unexpected error while sending notifications:`n`n$($_.Exception.Message)", 'Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
			}
			finally {
				# Restore cursor
				$notifyWindow.Cursor = [System.Windows.Input.Cursors]::Arrow
				$txtSelectionSummary.Text = "Ready"
			}
		}
	}.GetNewClosure())

	# Load window position/size from settings
	try {
		$settings = Read-TrackSessionsSettings -Path $SettingsPath
		if ($settings.NotifyDialog) {
			if ((Test-IsFiniteDouble -Value $settings.NotifyDialog.Left) -and
				(Test-IsFiniteDouble -Value $settings.NotifyDialog.Top)) {
				$notifyWindow.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
				$notifyWindow.Left = [double]$settings.NotifyDialog.Left
				$notifyWindow.Top = [double]$settings.NotifyDialog.Top
			}
			if ((Test-IsFiniteDouble -Value $settings.NotifyDialog.Width) -and
				([double]$settings.NotifyDialog.Width -ge $notifyWindow.MinWidth)) {
				$notifyWindow.Width = [double]$settings.NotifyDialog.Width
			}
			if ((Test-IsFiniteDouble -Value $settings.NotifyDialog.Height) -and
				([double]$settings.NotifyDialog.Height -ge $notifyWindow.MinHeight)) {
				$notifyWindow.Height = [double]$settings.NotifyDialog.Height
			}
		}
	}
	catch {
		# Silently ignore - use default position/size
	}

	# Save window position/size when closing
	$notifyWindow.Add_Closing({
		try {
			$settings = Read-TrackSessionsSettings -Path $SettingsPath
			if (-not $settings.NotifyDialog) {
				$settings.NotifyDialog = [ordered]@{
					Left = $null
					Top = $null
					Width = $null
					Height = $null
				}
			}

			# Save position and size
			$settings.NotifyDialog.Left = $notifyWindow.Left
			$settings.NotifyDialog.Top = $notifyWindow.Top
			$settings.NotifyDialog.Width = $notifyWindow.ActualWidth
			$settings.NotifyDialog.Height = $notifyWindow.ActualHeight

			Save-TrackSessionsSettings -Path $SettingsPath -Settings $settings
			Add-DebugLog -Message "Saved Notify Dialog position: L=$($notifyWindow.Left) T=$($notifyWindow.Top) W=$($notifyWindow.ActualWidth) H=$($notifyWindow.ActualHeight)"
		}
		catch {
			# Silently ignore save errors
			Add-DebugLog -Message "Failed to save Notify Dialog position: $($_.Exception.Message)"
		}
	}.GetNewClosure())

	# Show modeless window
	$notifyWindow.Show()
}

$iconFrames = @(
	(New-OrangeCircleIconFrame -Size 32 -Scale 0.92 -GlowAlpha 42),
	(New-OrangeCircleIconFrame -Size 32 -Scale 1.00 -GlowAlpha 68),
	(New-OrangeCircleIconFrame -Size 32 -Scale 1.08 -GlowAlpha 92),
	(New-OrangeCircleIconFrame -Size 32 -Scale 1.00 -GlowAlpha 68)
)
$headerFrames = @(
	(New-OrangeCircleIconFrame -Size 24 -Scale 0.92 -GlowAlpha 42),
	(New-OrangeCircleIconFrame -Size 24 -Scale 1.00 -GlowAlpha 68),
	(New-OrangeCircleIconFrame -Size 24 -Scale 1.08 -GlowAlpha 92),
	(New-OrangeCircleIconFrame -Size 24 -Scale 1.00 -GlowAlpha 68)
)
$script:iconFrameIndex = 0
$window.Icon = $iconFrames[$script:iconFrameIndex]
$imgAnimatedIcon.Source = $headerFrames[$script:iconFrameIndex]
$miniWindow.Icon = $iconFrames[$script:iconFrameIndex]
$imgMiniIcon.Source = $headerFrames[$script:iconFrameIndex]
$imgRestoreIcon.Source = $headerFrames[$script:iconFrameIndex]

$script:isMiniMode = $false
$script:isAppClosing = $false
$script:logoutArtifactsWritten = $false
$script:isSimulationModeEnabled = $false
$script:simulatedRows = @()
$script:simulatedSessionState = @{}

if ((Test-IsFiniteDouble -Value $script:mainWindowWidth) -and (Test-IsFiniteDouble -Value $script:mainWindowHeight) -and (Test-IsFiniteDouble -Value $script:mainWindowLeft) -and (Test-IsFiniteDouble -Value $script:mainWindowTop)) {
	$virtualLeft = [System.Windows.SystemParameters]::VirtualScreenLeft
	$virtualTop = [System.Windows.SystemParameters]::VirtualScreenTop
	$virtualWidth = [System.Windows.SystemParameters]::VirtualScreenWidth
	$virtualHeight = [System.Windows.SystemParameters]::VirtualScreenHeight

	$restoredWidth = [Math]::Max($window.MinWidth, [double]$script:mainWindowWidth)
	$restoredHeight = [Math]::Max($window.MinHeight, [double]$script:mainWindowHeight)

	$maxWidth = [Math]::Max($window.MinWidth, $virtualWidth)
	$maxHeight = [Math]::Max($window.MinHeight, $virtualHeight)
	$restoredWidth = [Math]::Min($restoredWidth, $maxWidth)
	$restoredHeight = [Math]::Min($restoredHeight, $maxHeight)

	$maxLeft = ($virtualLeft + $virtualWidth) - $restoredWidth
	$maxTop = ($virtualTop + $virtualHeight) - $restoredHeight
	$restoredLeft = [Math]::Min([Math]::Max([double]$script:mainWindowLeft, $virtualLeft), $maxLeft)
	$restoredTop = [Math]::Min([Math]::Max([double]$script:mainWindowTop, $virtualTop), $maxTop)

	$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
	$window.Width = $restoredWidth
	$window.Height = $restoredHeight
	$window.Left = $restoredLeft
	$window.Top = $restoredTop
}

$txtSession.Text = "{0} (ID {1})" -f $sessionName, $sessionId
$txtUserId.Text = $userContext.UserId
$txtDisplayName.Text = $userContext.DisplayName
$txtUserEmail.Text = $userContext.Email
$txtMachine.Text = $machineName
$txtFolder.Text = "{0} [{1}]" -f $script:effectiveOutputFolder, $script:folderMode
$txtJsonFile.Text = $script:currentJsonFilePath
$txtMiniMachine.Text = "Machine: {0}" -f $machineName
$txtMiniUser.Text = "Current User: {0}" -f $userContext.UserId

$adminAccentBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($script:UiAdminAccentColorHex))
$debugAccentBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($script:UiDebugAccentColorHex))
$adminAccentBrush.Freeze()
$debugAccentBrush.Freeze()

$btnManageUsers.BorderBrush = $adminAccentBrush
$btnManageUsers.BorderThickness = New-Object System.Windows.Thickness(3)

$btnZoomOutMain.BorderBrush = $debugAccentBrush
$btnZoomOutMain.BorderThickness = New-Object System.Windows.Thickness(3)
$btnZoomInMain.BorderBrush = $debugAccentBrush
$btnZoomInMain.BorderThickness = New-Object System.Windows.Thickness(3)
$chkSimulationMode.BorderBrush = $debugAccentBrush
$chkSimulationMode.BorderThickness = New-Object System.Windows.Thickness(3)
$chkSimulationMode.Padding = '6,2,6,2'

$usersFilePathForAdmin = Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Users.json'

# Load users list for display name lookup
if (Test-Path -LiteralPath $usersFilePathForAdmin) {
	try {
		$usersJson = Get-Content -LiteralPath $usersFilePathForAdmin -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
		if ($null -ne $usersJson) {
			if ($usersJson -is [System.Collections.IEnumerable] -and $usersJson -isnot [string]) {
				$script:usersList = @($usersJson)
			}
		}
	}
	catch {
	}
}

$script:isCurrentUserAdmin = Test-IsCurrentUserAdmin -UsersFilePath $usersFilePathForAdmin -CurrentUserContext $userContext
if (-not $script:isCurrentUserAdmin) {
	$btnManageUsers.Visibility = [System.Windows.Visibility]::Collapsed
	$btnManageUsers.IsEnabled = $false
}

function Update-StatusBar {
	$now = [DateTime]::Now
	$tz = [TimeZoneInfo]::Local
	$tzName = if ($tz.IsDaylightSavingTime($now)) { $tz.DaylightName } else { $tz.StandardName }

	$txtStatusDateTime.Text = "{0} | {1}" -f $now.ToString('dddd, yyyy-MM-dd HH:mm:ss'), $tzName

	# Get user's full name from users list if available
	$displayName = $userContext.DisplayName
	if ($null -ne $script:usersList) {
		$userFullName = Get-UserDisplayName -UserId $userContext.SamAccountName -UsersList $script:usersList
		if (-not [string]::IsNullOrWhiteSpace($userFullName)) {
			$displayName = $userFullName
		}
	}

	$txtStatusUser.Text = "{0} | SEID: {1}" -f $displayName, $userContext.SamAccountName
	$txtStatusMachine.Text = "Machine: {0}" -f $machineName
}

Update-StatusBar

function Get-SimulationInterval {
	$seconds = Get-Random -Minimum 5.0 -Maximum 7.0
	return [TimeSpan]::FromSeconds($seconds)
}

function Get-NextSimulatedState {
	param([Parameter(Mandatory = $true)][string]$CurrentState)

	switch ($CurrentState) {
		'Logged In' {
			if ((Get-Random -Minimum 1 -Maximum 101) -le 45) {
				return 'Disconnected'
			}
			return 'Logged In'
		}
		'Disconnected' { return 'Logged Out' }
		default { return 'Logged In' }
	}
}

function New-SimulatedStateMachineEvent {
	param(
		[Parameter(Mandatory = $true)]$TrackedMachines,
		[Parameter(Mandatory = $true)][string]$CurrentMachineName,
		[Parameter(Mandatory = $true)]$SessionStateMap
	)

	$candidates = @()
	foreach ($entry in @($TrackedMachines)) {
		if ($null -eq $entry) {
			continue
		}

		$candidateName = ''
		if (-not [string]::IsNullOrWhiteSpace([string]$entry.ShortName)) {
			$candidateName = [string]$entry.ShortName
		}
		elseif (-not [string]::IsNullOrWhiteSpace([string]$entry.FQDN)) {
			$candidateName = [string]$entry.FQDN
		}

		if ([string]::IsNullOrWhiteSpace($candidateName)) {
			continue
		}

		$candidateToken = $candidateName.Trim().ToUpperInvariant()
		$currentToken = $CurrentMachineName.Trim().ToUpperInvariant()
		if ($candidateToken -eq $currentToken) {
			continue
		}

		$candidates += $candidateName
	}

	if ($candidates.Count -eq 0) {
		$candidates = @('PAWS001', 'PAWS002', 'PAWS003')
	}

	$stateKeys = @($SessionStateMap.Keys)
	$createNewSession = ($stateKeys.Count -eq 0) -or ((Get-Random -Minimum 1 -Maximum 101) -le 40)

	if ($createNewSession) {
		$selectedMachine = [string]($candidates | Select-Object -First 1 -Skip (Get-Random -Minimum 0 -Maximum $candidates.Count))
		$simUserIndex = Get-Random -Minimum 11 -Maximum 98
		$sessionKey = ('{0}|IRS\\simuser{1}' -f $selectedMachine.ToUpperInvariant(), $simUserIndex)
		if (-not $SessionStateMap.ContainsKey($sessionKey)) {
			$SessionStateMap[$sessionKey] = [ordered]@{
				MachineName = $selectedMachine
				UserId = ("IRS\\simuser{0}" -f $simUserIndex)
				UserDisplayName = ("Sim User {0}" -f $simUserIndex)
				State = 'Logged In'
				LoginAtUtc = [DateTime]::UtcNow
			}
		}
		$session = $SessionStateMap[$sessionKey]
		$nowUtc = [DateTime]::UtcNow
		$stamp = $nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
		return [pscustomobject]@{
			MachineName = [string]$session.MachineName
			UserId = [string]$session.UserId
			UserDisplayName = [string]$session.UserDisplayName
			LastLogin = ([datetime]$session.LoginAtUtc).ToString('yyyy-MM-ddTHH:mm:ssZ')
			LastActivity = $stamp
			RowStatus = 'Logged In'
			StatusTimestamp = $stamp
			StatusTimestampDisplay = ("Status changed at: {0}" -f $stamp)
		}
	}

	$selectedKey = [string]($stateKeys | Select-Object -First 1 -Skip (Get-Random -Minimum 0 -Maximum $stateKeys.Count))
	$session = $SessionStateMap[$selectedKey]
	$nextState = Get-NextSimulatedState -CurrentState ([string]$session.State)
	$session.State = $nextState
	$SessionStateMap[$selectedKey] = $session

	$eventTimeUtc = [DateTime]::UtcNow
	$eventStamp = $eventTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
	$row = [pscustomobject]@{
		MachineName = [string]$session.MachineName
		UserId = [string]$session.UserId
		UserDisplayName = [string]$session.UserDisplayName
		LastLogin = ([datetime]$session.LoginAtUtc).ToString('yyyy-MM-ddTHH:mm:ssZ')
		LastActivity = $eventStamp
		RowStatus = [string]$nextState
		StatusTimestamp = $eventStamp
		StatusTimestampDisplay = ("Status changed at: {0}" -f $eventStamp)
	}

	if ($nextState -eq 'Logged Out') {
		[void]$SessionStateMap.Remove($selectedKey)
	}

	return $row
}

function New-SimulatedActivityRow {
	param(
		[Parameter(Mandatory = $true)]$TrackedMachines,
		[Parameter(Mandatory = $true)][string]$CurrentMachineName
	)

	$candidates = @()
	foreach ($entry in @($TrackedMachines)) {
		if ($null -eq $entry) {
			continue
		}

		$candidateName = ''
		if (-not [string]::IsNullOrWhiteSpace([string]$entry.ShortName)) {
			$candidateName = [string]$entry.ShortName
		}
		elseif (-not [string]::IsNullOrWhiteSpace([string]$entry.FQDN)) {
			$candidateName = [string]$entry.FQDN
		}

		if ([string]::IsNullOrWhiteSpace($candidateName)) {
			continue
		}

		$candidateToken = $candidateName.Trim().ToUpperInvariant()
		$currentToken = $CurrentMachineName.Trim().ToUpperInvariant()
		if ($candidateToken -eq $currentToken) {
			continue
		}

		$candidates += $candidateName
	}

	if ($candidates.Count -eq 0) {
		$candidates = @('PAWS001', 'PAWS002', 'PAWS003')
	}

	$nowUtc = [DateTime]::UtcNow
	$selectedMachine = [string]($candidates | Select-Object -First 1 -Skip (Get-Random -Minimum 0 -Maximum $candidates.Count))
	$simUserIndex = Get-Random -Minimum 11 -Maximum 98
	$stamp = $nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')

	return [pscustomobject]@{
		MachineName = $selectedMachine
		UserId = ("IRS\\simuser{0}" -f $simUserIndex)
		UserDisplayName = ("Sim User {0}" -f $simUserIndex)
		LastLogin = $stamp
		LastActivity = $stamp
		RowStatus = 'Logged In'
		StatusTimestamp = $stamp
		StatusTimestampDisplay = ("Status changed at: {0}" -f $stamp)
	}
}

function Update-SessionGridData {
	try {
		Add-DebugLog -Message "Update-SessionGridData: Starting"
		$realRows = @(Get-SessionGridRows -FolderPath $script:effectiveOutputFolder -TrackedMachines $script:trackedMachines -ExcludeMachineName $machineName)
		Add-DebugLog -Message "Update-SessionGridData: Got $($realRows.Count) real rows"
		
		if ($script:isSimulationModeEnabled -and $script:simulatedRows.Count -gt 0) {
			$combinedRows = @($script:simulatedRows + $realRows)
			Add-DebugLog -Message "Update-SessionGridData: Combined simulation ($($script:simulatedRows.Count)) and real rows = $($combinedRows.Count)"
		}
		else {
			$combinedRows = $realRows
			Add-DebugLog -Message "Update-SessionGridData: Using real rows only"
		}

		# Deduplicate: keep only the latest entry for each machine+user combination
		$dedupedRows = @()
		$dedupLookup = @{}
		
		foreach ($row in @($combinedRows | Sort-Object -Property LastActivity -Descending)) {
			$key = "$($row.MachineName)|$($row.UserId)"
			if (-not $dedupLookup.ContainsKey($key)) {
				$dedupedRows += $row
				$dedupLookup[$key] = $true
				Add-DebugLog -Message "Dedup: Added latest entry for $key (Status: $($row.RowStatus))"
			}
			else {
				Add-DebugLog -Message "Dedup: Skipped duplicate $key (newer entry already added)"
			}
		}
		
		Add-DebugLog -Message "Update-SessionGridData: Deduplicated $($combinedRows.Count) rows to $($dedupedRows.Count) final entries"
		
		# Sort deduplicated rows by LastActivity descending
		$finalRows = @($dedupedRows | Sort-Object -Property LastActivity -Descending)
		
		# Ensure all rows have UserDisplayNameResolved with proper lookup (using cache)
		foreach ($row in $finalRows) {
			# Safely pass usersList, even if not initialized yet
			$usersList = if ($null -ne $script:usersList) { $script:usersList } else { @() }
			$resolvedName = Get-CachedUserDisplayName -UserId $row.UserId -UsersList $usersList
			if (-not [string]::IsNullOrWhiteSpace($resolvedName)) {
				$row | Add-Member -NotePropertyName 'UserDisplayNameResolved' -NotePropertyValue $resolvedName -Force
			}
			else {
				$row | Add-Member -NotePropertyName 'UserDisplayNameResolved' -NotePropertyValue $row.UserDisplayName -Force
			}
		}
		
		if ($gridSessionFiles) {
			$gridSessionFiles.ItemsSource = $null
			$gridSessionFiles.ItemsSource = $finalRows

			$gridView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($gridSessionFiles.ItemsSource)
			if ($gridView) {
				$gridView.SortDescriptions.Clear()
				$gridView.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription('LastActivity', [System.ComponentModel.ListSortDirection]::Descending)))
				$gridView.Refresh()
			}
		}
		Add-DebugLog -Message "Update-SessionGridData: Grid updated successfully with $($finalRows.Count) deduplicated entries"
	}
	catch {
		Add-DebugLog -Message "Update-SessionGridData ERROR: $($_.Exception.Message)"
	}
}

$refreshAction = {
	try {
		$perfTimer = [System.Diagnostics.Stopwatch]::StartNew()
		Add-DebugLog -Message "refreshAction: Starting"
		$snapshot = Write-SessionSnapshot -CreatedAt $createdAtGmt -JsonPath $script:currentJsonFilePath -MachineName $machineName -SessionId $sessionId -SessionName $sessionName -UserContext $userContext
		if ($txtLastUpdated) { $txtLastUpdated.Text = $snapshot.LastUpdatedAtGmt }
		if ($txtJsonFile) { $txtJsonFile.Text = $script:currentJsonFilePath }
		if ($txtFolder) { $txtFolder.Text = "{0} [{1}]" -f $script:effectiveOutputFolder, $script:folderMode }

		$gridUpdateStart = [System.Diagnostics.Stopwatch]::StartNew()
		Update-SessionGridData
		$gridUpdateStart.Stop()
		Add-DebugLog -Message "PERF: Update-SessionGridData took $($gridUpdateStart.ElapsedMilliseconds)ms"
		
		# Check for new entries and show Windows notifications
		if ($gridSessionFiles -and $gridSessionFiles.ItemsSource) {
			$currentRows = @($gridSessionFiles.ItemsSource)
			if ($currentRows.Count -gt 0) {
				foreach ($row in $currentRows) {
					$isNew = $true
					foreach ($oldEntry in $script:lastNotificationEntries) {
						if ($oldEntry.MachineName -eq $row.MachineName -and $oldEntry.UserId -eq $row.UserId -and $oldEntry.LastActivity -eq $row.LastActivity) {
							$isNew = $false
							break
						}
					}
					if ($isNew) {
						if ($window -and $window.WindowState -eq [System.Windows.WindowState]::Minimized) {
							$title = "Session Activity: $($row.MachineName)"
							$message = "$($row.UserDisplayName) - $($row.RowStatus)"
							Show-WindowsNotification -Title $title -Message $message
						}
					}
				}
				
				$script:lastNotificationEntries = @($currentRows)
			}
		}

		$perfTimer.Stop()
		Add-DebugLog -Message "PERF: Total refreshAction took $($perfTimer.ElapsedMilliseconds)ms"
		Add-DebugLog -Message "refreshAction: Completed"
	}
	catch {
		Add-DebugLog -Message "refreshAction ERROR: $($_.Exception.Message)"
	}
}

$labelControls = @($lblSession, $lblUserId, $lblDisplayName, $lblUserEmail, $lblMachine, $lblFolder, $lblJsonFile, $lblLastUpdated)
$valueControls = @($txtSession, $txtUserId, $txtDisplayName, $txtUserEmail, $txtMachine, $txtFolder, $txtJsonFile, $txtLastUpdated)
$script:mainZoomLevel = $script:zoomMainContent

function Set-MainContentZoom {
	param(
		[Parameter(Mandatory = $true)][double]$ZoomLevel,
		[Parameter(Mandatory = $true)][Object[]]$Labels,
		[Parameter(Mandatory = $true)][Object[]]$Values,
		[Parameter(Mandatory = $true)]$HistoryLabel,
		[Parameter(Mandatory = $true)]$SessionGrid
	)

	$clamped = [Math]::Max(0.80, [Math]::Min(1.80, $ZoomLevel))
	$script:mainZoomLevel = [Math]::Round($clamped, 2)

	$labelSize = [Math]::Round(12.0 * $script:mainZoomLevel, 1)
	$valueSize = [Math]::Round(12.0 * $script:mainZoomLevel, 1)
	$gridSize = [Math]::Round(11.0 * $script:mainZoomLevel, 1)

	foreach ($label in $Labels) {
		$label.FontSize = $labelSize
	}
	foreach ($value in $Values) {
		$value.FontSize = $valueSize
	}
	$HistoryLabel.FontSize = $labelSize
	$SessionGrid.FontSize = $gridSize
	$SessionGrid.ColumnHeaderHeight = [Math]::Round(26.0 * $script:mainZoomLevel, 0)
	$SessionGrid.RowHeight = [Math]::Round(24.0 * $script:mainZoomLevel, 0)

	# Save zoom level to settings
	try {
		$settings = Read-TrackSessionsSettings -Path $SettingsPath
		$settings.ZoomLevels.MainContent = $script:mainZoomLevel
		Save-TrackSessionsSettings -Path $SettingsPath -Settings $settings
	}
	catch {
		# Silently ignore save errors
	}
}

function Update-MinimumLayoutConstraints {
	param(
		[Parameter(Mandatory = $true)]$MainWindow,
		[Parameter(Mandatory = $true)]$TopPaneRow,
		[Parameter(Mandatory = $true)]$BottomPaneRow,
		[Parameter(Mandatory = $true)]$HistoryLabel,
		[Parameter(Mandatory = $true)]$SessionGrid,
		[Parameter(Mandatory = $true)]$SampleValueControl
	)

	$tuning = $script:LayoutConstraintTuning
	$topVisibleRows = [int]$tuning.TopVisibleRows
	$bottomVisibleRows = [int]$tuning.BottomVisibleRows

	$topRowHeight = [Math]::Max([double]$tuning.TopRowBaseMinHeight, [Math]::Ceiling($SampleValueControl.FontSize * [double]$tuning.TopRowFontMultiplier))
	$topPaneMinimum = [Math]::Ceiling(($topVisibleRows * $topRowHeight) + [double]$tuning.TopPanePadding)

	$gridHeaderHeight = [Math]::Max([double]$tuning.GridHeaderBaseMinHeight, [double]$SessionGrid.ColumnHeaderHeight)
	$gridRowHeight = [Math]::Max([double]$tuning.GridRowBaseMinHeight, [double]$SessionGrid.RowHeight)
	$gridRowsOnlyMinimum = [Math]::Ceiling($gridHeaderHeight + ($bottomVisibleRows * $gridRowHeight) + [double]$tuning.GridRowsBottomPadding)
	$historyLabelHeight = [Math]::Max([double]$tuning.HistoryLabelBaseMinHeight, [Math]::Ceiling($HistoryLabel.FontSize * [double]$tuning.HistoryLabelFontMultiplier))
	$bottomPaneMinimum = [Math]::Ceiling($historyLabelHeight + $gridRowsOnlyMinimum + [double]$tuning.BottomPanePadding)

	$TopPaneRow.MinHeight = $topPaneMinimum
	$BottomPaneRow.MinHeight = $bottomPaneMinimum
	$SessionGrid.MinHeight = $gridRowsOnlyMinimum

	$currentTopHeight = [Math]::Max([double]$TopPaneRow.ActualHeight, $topPaneMinimum)
	$currentBottomHeight = [Math]::Max([double]$BottomPaneRow.ActualHeight, $bottomPaneMinimum)
	$fixedHeight = [Math]::Ceiling([double]$MainWindow.ActualHeight - ($currentTopHeight + $currentBottomHeight))
	if ($fixedHeight -lt [double]$tuning.WindowFrameBaseMinHeight) {
		$fixedHeight = [double]$tuning.WindowFrameBaseMinHeight
	}

	$MainWindow.MinHeight = [Math]::Ceiling($fixedHeight + $topPaneMinimum + $bottomPaneMinimum)
}

function Update-MainContentZoom {
	param(
		[Parameter(Mandatory = $true)][double]$Delta,
		[Parameter(Mandatory = $true)][Object[]]$Labels,
		[Parameter(Mandatory = $true)][Object[]]$Values,
		[Parameter(Mandatory = $true)]$HistoryLabel,
		[Parameter(Mandatory = $true)]$SessionGrid
	)

	Set-MainContentZoom -ZoomLevel ($script:mainZoomLevel + $Delta) -Labels $Labels -Values $Values -HistoryLabel $HistoryLabel -SessionGrid $SessionGrid
	Update-MinimumLayoutConstraints -MainWindow $window -TopPaneRow $topPaneRow -BottomPaneRow $bottomPaneRow -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles -SampleValueControl $txtSession
}

function Set-ResponsiveInfoLayout {
	param(
		[Parameter(Mandatory = $true)][double]$WindowWidth,
		[Parameter(Mandatory = $true)][Object[]]$Labels,
		[Parameter(Mandatory = $true)][Object[]]$Values,
		[Parameter(Mandatory = $true)]$LabelColumn,
		[Parameter(Mandatory = $true)]$ValueColumn
	)

	$isStacked = $WindowWidth -lt 620

	if ($isStacked) {
		$LabelColumn.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
		$ValueColumn.Width = New-Object System.Windows.GridLength(0)
		for ($i = 0; $i -lt $Labels.Count; $i++) {
			$labelRow = $i * 2
			$valueRow = $labelRow + 1

			[System.Windows.Controls.Grid]::SetRow($Labels[$i], $labelRow)
			[System.Windows.Controls.Grid]::SetColumn($Labels[$i], 0)
			[System.Windows.Controls.Grid]::SetColumnSpan($Labels[$i], 2)
			$Labels[$i].Margin = '0,4,0,0'

			[System.Windows.Controls.Grid]::SetRow($Values[$i], $valueRow)
			[System.Windows.Controls.Grid]::SetColumn($Values[$i], 0)
			[System.Windows.Controls.Grid]::SetColumnSpan($Values[$i], 2)
			$Values[$i].Margin = '0,0,0,8'
		}
	}
	else {
		if ($WindowWidth -lt 860) {
			$LabelColumn.Width = New-Object System.Windows.GridLength(190)
		}
		else {
			$LabelColumn.Width = New-Object System.Windows.GridLength(230)
		}
		$ValueColumn.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)

		for ($i = 0; $i -lt $Labels.Count; $i++) {
			[System.Windows.Controls.Grid]::SetRow($Labels[$i], $i)
			[System.Windows.Controls.Grid]::SetColumn($Labels[$i], 0)
			[System.Windows.Controls.Grid]::SetColumnSpan($Labels[$i], 1)
			$Labels[$i].Margin = '0,4,6,6'

			[System.Windows.Controls.Grid]::SetRow($Values[$i], $i)
			[System.Windows.Controls.Grid]::SetColumn($Values[$i], 1)
			[System.Windows.Controls.Grid]::SetColumnSpan($Values[$i], 1)
			$Values[$i].Margin = '0,4,0,6'
		}
	}
}

function Show-MiniSessionPanel {
	if ($script:isMiniMode) {
		return
	}
	Add-StartupTrace -Path $SettingsPath -EventName 'Mini.Show.Requested' -Detail ("MainState={0}" -f $window.WindowState)

	$script:isMiniMode = $true
	$workArea = [System.Windows.SystemParameters]::WorkArea
	if ((Test-IsFiniteDouble -Value $script:miniWindowLeft) -and (Test-IsFiniteDouble -Value $script:miniWindowTop)) {
		$maxLeft = $workArea.Right - $miniWindow.Width
		$maxTop = $workArea.Bottom - $miniWindow.Height
		$miniWindow.Left = [Math]::Min([Math]::Max($script:miniWindowLeft, $workArea.Left), $maxLeft)
		$miniWindow.Top = [Math]::Min([Math]::Max($script:miniWindowTop, $workArea.Top), $maxTop)
	}
	else {
		$miniWindow.Left = $workArea.Right - $miniWindow.Width - 16
		$miniWindow.Top = $workArea.Bottom - $miniWindow.Height - 16
	}
	$window.ShowInTaskbar = $false
	$window.WindowState = [System.Windows.WindowState]::Minimized
	$miniWindow.Show()
	$miniWindow.Activate()
	
	# Auto-hide mini window after 4 seconds with fade
	$miniAutoHideTimer = New-Object System.Windows.Threading.DispatcherTimer
	$miniAutoHideTimer.Interval = [TimeSpan]::FromSeconds(4)
	$miniAutoHideTimer.Add_Tick({
		$miniAutoHideTimer.Stop()
		if ($miniWindow.IsVisible) {
			# Non-blocking fade out animation using timer
			$fadeTimer = New-Object System.Windows.Threading.DispatcherTimer
			$fadeTimer.Interval = [TimeSpan]::FromMilliseconds(50)
			$script:fadeOpacity = 1.0
			
			$fadeTimer.Add_Tick({
				$script:fadeOpacity -= 0.1
				if ($script:fadeOpacity -lt 0) { $script:fadeOpacity = 0 }
				$miniWindow.Opacity = $script:fadeOpacity

				if ($script:fadeOpacity -le 0) {
					$fadeTimer.Stop()
					$miniWindow.Hide()
					$miniWindow.Opacity = 1.0
				}
			}.GetNewClosure())
			$fadeTimer.Start()
		}
	}.GetNewClosure())
	$miniAutoHideTimer.Start()
	Add-StartupTrace -Path $SettingsPath -EventName 'Mini.Show.Completed' -Detail ("MiniLeft={0};MiniTop={1}" -f [Math]::Round($miniWindow.Left, 2), [Math]::Round($miniWindow.Top, 2))
}

function Restore-MainWindowFromMini {
	if (-not $script:isMiniMode) {
		return
	}
	Add-StartupTrace -Path $SettingsPath -EventName 'Mini.Restore.Requested' -Detail ''

	$script:isMiniMode = $false
	$miniWindow.Hide()
	$window.ShowInTaskbar = $true
	$window.WindowState = [System.Windows.WindowState]::Normal
	$window.Activate()
	Add-StartupTrace -Path $SettingsPath -EventName 'Mini.Restore.Completed' -Detail ("MainState={0}" -f $window.WindowState)
}

$btnRefresh.Add_Click($refreshAction)

$btnSendNotifications.Add_Click({
	$usersFilePath = Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Users.json'
	if (Test-Path -LiteralPath $usersFilePath) {
		Show-NotifyOthersDialog -OwnerWindow $window -UsersFilePath $usersFilePath
	}
	else {
		[System.Windows.MessageBox]::Show("Users file not found at: $usersFilePath", 'Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
	}
}.GetNewClosure())

$simulationTimer = New-Object System.Windows.Threading.DispatcherTimer
$simulationTimer.Interval = Get-SimulationInterval
$simulationTimer.Add_Tick({
	if (-not $script:isSimulationModeEnabled) {
		return
	}

	$nextEvent = New-SimulatedStateMachineEvent -TrackedMachines $script:trackedMachines -CurrentMachineName $machineName -SessionStateMap $script:simulatedSessionState
	$script:simulatedRows = @($nextEvent) + @($script:simulatedRows)
	if ($script:simulatedRows.Count -gt 40) {
		$script:simulatedRows = @($script:simulatedRows | Select-Object -First 40)
	}

	Update-SessionGridData
	$simulationTimer.Interval = Get-SimulationInterval
}.GetNewClosure())

$chkSimulationMode.Add_Checked({
	$script:isSimulationModeEnabled = $true
	if ($script:simulatedRows.Count -eq 0) {
		$script:simulatedRows = @((New-SimulatedStateMachineEvent -TrackedMachines $script:trackedMachines -CurrentMachineName $machineName -SessionStateMap $script:simulatedSessionState))
	}
	Update-SessionGridData
	$simulationTimer.Interval = Get-SimulationInterval
	if (-not $simulationTimer.IsEnabled) {
		$simulationTimer.Start()
	}
	Add-StartupTrace -Path $SettingsPath -EventName 'Simulation.Enabled' -Detail 'Activity Grid simulator started.'
}.GetNewClosure())

$chkSimulationMode.Add_Unchecked({
	$script:isSimulationModeEnabled = $false
	if ($simulationTimer.IsEnabled) {
		$simulationTimer.Stop()
	}
	$script:simulatedRows = @()
	$script:simulatedSessionState = @{}
	Update-SessionGridData
	Add-StartupTrace -Path $SettingsPath -EventName 'Simulation.Disabled' -Detail 'Activity Grid simulator stopped.'
}.GetNewClosure())

$btnZoomOutMain.Add_Click({
	Update-MainContentZoom -Delta (-0.10) -Labels $labelControls -Values $valueControls -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles
}.GetNewClosure())

$btnZoomInMain.Add_Click({
	Update-MainContentZoom -Delta 0.10 -Labels $labelControls -Values $valueControls -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles
}.GetNewClosure())

$btnCopyMain.Add_Click({
	try {
		$sessionInfo = [ordered]@{
			SessionName = $sessionName
			SessionId = $sessionId
			UserId = $userContext.UserId
			UserDisplayName = $userContext.DisplayName
			UserEmail = $userContext.Email
			MachineName = $machineName
			OutputFolder = $script:effectiveOutputFolder
			CurrentJsonFile = $script:currentJsonFilePath
		}
		$rows = @($gridSessionFiles.ItemsSource)
		$copyText = Convert-MainViewToPsObjectText -SessionInfo $sessionInfo -GridRows $rows
		Copy-TextToClipboard -Text $copyText
		[System.Windows.MessageBox]::Show('Session and grid copied in PowerShell object format.', 'Track Sessions', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
	}
	catch {
		[System.Windows.MessageBox]::Show($_.Exception.Message, 'Copy Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
	}
}.GetNewClosure())

$btnEditSettings.Add_Click({
	try {
		Add-DebugLog -Message "Settings button clicked - opening dialog"
		$didSaveSettings = Show-EditSettingsDialog -OwnerWindow $window -SettingsFilePath $SettingsPath
		Add-DebugLog -Message "Settings dialog closed - SavedSettings: $didSaveSettings"

		if ($didSaveSettings) {
			$settingsData = Read-TrackSessionsSettings -Path $SettingsPath
			$trackingRuntime = Resolve-TrackingConfiguration -SettingsData $settingsData -DefaultOutputFolder $OutputFolder -JsonFileName $jsonFileName
			$script:effectiveOutputFolder = [string]$trackingRuntime.EffectiveFolder
			$script:trackedMachines = @($trackingRuntime.TrackedMachines)
			$script:sharedPath = [string]$trackingRuntime.SharedPath
			$script:folderMode = [string]$trackingRuntime.FolderMode
			$script:currentJsonFilePath = [string]$trackingRuntime.JsonPath
			if ($script:isSimulationModeEnabled) {
				$script:simulatedRows = @()
				$script:simulatedSessionState = @{}
			}
			& $refreshAction
			Add-DebugLog -Message "Settings applied and refreshed"
		}
	}
	catch {
		Add-DebugLog -Message "ERROR in Settings button: $($_.Exception.Message)"
		[System.Windows.MessageBox]::Show(
			"Error opening Settings dialog: $($_.Exception.Message)",
			'Settings Error',
			[System.Windows.MessageBoxButton]::OK,
			[System.Windows.MessageBoxImage]::Error
		) | Out-Null
	}
}.GetNewClosure())

$btnLog.Add_Click({
	$logWindow = New-Object System.Windows.Window
	$logWindow.Title = 'Debug Log Viewer'
	$logWindow.Width = 800
	$logWindow.Height = 600
	$logWindow.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
	$logWindow.Owner = $window
	$logWindow.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(240, 240, 240))
	$logWindow.ToolTip = 'Debug log viewer showing application trace messages.'

	$mainGrid = New-Object System.Windows.Controls.Grid
	$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = '*'}))
	$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = 'Auto'}))

	$txtLog = New-Object System.Windows.Controls.TextBox
	$txtLog.IsReadOnly = $true
	$txtLog.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
	$txtLog.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
	$txtLog.FontFamily = New-Object System.Windows.Media.FontFamily('Courier New')
	$txtLog.FontSize = 11
	$txtLog.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(255, 255, 255))
	$txtLog.Text = [string]::Join("`r`n", $script:debugLog)
	$txtLog.ToolTip = 'Debug log messages with timestamps. Use zoom buttons to adjust font size.'
	[System.Windows.Controls.Grid]::SetRow($txtLog, 0)
	$mainGrid.Children.Add($txtLog) | Out-Null

	$buttonGrid = New-Object System.Windows.Controls.Grid
	# Column layout: Zoom- | Zoom+ | Font | Clear | Export | Format | Spacer | Copy | Close
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'})) # 0: Zoom Out
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'})) # 1: Zoom In
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'})) # 2: Font Size
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'})) # 3: Clear
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'})) # 4: Export
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'})) # 5: Format Combo
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = '*'}))    # 6: Spacer
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'})) # 7: Copy
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'})) # 8: Close
	$buttonGrid.Margin = New-Object System.Windows.Thickness(8)
	$buttonGrid.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(250, 250, 250))
	[System.Windows.Controls.Grid]::SetRow($buttonGrid, 1)
	$mainGrid.Children.Add($buttonGrid) | Out-Null

	# Zoom Out Button
	$btnZoomOutLog = New-Object System.Windows.Controls.Button
	$btnZoomOutLog.Content = '-'
	$btnZoomOutLog.Width = 30
	$btnZoomOutLog.Height = 28
	$btnZoomOutLog.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
	$btnZoomOutLog.ToolTip = 'Zoom out (decrease font size).'
	[System.Windows.Controls.Grid]::SetColumn($btnZoomOutLog, 0)
	$buttonGrid.Children.Add($btnZoomOutLog) | Out-Null

	# Zoom In Button
	$btnZoomInLog = New-Object System.Windows.Controls.Button
	$btnZoomInLog.Content = '+'
	$btnZoomInLog.Width = 30
	$btnZoomInLog.Height = 28
	$btnZoomInLog.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
	$btnZoomInLog.ToolTip = 'Zoom in (increase font size).'
	[System.Windows.Controls.Grid]::SetColumn($btnZoomInLog, 1)
	$buttonGrid.Children.Add($btnZoomInLog) | Out-Null

	# Font Size Label
	$txtLogFontSize = New-Object System.Windows.Controls.TextBlock
	$txtLogFontSize.Text = 'Font: 11.0'
	$txtLogFontSize.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
	$txtLogFontSize.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(36, 65, 95))
	$txtLogFontSize.FontWeight = [System.Windows.FontWeights]::SemiBold
	$txtLogFontSize.Margin = New-Object System.Windows.Thickness(0, 0, 16, 0)
	$txtLogFontSize.ToolTip = 'Current font size for debug log text.'
	[System.Windows.Controls.Grid]::SetColumn($txtLogFontSize, 2)
	$buttonGrid.Children.Add($txtLogFontSize) | Out-Null

	# Zoom handlers - load from settings
	$settings = Read-TrackSessionsSettings -Path $SettingsPath
	$logZoomLevel = if ($settings.ZoomLevels -and (Test-IsFiniteDouble -Value $settings.ZoomLevels.LogViewer)) {
		[Math]::Max(0.70, [Math]::Min(6.00, [double]$settings.ZoomLevels.LogViewer))
	} else {
		1.0
	}

	$applyLogZoom = {
		param([double]$Zoom)
		$zoomClamped = [Math]::Max(0.70, [Math]::Min(6.00, $Zoom))
		$script:logZoomLevel = [Math]::Round($zoomClamped, 2)
		$fontSize = [Math]::Round(11.0 * $script:logZoomLevel, 1)
		$txtLog.FontSize = $fontSize
		$txtLogFontSize.Text = "Font: $fontSize"

		# Save zoom level to settings
		try {
			$currentSettings = Read-TrackSessionsSettings -Path $SettingsPath
			$currentSettings.ZoomLevels.LogViewer = $script:logZoomLevel
			Save-TrackSessionsSettings -Path $SettingsPath -Settings $currentSettings
		}
		catch {
			# Silently ignore save errors
		}
	}
	& $applyLogZoom -Zoom $logZoomLevel

	$btnZoomOutLog.Add_Click({
		& $applyLogZoom -Zoom ($script:logZoomLevel - 0.10)
	}.GetNewClosure())

	$btnZoomInLog.Add_Click({
		& $applyLogZoom -Zoom ($script:logZoomLevel + 0.10)
	}.GetNewClosure())

	# Clear Button
	$btnClear = New-Object System.Windows.Controls.Button
	$btnClear.Content = 'Clear Log'
	$btnClear.Width = 100
	$btnClear.Height = 28
	$btnClear.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
	$btnClear.ToolTip = 'Clear all debug log messages.'
	[System.Windows.Controls.Grid]::SetColumn($btnClear, 3)
	$btnClear.Add_Click({
		$script:debugLog = @()
		$txtLog.Text = ''
		Add-DebugLog -Message 'Debug log cleared'
		$txtLog.Text = [string]::Join("`r`n", $script:debugLog)
	}.GetNewClosure())
	$buttonGrid.Children.Add($btnClear) | Out-Null

	# Export Button
	$btnExport = New-Object System.Windows.Controls.Button
	$btnExport.Content = 'Export'
	$btnExport.Width = 100
	$btnExport.Height = 28
	$btnExport.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
	$btnExport.ToolTip = 'Export debug log to file in selected format.'
	[System.Windows.Controls.Grid]::SetColumn($btnExport, 4)
	$btnExport.Add_Click({
		try {
			# Get script base name
			$scriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

			# Create timestamp
			$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'

			# Determine file extension based on format
			$format = $cmbExportFormat.SelectedItem.ToString()
			$extension = if ($format -eq 'Markdown') { '.md' } else { '.txt' }

			# Build filename
			$filename = "{0}_DebugLog_{1}{2}" -f $scriptBaseName, $timestamp, $extension

			# Create Logs subfolder if it doesn't exist
			$logsFolder = Join-Path $PSScriptRoot 'Logs'
			if (-not (Test-Path -LiteralPath $logsFolder)) {
				New-Item -Path $logsFolder -ItemType Directory -Force | Out-Null
			}

			# Full path
			$exportPath = Join-Path $logsFolder $filename

			# Build content based on format
			if ($format -eq 'Markdown') {
				$content = "# Debug Log - $scriptBaseName`n"
				$content += "`n**Exported:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
				$content += "---`n`n"
				$content += "``````text`n"
				$content += [string]::Join("`n", $script:debugLog)
				$content += "`n``````"
			}
			else {
				$content = "Debug Log - $scriptBaseName"
				$content += "`nExported: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
				$content += "`n" + ('-' * 80) + "`n`n"
				$content += [string]::Join("`n", $script:debugLog)
			}

			# Write to file
			$content | Out-File -FilePath $exportPath -Encoding UTF8 -Force

			# Log success
			Add-DebugLog -Message "Log exported to: $exportPath"
			$txtLog.Text = [string]::Join("`r`n", $script:debugLog)

			# Show success message
			[System.Windows.MessageBox]::Show("Log exported successfully!`n`nFile: $filename`nLocation: $logsFolder", 'Export Complete', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
		}
		catch {
			[System.Windows.MessageBox]::Show("Failed to export log:`n`n$($_.Exception.Message)", 'Export Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
		}
	}.GetNewClosure())
	$buttonGrid.Children.Add($btnExport) | Out-Null

	# Export Format ComboBox (to right of Export button)
	$cmbExportFormat = New-Object System.Windows.Controls.ComboBox
	$cmbExportFormat.Width = 100
	$cmbExportFormat.Height = 28
	$cmbExportFormat.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
	$cmbExportFormat.ToolTip = 'Select export format for log file.'
	$cmbExportFormat.Items.Add('Markdown') | Out-Null
	$cmbExportFormat.Items.Add('Text') | Out-Null
	$cmbExportFormat.SelectedIndex = 0
	[System.Windows.Controls.Grid]::SetColumn($cmbExportFormat, 5)
	$buttonGrid.Children.Add($cmbExportFormat) | Out-Null

	# Copy Button
	$btnCopy = New-Object System.Windows.Controls.Button
	$btnCopy.Content = 'Copy'
	$btnCopy.Width = 100
	$btnCopy.Height = 28
	$btnCopy.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
	$btnCopy.ToolTip = 'Copy all debug log text to clipboard.'
	[System.Windows.Controls.Grid]::SetColumn($btnCopy, 7)
	$btnCopy.Add_Click({
		[System.Windows.Forms.Clipboard]::SetText($txtLog.Text)
		Add-DebugLog -Message 'Debug log copied to clipboard'
		$txtLog.Text = [string]::Join("`r`n", $script:debugLog)
	}.GetNewClosure())
	$buttonGrid.Children.Add($btnCopy) | Out-Null

	# Close Button
	$btnCloseLog = New-Object System.Windows.Controls.Button
	$btnCloseLog.Content = 'Close'
	$btnCloseLog.Width = 100
	$btnCloseLog.Height = 28
	$btnCloseLog.ToolTip = 'Close this debug log window.'
	[System.Windows.Controls.Grid]::SetColumn($btnCloseLog, 8)
	$btnCloseLog.Add_Click({
		$logWindow.Close()
	}.GetNewClosure())
	$buttonGrid.Children.Add($btnCloseLog) | Out-Null

	$logWindow.Content = $mainGrid
	$logWindow.ShowDialog() | Out-Null
}.GetNewClosure())

$btnManageUsers.Add_Click({
	$usersFilePath = Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Users.json'
	if (Test-Path -LiteralPath $usersFilePath) {
		& "$PSScriptRoot\TrackSessions.UserEditor2.ps1"
	}
	else {
		[System.Windows.MessageBox]::Show('Users file not found at: ' + $usersFilePath, 'Users File Not Found', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
	}
}.GetNewClosure())

$btnReservations.Add_Click({
	try {
		$refreshTimerWasEnabled = ($null -ne $timer -and $timer.IsEnabled)
		if ($refreshTimerWasEnabled) {
			$timer.Stop()
		}

		$dialogCandidates = @(
			(Join-Path $PSScriptRoot 'TrackSessions.Reservations.CalendarDialog2.ps1')
			(Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Reservations.CalendarDialog2.ps1')
		) | Select-Object -Unique

		$reservationDialogPath = $dialogCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
		
		# Load settings
		if (-not (Test-Path -LiteralPath $SettingsPath)) {
			[System.Windows.MessageBox]::Show('Settings file not found: ' + $SettingsPath, 'Settings Not Found', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
			return
		}

		$settingsObj = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
		
		# Get ReservationPath - create from template if missing
		$resPath = $null
		if ($settingsObj.Tracking) {
			# Safely access ReservationPath property using PSObject
			if ($settingsObj.Tracking.PSObject.Properties.Name -contains 'ReservationPath') {
				$resPath = $settingsObj.Tracking.ReservationPath
			}
		}
		
		# If not set, use default
		if (-not $resPath -or $resPath -eq '') {
			$resPath = Join-Path $script:effectiveOutputFolder 'Reservations'
		}
		
		# Ensure reservation path exists
		if (-not (Test-Path -LiteralPath $resPath)) {
			New-Item -ItemType Directory -Path $resPath -Force | Out-Null
		}
		
		# Get Users path
		$usersPath = Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Users.json'
		if (-not (Test-Path -LiteralPath $usersPath)) {
			[System.Windows.MessageBox]::Show('Users file not found: ' + $usersPath, 'File Not Found', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
			return
		}
		
		# Check if CalendarDialog exists
		if (-not (Test-Path -LiteralPath $reservationDialogPath)) {
			[System.Windows.MessageBox]::Show('Reservation Calendar Dialog not found.`n`nPath: ' + $reservationDialogPath, 'Dialog Not Found', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
			return
		}
		
		# Launch the calendar dialog. If a legacy version requires JsonPath, retry with a resolved value.
		$jsonPathForDialog = [string]$script:currentJsonFilePath
		if ([string]::IsNullOrWhiteSpace($jsonPathForDialog)) {
			$jsonPathForDialog = Join-Path -Path $script:effectiveOutputFolder -ChildPath $jsonFileName
		}
		if ([string]::IsNullOrWhiteSpace($jsonPathForDialog)) {
			throw 'Unable to launch Reservations because JsonPath could not be resolved.'
		}

		$invokeSplat = @{
			SettingsPath = $SettingsPath
			ReservationPath = $resPath
			UsersPath = $usersPath
		}
		$supportsJsonPath = $false
		try {
			$dialogCommandInfo = Get-Command -LiteralPath $reservationDialogPath -ErrorAction Stop
			if ($null -ne $dialogCommandInfo -and $null -ne $dialogCommandInfo.Parameters) {
				$supportsJsonPath = $dialogCommandInfo.Parameters.ContainsKey('JsonPath')
			}
		}
		catch {
			$supportsJsonPath = $false
		}

		try {
			& $reservationDialogPath @invokeSplat
		}
		catch [System.Management.Automation.ParameterBindingException] {
			if (-not $supportsJsonPath) {
				throw
			}

			if ($_.Exception.Message -notmatch 'Cannot bind argument to parameter\s+''?JsonPath''?|Missing an argument for parameter\s+''?JsonPath''?') {
				throw
			}

			$invokeSplat.JsonPath = $jsonPathForDialog
			& $reservationDialogPath @invokeSplat
		}
	}
	catch {
		[System.Windows.MessageBox]::Show('Error launching Reservations: ' + $_.Exception.Message, 'Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
	}
	finally {
		if ($refreshTimerWasEnabled -and $null -ne $timer -and -not $timer.IsEnabled) {
			$timer.Start()
		}
	}
}.GetNewClosure())


# Splash drag functionality
$script:splashDragStart = $null
if ($null -ne $splashBorder) {
	$splashBorder.Add_MouseLeftButtonDown({
		param($sender, $e)
		$script:splashDragStart = $e.GetPosition($window)
		$splashBorder.CaptureMouse()
	}.GetNewClosure())

	$splashBorder.Add_MouseLeftButtonUp({
		if ($null -ne $script:splashDragStart) {
			$splashBorder.ReleaseMouseCapture()
			$script:splashDragStart = $null

			# Save position after drag
			$left = [System.Windows.Controls.Canvas]::GetLeft($splashBorder)
			$top = [System.Windows.Controls.Canvas]::GetTop($splashBorder)
			try {
				$settings = Read-TrackSessionsSettings -Path $SettingsPath
				$settings.Layout.SplashLeft = $left
				$settings.Layout.SplashTop = $top
				Save-TrackSessionsSettings -Path $SettingsPath -Settings $settings
				Add-DebugLog -Message "Saved Splash position: L=$left T=$top"
			}
			catch {
				Add-DebugLog -Message "Failed to save Splash position: $($_.Exception.Message)"
			}
		}
	}.GetNewClosure())

	$splashBorder.Add_MouseMove({
		param($sender, $e)
		if ($null -ne $script:splashDragStart -and $e.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
			$currentPos = $e.GetPosition($window)
			$currentLeft = [System.Windows.Controls.Canvas]::GetLeft($splashBorder)
			$currentTop = [System.Windows.Controls.Canvas]::GetTop($splashBorder)

			$deltaX = $currentPos.X - $script:splashDragStart.X
			$deltaY = $currentPos.Y - $script:splashDragStart.Y

			$newLeft = $currentLeft + $deltaX
			$newTop = $currentTop + $deltaY

			# Clamp to window bounds
			$newLeft = [Math]::Max(0, [Math]::Min($newLeft, $window.ActualWidth - $splashBorder.ActualWidth))
			$newTop = [Math]::Max(0, [Math]::Min($newTop, $window.ActualHeight - $splashBorder.ActualHeight))

			[System.Windows.Controls.Canvas]::SetLeft($splashBorder, $newLeft)
			[System.Windows.Controls.Canvas]::SetTop($splashBorder, $newTop)

			$script:splashDragStart = $currentPos
		}
	}.GetNewClosure())
}

$btnCloseStartupOverlay.Add_Click({
	# Save splash position and size before closing
	if ($null -ne $splashBorder) {
		$left = [System.Windows.Controls.Canvas]::GetLeft($splashBorder)
		$top = [System.Windows.Controls.Canvas]::GetTop($splashBorder)
		$width = $splashBorder.ActualWidth
		$height = $splashBorder.ActualHeight

		try {
			$settings = Read-TrackSessionsSettings -Path $SettingsPath
			$settings.Layout.SplashLeft = $left
			$settings.Layout.SplashTop = $top
			$settings.Layout.SplashWidth = $width
			$settings.Layout.SplashHeight = $height
			Save-TrackSessionsSettings -Path $SettingsPath -Settings $settings
			Add-DebugLog -Message "Saved Splash position/size on close: L=$left T=$top W=$width H=$height"
		}
		catch {
			Add-DebugLog -Message "Failed to save Splash position/size: $($_.Exception.Message)"
		}
	}

	$startupOverlay.Visibility = [System.Windows.Visibility]::Collapsed

	# Show "Notify Others" dialog after splash screen closes
	$usersFilePath = Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Users.json'
	if (Test-Path -LiteralPath $usersFilePath) {
		Show-NotifyOthersDialog -OwnerWindow $window -UsersFilePath $usersFilePath
	}
}.GetNewClosure())

$btnMinimize.Add_Click({
	$window.WindowState = [System.Windows.WindowState]::Minimized
}.GetNewClosure())

$btnRestoreMini.Add_Click({
	Restore-MainWindowFromMini
}.GetNewClosure())

$miniRootBorder.Add_MouseLeftButtonDown({
	param($eventSource, $e)
	if ($e.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
		$miniWindow.DragMove()
		Save-MiniWindowPosition -MiniWindow $miniWindow
	}
}.GetNewClosure())

$miniWindow.Add_LocationChanged({
	if ($miniWindow.IsVisible) {
		Save-MiniWindowPosition -MiniWindow $miniWindow
	}
}.GetNewClosure())

$miniWindow.Add_MouseDoubleClick({
	Restore-MainWindowFromMini
}.GetNewClosure())

$miniWindow.Add_Closing({
	param($eventSource, $e)
	if (-not $script:isAppClosing) {
		$e.Cancel = $true
		Save-MiniWindowPosition -MiniWindow $miniWindow
		Restore-MainWindowFromMini
	}
}.GetNewClosure())

$window.Add_StateChanged({
	Add-StartupTrace -Path $SettingsPath -EventName 'Main.StateChanged' -Detail ("State={0}" -f $window.WindowState)
}.GetNewClosure())

$window.Add_ContentRendered({
	$bodyGrid = $window.FindName('BodyGrid')
	if ((Test-IsFiniteDouble -Value $script:bottomPaneHeight) -and $bodyGrid -and $bottomPaneRow) {
		$minimumBottom = [Math]::Max(130, [double]$bottomPaneRow.MinHeight)
		$maximumBottom = [Math]::Max($minimumBottom, $bodyGrid.ActualHeight - 176)
		$restoredBottom = [Math]::Min([Math]::Max($script:bottomPaneHeight, $minimumBottom), $maximumBottom)
		$bottomPaneRow.Height = New-Object System.Windows.GridLength($restoredBottom)
	}
	Update-MinimumLayoutConstraints -MainWindow $window -TopPaneRow $topPaneRow -BottomPaneRow $bottomPaneRow -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles -SampleValueControl $txtSession
	Add-StartupTrace -Path $SettingsPath -EventName 'Main.ContentRendered' -Detail ("State={0}" -f $window.WindowState)

	# PERFORMANCE FIX: Non-blocking background load with status updates
	try {
		Add-DebugLog -Message "ContentRendered: Starting background jobs"
		if ($txtStatusDateTime) { $txtStatusDateTime.Text = 'Loading user context...' }

		# Start background job for user context (LDAP lookup - non-blocking)
		$script:userContextJob = Start-BackgroundUserContextJob -TimeoutSeconds 3

		# Start background job for session data (file enumeration - non-blocking)
		Add-DebugLog -Message "ContentRendered: Starting session load job for folder: $script:effectiveOutputFolder"
		$script:sessionLoadJob = Start-BackgroundSessionLoadJob -SessionFolderPath $script:effectiveOutputFolder -TimeoutSeconds 10

		# Create timer to poll job completion (non-blocking UI)
		$script:pollTimer = New-Object System.Windows.Threading.DispatcherTimer
		$script:pollTimer.Interval = [TimeSpan]::FromMilliseconds(100)

		$script:pollTimer.Add_Tick({
			param($timerSender, $timerArgs)

			# Capture outer scope variables (for timer callback)
			$localUserContext = $userContext
			$localTxtDisplayName = $txtDisplayName
			$localTxtUserEmail = $txtUserEmail
			$localTxtStatusDateTime = $txtStatusDateTime
			$localGridSessionFiles = $gridSessionFiles
			$localMachineName = $machineName
			$localTxtJsonFile = $txtJsonFile
			$localTxtFolder = $txtFolder

			# Check user context job
			if ($script:userContextJob -and $script:userContextJob.State -eq 'Completed' -and -not $script:BackgroundLoadingState.UserContextLoaded) {
				$result = Receive-Job -Job $script:userContextJob
				Remove-Job -Job $script:userContextJob -Force

				if ($result -and $result.Success) {
					# Update the global $userContext with LDAP info
					$localUserContext.UserId = $result.UserId
					$localUserContext.SamAccountName = $result.SamAccountName
					$localUserContext.Email = $result.Email
					$localUserContext.DisplayName = $result.DisplayName

					$script:BackgroundLoadingState.UserContext = $localUserContext

					# Update UI with resolved display name
					if ($localTxtDisplayName) { $localTxtDisplayName.Text = $result.DisplayName }
					if ($localTxtUserEmail) { $localTxtUserEmail.Text = $result.Email }

					Add-DebugLog -Message "ContentRendered: User context loaded (DisplayName: $($result.DisplayName))"
				}
				else {
					# LDAP timeout - keep fast fallback values
					$script:BackgroundLoadingState.UserContext = $localUserContext
					Add-DebugLog -Message "ContentRendered: User context timed out, using fallback"
				}

				$script:BackgroundLoadingState.UserContextLoaded = $true
				if ($localTxtStatusDateTime) { $localTxtStatusDateTime.Text = 'Loading sessions...' }
			}

			# Check session load job
			if ($script:sessionLoadJob -and $script:sessionLoadJob.State -eq 'Completed' -and -not $script:BackgroundLoadingState.SessionsLoaded) {
				$sessionResult = Receive-Job -Job $script:sessionLoadJob
				Remove-Job -Job $script:sessionLoadJob -Force

				if ($sessionResult -and $sessionResult.Success) {
					$script:BackgroundLoadingState.SessionData = $sessionResult.Files
					Add-DebugLog -Message "ContentRendered: Session data loaded ($($sessionResult.Files.Count) files)"
					if ($sessionResult.Files.Count -gt 0) {
						Add-DebugLog -Message "  -> First file: $($sessionResult.Files[0].FileName)"
					}
				}
				else {
					$script:BackgroundLoadingState.SessionData = @()
					Add-DebugLog -Message "ContentRendered: Session load FAILED - Error: $($sessionResult.Error)"
				}

				$script:BackgroundLoadingState.SessionsLoaded = $true
			}

			# Both jobs complete - update UI and stop timer
			if ($script:BackgroundLoadingState.UserContextLoaded -and $script:BackgroundLoadingState.SessionsLoaded) {
				$timerSender.Stop()

				# MINIMAL CHANGE: Just call the ORIGINAL working refreshAction
				try {
					Add-DebugLog -Message "ContentRendered: Background jobs complete, calling original refreshAction"
					& $refreshAction
					$script:BackgroundLoadingState.LoadingInProgress = $false
					Add-DebugLog -Message "ContentRendered: Initial load complete"
				}
				catch {
					if ($txtStatusDateTime) { $txtStatusDateTime.Text = "Error: $($_.Exception.Message)" }
					Add-DebugLog -Message "ContentRendered: ERROR updating UI: $($_.Exception.Message)"
				}
			}

			# Timeout after 10 seconds total
			if ($script:pollTimer.Tag -and (Get-Date) -gt $script:pollTimer.Tag) {
				$timerSender.Stop()

				# Stop any remaining jobs
				if ($script:userContextJob -and $script:userContextJob.State -eq 'Running') {
					Stop-Job -Job $script:userContextJob -ErrorAction SilentlyContinue
					Remove-Job -Job $script:userContextJob -Force -ErrorAction SilentlyContinue
					Add-DebugLog -Message "ContentRendered: User context job timed out"
				}
				if ($script:sessionLoadJob -and $script:sessionLoadJob.State -eq 'Running') {
					Stop-Job -Job $script:sessionLoadJob -ErrorAction SilentlyContinue
					Remove-Job -Job $script:sessionLoadJob -Force -ErrorAction SilentlyContinue
					Add-DebugLog -Message "ContentRendered: Session load job timed out"
				}

				if ($txtStatusDateTime) { $txtStatusDateTime.Text = 'Ready (some operations timed out)' }
				$script:BackgroundLoadingState.LoadingInProgress = $false
			}
		}.GetNewClosure())

		# Store timeout deadline in Tag
		$script:pollTimer.Tag = (Get-Date).AddSeconds(10)
		$script:pollTimer.Start()
		Add-DebugLog -Message "ContentRendered: Background jobs started, polling for completion"
	}
	catch {
		if ($txtStatusDateTime) { $txtStatusDateTime.Text = "Error: $($_.Exception.Message)" }
		Add-DebugLog -Message "ContentRendered: ERROR: $($_.Exception.Message)"
	}
}.GetNewClosure())

$window.Add_Loaded({
	Add-StartupTrace -Path $SettingsPath -EventName 'Main.Loaded' -Detail ("State={0}" -f $window.WindowState)

	# Position and size the splash overlay
	if ($null -ne $splashBorder) {
		# Apply saved size if available
		if ((Test-IsFiniteDouble -Value $script:splashWidth) -and $script:splashWidth -ge 500) {
			$splashBorder.Width = $script:splashWidth
		}
		if ((Test-IsFiniteDouble -Value $script:splashHeight) -and $script:splashHeight -ge 300) {
			$splashBorder.Height = $script:splashHeight
		}

		# Calculate center position if no saved position
		$left = 0
		$top = 0
		if ((Test-IsFiniteDouble -Value $script:splashLeft) -and (Test-IsFiniteDouble -Value $script:splashTop)) {
			$left = $script:splashLeft
			$top = $script:splashTop
		}
		else {
			# Center the splash in the window
			$left = ($window.ActualWidth - $splashBorder.Width) / 2
			$top = ($window.ActualHeight - $splashBorder.Height) / 2
		}

		# Clamp to window bounds
		$left = [Math]::Max(0, [Math]::Min($left, $window.ActualWidth - $splashBorder.Width))
		$top = [Math]::Max(0, [Math]::Min($top, $window.ActualHeight - $splashBorder.Height))

		[System.Windows.Controls.Canvas]::SetLeft($splashBorder, $left)
		[System.Windows.Controls.Canvas]::SetTop($splashBorder, $top)

		Add-DebugLog -Message "Splash positioned at L=$left T=$top W=$($splashBorder.Width) H=$($splashBorder.Height)"
	}
}.GetNewClosure())

$window.Add_SourceInitialized({
	Add-StartupTrace -Path $SettingsPath -EventName 'Main.SourceInitialized' -Detail ''
}.GetNewClosure())


($window.FindName('MainRowSplitter')).Add_DragCompleted({
	if ($bottomPaneRow -and $bottomPaneRow.Height.GridUnitType -eq [System.Windows.GridUnitType]::Pixel) {
		Save-SplitterPosition -BottomRow $bottomPaneRow -Height $bottomPaneRow.Height.Value
	}
	Update-MinimumLayoutConstraints -MainWindow $window -TopPaneRow $topPaneRow -BottomPaneRow $bottomPaneRow -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles -SampleValueControl $txtSession
}.GetNewClosure())

$btnCloseAfterSession.Add_Click({
	$script:isAppClosing = $true
	Add-StartupTrace -Path $SettingsPath -EventName 'CloseAfterSession.Clicked' -Detail ''
	if ($simulationTimer.IsEnabled) {
		$simulationTimer.Stop()
	}
	& $refreshAction
	Write-SessionCloseArtifacts -CurrentJsonPath $script:currentJsonFilePath -SessionName $sessionName -SessionId $sessionId -MachineName $machineName -UserContext $userContext
	if ($miniWindow.IsVisible) {
		Save-MiniWindowPosition -MiniWindow $miniWindow
	}
	if ($miniWindow.IsVisible) {
		$miniWindow.Close()
	}
	$window.Close()
}.GetNewClosure())

$window.Add_SizeChanged({
	Set-ResponsiveInfoLayout -WindowWidth $window.ActualWidth -Labels $labelControls -Values $valueControls -LabelColumn $lblCol -ValueColumn $valCol
	Update-MinimumLayoutConstraints -MainWindow $window -TopPaneRow $topPaneRow -BottomPaneRow $bottomPaneRow -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles -SampleValueControl $txtSession
}.GetNewClosure())

Set-ResponsiveInfoLayout -WindowWidth $window.ActualWidth -Labels $labelControls -Values $valueControls -LabelColumn $lblCol -ValueColumn $valCol
Set-MainContentZoom -ZoomLevel $script:mainZoomLevel -Labels $labelControls -Values $valueControls -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles
Update-MinimumLayoutConstraints -MainWindow $window -TopPaneRow $topPaneRow -BottomPaneRow $bottomPaneRow -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles -SampleValueControl $txtSession

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMinutes(3)
$timer.Add_Tick({
	# PERFORMANCE FIX: Non-blocking refresh using background jobs
	try {
		# Don't refresh if background loading still in progress
		if ($script:BackgroundLoadingState.LoadingInProgress) {
			Add-DebugLog -Message "Refresh timer: Skipping refresh (background load in progress)"
			return
		}

		Add-DebugLog -Message "Refresh timer: Starting background session refresh"
		if ($txtStatusDateTime) { $txtStatusDateTime.Text = 'Refreshing...' }

		# Update current session snapshot first (fast, synchronous)
		Write-SessionSnapshot -CreatedAt $createdAtGmt -JsonPath $script:currentJsonFilePath -MachineName $machineName -SessionId $sessionId -SessionName $sessionName -UserContext $userContext
		if ($txtLastUpdated) { $txtLastUpdated.Text = [DateTime]::UtcNow.ToString('o') }

		# Start background refresh job (non-blocking)
		$script:refreshJob = Start-BackgroundSessionLoadJob -SessionFolderPath $script:effectiveOutputFolder -TimeoutSeconds 10

		# Poll for completion
		$script:refreshPollTimer = New-Object System.Windows.Threading.DispatcherTimer
		$script:refreshPollTimer.Interval = [TimeSpan]::FromMilliseconds(200)

		$script:refreshPollTimer.Add_Tick({
			param($timerSender, $timerArgs)

			if ($script:refreshJob -and $script:refreshJob.State -eq 'Completed') {
				$timerSender.Stop()

				$sessionResult = Receive-Job -Job $script:refreshJob
				Remove-Job -Job $script:refreshJob -Force

				if ($sessionResult -and $sessionResult.Success) {
					$script:BackgroundLoadingState.SessionData = $sessionResult.Files
					Add-DebugLog -Message "Refresh timer: Session data loaded, calling original refreshAction"
					# MINIMAL CHANGE: Call ORIGINAL working refreshAction
					& $refreshAction
					Add-DebugLog -Message "Refresh timer: Background refresh complete"
				}
				else {
					if ($txtStatusDateTime) { $txtStatusDateTime.Text = 'Ready (refresh failed)' }
					Add-DebugLog -Message "Refresh timer: Refresh error: $($sessionResult.Error)"
				}
			}

			# Timeout after 15 seconds
			if ($script:refreshPollTimer.Tag -and (Get-Date) -gt $script:refreshPollTimer.Tag) {
				$timerSender.Stop()
				if ($script:refreshJob -and $script:refreshJob.State -eq 'Running') {
					Stop-Job -Job $script:refreshJob -ErrorAction SilentlyContinue
					Remove-Job -Job $script:refreshJob -Force -ErrorAction SilentlyContinue
				}
				if ($txtStatusDateTime) { $txtStatusDateTime.Text = 'Ready (refresh timed out)' }
				Add-DebugLog -Message "Refresh timer: Background refresh timed out"
			}
		}.GetNewClosure())

		$script:refreshPollTimer.Tag = (Get-Date).AddSeconds(15)
		$script:refreshPollTimer.Start()
	}
	catch {
		if ($txtStatusDateTime) { $txtStatusDateTime.Text = "Error: $($_.Exception.Message)" }
		Add-DebugLog -Message "Refresh timer ERROR: $($_.Exception.Message)"
	}
}.GetNewClosure())
$timer.Start()

$statusTimer = New-Object System.Windows.Threading.DispatcherTimer
$statusTimer.Interval = [TimeSpan]::FromSeconds(1)
$statusTimer.Add_Tick({
	Update-StatusBar
}.GetNewClosure())
$statusTimer.Start()

$iconTimer = New-Object System.Windows.Threading.DispatcherTimer
$iconTimer.Interval = [TimeSpan]::FromMilliseconds(240)
$iconTimer.Add_Tick({
	try {
		if ($script:iconFrameIndex -ne $null) {
			$script:iconFrameIndex = ($script:iconFrameIndex + 1) % $iconFrames.Count
			if ($window -and $miniWindow) {
				$window.Icon = $iconFrames[$script:iconFrameIndex]
				$miniWindow.Icon = $iconFrames[$script:iconFrameIndex]
				$imgAnimatedIcon.Source = $headerFrames[$script:iconFrameIndex]
				$imgMiniIcon.Source = $headerFrames[$script:iconFrameIndex]
				$imgRestoreIcon.Source = $headerFrames[$script:iconFrameIndex]
			}
		}
	}
	catch {
		# Silently ignore errors when UI elements are not accessible
		# (e.g., during modal dialog display)
	}
}.GetNewClosure())
$iconTimer.Start()

# PERFORMANCE FIX: Removed redundant 60-second grid refresh timer
# The main 3-minute timer already handles periodic refreshes
# FileSystemWatcher (when enabled) will provide real-time updates
# Keeping this timer would cause 3 refreshes during each main timer cycle (wasted work)
# $gridRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
# $gridRefreshTimer.Interval = [TimeSpan]::FromSeconds(60)
# $gridRefreshTimer.Add_Tick({
# 	try {
# 		Add-DebugLog -Message "Grid refresh timer fired - updating grid data"
# 		Update-SessionGridData
# 	}
# 	catch {
# 		Add-DebugLog -Message "ERROR in grid refresh timer: $($_)"
# 	}
# })
# $gridRefreshTimer.Start()

# TEMPORARILY DISABLED: FileSystemWatcher causing crash - disable for testing
<#
$script:lastFileWatcherTime = [System.Diagnostics.Stopwatch]::StartNew()
$fileChangedAction = {
	param($source, $eventArgs)
	# Debounce check - only process if 500ms have passed since last event
	if ($script:lastFileWatcherTime.ElapsedMilliseconds -lt 500) {
		return
	}
	$script:lastFileWatcherTime.Restart()
	
	try {
		$window.Dispatcher.BeginInvoke([Action]{
			try {
				Add-DebugLog -Message "FileSystemWatcher: Change detected in $($eventArgs.Name)"
				Update-SessionGridData
			}
			catch {
				Add-DebugLog -Message "ERROR in file watcher handler: $($_)"
			}
		}, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
	}
	catch {
		Add-DebugLog -Message "ERROR dispatching file watcher event: $($_)"
	}
}

$fileWatcher = New-Object System.IO.FileSystemWatcher
$fileWatcher.Path = $script:effectiveOutputFolder
$fileWatcher.Filter = '*.json'
$fileWatcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
$fileWatcher.IncludeSubdirectories = $false

$fileWatcher.add_Changed($fileChangedAction)
$fileWatcher.add_Created($fileChangedAction)
$fileWatcher.add_Deleted($fileChangedAction)
$fileWatcher.EnableRaisingEvents = $true
#>

# PERFORMANCE FIX: Initial refresh moved to ContentRendered event (line 2690)
# & $refreshAction
Add-StartupTrace -Path $SettingsPath -EventName 'Before.ShowDialog' -Detail 'Entering modal loop'

$window.Add_Closed({
	$script:isAppClosing = $true
	Add-StartupTrace -Path $SettingsPath -EventName 'Main.Closed' -Detail 'Main window closed'
	$bottomPaneRow = $window.FindName('BottomPaneRow')
	if ($bottomPaneRow -and $bottomPaneRow.Height.GridUnitType -eq [System.Windows.GridUnitType]::Pixel) {
		Save-SplitterPosition -BottomRow $bottomPaneRow -Height $bottomPaneRow.Height.Value
	}
	Save-MainWindowBounds -MainWindow $window
	Write-SessionCloseArtifacts -CurrentJsonPath $script:currentJsonFilePath -SessionName $sessionName -SessionId $sessionId -MachineName $machineName -UserContext $userContext
	if ($timer.IsEnabled) {
		$timer.Stop()
	}
	if ($simulationTimer.IsEnabled) {
		$simulationTimer.Stop()
	}
	if ($iconTimer.IsEnabled) {
		$iconTimer.Stop()
	}
	if ($statusTimer.IsEnabled) {
		$statusTimer.Stop()
	}
	# PERFORMANCE FIX: gridRefreshTimer removed (see line 2764)
	# if ($gridRefreshTimer.IsEnabled) {
	# 	$gridRefreshTimer.Stop()
	# }
	if ($null -ne $fileWatcher) {
		$fileWatcher.EnableRaisingEvents = $false
		$fileWatcher.Dispose()
	}
	if ($miniWindow.IsVisible) {
		Save-MiniWindowPosition -MiniWindow $miniWindow
		$miniWindow.Close()
	}
}.GetNewClosure())

# RESTORE: Initial refresh call BEFORE window shows (like working version)
& $refreshAction
Add-StartupTrace -Path $SettingsPath -EventName 'Before.ShowDialog' -Detail 'Initial refresh complete'

[void]$window.ShowDialog()
