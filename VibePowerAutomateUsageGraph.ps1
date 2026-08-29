<#
.SYNOPSIS
Power Automate Usage Monitor (WPF, PowerShell 5.1)

.DESCRIPTION
This script provides a WPF dashboard that supports:
- Simulation mode (fully local synthetic telemetry)
- Live mode (stubs with detailed guidance for Graph/REST/PowerShell integration)
- Scrolling usage grid with run-history links
- Animated health motif (green/yellow)
- Left-scrolling latency graph with 10-second historical scale ticks
- Export options: CSV, PSObject (CLIXML), and formatted Excel with chart

NOTES
- Target runtime: Windows PowerShell 5.1
- The markdown tab includes Mermaid diagrams rendered inside WPF WebBrowser.
- Mermaid rendering depends on web access and local IE/WebBrowser capabilities.
#>

#region Markdown Notes In Script
<#
## Power Automate Usage Graph - Embedded Notes

The UI is intentionally split into:
1. Control rail (mode, start/stop, export)
2. Live health panel (animated motif + rolling latency graph)
3. Run log grid (scrolling)
4. Markdown tab with Mermaid diagrams rendered in WPF

### Live Integration Strategy (Stubbed)

- Microsoft Graph option:
  - Explore connectors/telemetry where available for environment and flow metadata.
- Power Platform Admin / Power Automate REST APIs:
  - Use AAD app registration and OAuth client credentials for unattended service polling.
  - Poll run history endpoints on schedule and normalize to usage records.
- PowerShell modules option:
  - Use Microsoft.PowerApps.Administration.PowerShell for admin-centric workflow metadata.
  - Use custom REST calls for per-run telemetry and latency.

### Mermaid Sequence (also shown in markdown tab)

```mermaid
sequenceDiagram
	participant UI as WPF Dashboard
	participant Poller as Update Timer
	participant Source as Simulated/Live Source
	participant Grid as Usage Grid
	participant Graph as Latency Graph
	Poller->>Source: Fetch records
	Source-->>Poller: Usage records
	Poller->>Grid: Append + scroll
	Poller->>Graph: Push latency + redraw
	Poller->>UI: Recompute health motif
```
#>
#endregion

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Web

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Vibe Power Automate Usage Graph"
		Height="920"
		Width="1500"
		WindowStartupLocation="CenterScreen"
		Background="#0F172A"
		Foreground="#E2E8F0"
		FontFamily="Segoe UI">
	<Grid Margin="12">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="260"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<Border Grid.Row="0" CornerRadius="10" Padding="10" Margin="0,0,0,10" Background="#111827" BorderBrush="#334155" BorderThickness="1">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="180"/>
					<ColumnDefinition Width="10"/>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="120"/>
					<ColumnDefinition Width="120"/>
					<ColumnDefinition Width="20"/>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="220"/>
					<ColumnDefinition Width="130"/>
					<ColumnDefinition Width="44"/>
					<ColumnDefinition Width="44"/>
					<ColumnDefinition Width="*"/>
				</Grid.ColumnDefinitions>

				<TextBlock Grid.Column="0" VerticalAlignment="Center" Margin="0,0,6,0" Text="Mode:"/>
				<ComboBox Grid.Column="1" Name="ModeCombo" SelectedIndex="1" VerticalContentAlignment="Center" ToolTip="Choose Simulation for demo data or Live for cloud polling stubs.">
					<ComboBoxItem Content="Live"/>
					<ComboBoxItem Content="Simulation"/>
				</ComboBox>

				<TextBlock Grid.Column="3" VerticalAlignment="Center" Margin="0,0,6,0" Text="Polling (sec):"/>
				<TextBox Grid.Column="4" Name="PollingSecondsBox" Text="2" Padding="4" HorizontalContentAlignment="Center" ToolTip="Polling interval in seconds (1 to 60)."/>
				<Button Grid.Column="5" Name="ApplyPollingButton" Content="Apply" Margin="8,0,0,0" ToolTip="Apply the polling interval."/>

				<Button Grid.Column="7" Name="StartButton" Content="Start" Padding="16,6" Margin="0,0,8,0" Background="#065F46" Foreground="#ECFDF5" ToolTip="Start monitoring updates."/>
				<Button Grid.Column="8" Name="StopButton" Content="Stop" Padding="16,6" Background="#7F1D1D" Foreground="#FEE2E2" IsEnabled="False" ToolTip="Stop monitoring updates."/>

				<ComboBox Grid.Column="9" Name="ExportTypeCombo" SelectedIndex="0" Margin="10,0,8,0" VerticalContentAlignment="Center" ToolTip="Choose export format.">
					<ComboBoxItem Content="CSV"/>
					<ComboBoxItem Content="PSObject"/>
					<ComboBoxItem Content="FormattedExcel"/>
				</ComboBox>
				<Button Grid.Column="10" Name="ExportButton" Content="Export" Width="100" HorizontalAlignment="Left" ToolTip="Export current grid data and open the exported file."/>
				<Button Grid.Column="11" Name="ZoomInButton" Content="+" Width="34" Height="28" Margin="6,0,4,0" ToolTip="Zoom in the usage grid text."/>
				<Button Grid.Column="12" Name="ZoomOutButton" Content="-" Width="34" Height="28" ToolTip="Zoom out the usage grid text."/>
			</Grid>
		</Border>

		<Grid Grid.Row="1">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="2*"/>
				<ColumnDefinition Width="3*"/>
			</Grid.ColumnDefinitions>

			<Grid Grid.Column="0" Margin="0,0,10,0">
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="*"/>
				</Grid.RowDefinitions>

				<Border Grid.Row="0" CornerRadius="12" Margin="0,0,0,10" Padding="14" Background="#111827" BorderBrush="#334155" BorderThickness="1">
					<Grid>
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="170"/>
							<ColumnDefinition Width="*"/>
						</Grid.ColumnDefinitions>

						<Canvas Width="150" Height="150" HorizontalAlignment="Center" VerticalAlignment="Center">
							<Ellipse Name="HealthPulse" Width="130" Height="130" Canvas.Left="10" Canvas.Top="10" Opacity="0.82" StrokeThickness="3" Stroke="#86EFAC">
								<Ellipse.Fill>
									<RadialGradientBrush RadiusX="0.9" RadiusY="0.9" GradientOrigin="0.4,0.4" Center="0.5,0.5">
										<GradientStop x:Name="HealthInnerStop" Color="#22C55E" Offset="0"/>
										<GradientStop x:Name="HealthOuterStop" Color="#166534" Offset="1"/>
									</RadialGradientBrush>
								</Ellipse.Fill>
								<Ellipse.RenderTransform>
									<ScaleTransform x:Name="HealthScale" CenterX="65" CenterY="65" ScaleX="1" ScaleY="1"/>
								</Ellipse.RenderTransform>
							</Ellipse>
							<Canvas.Triggers>
								<EventTrigger RoutedEvent="Canvas.Loaded">
									<BeginStoryboard>
										<Storyboard RepeatBehavior="Forever" AutoReverse="True">
											<DoubleAnimation Storyboard.TargetName="HealthScale" Storyboard.TargetProperty="ScaleX" From="0.96" To="1.07" Duration="0:0:1.2"/>
											<DoubleAnimation Storyboard.TargetName="HealthScale" Storyboard.TargetProperty="ScaleY" From="0.96" To="1.07" Duration="0:0:1.2"/>
											<DoubleAnimation Storyboard.TargetName="HealthPulse" Storyboard.TargetProperty="Opacity" From="0.65" To="1.0" Duration="0:0:1.2"/>
										</Storyboard>
									</BeginStoryboard>
								</EventTrigger>
							</Canvas.Triggers>
						</Canvas>

						<StackPanel Grid.Column="1" Margin="12,4,0,0">
							<TextBlock Name="HealthHeadlineText" FontSize="28" FontWeight="SemiBold" Text="Health: GOOD" Foreground="#86EFAC"/>
							<TextBlock Name="HealthDetailText" Margin="0,8,0,0" FontSize="16" TextWrapping="Wrap" Text="Low failure rate and normal latency."/>
							<TextBlock Name="StatsText" Margin="0,10,0,0" FontSize="14" Foreground="#CBD5E1" Text="Runs: 0 | Avg Latency: 0.0 sec | Failures(20): 0"/>
						</StackPanel>
					</Grid>
				</Border>

				<Border Grid.Row="1" CornerRadius="12" Padding="8" Background="#111827" BorderBrush="#334155" BorderThickness="1">
					<Grid>
						<Grid.RowDefinitions>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="*"/>
						</Grid.RowDefinitions>
						<TextBlock Text="Latency History (10-second horizontal ticks, newest at right)" FontWeight="SemiBold" Margin="4,2,4,6"/>
						<Canvas Name="LatencyCanvas" Grid.Row="1" Background="#0B1220" Height="320" ToolTip="Latency graph. Newest point is at the right; horizontal ticks are 10-second history increments."/>
					</Grid>
				</Border>
			</Grid>

			<Border Grid.Column="1" CornerRadius="12" Padding="8" Background="#111827" BorderBrush="#334155" BorderThickness="1">
				<Grid>
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
					</Grid.RowDefinitions>
					<TextBlock Text="Power Automate Workflow Usage Log" FontWeight="SemiBold" Margin="4,2,4,8"/>
					<DataGrid Name="UsageGrid"
							  Grid.Row="1"
							  AutoGenerateColumns="False"
							  HeadersVisibility="Column"
							  CanUserAddRows="False"
							  CanUserDeleteRows="False"
							  IsReadOnly="True"
							  CanUserReorderColumns="False"
							  EnableRowVirtualization="True"
							  ScrollViewer.VerticalScrollBarVisibility="Visible"
							  ScrollViewer.HorizontalScrollBarVisibility="Auto"
							  Background="#0B1220"
							  Foreground="#F8FAFC"
							  RowBackground="#111827"
							  AlternatingRowBackground="#1E293B"
							  AlternationCount="2"
							  ToolTip="Power Automate run log. Click a run-history link to open the run in browser."
							  BorderThickness="0">
						<DataGrid.ColumnHeaderStyle>
							<Style TargetType="DataGridColumnHeader">
								<Setter Property="Background" Value="#0F172A"/>
								<Setter Property="Foreground" Value="#F8FAFC"/>
								<Setter Property="FontWeight" Value="SemiBold"/>
								<Setter Property="BorderBrush" Value="#334155"/>
								<Setter Property="BorderThickness" Value="0,0,0,1"/>
								<Setter Property="Padding" Value="6,4"/>
							</Style>
						</DataGrid.ColumnHeaderStyle>
						<DataGrid.RowStyle>
							<Style TargetType="DataGridRow">
								<Setter Property="Foreground" Value="#F8FAFC"/>
								<Setter Property="Background" Value="#111827"/>
								<Style.Triggers>
									<Trigger Property="IsSelected" Value="True">
										<Setter Property="Background" Value="#1D4ED8"/>
										<Setter Property="Foreground" Value="#FFFFFF"/>
									</Trigger>
								</Style.Triggers>
							</Style>
						</DataGrid.RowStyle>
						<DataGrid.CellStyle>
							<Style TargetType="DataGridCell">
								<Setter Property="Foreground" Value="#F8FAFC"/>
								<Setter Property="Background" Value="Transparent"/>
								<Setter Property="BorderBrush" Value="#334155"/>
								<Setter Property="BorderThickness" Value="0,0,0,1"/>
								<Setter Property="Padding" Value="5,3"/>
								<Style.Triggers>
									<Trigger Property="IsSelected" Value="True">
										<Setter Property="Background" Value="#1D4ED8"/>
										<Setter Property="Foreground" Value="#FFFFFF"/>
									</Trigger>
								</Style.Triggers>
							</Style>
						</DataGrid.CellStyle>
						<DataGrid.Columns>
							<DataGridTextColumn Header="Environment" Binding="{Binding EnvironmentName}" Width="120"/>
							<DataGridTextColumn Header="Solution" Binding="{Binding Solution}" Width="130"/>
							<DataGridTextColumn Header="Workflow" Binding="{Binding Workflow}" Width="190"/>
							<DataGridTextColumn Header="Start Time" Binding="{Binding StartTime}" Width="150"/>
							<DataGridTextColumn Header="End Time" Binding="{Binding EndTime}" Width="150"/>
							<DataGridTextColumn Header="Success/Fail" Binding="{Binding Outcome}" Width="95"/>
							<DataGridTextColumn Header="Latency (sec)" Binding="{Binding LatencySeconds}" Width="95"/>
							<DataGridHyperlinkColumn Header="Run History" Width="220" Binding="{Binding RunHistoryLink}" ContentBinding="{Binding RunHistoryLink}">
								<DataGridHyperlinkColumn.ElementStyle>
									<Style TargetType="TextBlock">
										<Setter Property="Foreground" Value="#93C5FD"/>
									</Style>
								</DataGridHyperlinkColumn.ElementStyle>
							</DataGridHyperlinkColumn>
						</DataGrid.Columns>
					</DataGrid>
				</Grid>
			</Border>
		</Grid>

		<Border Grid.Row="2" Margin="0,10,0,0" CornerRadius="12" Padding="0" Background="#111827" BorderBrush="#334155" BorderThickness="1">
				<TabControl Name="BottomTabs">
					<TabItem Header="Markdown &amp; Mermaid">
					<Grid>
						<WebBrowser Name="MarkdownBrowser" ToolTip="Markdown and Mermaid rendering surface."/>
					</Grid>
				</TabItem>
			</TabControl>
		</Border>

		<StatusBar Grid.Row="3" Name="MainStatusBar" Background="#0F172A" Foreground="#E2E8F0" BorderBrush="#334155" BorderThickness="1,1,1,0" ToolTip="Application status information.">
			<StatusBarItem>
				<TextBlock Name="StatusText" Text="Ready"/>
			</StatusBarItem>
			<Separator/>
			<StatusBarItem>
				<TextBlock Name="ExcelStatusText" Text="Excel Installed: Checking..."/>
			</StatusBarItem>
		</StatusBar>
	</Grid>
</Window>
"@

[xml]$xamlXml = $xaml
$reader = New-Object System.Xml.XmlNodeReader($xamlXml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{}
@(
	'ModeCombo', 'PollingSecondsBox', 'ApplyPollingButton', 'StartButton', 'StopButton',
	'ExportTypeCombo', 'ExportButton', 'ZoomInButton', 'ZoomOutButton',
	'HealthPulse', 'HealthInnerStop', 'HealthOuterStop',
	'HealthHeadlineText', 'HealthDetailText', 'StatsText', 'LatencyCanvas', 'UsageGrid',
	'MarkdownBrowser', 'StatusText', 'ExcelStatusText'
) | ForEach-Object {
	$controls[$_] = $window.FindName($_)
}

$script:usageItems = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$script:latencySeries = New-Object 'System.Collections.Generic.List[double]'
$script:maxHistorySeconds = 120
$script:updateIntervalSeconds = 2
$script:maxPoints = [Math]::Max(12, [int]($script:maxHistorySeconds / $script:updateIntervalSeconds) + 1)
$script:recentWindow = 20
$script:rng = New-Object System.Random
$script:gridZoom = 1.0
$script:excelInfo = $null
$script:allGridColumnsByOriginalOrder = @()
$script:freezeCheckBoxes = @{}

$controls['UsageGrid'].ItemsSource = $script:usageItems

function New-FreezeHeaderElement {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Title,
		[Parameter(Mandatory = $true)]
		[string]$Key,
		[Parameter(Mandatory = $true)]
		[string]$ToolTip
	)

	$panel = New-Object Windows.Controls.StackPanel
	$panel.Orientation = [Windows.Controls.Orientation]::Horizontal
	$panel.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch

	$text = New-Object Windows.Controls.TextBlock
	$text.Text = $Title
	$text.VerticalAlignment = [Windows.VerticalAlignment]::Center

	$check = New-Object Windows.Controls.CheckBox
	$check.Margin = New-Object Windows.Thickness(8, 0, 0, 0)
	$check.VerticalAlignment = [Windows.VerticalAlignment]::Center
	$check.ToolTip = $ToolTip
	$check.IsChecked = $false

	$panel.Children.Add($text) | Out-Null
	$panel.Children.Add($check) | Out-Null

	$script:freezeCheckBoxes[$Key] = $check
	$panel
}

function Update-FrozenColumns {
	if (-not $script:allGridColumnsByOriginalOrder -or $script:allGridColumnsByOriginalOrder.Count -eq 0) {
		return
	}

	$frozenKeys = @()
	if ($script:freezeCheckBoxes['Environment'].IsChecked) { $frozenKeys += 'Environment' }
	if ($script:freezeCheckBoxes['Solution'].IsChecked) { $frozenKeys += 'Solution' }
	if ($script:freezeCheckBoxes['Workflow'].IsChecked) { $frozenKeys += 'Workflow' }

	$keyToIndex = @{
		Environment = 0
		Solution    = 1
		Workflow    = 2
	}

	$frozenColumns = @()
	foreach ($k in $frozenKeys) {
		$frozenColumns += $script:allGridColumnsByOriginalOrder[$keyToIndex[$k]]
	}

	$orderedColumns = @($frozenColumns)
	foreach ($col in $script:allGridColumnsByOriginalOrder) {
		if ($frozenColumns -notcontains $col) {
			$orderedColumns += $col
		}
	}

	for ($i = 0; $i -lt $orderedColumns.Count; $i++) {
		$orderedColumns[$i].DisplayIndex = $i
	}

	$controls['UsageGrid'].FrozenColumnCount = $frozenColumns.Count
	if ($frozenColumns.Count -gt 0) {
		$names = @()
		foreach ($k in $frozenKeys) {
			$names += $k
		}
		Set-StatusText -Message ("Frozen columns: {0}" -f ($names -join ', '))
	}
	else {
		Set-StatusText -Message 'Frozen columns: none'
	}
}

function Initialize-FreezeHeaderControls {
	$grid = $controls['UsageGrid']
	if (-not $grid -or $grid.Columns.Count -lt 3) {
		return
	}

	$script:allGridColumnsByOriginalOrder = @(
		$grid.Columns[0],
		$grid.Columns[1],
		$grid.Columns[2],
		$grid.Columns[3],
		$grid.Columns[4],
		$grid.Columns[5],
		$grid.Columns[6],
		$grid.Columns[7]
	)

	$grid.Columns[0].Header = New-FreezeHeaderElement -Title 'Environment' -Key 'Environment' -ToolTip 'Freeze/unfreeze Environment column.'
	$grid.Columns[1].Header = New-FreezeHeaderElement -Title 'Solution' -Key 'Solution' -ToolTip 'Freeze/unfreeze Solution column.'
	$grid.Columns[2].Header = New-FreezeHeaderElement -Title 'Workflow' -Key 'Workflow' -ToolTip 'Freeze/unfreeze Workflow column.'

	$script:freezeCheckBoxes['Environment'].Add_Checked({ Update-FrozenColumns })
	$script:freezeCheckBoxes['Environment'].Add_Unchecked({ Update-FrozenColumns })
	$script:freezeCheckBoxes['Solution'].Add_Checked({ Update-FrozenColumns })
	$script:freezeCheckBoxes['Solution'].Add_Unchecked({ Update-FrozenColumns })
	$script:freezeCheckBoxes['Workflow'].Add_Checked({ Update-FrozenColumns })
	$script:freezeCheckBoxes['Workflow'].Add_Unchecked({ Update-FrozenColumns })
}

function Get-ExcelInstallationInfo {
	$excel = $null
	try {
		$excel = New-Object -ComObject Excel.Application
		$version = [string]$excel.Version
		$appPath = ''
		try {
			$appPath = [string]$excel.Path
		}
		catch {
			$appPath = ''
		}

		$exePath = ''
		if ($appPath) {
			$candidate = Join-Path $appPath 'EXCEL.EXE'
			if (Test-Path -LiteralPath $candidate) {
				$exePath = $candidate
			}
		}

		[pscustomobject]@{
			Installed = $true
			Version   = $version
			ExePath   = $exePath
		}
	}
	catch {
		[pscustomobject]@{
			Installed = $false
			Version   = ''
			ExePath   = ''
		}
	}
	finally {
		if ($excel) {
			try { $excel.Quit() } catch {}
			[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
			[GC]::Collect()
			[GC]::WaitForPendingFinalizers()
		}
	}
}

function Update-ExcelStatusBar {
	if (-not $script:excelInfo) {
		$script:excelInfo = Get-ExcelInstallationInfo
	}

	if ($script:excelInfo.Installed) {
		$controls['ExcelStatusText'].Text = 'Excel Installed: Yes'
		$controls['ExcelStatusText'].ToolTip = "Excel Version: $($script:excelInfo.Version)"
	}
	else {
		$controls['ExcelStatusText'].Text = 'Excel Installed: No'
		$controls['ExcelStatusText'].ToolTip = 'Excel was not detected on this machine.'
	}
}

function Set-StatusText {
	param([string]$Message)
	if ($controls['StatusText']) {
		$controls['StatusText'].Text = $Message
	}
}

function Set-GridZoom {
	param(
		[Parameter(Mandatory = $true)]
		[double]$NewZoom
	)

	$script:gridZoom = [Math]::Max(0.70, [Math]::Min(2.00, $NewZoom))
	$controls['UsageGrid'].LayoutTransform = New-Object Windows.Media.ScaleTransform($script:gridZoom, $script:gridZoom)
	Set-StatusText -Message ("Grid Zoom: {0}%" -f [int]([Math]::Round($script:gridZoom * 100)))
}

function Open-ExportFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ExportChoice,
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	switch ($ExportChoice) {
		'PSObject' {
			Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$Path`"" | Out-Null
		}
		'CSV' {
			if ($script:excelInfo -and $script:excelInfo.Installed) {
				if ($script:excelInfo.ExePath -and (Test-Path -LiteralPath $script:excelInfo.ExePath)) {
					Start-Process -FilePath $script:excelInfo.ExePath -ArgumentList "`"$Path`"" | Out-Null
				}
				else {
					Start-Process -FilePath 'excel.exe' -ArgumentList "`"$Path`"" | Out-Null
				}
			}
			else {
				throw 'Excel is not installed. CSV export requires Excel to open automatically.'
			}
		}
		'FormattedExcel' {
			if ($script:excelInfo -and $script:excelInfo.Installed) {
				if ($script:excelInfo.ExePath -and (Test-Path -LiteralPath $script:excelInfo.ExePath)) {
					Start-Process -FilePath $script:excelInfo.ExePath -ArgumentList "`"$Path`"" | Out-Null
				}
				else {
					Start-Process -FilePath 'excel.exe' -ArgumentList "`"$Path`"" | Out-Null
				}
			}
			else {
				throw 'Excel is not installed. Excel export requires Excel to open automatically.'
			}
		}
	}
}

function Convert-MarkdownToHtml {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Markdown
	)

	$encoded = [System.Web.HttpUtility]::HtmlEncode($Markdown)
	$html = $encoded

	$html = [regex]::Replace(
		$html,
		'(?s)```mermaid\s*(.*?)```',
		'<div class="mermaid">$1</div>'
	)

	$html = [regex]::Replace(
		$html,
		'(?m)^##\s+(.+)$',
		'<h2>$1</h2>'
	)
	$html = [regex]::Replace(
		$html,
		'(?m)^###\s+(.+)$',
		'<h3>$1</h3>'
	)

	$paragraphs = $html -split "`r?`n`r?`n"
	$paragraphs = $paragraphs | ForEach-Object {
		$block = $_
		if ($block -match '^<h2>|^<h3>|^<div class="mermaid">') {
			return $block
		}

		$lines = $block -split "`r?`n"
		$lines = $lines | ForEach-Object {
			if ($_ -match '^\-\s+') {
				'<li>' + ($_ -replace '^\-\s+', '') + '</li>'
			}
			else {
				$_
			}
		}
		$listLines = @($lines | Where-Object { $_ -like '<li>*</li>' })

		if ($listLines.Count -gt 0) {
			'<ul>' + ($listLines -join '') + '</ul>'
		}
		else {
			'<p>' + (($lines -join '<br/>')) + '</p>'
		}
	}

	@"
<!DOCTYPE html>
<html>
<head>
	<meta http-equiv="X-UA-Compatible" content="IE=edge" />
	<meta charset="utf-8" />
	<style>
		body { font-family: Segoe UI, Arial, sans-serif; padding: 14px; background: #0B1220; color: #E2E8F0; }
		h2, h3 { color: #93C5FD; }
		p, li { font-size: 14px; line-height: 1.45; }
		.mermaid { background: #0F172A; border: 1px solid #334155; border-radius: 10px; padding: 8px; margin: 10px 0; }
		code { background: #1E293B; padding: 2px 4px; border-radius: 4px; }
	</style>
	<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
	<script>
		try {
			mermaid.initialize({ startOnLoad: true, theme: 'dark' });
		} catch(e) {
			console.log('Mermaid unavailable: ' + e);
		}
	</script>
</head>
<body>
$($paragraphs -join "`n")
</body>
</html>
"@
}

function Get-MarkdownSection {
	@"
## Vibe Power Automate Usage Graph

This tab is rendered from markdown and includes Mermaid diagrams.

### Modes

- Live mode: use `Get-LivePowerAutomateRuns` stub and implement cloud calls.
- Simulation mode: generates synthetic workflow run telemetry.

### Export Options

- CSV: operational exports for downstream processing.
- PSObject: CLIXML for native PowerShell object fidelity.
- FormattedExcel: workbook with formatting and latency chart.

### Mermaid Architecture

```mermaid
flowchart LR
	A[Polling Timer] --> B{Mode}
	B -->|Simulation| C[New-SimulatedRun]
	B -->|Live| D[Get-LivePowerAutomateRuns]
	C --> E[Normalize Usage Record]
	D --> E
	E --> F[Data Grid]
	E --> G[Latency Series]
	G --> H[Canvas Graph Redraw]
	E --> I[Health Motif Update]
```

### Mermaid Sequence

```mermaid
sequenceDiagram
	participant U as UI
	participant T as Timer
	participant S as Source
	T->>S: Request latest run data
	S-->>T: Returns run records
	T->>U: Update grid and chart
	T->>U: Recompute status motif
```

"@
}

function Set-MarkdownTab {
	$markdown = Get-MarkdownSection
	$html = Convert-MarkdownToHtml -Markdown $markdown
	$controls['MarkdownBrowser'].NavigateToString($html)
}

function New-SimulatedRun {
	param(
		[datetime]$Now
	)

	$environments = @('IRS-Prod', 'IRS-Test', 'IRS-Dev', 'Treasury-Shared')
	$solutions = @('ComplianceOps', 'TaxReview', 'AuditRouting', 'UserLifecycle')
	$workflows = @(
		'Sync-Submission-Metadata',
		'Daily-Return-Reconciliation',
		'Notify-Case-Owner',
		'Generate-Exception-Alert',
		'Close-Stale-Approval-Items'
	)

	$latency = [Math]::Round(($script:rng.NextDouble() * 28.0) + 2.0, 1)
	$start = $Now.AddSeconds(-$latency)
	$outcome = if ($script:rng.NextDouble() -lt 0.18) { 'Fail' } else { 'Success' }

	if ($outcome -eq 'Fail') {
		$latency = [Math]::Round($latency + ($script:rng.NextDouble() * 12.0), 1)
		$start = $Now.AddSeconds(-$latency)
	}

	$flowName = $workflows[$script:rng.Next(0, $workflows.Count)]
	$envName = $environments[$script:rng.Next(0, $environments.Count)]
	$solution = $solutions[$script:rng.Next(0, $solutions.Count)]
	$runId = [guid]::NewGuid().ToString()

	[pscustomobject]@{
		EnvironmentName = $envName
		Solution        = $solution
		Workflow        = $flowName
		StartTime       = $start.ToString('yyyy-MM-dd HH:mm:ss')
		EndTime         = $Now.ToString('yyyy-MM-dd HH:mm:ss')
		Outcome         = $outcome
		LatencySeconds  = $latency
		RunHistoryLink  = "https://make.powerautomate.com/environments/$envName/flows/$flowName/runs/$runId"
	}
}

function Get-LivePowerAutomateRuns {
	<#
	.SYNOPSIS
	Live polling stub for Power Automate run history.

	.DESCRIPTION
	Implement one of the integration options below:

	1) Azure AD App + REST API (recommended for unattended polling)
	   - Register app in Entra ID and grant required Power Platform / Dataverse scopes.
	   - Acquire token via client credentials:
		 Invoke-RestMethod to https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token
	   - Query flow/run endpoints (Power Platform API surface) and map fields to:
		 EnvironmentName, Solution, Workflow, StartTime, EndTime, Outcome, LatencySeconds, RunHistoryLink

	2) Microsoft Graph where applicable
	   - Use Graph SDK or Invoke-RestMethod with bearer token.
	   - Correlate workflow-related entities and telemetry where available.

	3) PowerShell Administration modules
	   - Install/use Microsoft.PowerApps.Administration.PowerShell
	   - Gather environment + flow metadata via cmdlets.
	   - Augment with REST calls for run-level telemetry.

	Return contract:
	   Must return an array of PSCustomObject records with the same schema as New-SimulatedRun.
	#>
	param(
		[datetime]$Now
	)

	# TODO: Replace with cloud polling logic.
	# Returning empty array keeps UI responsive while integration is built.
	@()
}

function Update-StatusMotif {
	$count = $script:usageItems.Count
	if ($count -eq 0) {
		$controls['HealthHeadlineText'].Text = 'Health: GOOD'
		$controls['HealthDetailText'].Text = 'No runs yet. Start monitoring to collect telemetry.'
		$controls['StatsText'].Text = 'Runs: 0 | Avg Latency: 0.0 sec | Failures(20): 0'
		$controls['HealthInnerStop'].Color = [Windows.Media.ColorConverter]::ConvertFromString('#22C55E')
		$controls['HealthOuterStop'].Color = [Windows.Media.ColorConverter]::ConvertFromString('#166534')
		$controls['HealthPulse'].Stroke = [Windows.Media.Brushes]::LightGreen
		$controls['HealthHeadlineText'].Foreground = [Windows.Media.Brushes]::LightGreen
		return
	}

	$recent = @($script:usageItems | Select-Object -Last $script:recentWindow)
	$recentFailures = @($recent | Where-Object { $_.Outcome -eq 'Fail' }).Count
	$failureRate = if ($recent.Count -gt 0) { $recentFailures / $recent.Count } else { 0 }

	$latencies = @($script:usageItems | ForEach-Object { [double]$_.LatencySeconds })
	$avgLatency = if ($latencies.Count -gt 0) {
		[Math]::Round((($latencies | Measure-Object -Average).Average), 2)
	}
	else { 0.0 }

	$isWarning = ($failureRate -ge 0.25) -or ($avgLatency -ge 15)
	if ($isWarning) {
		$controls['HealthHeadlineText'].Text = 'Health: WARNING'
		$controls['HealthDetailText'].Text = 'Elevated failures or latency. Investigate workflow bottlenecks and connector throttling.'
		$controls['HealthInnerStop'].Color = [Windows.Media.ColorConverter]::ConvertFromString('#FACC15')
		$controls['HealthOuterStop'].Color = [Windows.Media.ColorConverter]::ConvertFromString('#854D0E')
		$controls['HealthPulse'].Stroke = [Windows.Media.Brushes]::Khaki
		$controls['HealthHeadlineText'].Foreground = [Windows.Media.Brushes]::Khaki
	}
	else {
		$controls['HealthHeadlineText'].Text = 'Health: GOOD'
		$controls['HealthDetailText'].Text = 'Low failure rate and normal latency.'
		$controls['HealthInnerStop'].Color = [Windows.Media.ColorConverter]::ConvertFromString('#22C55E')
		$controls['HealthOuterStop'].Color = [Windows.Media.ColorConverter]::ConvertFromString('#166534')
		$controls['HealthPulse'].Stroke = [Windows.Media.Brushes]::LightGreen
		$controls['HealthHeadlineText'].Foreground = [Windows.Media.Brushes]::LightGreen
	}

	$controls['StatsText'].Text = "Runs: $count | Avg Latency: $avgLatency sec | Failures(20): $recentFailures"
}

function Draw-LatencyGraph {
	$canvas = $controls['LatencyCanvas']
	$canvas.Children.Clear()

	$width = [double]$canvas.ActualWidth
	if ([double]::IsNaN($width) -or [double]::IsInfinity($width) -or $width -le 0) {
		$width = [double]$canvas.Width
	}
	if ([double]::IsNaN($width) -or [double]::IsInfinity($width) -or $width -le 0) {
		$width = 700.0
	}

	$height = [double]$canvas.ActualHeight
	if ([double]::IsNaN($height) -or [double]::IsInfinity($height) -or $height -le 0) {
		$height = [double]$canvas.Height
	}
	if ([double]::IsNaN($height) -or [double]::IsInfinity($height) -or $height -le 0) {
		$height = 320.0
	}

	$paddingLeft = 44
	$paddingRight = 16
	$paddingTop = 14
	$paddingBottom = 28

	$plotWidth = [Math]::Max(20.0, [double]($width - $paddingLeft - $paddingRight))
	$plotHeight = [Math]::Max(20.0, [double]($height - $paddingTop - $paddingBottom))

	$gridBrush = New-Object Windows.Media.SolidColorBrush([Windows.Media.ColorConverter]::ConvertFromString('#1F2937'))
	$axisBrush = New-Object Windows.Media.SolidColorBrush([Windows.Media.ColorConverter]::ConvertFromString('#64748B'))

	for ($i = 0; $i -le 5; $i++) {
		$y = $paddingTop + ($plotHeight / 5.0 * $i)
		$line = New-Object Windows.Shapes.Line
		$line.X1 = $paddingLeft
		$line.X2 = $paddingLeft + $plotWidth
		$line.Y1 = $y
		$line.Y2 = $y
		$line.Stroke = $gridBrush
		$line.StrokeThickness = 1
		$canvas.Children.Add($line) | Out-Null

		$latLabel = New-Object Windows.Controls.TextBlock
		$latValue = [Math]::Round((1 - ($i / 5.0)) * 40, 0)
		$latLabel.Text = "$latValue"
		$latLabel.Foreground = [Windows.Media.Brushes]::SlateGray
		[Windows.Controls.Canvas]::SetLeft($latLabel, 8)
		[Windows.Controls.Canvas]::SetTop($latLabel, $y - 8)
		$canvas.Children.Add($latLabel) | Out-Null
	}

	for ($sec = 0; $sec -le $script:maxHistorySeconds; $sec += 10) {
		$x = $paddingLeft + ($plotWidth * (1 - ($sec / [double]$script:maxHistorySeconds)))
		$tick = New-Object Windows.Shapes.Line
		$tick.X1 = $x
		$tick.X2 = $x
		$tick.Y1 = $paddingTop
		$tick.Y2 = $paddingTop + $plotHeight
		$tick.Stroke = $gridBrush
		$tick.StrokeThickness = 1
		$canvas.Children.Add($tick) | Out-Null

		$label = New-Object Windows.Controls.TextBlock
		$label.Text = "$sec s"
		$label.Foreground = [Windows.Media.Brushes]::SlateGray
		[Windows.Controls.Canvas]::SetLeft($label, $x - 12)
		[Windows.Controls.Canvas]::SetTop($label, $paddingTop + $plotHeight + 4)
		$canvas.Children.Add($label) | Out-Null
	}

	$xAxis = New-Object Windows.Shapes.Line
	$xAxis.X1 = $paddingLeft
	$xAxis.X2 = $paddingLeft + $plotWidth
	$xAxis.Y1 = $paddingTop + $plotHeight
	$xAxis.Y2 = $paddingTop + $plotHeight
	$xAxis.Stroke = $axisBrush
	$xAxis.StrokeThickness = 1.4
	$canvas.Children.Add($xAxis) | Out-Null

	$yAxis = New-Object Windows.Shapes.Line
	$yAxis.X1 = $paddingLeft
	$yAxis.X2 = $paddingLeft
	$yAxis.Y1 = $paddingTop
	$yAxis.Y2 = $paddingTop + $plotHeight
	$yAxis.Stroke = $axisBrush
	$yAxis.StrokeThickness = 1.4
	$canvas.Children.Add($yAxis) | Out-Null

	if ($script:latencySeries.Count -lt 2) {
		return
	}

	$maxLatencyScale = 40.0
	$points = New-Object Windows.Media.PointCollection
	$seriesCount = $script:latencySeries.Count
	$startIndex = [Math]::Max(0, $seriesCount - $script:maxPoints)

	$visible = @()
	for ($i = $startIndex; $i -lt $seriesCount; $i++) {
		$visible += [double]$script:latencySeries[$i]
	}

	for ($i = 0; $i -lt $visible.Count; $i++) {
		$x = $paddingLeft + ($plotWidth * ($i / [double]([Math]::Max(1, $script:maxPoints - 1))))
		$yNorm = [Math]::Min(1.0, [Math]::Max(0.0, ($visible[$i] / $maxLatencyScale)))
		$y = $paddingTop + (($plotHeight) * (1.0 - $yNorm))
		$points.Add((New-Object Windows.Point($x, $y)))
	}

	$polyline = New-Object Windows.Shapes.Polyline
	$polyline.Points = $points
	$polyline.Stroke = [Windows.Media.Brushes]::DeepSkyBlue
	$polyline.StrokeThickness = 2.2
	$canvas.Children.Add($polyline) | Out-Null
}

function Add-UsageRecord {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$Record
	)

	$script:usageItems.Add($Record)
	$script:latencySeries.Add([double]$Record.LatencySeconds)

	while ($script:latencySeries.Count -gt ($script:maxPoints * 3)) {
		$script:latencySeries.RemoveAt(0)
	}

	if ($script:usageItems.Count -gt 1000) {
		$script:usageItems.RemoveAt(0)
	}

	$controls['UsageGrid'].ScrollIntoView($Record)
	Update-StatusMotif
	Draw-LatencyGraph
}

function Get-ModeText {
	$item = $controls['ModeCombo'].SelectedItem
	if (-not $item) { return 'Simulation' }
	[string]$item.Content
}

function Tick-Monitoring {
	$now = Get-Date
	$mode = Get-ModeText

	if ($mode -eq 'Live') {
		$records = @(Get-LivePowerAutomateRuns -Now $now)
		foreach ($r in $records) {
			Add-UsageRecord -Record $r
		}
	}
	else {
		Add-UsageRecord -Record (New-SimulatedRun -Now $now)
	}
}

function Export-ToFormattedExcel {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,
		[Parameter(Mandatory = $true)]
		[object[]]$Rows
	)

	$excel = $null
	$workbook = $null
	$sheet = $null
	try {
		$excel = New-Object -ComObject Excel.Application
		$excel.Visible = $false
		$workbook = $excel.Workbooks.Add()
		$sheet = $workbook.Worksheets.Item(1)
		$sheet.Name = 'UsageLog'

		$headers = @('Environment', 'Solution', 'Workflow', 'StartTime', 'EndTime', 'Outcome', 'LatencySeconds', 'RunHistoryLink')
		for ($c = 0; $c -lt $headers.Count; $c++) {
			$sheet.Cells.Item(1, $c + 1).Value2 = $headers[$c]
		}

		$headerRange = $sheet.Range('A1', 'H1')
		$headerRange.Font.Bold = $true
		$headerRange.Interior.Color = 0x4F81BD
		$headerRange.Font.Color = 0xFFFFFF

		$rowIndex = 2
		foreach ($row in $Rows) {
			$sheet.Cells.Item($rowIndex, 1).Value2 = $row.EnvironmentName
			$sheet.Cells.Item($rowIndex, 2).Value2 = $row.Solution
			$sheet.Cells.Item($rowIndex, 3).Value2 = $row.Workflow
			$sheet.Cells.Item($rowIndex, 4).Value2 = $row.StartTime
			$sheet.Cells.Item($rowIndex, 5).Value2 = $row.EndTime
			$sheet.Cells.Item($rowIndex, 6).Value2 = $row.Outcome
			$sheet.Cells.Item($rowIndex, 7).Value2 = [double]$row.LatencySeconds
			$sheet.Cells.Item($rowIndex, 8).Value2 = $row.RunHistoryLink
			$rowIndex++
		}

		$lastRow = [Math]::Max(2, $rowIndex - 1)
		$dataRange = $sheet.Range("A1", "H$lastRow")
		$dataRange.Borders.LineStyle = 1
		$dataRange.EntireColumn.AutoFit() | Out-Null

		$chartObjects = $sheet.ChartObjects()
		$chartObj = $chartObjects.Add(680, 20, 520, 280)
		$chart = $chartObj.Chart
		$chart.ChartType = 4
		$series = $chart.SeriesCollection().NewSeries()
		$series.Name = 'LatencySeconds'
		$series.XValues = $sheet.Range("A2", "A$lastRow")
		$series.Values = $sheet.Range("G2", "G$lastRow")
		$chart.HasTitle = $true
		$chart.ChartTitle.Text = 'Power Automate Latency Trend'

		$workbook.SaveAs($Path)
	}
	finally {
		if ($workbook) { $workbook.Close($true) | Out-Null }
		if ($excel) { $excel.Quit() }

		if ($sheet) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheet) }
		if ($workbook) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) }
		if ($excel) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }

		[GC]::Collect()
		[GC]::WaitForPendingFinalizers()
	}
}

function Export-UsageData {
	$rows = @($script:usageItems)
	if ($rows.Count -eq 0) {
		[System.Windows.MessageBox]::Show('No data to export yet.', 'Export', 'OK', 'Information') | Out-Null
		return
	}

	$exportChoice = [string]($controls['ExportTypeCombo'].SelectedItem.Content)
	$dialog = New-Object Microsoft.Win32.SaveFileDialog

	switch ($exportChoice) {
		'CSV' {
			$dialog.Filter = 'CSV (*.csv)|*.csv'
			$dialog.FileName = 'PowerAutomateUsage.csv'
		}
		'PSObject' {
			$dialog.Filter = 'PowerShell CLIXML (*.clixml)|*.clixml'
			$dialog.FileName = 'PowerAutomateUsage.clixml'
		}
		'FormattedExcel' {
			$dialog.Filter = 'Excel Workbook (*.xlsx)|*.xlsx'
			$dialog.FileName = 'PowerAutomateUsage.xlsx'
		}
		default {
			[System.Windows.MessageBox]::Show('Unknown export type.', 'Export', 'OK', 'Warning') | Out-Null
			return
		}
	}

	$result = $dialog.ShowDialog()
	if (-not $result) { return }

	$path = $dialog.FileName

	try {
		switch ($exportChoice) {
			'CSV' {
				$rows | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
			}
			'PSObject' {
				$rows | Export-Clixml -Path $path -Depth 6
			}
			'FormattedExcel' {
				Export-ToFormattedExcel -Path $path -Rows $rows
			}
		}
		Open-ExportFile -ExportChoice $exportChoice -Path $path
		Set-StatusText -Message "Export completed: $path"
		[System.Windows.MessageBox]::Show("Export completed: $path", 'Export', 'OK', 'Information') | Out-Null
	}
	catch {
		Set-StatusText -Message "Export failed: $($_.Exception.Message)"
		[System.Windows.MessageBox]::Show("Export failed: $($_.Exception.Message)", 'Export Error', 'OK', 'Error') | Out-Null
	}
}

$script:updateTimer = New-Object Windows.Threading.DispatcherTimer
$script:updateTimer.Interval = [TimeSpan]::FromSeconds($script:updateIntervalSeconds)
$script:updateTimer.Add_Tick({
	try {
		Tick-Monitoring
	}
	catch {
		$controls['HealthHeadlineText'].Text = 'Health: WARNING'
		$controls['HealthDetailText'].Text = "Update error: $($_.Exception.Message)"
	}
})

$controls['ApplyPollingButton'].Add_Click({
	$text = $controls['PollingSecondsBox'].Text
	$value = 0
	if (-not [int]::TryParse($text, [ref]$value) -or $value -lt 1 -or $value -gt 60) {
		[System.Windows.MessageBox]::Show('Polling interval must be an integer between 1 and 60.', 'Polling', 'OK', 'Warning') | Out-Null
		return
	}

	$script:updateIntervalSeconds = $value
	$script:updateTimer.Interval = [TimeSpan]::FromSeconds($script:updateIntervalSeconds)
	$script:maxPoints = [Math]::Max(12, [int]($script:maxHistorySeconds / $script:updateIntervalSeconds) + 1)
	Set-StatusText -Message "Polling interval applied: $value sec"
	Draw-LatencyGraph
})

$controls['StartButton'].Add_Click({
	$script:updateTimer.Start()
	$controls['StartButton'].IsEnabled = $false
	$controls['StopButton'].IsEnabled = $true
	Set-StatusText -Message 'Monitoring started'
})

$controls['StopButton'].Add_Click({
	$script:updateTimer.Stop()
	$controls['StartButton'].IsEnabled = $true
	$controls['StopButton'].IsEnabled = $false
	Set-StatusText -Message 'Monitoring stopped'
})

$controls['ExportButton'].Add_Click({ Export-UsageData })

$controls['ZoomInButton'].Add_Click({ Set-GridZoom -NewZoom ($script:gridZoom + 0.10) })
$controls['ZoomOutButton'].Add_Click({ Set-GridZoom -NewZoom ($script:gridZoom - 0.10) })

$controls['UsageGrid'].AddHandler(
	[System.Windows.Documents.Hyperlink]::ClickEvent,
	[System.Windows.RoutedEventHandler]{
		param($sender, $e)
		try {
			$link = [string]$e.OriginalSource.NavigateUri
			if ($link) {
				Start-Process $link | Out-Null
			}
		}
		catch {
		}
	}
)

$controls['LatencyCanvas'].Add_SizeChanged({ Draw-LatencyGraph })

$window.Add_Closing({
	if ($script:updateTimer) {
		$script:updateTimer.Stop()
	}
})

Set-MarkdownTab
Update-StatusMotif
Draw-LatencyGraph
Set-GridZoom -NewZoom $script:gridZoom
Update-ExcelStatusBar
Initialize-FreezeHeaderControls
Set-StatusText -Message 'Ready'

[void]$window.ShowDialog()

