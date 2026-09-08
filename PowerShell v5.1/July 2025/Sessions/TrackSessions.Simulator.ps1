[CmdletBinding()]
param(
	[string]$OutputFolder = "$env:ProgramData\SessionTracker\Json",
	[switch]$RegisterLogonTask,
	[string]$TaskName = "TrackSessionsWpf",
	[string]$SettingsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:LayoutConstraintTuning = [ordered]@{
	TopVisibleRows = 3
	BottomVisibleRows = 3
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

function Convert-ToSafeFileToken {
	param([Parameter(Mandatory = $true)][string]$Value)

	$safe = $Value -replace '[^A-Za-z0-9._-]', '-'
	$safe = $safe.Trim('-')
	if ([string]::IsNullOrWhiteSpace($safe)) {
		return 'Unknown'
	}
	return $safe
}

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

function Append-StartupTrace {
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

$userContext = Get-CurrentUserContext
$machineName = $env:COMPUTERNAME
$sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
$sessionName = Get-CurrentSessionName -SamAccountName $userContext.SamAccountName
$createdAtGmt = [DateTime]::UtcNow

$fileMachine = Convert-ToSafeFileToken -Value $machineName
$fileUser = Convert-ToSafeFileToken -Value $userContext.UserId
$fileDisplay = Convert-ToSafeFileToken -Value $userContext.DisplayName
$fileStamp = $createdAtGmt.ToString('yyyyMMdd_HHmmss') + 'Z'

$jsonFileName = "Session.{0}.{1}.{2}.{3}.json" -f $fileMachine, $fileUser, $fileDisplay, $fileStamp

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

	$trackedLookup = @{}
	foreach ($entry in @($TrackedMachines)) {
		if ($null -eq $entry) {
			continue
		}

		$shortName = [string]$entry.ShortName
		$fqdn = [string]$entry.FQDN
		if (-not [string]::IsNullOrWhiteSpace($shortName)) {
			$shortToken = $shortName.Trim().ToUpperInvariant()
			$trackedLookup[$shortToken] = $true
		}
		if (-not [string]::IsNullOrWhiteSpace($fqdn)) {
			$fqdnToken = $fqdn.Trim().ToUpperInvariant()
			$trackedLookup[$fqdnToken] = $true
			if ($fqdnToken.Contains('.')) {
				$trackedLookup[$fqdnToken.Split('.')[0]] = $true
			}
		}
	}

	$excludeToken = ''
	if (-not [string]::IsNullOrWhiteSpace($ExcludeMachineName)) {
		$excludeToken = $ExcludeMachineName.Trim().ToUpperInvariant()
	}

	try {
		if (-not (Test-Path -LiteralPath $FolderPath)) {
			return @()
		}

		$jsonFiles = Get-ChildItem -LiteralPath $FolderPath -Filter '*.json' -File -ErrorAction Stop |
			Sort-Object LastWriteTime -Descending

		foreach ($file in $jsonFiles) {
			try {
				$obj = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
				if ($null -eq $obj) {
					continue
				}

				$machineValue = [string]$obj.MachineName
				$machineToken = $machineValue.Trim().ToUpperInvariant()
				$machineShortToken = if ($machineToken.Contains('.')) { $machineToken.Split('.')[0] } else { $machineToken }

				if (-not [string]::IsNullOrWhiteSpace($excludeToken) -and ($machineToken -eq $excludeToken -or $machineShortToken -eq $excludeToken)) {
					continue
				}

				if ($trackedLookup.Count -gt 0) {
					if (-not ($trackedLookup.ContainsKey($machineToken) -or $trackedLookup.ContainsKey($machineShortToken))) {
						continue
					}
				}

				$statusTimestamp = [string]$obj.LastUpdatedAtGmt
				if ([string]::IsNullOrWhiteSpace($statusTimestamp)) {
					$statusTimestamp = [string]$obj.CreatedAtGmt
				}

				$computedStatus = Get-SessionStatusFromSnapshot -SnapshotObject $obj -SourceFilePath $file.FullName

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
			}
		}
	}
	catch {
	}

	return $rows
}

function Get-SessionStatusFromSnapshot {
	param(
		[Parameter(Mandatory = $true)]$SnapshotObject,
		[Parameter(Mandatory = $true)][string]$SourceFilePath
	)

	$fileName = [System.IO.Path]::GetFileName($SourceFilePath)
	$sessionStatus = [string]$SnapshotObject.SessionStatus
	$closeEvent = [string]$SnapshotObject.SessionCloseEvent
	$closedAt = [string]$SnapshotObject.SessionClosedAtGmt

	if ($fileName -like '*.Logout.json' -or $sessionStatus -eq 'Closed' -or -not [string]::IsNullOrWhiteSpace($closedAt) -or -not [string]::IsNullOrWhiteSpace($closeEvent)) {
		return 'Logged Out'
	}

	$lastUpdateRaw = [string]$SnapshotObject.LastUpdatedAtGmt
	if (-not [string]::IsNullOrWhiteSpace($lastUpdateRaw)) {
		try {
			$lastUpdate = [datetime]::Parse($lastUpdateRaw, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
			$age = [DateTime]::UtcNow - $lastUpdate.ToUniversalTime()
			if ($age.TotalMinutes -ge 10) {
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

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Windows Session Tracker"
		Height="460"
		Width="860"
		MinHeight="420"
		MinWidth="560"
		WindowStartupLocation="CenterScreen"
		ResizeMode="CanResizeWithGrip"
		SizeToContent="Manual"
		ShowInTaskbar="True"
		Background="#F4F8FC">
	<Grid Margin="18">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
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
					<RowDefinition x:Name="TopPaneRow" Height="*" MinHeight="170"/>
					<RowDefinition Height="6"/>
					<RowDefinition x:Name="BottomPaneRow" Height="190" MinHeight="130"/>
				</Grid.RowDefinitions>

				<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="4">
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
						<TextBox Grid.Row="0" Grid.Column="1" Name="TxtSession" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True"/>

						<TextBlock Name="LblUserId" Grid.Row="1" Grid.Column="0" Text="User ID:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="1" Grid.Column="1" Name="TxtUserId" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True"/>

						<TextBlock Name="LblDisplayName" Grid.Row="2" Grid.Column="0" Text="User Display Name:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="2" Grid.Column="1" Name="TxtDisplayName" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True"/>

						<TextBlock Name="LblUserEmail" Grid.Row="3" Grid.Column="0" Text="User Email:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="3" Grid.Column="1" Name="TxtUserEmail" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True"/>

						<TextBlock Name="LblMachine" Grid.Row="4" Grid.Column="0" Text="Machine Name:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="4" Grid.Column="1" Name="TxtMachine" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True"/>

						<TextBlock Name="LblFolder" Grid.Row="5" Grid.Column="0" Text="JSON Output Folder (default):" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="5" Grid.Column="1" Name="TxtFolder" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True"/>

						<TextBlock Name="LblJsonFile" Grid.Row="6" Grid.Column="0" Text="Current JSON File:" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="6" Grid.Column="1" Name="TxtJsonFile" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True"/>

						<TextBlock Name="LblLastUpdated" Grid.Row="7" Grid.Column="0" Text="Last Update (GMT):" FontWeight="SemiBold" Margin="0,4,6,6" VerticalAlignment="Top"/>
						<TextBox Grid.Row="7" Grid.Column="1" Name="TxtLastUpdated" Margin="0,4,0,6" TextWrapping="Wrap" VerticalAlignment="Top" IsReadOnly="True" BorderThickness="0" Background="Transparent" IsReadOnlyCaretVisible="True"/>
					</Grid>
				</ScrollViewer>

				<GridSplitter Name="MainRowSplitter" Grid.Row="1" Height="6" HorizontalAlignment="Stretch" VerticalAlignment="Center" ResizeDirection="Rows" ResizeBehavior="PreviousAndNext" Background="#D9E5EF"/>

				<Grid Grid.Row="2" Margin="4,8,4,4">
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
					</Grid.RowDefinitions>
					<TextBlock Name="LblHistory" Grid.Row="0" Text="Activity on Other Machines" FontWeight="SemiBold" Margin="0,0,0,6"/>
					<DataGrid Name="GridSessionFiles"
							  Grid.Row="1"
							  MinHeight="120"
							  AutoGenerateColumns="False"
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
							<DataGridTextColumn Header="User Display Name" Binding="{Binding UserDisplayName}" Width="*"/>
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
				<ColumnDefinition Width="*"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
				<ColumnDefinition Width="Auto"/>
			</Grid.ColumnDefinitions>
			<StackPanel Grid.Column="0" Orientation="Vertical" VerticalAlignment="Center">
				<StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,4">
					<TextBlock Text="Legend:" FontSize="11" Foreground="#365065" Margin="0,0,6,0" VerticalAlignment="Center"/>
					<Border Width="10" Height="10" Background="#E7F7EC" BorderBrush="#B9E1C7" BorderThickness="1" Margin="0,0,4,0" VerticalAlignment="Center"/>
					<TextBlock Text="Logged In" FontSize="11" Foreground="#365065" Margin="0,0,8,0" VerticalAlignment="Center"/>
					<Border Width="10" Height="10" Background="#FDEBEC" BorderBrush="#E6BFC3" BorderThickness="1" Margin="0,0,4,0" VerticalAlignment="Center"/>
					<TextBlock Text="Logged Out" FontSize="11" Foreground="#365065" Margin="0,0,8,0" VerticalAlignment="Center"/>
					<Border Width="10" Height="10" Background="#E8F3FF" BorderBrush="#BFD8F5" BorderThickness="1" Margin="0,0,4,0" VerticalAlignment="Center"/>
					<TextBlock Text="Disconnected" FontSize="11" Foreground="#365065" VerticalAlignment="Center"/>
				</StackPanel>
				<StackPanel Orientation="Horizontal" VerticalAlignment="Center">
					<CheckBox Name="ChkSimulationMode" Content="Simulation Mode" VerticalAlignment="Center" Margin="0,0,10,0" ToolTip="When enabled, simulator rows are added to the Activity Grid every 5-7 seconds."/>
					<Button Name="BtnZoomOutMain" Content="-" Width="30" Height="28" Margin="0,0,6,0" ToolTip="Zoom out main details and session grid."/>
					<Button Name="BtnZoomInMain" Content="+" Width="30" Height="28" Margin="0,0,10,0" ToolTip="Zoom in main details and session grid."/>
					<TextBlock Text="Session JSON auto-updates every 3 minutes while this app is running." Foreground="#334E68" VerticalAlignment="Center" TextWrapping="Wrap" Margin="0,0,12,0"/>
				</StackPanel>
			</StackPanel>
			<Button Grid.Column="1" Name="BtnRefresh" Content="Refresh Now" Width="110" Height="30" Margin="0,0,8,0" HorizontalAlignment="Right" VerticalAlignment="Center"/>
			<Button Grid.Column="2" Name="BtnCopyMain" Content="Copy" Width="74" Height="30" Margin="0,0,8,0" HorizontalAlignment="Right" VerticalAlignment="Center" ToolTip="Copies Session and Grid as PowerShell object format"/>
			<Button Grid.Column="3" Name="BtnEditSettings" Content="Edit Settings" Width="108" Height="30" Margin="0,0,8,0" HorizontalAlignment="Right" VerticalAlignment="Center"/>
			<Button Grid.Column="4" Name="BtnMinimize" Content="_" Width="34" Height="30" Margin="0,0,8,0" FontWeight="Bold" HorizontalAlignment="Right" VerticalAlignment="Center"/>
			<Button Grid.Column="5" Name="BtnCloseAfterSession" Content="Close After Session" Width="150" Height="30" HorizontalAlignment="Right" VerticalAlignment="Center"/>
		</Grid>

		<Grid Name="StartupOverlay" Grid.RowSpan="3" Background="#B3000000" Visibility="Visible" Panel.ZIndex="1000">
			<Border Width="700" MaxWidth="760" Padding="16" CornerRadius="10" Background="#FFFDF8F1" BorderBrush="#D9C7A9" BorderThickness="1" HorizontalAlignment="Center" VerticalAlignment="Center">
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
$btnCopyMain = $window.FindName('BtnCopyMain')
$btnEditSettings = $window.FindName('BtnEditSettings')
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
Append-StartupTrace -Path $SettingsPath -EventName 'Script.Start' -Detail ("PID={0};SettingsPath={1}" -f $PID, $SettingsPath)

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
		Background="#F6FAFF">
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
				<Button Name="BtnZoomInSettings" Content="+" Width="30" Height="28" Margin="0,0,10,0" ToolTip="Zoom in tracked machines grid only."/>
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
$iconFrameIndex = 0
$window.Icon = $iconFrames[$iconFrameIndex]
$imgAnimatedIcon.Source = $headerFrames[$iconFrameIndex]
$miniWindow.Icon = $iconFrames[$iconFrameIndex]
$imgMiniIcon.Source = $headerFrames[$iconFrameIndex]
$imgRestoreIcon.Source = $headerFrames[$iconFrameIndex]

$script:isMiniMode = $false
$script:isAppClosing = $false
$script:isMinimizeInterceptionEnabled = $false
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
			return 'Logged Out'
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
	$realRows = @(Get-SessionGridRows -FolderPath $script:effectiveOutputFolder -TrackedMachines $script:trackedMachines -ExcludeMachineName $machineName)
	if ($script:isSimulationModeEnabled -and $script:simulatedRows.Count -gt 0) {
		$combinedRows = @($script:simulatedRows + $realRows)
	}
	else {
		$combinedRows = $realRows
	}

	$combinedRows = @($combinedRows | Sort-Object -Property LastActivity -Descending)

	$gridSessionFiles.ItemsSource = $null
	$gridSessionFiles.ItemsSource = $combinedRows

	$gridView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($gridSessionFiles.ItemsSource)
	if ($gridView) {
		$gridView.SortDescriptions.Clear()
		$gridView.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription('LastActivity', [System.ComponentModel.ListSortDirection]::Descending)))
		$gridView.Refresh()
	}
}

$refreshAction = {
	$snapshot = Write-SessionSnapshot -CreatedAt $createdAtGmt -JsonPath $script:currentJsonFilePath -MachineName $machineName -SessionId $sessionId -SessionName $sessionName -UserContext $userContext
	$txtLastUpdated.Text = $snapshot.LastUpdatedAtGmt
	$txtJsonFile.Text = $script:currentJsonFilePath
	$txtFolder.Text = "{0} [{1}]" -f $script:effectiveOutputFolder, $script:folderMode
	Update-SessionGridData
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
	Append-StartupTrace -Path $SettingsPath -EventName 'Mini.Show.Requested' -Detail ("MainState={0}" -f $window.WindowState)

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
	Append-StartupTrace -Path $SettingsPath -EventName 'Mini.Show.Completed' -Detail ("MiniLeft={0};MiniTop={1}" -f [Math]::Round($miniWindow.Left, 2), [Math]::Round($miniWindow.Top, 2))
}

function Restore-MainWindowFromMini {
	if (-not $script:isMiniMode) {
		return
	}
	Append-StartupTrace -Path $SettingsPath -EventName 'Mini.Restore.Requested' -Detail ''

	$script:isMiniMode = $false
	$miniWindow.Hide()
	$window.ShowInTaskbar = $true
	$window.WindowState = [System.Windows.WindowState]::Normal
	$window.Activate()
	Append-StartupTrace -Path $SettingsPath -EventName 'Mini.Restore.Completed' -Detail ("MainState={0}" -f $window.WindowState)
}

$btnRefresh.Add_Click($refreshAction)

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
})

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
	Append-StartupTrace -Path $SettingsPath -EventName 'Simulation.Enabled' -Detail 'Activity Grid simulator started.'
})

$chkSimulationMode.Add_Unchecked({
	$script:isSimulationModeEnabled = $false
	if ($simulationTimer.IsEnabled) {
		$simulationTimer.Stop()
	}
	$script:simulatedRows = @()
	$script:simulatedSessionState = @{}
	Update-SessionGridData
	Append-StartupTrace -Path $SettingsPath -EventName 'Simulation.Disabled' -Detail 'Activity Grid simulator stopped.'
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
})

$btnEditSettings.Add_Click({
	$didSaveSettings = Show-EditSettingsDialog -OwnerWindow $window -SettingsFilePath $SettingsPath
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
	}
})

$btnCloseStartupOverlay.Add_Click({
	$startupOverlay.Visibility = [System.Windows.Visibility]::Collapsed
})

$btnMinimize.Add_Click({
	Show-MiniSessionPanel
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
	Append-StartupTrace -Path $SettingsPath -EventName 'Main.StateChanged' -Detail ("State={0};InterceptionEnabled={1}" -f $window.WindowState, $script:isMinimizeInterceptionEnabled)
	if ($script:isMinimizeInterceptionEnabled -and -not $script:isAppClosing -and $window.WindowState -eq [System.Windows.WindowState]::Minimized) {
		$window.WindowState = [System.Windows.WindowState]::Normal
		Show-MiniSessionPanel
	}
})

$window.Add_ContentRendered({
	$script:isMinimizeInterceptionEnabled = $true
	$bodyGrid = $window.FindName('BodyGrid')
	if ((Test-IsFiniteDouble -Value $script:bottomPaneHeight) -and $bodyGrid -and $bottomPaneRow) {
		$minimumBottom = [Math]::Max(130, [double]$bottomPaneRow.MinHeight)
		$maximumBottom = [Math]::Max($minimumBottom, $bodyGrid.ActualHeight - 176)
		$restoredBottom = [Math]::Min([Math]::Max($script:bottomPaneHeight, $minimumBottom), $maximumBottom)
		$bottomPaneRow.Height = New-Object System.Windows.GridLength($restoredBottom)
	}
	Update-MinimumLayoutConstraints -MainWindow $window -TopPaneRow $topPaneRow -BottomPaneRow $bottomPaneRow -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles -SampleValueControl $txtSession
	Append-StartupTrace -Path $SettingsPath -EventName 'Main.ContentRendered' -Detail ("State={0}" -f $window.WindowState)
})

$window.Add_Loaded({
	Append-StartupTrace -Path $SettingsPath -EventName 'Main.Loaded' -Detail ("State={0}" -f $window.WindowState)
})

$window.Add_SourceInitialized({
	Append-StartupTrace -Path $SettingsPath -EventName 'Main.SourceInitialized' -Detail ''
})


($window.FindName('MainRowSplitter')).Add_DragCompleted({
	if ($bottomPaneRow -and $bottomPaneRow.Height.GridUnitType -eq [System.Windows.GridUnitType]::Pixel) {
		Save-SplitterPosition -BottomRow $bottomPaneRow -Height $bottomPaneRow.Height.Value
	}
	Update-MinimumLayoutConstraints -MainWindow $window -TopPaneRow $topPaneRow -BottomPaneRow $bottomPaneRow -HistoryLabel $lblHistory -SessionGrid $gridSessionFiles -SampleValueControl $txtSession
})

$btnCloseAfterSession.Add_Click({
	$script:isAppClosing = $true
	Append-StartupTrace -Path $SettingsPath -EventName 'CloseAfterSession.Clicked' -Detail ''
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
$timer.Add_Tick($refreshAction)
$timer.Start()

$iconTimer = New-Object System.Windows.Threading.DispatcherTimer
$iconTimer.Interval = [TimeSpan]::FromMilliseconds(240)
$iconTimer.Add_Tick({
	$script:iconFrameIndex = ($script:iconFrameIndex + 1) % $iconFrames.Count
	$window.Icon = $iconFrames[$script:iconFrameIndex]
	$miniWindow.Icon = $iconFrames[$script:iconFrameIndex]
	$imgAnimatedIcon.Source = $headerFrames[$script:iconFrameIndex]
	$imgMiniIcon.Source = $headerFrames[$script:iconFrameIndex]
	$imgRestoreIcon.Source = $headerFrames[$script:iconFrameIndex]
})
$iconTimer.Start()

& $refreshAction
Append-StartupTrace -Path $SettingsPath -EventName 'Before.ShowDialog' -Detail 'Entering modal loop'

$window.Add_Closed({
	$script:isAppClosing = $true
	Append-StartupTrace -Path $SettingsPath -EventName 'Main.Closed' -Detail 'Main window closed'
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
	if ($miniWindow.IsVisible) {
		Save-MiniWindowPosition -MiniWindow $miniWindow
		$miniWindow.Close()
	}
})

[void]$window.ShowDialog()
