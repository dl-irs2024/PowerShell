Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Data
Add-Type -AssemblyName System.Windows.Forms

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:settingsPath = Join-Path $PSScriptRoot 'SampleCsvEditor.settings.json'
$script:appSettings = $null
$script:previewFontSize = 12
$script:editorFontSize = 12
$script:editorWindows = New-Object System.Collections.ArrayList
$script:useBanding = $false
$script:logPath = Join-Path $PSScriptRoot 'SampleCsvEditor.crash.log'
$script:gridHeadersBrush = [System.Windows.Media.Brushes]::Lavender
$script:excelInfo = $null
$script:mainStatusTimer = $null
$script:previewRowLimit = 500

function Write-AppLog {
	param(
		[Parameter(Mandatory = $true)][string]$Message,
		[System.Exception]$Exception
	)

	try {
		$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
		$lines = New-Object System.Collections.Generic.List[string]
		[void]$lines.Add("[$stamp] $Message")
		if ($null -ne $Exception) {
			[void]$lines.Add("Exception: $($Exception.GetType().FullName)")
			[void]$lines.Add("Message: $($Exception.Message)")
			if (-not [string]::IsNullOrWhiteSpace($Exception.StackTrace)) {
				[void]$lines.Add('StackTrace:')
				[void]$lines.Add($Exception.StackTrace)
			}
		}
		[void]$lines.Add('')
		Add-Content -LiteralPath $script:logPath -Value $lines -Encoding UTF8
	}
	catch {
		# Logging should never crash the app.
	}
}

function Get-DefaultSettings {
	return @{
		FilePaths   = @()
		PreviewZoom = 12
		EditorZoom  = 12
		UseBanding  = $false
		PreviewRowLimit = 500
		MainWindowLeft = $null
		MainWindowTop = $null
		MainWindowWidth = 1360
		MainWindowHeight = 760
		MainWindowState = 'Normal'
	}
}

function Load-AppSettings {
	$defaults = Get-DefaultSettings

	if (-not (Test-Path -LiteralPath $script:settingsPath)) {
		return $defaults
	}

	try {
		$raw = Get-Content -LiteralPath $script:settingsPath -Raw -ErrorAction Stop
		if ([string]::IsNullOrWhiteSpace($raw)) {
			return $defaults
		}

		$json = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
		$filePaths = @()
		if ($null -ne $json.FilePaths) {
			$filePaths = @($json.FilePaths | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
		}

		$previewZoom = 12
		if ($null -ne $json.PreviewZoom) {
			$previewZoom = [int]$json.PreviewZoom
		}

		$editorZoom = 12
		if ($null -ne $json.EditorZoom) {
			$editorZoom = [int]$json.EditorZoom
		}

		$useBanding = $false
		if ($null -ne $json.UseBanding) {
			$useBanding = [bool]$json.UseBanding
		}

		$previewRowLimit = 500
		if ($null -ne $json.PreviewRowLimit) {
			$previewRowLimit = [int]$json.PreviewRowLimit
		}

		$mainWindowLeft = $null
		if ($null -ne $json.MainWindowLeft) {
			$mainWindowLeft = [double]$json.MainWindowLeft
		}

		$mainWindowTop = $null
		if ($null -ne $json.MainWindowTop) {
			$mainWindowTop = [double]$json.MainWindowTop
		}

		$mainWindowWidth = 1360
		if ($null -ne $json.MainWindowWidth) {
			$mainWindowWidth = [double]$json.MainWindowWidth
		}

		$mainWindowHeight = 760
		if ($null -ne $json.MainWindowHeight) {
			$mainWindowHeight = [double]$json.MainWindowHeight
		}

		$mainWindowState = 'Normal'
		if ($null -ne $json.MainWindowState -and -not [string]::IsNullOrWhiteSpace([string]$json.MainWindowState)) {
			$mainWindowState = [string]$json.MainWindowState
		}

		return @{
			FilePaths   = $filePaths
			PreviewZoom = [Math]::Max(8, [Math]::Min($previewZoom, 28))
			EditorZoom  = [Math]::Max(8, [Math]::Min($editorZoom, 28))
			UseBanding  = $useBanding
			PreviewRowLimit = [Math]::Max(50, [Math]::Min($previewRowLimit, 50000))
			MainWindowLeft = $mainWindowLeft
			MainWindowTop = $mainWindowTop
			MainWindowWidth = [Math]::Max(900, [Math]::Min($mainWindowWidth, 5000))
			MainWindowHeight = [Math]::Max(600, [Math]::Min($mainWindowHeight, 4000))
			MainWindowState = if ($mainWindowState -eq 'Maximized') { 'Maximized' } else { 'Normal' }
		}
	}
	catch {
		return $defaults
	}

}

function Save-AppSettings {
	param([Parameter(Mandatory = $false)][hashtable]$Settings)

	if ($null -eq $Settings) {
		$Settings = Get-DefaultSettings
	}

	$payload = @{
		FilePaths   = @(Get-SettingValue -Settings $Settings -Key 'FilePaths' -DefaultValue @())
		PreviewZoom = [int](Get-SettingValue -Settings $Settings -Key 'PreviewZoom' -DefaultValue 12)
		EditorZoom  = [int](Get-SettingValue -Settings $Settings -Key 'EditorZoom' -DefaultValue 12)
		UseBanding  = [bool](Get-SettingValue -Settings $Settings -Key 'UseBanding' -DefaultValue $false)
		PreviewRowLimit = [int](Get-SettingValue -Settings $Settings -Key 'PreviewRowLimit' -DefaultValue 500)
		MainWindowLeft = Get-SettingValue -Settings $Settings -Key 'MainWindowLeft' -DefaultValue $null
		MainWindowTop = Get-SettingValue -Settings $Settings -Key 'MainWindowTop' -DefaultValue $null
		MainWindowWidth = [double](Get-SettingValue -Settings $Settings -Key 'MainWindowWidth' -DefaultValue 1360)
		MainWindowHeight = [double](Get-SettingValue -Settings $Settings -Key 'MainWindowHeight' -DefaultValue 760)
		MainWindowState = [string](Get-SettingValue -Settings $Settings -Key 'MainWindowState' -DefaultValue 'Normal')
	}

	$payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:settingsPath -Encoding UTF8
}

function Ensure-AppSettings {
	if ($null -eq $script:appSettings) {
		$script:appSettings = Load-AppSettings
	}

	if ($script:appSettings -isnot [hashtable]) {
		$defaults = Get-DefaultSettings
		try {
			if ($null -ne $script:appSettings.PSObject.Properties['FilePaths']) {
				$defaults['FilePaths'] = @($script:appSettings.FilePaths)
			}
			if ($null -ne $script:appSettings.PSObject.Properties['PreviewZoom']) {
				$defaults['PreviewZoom'] = [int]$script:appSettings.PreviewZoom
			}
			if ($null -ne $script:appSettings.PSObject.Properties['EditorZoom']) {
				$defaults['EditorZoom'] = [int]$script:appSettings.EditorZoom
			}
			if ($null -ne $script:appSettings.PSObject.Properties['UseBanding']) {
				$defaults['UseBanding'] = [bool]$script:appSettings.UseBanding
			}
			if ($null -ne $script:appSettings.PSObject.Properties['PreviewRowLimit']) {
				$defaults['PreviewRowLimit'] = [int]$script:appSettings.PreviewRowLimit
			}
			if ($null -ne $script:appSettings.PSObject.Properties['MainWindowLeft']) {
				$defaults['MainWindowLeft'] = $script:appSettings.MainWindowLeft
			}
			if ($null -ne $script:appSettings.PSObject.Properties['MainWindowTop']) {
				$defaults['MainWindowTop'] = $script:appSettings.MainWindowTop
			}
			if ($null -ne $script:appSettings.PSObject.Properties['MainWindowWidth']) {
				$defaults['MainWindowWidth'] = [double]$script:appSettings.MainWindowWidth
			}
			if ($null -ne $script:appSettings.PSObject.Properties['MainWindowHeight']) {
				$defaults['MainWindowHeight'] = [double]$script:appSettings.MainWindowHeight
			}
			if ($null -ne $script:appSettings.PSObject.Properties['MainWindowState']) {
				$defaults['MainWindowState'] = [string]$script:appSettings.MainWindowState
			}
		}
		catch {
			# Keep defaults if conversion fails.
		}
		$script:appSettings = $defaults
	}

	if ($null -eq (Get-SettingValue -Settings $script:appSettings -Key 'FilePaths' -DefaultValue $null)) {
		$script:appSettings['FilePaths'] = @()
	}
	if ($null -eq (Get-SettingValue -Settings $script:appSettings -Key 'PreviewZoom' -DefaultValue $null)) {
		$script:appSettings['PreviewZoom'] = 12
	}
	if ($null -eq (Get-SettingValue -Settings $script:appSettings -Key 'EditorZoom' -DefaultValue $null)) {
		$script:appSettings['EditorZoom'] = 12
	}
	if ($null -eq (Get-SettingValue -Settings $script:appSettings -Key 'UseBanding' -DefaultValue $null)) {
		$script:appSettings['UseBanding'] = $false
	}
	if ($null -eq (Get-SettingValue -Settings $script:appSettings -Key 'PreviewRowLimit' -DefaultValue $null)) {
		$script:appSettings['PreviewRowLimit'] = 500
	}
	if ($null -eq (Get-SettingValue -Settings $script:appSettings -Key 'MainWindowWidth' -DefaultValue $null)) {
		$script:appSettings['MainWindowWidth'] = 1360
	}
	if ($null -eq (Get-SettingValue -Settings $script:appSettings -Key 'MainWindowHeight' -DefaultValue $null)) {
		$script:appSettings['MainWindowHeight'] = 760
	}
	if ($null -eq (Get-SettingValue -Settings $script:appSettings -Key 'MainWindowState' -DefaultValue $null)) {
		$script:appSettings['MainWindowState'] = 'Normal'
	}
}

function Set-AppSetting {
	param(
		[Parameter(Mandatory = $true)][string]$Key,
		$Value
	)

	Ensure-AppSettings
	$script:appSettings[$Key] = $Value
}

function ConvertTo-RowArray {
	param($InputObject)

	if ($null -eq $InputObject) {
		return @()
	}

	if ($InputObject -is [System.Array]) {
		return $InputObject
	}

	return @($InputObject)
}

function Convert-ToFileSizeText {
	param([long]$Bytes)

	if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
	if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
	if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
	return ('{0} B' -f $Bytes)
}

function Get-ValidFontSize {
	param(
		$Value,
		[int]$Default = 12
	)

	$size = $Default
	try {
		$size = [int][Math]::Round([double]$Value)
	}
	catch {
		$size = $Default
	}

	if ($size -lt 8) { return 8 }
	if ($size -gt 28) { return 28 }
	return $size
}

function Get-ValidPreviewRowLimit {
	param(
		$Value,
		[int]$Default = 500
	)

	$limit = $Default
	try {
		$limit = [int]$Value
	}
	catch {
		$limit = $Default
	}

	if ($limit -lt 50) { return 50 }
	if ($limit -gt 50000) { return 50000 }
	return $limit
}

function Get-ExcelInstallInfo {
	$path = $null
	$version = 'Unknown'

	try {
		$cmd = Get-Command -Name 'excel.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
			$path = $cmd.Source
		}
	}
	catch {
	}

	if ([string]::IsNullOrWhiteSpace($path)) {
		try {
			$appPath = Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe' -ErrorAction SilentlyContinue
			if ($null -ne $appPath -and -not [string]::IsNullOrWhiteSpace($appPath.'(default)')) {
				$path = [string]$appPath.'(default)'
			}
		}
		catch {
		}
	}

	if ([string]::IsNullOrWhiteSpace($path)) {
		try {
			$installRoot = Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction SilentlyContinue
			if ($null -ne $installRoot -and -not [string]::IsNullOrWhiteSpace($installRoot.InstallPath)) {
				$candidate = Join-Path $installRoot.InstallPath 'EXCEL.EXE'
				if (Test-Path -LiteralPath $candidate) {
					$path = $candidate
				}
			}
		}
		catch {
		}
	}

	$installed = $false
	if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
		$installed = $true
		try {
			$version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path).FileVersion
		}
		catch {
			$version = 'Unknown'
		}
	}

	$tooltip = if ($installed) {
		"Version: $version`nPath: $path"
	}
	else {
		'Excel executable not found on this machine.'
	}

	return [pscustomobject]@{
		Installed = $installed
		Path      = $path
		Version   = $version
		ToolTip   = $tooltip
	}
}

function Update-ExcelIndicator {
	param([System.Windows.Controls.TextBlock]$Target)

	if ($null -eq $Target) { return }
	if ($null -eq $script:excelInfo) {
		$script:excelInfo = Get-ExcelInstallInfo
	}

	$Target.Text = if ($script:excelInfo.Installed) { 'Yes' } else { 'No' }
	$Target.ToolTip = $script:excelInfo.ToolTip
}

function Get-ExcelColumnLetter {
	param([int]$Index)

	if ($Index -lt 0) { return '' }

	$result = ''
	$current = $Index
	while ($current -ge 0) {
		$remainder = $current % 26
		$result = [char](65 + $remainder) + $result
		$current = [math]::Floor($current / 26) - 1
	}

	return $result
}

function New-ColumnHeaderText {
	param(
		[Parameter(Mandatory = $true)][string]$Text,
		[double]$FontSize = 11,
		[string]$HorizontalAlignment = 'Center'
	)

	$tb = New-Object System.Windows.Controls.TextBlock
	$tb.Text = $Text
	$tb.FontWeight = [System.Windows.FontWeights]::SemiBold
	$tb.HorizontalAlignment = $HorizontalAlignment
	$tb.TextAlignment = [System.Windows.TextAlignment]::Center
	$tb.FontSize = $FontSize
	$tb.Foreground = [System.Windows.Media.Brushes]::MidnightBlue
	return $tb
}

function New-RowNumberHeader {
	$outer = New-Object System.Windows.Controls.StackPanel
	$outer.Orientation = [System.Windows.Controls.Orientation]::Vertical
	$outer.Margin = '2,0,2,0'

	$top = New-ColumnHeaderText -Text '#' -FontSize 10
	$top.Margin = '0,0,0,2'
	$bottom = New-ColumnHeaderText -Text 'Rows' -HorizontalAlignment 'Center'

	[void]$outer.Children.Add($top)
	[void]$outer.Children.Add($bottom)
	return $outer
}

function New-StackedHeader {
	param(
		[Parameter(Mandatory = $true)][string]$ColumnLetter,
		[Parameter(Mandatory = $true)][string]$Label
	)

	$outer = New-Object System.Windows.Controls.StackPanel
	$outer.Orientation = [System.Windows.Controls.Orientation]::Vertical
	$outer.Margin = '2,0,2,0'

	$top = New-ColumnHeaderText -Text $ColumnLetter -FontSize 10
	$top.Margin = '0,0,0,2'
	$bottom = New-ColumnHeaderText -Text $Label -HorizontalAlignment 'Center'

	[void]$outer.Children.Add($top)
	[void]$outer.Children.Add($bottom)
	return $outer
}

function Apply-GridHeadersMotif {
	param([Parameter(Mandatory = $true)][System.Windows.Controls.DataGrid]$Grid)

	$headerStyle = New-Object System.Windows.Style([System.Windows.Controls.Primitives.DataGridColumnHeader])
	[void]$headerStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BackgroundProperty, $script:gridHeadersBrush)))
	[void]$headerStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::ForegroundProperty, [System.Windows.Media.Brushes]::MidnightBlue)))
	[void]$headerStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderBrushProperty, [System.Windows.Media.Brushes]::SlateBlue)))
	[void]$headerStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderThicknessProperty, (New-Object System.Windows.Thickness(0.5)))))
	[void]$headerStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::PaddingProperty, (New-Object System.Windows.Thickness(4,3,4,3)))))
	$Grid.ColumnHeaderStyle = $headerStyle
}

function Apply-GridBanding {
	param([Parameter(Mandatory = $true)][System.Windows.Controls.DataGrid]$Grid)

	if ($script:useBanding) {
		$Grid.AlternationCount = 2
		$Grid.RowBackground = [System.Windows.Media.Brushes]::White
		$Grid.AlternatingRowBackground = [System.Windows.Media.Brushes]::AliceBlue
	}
	else {
		# Disable row alternation completely when banding is off.
		$Grid.AlternationCount = 0
		$Grid.RowBackground = $null
		$Grid.AlternatingRowBackground = $null
	}
}

function Get-SettingValue {
	param(
		[Parameter(Mandatory = $true)][hashtable]$Settings,
		[Parameter(Mandatory = $true)][string]$Key,
		$DefaultValue
	)

	if ($null -eq $Settings) { return $DefaultValue }
	if ($Settings.ContainsKey($Key) -and $null -ne $Settings[$Key]) {
		return $Settings[$Key]
	}

	return $DefaultValue
}

function Import-CsvTable {
	param([Parameter(Mandatory = $true)][string]$Path)

	$table = New-Object System.Data.DataTable
	$columnNames = @()
	$hasColumns = $false
	$rowIndex = 1
	[void]$table.Columns.Add('__RowNumber', [int])

	foreach ($row in (Import-Csv -LiteralPath $Path)) {
		if (-not $hasColumns) {
			$columnNames = @($row.PSObject.Properties.Name)
			foreach ($name in $columnNames) {
				[void]$table.Columns.Add($name, [string])
			}
			$hasColumns = $true
		}

		$newRow = $table.NewRow()
		$newRow['__RowNumber'] = $rowIndex
		foreach ($name in $columnNames) {
			$newRow[$name] = [string]$row.$name
		}
		[void]$table.Rows.Add($newRow)
		$rowIndex++
	}

	return ,$table
}

function Import-CsvTablePreview {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[int]$MaxRows = 500
	)

	$safeMaxRows = Get-ValidPreviewRowLimit -Value $MaxRows -Default 500
	$table = New-Object System.Data.DataTable
	$columnNames = @()
	$hasColumns = $false
	$rowIndex = 1
	[void]$table.Columns.Add('__RowNumber', [int])

	foreach ($row in (Import-Csv -LiteralPath $Path)) {
		if (-not $hasColumns) {
			$columnNames = @($row.PSObject.Properties.Name)
			foreach ($name in $columnNames) {
				[void]$table.Columns.Add($name, [string])
			}
			$hasColumns = $true
		}

		$newRow = $table.NewRow()
		$newRow['__RowNumber'] = $rowIndex
		foreach ($name in $columnNames) {
			$newRow[$name] = [string]$row.$name
		}
		[void]$table.Rows.Add($newRow)
		$rowIndex++

		if ($table.Rows.Count -ge $safeMaxRows) {
			break
		}
	}

	return [pscustomobject]@{
		Table      = $table
		ShownRows  = $table.Rows.Count
		RowLimit   = $safeMaxRows
		IsCapped   = ($table.Rows.Count -ge $safeMaxRows)
	}
}

function Export-DataTableToCsv {
	param(
		[Parameter(Mandatory = $true)][System.Data.DataTable]$Table,
		[Parameter(Mandatory = $true)][string]$Path
	)

	$columnNames = @($Table.Columns | Where-Object { $_.ColumnName -ne '__RowNumber' } | ForEach-Object { $_.ColumnName })
	$objects = New-Object System.Collections.Generic.List[object]

	foreach ($row in $Table.Rows) {
		$item = [ordered]@{}
		foreach ($name in $columnNames) {
			$item[$name] = [string]$row[$name]
		}
		[void]$objects.Add([pscustomobject]$item)
	}

	$objects | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

function New-FreezeHeader {
	param(
		[Parameter(Mandatory = $true)][string]$ColumnLetter,
		[Parameter(Mandatory = $true)][string]$ColumnName,
		[Parameter(Mandatory = $true)][scriptblock]$OnToggle
	)

	$outer = New-Object System.Windows.Controls.StackPanel
	$outer.Orientation = [System.Windows.Controls.Orientation]::Vertical
	$outer.Margin = '2,0,2,0'

	$letterText = New-ColumnHeaderText -Text $ColumnLetter -FontSize 10
	$letterText.Margin = '0,0,0,2'
	[void]$outer.Children.Add($letterText)

	$stack = New-Object System.Windows.Controls.StackPanel
	$stack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
	$stack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

	$check = New-Object System.Windows.Controls.CheckBox
	$check.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
	$check.ToolTip = 'Freeze this column'
	$check.Margin = '0,0,4,0'

	$text = New-Object System.Windows.Controls.TextBlock
	$text.Text = $ColumnName
	$text.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

	[void]$stack.Children.Add($check)
	[void]$stack.Children.Add($text)

	$check.Add_Checked($OnToggle)
	$check.Add_Unchecked($OnToggle)

	[void]$outer.Children.Add($stack)
	return $outer
}

function Get-HeaderFreezeCheckbox {
	param([System.Windows.Controls.DataGridColumn]$Column)

	if ($null -eq $Column -or $null -eq $Column.Header) { return $null }
	if ($Column.Header -is [System.Windows.Controls.CheckBox]) {
		return $Column.Header
	}
	if ($Column.Header -isnot [System.Windows.Controls.Panel]) { return $null }

	$stack = New-Object System.Collections.Stack
	$stack.Push($Column.Header)

	while ($stack.Count -gt 0) {
		$current = $stack.Pop()
		if ($current -is [System.Windows.Controls.CheckBox]) {
			return $current
		}

		if ($current -is [System.Windows.Controls.Panel]) {
			foreach ($child in $current.Children) {
				if ($null -ne $child) {
					$stack.Push($child)
				}
			}
		}
	}

	return $null
}

function Apply-FrozenColumns {
	param([Parameter(Mandatory = $true)][System.Windows.Controls.DataGrid]$Grid)

	$rowNumberColumn = $null
	$frozen = @()
	$normal = @()

	foreach ($col in ($Grid.Columns | Sort-Object DisplayIndex)) {
		if ([string]$col.SortMemberPath -eq '__RowNumber') {
			$rowNumberColumn = $col
			continue
		}

		$check = Get-HeaderFreezeCheckbox -Column $col
		if ($null -ne $check -and $check.IsChecked) {
			$frozen += $col
		}
		else {
			$normal += $col
		}
	}

	$idx = 0
	$rowColumnCount = 0
	if ($null -ne $rowNumberColumn) {
		$rowNumberColumn.DisplayIndex = 0
		$idx = 1
		$rowColumnCount = 1
	}

	foreach ($col in $frozen) {
		$col.DisplayIndex = $idx
		$idx++
	}
	foreach ($col in $normal) {
		$col.DisplayIndex = $idx
		$idx++
	}

	$Grid.FrozenColumnCount = $frozen.Count + $rowColumnCount
}

function Set-DataGridColumns {
	param(
		[Parameter(Mandatory = $true)][System.Windows.Controls.DataGrid]$Grid,
		[Parameter(Mandatory = $true)][string[]]$ColumnNames,
		[bool]$EnableLogicalScrolling = $false
	)

	$Grid.Columns.Clear()
	Apply-GridHeadersMotif -Grid $Grid
	[System.Windows.Controls.ScrollViewer]::SetCanContentScroll($Grid, $EnableLogicalScrolling)
	$Grid.EnableRowVirtualization = $EnableLogicalScrolling
	$Grid.EnableColumnVirtualization = $EnableLogicalScrolling
	[System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($Grid, $EnableLogicalScrolling)
	[System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($Grid, [System.Windows.Controls.VirtualizationMode]::Recycling)

	$rowCol = New-Object System.Windows.Controls.DataGridTextColumn
	$rowBinding = New-Object System.Windows.Data.Binding
	$rowBinding.Path = New-Object System.Windows.PropertyPath('[__RowNumber]')
	$rowBinding.Mode = [System.Windows.Data.BindingMode]::OneWay
	$rowCol.Binding = $rowBinding
	$rowCol.SortMemberPath = '__RowNumber'
	$rowCol.Header = New-RowNumberHeader
	$rowCol.IsReadOnly = $true
	$rowCol.MinWidth = 60
	$rowCol.Width = 60
	$rowCellStyle = New-Object System.Windows.Style([System.Windows.Controls.TextBlock])
	[void]$rowCellStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Center)))
	[void]$rowCellStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::ForegroundProperty, [System.Windows.Media.Brushes]::MidnightBlue)))
	[void]$rowCellStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::FontWeightProperty, [System.Windows.FontWeights]::SemiBold)))
	$rowCol.ElementStyle = $rowCellStyle
	[void]$Grid.Columns.Add($rowCol)

	$dataColumnNames = @($ColumnNames | Where-Object { $_ -ne '__RowNumber' })
	$letterIndex = 0

	foreach ($name in $dataColumnNames) {
		$col = New-Object System.Windows.Controls.DataGridTextColumn
		$binding = New-Object System.Windows.Data.Binding
		$binding.Path = New-Object System.Windows.PropertyPath("[$name]")
		$binding.Mode = [System.Windows.Data.BindingMode]::TwoWay
		$binding.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
		$col.Binding = $binding
		$col.SortMemberPath = $name
		$col.MinWidth = 90
		$col.Width = New-Object System.Windows.Controls.DataGridLength(140)

		$toggleHandler = {
			param($sender, $args)
			$colForEvent = $sender
			while ($null -ne $colForEvent -and $colForEvent -isnot [System.Windows.Controls.DataGrid]) {
				$colForEvent = [System.Windows.Media.VisualTreeHelper]::GetParent($colForEvent)
			}

			if ($colForEvent -is [System.Windows.Controls.DataGrid]) {
				Apply-FrozenColumns -Grid $colForEvent
			}
		}.GetNewClosure()

		$col.Header = New-FreezeHeader -ColumnLetter (Get-ExcelColumnLetter -Index $letterIndex) -ColumnName $name -OnToggle $toggleHandler
		$letterIndex++
		[void]$Grid.Columns.Add($col)
	}

	Apply-FrozenColumns -Grid $Grid
}

function Get-CsvFileStats {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[switch]$SkipRowCount
	)

	$file = Get-Item -LiteralPath $Path
	$rowCount = if ($SkipRowCount) { 'Pending' } else { 0 }
	$columnCount = 0
	$reader = $null

	try {
		$reader = [System.IO.File]::OpenText($Path)
		$headerLine = $reader.ReadLine()

		if (-not [string]::IsNullOrWhiteSpace($headerLine)) {
			$headerCols = ConvertFrom-Csv -InputObject $headerLine
			if ($null -ne $headerCols) {
				$columnCount = ($headerCols.PSObject.Properties | Measure-Object).Count
			}
		}

		if (-not $SkipRowCount) {
			$lineCount = if ($null -eq $headerLine) { 0 } else { 1 }
			while ($null -ne $reader.ReadLine()) {
				$lineCount++
			}

			if ($lineCount -gt 0) {
				$rowCount = [Math]::Max(0, $lineCount - 1)
			}
		}
	}
	finally {
		if ($null -ne $reader) {
			$reader.Dispose()
		}
	}

	return [pscustomobject]@{
		Name       = $file.Name
		FullPath   = $file.FullName
		LastUpdate = $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
		FileSize   = Convert-ToFileSizeText -Bytes $file.Length
		Rows       = $rowCount
		Columns    = $columnCount
	}
}

function Get-VisualParentOfType {
	param(
		[Parameter(Mandatory = $true)][System.Windows.DependencyObject]$Child,
		[Parameter(Mandatory = $true)][Type]$ParentType
	)

	$current = $Child
	while ($null -ne $current) {
		if ($ParentType.IsInstanceOfType($current)) {
			return $current
		}
		$current = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
	}

	return $null
}

function Convert-CsvToHtml {
	param([Parameter(Mandatory = $true)][string]$CsvPath)

	try {
		$rows = ConvertTo-RowArray -InputObject (Import-Csv -LiteralPath $CsvPath)
		if ($rows.Count -eq 0) { return $null }

		$html = @"
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<style>
		body { font-family: Arial, sans-serif; margin: 20px; }
		table { border-collapse: collapse; width: 100%; }
		th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
		th { background-color: #4CAF50; color: white; }
		tr:nth-child(even) { background-color: #f2f2f2; }
	</style>
	<title>$(Split-Path -Leaf $CsvPath)</title>
</head>
<body>
	<h1>$(Split-Path -Leaf $CsvPath)</h1>
	<table>
"@

		$columnNames = $rows[0].PSObject.Properties.Name
		$html += "\t\t<tr>"
		foreach ($name in $columnNames) {
			$html += "<th>$([System.Web.HttpUtility]::HtmlEncode($name))</th>"
		}
		$html += "</tr>\n"

		foreach ($row in $rows) {
			$html += "\t\t<tr>"
			foreach ($name in $columnNames) {
				$value = [System.Web.HttpUtility]::HtmlEncode([string]$row.$name)
				$html += "<td>$value</td>"
			}
			$html += "</tr>\n"
		}

		$html += @"
	</table>
</body>
</html>
"@

		return $html
	}
	catch {
		return $null
	}
}

function Copy-CsvNamesToClipboard {
	param([Parameter(Mandatory = $true)][object[]]$Items)

	if ($null -eq $Items -or $Items.Count -eq 0) { return }

	$names = @()
	foreach ($item in $Items) {
		if ($null -ne $item.FullPath) {
			$names += ('"' + $item.FullPath + '"')
		}
	}

	if ($names.Count -eq 0) { return }

	$clipboardText = $names -join ', '
	$clipboardText | Set-Clipboard
}

function Get-FreeMemoryText {
	try {
		$totalMemory = (Get-Process -Id $PID | Measure-Object -Property WorkingSet -Sum).Sum
		return Convert-ToFileSizeText -Bytes $totalMemory
	}
	catch {
		return 'N/A'
	}
}

function Get-SelectedCellData {
	param(
		[Parameter(Mandatory = $true)]$DataGrid,
		[Parameter(Mandatory = $true)]$SelectedCells
	)

	$data = @()
	$cellsInfo = @()

	foreach ($cell in $SelectedCells) {
		try {
			$row = $cell.Item
			$column = $cell.Column
			if ($null -eq $row -or $null -eq $column) { continue }

			$columnName = $column.SortMemberPath
			if ([string]::IsNullOrWhiteSpace($columnName)) { continue }

			$value = $row[$columnName]
			$cellsInfo += [pscustomobject]@{
				Column = $columnName
				Value  = $value
			}
		}
		catch {
			continue
		}
	}

	return $cellsInfo
}

function Get-VisibleScreenBounds {
	$aggregate = [System.Windows.Rect]::Empty
	$screens = [System.Windows.Forms.Screen]::AllScreens

	foreach ($screen in $screens) {
		$b = $screen.WorkingArea
		$rect = New-Object System.Windows.Rect([double]$b.Left, [double]$b.Top, [double]$b.Width, [double]$b.Height)
		if ($aggregate.IsEmpty) {
			$aggregate = $rect
		}
		else {
			$aggregate = [System.Windows.Rect]::Union($aggregate, $rect)
		}
	}

	if ($aggregate.IsEmpty) {
		return New-Object System.Windows.Rect(0, 0, 1920, 1080)
	}

	return $aggregate
}

function Restore-MainWindowPlacement {
	param([Parameter(Mandatory = $true)][System.Windows.Window]$Window)

	$bounds = Get-VisibleScreenBounds
	$minWidth = 900.0
	$minHeight = 600.0

	$requestedWidth = [double](Get-SettingValue -Settings $script:appSettings -Key 'MainWindowWidth' -DefaultValue 1360)
	$requestedHeight = [double](Get-SettingValue -Settings $script:appSettings -Key 'MainWindowHeight' -DefaultValue 760)
	$width = [Math]::Max($minWidth, [Math]::Min($requestedWidth, $bounds.Width))
	$height = [Math]::Max($minHeight, [Math]::Min($requestedHeight, $bounds.Height))

	$requestedLeft = Get-SettingValue -Settings $script:appSettings -Key 'MainWindowLeft' -DefaultValue $null
	$requestedTop = Get-SettingValue -Settings $script:appSettings -Key 'MainWindowTop' -DefaultValue $null

	if ($null -eq $requestedLeft -or $null -eq $requestedTop) {
		$left = $bounds.Left + (($bounds.Width - $width) / 2)
		$top = $bounds.Top + (($bounds.Height - $height) / 2)
	}
	else {
		$left = [double]$requestedLeft
		$top = [double]$requestedTop
	}

	$left = [Math]::Max($bounds.Left, [Math]::Min($left, $bounds.Right - $width))
	$top = [Math]::Max($bounds.Top, [Math]::Min($top, $bounds.Bottom - $height))

	$Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
	$Window.Width = $width
	$Window.Height = $height
	$Window.Left = $left
	$Window.Top = $top

	$state = [string](Get-SettingValue -Settings $script:appSettings -Key 'MainWindowState' -DefaultValue 'Normal')
	if ($state -eq 'Maximized') {
		$Window.WindowState = [System.Windows.WindowState]::Maximized
	}
	else {
		$Window.WindowState = [System.Windows.WindowState]::Normal
	}
}

function Save-MainWindowPlacement {
	param([Parameter(Mandatory = $true)][System.Windows.Window]$Window)

	$state = $Window.WindowState
	Set-AppSetting -Key 'MainWindowState' -Value ([string]$state)

	if ($state -eq [System.Windows.WindowState]::Normal) {
		Set-AppSetting -Key 'MainWindowLeft' -Value ([double]$Window.Left)
		Set-AppSetting -Key 'MainWindowTop' -Value ([double]$Window.Top)
		Set-AppSetting -Key 'MainWindowWidth' -Value ([double]$Window.Width)
		Set-AppSetting -Key 'MainWindowHeight' -Value ([double]$Window.Height)
	}
	else {
		Set-AppSetting -Key 'MainWindowLeft' -Value ([double]$Window.RestoreBounds.Left)
		Set-AppSetting -Key 'MainWindowTop' -Value ([double]$Window.RestoreBounds.Top)
		Set-AppSetting -Key 'MainWindowWidth' -Value ([double]$Window.RestoreBounds.Width)
		Set-AppSetting -Key 'MainWindowHeight' -Value ([double]$Window.RestoreBounds.Height)
	}
}

function Get-PreviewSelectionSnapshot {
	param([Parameter(Mandatory = $true)][System.Windows.Controls.DataGrid]$Grid)

	$snapshot = New-Object System.Collections.Generic.List[object]
	foreach ($cellInfo in @($Grid.SelectedCells)) {
		if ($null -eq $cellInfo.Item -or $null -eq $cellInfo.Column) { continue }
		$columnName = [string]$cellInfo.Column.SortMemberPath
		if ([string]::IsNullOrWhiteSpace($columnName)) { continue }

		try {
			$rowNumber = [int]$cellInfo.Item['__RowNumber']
			[void]$snapshot.Add([pscustomobject]@{ RowNumber = $rowNumber; ColumnName = $columnName })
		}
		catch {
		}
	}

	return @($snapshot)
}

function Restore-PreviewSelectionSnapshot {
	param(
		[Parameter(Mandatory = $true)][System.Windows.Controls.DataGrid]$Grid,
		[Parameter(Mandatory = $true)][object[]]$Snapshot
	)

	if ($null -eq $Snapshot -or $Snapshot.Count -eq 0) { return }

	$rowViewByRowNumber = @{}
	foreach ($rowView in @($Grid.ItemsSource)) {
		try {
			$rowViewByRowNumber[[int]$rowView['__RowNumber']] = $rowView
		}
		catch {
		}
	}

	$columnByName = @{}
	foreach ($col in @($Grid.Columns)) {
		$name = [string]$col.SortMemberPath
		if (-not [string]::IsNullOrWhiteSpace($name)) {
			$columnByName[$name] = $col
		}
	}

	try { $Grid.SelectedCells.Clear() } catch { }

	foreach ($s in $Snapshot) {
		if ($null -eq $s) { continue }
		$rowNumber = [int]$s.RowNumber
		$columnName = [string]$s.ColumnName
		if (-not $rowViewByRowNumber.ContainsKey($rowNumber)) { continue }
		if (-not $columnByName.ContainsKey($columnName)) { continue }

		$cellInfo = New-Object System.Windows.Controls.DataGridCellInfo($rowViewByRowNumber[$rowNumber], $columnByName[$columnName])
		[void]$Grid.SelectedCells.Add($cellInfo)
	}
}

function Get-ChartDataFromSelectedCells {
	param([Parameter(Mandatory = $true)][System.Windows.Controls.DataGrid]$Grid)

	$selectedCells = @($Grid.SelectedCells)
	if ($selectedCells.Count -eq 0) { return @() }

	$chartData = Get-SelectedCellData -DataGrid $Grid -SelectedCells $selectedCells
	if ($chartData.Count -gt 0) { return $chartData }

	# Fallback to keep non-numeric data visible in charts like pie category labels.
	$fallback = New-Object System.Collections.Generic.List[object]
	foreach ($cellInfo in $selectedCells) {
		if ($null -eq $cellInfo.Item -or $null -eq $cellInfo.Column) { continue }
		$name = [string]$cellInfo.Column.SortMemberPath
		if ([string]::IsNullOrWhiteSpace($name)) { continue }
		$value = ''
		try { $value = [string]$cellInfo.Item[$name] } catch { $value = '' }
		[void]$fallback.Add([pscustomobject]@{ Column = $name; Value = $value })
	}

	return @($fallback)
}

function Get-SortableTimestamp {
	return (Get-Date).ToString('yyyyMMdd_HHmmss')
}

function Show-ChartWindow {
	param(
		[Parameter(Mandatory = $true)]$ChartData,
		[Parameter(Mandatory = $true)][string]$ChartType,
		[Parameter(Mandatory = $true)][string]$SourceCsvPath,
		[Parameter(Mandatory = $true)][bool]$ExcelInstalled
	)

	try {
		$chartXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Chart Viewer - $ChartType" Height="600" Width="900" WindowStartupLocation="CenterScreen">
	<Grid Margin="10">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<TextBlock Grid.Row="0" FontSize="16" FontWeight="Bold" Margin="0,0,0,10" Text="Chart: $ChartType"/>

		<Grid Grid.Row="1">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="2*"/>
				<ColumnDefinition Width="*"/>
			</Grid.ColumnDefinitions>

			<Border Grid.Column="0" BorderBrush="Gray" BorderThickness="1" Background="White" Margin="0,0,10,0">
				<ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
					<Canvas x:Name="chartCanvas" Width="500" Height="400" Background="White"/>
				</ScrollViewer>
			</Border>

			<StackPanel Grid.Column="1">
				<TextBlock Text="Legend &amp; Details" FontWeight="SemiBold" FontSize="14" Margin="0,0,0,8"/>
				<Border BorderBrush="Gray" BorderThickness="1" Padding="8" Background="WhiteSmoke">
					<ScrollViewer VerticalScrollBarVisibility="Auto" MaxHeight="400">
						<TextBlock x:Name="txtLegend" TextWrapping="Wrap" FontFamily="Consolas" FontSize="11"/>
					</ScrollViewer>
				</Border>
			</StackPanel>
		</Grid>

		<StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
			<Button x:Name="btnCopyChart" Content="Copy to Clipboard" Width="140" Margin="0,0,8,0" ToolTip="Copy chart data to clipboard"/>
			<Button x:Name="btnCreateExcel" Content="Create in Excel" Width="140" Margin="0,0,8,0" ToolTip="Create Excel file with chart"/>
			<Button x:Name="btnCloseChart" Content="Close" Width="100" ToolTip="Close chart window"/>
		</StackPanel>
	</Grid>
</Window>
"@

		$reader = New-Object System.Xml.XmlNodeReader ([xml]$chartXaml)
		$chartWindow = [Windows.Markup.XamlReader]::Load($reader)

		$chartCanvas = $chartWindow.FindName('chartCanvas')
		$txtLegend = $chartWindow.FindName('txtLegend')
		$btnCopyChart = $chartWindow.FindName('btnCopyChart')
		$btnCreateExcel = $chartWindow.FindName('btnCreateExcel')
		$btnCloseChart = $chartWindow.FindName('btnCloseChart')

		# Enable/disable Excel button
		$btnCreateExcel.IsEnabled = $ExcelInstalled

		# Build legend text
		$legendText = "Chart Type: $ChartType`n"
		$legendText += "Data Points: $($ChartData.Count)`n"
		$legendText += "Source: $([System.IO.Path]::GetFileName($SourceCsvPath))`n`n"
		$legendText += "Selected Data:`n"
		$legendText += "-" * 40 + "`n"

		foreach ($item in $ChartData) {
			$legendText += "$($item.Column): $($item.Value)`n"
		}

		$txtLegend.Text = $legendText

		# Draw simple chart visualization
		Draw-SimpleChart -Canvas $chartCanvas -ChartData $ChartData -ChartType $ChartType

		# Copy to Clipboard handler
		$btnCopyChart.Add_Click({
			try {
				$clipText = "Chart Data - $ChartType`n"
				$clipText += "=" * 50 + "`n"
				foreach ($item in $ChartData) {
					$clipText += "$($item.Column)`t$($item.Value)`n"
				}
				$clipText | Set-Clipboard
				[System.Windows.MessageBox]::Show('Chart data copied to clipboard.', 'Success', 'OK', 'Information') | Out-Null
			}
			catch {
				[System.Windows.MessageBox]::Show("Copy failed: $($_.Exception.Message)", 'Error', 'OK', 'Error') | Out-Null
			}
		}.GetNewClosure())

		# Create in Excel handler
		$btnCreateExcel.Add_Click({
			try {
				$baseName = [System.IO.Path]::GetFileNameWithoutExtension($SourceCsvPath)
				$directory = [System.IO.Path]::GetDirectoryName($SourceCsvPath)
				$chartTypeClean = $ChartType -replace '\s+', ''
				$timestamp = Get-SortableTimestamp
				$excelFileName = "${baseName}_${chartTypeClean}_${timestamp}.xlsx"
				$excelPath = Join-Path $directory $excelFileName

				Create-ExcelWithChart -ChartData $ChartData -ChartType $ChartType -OutputPath $excelPath
				[System.Windows.MessageBox]::Show("Excel file created:`n$excelPath", 'Success', 'OK', 'Information') | Out-Null

				# Open the file
				Start-Process -FilePath $excelPath
			}
			catch {
				[System.Windows.MessageBox]::Show("Excel creation failed: $($_.Exception.Message)", 'Error', 'OK', 'Error') | Out-Null
			}
		}.GetNewClosure())

		# Close handler
		$btnCloseChart.Add_Click({ $chartWindow.Close() }.GetNewClosure())

		[void]$chartWindow.ShowDialog()
	}
	catch {
		Write-AppLog -Message "Show-ChartWindow failed" -Exception $_.Exception
		[System.Windows.MessageBox]::Show(
			"Unable to show chart window. Details were written to:`n$script:logPath`n`n$($_.Exception.Message)",
			'Chart Error',
			'OK',
			'Error'
		) | Out-Null
	}
}

function Draw-SimpleChart {
	param(
		[Parameter(Mandatory = $true)]$Canvas,
		[Parameter(Mandatory = $true)]$ChartData,
		[Parameter(Mandatory = $true)][string]$ChartType
	)

	try {
		$Canvas.Children.Clear()

		# Get numeric values
		$values = @()
		$labels = @()
		foreach ($item in $ChartData) {
			$numValue = 0
			if ([double]::TryParse($item.Value, [ref]$numValue)) {
				$values += $numValue
				$labels += $item.Column
			}
		}

		if ($values.Count -eq 0) {
			$text = New-Object System.Windows.Controls.TextBlock
			$text.Text = "No numeric data to chart"
			$text.FontSize = 16
			$text.Foreground = [System.Windows.Media.Brushes]::Gray
			[System.Windows.Controls.Canvas]::SetLeft($text, 150)
			[System.Windows.Controls.Canvas]::SetTop($text, 180)
			[void]$Canvas.Children.Add($text)
			return
		}

		$width = $Canvas.Width
		$height = $Canvas.Height
		$colors = @([System.Windows.Media.Brushes]::SteelBlue, [System.Windows.Media.Brushes]::Coral,
					[System.Windows.Media.Brushes]::MediumSeaGreen, [System.Windows.Media.Brushes]::Gold,
					[System.Windows.Media.Brushes]::Orchid, [System.Windows.Media.Brushes]::Tomato)

		switch ($ChartType) {
			{ $_ -in 'Pie', 'Pie Exploded' } {
				$centerX = $width / 2
				$centerY = $height / 2
				$radius = [Math]::Min($width, $height) / 3
				$total = ($values | Measure-Object -Sum).Sum
				$startAngle = -90

				if ($total -le 0) {
					$text = New-Object System.Windows.Controls.TextBlock
					$text.Text = "No positive numeric data to chart"
					$text.FontSize = 16
					$text.Foreground = [System.Windows.Media.Brushes]::Gray
					[System.Windows.Controls.Canvas]::SetLeft($text, 120)
					[System.Windows.Controls.Canvas]::SetTop($text, 180)
					[void]$Canvas.Children.Add($text)
					return
				}

				for ($i = 0; $i -lt $values.Count; $i++) {
					$value = $values[$i]
					if ($value -le 0) { continue }
					$angle = ($value / $total) * 360
					$endAngle = $startAngle + $angle

					$startRadians = $startAngle * [Math]::PI / 180
					$endRadians = $endAngle * [Math]::PI / 180

					$startX = $centerX + ($radius * [Math]::Cos($startRadians))
					$startY = $centerY + ($radius * [Math]::Sin($startRadians))
					$endX = $centerX + ($radius * [Math]::Cos($endRadians))
					$endY = $centerY + ($radius * [Math]::Sin($endRadians))

					$isLargeArc = $angle -gt 180

					$figure = New-Object System.Windows.Media.PathFigure
					$figure.StartPoint = New-Object System.Windows.Point($centerX, $centerY)
					[void]$figure.Segments.Add((New-Object System.Windows.Media.LineSegment((New-Object System.Windows.Point($startX, $startY)), $true)))
					[void]$figure.Segments.Add((New-Object System.Windows.Media.ArcSegment(
						(New-Object System.Windows.Point($endX, $endY)),
						(New-Object System.Windows.Size($radius, $radius)),
						0,
						$isLargeArc,
						[System.Windows.Media.SweepDirection]::Clockwise,
						$true
					)))
					[void]$figure.Segments.Add((New-Object System.Windows.Media.LineSegment((New-Object System.Windows.Point($centerX, $centerY)), $true)))
					$figure.IsClosed = $true

					$geometry = New-Object System.Windows.Media.PathGeometry
					[void]$geometry.Figures.Add($figure)

					$path = New-Object System.Windows.Shapes.Path
					$path.Data = $geometry
					$path.Fill = $colors[$i % $colors.Count]
					$path.Stroke = [System.Windows.Media.Brushes]::White
					$path.StrokeThickness = 1.25
					[void]$Canvas.Children.Add($path)

					$startAngle = $endAngle
				}

				$outline = New-Object System.Windows.Shapes.Ellipse
				$outline.Width = $radius * 2
				$outline.Height = $radius * 2
				$outline.Stroke = [System.Windows.Media.Brushes]::DimGray
				$outline.StrokeThickness = 1
				$outline.Fill = [System.Windows.Media.Brushes]::Transparent
				[System.Windows.Controls.Canvas]::SetLeft($outline, $centerX - $radius)
				[System.Windows.Controls.Canvas]::SetTop($outline, $centerY - $radius)
				[void]$Canvas.Children.Add($outline)
			}
			{ $_ -in 'Bar', 'Stacked Bar' } {
				$maxValue = ($values | Measure-Object -Maximum).Maximum
				$barWidth = 40
				$spacing = 60
				$chartHeight = $height - 80

				for ($i = 0; $i -lt $values.Count; $i++) {
					$value = $values[$i]
					$barHeight = ($value / $maxValue) * $chartHeight
					$x = 50 + ($i * $spacing)
					$y = $height - 50 - $barHeight

					$rect = New-Object System.Windows.Shapes.Rectangle
					$rect.Width = $barWidth
					$rect.Height = $barHeight
					$rect.Fill = $colors[$i % $colors.Count]
					[System.Windows.Controls.Canvas]::SetLeft($rect, $x)
					[System.Windows.Controls.Canvas]::SetTop($rect, $y)
					[void]$Canvas.Children.Add($rect)

					# Label
					$text = New-Object System.Windows.Controls.TextBlock
					$text.Text = $value.ToString('N0')
					$text.FontSize = 10
					[System.Windows.Controls.Canvas]::SetLeft($text, $x + 5)
					[System.Windows.Controls.Canvas]::SetTop($text, $y - 20)
					[void]$Canvas.Children.Add($text)
				}
			}
			{ $_ -in 'Line', 'Scatter' } {
				$maxValue = ($values | Measure-Object -Maximum).Maximum
				$chartHeight = $height - 80
				$chartWidth = $width - 100
				$stepX = $chartWidth / [Math]::Max(1, ($values.Count - 1))

				for ($i = 0; $i -lt $values.Count; $i++) {
					$value = $values[$i]
					$x = 50 + ($i * $stepX)
					$y = $height - 50 - (($value / $maxValue) * $chartHeight)

					$ellipse = New-Object System.Windows.Shapes.Ellipse
					$ellipse.Width = 8
					$ellipse.Height = 8
					$ellipse.Fill = $colors[0]
					[System.Windows.Controls.Canvas]::SetLeft($ellipse, $x - 4)
					[System.Windows.Controls.Canvas]::SetTop($ellipse, $y - 4)
					[void]$Canvas.Children.Add($ellipse)

					# Draw line to next point
					if ($i -lt $values.Count - 1 -and $ChartType -eq 'Line') {
						$nextValue = $values[$i + 1]
						$nextX = 50 + (($i + 1) * $stepX)
						$nextY = $height - 50 - (($nextValue / $maxValue) * $chartHeight)

						$line = New-Object System.Windows.Shapes.Line
						$line.X1 = $x
						$line.Y1 = $y
						$line.X2 = $nextX
						$line.Y2 = $nextY
						$line.Stroke = $colors[0]
						$line.StrokeThickness = 2
						[void]$Canvas.Children.Add($line)
					}
				}
			}
		}
	}
	catch {
		Write-AppLog -Message "Draw-SimpleChart failed" -Exception $_.Exception
	}
}

function Create-ExcelWithChart {
	param(
		[Parameter(Mandatory = $true)]$ChartData,
		[Parameter(Mandatory = $true)][string]$ChartType,
		[Parameter(Mandatory = $true)][string]$OutputPath
	)

	$excel = $null
	$workbook = $null
	$worksheet = $null

	try {
		# Create Excel COM object
		$excel = New-Object -ComObject Excel.Application
		$excel.Visible = $false
		$excel.DisplayAlerts = $false

		# Create new workbook
		$workbook = $excel.Workbooks.Add()
		$worksheet = $workbook.Worksheets.Item(1)
		$worksheet.Name = "Chart Data"

		# Write headers
		$worksheet.Cells.Item(1, 1) = "Column"
		$worksheet.Cells.Item(1, 2) = "Value"

		# Write data
		$row = 2
		foreach ($item in $ChartData) {
			$worksheet.Cells.Item($row, 1) = $item.Column
			$worksheet.Cells.Item($row, 2) = $item.Value
			$row++
		}

		# Auto-fit columns
		$worksheet.Columns.Item(1).AutoFit() | Out-Null
		$worksheet.Columns.Item(2).AutoFit() | Out-Null

		# Add chart
		$chartStartRow = $row + 2
		$dataRange = $worksheet.Range($worksheet.Cells.Item(2, 1), $worksheet.Cells.Item($row - 1, 2))

		$chartObject = $worksheet.Shapes.AddChart2().Chart
		$chartObject.SetSourceData($dataRange)

		# Set chart type
		$xlChartType = switch ($ChartType) {
			'Pie' { 5 } # xlPie
			'Pie Exploded' { 69 } # xl3DPieExploded
			'Bar' { 57 } # xlColumnClustered
			'Stacked Bar' { 58 } # xlColumnStacked
			'Line' { 4 } # xlLine
			'Scatter' { 73 } # xlXYScatter
			default { 5 }
		}
		$chartObject.ChartType = $xlChartType

		# Save and close
		$workbook.SaveAs($OutputPath)
		$workbook.Close($false)
		$excel.Quit()
	}
	catch {
		throw
	}
	finally {
		# Clean up COM objects
		if ($null -ne $worksheet) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($worksheet) | Out-Null }
		if ($null -ne $workbook) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null }
		if ($null -ne $excel) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null }
		[System.GC]::Collect()
		[System.GC]::WaitForPendingFinalizers()
	}
}

function Show-EditorWindow {
	param(
		[Parameter(Mandatory = $true)][string]$CsvPath,
		[Parameter(Mandatory = $true)][scriptblock]$OnSaved
	)

	try {

	$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="CSV Editor - Inline Editing" Height="700" Width="1200" WindowStartupLocation="CenterOwner">
	<Grid Margin="10">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<DockPanel Grid.Row="0" Margin="0,0,0,8">
			<StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
				<TextBlock Text="Excel Installed: " VerticalAlignment="Center" Margin="0,0,4,0" FontWeight="SemiBold"/>
				<TextBlock x:Name="txtEditExcelInstalled" Text="No" VerticalAlignment="Center" Margin="0,0,10,0" ToolTip="Excel detection details"/>
				<Button x:Name="btnEditZoomOut" Content="-" Width="36" Margin="0,0,6,0" ToolTip="Zoom out editor grid"/>
				<Button x:Name="btnEditZoomIn" Content="+" Width="36" ToolTip="Zoom in editor grid"/>
			</StackPanel>
			<TextBlock x:Name="txtPath" FontWeight="Bold" FontSize="18" TextWrapping="Wrap" ToolTip="Full path for the file currently open in editor"/>
		</DockPanel>

		<DataGrid x:Name="editGrid" Grid.Row="1"
				  AutoGenerateColumns="False"
				  CanUserAddRows="False"
				  CanUserDeleteRows="True"
				  CanUserReorderColumns="True"
				  CanUserResizeColumns="True"
				  IsReadOnly="False"
				  HorizontalScrollBarVisibility="Auto"
				  VerticalScrollBarVisibility="Auto"
				  EnableColumnVirtualization="False"
				  SelectionUnit="CellOrRowHeader"
				  FrozenColumnCount="0"
				  ToolTip="Inline CSV editor. Use header checkboxes to freeze columns on the left."/>

		<StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
			<TextBlock x:Name="txtChangedCount" Text="Changed Cells: 0" VerticalAlignment="Center" Margin="0,0,12,0" FontWeight="SemiBold" ToolTip="Count of edited cells currently highlighted in purple"/>
			<Button x:Name="btnSave" Content="Save" Width="110" Margin="0,0,8,0" ToolTip="Save all edits back to this CSV file"/>
			<Button x:Name="btnRevert" Content="Revert" Width="110" Margin="0,0,8,0" ToolTip="Revert edits to the last saved state" IsEnabled="False"/>
			<Button x:Name="btnExcel" Content="Open in Excel" Width="130" Margin="0,0,8,0" ToolTip="Open this file in Excel (or default associated app)"/>
			<Button x:Name="btnClose" Content="Close" Width="110" ToolTip="Close this editor window (you will be prompted to Save or Revert if needed)"/>
		</StackPanel>

		<StatusBar Grid.Row="3" Margin="0,8,0,0" ToolTip="Editor status with table and process memory details">
			<StatusBarItem>
				<TextBlock x:Name="txtEditStatus" Text="Ready"/>
			</StatusBarItem>
		</StatusBar>
	</Grid>
</Window>
"@

	$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
	$window = [Windows.Markup.XamlReader]::Load($reader)

	$txtPath = $window.FindName('txtPath')
	$editGrid = $window.FindName('editGrid')
	$btnSave = $window.FindName('btnSave')
	$btnRevert = $window.FindName('btnRevert')
	$btnExcel = $window.FindName('btnExcel')
	$btnClose = $window.FindName('btnClose')
	$btnEditZoomOut = $window.FindName('btnEditZoomOut')
	$btnEditZoomIn = $window.FindName('btnEditZoomIn')
	$txtEditStatus = $window.FindName('txtEditStatus')
	$txtChangedCount = $window.FindName('txtChangedCount')
	$txtEditExcelInstalled = $window.FindName('txtEditExcelInstalled')
	Update-ExcelIndicator -Target $txtEditExcelInstalled

	# Show wait cursor while loading CSV data
	$loadStartTime = [DateTime]::UtcNow
	[System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
	$window.Dispatcher.Invoke([Action]{ }, [System.Windows.Threading.DispatcherPriority]::Background)

	try {
		$txtPath.Text = "INLINE EDIT File: $([System.IO.Path]::GetFileName($CsvPath))"
		$txtPath.FontWeight = [System.Windows.FontWeights]::Bold
		$txtPath.FontSize = 18
		$workingTable = Import-CsvTable -Path $CsvPath
		$baselineTable = $workingTable.Copy()
		$editedCellBrush = [System.Windows.Media.Brushes]::Purple
		$editedTextBrush = [System.Windows.Media.Brushes]::White
		$originalCellValues = @{}
		$editedCellKeys = New-Object System.Collections.Generic.HashSet[string]
		$hasUnsavedChanges = $false
		$fileInfo = Get-Item -LiteralPath $CsvPath
	}
	finally {
		# Ensure wait cursor is shown for at least 250ms for user feedback
		$elapsedMs = ([DateTime]::UtcNow - $loadStartTime).TotalMilliseconds
		if ($elapsedMs -lt 250) {
			Start-Sleep -Milliseconds ([int]([Math]::Ceiling(250 - $elapsedMs)))
		}
	}

	$updateChangedCellCount = {
		$txtChangedCount.Text = "Changed Cells: $($editedCellKeys.Count)"
	}.GetNewClosure()

	$updateEditorStatus = {
		try {
			if ($null -eq $txtEditStatus -or $null -eq $txtEditExcelInstalled -or $null -eq $workingTable -or $null -eq $fileInfo) { return }

			$memText = 'N/A'
			try {
				$proc = Get-Process -Id $PID -ErrorAction Stop
				$memText = Convert-ToFileSizeText -Bytes $proc.WorkingSet64
			}
			catch {
				$memText = 'N/A'
			}

			$excelInstalled = [string]$txtEditExcelInstalled.Text
			$txtEditStatus.Text = "Rows: $($workingTable.Rows.Count) | Columns: $($workingTable.Columns.Count) | File Size: $(Convert-ToFileSizeText -Bytes $fileInfo.Length) | Excel Installed: $excelInstalled | PowerShell Memory: $memText"
		}
		catch {
			# Silently ignore errors during window teardown
		}
	}.GetNewClosure()

	$setDirtyState = {
		param([bool]$IsDirty)
		try {
			$hasUnsavedChanges = $IsDirty
			if ($null -ne $btnRevert) {
				$btnRevert.IsEnabled = $hasUnsavedChanges
			}
			if ($null -ne $updateChangedCellCount) {
				& $updateChangedCellCount
			}
			& $updateEditorStatus
		}
		catch {
			# Silently ignore errors during window teardown
		}
	}.GetNewClosure()

	$applyEditedHighlights = {
		try {
			if ($null -eq $editGrid -or $null -eq $editGrid.Items -or $null -eq $editGrid.Columns) { return }
			if ($null -eq $editedCellKeys) { return }

			for ($i = 0; $i -lt $editGrid.Items.Count; $i++) {
				$rowObj = $editGrid.ItemContainerGenerator.ContainerFromIndex($i)
				if ($null -eq $rowObj) { continue }

				foreach ($column in $editGrid.Columns) {
					$columnName = [string]$column.SortMemberPath
					if ([string]::IsNullOrWhiteSpace($columnName)) { continue }

					$key = "$i|$columnName"
					$cellContent = $column.GetCellContent($rowObj)
					if ($null -eq $cellContent) { continue }

					$cell = Get-VisualParentOfType -Child $cellContent -ParentType ([System.Windows.Controls.DataGridCell])
					if ($null -eq $cell) { continue }

					if ($editedCellKeys.Contains($key)) {
						$cell.Background = $editedCellBrush
						$cell.Foreground = $editedTextBrush
					}
					else {
						$cell.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
						$cell.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
					}
				}
			}
		}
		catch {
			# Silently ignore errors during window teardown
		}
	}.GetNewClosure()

	$saveCurrentChanges = {
		try {
			Export-DataTableToCsv -Table $workingTable -Path $CsvPath
			$baselineTable = $workingTable.Copy()
			$originalCellValues.Clear()
			$editedCellKeys.Clear()
			$fileInfo = Get-Item -LiteralPath $CsvPath
			$editGrid.Items.Refresh()
			& $setDirtyState $false
			& $OnSaved
			return $true
		}
		catch {
			[System.Windows.MessageBox]::Show($_.Exception.Message, 'Save Error', 'OK', 'Error') | Out-Null
			return $false
		}
	}.GetNewClosure()

	if ($workingTable.Columns.Count -gt 0) {
		Set-DataGridColumns -Grid $editGrid -ColumnNames @($workingTable.Columns | ForEach-Object { $_.ColumnName })
	}

	$editGrid.ItemsSource = $workingTable.DefaultView
	$script:editorFontSize = Get-ValidFontSize -Value $script:editorFontSize -Default 12
	$editGrid.FontSize = $script:editorFontSize
	[System.Windows.Controls.ScrollViewer]::SetCanContentScroll($editGrid, $false)
	Apply-GridHeadersMotif -Grid $editGrid
	Apply-GridBanding -Grid $editGrid
	$window.Tag = $editGrid
	& $updateChangedCellCount
	& $updateEditorStatus

	# Clear wait cursor after loading is complete
	[System.Windows.Input.Mouse]::OverrideCursor = $null

	$revertToBaseline = {
		param([bool]$UseWaitCursor = $false)

		if ($UseWaitCursor) {
			[System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
			$window.Dispatcher.Invoke([Action]{ }, [System.Windows.Threading.DispatcherPriority]::Background)
		}

		try {
			if ($null -eq $baselineTable -or $null -eq $editGrid) { return }

			$workingTable = $baselineTable.Copy()
			if ($workingTable.Columns.Count -gt 0) {
				Set-DataGridColumns -Grid $editGrid -ColumnNames @($workingTable.Columns | ForEach-Object { $_.ColumnName })
			}
			$editGrid.ItemsSource = $workingTable.DefaultView
			$script:editorFontSize = 12
			$editGrid.FontSize = $script:editorFontSize
			Set-AppSetting -Key 'EditorZoom' -Value $script:editorFontSize
			Save-AppSettings -Settings $script:appSettings
			Apply-GridHeadersMotif -Grid $editGrid
			Apply-GridBanding -Grid $editGrid
			if ($null -ne $originalCellValues) { $originalCellValues.Clear() }
			if ($null -ne $editedCellKeys) { $editedCellKeys.Clear() }
			$editGrid.Items.Refresh()
			& $applyEditedHighlights
			& $setDirtyState $false
		}
		catch {
			# Silently ignore errors during window teardown
		}
		finally {
			if ($UseWaitCursor) {
				[System.Windows.Input.Mouse]::OverrideCursor = $null
			}
		}
	}.GetNewClosure()

	$memoryTimer = New-Object System.Windows.Threading.DispatcherTimer
	$memoryTimer.Interval = [TimeSpan]::FromSeconds(2)
	$memoryTimer.Add_Tick({
		if ($window.IsLoaded -and $window.IsVisible) {
			& $updateEditorStatus
		}
	}.GetNewClosure())
	$memoryTimer.Start()

	$editGrid.Add_LayoutUpdated({ & $applyEditedHighlights }.GetNewClosure())

	$editGrid.Add_BeginningEdit({
		param($sender, $e)

		if ($null -eq $e.Row -or $null -eq $e.Column) { return }
		if ($null -eq $e.Row.Item) { return }
		$rowIndex = $e.Row.GetIndex()
		$columnName = [string]$e.Column.SortMemberPath
		if ([string]::IsNullOrWhiteSpace($columnName)) { return }

		$key = "$rowIndex|$columnName"
		try {
			$originalCellValues[$key] = [string]$e.Row.Item[$columnName]
		}
		catch {
			$originalCellValues[$key] = ''
		}
	}.GetNewClosure())

	$editGrid.Add_CellEditEnding({
		param($sender, $e)

		if ($e.EditAction -ne [System.Windows.Controls.DataGridEditAction]::Commit) { return }
		if ($null -eq $e.Row -or $null -eq $e.Column) { return }
		if ($null -eq $e.Row.Item) { return }

		$rowIndex = $e.Row.GetIndex()
		$columnName = [string]$e.Column.SortMemberPath
		if ([string]::IsNullOrWhiteSpace($columnName)) { return }

		$key = "$rowIndex|$columnName"
		$oldValue = ''
		if ($originalCellValues.ContainsKey($key)) {
			$oldValue = [string]$originalCellValues[$key]
		}

		$newValue = ''
		if ($e.EditingElement -is [System.Windows.Controls.TextBox]) {
			$newValue = [string]$e.EditingElement.Text
		}
		else {
			try {
				$newValue = [string]$e.Row.Item[$columnName]
			}
			catch {
				$newValue = ''
			}
		}
		if ($oldValue -ne $newValue) {
			[void]$editedCellKeys.Add($key)
		}
		else {
			if ($editedCellKeys.Contains($key)) {
				[void]$editedCellKeys.Remove($key)
			}
		}
		& $setDirtyState ($editedCellKeys.Count -gt 0)

		if ($originalCellValues.ContainsKey($key)) {
			[void]$originalCellValues.Remove($key)
		}

		$editGrid.Dispatcher.BeginInvoke(
			[System.Action]{ & $applyEditedHighlights },
			[System.Windows.Threading.DispatcherPriority]::Background
		) | Out-Null
	}.GetNewClosure())

	$editGrid.Add_LoadingRow({ & $applyEditedHighlights }.GetNewClosure())

	$btnSave.Add_Click({
		if (& $saveCurrentChanges) {
			$editGrid.Items.Refresh()
			& $applyEditedHighlights
			[System.Windows.MessageBox]::Show('Saved successfully.', 'CSV Editor', 'OK', 'Information') | Out-Null
		}
	}.GetNewClosure())

	$btnRevert.Add_Click({
		& $revertToBaseline $true
	}.GetNewClosure())

	$btnExcel.Add_Click({
		try {
			Start-Process -FilePath 'excel.exe' -ArgumentList @("`"$CsvPath`"") | Out-Null
		}
		catch {
			Start-Process -FilePath $CsvPath | Out-Null
		}
	}.GetNewClosure())

	$btnEditZoomIn.Add_Click({
		try {
			Ensure-AppSettings
			$current = [int][Math]::Round([double]$editGrid.FontSize)
			$script:editorFontSize = Get-ValidFontSize -Value ([Math]::Min([Math]::Max($current, 8) + 1, 28)) -Default 12
			$editGrid.FontSize = $script:editorFontSize
			Set-AppSetting -Key 'EditorZoom' -Value $script:editorFontSize
			Save-AppSettings -Settings $script:appSettings
			& $updateEditorStatus
		}
		catch {
			$txtEditStatus.Text = "Zoom error: $($_.Exception.Message)"
		}
	}.GetNewClosure())

	$btnEditZoomOut.Add_Click({
		try {
			Ensure-AppSettings
			$current = [int][Math]::Round([double]$editGrid.FontSize)
			$script:editorFontSize = Get-ValidFontSize -Value ([Math]::Max([Math]::Max($current, 8) - 1, 8)) -Default 12
			$editGrid.FontSize = $script:editorFontSize
			Set-AppSetting -Key 'EditorZoom' -Value $script:editorFontSize
			Save-AppSettings -Settings $script:appSettings
			& $updateEditorStatus
		}
		catch {
			$txtEditStatus.Text = "Zoom error: $($_.Exception.Message)"
		}
	}.GetNewClosure())

	$btnClose.Add_Click({ $window.Close() }.GetNewClosure())

	$window.Add_Closing({
		param($sender, $e)

		$timerWasRunning = $false
		if ($null -ne $memoryTimer) {
			try {
				$timerWasRunning = $memoryTimer.IsEnabled
				if ($timerWasRunning) {
					$memoryTimer.Stop()
				}
			}
			catch {
			}
		}

		if (-not $hasUnsavedChanges) { return }

		$result = [System.Windows.MessageBox]::Show(
			'You have unsaved changes. Choose Yes to Save, No to Revert/Discard, or Cancel to stay open.',
			'Unsaved Changes',
			[System.Windows.MessageBoxButton]::YesNoCancel,
			[System.Windows.MessageBoxImage]::Question
		)

		if ($result -eq [System.Windows.MessageBoxResult]::Cancel) {
			$e.Cancel = $true
			if ($timerWasRunning -and $null -ne $memoryTimer) {
				try { $memoryTimer.Start() } catch { }
			}
			return
		}

		if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
			if (-not (& $saveCurrentChanges)) {
				$e.Cancel = $true
				if ($timerWasRunning -and $null -ne $memoryTimer) {
					try { $memoryTimer.Start() } catch { }
				}
			}
			return
		}

		if ($result -eq [System.Windows.MessageBoxResult]::No) {
			& $revertToBaseline $false
		}
	}.GetNewClosure())

	$window.Add_Closed({
		if ($null -ne $memoryTimer) {
			try {
				if ($memoryTimer.IsEnabled) {
					$memoryTimer.Stop()
				}
			}
			catch {
			}
		}

		if ($null -ne $script:editorWindows -and $null -ne $window) {
			try {
				[void]$script:editorWindows.Remove($window)
			}
			catch {
			}
		}
	}.GetNewClosure())

	[void]$script:editorWindows.Add($window)
	[void]$window.Show()
	}
	catch {
		Write-AppLog -Message "Show-EditorWindow failed for path: $CsvPath" -Exception $_.Exception
		[System.Windows.MessageBox]::Show(
			"Unable to open editor window. Details were written to:`n$script:logPath`n`n$($_.Exception.Message)",
			'Editor Error',
			'OK',
			'Error'
		) | Out-Null
	}
}

$mainXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="CSV Editor (PowerShell 5.1 + WPF)" Height="760" Width="1360" WindowStartupLocation="CenterScreen" AllowDrop="True">
	<Grid Margin="10">
		<Grid.ColumnDefinitions>
			<ColumnDefinition Width="2*"/>
			<ColumnDefinition Width="Auto"/>
			<ColumnDefinition Width="3*"/>
		</Grid.ColumnDefinitions>
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<TextBlock Grid.Row="0" Grid.ColumnSpan="3"
				   Margin="0,0,0,8"
				   Text="Drag and drop CSV files or folders into the left grid. Click a file to preview it on the right."
				   FontWeight="SemiBold"
				   ToolTip="Drop CSV files/folders to build your working list. Select a row to load preview."/>

		<StackPanel Grid.Row="0" Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,0,8">
			<CheckBox x:Name="chkChart"
					  Content="Chart"
					  Margin="0,0,8,0"
					  VerticalAlignment="Center"
					  ToolTip="Enable chart visualization from selected data"/>
			<ComboBox x:Name="cmbChartType"
					  Width="130"
					  Margin="0,0,12,0"
					  VerticalAlignment="Center"
					  IsEnabled="False"
					  ToolTip="Select chart type to visualize selected data">
				<ComboBoxItem Content="Pie" IsSelected="True"/>
				<ComboBoxItem Content="Pie Exploded"/>
				<ComboBoxItem Content="Bar"/>
				<ComboBoxItem Content="Stacked Bar"/>
				<ComboBoxItem Content="Line"/>
				<ComboBoxItem Content="Scatter"/>
			</ComboBox>
			<CheckBox x:Name="chkBanding"
					  Content="Banding"
					  VerticalAlignment="Center"
					  ToolTip="Toggle alternating row colors globally for preview and all open editor windows."/>
		</StackPanel>

		<DataGrid x:Name="fileGrid" Grid.Row="1" Grid.Column="0" Margin="0,0,0,0"
				  AutoGenerateColumns="False"
				  CanUserAddRows="False"
				  IsReadOnly="True"
				  SelectionMode="Extended"
				  SelectionUnit="FullRow"
				  AllowDrop="True"
				  ToolTip="Drop CSV files or folders here. Ctrl+Click for multi-select. Click a row to preview on the right.">
			<DataGrid.Columns>
				<DataGridTextColumn Header="File" Binding="{Binding Name}" Width="2*"/>
				<DataGridTextColumn Header="Last Update" Binding="{Binding LastUpdate}" Width="1.4*"/>
				<DataGridTextColumn Header="File Size" Binding="{Binding FileSize}" Width="*"/>
				<DataGridTextColumn Header="Rows" Binding="{Binding Rows}" Width="0.7*"/>
				<DataGridTextColumn Header="Columns" Binding="{Binding Columns}" Width="0.8*"/>
			</DataGrid.Columns>
		</DataGrid>

		<GridSplitter Grid.Row="1" Grid.Column="1"
					  Width="5"
					  HorizontalAlignment="Stretch"
					  VerticalAlignment="Stretch"
					  Background="#FFAAAAAA"
					  ShowsPreview="True"
					  ToolTip="Drag to resize file list and preview panes"/>

		<Grid Grid.Row="1" Grid.Column="2">
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
			</Grid.RowDefinitions>

			<DockPanel Grid.Row="0" Margin="0,0,0,8">
				<StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
					<Button x:Name="btnAddFiles" Content="Add Files" Width="120" Margin="0,0,6,0" ToolTip="Browse and add one or more CSV files"/>
					<Button x:Name="btnRunPowerShell" Content="Run PowerShell" Width="140" Margin="0,0,6,0" ToolTip="Export selected CSVs to HTML and open in Edge"/>
					<Button x:Name="btnCopyCsvNames" Content="Copy CSV Names" Width="140" Margin="0,0,12,0" ToolTip="Copy selected CSV names with full path to clipboard"/>
					<Button x:Name="btnZoomOut" Content="-" Width="36" Margin="0,0,6,0" ToolTip="Zoom out preview grid"/>
					<Button x:Name="btnZoomIn" Content="+" Width="36" Margin="0,0,12,0" ToolTip="Zoom in preview grid"/>
					<Button x:Name="btnOpenEditor" Content="Open in New Window" Width="170" IsEnabled="False" ToolTip="Open selected CSV in editable window"/>
				</StackPanel>
				<TextBlock x:Name="txtPreviewTitle" FontWeight="SemiBold" VerticalAlignment="Center" Text="Preview" ToolTip="Current preview file"/>
			</DockPanel>

			<DataGrid x:Name="previewGrid" Grid.Row="1"
					  AutoGenerateColumns="False"
					  CanUserAddRows="False"
					  IsReadOnly="True"
					  CanUserReorderColumns="True"
						  EnableRowVirtualization="True"
						  EnableColumnVirtualization="True"
						  VirtualizingPanel.IsVirtualizing="True"
						  VirtualizingPanel.VirtualizationMode="Recycling"
						  ScrollViewer.CanContentScroll="True"
					  HorizontalScrollBarVisibility="Visible"
					  VerticalScrollBarVisibility="Auto"
					  FrozenColumnCount="0"
					  FontSize="12"
					  SelectionMode="Extended"
					  SelectionUnit="Cell"
					  ToolTip="Preview grid. Use header checkboxes to freeze columns. Select cells to chart when Chart is enabled."/>
		</Grid>

		<StatusBar Grid.Row="3" Grid.ColumnSpan="3" Margin="0,8,0,0" ToolTip="Files loaded and PowerShell memory usage">
			<StatusBarItem>
				<TextBlock x:Name="txtStatus" Text="Ready."/>
			</StatusBarItem>
			<StatusBarItem HorizontalAlignment="Right">
				<StackPanel Orientation="Horizontal">
					<TextBlock Text="Files: " FontWeight="SemiBold"/>
					<TextBlock x:Name="txtFileCount" Text="0" Margin="0,0,20,0"/>
					<TextBlock Text="Excel Installed: " FontWeight="SemiBold"/>
					<TextBlock x:Name="txtMainExcelInstalled" Text="No" Margin="0,0,20,0" ToolTip="Excel detection details"/>
					<TextBlock Text="Memory: " FontWeight="SemiBold"/>
					<TextBlock x:Name="txtMemory" Text="0 B"/>
				</StackPanel>
			</StatusBarItem>
		</StatusBar>
	</Grid>
</Window>
"@

$mainReader = New-Object System.Xml.XmlNodeReader ([xml]$mainXaml)
$mainWindow = [Windows.Markup.XamlReader]::Load($mainReader)

[System.Windows.Threading.Dispatcher]::CurrentDispatcher.add_UnhandledException({
	param($sender, $e)
	Write-AppLog -Message 'Unhandled UI dispatcher exception.' -Exception $e.Exception
	[System.Windows.MessageBox]::Show(
		"An unexpected UI error occurred. Details were written to:`n$script:logPath`n`n$($e.Exception.Message)",
		'Unhandled UI Error',
		'OK',
		'Error'
	) | Out-Null
	$e.Handled = $true
})

[AppDomain]::CurrentDomain.add_UnhandledException({
	param($sender, $eventArgs)
	$ex = $eventArgs.ExceptionObject -as [System.Exception]
	if ($null -ne $ex) {
		Write-AppLog -Message 'Unhandled AppDomain exception.' -Exception $ex
	}
	else {
		Write-AppLog -Message 'Unhandled AppDomain exception (non-Exception object).' -Exception $null
	}
})

$fileGrid = $mainWindow.FindName('fileGrid')
$previewGrid = $mainWindow.FindName('previewGrid')
$btnAddFiles = $mainWindow.FindName('btnAddFiles')
$btnZoomOut = $mainWindow.FindName('btnZoomOut')
$btnZoomIn = $mainWindow.FindName('btnZoomIn')
$btnOpenEditor = $mainWindow.FindName('btnOpenEditor')
$btnRunPowerShell = $mainWindow.FindName('btnRunPowerShell')
$btnCopyCsvNames = $mainWindow.FindName('btnCopyCsvNames')
$chkChart = $mainWindow.FindName('chkChart')
$cmbChartType = $mainWindow.FindName('cmbChartType')
$chkBanding = $mainWindow.FindName('chkBanding')
$txtPreviewTitle = $mainWindow.FindName('txtPreviewTitle')
$txtStatus = $mainWindow.FindName('txtStatus')
$txtFileCount = $mainWindow.FindName('txtFileCount')
$txtMemory = $mainWindow.FindName('txtMemory')
$txtMainExcelInstalled = $mainWindow.FindName('txtMainExcelInstalled')

Update-ExcelIndicator -Target $txtMainExcelInstalled

$fileItems = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$fileGrid.ItemsSource = $fileItems

$script:currentPreviewPath = $null
$script:appSettings = Load-AppSettings
Ensure-AppSettings
$script:previewFontSize = Get-ValidFontSize -Value (Get-SettingValue -Settings $script:appSettings -Key 'PreviewZoom' -DefaultValue 12) -Default 12
$script:editorFontSize = Get-ValidFontSize -Value (Get-SettingValue -Settings $script:appSettings -Key 'EditorZoom' -DefaultValue 12) -Default 12
$script:useBanding = [bool](Get-SettingValue -Settings $script:appSettings -Key 'UseBanding' -DefaultValue $false)
$script:previewRowLimit = Get-ValidPreviewRowLimit -Value (Get-SettingValue -Settings $script:appSettings -Key 'PreviewRowLimit' -DefaultValue 500) -Default 500
Restore-MainWindowPlacement -Window $mainWindow

function Apply-GlobalBanding {
	Apply-GridBanding -Grid $previewGrid
	foreach ($w in @($script:editorWindows)) {
		if ($null -eq $w) { continue }
		if ($w.Tag -is [System.Windows.Controls.DataGrid]) {
			Apply-GridBanding -Grid ([System.Windows.Controls.DataGrid]$w.Tag)
		}
	}
}

function Persist-FileList {
	Ensure-AppSettings
	Set-AppSetting -Key 'FilePaths' -Value @($fileItems | ForEach-Object { $_.FullPath } | Sort-Object -Unique)
	Save-AppSettings -Settings $script:appSettings
}

function Refresh-SelectedFileStats {
	$selected = $fileGrid.SelectedItem
	if ($null -eq $selected) { return }

	try {
		$updated = Get-CsvFileStats -Path $selected.FullPath
		$selected.LastUpdate = $updated.LastUpdate
		$selected.FileSize = $updated.FileSize
		$selected.Rows = $updated.Rows
		$selected.Columns = $updated.Columns
		$fileGrid.Items.Refresh()
	}
	catch {
		$txtStatus.Text = "Unable to refresh stats: $($_.Exception.Message)"
	}
}

function Show-Preview {
	param([Parameter(Mandatory = $true)][string]$CsvPath)

	$waitStarted = [DateTime]::UtcNow
	[System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
	$mainWindow.Dispatcher.Invoke([Action]{ }, [System.Windows.Threading.DispatcherPriority]::Background)

	try {
		$previewResult = Import-CsvTablePreview -Path $CsvPath -MaxRows $script:previewRowLimit
		$table = $previewResult.Table
		$tableView = $table.DefaultView

		if ($table.Columns.Count -gt 0) {
			Set-DataGridColumns -Grid $previewGrid -ColumnNames @($table.Columns | ForEach-Object { $_.ColumnName }) -EnableLogicalScrolling $true
		}
		else {
			$previewGrid.Columns.Clear()
		}

		$previewGrid.ItemsSource = $tableView
		$script:previewFontSize = Get-ValidFontSize -Value $script:previewFontSize -Default 12
		$previewGrid.FontSize = $script:previewFontSize
		Apply-GridBanding -Grid $previewGrid

		$script:currentPreviewPath = $CsvPath
		if ($previewResult.IsCapped) {
			$txtPreviewTitle.Text = "Preview: $([System.IO.Path]::GetFileName($CsvPath)) (first $($previewResult.ShownRows) rows)"
		}
		else {
			$txtPreviewTitle.Text = "Preview: $([System.IO.Path]::GetFileName($CsvPath))"
		}
		$btnOpenEditor.IsEnabled = $true
		$loadMs = [math]::Round(([DateTime]::UtcNow - $waitStarted).TotalMilliseconds)
		$txtStatus.Text = "Preview loaded: $($previewResult.ShownRows) row(s) shown (limit $($previewResult.RowLimit)) in ${loadMs} ms."
	}
	catch {
		$txtStatus.Text = "Preview error: $($_.Exception.Message)"
	}
	finally {
		$elapsedMs = ([DateTime]::UtcNow - $waitStarted).TotalMilliseconds
		if ($elapsedMs -lt 250) {
			$remaining = [int]([Math]::Ceiling(250 - $elapsedMs))
			$sw = [System.Diagnostics.Stopwatch]::StartNew()
			while ($sw.ElapsedMilliseconds -lt $remaining) {
				$mainWindow.Dispatcher.Invoke([Action]{ }, [System.Windows.Threading.DispatcherPriority]::Background)
			}
		}
		[System.Windows.Input.Mouse]::OverrideCursor = $null
	}
}

function Add-CsvFiles {
	param([string[]]$Paths)

	if ($null -eq $Paths -or $Paths.Count -eq 0) { return }

	$known = @{}
	foreach ($it in $fileItems) {
		$known[$it.FullPath.ToLowerInvariant()] = $true
	}

	$foundCsv = New-Object System.Collections.Generic.List[string]

	foreach ($path in $Paths) {
		if (-not (Test-Path -LiteralPath $path)) { continue }

		$item = Get-Item -LiteralPath $path
		if ($item.PSIsContainer) {
			$csvFiles = Get-ChildItem -LiteralPath $item.FullName -Filter '*.csv' -File -Recurse -ErrorAction SilentlyContinue
			foreach ($csv in $csvFiles) {
				[void]$foundCsv.Add($csv.FullName)
			}
		}
		elseif ($item.Extension -ieq '.csv') {
			[void]$foundCsv.Add($item.FullName)
		}
	}

	$added = 0
	foreach ($csvPath in ($foundCsv | Sort-Object -Unique)) {
		$key = $csvPath.ToLowerInvariant()
		if ($known.ContainsKey($key)) { continue }

		try {
			$stats = Get-CsvFileStats -Path $csvPath -SkipRowCount
			[void]$fileItems.Add($stats)
			$known[$key] = $true
			$added++
		}
		catch {
			$txtStatus.Text = "Skipped ${csvPath}: $($_.Exception.Message)"
		}
	}

	$txtStatus.Text = "Added $added CSV file(s)."
	$txtFileCount.Text = [string]$fileItems.Count
	Persist-FileList
}

$fileGrid.Add_DragOver({
	param($sender, $e)
	if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
		$e.Effects = [System.Windows.DragDropEffects]::Copy
	}
	else {
		$e.Effects = [System.Windows.DragDropEffects]::None
	}
	$e.Handled = $true
})

$fileGrid.Add_Drop({
	param($sender, $e)
	if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
		$paths = [string[]]$e.Data.GetData([System.Windows.DataFormats]::FileDrop)
		Add-CsvFiles -Paths $paths
	}
	$e.Handled = $true
})

$fileGrid.Add_SelectionChanged({
	if ($null -eq $fileGrid.SelectedItem) {
		$btnOpenEditor.IsEnabled = $false
		return
	}
	Show-Preview -CsvPath $fileGrid.SelectedItem.FullPath
	Refresh-SelectedFileStats
})

$previewGrid.Add_SelectedCellsChanged({
	if (-not $chkChart.IsChecked) { return }

	try {
		$selectedCells = @($previewGrid.SelectedCells)
		$cmbChartType.IsEnabled = ($selectedCells.Count -gt 0)
		if ($selectedCells.Count -eq 0) {
			$txtStatus.Text = 'Chart mode enabled. Select one or more cells, then choose a chart type.'
			return
		}

		$txtStatus.Text = "Chart mode enabled. Selected $($selectedCells.Count) cell(s). Choose a chart type to open chart window."
	}
	catch {
		$txtStatus.Text = "Error processing selection: $($_.Exception.Message)"
	}
})

$fileGrid.Add_LoadingRow({
	param($sender, $e)

	if ($null -eq $e.Row -or $null -eq $e.Row.Item) { return }
	$item = $e.Row.Item
	$rowOver = $false
	$colOver = $false

	try { $rowOver = ([int]$item.Rows -gt 100) } catch { $rowOver = $false }
	try { $colOver = ([int]$item.Columns -gt 20) } catch { $colOver = $false }

	$rowsCell = $fileGrid.Columns[3].GetCellContent($e.Row)
	if ($null -ne $rowsCell) {
		$rowsCell.Foreground = if ($rowOver) { [System.Windows.Media.Brushes]::Red } else { [System.Windows.SystemColors]::ControlTextBrush }
		if ($rowOver) {
			$rowsCell.FontWeight = [System.Windows.FontWeights]::Bold
		}
		else {
			$rowsCell.FontWeight = [System.Windows.FontWeights]::Normal
		}
	}

	$colsCell = $fileGrid.Columns[4].GetCellContent($e.Row)
	if ($null -ne $colsCell) {
		$colsCell.Foreground = if ($colOver) { [System.Windows.Media.Brushes]::Red } else { [System.Windows.SystemColors]::ControlTextBrush }
		if ($colOver) {
			$colsCell.FontWeight = [System.Windows.FontWeights]::Bold
		}
		else {
			$colsCell.FontWeight = [System.Windows.FontWeights]::Normal
		}
	}
})

$btnZoomIn.Add_Click({
	Ensure-AppSettings
	$script:previewFontSize = Get-ValidFontSize -Value ([Math]::Min($script:previewFontSize + 1, 28)) -Default 12
	$previewGrid.FontSize = $script:previewFontSize
	Set-AppSetting -Key 'PreviewZoom' -Value $script:previewFontSize
	Save-AppSettings -Settings $script:appSettings
	$txtStatus.Text = "Preview zoom: $($script:previewFontSize)"
})

$btnZoomOut.Add_Click({
	Ensure-AppSettings
	$script:previewFontSize = Get-ValidFontSize -Value ([Math]::Max($script:previewFontSize - 1, 8)) -Default 12
	$previewGrid.FontSize = $script:previewFontSize
	Set-AppSetting -Key 'PreviewZoom' -Value $script:previewFontSize
	Save-AppSettings -Settings $script:appSettings
	$txtStatus.Text = "Preview zoom: $($script:previewFontSize)"
})

$btnAddFiles.Add_Click({
	try {
		$dialog = New-Object Microsoft.Win32.OpenFileDialog
		$dialog.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
		$dialog.Multiselect = $true
		$dialog.Title = 'Select CSV file(s)'

		$result = $dialog.ShowDialog()
		if ($result -eq $true) {
			Add-CsvFiles -Paths ([string[]]$dialog.FileNames)
			if ($fileItems.Count -gt 0 -and $null -eq $fileGrid.SelectedItem) {
				$fileGrid.SelectedIndex = 0
			}
		}
	}
	catch {
		$txtStatus.Text = "Add Files error: $($_.Exception.Message)"
	}
})

$chkChart.Add_Checked({
	$previewGrid.SelectionMode = [System.Windows.Controls.DataGridSelectionMode]::Extended
	$previewGrid.SelectionUnit = [System.Windows.Controls.DataGridSelectionUnit]::Cell
	$cmbChartType.IsEnabled = (@($previewGrid.SelectedCells).Count -gt 0)
	$txtStatus.Text = 'Chart mode enabled. Select one or more cells, then choose a chart type.'
})

$chkChart.Add_Unchecked({
	$cmbChartType.IsEnabled = $false
	$previewGrid.SelectionMode = [System.Windows.Controls.DataGridSelectionMode]::Extended
	$previewGrid.SelectionUnit = [System.Windows.Controls.DataGridSelectionUnit]::FullRow
	try { $previewGrid.SelectedCells.Clear() } catch { }
	$txtStatus.Text = 'Chart mode disabled. Row selection mode enabled.'
})

$cmbChartType.Add_SelectionChanged({
	if (-not $chkChart.IsChecked) { return }
	if ($null -eq $cmbChartType.SelectedItem) { return }

	try {
		$selectedCells = @($previewGrid.SelectedCells)
		if ($selectedCells.Count -eq 0) {
			$txtStatus.Text = 'Select one or more cells before choosing a chart type.'
			return
		}

		$selectionSnapshot = Get-PreviewSelectionSnapshot -Grid $previewGrid

		$chartType = [string]$cmbChartType.SelectedItem.Content
		$chartData = Get-ChartDataFromSelectedCells -Grid $previewGrid
		if ($chartData.Count -eq 0) {
			$txtStatus.Text = 'No valid numeric/cell data found in selected range for charting.'
			return
		}

		if ($null -eq $script:excelInfo) {
			$script:excelInfo = Get-ExcelInstallInfo
		}
		if ([string]::IsNullOrWhiteSpace($script:currentPreviewPath)) {
			$txtStatus.Text = 'No CSV file is currently loaded in preview.'
			return
		}

		Show-ChartWindow -ChartData $chartData -ChartType $chartType -SourceCsvPath $script:currentPreviewPath -ExcelInstalled $script:excelInfo.Installed
		Restore-PreviewSelectionSnapshot -Grid $previewGrid -Snapshot $selectionSnapshot
		$previewGrid.SelectionUnit = [System.Windows.Controls.DataGridSelectionUnit]::Cell
		$previewGrid.SelectionMode = [System.Windows.Controls.DataGridSelectionMode]::Extended
		$cmbChartType.IsEnabled = (@($previewGrid.SelectedCells).Count -gt 0)
		$txtStatus.Text = "Chart window closed. Current cell selection is still active; choose another chart type if needed."
	}
	catch {
		$txtStatus.Text = "Chart error: $($_.Exception.Message)"
		Write-AppLog -Message "Chart selection workflow failed" -Exception $_.Exception
	}
})

$chkBanding.Add_Checked({
	Ensure-AppSettings
	$script:useBanding = $true
	Set-AppSetting -Key 'UseBanding' -Value $true
	Save-AppSettings -Settings $script:appSettings
	Apply-GlobalBanding
	$txtStatus.Text = 'Banding enabled.'
})

$chkBanding.Add_Unchecked({
	Ensure-AppSettings
	$script:useBanding = $false
	Set-AppSetting -Key 'UseBanding' -Value $false
	Save-AppSettings -Settings $script:appSettings
	Apply-GlobalBanding
	$txtStatus.Text = 'Banding disabled.'
})

$btnOpenEditor.Add_Click({
	if ($null -eq $fileGrid.SelectedItem) { return }

	Show-EditorWindow -CsvPath $fileGrid.SelectedItem.FullPath -OnSaved {
		Refresh-SelectedFileStats
		if ($null -ne $script:currentPreviewPath) {
			Show-Preview -CsvPath $script:currentPreviewPath
		}
	}
})

$btnRunPowerShell.Add_Click({
	if ($null -eq $fileGrid.SelectedItem) { return }

	$selectedItems = @($fileGrid.SelectedItems)
	if ($selectedItems.Count -eq 0) { return }

	$tempFolder = Join-Path $env:TEMP "CSVtoHTML_$(Get-Random)"
	New-Item -ItemType Directory -Force -Path $tempFolder | Out-Null

	foreach ($item in $selectedItems) {
		$csvPath = $item.FullPath
		$htmlContent = Convert-CsvToHtml -CsvPath $csvPath
		if ($null -eq $htmlContent) {
			$txtStatus.Text = "Error converting CSV: $($item.Name)"
			continue
		}

		$htmlFileName = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetFileName($csvPath), '.html')
		$htmlPath = Join-Path $tempFolder $htmlFileName
		$htmlContent | Set-Content -LiteralPath $htmlPath -Encoding UTF8

		# Open in Edge
		try {
			Start-Process -FilePath 'msedge.exe' -ArgumentList $htmlPath -ErrorAction SilentlyContinue
		}
		catch {
			Start-Process -FilePath $htmlPath -ErrorAction SilentlyContinue
		}
	}

	$txtStatus.Text = "Exported $($selectedItems.Count) CSV file(s) to HTML and opened in Edge."
})

$btnCopyCsvNames.Add_Click({
	if ($null -eq $fileGrid.SelectedItem) { return }

	$selectedItems = @($fileGrid.SelectedItems)
	if ($selectedItems.Count -eq 0) { return }

	Copy-CsvNamesToClipboard -Items $selectedItems
	$txtStatus.Text = "Copied $($selectedItems.Count) CSV filename(s) to clipboard."
})

$mainWindow.Add_ContentRendered({
	$savedPaths = @(Get-SettingValue -Settings $script:appSettings -Key 'FilePaths' -DefaultValue @())
	if ($savedPaths.Count -gt 0) {
		Add-CsvFiles -Paths $savedPaths
		if ($fileItems.Count -gt 0 -and $null -eq $fileGrid.SelectedItem) {
			$fileGrid.SelectedIndex = 0
		}
	}

	$script:previewFontSize = Get-ValidFontSize -Value $script:previewFontSize -Default 12
	$previewGrid.FontSize = $script:previewFontSize
	$chkBanding.IsChecked = $script:useBanding
	Apply-GlobalBanding

	# Update status bar with file count and memory
	$updateStatusBar = {
		$txtFileCount.Text = [string]$fileItems.Count
		$txtMemory.Text = Get-FreeMemoryText
	}

	# Initial update
	& $updateStatusBar

	# Create timer to update status bar every 2 seconds
	$script:mainStatusTimer = New-Object System.Windows.Threading.DispatcherTimer
	$script:mainStatusTimer.Interval = [System.TimeSpan]::FromSeconds(2)
	$script:mainStatusTimer.Add_Tick($updateStatusBar)
	$script:mainStatusTimer.Start()
})

$mainWindow.Add_Closing({
	if ($null -ne $script:mainStatusTimer) {
		try {
			if ($script:mainStatusTimer.IsEnabled) {
				$script:mainStatusTimer.Stop()
			}
		}
		catch {
		}
		$script:mainStatusTimer = $null
	}

	Ensure-AppSettings
	Persist-FileList
	Set-AppSetting -Key 'PreviewZoom' -Value $script:previewFontSize
	Set-AppSetting -Key 'EditorZoom' -Value $script:editorFontSize
	Set-AppSetting -Key 'UseBanding' -Value $script:useBanding
	Save-MainWindowPlacement -Window $mainWindow
	Save-AppSettings -Settings $script:appSettings
})

[void]$mainWindow.ShowDialog()
