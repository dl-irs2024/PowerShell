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

<#
╔═══════════════════════════════════════════════════════════════════════════════╗
║                   TRACKSESSIONS CR3 - FUNCTION REFERENCE MAP                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝

ARCHITECTURE NOTES:
  • Single-file execution model with external XAML files (no modules - avoids scope issues)
  • XAML files loaded via Load-XamlFromFile() with XamlReader.Load()
  • Event handlers wired using .Add_Click(), .Add_SizeChanged(), etc. scriptblock patterns
  • All event handlers include .GetNewClosure() for proper outer scope capture
  • Script-level variables ($script:debugLog, $script:usersList, etc.) initialized early (line ~1041)

FUNCTION ORGANIZATION BY CATEGORY:
─────────────────────────────────────────────────────────────────────────────

[IDENTITY & USER CONTEXT] (Lines 65-415)
  • Get-UserDisplayName (65)                      - Resolves user display name from registry
  • Convert-ToSafeFileToken (103)                 - Makes strings safe for file names
  • Start-BackgroundUserContextJob (116)          - Background job for user context discovery
  • Wait-BackgroundJobWithTimeout (216)           - Waits for background job with timeout
  • Get-CurrentUserContext (300)                  - Gets current user context (name, SID, domain)
  • Get-CurrentSessionName (365)                  - Derives session name from context
  • Test-IsCurrentUserAdmin (386)                 - Checks admin privileges

[SESSION TRACKING] (Lines 467-958)
  • Register-TrackSessionsLogonTask (467)         - Registers scheduled task for logon events
  • Get-DefaultTrackedMachines (517)              - Returns default machine list for tracking
  • Write-SessionSnapshot (763)                   - Writes session data to JSON snapshot
  • Write-SessionCloseArtifacts (792)             - Writes session close artifacts
  • Get-SessionGridRows (836)                     - Formats session data for grid display
  • Get-SessionStatusFromSnapshot (958)           - Derives session status from snapshot

[SETTINGS & CONFIGURATION] (Lines 525-1516)
  • Read-TrackSessionsSettings (525)              - Reads TrackSessions.Settings.json file
  • Save-TrackSessionsSettings (661)              - Saves settings to JSON file
  • Add-StartupTrace (675)                        - Adds startup diagnostic trace entries
  • Test-IsFiniteDouble (719)                     - Validates numeric values
  • Resolve-TrackingConfiguration (1462)          - Resolves configuration from settings
  • Convert-TrackingSettingsToPsObjectText (1426) - Converts settings to PowerShell text
  • Convert-MainViewToPsObjectText (1516)         - Converts main view state to PowerShell text
  • Convert-ToSingleQuotedPsString (1420)         - Escapes strings for PowerShell output

[XAML & UI LOADING] (Lines 1024-1055)
  • Load-XamlFromFile (1024)                      - Loads external XAML from file using XamlReader
  • XAML FILES (External):
    - TrackSessions.MainWindow.xaml               - Main UI (grid, info pane, buttons)
    - TrackSessions.MiniWindow.xaml               - Minimized compact panel
    - TrackSessions.SettingsDialog.xaml           - Settings configuration dialog

[CACHING & DATA MANAGEMENT] (Lines 1138-1302)
  • Add-DebugLog (1138)                           - Adds debug log entry (max 500 entries)
  • Update-SessionGridDataFromCache (1148)        - Updates grid from cached session data
  • Get-CachedSessionData (1281)                  - Retrieves cached session data
  • Get-CachedUserDisplayName (1302)              - Retrieves cached user display name

[NOTIFICATIONS & UI FEEDBACK] (Lines 1317-1449)
  • Show-WindowsNotification (1317)               - Shows Windows toast notification
  • Save-MiniWindowPosition (1349)                - Saves mini window position to registry
  • Save-SplitterPosition (1362)                  - Saves splitter position to registry
  • Save-MainWindowBounds (1383)                  - Saves main window bounds to registry
  • Copy-TextToClipboard (1449)                   - Copies text to Windows clipboard

[DIALOGS & EVENT-DRIVEN FUNCTIONS] (Lines 1552+)
  • Show-EditSettingsDialog (1552)                - Opens Settings dialog (EVENT-DRIVEN)
    EVENT HANDLERS: BtnBrowseSharedPath, BtnRevealSharedPath, BtnZoomOut/In, BtnCopy, BtnCancel, BtnSave
  
  [MAIN WINDOW EVENT HANDLERS] (Lines 2327-2830)
  • $btnRefresh.Add_Click (2327)                  - Refresh session grid (EVENT)
  • $btnEditSettings.Add_Click (2400)             - Opens Settings dialog (EVENT)
  • $btnLog.Add_Click (2433)                      - Opens Log viewer with debug entries (EVENT)
  • $btnManageUsers.Add_Click (2508)              - Launches UserEditor in separate process (EVENT)
  • $btnReservations.Add_Click (2526)             - Launches Reservations dialog (EVENT)
  • $btnCloseStartupOverlay.Add_Click (2632)      - Hides startup overlay (EVENT)
  • $btnMinimize.Add_Click (2636)                 - Minimizes to mini panel (EVENT)
  • $btnCloseAfterSession.Add_Click (2830)        - Closes app after session ends (EVENT)
  • $window.Add_SizeChanged (2840+)               - Handles window resize events (EVENT)

[LAYOUT & ZOOM] (Lines 1833-2261)
  • Update-StatusBar (1833)                       - Updates status bar with timestamp/machine/user
  • Set-MainContentZoom (2131)                    - Sets zoom level for main content
  • Update-MinimumLayoutConstraints (2159)        - Updates layout constraints for responsive design
  • Update-MainContentZoom (2196)                 - Updates grid/control zoom
  • Set-ResponsiveInfoLayout (2209)               - Adjusts info pane layout for window size
  • Show-MiniSessionPanel (2261)                  - Shows mini panel (EVENT-DRIVEN)
  • Restore-MainWindowFromMini (2313)             - Restores main window from mini (EVENT-DRIVEN)

[SIMULATION & TESTING] (Lines 1845-1960)
  • Get-SimulationInterval (1845)                 - Returns interval for test data generation
  • Get-NextSimulatedState (1850)                 - Generates next simulated session state
  • New-SimulatedStateMachineEvent (1865)         - Creates simulated FSM event
  • New-SimulatedActivityRow (1960)               - Creates simulated activity row
  • Update-SessionGridData (2014)                 - Updates grid with session data (real or simulated)

KEY ODDITIES & SPECIAL PATTERNS:
  • Event Handlers (22 .Add_Click handlers + 1 .Add_SizeChanged) - All use scriptblock .GetNewClosure()
  • UserEditor Invocation (2508) - Runs in separate PowerShell process (not same-scope &) to avoid scope conflicts
  • HTML Injection - FileReport_*.html generated by external scripts (not in CR3)
  • C# Usage - Only standard System.Windows/.NET classes (no custom Add-Type definitions)
  • Background Jobs - User context and session loading run asynchronously (lines 116, 242)
  • Registry Caching - Window position/splitter/bounds stored in registry for persistence
  • Multi-File JSON - Reads TrackSessions.Settings.json and TrackSessions.Users.json

TOTAL FUNCTION COUNT: 46 functions
EVENT-DRIVEN FUNCTIONS: 22+ (all button clicks + window size handler)
EXTERNAL XAML FILES: 3
#>

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

$script:LayoutConstraintTuning = [ordered]@{
	TopVisibleRows = 3
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
			if (Test-Path -LiteralPath $FolderPath) {
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
		[ordered]@{ ShortName = 'PAWS001'; FQDN = ''; Comment = 'Preset PAWS machine' }
		[ordered]@{ ShortName = 'PAWS002'; FQDN = ''; Comment = 'Preset PAWS machine' }
		[ordered]@{ ShortName = 'PAWS003'; FQDN = ''; Comment = 'Preset PAWS machine' }
	)
}

function Read-TrackSessionsSettings {
	param([Parameter(Mandatory = $true)][string]$Path)

	$defaultSettings = [ordered]@{
		SchemaVersion = '1.0'
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
		}
		Tracking = [ordered]@{
			SharedPath = ''
			Machines = @(Get-DefaultTrackedMachines)
		}
		StartupTrace = [ordered]@{
			Enabled = $true
			Events = @()
		}
		Debug = [ordered]@{
			ShowAllSessions = $false
			ShowFilterInLog = $false
			ShowRefreshEvents = $false
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

		$debugShowAllSessions = $false
		if ($loaded.Debug -and $null -ne $loaded.Debug.ShowAllSessions) {
			$debugShowAllSessions = [bool]$loaded.Debug.ShowAllSessions
		}

		$debugShowFilterInLog = $false
		if ($loaded.Debug -and $null -ne $loaded.Debug.ShowFilterInLog) {
			$debugShowFilterInLog = [bool]$loaded.Debug.ShowFilterInLog
		}

		$debugShowRefreshEvents = $false
		if ($loaded.Debug -and $null -ne $loaded.Debug.ShowRefreshEvents) {
			$debugShowRefreshEvents = [bool]$loaded.Debug.ShowRefreshEvents
		}

		return [ordered]@{
			SchemaVersion = '1.0'
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
			}
			Tracking = [ordered]@{
				SharedPath = $sharedPath
				Machines = $machines
			}
			StartupTrace = [ordered]@{
				Enabled = $traceEnabled
				Events = $traceEvents
			}
			Debug = [ordered]@{
				ShowAllSessions = $debugShowAllSessions
				ShowFilterInLog = $debugShowFilterInLog
				ShowRefreshEvents = $debugShowRefreshEvents
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

$script:machineName = $env:COMPUTERNAME
$sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
$sessionName = Get-CurrentSessionName -SamAccountName $userContext.SamAccountName
$createdAtGmt = [DateTime]::UtcNow

$fileMachine = Convert-ToSafeFileToken -Value $script:machineName
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

# ============================================================================
# REGION: XAML LOADERS
# ============================================================================
# Helper function to load XAML from external .xaml files
function Load-XamlFromFile {
	param(
		[Parameter(Mandatory = $true)][string]$XamlFilePath
	)
	
	if (-not (Test-Path $XamlFilePath)) {
		throw "XAML file not found: $XamlFilePath"
	}
	
	$xamlContent = Get-Content $XamlFilePath -Raw
	[xml]$xamlXml = $xamlContent
	$xamlReader = New-Object System.Xml.XmlNodeReader $xamlXml
	return [Windows.Markup.XamlReader]::Load($xamlReader)
}

function Resolve-TrackingConfiguration {
	param(
		[Parameter(Mandatory = $true)]$SettingsData,
		[Parameter(Mandatory = $true)][string]$DefaultOutputFolder,
		[Parameter(Mandatory = $true)][string]$JsonFileName
	)

	$trackedMachines = @()
	$sharedPath = ''

	if ($SettingsData.Tracking -and $SettingsData.Tracking.Machines) {
		$trackedMachines = @($SettingsData.Tracking.Machines)
	}
	if ($SettingsData.Tracking -and $null -ne $SettingsData.Tracking.SharedPath) {
		$sharedPath = [string]$SettingsData.Tracking.SharedPath
	}

	$effectiveFolder = $DefaultOutputFolder
	$folderMode = 'Default'
	if (-not [string]::IsNullOrWhiteSpace($sharedPath)) {
		$candidate = $sharedPath.Trim()
		if ($candidate.StartsWith('\\')) {
			try {
				if (-not (Test-Path -LiteralPath $candidate)) {
					New-Item -Path $candidate -ItemType Directory -Force | Out-Null
				}
				$effectiveFolder = $candidate
				$folderMode = 'Shared UNC'
			}
			catch {
				$effectiveFolder = $DefaultOutputFolder
				$folderMode = 'Default (Shared UNC unavailable)'
			}
		}
	}

	$jsonPath = Join-Path -Path $effectiveFolder -ChildPath $JsonFileName

	return [ordered]@{
		EffectiveFolder = $effectiveFolder
		FolderMode = $folderMode
		TrackedMachines = $trackedMachines
		SharedPath = $sharedPath
		JsonPath = $jsonPath
	}
}

# Initialize script-level variables BEFORE XAML loading to prevent undefined variable errors in event handlers
$script:lastNotificationEntries = @()
$script:debugLog = @()
$script:usersList = @()
$script:sessionCache = @{}
$script:userDisplayNameCache = @{}

# Define Add-DebugLog EARLY so it's available for all startup logging
function Add-DebugLog {
	param([string]$Message)
	$timestamp = [DateTime]::Now.ToString('HH:mm:ss.fff')
	$entry = "[$timestamp] $Message"
	$script:debugLog += $entry
	if ($script:debugLog.Count -gt 500) {
		$script:debugLog = @($script:debugLog | Select-Object -Last 500)
	}
}

# Load main window from TrackSessions.MainWindow.xaml
$xamlPath = Join-Path $PSScriptRoot "TrackSessions.MainWindow.xaml"
$window = Load-XamlFromFile $xamlPath

# All Main Window XAML has been extracted to TrackSessions.MainWindow.xaml
# DO NOT ADD EMBEDDED XAML HERE - use Load-XamlFromFile() instead

# Load mini window from TrackSessions.MiniWindow.xaml
$miniXamlPath = Join-Path $PSScriptRoot "TrackSessions.MiniWindow.xaml"
$miniWindow = Load-XamlFromFile $miniXamlPath

# All Mini Window XAML has been extracted to TrackSessions.MiniWindow.xaml
# DO NOT ADD EMBEDDED XAML HERE - use Load-XamlFromFile() instead

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
$btnCopyMain = $window.FindName('BtnCopyMain')
$btnEditSettings = $window.FindName('BtnEditSettings')
$btnLog = $window.FindName('BtnLog')
$btnManageUsers = $window.FindName('BtnManageUsers')
$btnReservations = $window.FindName('BtnReservations')
$btnMinimize = $window.FindName('BtnMinimize')
$btnCloseAfterSession = $window.FindName('BtnCloseAfterSession')
$startupOverlay = $window.FindName('StartupOverlay')
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

$txtMiniMachine = $miniWindow.FindName('TxtMiniMachine')
$txtMiniUser = $miniWindow.FindName('TxtMiniUser')
$btnRestoreMini = $miniWindow.FindName('BtnRestoreMini')
$imgMiniIcon = $miniWindow.FindName('ImgMiniIcon')
$imgRestoreIcon = $miniWindow.FindName('ImgRestoreIcon')
$miniRootBorder = $miniWindow.FindName('MiniRootBorder')

$settingsData = Read-TrackSessionsSettings -Path $SettingsPath

# Extract debug settings from loaded configuration
$script:debugShowAllSessions = $false
if ($settingsData.Debug -and $null -ne $settingsData.Debug.ShowAllSessions) {
	$script:debugShowAllSessions = [bool]$settingsData.Debug.ShowAllSessions
}
$script:debugShowFilterInLog = $false
if ($settingsData.Debug -and $null -ne $settingsData.Debug.ShowFilterInLog) {
	$script:debugShowFilterInLog = [bool]$settingsData.Debug.ShowFilterInLog
}
$script:debugShowRefreshEvents = $false
if ($settingsData.Debug -and $null -ne $settingsData.Debug.ShowRefreshEvents) {
	$script:debugShowRefreshEvents = [bool]$settingsData.Debug.ShowRefreshEvents
}

# CRITICAL FIX: Use Resolve-TrackingConfiguration to apply UNC path at startup
$trackingRuntime = Resolve-TrackingConfiguration -SettingsData $settingsData -DefaultOutputFolder $OutputFolder -JsonFileName $jsonFileName
$script:effectiveOutputFolder = [string]$trackingRuntime.EffectiveFolder
$script:trackedMachines = @($trackingRuntime.TrackedMachines)
$script:sharedPath = [string]$trackingRuntime.SharedPath
$script:folderMode = [string]$trackingRuntime.FolderMode
$script:currentJsonFilePath = [string]$trackingRuntime.JsonPath

Add-DebugLog -Message "=== APP STARTUP CONFIGURATION ==="
Add-DebugLog -Message "Effective Folder: $($script:effectiveOutputFolder)"
Add-DebugLog -Message "Folder Mode: $($script:folderMode)"
Add-DebugLog -Message "Shared Path: $($script:sharedPath)"
Add-DebugLog -Message "Tracked Machines: $($script:trackedMachines -join ', ')"
Add-DebugLog -Message "=== DEBUG SETTINGS ==="
Add-DebugLog -Message "ShowAllSessions: $($script:debugShowAllSessions)"
Add-DebugLog -Message "ShowFilterInLog: $($script:debugShowFilterInLog)"
Add-DebugLog -Message "ShowRefreshEvents: $($script:debugShowRefreshEvents)"
Add-DebugLog -Message "=== END STARTUP CONFIG ==="

$script:miniWindowLeft = $settingsData.MiniWindow.Left
$script:miniWindowTop = $settingsData.MiniWindow.Top
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

Add-StartupTrace -Path $SettingsPath -EventName 'Script.Start' -Detail ("PID={0};SettingsPath={1}" -f $PID, $SettingsPath)

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
			$resolvedName = Get-CachedUserDisplayName -UserId $row.UserId -UsersList $script:usersList
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

#region ===== SETTINGS APPLICATION (after updates) =====
$trackingRuntime = Resolve-TrackingConfiguration -SettingsData $settingsData -DefaultOutputFolder $OutputFolder -JsonFileName $jsonFileName
$script:effectiveOutputFolder = [string]$trackingRuntime.EffectiveFolder
$script:trackedMachines = @($trackingRuntime.TrackedMachines)
$script:sharedPath = [string]$trackingRuntime.SharedPath
$script:folderMode = [string]$trackingRuntime.FolderMode
$script:currentJsonFilePath = [string]$trackingRuntime.JsonPath

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

	# Load settings dialog from TrackSessions.SettingsDialog.xaml
	$settingsXamlPath = Join-Path $PSScriptRoot "TrackSessions.SettingsDialog.xaml"
	$settingsWindow = Load-XamlFromFile $settingsXamlPath
	$settingsWindow.Owner = $OwnerWindow
	
	# All Settings Dialog XAML has been extracted to TrackSessions.SettingsDialog.xaml
	# DO NOT ADD EMBEDDED XAML HERE - use Load-XamlFromFile() instead

	$txtSharedPathSettings = $settingsWindow.FindName('TxtSharedPath')
	$btnBrowseSharedPath = $settingsWindow.FindName('BtnBrowseSharedPath')
	$btnRevealSharedPath = $settingsWindow.FindName('BtnRevealSharedPath')
	$gridTrackedMachines = $settingsWindow.FindName('GridTrackedMachines')
	$btnZoomOutSettings = $settingsWindow.FindName('BtnZoomOutSettings')
	$btnZoomInSettings = $settingsWindow.FindName('BtnZoomInSettings')
	$btnCopySettings = $settingsWindow.FindName('BtnCopySettings')
	$btnCancelSettings = $settingsWindow.FindName('BtnCancelSettings')
	$btnSaveCloseSettings = $settingsWindow.FindName('BtnSaveCloseSettings')
	$chkShowAllSessions = $settingsWindow.FindName('ChkShowAllSessions')
	$chkShowFilterInLog = $settingsWindow.FindName('ChkShowFilterInLog')
	$chkShowRefreshEvents = $settingsWindow.FindName('ChkShowRefreshEvents')

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

	# Initialize debug checkboxes from settings
	if ($chkShowAllSessions) {
		$chkShowAllSessions.IsChecked = [bool]$settings.Debug.ShowAllSessions
	}
	if ($chkShowFilterInLog) {
		$chkShowFilterInLog.IsChecked = [bool]$settings.Debug.ShowFilterInLog
	}
	if ($chkShowRefreshEvents) {
		$chkShowRefreshEvents.IsChecked = [bool]$settings.Debug.ShowRefreshEvents
	}

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
	})

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
	})

	$settingsZoomLevel = 1.0
	$applySettingsGridZoom = {
		param([double]$Zoom)
		$zoomClamped = [Math]::Max(0.80, [Math]::Min(1.80, $Zoom))
		$settingsZoomLevel = [Math]::Round($zoomClamped, 2)
		$gridTrackedMachines.FontSize = [Math]::Round(11.0 * $settingsZoomLevel, 1)
		$gridTrackedMachines.ColumnHeaderHeight = [Math]::Round(26.0 * $settingsZoomLevel, 0)
		$gridTrackedMachines.RowHeight = [Math]::Round(24.0 * $settingsZoomLevel, 0)
	}
	& $applySettingsGridZoom -Zoom $settingsZoomLevel

	$btnZoomOutSettings.Add_Click({
		& $applySettingsGridZoom -Zoom ($settingsZoomLevel - 0.10)
	})

	$btnZoomInSettings.Add_Click({
		& $applySettingsGridZoom -Zoom ($settingsZoomLevel + 0.10)
	})

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
	})

	$btnCancelSettings.Add_Click({
		$settingsWindow.DialogResult = $false
		$settingsWindow.Close()
	})

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

			# Save Debug settings
			if (-not $settingsToSave.Debug) {
				$settingsToSave.Debug = [ordered]@{ ShowAllSessions = $false; ShowFilterInLog = $false; ShowRefreshEvents = $false }
			}
			if ($chkShowAllSessions) {
				$settingsToSave.Debug.ShowAllSessions = [bool]$chkShowAllSessions.IsChecked
			}
			if ($chkShowFilterInLog) {
				$settingsToSave.Debug.ShowFilterInLog = [bool]$chkShowFilterInLog.IsChecked
			}
			if ($chkShowRefreshEvents) {
				$settingsToSave.Debug.ShowRefreshEvents = [bool]$chkShowRefreshEvents.IsChecked
			}

			Save-TrackSessionsSettings -Path $SettingsFilePath -Settings $settingsToSave

			$settingsWindow.DialogResult = $true
			$settingsWindow.Close()
		}
		catch {
			[System.Windows.MessageBox]::Show($_.Exception.Message, 'Save Failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
		}
	})

	$result = $settingsWindow.ShowDialog()
	return [bool]$result
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
$txtMachine.Text = $script:machineName
$txtFolder.Text = "{0} [{1}]" -f $script:effectiveOutputFolder, $script:folderMode
$txtJsonFile.Text = $script:currentJsonFilePath
$txtMiniMachine.Text = "Machine: {0}" -f $script:machineName
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
	$txtStatusUser.Text = "User: {0} | SEID: {1}" -f $userContext.DisplayName, $userContext.SamAccountName
	$txtStatusMachine.Text = "Machine: {0}" -f $script:machineName
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
		if ($script:debugShowRefreshEvents) {
			Add-DebugLog -Message "REFRESH EVENT: Update-SessionGridData starting"
		}
		else {
			Add-DebugLog -Message "Update-SessionGridData: Starting"
		}
		
		# When ShowAllSessions is enabled, include current machine; otherwise exclude it
		$excludeMachine = if ($script:debugShowAllSessions) { '' } else { $script:machineName }
		
		if ($script:debugShowFilterInLog) {
			Add-DebugLog -Message "FILTER: Will exclude machine: '$excludeMachine'"
		}
		
		$realRows = @(Get-SessionGridRows -FolderPath $script:effectiveOutputFolder -TrackedMachines $script:trackedMachines -ExcludeMachineName $excludeMachine)
		Add-DebugLog -Message "Update-SessionGridData: Got $($realRows.Count) real rows from '$($script:effectiveOutputFolder)'"
		
		if ($script:isSimulationModeEnabled -and $script:simulatedRows.Count -gt 0) {
			$combinedRows = @($script:simulatedRows + $realRows)
			if ($script:debugShowRefreshEvents) {
				Add-DebugLog -Message "REFRESH EVENT: Combined simulation ($($script:simulatedRows.Count)) and real rows = $($combinedRows.Count)"
			}
			else {
				Add-DebugLog -Message "Update-SessionGridData: Combined simulation ($($script:simulatedRows.Count)) and real rows = $($combinedRows.Count)"
			}
		}
		else {
			$combinedRows = $realRows
			if ($script:debugShowRefreshEvents) {
				Add-DebugLog -Message "REFRESH EVENT: Using real rows only"
			}
			else {
				Add-DebugLog -Message "Update-SessionGridData: Using real rows only"
			}
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
			$resolvedName = Get-CachedUserDisplayName -UserId $row.UserId -UsersList $script:usersList
			if (-not [string]::IsNullOrWhiteSpace($resolvedName)) {
				$row | Add-Member -NotePropertyName 'UserDisplayNameResolved' -NotePropertyValue $resolvedName -Force
			}
			else {
				$row | Add-Member -NotePropertyName 'UserDisplayNameResolved' -NotePropertyValue $row.UserDisplayName -Force
			}
		}
		
		if ($gridSessionFiles) {
			if ($script:debugShowRefreshEvents) {
				Add-DebugLog -Message "REFRESH EVENT: Setting grid ItemsSource with $($finalRows.Count) rows"
			}
			else {
				Add-DebugLog -Message "Update-SessionGridData: Setting grid ItemsSource with $($finalRows.Count) rows"
			}
			
			$gridSessionFiles.ItemsSource = $null
			$gridSessionFiles.ItemsSource = $finalRows
			Add-DebugLog -Message "Update-SessionGridData: Grid ItemsSource set successfully"

			$gridView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($gridSessionFiles.ItemsSource)
			if ($gridView) {
				$gridView.SortDescriptions.Clear()
				$gridView.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription('LastActivity', [System.ComponentModel.ListSortDirection]::Descending)))
				$gridView.Refresh()
				Add-DebugLog -Message "Update-SessionGridData: Grid view refreshed"
			}
		}
		else {
			Add-DebugLog -Message "Update-SessionGridData: ERROR - gridSessionFiles is NULL, cannot set ItemsSource"
		}
		
		if ($script:debugShowRefreshEvents) {
			Add-DebugLog -Message "REFRESH EVENT: Grid updated successfully with $($finalRows.Count) deduplicated entries"
		}
		else {
			Add-DebugLog -Message "Update-SessionGridData: Grid updated successfully with $($finalRows.Count) deduplicated entries"
		}
	}
	catch {
		Add-DebugLog -Message "Update-SessionGridData ERROR: $($_.Exception.Message)"
		Add-DebugLog -Message "Update-SessionGridData ERROR Stack: $($_.Exception.StackTrace)"
	}
}

$refreshAction = {
	try {
		$perfTimer = [System.Diagnostics.Stopwatch]::StartNew()
		
		if ($script:debugShowRefreshEvents) {
			Add-DebugLog -Message "REFRESH EVENT: Starting refresh action"
		}
		else {
			Add-DebugLog -Message "refreshAction: Starting"
		}
		
		if ($script:debugShowFilterInLog) {
			Add-DebugLog -Message "FILTER: EffectiveFolder=$($script:effectiveOutputFolder)"
			Add-DebugLog -Message "FILTER: TrackedMachines=$($script:trackedMachines -join ',')"
			Add-DebugLog -Message "FILTER: ExcludeMachine=$($script:machineName)"
			Add-DebugLog -Message "FILTER: ShowAllSessions=$($script:debugShowAllSessions)"
		}
		
		$snapshot = Write-SessionSnapshot -CreatedAt $createdAtGmt -JsonPath $script:currentJsonFilePath -MachineName $script:machineName -SessionId $sessionId -SessionName $sessionName -UserContext $userContext
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
			if ($script:debugShowFilterInLog) {
				Add-DebugLog -Message "FILTER: Grid now contains $($currentRows.Count) rows"
			}
			
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
		
		if ($script:debugShowRefreshEvents) {
			Add-DebugLog -Message "REFRESH EVENT: Completed"
		}
		else {
			Add-DebugLog -Message "refreshAction: Completed"
		}
	}
	catch {
		Add-DebugLog -Message "refreshAction ERROR: $($_.Exception.Message)"
		Add-DebugLog -Message "refreshAction ERROR Stack: $($_.Exception.StackTrace)"
	}
}

$labelControls = @($lblSession, $lblUserId, $lblDisplayName, $lblUserEmail, $lblMachine, $lblFolder, $lblJsonFile, $lblLastUpdated)
$valueControls = @($txtSession, $txtUserId, $txtDisplayName, $txtUserEmail, $txtMachine, $txtFolder, $txtJsonFile, $txtLastUpdated)
$script:mainZoomLevel = 1.0

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
			})
			$fadeTimer.Start()
		}
	})
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

$simulationTimer = New-Object System.Windows.Threading.DispatcherTimer
$simulationTimer.Interval = Get-SimulationInterval
$simulationTimer.Add_Tick({
	if (-not $script:isSimulationModeEnabled) {
		return
	}

	$nextEvent = New-SimulatedStateMachineEvent -TrackedMachines $script:trackedMachines -CurrentMachineName $script:machineName -SessionStateMap $script:simulatedSessionState
	$script:simulatedRows = @($nextEvent) + @($script:simulatedRows)
	if ($script:simulatedRows.Count -gt 40) {
		$script:simulatedRows = @($script:simulatedRows | Select-Object -First 40)
	}

	Update-SessionGridData
	$simulationTimer.Interval = Get-SimulationInterval
})

$chkSimulationMode.Add_Checked({
	$script:isSimulationModeEnabled = $true
	if ($script:simulatedRows.Count -eq 0) {
		$script:simulatedRows = @((New-SimulatedStateMachineEvent -TrackedMachines $script:trackedMachines -CurrentMachineName $script:machineName -SessionStateMap $script:simulatedSessionState))
	}
	Update-SessionGridData
	$simulationTimer.Interval = Get-SimulationInterval
	if (-not $simulationTimer.IsEnabled) {
		$simulationTimer.Start()
	}
	Add-StartupTrace -Path $SettingsPath -EventName 'Simulation.Enabled' -Detail 'Activity Grid simulator started.'
})

$chkSimulationMode.Add_Unchecked({
	$script:isSimulationModeEnabled = $false
	if ($simulationTimer.IsEnabled) {
		$simulationTimer.Stop()
	}
	$script:simulatedRows = @()
	$script:simulatedSessionState = @{}
	Update-SessionGridData
	Add-StartupTrace -Path $SettingsPath -EventName 'Simulation.Disabled' -Detail 'Activity Grid simulator stopped.'
})

$btnZoomOutMain.Add_Click({
	Update-MainContentZoom -Delta (-0.10) -Labels $labelControls -Values $valueControls -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles
})

$btnZoomInMain.Add_Click({
	Update-MainContentZoom -Delta 0.10 -Labels $labelControls -Values $valueControls -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles
})

$btnCopyMain.Add_Click({
	try {
		$sessionInfo = [ordered]@{
			SessionName = $sessionName
			SessionId = $sessionId
			UserId = $userContext.UserId
			UserDisplayName = $userContext.DisplayName
			UserEmail = $userContext.Email
			MachineName = $script:machineName
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
})

$btnEditSettings.Add_Click({
	try {
		Add-DebugLog -Message "Settings button clicked - opening dialog"
		$didSaveSettings = Show-EditSettingsDialog -OwnerWindow $window -SettingsFilePath $SettingsPath
		Add-DebugLog -Message "Settings dialog closed - SavedSettings: $didSaveSettings"

		if ($didSaveSettings) {
			$settingsData = Read-TrackSessionsSettings -Path $SettingsPath
			
			# Reload debug settings from updated configuration
			$script:debugShowAllSessions = $false
			if ($settingsData.Debug -and $null -ne $settingsData.Debug.ShowAllSessions) {
				$script:debugShowAllSessions = [bool]$settingsData.Debug.ShowAllSessions
			}
			$script:debugShowFilterInLog = $false
			if ($settingsData.Debug -and $null -ne $settingsData.Debug.ShowFilterInLog) {
				$script:debugShowFilterInLog = [bool]$settingsData.Debug.ShowFilterInLog
			}
			$script:debugShowRefreshEvents = $false
			if ($settingsData.Debug -and $null -ne $settingsData.Debug.ShowRefreshEvents) {
				$script:debugShowRefreshEvents = [bool]$settingsData.Debug.ShowRefreshEvents
			}
			
			if ($script:debugShowFilterInLog) {
				Add-DebugLog -Message "DEBUG: ShowFilterInLog is now ENABLED"
			}
			if ($script:debugShowRefreshEvents) {
				Add-DebugLog -Message "DEBUG: ShowRefreshEvents is now ENABLED"
			}
			if ($script:debugShowAllSessions) {
				Add-DebugLog -Message "DEBUG: ShowAllSessions is now ENABLED"
			}
			
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
})

$btnLog.Add_Click({
	$logWindow = New-Object System.Windows.Window
	$logWindow.Title = 'Debug Log Viewer'
	$logWindow.Width = 800
	$logWindow.Height = 600
	$logWindow.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
	$logWindow.Owner = $window
	$logWindow.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(240, 240, 240))
	
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
	[System.Windows.Controls.Grid]::SetRow($txtLog, 0)
	$mainGrid.Children.Add($txtLog) | Out-Null
	
	$buttonGrid = New-Object System.Windows.Controls.Grid
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'}))
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'}))
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = '*'}))
	$buttonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = 'Auto'}))
	$buttonGrid.Margin = New-Object System.Windows.Thickness(8)
	$buttonGrid.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(250, 250, 250))
	[System.Windows.Controls.Grid]::SetRow($buttonGrid, 1)
	$mainGrid.Children.Add($buttonGrid) | Out-Null
	
	$btnClear = New-Object System.Windows.Controls.Button
	$btnClear.Content = 'Clear Log'
	$btnClear.Width = 100
	$btnClear.Height = 28
	$btnClear.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
	[System.Windows.Controls.Grid]::SetColumn($btnClear, 0)
	$btnClear.Add_Click({
		$script:debugLog = @()
		$txtLog.Text = ''
		Add-DebugLog -Message 'Debug log cleared'
		$txtLog.Text = [string]::Join("`r`n", $script:debugLog)
	})
	$buttonGrid.Children.Add($btnClear) | Out-Null
	
	$btnCopy = New-Object System.Windows.Controls.Button
	$btnCopy.Content = 'Copy'
	$btnCopy.Width = 100
	$btnCopy.Height = 28
	$btnCopy.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
	[System.Windows.Controls.Grid]::SetColumn($btnCopy, 1)
	$btnCopy.Add_Click({
		[System.Windows.Forms.Clipboard]::SetText($txtLog.Text)
		Add-DebugLog -Message 'Debug log copied to clipboard'
		$txtLog.Text = [string]::Join("`r`n", $script:debugLog)
	})
	$buttonGrid.Children.Add($btnCopy) | Out-Null
	
	$btnCloseLog = New-Object System.Windows.Controls.Button
	$btnCloseLog.Content = 'Close'
	$btnCloseLog.Width = 100
	$btnCloseLog.Height = 28
	[System.Windows.Controls.Grid]::SetColumn($btnCloseLog, 3)
	$btnCloseLog.Add_Click({
		$logWindow.Close()
	})
	$buttonGrid.Children.Add($btnCloseLog) | Out-Null
	
	$logWindow.Content = $mainGrid
	$logWindow.ShowDialog() | Out-Null
})

$btnManageUsers.Add_Click({
	$usersFilePath = Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Users.json'
	$userEditorPath = Join-Path $PSScriptRoot 'TrackSessions.UserEditor.ps1'
	
	if (Test-Path -LiteralPath $usersFilePath) {
		if (Test-Path -LiteralPath $userEditorPath) {
			# Launch UserEditor in separate process to avoid scope conflicts
			Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$userEditorPath`"" -WindowStyle Normal
		}
		else {
			[System.Windows.MessageBox]::Show('UserEditor script not found at: ' + $userEditorPath, 'UserEditor Not Found', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
		}
	}
	else {
		[System.Windows.MessageBox]::Show('Users file not found at: ' + $usersFilePath, 'Users File Not Found', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
	}
})

$btnReservations.Add_Click({
	try {
		$refreshTimerWasEnabled = ($null -ne $timer -and $timer.IsEnabled)
		if ($refreshTimerWasEnabled) {
			$timer.Stop()
		}

		$dialogCandidates = @(
			(Join-Path $PSScriptRoot 'TrackSessions.Reservations.CalendarDialog.ps1')
			(Join-Path (Split-Path -Parent $SettingsPath) 'TrackSessions.Reservations.CalendarDialog.ps1')
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
})


$btnCloseStartupOverlay.Add_Click({
	$startupOverlay.Visibility = [System.Windows.Visibility]::Collapsed
})

$btnMinimize.Add_Click({
	$window.WindowState = [System.Windows.WindowState]::Minimized
})

$btnRestoreMini.Add_Click({
	Restore-MainWindowFromMini
})

$miniRootBorder.Add_MouseLeftButtonDown({
	param($eventSource, $e)
	if ($e.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
		$miniWindow.DragMove()
		Save-MiniWindowPosition -MiniWindow $miniWindow
	}
})

$miniWindow.Add_LocationChanged({
	if ($miniWindow.IsVisible) {
		Save-MiniWindowPosition -MiniWindow $miniWindow
	}
})

$miniWindow.Add_MouseDoubleClick({
	Restore-MainWindowFromMini
})

$miniWindow.Add_Closing({
	param($eventSource, $e)
	if (-not $script:isAppClosing) {
		$e.Cancel = $true
		Save-MiniWindowPosition -MiniWindow $miniWindow
		Restore-MainWindowFromMini
	}
})

$window.Add_StateChanged({
	Add-StartupTrace -Path $SettingsPath -EventName 'Main.StateChanged' -Detail ("State={0}" -f $window.WindowState)
})

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
			$localMachineName = $script:machineName

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
					Add-DebugLog -Message "ContentRendered: Both background jobs complete"
					Add-DebugLog -Message "  -> User Context Loaded: $($script:BackgroundLoadingState.UserContextLoaded)"
					Add-DebugLog -Message "  -> Sessions Loaded: $($script:BackgroundLoadingState.SessionsLoaded)"
					Add-DebugLog -Message "  -> Session Files Found: $($script:BackgroundLoadingState.SessionData.Count)"
					Add-DebugLog -Message "  -> Effective Output Folder: $($script:effectiveOutputFolder)"
					Add-DebugLog -Message "ContentRendered: Calling refreshAction to populate grid"
					& $refreshAction
					$script:BackgroundLoadingState.LoadingInProgress = $false
					Add-DebugLog -Message "ContentRendered: Initial load complete, grid should now display data"
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
		})

		# Store timeout deadline in Tag
		$script:pollTimer.Tag = (Get-Date).AddSeconds(10)
		$script:pollTimer.Start()
		Add-DebugLog -Message "ContentRendered: Background jobs started, polling for completion"
	}
	catch {
		if ($txtStatusDateTime) { $txtStatusDateTime.Text = "Error: $($_.Exception.Message)" }
		Add-DebugLog -Message "ContentRendered: ERROR: $($_.Exception.Message)"
	}
})

$window.Add_Loaded({
	Add-StartupTrace -Path $SettingsPath -EventName 'Main.Loaded' -Detail ("State={0}" -f $window.WindowState)
})

$window.Add_SourceInitialized({
	Add-StartupTrace -Path $SettingsPath -EventName 'Main.SourceInitialized' -Detail ''
})


($window.FindName('MainRowSplitter')).Add_DragCompleted({
	if ($bottomPaneRow -and $bottomPaneRow.Height.GridUnitType -eq [System.Windows.GridUnitType]::Pixel) {
		Save-SplitterPosition -BottomRow $bottomPaneRow -Height $bottomPaneRow.Height.Value
	}
	Update-MinimumLayoutConstraints -MainWindow $window -TopPaneRow $topPaneRow -BottomPaneRow $bottomPaneRow -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles -SampleValueControl $txtSession
})

$btnCloseAfterSession.Add_Click({
	$script:isAppClosing = $true
	Add-StartupTrace -Path $SettingsPath -EventName 'CloseAfterSession.Clicked' -Detail ''
	if ($simulationTimer.IsEnabled) {
		$simulationTimer.Stop()
	}
	& $refreshAction
	Write-SessionCloseArtifacts -CurrentJsonPath $script:currentJsonFilePath -SessionName $sessionName -SessionId $sessionId -MachineName $script:machineName -UserContext $userContext
	if ($miniWindow.IsVisible) {
		Save-MiniWindowPosition -MiniWindow $miniWindow
	}
	if ($miniWindow.IsVisible) {
		$miniWindow.Close()
	}
	$window.Close()
})

$window.Add_SizeChanged({
	Set-ResponsiveInfoLayout -WindowWidth $window.ActualWidth -Labels $labelControls -Values $valueControls -LabelColumn $lblCol -ValueColumn $valCol
	Update-MinimumLayoutConstraints -MainWindow $window -TopPaneRow $topPaneRow -BottomPaneRow $bottomPaneRow -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles -SampleValueControl $txtSession
})

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
		Write-SessionSnapshot -CreatedAt $createdAtGmt -JsonPath $script:currentJsonFilePath -MachineName $script:machineName -SessionId $sessionId -SessionName $sessionName -UserContext $userContext
		if ($txtLastUpdated) { $txtLastUpdated.Text = [DateTime]::UtcNow.ToString('o') }

		# Start background refresh job (non-blocking)
		$script:refreshJob = Start-BackgroundSessionLoadJob -SessionFolderPath $script:effectiveOutputFolder -TimeoutSeconds 10

		# Capture variables for inner timer
		$capturedGridSessionFiles = $gridSessionFiles
		$capturedMachineName = $script:machineName
		$capturedWindow = $window
		$capturedTxtStatusDateTime = $txtStatusDateTime

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
					if ($capturedTxtStatusDateTime) { $capturedTxtStatusDateTime.Text = 'Ready (refresh failed)' }
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
				if ($capturedTxtStatusDateTime) { $capturedTxtStatusDateTime.Text = 'Ready (refresh timed out)' }
				Add-DebugLog -Message "Refresh timer: Background refresh timed out"
			}
		})

		$script:refreshPollTimer.Tag = (Get-Date).AddSeconds(15)
		$script:refreshPollTimer.Start()
	}
	catch {
		if ($txtStatusDateTime) { $txtStatusDateTime.Text = "Error: $($_.Exception.Message)" }
		Add-DebugLog -Message "Refresh timer ERROR: $($_.Exception.Message)"
	}
})
$timer.Start()

$statusTimer = New-Object System.Windows.Threading.DispatcherTimer
$statusTimer.Interval = [TimeSpan]::FromSeconds(1)
$statusTimer.Add_Tick({
	Update-StatusBar
})
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
})
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
	Write-SessionCloseArtifacts -CurrentJsonPath $script:currentJsonFilePath -SessionName $sessionName -SessionId $sessionId -MachineName $script:machineName -UserContext $userContext
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
})

# RESTORE: Initial refresh call BEFORE window shows (like working version)
& $refreshAction
Add-StartupTrace -Path $SettingsPath -EventName 'Before.ShowDialog' -Detail 'Initial refresh complete'

[void]$window.ShowDialog()
