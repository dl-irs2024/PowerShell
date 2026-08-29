Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Data

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

		return @{
			FilePaths   = $filePaths
			PreviewZoom = [Math]::Max(8, [Math]::Min($previewZoom, 28))
			EditorZoom  = [Math]::Max(8, [Math]::Min($editorZoom, 28))
			UseBanding  = $useBanding
		}
	}
	catch {
		return $defaults
	}

}

function Save-AppSettings {
	param([Parameter(Mandatory = $true)][hashtable]$Settings)

	if ($null -eq $Settings) {
		$Settings = Get-DefaultSettings
	}

	$payload = @{
		FilePaths   = @(Get-SettingValue -Settings $Settings -Key 'FilePaths' -DefaultValue @())
		PreviewZoom = [int](Get-SettingValue -Settings $Settings -Key 'PreviewZoom' -DefaultValue 12)
		EditorZoom  = [int](Get-SettingValue -Settings $Settings -Key 'EditorZoom' -DefaultValue 12)
		UseBanding  = [bool](Get-SettingValue -Settings $Settings -Key 'UseBanding' -DefaultValue $false)
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
		[Parameter(Mandatory = $true)][string[]]$ColumnNames
	)

	$Grid.Columns.Clear()
	Apply-GridHeadersMotif -Grid $Grid
	[System.Windows.Controls.ScrollViewer]::SetCanContentScroll($Grid, $false)

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
	param([Parameter(Mandatory = $true)][string]$Path)

	$file = Get-Item -LiteralPath $Path
	$rowCount = 0
	$columnCount = 0

	$headerLine = Get-Content -LiteralPath $Path -TotalCount 1 -ErrorAction Stop
	if (-not [string]::IsNullOrWhiteSpace($headerLine)) {
		$headerCols = ConvertFrom-Csv -InputObject $headerLine
		if ($null -ne $headerCols) {
			$columnCount = ($headerCols.PSObject.Properties | Measure-Object).Count
		}
	}

	$lineCount = (Get-Content -LiteralPath $Path | Measure-Object -Line).Lines
	if ($lineCount -gt 0) {
		$rowCount = [Math]::Max(0, $lineCount - 1)
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
			<TextBlock x:Name="txtPath" FontWeight="SemiBold" TextWrapping="Wrap" ToolTip="Full path for the file currently open in editor"/>
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
	$txtEditExcelInstalled = $window.FindName('txtEditExcelInstalled')
	Update-ExcelIndicator -Target $txtEditExcelInstalled

	$txtPath.Text = "File: $([System.IO.Path]::GetFileName($CsvPath))"
	$txtPath.FontWeight = [System.Windows.FontWeights]::Bold
	$workingTable = Import-CsvTable -Path $CsvPath
	$baselineTable = $workingTable.Copy()
	$editedCellBrush = [System.Windows.Media.Brushes]::Purple
	$editedTextBrush = [System.Windows.Media.Brushes]::White
	$originalCellValues = @{}
	$editedCellKeys = New-Object System.Collections.Generic.HashSet[string]
	$hasUnsavedChanges = $false
	$fileInfo = Get-Item -LiteralPath $CsvPath

	$updateEditorStatus = {
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
	}.GetNewClosure()

	$setDirtyState = {
		param([bool]$IsDirty)
		$hasUnsavedChanges = $IsDirty
		$btnRevert.IsEnabled = $hasUnsavedChanges
		& $updateEditorStatus
	}.GetNewClosure()

	$applyEditedHighlights = {
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
	}.GetNewClosure()

	$saveCurrentChanges = {
		try {
			Export-DataTableToCsv -Table $workingTable -Path $CsvPath
			$baselineTable = $workingTable.Copy()
			$originalCellValues.Clear()
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
	& $updateEditorStatus

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
			& $setDirtyState $true
		}
		else {
			if ($editedCellKeys.Contains($key)) {
				[void]$editedCellKeys.Remove($key)
			}
		}

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
			$editedCellKeys.Clear()
			$editGrid.Items.Refresh()
			& $applyEditedHighlights
			[System.Windows.MessageBox]::Show('Saved successfully.', 'CSV Editor', 'OK', 'Information') | Out-Null
		}
	}.GetNewClosure())

	$btnRevert.Add_Click({
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
		$originalCellValues.Clear()
		$editedCellKeys.Clear()
		$editGrid.Items.Refresh()
		& $applyEditedHighlights
		& $setDirtyState $false
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

		$timerWasRunning = $memoryTimer.IsEnabled
		if ($timerWasRunning) {
			$memoryTimer.Stop()
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
			if ($timerWasRunning) {
				$memoryTimer.Start()
			}
			return
		}

		if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
			if (-not (& $saveCurrentChanges)) {
				$e.Cancel = $true
				if ($timerWasRunning) {
					$memoryTimer.Start()
				}
			}
			return
		}

		if ($result -eq [System.Windows.MessageBoxResult]::No) {
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
			$originalCellValues.Clear()
			$editedCellKeys.Clear()
			$editGrid.Items.Refresh()
			& $applyEditedHighlights
			& $setDirtyState $false
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
		[void]$script:editorWindows.Remove($window)
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
			<ColumnDefinition Width="3*"/>
		</Grid.ColumnDefinitions>
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<TextBlock Grid.Row="0" Grid.ColumnSpan="2"
				   Margin="0,0,0,8"
				   Text="Drag and drop CSV files or folders into the left grid. Click a file to preview it on the right."
				   FontWeight="SemiBold"
				   ToolTip="Drop CSV files/folders to build your working list. Select a row to load preview."/>

		<CheckBox x:Name="chkBanding"
				  Grid.Row="0"
				  Grid.Column="1"
				  HorizontalAlignment="Right"
				  VerticalAlignment="Center"
				  Margin="0,0,0,8"
				  Content="Banding"
				  ToolTip="Toggle alternating row colors globally for preview and all open editor windows."/>

		<DataGrid x:Name="fileGrid" Grid.Row="1" Grid.Column="0" Margin="0,0,8,0"
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

		<Grid Grid.Row="1" Grid.Column="1">
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
			</Grid.RowDefinitions>

			<DockPanel Grid.Row="0" Margin="0,0,0,8">
				<StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
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
					  HorizontalScrollBarVisibility="Visible"
					  VerticalScrollBarVisibility="Auto"
					  FrozenColumnCount="0"
					  FontSize="12"
					  ToolTip="Preview grid. Use header checkboxes to freeze columns."/>
		</Grid>

		<StatusBar Grid.Row="3" Grid.ColumnSpan="2" Margin="0,8,0,0" ToolTip="Files loaded and PowerShell memory usage">
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
$btnZoomOut = $mainWindow.FindName('btnZoomOut')
$btnZoomIn = $mainWindow.FindName('btnZoomIn')
$btnOpenEditor = $mainWindow.FindName('btnOpenEditor')
$btnRunPowerShell = $mainWindow.FindName('btnRunPowerShell')
$btnCopyCsvNames = $mainWindow.FindName('btnCopyCsvNames')
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
		$table = Import-CsvTable -Path $CsvPath
		$tableView = $table.DefaultView

		if ($table.Columns.Count -gt 0) {
			Set-DataGridColumns -Grid $previewGrid -ColumnNames @($table.Columns | ForEach-Object { $_.ColumnName })
		}
		else {
			$previewGrid.Columns.Clear()
		}

		$previewGrid.ItemsSource = $tableView
		$script:previewFontSize = Get-ValidFontSize -Value $script:previewFontSize -Default 12
		$previewGrid.FontSize = $script:previewFontSize
		Apply-GridBanding -Grid $previewGrid

		$script:currentPreviewPath = $CsvPath
		$txtPreviewTitle.Text = "Preview: $([System.IO.Path]::GetFileName($CsvPath))"
		$btnOpenEditor.IsEnabled = $true
		$txtStatus.Text = 'Preview loaded.'
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
			$stats = Get-CsvFileStats -Path $csvPath
			[void]$fileItems.Add($stats)
			$known[$key] = $true
			$added++
		}
		catch {
			$txtStatus.Text = "Skipped ${csvPath}: $($_.Exception.Message)"
		}
	}

	$txtStatus.Text = "Added $added CSV file(s)."
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
		$rowsCell.Foreground = if ($rowOver) { [System.Windows.Media.Brushes]::Red } else { [System.Windows.Media.Brushes]::Black }
		if ($rowOver) {
			$rowsCell.FontWeight = [System.Windows.FontWeights]::Bold
		}
		else {
			$rowsCell.FontWeight = [System.Windows.FontWeights]::Normal
		}
	}

	$colsCell = $fileGrid.Columns[4].GetCellContent($e.Row)
	if ($null -ne $colsCell) {
		$colsCell.Foreground = if ($colOver) { [System.Windows.Media.Brushes]::Red } else { [System.Windows.Media.Brushes]::Black }
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
		$script:mainStatusTimer.Stop()
		$script:mainStatusTimer = $null
	}

	Ensure-AppSettings
	Persist-FileList
	Set-AppSetting -Key 'PreviewZoom' -Value $script:previewFontSize
	Set-AppSetting -Key 'EditorZoom' -Value $script:editorFontSize
	Set-AppSetting -Key 'UseBanding' -Value $script:useBanding
	Save-AppSettings -Settings $script:appSettings
})

[void]$mainWindow.ShowDialog()
