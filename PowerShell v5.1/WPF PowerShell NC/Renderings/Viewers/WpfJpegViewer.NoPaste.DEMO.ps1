param(
	[switch]$CommandLine,
	[Parameter(Position = 0)]
	[string]$ImageFile,
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$ExtraArgs
)

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:SettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'WpfJpegViewer.Prompts.Settings.json'

function Format-Bytes {
	param([long]$Bytes)

	if ($Bytes -lt 1KB) { return "$Bytes B" }
	if ($Bytes -lt 1MB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
	if ($Bytes -lt 1GB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
	if ($Bytes -lt 1TB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
	return ('{0:N2} TB' -f ($Bytes / 1TB))
}

function Format-SizeForList {
	param([long]$Bytes)

	if ($Bytes -lt 1MB) {
		return ('{0:N1} KB' -f ($Bytes / 1KB))
	}
	return ('{0:N2} MB' -f ($Bytes / 1MB))
}

function Get-IsJpegPath {
	param([string]$Path)
	return ([IO.Path]::GetExtension($Path) -match '^\.(jpg|jpeg)$')
}

function Get-JpegFilesInDirectory {
	param([string]$DirectoryPath)

	if (-not (Test-Path -LiteralPath $DirectoryPath -PathType Container)) {
		return @()
	}

	return @(Get-ChildItem -LiteralPath $DirectoryPath -File -ErrorAction SilentlyContinue |
		Where-Object { $_.Extension -match '^\.(jpg|jpeg)$' } |
		Sort-Object Name)
}

function Decode-ExifText {
	param([byte[]]$Bytes)

	if (-not $Bytes -or $Bytes.Length -eq 0) { return '' }

	$asciiPrefix = [System.Text.Encoding]::ASCII.GetString($Bytes, 0, [Math]::Min(8, $Bytes.Length))
	if ($asciiPrefix.StartsWith('ASCII')) {
		$text = [System.Text.Encoding]::ASCII.GetString($Bytes, 8, $Bytes.Length - 8)
		return $text.Trim([char]0, ' ')
	}

	if ($asciiPrefix.StartsWith('UNICODE')) {
		$text = [System.Text.Encoding]::Unicode.GetString($Bytes, 8, $Bytes.Length - 8)
		return $text.Trim([char]0, ' ')
	}

	try {
		$unicode = [System.Text.Encoding]::Unicode.GetString($Bytes).Trim([char]0, ' ')
		if ($unicode -match '[A-Za-z0-9]') { return $unicode }
	} catch {
	}

	try {
		return [System.Text.Encoding]::UTF8.GetString($Bytes).Trim([char]0, ' ')
	} catch {
		return ''
	}
}

function Get-JpegComment {
	param([System.Drawing.Image]$Image)

	$comment = ''

	$propertyIds = @{
		XPComment       = 0x9C9C
		UserComment     = 0x9286
		ImageDescription = 0x010E
	}

	if ($Image.PropertyIdList -contains $propertyIds.XPComment) {
		$prop = $Image.GetPropertyItem($propertyIds.XPComment)
		$comment = [System.Text.Encoding]::Unicode.GetString($prop.Value).Trim([char]0, ' ')
		if ($comment) { return $comment }
	}

	if ($Image.PropertyIdList -contains $propertyIds.UserComment) {
		$prop = $Image.GetPropertyItem($propertyIds.UserComment)
		$comment = Decode-ExifText -Bytes $prop.Value
		if ($comment) { return $comment }
	}

	if ($Image.PropertyIdList -contains $propertyIds.ImageDescription) {
		$prop = $Image.GetPropertyItem($propertyIds.ImageDescription)
		$comment = Decode-ExifText -Bytes $prop.Value
		if ($comment) { return $comment }
	}

	return ''
}

function Set-JpegComment {
	param(
		[string]$Path,
		[string]$CommentText
	)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "File not found: $Path"
	}

	$comment = if ($null -ne $CommentText) { [string]$CommentText } else { '' }
	$img = $null
	$tempPath = Join-Path -Path ([IO.Path]::GetDirectoryName($Path)) -ChildPath (([IO.Path]::GetFileNameWithoutExtension($Path)) + '.tmp.' + [Guid]::NewGuid().ToString('N') + '.jpg')

	try {
		$img = [System.Drawing.Image]::FromFile($Path)

		$asciiCommentBytes = [System.Text.Encoding]::ASCII.GetBytes($comment + [char]0)
		$descProp = [System.Runtime.Serialization.FormatterServices]::GetUninitializedObject([System.Drawing.Imaging.PropertyItem])
		$descProp.Id = 0x010E
		$descProp.Type = 2
		$descProp.Len = $asciiCommentBytes.Length
		$descProp.Value = $asciiCommentBytes
		$img.SetPropertyItem($descProp)

		$xpCommentBytes = [System.Text.Encoding]::Unicode.GetBytes($comment + [char]0)
		$xpProp = [System.Runtime.Serialization.FormatterServices]::GetUninitializedObject([System.Drawing.Imaging.PropertyItem])
		$xpProp.Id = 0x9C9C
		$xpProp.Type = 1
		$xpProp.Len = $xpCommentBytes.Length
		$xpProp.Value = $xpCommentBytes
		$img.SetPropertyItem($xpProp)

		$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
		if (-not $jpegCodec) {
			throw 'JPEG encoder unavailable in System.Drawing on this machine.'
		}

		$encParams = New-Object System.Drawing.Imaging.EncoderParameters 1
		$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]100)
		$img.Save($tempPath, $jpegCodec, $encParams)
	} finally {
		if ($img) { $img.Dispose() }
	}

	try {
		[IO.File]::Copy($tempPath, $Path, $true)
	} finally {
		if (Test-Path -LiteralPath $tempPath) {
			Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
		}
	}
}

function Test-JpegHasComment {
	param([string]$Path)

	$img = $null
	try {
		$img = [System.Drawing.Image]::FromFile($Path)
		$comment = Get-JpegComment -Image $img
		return (-not [string]::IsNullOrWhiteSpace($comment))
	} catch {
		return $false
	} finally {
		if ($img) { $img.Dispose() }
	}
}

function Get-JpegListDetails {
	param([string]$Path)

	$details = [ordered]@{
		HasComment       = $false
		CompressionRatio = 'n/a'
		CommentText      = ''
	}

	$img = $null
	try {
		$img = [System.Drawing.Image]::FromFile($Path)
		$comment = Get-JpegComment -Image $img
		$details.HasComment = (-not [string]::IsNullOrWhiteSpace($comment))
		$details.CommentText = if ($details.HasComment) { $comment } else { '' }

		$fileLen = (Get-Item -LiteralPath $Path -ErrorAction Stop).Length
		if ($fileLen -gt 0 -and $img.Width -gt 0 -and $img.Height -gt 0) {
			$rawBytes = [double]$img.Width * [double]$img.Height * 3.0
			$ratio = $rawBytes / [double]$fileLen
			if ([double]::IsInfinity($ratio) -or [double]::IsNaN($ratio)) {
				$details.CompressionRatio = 'n/a'
			} else {
				$details.CompressionRatio = ('{0:N1}:1' -f $ratio)
			}
		}
	} catch {
	} finally {
		if ($img) { $img.Dispose() }
	}

	return $details
}

function Add-PropRow {
	param(
		[System.Collections.ObjectModel.ObservableCollection[object]]$Collection,
		[string]$Property,
		[string]$Value,
		[bool]$IsUrl = $false,
		[string]$Url = ''
	)

	$Collection.Add([pscustomobject]@{
		Property = $Property
		Value    = $Value
		IsUrl    = $IsUrl
		Url      = $Url
	})
}

function New-PropRowObject {
	param(
		[string]$Property,
		[string]$Value,
		[bool]$IsUrl = $false,
		[string]$Url = ''
	)

	return [pscustomobject]@{
		Property = $Property
		Value    = $Value
		IsUrl    = $IsUrl
		Url      = $Url
	}
}

function Get-JpegMetadataRows {
	param([string]$Path)

	$rows = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
	$comment = ''
	$urlRegex = [regex]'https?://[^\s"''<>)]+'

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		return [pscustomobject]@{ Rows = $rows; Comment = '' }
	}

	$fileInfo = Get-Item -LiteralPath $Path
	Add-PropRow -Collection $rows -Property 'File Name' -Value $fileInfo.Name
	Add-PropRow -Collection $rows -Property 'Full Path' -Value $fileInfo.FullName
	Add-PropRow -Collection $rows -Property 'File Size' -Value (Format-Bytes $fileInfo.Length)
	Add-PropRow -Collection $rows -Property 'Date Created' -Value $fileInfo.CreationTime.ToString('yyyy-MM-dd HH:mm:ss')
	Add-PropRow -Collection $rows -Property 'Date Modified' -Value $fileInfo.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')

	$img = $null
	try {
		$img = [System.Drawing.Image]::FromFile($Path)
		Add-PropRow -Collection $rows -Property 'Pixel Width' -Value ([string]$img.Width)
		Add-PropRow -Collection $rows -Property 'Pixel Height' -Value ([string]$img.Height)
		Add-PropRow -Collection $rows -Property 'Horizontal DPI' -Value ([string]$img.HorizontalResolution)
		Add-PropRow -Collection $rows -Property 'Vertical DPI' -Value ([string]$img.VerticalResolution)
		Add-PropRow -Collection $rows -Property 'Raw Format' -Value $img.RawFormat.ToString()

		$comment = Get-JpegComment -Image $img
	} catch {
		Add-PropRow -Collection $rows -Property 'Image Read Error' -Value $_.Exception.Message
	} finally {
		if ($img) { $img.Dispose() }
	}

	$urlMatches = @()
	if (-not [string]::IsNullOrWhiteSpace($comment)) {
		$urlMatches = @($urlRegex.Matches($comment))
	}

	$insertIndex = 1
	if ($urlMatches.Count -gt 0) {
		$urlIndex = 1
		foreach ($match in $urlMatches) {
			$url = [string]$match.Value
			$rows.Insert($insertIndex, (New-PropRowObject -Property ("Comment URL $urlIndex") -Value $url -IsUrl $true -Url $url))
			$insertIndex++
			$urlIndex++
		}
	} else {
		$rows.Insert($insertIndex, (New-PropRowObject -Property 'Comment URL 1' -Value 'None' -IsUrl $false -Url ''))
	}

	return [pscustomobject]@{
		Rows    = $rows
		Comment = $comment
	}
}

function Get-AncestorOfType {
	param(
		[System.Windows.DependencyObject]$Start,
		[Type]$TargetType
	)

	$current = $Start
	while ($current -and -not $TargetType.IsInstanceOfType($current)) {
		$current = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
	}
	return $current
}

function Get-DefaultSettings {
	return [ordered]@{
		Window = [ordered]@{
			Left   = [double]::NaN
			Top    = [double]::NaN
			Width  = 1400
			Height = 900
			State  = 'Normal'
		}
		DebugWindow = [ordered]@{
			Left   = [double]::NaN
			Top    = [double]::NaN
			Width  = 420
			Height = 220
		}
		LastFiles        = @()
		LastSelectedFile = ''
		LastCopyFormat   = 'Text'
	}
}

function Read-ViewerSettings {
	if (-not (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf)) {
		return Get-DefaultSettings
	}

	try {
		$raw = Get-Content -LiteralPath $script:SettingsPath -Raw -ErrorAction Stop
		if ([string]::IsNullOrWhiteSpace($raw)) {
			return Get-DefaultSettings
		}

		$parsed = $raw | ConvertFrom-Json -ErrorAction Stop
		$defaults = Get-DefaultSettings

		if ($parsed.Window) {
			$defaults.Window.Left = [double]$parsed.Window.Left
			$defaults.Window.Top = [double]$parsed.Window.Top
			$defaults.Window.Width = [double]$parsed.Window.Width
			$defaults.Window.Height = [double]$parsed.Window.Height
			$defaults.Window.State = [string]$parsed.Window.State
		}

		if ($parsed.DebugWindow) {
			$defaults.DebugWindow.Left = [double]$parsed.DebugWindow.Left
			$defaults.DebugWindow.Top = [double]$parsed.DebugWindow.Top
			$defaults.DebugWindow.Width = [double]$parsed.DebugWindow.Width
			$defaults.DebugWindow.Height = [double]$parsed.DebugWindow.Height
		}

		if ($parsed.LastFiles) {
			$defaults.LastFiles = @($parsed.LastFiles)
		}

		if ($parsed.LastSelectedFile) {
			$defaults.LastSelectedFile = [string]$parsed.LastSelectedFile
		}

		if ($parsed.LastCopyFormat) {
			$defaults.LastCopyFormat = [string]$parsed.LastCopyFormat
		}

		return $defaults
	} catch {
		return Get-DefaultSettings
	}
}

function Write-ViewerSettings {
	param(
		[hashtable]$Settings,
		[System.Windows.Window]$Window,
		[System.Collections.IEnumerable]$CurrentFiles,
		[string]$SelectedFile,
		[string]$CopyFormat,
		[System.Windows.Window]$DebugWindow
	)

	$windowToSave = if ($Window.WindowState -eq 'Normal') { $Window } else { $Window.RestoreBounds }

	$Settings.Window.Left = [double]$windowToSave.Left
	$Settings.Window.Top = [double]$windowToSave.Top
	$Settings.Window.Width = [double]$windowToSave.Width
	$Settings.Window.Height = [double]$windowToSave.Height
	$Settings.Window.State = [string]$Window.WindowState

	$last = New-Object System.Collections.Generic.List[string]
	foreach ($f in $CurrentFiles) {
		if ($f -and $f.FullPath -and (Test-Path -LiteralPath $f.FullPath -PathType Leaf)) {
			[void]$last.Add([string]$f.FullPath)
		}
	}

	$Settings.LastFiles = $last.ToArray()
	$Settings.LastSelectedFile = if ($SelectedFile) { $SelectedFile } else { '' }
	$Settings.LastCopyFormat = if ($CopyFormat) { $CopyFormat } else { 'Text' }

	if ($DebugWindow) {
		$Settings.DebugWindow.Left = [double]$DebugWindow.Left
		$Settings.DebugWindow.Top = [double]$DebugWindow.Top
		$Settings.DebugWindow.Width = [double]$DebugWindow.Width
		$Settings.DebugWindow.Height = [double]$DebugWindow.Height
	}

	try {
		$Settings | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
	} catch {
	}
}

function Clamp-WindowToVisibleScreen {
	param(
		[System.Windows.Window]$Window,
		[double]$DefaultLeft,
		[double]$DefaultTop
	)

	if (-not $Window) { return }

	$vsLeft = [double][System.Windows.SystemParameters]::VirtualScreenLeft
	$vsTop = [double][System.Windows.SystemParameters]::VirtualScreenTop
	$vsWidth = [double][System.Windows.SystemParameters]::VirtualScreenWidth
	$vsHeight = [double][System.Windows.SystemParameters]::VirtualScreenHeight

	$width = if ($Window.Width -gt 100) { [double]$Window.Width } else { 420.0 }
	$height = if ($Window.Height -gt 80) { [double]$Window.Height } else { 220.0 }

	$left = if ([double]::IsNaN([double]$Window.Left)) { $DefaultLeft } else { [double]$Window.Left }
	$top = if ([double]::IsNaN([double]$Window.Top)) { $DefaultTop } else { [double]$Window.Top }

	$minVisibleX = [Math]::Min(120.0, $width * 0.5)
	$minVisibleY = [Math]::Min(80.0, $height * 0.5)

	$minLeft = $vsLeft - $width + $minVisibleX
	$maxLeft = ($vsLeft + $vsWidth) - $minVisibleX
	$minTop = $vsTop
	$maxTop = ($vsTop + $vsHeight) - $minVisibleY

	$Window.Left = [Math]::Max($minLeft, [Math]::Min($left, $maxLeft))
	$Window.Top = [Math]::Max($minTop, [Math]::Min($top, $maxTop))
}

function Get-PropertyRows {
	$rows = @()
	if ($dgProps -and $dgProps.ItemsSource) {
		foreach ($row in $dgProps.ItemsSource) {
			if ($row) { $rows += $row }
		}
	}
	return $rows
}

function Convert-PropsToClipboardText {
	param([string]$FormatName)

	$rows = Get-PropertyRows
	if (-not $rows -or $rows.Count -eq 0) { return '' }

	switch ($FormatName) {
		'CSV' {
			return (($rows | Select-Object Property, Value, IsUrl, Url) | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
		}
		'TSV Tab separated' {
			$lines = @('Property	Value	IsUrl	Url')
			foreach ($r in $rows) {
				$prop = ([string]$r.Property) -replace "`t", ' '
				$val = ([string]$r.Value) -replace "`t", ' '
				$isUrl = [string]$r.IsUrl
				$url = ([string]$r.Url) -replace "`t", ' '
				$lines += "$prop`t$val`t$isUrl`t$url"
			}
			return $lines -join [Environment]::NewLine
		}
		'PSObject format' {
			return (($rows | Select-Object Property, Value, IsUrl, Url) | Format-List | Out-String).TrimEnd()
		}
		default {
			$lines = foreach ($r in $rows) { "{0}: {1}" -f $r.Property, $r.Value }
			return $lines -join [Environment]::NewLine
		}
	}
}

function Update-CommentIndicator {
	param([string]$CommentText)

	if (-not $icoComment) { return }
	if ([string]::IsNullOrWhiteSpace($CommentText)) {
		$icoComment.Visibility = 'Collapsed'
	} else {
		$icoComment.Visibility = 'Visible'
	}
}

function Update-CommentUrlRowsInGrid {
	param([string]$CommentText)

	if (-not $dgProps -or -not $dgProps.ItemsSource) { return }

	$sourceRows = @($dgProps.ItemsSource)
	if ($sourceRows.Count -eq 0) { return }

	$newRows = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
	foreach ($row in $sourceRows) {
		if (-not $row) { continue }
		if ([string]$row.Property -notmatch '^Comment URL\s+\d+$') {
			$newRows.Add($row)
		}
	}

	$insertIndex = if ($newRows.Count -gt 0) { 1 } else { 0 }
	$regex = [regex]'https?://[^\s"''<>)]+'
	$matches = @()
	if (-not [string]::IsNullOrWhiteSpace($CommentText)) {
		$matches = @($regex.Matches($CommentText))
	}

	if ($matches.Count -gt 0) {
		$urlIndex = 1
		foreach ($m in $matches) {
			$url = [string]$m.Value
			$newRows.Insert($insertIndex, (New-PropRowObject -Property ("Comment URL $urlIndex") -Value $url -IsUrl $true -Url $url))
			$insertIndex++
			$urlIndex++
		}
	} else {
		$newRows.Insert($insertIndex, (New-PropRowObject -Property 'Comment URL 1' -Value 'None' -IsUrl $false -Url ''))
	}

	$dgProps.ItemsSource = $newRows
}

function Show-AboutDialog {
	param(
		[System.Windows.Window]$Owner,
		[switch]$AllowAppendUrl,
		[int]$AutoCloseSeconds = 0
	)

	$timer = $null

	[xml]$aboutXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="WPF JPEG Viewer"
		Width="620"
		Height="462"
		WindowStartupLocation="CenterOwner"
		ResizeMode="NoResize"
		Background="#0B1220">
	<Window.Triggers>
		<EventTrigger RoutedEvent="Window.Loaded">
			<BeginStoryboard>
				<Storyboard RepeatBehavior="Forever">
					<DoubleAnimation Storyboard.TargetName="jpegColorPanel" Storyboard.TargetProperty="Width" From="250" To="84" Duration="0:0:2.93" AutoReverse="True"/>
					<DoubleAnimation Storyboard.TargetName="jpegColorPanel" Storyboard.TargetProperty="Opacity" From="1.0" To="0.62" Duration="0:0:2.93" AutoReverse="True"/>
					<DoubleAnimation Storyboard.TargetName="jpegColorPanel" Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleY)" From="1.0" To="0.86" Duration="0:0:2.93" AutoReverse="True"/>
					<DoubleAnimation Storyboard.TargetName="jpegCompressedStub" Storyboard.TargetProperty="Opacity" From="0.25" To="1.0" Duration="0:0:2.93" AutoReverse="True"/>
					<DoubleAnimation Storyboard.TargetName="jpegCompressedStub" Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleX)" From="0.78" To="1.0" Duration="0:0:2.93" AutoReverse="True"/>
					<DoubleAnimation Storyboard.TargetName="txtExpandedCue" Storyboard.TargetProperty="Opacity" From="1.0" To="0.25" Duration="0:0:2.93" AutoReverse="True"/>
					<DoubleAnimation Storyboard.TargetName="txtCompressedCue" Storyboard.TargetProperty="Opacity" From="0.25" To="1.0" Duration="0:0:2.93" AutoReverse="True"/>
				</Storyboard>
			</BeginStoryboard>
		</EventTrigger>
	</Window.Triggers>
	<Window.Resources>
		<Style TargetType="{x:Type Hyperlink}">
			<Setter Property="Foreground" Value="#FDE047"/>
			<Setter Property="TextDecorations" Value="Underline"/>
		</Style>
		<Style x:Key="DialogPurpleButtonStyle" TargetType="Button">
			<Setter Property="Background" Value="#E9D5FF"/>
			<Setter Property="BorderBrush" Value="#6D28D9"/>
			<Setter Property="Foreground" Value="#3B0764"/>
			<Setter Property="BorderThickness" Value="4"/>
			<Setter Property="FontWeight" Value="Bold"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="Padding" Value="8,3"/>
			<Setter Property="Cursor" Value="Hand"/>
		</Style>
	</Window.Resources>
	<Grid Margin="12">
		<Grid.RowDefinitions>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>
		<Border Grid.Row="0" CornerRadius="12" Padding="16" BorderThickness="1" BorderBrush="#334155">
			<Border.Background>
				<LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
					<GradientStop Color="#1E3A8A" Offset="0"/>
					<GradientStop Color="#0EA5E9" Offset="0.55"/>
					<GradientStop Color="#F59E0B" Offset="1"/>
				</LinearGradientBrush>
			</Border.Background>
			<Grid>
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="*"/>
				</Grid.RowDefinitions>
				<StackPanel Grid.Row="0">
					<TextBlock Text="JPEG" FontSize="54" FontWeight="Bold" Foreground="White"/>
					<TextBlock Text="WPF JPEG Viewer (PowerShell 5.1)" FontSize="18" FontWeight="SemiBold" Foreground="#E2E8F0" Margin="0,2,0,12"/>
					<TextBlock Foreground="White" Margin="0,0,0,6">
						<Hyperlink Name="lnkJpegSpec">JPEG Specification (ISO/IEC 10918)</Hyperlink>
					</TextBlock>
					<TextBlock Foreground="White" Margin="0,0,0,6">
						<Hyperlink Name="lnkExifSpec">EXIF / JPEG Metadata (CIPA EXIF)</Hyperlink>
					</TextBlock>
					<TextBlock Foreground="White" Margin="0,0,0,10">
						<Hyperlink Name="lnkWindowsJpeg">Windows JPEG Implementations (WIC / GDI+)</Hyperlink>
					</TextBlock>
					<TextBlock Text="Tip: URLs detected in JPEG comments become clickable properties in the grid." Foreground="#F8FAFC" TextWrapping="Wrap"/>
				</StackPanel>
				<Border Grid.Row="1" Margin="0,14,0,0" CornerRadius="10" BorderBrush="#93C5FD" BorderThickness="1" Padding="10" Background="#0B294A">
					<Grid>
						<Grid.RowDefinitions>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="*"/>
							<RowDefinition Height="Auto"/>
						</Grid.RowDefinitions>
						<TextBlock Grid.Row="0" Text="JPEG compression / expansion" Foreground="#DBEAFE" FontWeight="SemiBold" Margin="0,0,0,8"/>
						<Grid Grid.Row="1" HorizontalAlignment="Left" VerticalAlignment="Center">
							<Grid.ColumnDefinitions>
								<ColumnDefinition Width="*"/>
								<ColumnDefinition Width="Auto"/>
							</Grid.ColumnDefinitions>
							<Border Name="jpegColorPanel" Grid.Column="0" Width="250" Height="98" CornerRadius="8" BorderBrush="#1D4ED8" BorderThickness="2" HorizontalAlignment="Left" ToolTip="Color image payload shrinks when compressed">
								<Border.RenderTransform>
									<ScaleTransform ScaleX="1" ScaleY="1"/>
								</Border.RenderTransform>
								<Border.Background>
									<LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
										<GradientStop Color="#EF4444" Offset="0"/>
										<GradientStop Color="#F59E0B" Offset="0.22"/>
										<GradientStop Color="#EAB308" Offset="0.44"/>
										<GradientStop Color="#22C55E" Offset="0.64"/>
										<GradientStop Color="#38BDF8" Offset="0.82"/>
										<GradientStop Color="#6366F1" Offset="1"/>
									</LinearGradientBrush>
								</Border.Background>
							</Border>
							<TextBlock Grid.Column="1" Text="JPEG" Foreground="#BAE6FD" FontWeight="Bold" VerticalAlignment="Center" Margin="10,0,0,0"/>
							<Border Name="jpegCompressedStub" Grid.Column="0" Width="52" Height="98" CornerRadius="8" BorderBrush="#67E8F9" BorderThickness="2" HorizontalAlignment="Left" Opacity="0.25" ToolTip="Compressed stream representation">
								<Border.RenderTransform>
									<ScaleTransform ScaleX="0.78" ScaleY="1"/>
								</Border.RenderTransform>
								<Border.Background>
									<SolidColorBrush Color="#0EA5E9"/>
								</Border.Background>
							</Border>
						</Grid>
						<StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,8,0,0">
							<TextBlock Name="txtExpandedCue" Text="Expanded" Foreground="#BAE6FD" FontWeight="Bold" Opacity="1.0"/>
							<TextBlock Text="  ->  " Foreground="#93C5FD" FontWeight="SemiBold"/>
							<TextBlock Name="txtCompressedCue" Text="Compressed" Foreground="#BAE6FD" FontWeight="Bold" Opacity="0.25"/>
						</StackPanel>
					</Grid>
				</Border>
			</Grid>
		</Border>

		<StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
			<Button Name="btnAppendTempUrl" Content="Append Test URL" Width="130" Margin="0,0,8,0" ToolTip="Append temporary test JPEG URL to comment and refresh properties" Style="{StaticResource DialogPurpleButtonStyle}"/>
			<Button Name="btnOpenDebug" Content="Show Debug" Width="120" Margin="0,0,8,0" ToolTip="Show or hide Debug window" Style="{StaticResource DialogPurpleButtonStyle}"/>
			<Button Name="btnCloseAbout" Content="Close" Width="82" ToolTip="Close about window" Style="{StaticResource DialogPurpleButtonStyle}"/>
		</StackPanel>
	</Grid>
</Window>
"@

	$aboutReader = New-Object System.Xml.XmlNodeReader $aboutXaml
	$aboutWindow = [Windows.Markup.XamlReader]::Load($aboutReader)
	if ($Owner -and $Owner.IsVisible) {
		$aboutWindow.Owner = $Owner
	}

	$lnkJpegSpec = $aboutWindow.FindName('lnkJpegSpec')
	$lnkExifSpec = $aboutWindow.FindName('lnkExifSpec')
	$lnkWindowsJpeg = $aboutWindow.FindName('lnkWindowsJpeg')
	$btnAppendTempUrl = $aboutWindow.FindName('btnAppendTempUrl')
	$btnOpenDebug = $aboutWindow.FindName('btnOpenDebug')
	$btnCloseAbout = $aboutWindow.FindName('btnCloseAbout')

	$lnkJpegSpec.Add_Click({ Start-Process -FilePath 'https://jpeg.org/jpeg/' })
	$lnkExifSpec.Add_Click({ Start-Process -FilePath 'https://www.cipa.jp/std/documents/e/DC-008-Translation-2019-E.pdf' })
	$lnkWindowsJpeg.Add_Click({ Start-Process -FilePath 'https://learn.microsoft.com/windows/win32/wic/-wic-about-windows-imaging-codec' })

	if (-not $AllowAppendUrl) {
		$btnAppendTempUrl.Visibility = 'Collapsed'
	}

	$btnOpenDebug.Content = if ($debugWindow -and $debugWindow.IsVisible) { 'Hide Debug' } else { 'Show Debug' }

	$btnAppendTempUrl.Add_Click({
		$testUrl = 'https://example.com/jpeg-comment-test'
		if ([string]::IsNullOrWhiteSpace($txtComment.Text)) {
			$txtComment.Text = $testUrl
		} elseif ($txtComment.Text -notmatch [regex]::Escape($testUrl)) {
			$txtComment.Text = ($txtComment.Text.TrimEnd() + [Environment]::NewLine + $testUrl)
		}

		Update-CommentUrlRowsInGrid -CommentText $txtComment.Text
		Update-CommentIndicator -CommentText $txtComment.Text
		if ($lbFiles.SelectedItem) {
			$lbFiles.SelectedItem.HasComment = $true
			$lbFiles.Items.Refresh()
		}
		$txtStatus.Text = 'Temporary test URL appended to comment and properties updated.'
	})

	$btnOpenDebug.Add_Click({
		if (-not $debugWindow) { return }
		if ($debugWindow.IsVisible) {
			$debugWindow.Hide()
			$btnOpenDebug.Content = 'Show Debug'
			$btnOpenDebug.ToolTip = 'Show Debug window'
			return
		}

		if ($viewerSettings.DebugWindow) {
			if ($viewerSettings.DebugWindow.Width -gt 100) { $debugWindow.Width = [double]$viewerSettings.DebugWindow.Width }
			if ($viewerSettings.DebugWindow.Height -gt 80) { $debugWindow.Height = [double]$viewerSettings.DebugWindow.Height }
			$debugWindow.Left = [double]$viewerSettings.DebugWindow.Left
			$debugWindow.Top = [double]$viewerSettings.DebugWindow.Top
		}
		Clamp-WindowToVisibleScreen -Window $debugWindow -DefaultLeft ($aboutWindow.Left + $aboutWindow.Width + 8) -DefaultTop $aboutWindow.Top
		[void]$debugWindow.Show()
		Update-DebugMetrics
		$btnOpenDebug.Content = 'Hide Debug'
		$btnOpenDebug.ToolTip = 'Hide Debug window'
	})

	$btnCloseAbout.Add_Click({ $aboutWindow.Close() })

	if ($AutoCloseSeconds -gt 0) {
		$timer = New-Object System.Windows.Threading.DispatcherTimer
		$timer.Interval = [TimeSpan]::FromSeconds($AutoCloseSeconds)
		$timer.Add_Tick({
			$timer.Stop()
			$aboutWindow.Close()
		}.GetNewClosure())
		$timer.Start()

		$aboutWindow.Add_PreviewMouseDown({
			if ($timer) { $timer.Stop() }
			$aboutWindow.Close()
		}.GetNewClosure())

		# For splash mode, avoid modal blocking on startup.
		[void]$aboutWindow.Show()
		return
	}

	[void]$aboutWindow.ShowDialog()
}

function New-DebugWindow {
	[xml]$debugXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="JPEG Viewer Debug"
		Width="420"
		Height="220"
		Topmost="True"
		ResizeMode="CanResizeWithGrip"
		WindowStartupLocation="Manual"
		Background="#0F172A"
		Foreground="#E2E8F0">
	<Grid Margin="10">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
		</Grid.RowDefinitions>
		<TextBlock Text="Image / View Metrics" FontSize="16" FontWeight="Bold" Margin="0,0,0,8" Foreground="#F8FAFC"/>
		<TextBox Name="txtDebugMetrics" Grid.Row="1" FontFamily="Consolas" FontSize="15" FontWeight="SemiBold" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" VerticalContentAlignment="Top" Padding="8" Background="#F8FAFC" Foreground="#0B1220" BorderBrush="#93C5FD" BorderThickness="2"/>
	</Grid>
</Window>
"@

	$debugReader = New-Object System.Xml.XmlNodeReader $debugXaml
	return [Windows.Markup.XamlReader]::Load($debugReader)
}

function Update-DebugMetrics {
	if (-not $txtDebugMetrics) { return }

	$imgPxW = if ($script:CurrentBitmap) { [int]$script:CurrentBitmap.PixelWidth } else { 0 }
	$imgPxH = if ($script:CurrentBitmap) { [int]$script:CurrentBitmap.PixelHeight } else { 0 }
	$zoomPct = [int]([Math]::Round($script:CurrentZoom * 100))

	$viewportW = [Math]::Round([double]$svImage.ViewportWidth, 1)
	$viewportH = [Math]::Round([double]$svImage.ViewportHeight, 1)
	$extentW = [Math]::Round([double]$svImage.ExtentWidth, 1)
	$extentH = [Math]::Round([double]$svImage.ExtentHeight, 1)
	$offsetX = [Math]::Round([double]$svImage.HorizontalOffset, 1)
	$offsetY = [Math]::Round([double]$svImage.VerticalOffset, 1)

	$txtDebugMetrics.Text = @(
		"Image px:       ${imgPxW} x ${imgPxH}",
		"",
		"Zoom:           ${zoomPct}% (${0:N4})" -f $script:CurrentZoom,
		"Client (DIP):   {0:N1} x {1:N1}" -f [double]$mainContentGrid.ActualWidth, [double]$mainContentGrid.ActualHeight,
		"Coord Space:    (0,0) to ({0:N1},{1:N1})" -f [double]$mainContentGrid.ActualWidth, [double]$mainContentGrid.ActualHeight,
		"Viewport (DIP): ${viewportW} x ${viewportH}",
		"Extent (DIP):   ${extentW} x ${extentH}",
		"Offset (DIP):   X=${offsetX}  Y=${offsetY}",
		"Mode:           $($script:ZoomMode)"
	) -join [Environment]::NewLine
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="WPF JPEG Viewer (PowerShell 5.1)"
		Width="1400"
		Height="900"
		MinWidth="1000"
		MinHeight="650"
		Background="#F3F5F8"
		WindowStartupLocation="CenterScreen"
		AllowDrop="True">
	<Window.Resources>
		<Style x:Key="BaseActionButtonStyle" TargetType="Button">
			<Setter Property="FontWeight" Value="Bold"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="BorderThickness" Value="4"/>
			<Setter Property="Padding" Value="8,3"/>
			<Setter Property="Cursor" Value="Hand"/>
		</Style>
		<Style x:Key="GreenPastelButtonStyle" TargetType="Button" BasedOn="{StaticResource BaseActionButtonStyle}">
			<Setter Property="Background" Value="#CDEFD6"/>
			<Setter Property="BorderBrush" Value="#2E7D4E"/>
			<Setter Property="Foreground" Value="#123524"/>
		</Style>
		<Style x:Key="RedPastelButtonStyle" TargetType="Button" BasedOn="{StaticResource BaseActionButtonStyle}">
			<Setter Property="Background" Value="#F9D0D0"/>
			<Setter Property="BorderBrush" Value="#8F2A2A"/>
			<Setter Property="Foreground" Value="#3B0D0D"/>
		</Style>
		<Style x:Key="BluePastelButtonStyle" TargetType="Button" BasedOn="{StaticResource BaseActionButtonStyle}">
			<Setter Property="Background" Value="#CFE4FF"/>
			<Setter Property="BorderBrush" Value="#245A9E"/>
			<Setter Property="Foreground" Value="#102A4A"/>
		</Style>
		<Style x:Key="OrangePastelButtonStyle" TargetType="Button" BasedOn="{StaticResource BaseActionButtonStyle}">
			<Setter Property="Background" Value="#FFE2C2"/>
			<Setter Property="BorderBrush" Value="#A05814"/>
			<Setter Property="Foreground" Value="#4A250A"/>
		</Style>
		<Style x:Key="PurplePastelButtonStyle" TargetType="Button" BasedOn="{StaticResource BaseActionButtonStyle}">
			<Setter Property="Background" Value="#E9D5FF"/>
			<Setter Property="BorderBrush" Value="#6D28D9"/>
			<Setter Property="Foreground" Value="#3B0764"/>
		</Style>
		<Style x:Key="CopyComboStyle" TargetType="ComboBox">
			<Setter Property="Background" Value="#CDEFD6"/>
			<Setter Property="BorderBrush" Value="#2E7D4E"/>
			<Setter Property="Foreground" Value="#123524"/>
			<Setter Property="BorderThickness" Value="4"/>
			<Setter Property="FontWeight" Value="Bold"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="Padding" Value="6,2"/>
		</Style>
		<Style x:Key="PulsingCloseButtonStyle" TargetType="Button" BasedOn="{StaticResource RedPastelButtonStyle}">
			<Setter Property="Visibility" Value="Collapsed"/>
			<Setter Property="ToolTip" Value="Exit maximize mode"/>
			<Style.Triggers>
				<Trigger Property="Visibility" Value="Visible">
					<Trigger.EnterActions>
						<BeginStoryboard x:Name="ClosePulseStoryboard">
							<Storyboard RepeatBehavior="Forever" AutoReverse="True">
								<DoubleAnimation Storyboard.TargetProperty="Opacity" From="0.72" To="1.0" Duration="0:0:0.55"/>
							</Storyboard>
						</BeginStoryboard>
					</Trigger.EnterActions>
					<Trigger.ExitActions>
						<StopStoryboard BeginStoryboardName="ClosePulseStoryboard"/>
					</Trigger.ExitActions>
				</Trigger>
			</Style.Triggers>
		</Style>
		<Style x:Key="PulsingChevronButtonStyle" TargetType="Button">
			<Setter Property="Background" Value="#CFE4FF"/>
			<Setter Property="Foreground" Value="#102A4A"/>
			<Setter Property="BorderBrush" Value="#245A9E"/>
			<Setter Property="BorderThickness" Value="4"/>
			<Setter Property="Cursor" Value="Hand"/>
			<Setter Property="Opacity" Value="0.82"/>
			<Setter Property="FontWeight" Value="Bold"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="ToolTip" Value="Go to previous/next image"/>
			<Style.Triggers>
				<Trigger Property="Visibility" Value="Visible">
					<Trigger.EnterActions>
						<BeginStoryboard x:Name="PulseStoryboard">
							<Storyboard RepeatBehavior="Forever" AutoReverse="True">
								<DoubleAnimation Storyboard.TargetProperty="Opacity" From="0.55" To="0.95" Duration="0:0:0.7"/>
							</Storyboard>
						</BeginStoryboard>
					</Trigger.EnterActions>
					<Trigger.ExitActions>
						<StopStoryboard BeginStoryboardName="PulseStoryboard"/>
					</Trigger.ExitActions>
				</Trigger>
			</Style.Triggers>
		</Style>
	</Window.Resources>
	<Grid Margin="8">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto" />
			<RowDefinition Height="*" />
			<RowDefinition Height="Auto" />
		</Grid.RowDefinitions>

		<Border Name="topToolbarBorder" Grid.Row="0" Background="#FFFFFF" BorderBrush="#D7DDE6" BorderThickness="1" CornerRadius="6" Padding="8" Margin="0,0,0,8">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="320"/>
					<ColumnDefinition Width="5"/>
					<ColumnDefinition Width="*"/>
				</Grid.ColumnDefinitions>

				<Border Grid.Column="0" Background="#F8FAFC" BorderBrush="#E2E8F0" BorderThickness="1" CornerRadius="4" Padding="6" Margin="0,0,0,0">
					<StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
						<Button Name="btnAddFiles" Content="Add Files" Width="96" Margin="0,0,6,0" ToolTip="Add one or more JPEG files" Style="{StaticResource GreenPastelButtonStyle}"/>
						<Button Name="btnAddFolder" Content="Add Folder" Width="102" Margin="0,0,6,0" ToolTip="Add all JPEG files from a folder" Style="{StaticResource GreenPastelButtonStyle}"/>
						<Button Name="btnClearFiles" Content="Clear" Width="76" ToolTip="Clear loaded files and reset viewer state" Style="{StaticResource RedPastelButtonStyle}"/>
					</StackPanel>
				</Border>

				<Border Grid.Column="2" Background="#F8FAFC" BorderBrush="#E2E8F0" BorderThickness="1" CornerRadius="4" Padding="6" Margin="0,0,0,0">
					<DockPanel LastChildFill="False">
						<StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
							<Button Name="btnPrev" Content="Prev" Width="82" Margin="0,0,6,0" ToolTip="Select previous file" Style="{StaticResource BluePastelButtonStyle}"/>
							<Button Name="btnNext" Content="Next" Width="82" Margin="0,0,12,0" ToolTip="Select next file" Style="{StaticResource BluePastelButtonStyle}"/>
							<Button Name="btnToggleFullscreen" Content="Maximize" Width="102" Margin="0,0,12,0" ToolTip="Maximize image area with bottom comment panel" Style="{StaticResource PurplePastelButtonStyle}"/>
							<Button Name="btnFit" Content="Fit" Width="66" Margin="0,0,6,0" ToolTip="Fit image to visible viewer area" Style="{StaticResource BluePastelButtonStyle}"/>
							<Button Name="btnFitWidth" Content="Fit Width" Width="90" Margin="0,0,6,0" ToolTip="Fit image width to viewer area" Style="{StaticResource BluePastelButtonStyle}"/>
							<Button Name="btnFitHeight" Content="Fit Height" Width="90" Margin="0,0,6,0" ToolTip="Fit image height to viewer area" Style="{StaticResource BluePastelButtonStyle}"/>
							<Button Name="btnResetView" Content="R" Width="32" Margin="0,0,10,0" ToolTip="Reset view: fit image and scroll to top-left" Style="{StaticResource BluePastelButtonStyle}"/>
							<Button Name="btnZoomOut" Content="-" Width="40" Margin="0,0,6,0" ToolTip="Zoom out" Style="{StaticResource OrangePastelButtonStyle}"/>
							<Button Name="btnZoomIn" Content="+" Width="40" ToolTip="Zoom in" Style="{StaticResource OrangePastelButtonStyle}"/>
						</StackPanel>
						<TextBlock Name="txtZoom" DockPanel.Dock="Right" VerticalAlignment="Center" FontWeight="SemiBold" Foreground="#2D3748" Text="Zoom: 100%" ToolTip="Current zoom percentage"/>
					</DockPanel>
				</Border>
			</Grid>
		</Border>

		<Grid Name="mainContentGrid" Grid.Row="1">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="320" />
				<ColumnDefinition Width="5" />
				<ColumnDefinition Width="*" />
			</Grid.ColumnDefinitions>

			<Border Name="fileListBorder" Grid.Column="0" Background="White" BorderBrush="#D7DDE6" BorderThickness="1" CornerRadius="6" Padding="4">
				<DockPanel LastChildFill="True">
					<TextBlock DockPanel.Dock="Top" Text="Loaded JPEG Files" FontWeight="SemiBold" Margin="6,4,6,6"/>
					<ListView Name="lbFiles" AllowDrop="True" BorderThickness="0" SelectionMode="Extended" ToolTip="Loaded images. Drag files or folders from Explorer. Ctrl+click to multi-select.">
						<ListView.ContextMenu>
							<ContextMenu>
								<MenuItem Name="miRemoveFromList" Header="Remove File From List" ToolTip="Remove selected file(s) from this list only"/>
							</ContextMenu>
						</ListView.ContextMenu>
						<ListView.View>
							<GridView>
								<GridViewColumn Width="28">
									<GridViewColumn.CellTemplate>
										<DataTemplate>
											<Grid Width="18" Height="18" HorizontalAlignment="Center" VerticalAlignment="Center">
												<Border Width="13" Height="16" Background="#FACC15" BorderBrush="#A16207" BorderThickness="1" CornerRadius="1">
													<Border.Style>
														<Style TargetType="Border">
															<Setter Property="Visibility" Value="Collapsed"/>
															<Setter Property="ToolTip" Value=""/>
															<Style.Triggers>
																<DataTrigger Binding="{Binding HasComment}" Value="True">
																	<Setter Property="Visibility" Value="Visible"/>
																	<Setter Property="ToolTip" Value="{Binding CommentToolTip}"/>
																</DataTrigger>
															</Style.Triggers>
														</Style>
													</Border.Style>
												</Border>
												<Polygon Points="8,1 12,1 12,5" Fill="#FEF9C3" Stroke="#A16207" StrokeThickness="0.8" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="5,0,0,0"/>
											</Grid>
										</DataTemplate>
									</GridViewColumn.CellTemplate>
								</GridViewColumn>
								<GridViewColumn Header="Name" Width="155" DisplayMemberBinding="{Binding Name}"/>
								<GridViewColumn Header="Modified" Width="122" DisplayMemberBinding="{Binding LastModified}"/>
								<GridViewColumn Header="Size" Width="80">
									<GridViewColumn.CellTemplate>
										<DataTemplate>
											<TextBlock Text="{Binding SizeDisplay}" TextAlignment="Right" HorizontalAlignment="Right" Width="76"/>
										</DataTemplate>
									</GridViewColumn.CellTemplate>
								</GridViewColumn>
								<GridViewColumn Header="Ratio" Width="72">
									<GridViewColumn.CellTemplate>
										<DataTemplate>
											<TextBlock Text="{Binding CompressionRatio}" TextAlignment="Right" HorizontalAlignment="Right" Width="68"/>
										</DataTemplate>
									</GridViewColumn.CellTemplate>
								</GridViewColumn>
							</GridView>
						</ListView.View>
					</ListView>
				</DockPanel>
			</Border>

				<GridSplitter Name="fileListSplitter" Grid.Column="1" Width="5" HorizontalAlignment="Stretch" Background="#CBD5E0" ShowsPreview="True" ToolTip="Resize file list and viewer panels"/>

				<Grid Name="viewerPanelGrid" Grid.Column="2">
				<Grid.RowDefinitions>
					<RowDefinition Height="*" MinHeight="180"/>
					<RowDefinition Height="5" />
					<RowDefinition Height="290" MinHeight="190"/>
				</Grid.RowDefinitions>

				<Border Grid.Row="0" Background="Black" CornerRadius="6" BorderBrush="#D7DDE6" BorderThickness="1" ClipToBounds="True" ToolTip="Mouse wheel zoom. Left-drag to pan image.">
					<Grid Name="imageHost">
						<ScrollViewer Name="svImage" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Focusable="False" CanContentScroll="False" PanningMode="Both" Cursor="Hand" ToolTip="Mouse wheel zoom. Left-drag to pan image.">
							<Grid>
								<Image Name="imgViewer" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality" HorizontalAlignment="Left" VerticalAlignment="Top"/>
							</Grid>
						</ScrollViewer>

						<Button Name="btnOverlayPrev" Content="&lt;" Width="48" Height="80" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="12,0,0,0" Visibility="Collapsed" FontSize="26" FontWeight="Bold" Style="{StaticResource PulsingChevronButtonStyle}" ToolTip="Previous image"/>
						<Button Name="btnOverlayNext" Content="&gt;" Width="48" Height="80" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0" Visibility="Collapsed" FontSize="26" FontWeight="Bold" Style="{StaticResource PulsingChevronButtonStyle}" ToolTip="Next image"/>
					</Grid>
				</Border>

				<GridSplitter Name="viewerMetaSplitter" Grid.Row="1" Height="5" HorizontalAlignment="Stretch" Background="#CBD5E0" ShowsPreview="True" ToolTip="Resize viewer and metadata panels"/>

					<Grid Name="metadataGrid" Grid.Row="2">
					<Grid.RowDefinitions>
							<RowDefinition Height="2*" MinHeight="112"/>
							<RowDefinition Height="*" MinHeight="72"/>
					</Grid.RowDefinitions>

					<Border Name="propsBorder" Grid.Row="0" Background="White" BorderBrush="#D7DDE6" BorderThickness="1" CornerRadius="6" Padding="6" Margin="0,0,0,6">
						<DockPanel>
							<DockPanel DockPanel.Dock="Top" LastChildFill="False" Margin="0,0,0,6">
								<TextBlock DockPanel.Dock="Left" Text="JPEG Properties" FontWeight="SemiBold" Margin="2,0,0,0" VerticalAlignment="Center"/>
								<StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
									<ComboBox Name="cmbCopyFormat" Width="180" Margin="0,0,6,0" SelectedIndex="0" ToolTip="Choose export format for property copy" Style="{StaticResource CopyComboStyle}">
										<ComboBoxItem Content="Text"/>
										<ComboBoxItem Content="PSObject format"/>
										<ComboBoxItem Content="CSV"/>
										<ComboBoxItem Content="TSV Tab separated"/>
									</ComboBox>
									<Button Name="btnCopyProps" Content="Copy Properties" Width="136" ToolTip="Copy properties grid to clipboard in selected format" Style="{StaticResource GreenPastelButtonStyle}"/>
								</StackPanel>
							</DockPanel>
							<DataGrid Name="dgProps" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Single" GridLinesVisibility="Horizontal" HeadersVisibility="Column" CanUserAddRows="False" CanUserDeleteRows="False" CanUserResizeRows="False" ToolTip="JPEG metadata and extracted URLs from comments">
								<DataGrid.RowStyle>
									<Style TargetType="DataGridRow">
										<Style.Triggers>
											<DataTrigger Binding="{Binding IsUrl}" Value="True">
												<Setter Property="Background" Value="#DBEAFE"/>
											</DataTrigger>
										</Style.Triggers>
									</Style>
								</DataGrid.RowStyle>
								<DataGrid.Columns>
									<DataGridTextColumn Header="Property" Binding="{Binding Property}" Width="220"/>
									<DataGridTemplateColumn Header="Value" Width="*">
										<DataGridTemplateColumn.CellTemplate>
											<DataTemplate>
												<TextBlock Text="{Binding Value}" TextWrapping="Wrap">
													<TextBlock.Style>
														<Style TargetType="TextBlock">
															<Setter Property="Foreground" Value="#1F2937"/>
															<Setter Property="Cursor" Value="Arrow"/>
															<Style.Triggers>
																<DataTrigger Binding="{Binding IsUrl}" Value="True">
																	<Setter Property="Foreground" Value="#0A58CA"/>
																	<Setter Property="TextDecorations" Value="Underline"/>
																	<Setter Property="Cursor" Value="Hand"/>
																</DataTrigger>
															</Style.Triggers>
														</Style>
													</TextBlock.Style>
												</TextBlock>
											</DataTemplate>
										</DataGridTemplateColumn.CellTemplate>
									</DataGridTemplateColumn>
								</DataGrid.Columns>
							</DataGrid>
						</DockPanel>
					</Border>

					<Border Name="commentBorder" Grid.Row="1" Background="White" BorderBrush="#D7DDE6" BorderThickness="1" CornerRadius="6" Padding="6">
						<DockPanel>
							<DockPanel DockPanel.Dock="Top" LastChildFill="False" Margin="0,0,0,6">
								<StackPanel DockPanel.Dock="Left" Orientation="Horizontal">
									<Grid Name="icoComment" Width="14" Height="16" Margin="2,0,6,0" VerticalAlignment="Center" Visibility="Collapsed" ToolTip="JPEG comment exists">
										<Border Width="13" Height="16" Background="#FACC15" BorderBrush="#A16207" BorderThickness="1" CornerRadius="1"/>
										<Polygon Points="8,1 12,1 12,5" Fill="#FEF9C3" Stroke="#A16207" StrokeThickness="0.8" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="5,0,0,0"/>
									</Grid>
									<TextBlock Text="JPEG Comment" FontWeight="Bold" FontSize="14" Margin="0,0,0,0" VerticalAlignment="Center"/>
								</StackPanel>
								<StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
									<Button Name="btnCloseFullscreen" Content="Close" Width="86" Margin="0,0,6,0" ToolTip="Exit maximize mode and restore the normal viewer" Style="{StaticResource PulsingCloseButtonStyle}"/>
									<Button Name="btnEditComment" Content="Edit" Width="72" Margin="0,0,6,0" ToolTip="Edit JPEG comment inline" Style="{StaticResource RedPastelButtonStyle}"/>
									<Button Name="btnSaveComment" Content="Save" Width="78" Margin="0,0,6,0" Visibility="Collapsed" ToolTip="Save inline JPEG comment changes" Style="{StaticResource GreenPastelButtonStyle}"/>
									<Button Name="btnRevertComment" Content="Revert" Width="86" Margin="0,0,6,0" Visibility="Collapsed" ToolTip="Discard inline edits and restore original comment" Style="{StaticResource RedPastelButtonStyle}"/>
									<Button Name="btnCopyImage" Content="Copy Image" Width="98" Margin="0,0,6,0" ToolTip="Copy currently displayed image to clipboard" Style="{StaticResource GreenPastelButtonStyle}"/>
									<Button Name="btnCopyComment" Content="Copy Comment" Width="122" ToolTip="Copy JPEG comment text to clipboard" Style="{StaticResource GreenPastelButtonStyle}"/>
								</StackPanel>
							</DockPanel>
							<TextBox Name="txtComment" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" Background="#FCFCFD" BorderBrush="#D7DDE6" BorderThickness="1" FontSize="14" FontWeight="Bold" ToolTip="Raw JPEG comment text. Scroll to read long comments."/>
						</DockPanel>
					</Border>
				</Grid>
			</Grid>
		</Grid>

		<StatusBar Name="statusBarMain" Grid.Row="2" Background="#FFFFFF" BorderBrush="#D7DDE6" BorderThickness="1" Margin="0,8,0,0">
			<StatusBarItem>
				<Button Name="btnAbout" Content="About" Width="70" ToolTip="Show viewer about page and JPEG reference links" Style="{StaticResource PurplePastelButtonStyle}"/>
			</StatusBarItem>
			<Separator/>
			<StatusBarItem>
				<TextBlock Name="txtCurrentFile" ToolTip="Full path of selected file">
					<Run x:Name="runCurrentLabel" Text="Current: " FontWeight="Bold"/>
					<Run x:Name="runCurrentValue" Text="(none)" Foreground="#1E3A8A"/>
				</TextBlock>
			</StatusBarItem>
			<Separator/>
			<StatusBarItem>
				<TextBlock Name="txtCounts" ToolTip="Files loaded, total size, and disk free space">
					<Run x:Name="runFilesLabel" Text="Files: " FontWeight="Bold"/>
					<Run x:Name="runFilesValue" Text="0" Foreground="#1E3A8A"/>
					<Run Text=" | "/>
					<Run x:Name="runTotalLabel" Text="Total Size: " FontWeight="Bold"/>
					<Run x:Name="runTotalValue" Text="0 KB" Foreground="#1E3A8A"/>
					<Run Text=" | "/>
					<Run x:Name="runDiskLabel" Text="Disk Free: " FontWeight="Bold"/>
					<Run x:Name="runDiskValue" Text="n/a" Foreground="#1E3A8A"/>
				</TextBlock>
			</StatusBarItem>
			<Separator/>
			<StatusBarItem>
				<TextBlock Name="txtStatus" Text="Ready" ToolTip="Latest action/result" Foreground="#1E3A8A"/>
			</StatusBarItem>
		</StatusBar>
	</Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$btnAddFiles = $window.FindName('btnAddFiles')
$btnAddFolder = $window.FindName('btnAddFolder')
$btnClearFiles = $window.FindName('btnClearFiles')
$btnPrev = $window.FindName('btnPrev')
$btnNext = $window.FindName('btnNext')
$btnToggleFullscreen = $window.FindName('btnToggleFullscreen')
$btnFit = $window.FindName('btnFit')
$btnFitWidth = $window.FindName('btnFitWidth')
$btnFitHeight = $window.FindName('btnFitHeight')
$btnResetView = $window.FindName('btnResetView')
$btnZoomOut = $window.FindName('btnZoomOut')
$btnZoomIn = $window.FindName('btnZoomIn')
$txtZoom = $window.FindName('txtZoom')
$lbFiles = $window.FindName('lbFiles')
$imageHost = $window.FindName('imageHost')
$svImage = $window.FindName('svImage')
$imgViewer = $window.FindName('imgViewer')
$btnOverlayPrev = $window.FindName('btnOverlayPrev')
$btnOverlayNext = $window.FindName('btnOverlayNext')
$dgProps = $window.FindName('dgProps')
$icoComment = $window.FindName('icoComment')
$cmbCopyFormat = $window.FindName('cmbCopyFormat')
$btnCopyProps = $window.FindName('btnCopyProps')
$btnEditComment = $window.FindName('btnEditComment')
$btnSaveComment = $window.FindName('btnSaveComment')
$btnRevertComment = $window.FindName('btnRevertComment')
$btnCopyComment = $window.FindName('btnCopyComment')
$btnCopyImage = $window.FindName('btnCopyImage')
$btnCloseFullscreen = $window.FindName('btnCloseFullscreen')
$txtComment = $window.FindName('txtComment')
$runCurrentValue = $window.FindName('runCurrentValue')
$runFilesValue = $window.FindName('runFilesValue')
$runTotalValue = $window.FindName('runTotalValue')
$runDiskValue = $window.FindName('runDiskValue')
$txtStatus = $window.FindName('txtStatus')
$txtCurrentFile = $window.FindName('txtCurrentFile')
$btnAbout = $window.FindName('btnAbout')
$miRemoveFromList = $window.FindName('miRemoveFromList')

$topToolbarBorder = $window.FindName('topToolbarBorder')
$mainContentGrid = $window.FindName('mainContentGrid')
$fileListBorder = $window.FindName('fileListBorder')
$fileListSplitter = $window.FindName('fileListSplitter')
$viewerPanelGrid = $window.FindName('viewerPanelGrid')
$viewerMetaSplitter = $window.FindName('viewerMetaSplitter')
$metadataGrid = $window.FindName('metadataGrid')
$propsBorder = $window.FindName('propsBorder')
$commentBorder = $window.FindName('commentBorder')
$statusBarMain = $window.FindName('statusBarMain')

$viewerSettings = Read-ViewerSettings

$files = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$lbFiles.ItemsSource = $files

$scaleTransform = New-Object System.Windows.Media.ScaleTransform
$imgViewer.RenderTransform = $scaleTransform
$imgViewer.RenderTransformOrigin = New-Object System.Windows.Point(0, 0)

$debugWindow = New-DebugWindow
$txtDebugMetrics = $debugWindow.FindName('txtDebugMetrics')
$script:DebugToggleButtonRef = $null

$debugWindow.Add_Closing({
	param($sender, $e)
	# Keep the debug window reusable; WPF cannot Show() a window once it has actually closed.
	$e.Cancel = $true
	$sender.Hide()
	if ($script:DebugToggleButtonRef) {
		$script:DebugToggleButtonRef.Content = 'Show Debug'
		$script:DebugToggleButtonRef.ToolTip = 'Show Debug window'
	}
})

$script:CurrentBitmap = $null
$script:ZoomMode = 'Fit'
$script:CurrentZoom = 1.0
$script:IsFitPending = $true
$script:HasLoadedFirstImage = $false
$script:IsPanning = $false
$script:PanStartPoint = $null
$script:PanStartH = 0.0
$script:PanStartV = 0.0
$script:IsFullscreenMode = $false
$script:SavedWindowStyle = $null
$script:SavedResizeMode = $null
$script:SavedWindowState = $null
$script:SavedTopmost = $false
$script:SavedTopRowHeight = [System.Windows.GridLength]::Auto
$script:SavedStatusRowHeight = [System.Windows.GridLength]::Auto
$script:SavedLeftColumnWidth = New-Object System.Windows.GridLength(320)
$script:SavedSplitterColumnWidth = New-Object System.Windows.GridLength(5)
$script:SavedMetaRowHeight = New-Object System.Windows.GridLength(290)
$script:SavedMetaSplitterHeight = New-Object System.Windows.GridLength(5)
$script:SavedPropsRowHeight = New-Object System.Windows.GridLength(2, [System.Windows.GridUnitType]::Star)
$script:SavedCommentRowHeight = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$script:IsCommentEditMode = $false
$script:OriginalCommentText = ''
$script:IsPropsExpandedBySplitterToggle = $false
$script:BeforeExpandMetaRow0 = New-Object System.Windows.GridLength(2, [System.Windows.GridUnitType]::Star)
$script:BeforeExpandMetaRow1 = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$script:PendingListDetails = New-Object 'System.Collections.Generic.Queue[object]'
$script:ListHydrateTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ListHydrateTimer.Interval = [TimeSpan]::FromMilliseconds(40)

$script:ListHydrateTimer.Add_Tick({
	$processed = 0
	$maxPerTick = 3
	$hasChanges = $false

	while ($script:PendingListDetails.Count -gt 0 -and $processed -lt $maxPerTick) {
		$item = $script:PendingListDetails.Dequeue()
		$processed++
		if (-not $item) { continue }
		if (-not $files.Contains($item)) { continue }
		if ($item.HasDetailsHydrated) { continue }
		if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }

		try {
			$listDetails = Get-JpegListDetails -Path $item.FullPath
			$item.CompressionRatio = [string]$listDetails.CompressionRatio
			$item.HasComment = [bool]$listDetails.HasComment
			$item.CommentToolTip = if ([string]::IsNullOrWhiteSpace([string]$listDetails.CommentText)) { 'No JPEG comment found.' } else { [string]$listDetails.CommentText }
			$item.HasDetailsHydrated = $true
			$hasChanges = $true
		} catch {
			$item.CompressionRatio = 'n/a'
			$item.HasComment = $false
			$item.CommentToolTip = 'No JPEG comment found.'
			$item.HasDetailsHydrated = $true
			$hasChanges = $true
		}
	}

	if ($hasChanges) {
		$lbFiles.Items.Refresh()
		if ($lbFiles.SelectedItem) { Update-Status }
	}

	if ($script:PendingListDetails.Count -eq 0) {
		$script:ListHydrateTimer.Stop()
	}
})

function Start-ListDetailsHydration {
	if (-not $script:PendingListDetails) { return }

	foreach ($item in $files) {
		if (-not $item) { continue }
		if ($item.HasDetailsHydrated) { continue }
		$script:PendingListDetails.Enqueue($item)
	}

	if ($script:PendingListDetails.Count -gt 0 -and -not $script:ListHydrateTimer.IsEnabled) {
		$script:ListHydrateTimer.Start()
	}
}

function Set-CommentEditMode {
	param([bool]$Enable)

	$script:IsCommentEditMode = $Enable
	if ($Enable) {
		$txtComment.IsReadOnly = $false
		$txtComment.Background = '#FFFFFF'
		$txtComment.BorderBrush = '#15803D'
		$txtComment.BorderThickness = '2'
		$btnEditComment.Visibility = 'Collapsed'
		$btnSaveComment.Visibility = 'Visible'
		$btnRevertComment.Visibility = 'Visible'
		$txtComment.Focus()
		$txtComment.CaretIndex = $txtComment.Text.Length
	} else {
		$txtComment.IsReadOnly = $true
		$txtComment.Background = '#FCFCFD'
		$txtComment.BorderBrush = '#D7DDE6'
		$txtComment.BorderThickness = '1'
		$btnEditComment.Visibility = 'Visible'
		$btnSaveComment.Visibility = 'Collapsed'
		$btnRevertComment.Visibility = 'Collapsed'
	}
}

function Get-WrappedIndex {
	param(
		[int]$Index,
		[int]$Count
	)

	if ($Count -le 0) { return -1 }
	while ($Index -lt 0) { $Index += $Count }
	if ($Index -ge $Count) { $Index = $Index % $Count }
	return $Index
}

function Update-NavTooltips {
	if ($files.Count -eq 0) {
		$btnPrev.ToolTip = 'Select previous file'
		$btnNext.ToolTip = 'Select next file'
		$btnOverlayPrev.ToolTip = 'Previous image'
		$btnOverlayNext.ToolTip = 'Next image'
		return
	}

	$currentIndex = if ($lbFiles.SelectedIndex -ge 0) { $lbFiles.SelectedIndex } else { 0 }
	$prevIndex = Get-WrappedIndex -Index ($currentIndex - 1) -Count $files.Count
	$nextIndex = Get-WrappedIndex -Index ($currentIndex + 1) -Count $files.Count
	$prevItem = $files[$prevIndex]
	$nextItem = $files[$nextIndex]

	$prevTip = "Previous: $($prevItem.Name)"
	$nextTip = "Next: $($nextItem.Name)"
	$btnPrev.ToolTip = $prevTip
	$btnNext.ToolTip = $nextTip
	$btnOverlayPrev.ToolTip = $prevTip
	$btnOverlayNext.ToolTip = $nextTip
}

function Set-FullscreenMode {
	param([bool]$Enable)

	if ($Enable -eq $script:IsFullscreenMode) { return }

	if ($Enable) {
		$script:SavedWindowStyle = $window.WindowStyle
		$script:SavedResizeMode = $window.ResizeMode
		$script:SavedWindowState = $window.WindowState
		$script:SavedTopmost = $window.Topmost
		$script:SavedTopRowHeight = $mainContentGrid.Parent.RowDefinitions[0].Height
		$script:SavedStatusRowHeight = $mainContentGrid.Parent.RowDefinitions[2].Height
		$script:SavedLeftColumnWidth = $mainContentGrid.ColumnDefinitions[0].Width
		$script:SavedSplitterColumnWidth = $mainContentGrid.ColumnDefinitions[1].Width
		$script:SavedMetaRowHeight = $viewerPanelGrid.RowDefinitions[2].Height
		$script:SavedMetaSplitterHeight = $viewerPanelGrid.RowDefinitions[1].Height
		$script:SavedPropsRowHeight = $metadataGrid.RowDefinitions[0].Height
		$script:SavedCommentRowHeight = $metadataGrid.RowDefinitions[1].Height

		$mainContentGrid.Parent.RowDefinitions[0].Height = New-Object System.Windows.GridLength(0)
		$mainContentGrid.Parent.RowDefinitions[2].Height = New-Object System.Windows.GridLength(0)
		$mainContentGrid.ColumnDefinitions[0].Width = New-Object System.Windows.GridLength(0)
		$mainContentGrid.ColumnDefinitions[1].Width = New-Object System.Windows.GridLength(0)

		$fileListBorder.Visibility = 'Collapsed'
		$fileListSplitter.Visibility = 'Collapsed'
		$topToolbarBorder.Visibility = 'Collapsed'
		$statusBarMain.Visibility = 'Collapsed'

		$viewerPanelGrid.RowDefinitions[1].Height = New-Object System.Windows.GridLength(0)
		$viewerPanelGrid.RowDefinitions[2].Height = New-Object System.Windows.GridLength(220)
		$viewerMetaSplitter.Visibility = 'Collapsed'
		$propsBorder.Visibility = 'Collapsed'
		$metadataGrid.RowDefinitions[0].Height = New-Object System.Windows.GridLength(0)
		$metadataGrid.RowDefinitions[1].Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
		$commentBorder.Margin = '0'
		$btnCloseFullscreen.Visibility = 'Visible'

		$window.WindowStyle = [System.Windows.WindowStyle]::None
		$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
		$window.Topmost = $true
		$window.WindowState = [System.Windows.WindowState]::Maximized
		$btnToggleFullscreen.Content = 'Restore'
		$btnToggleFullscreen.ToolTip = 'Restore normal layout and window mode'
		$script:IsFullscreenMode = $true
	} else {
		$mainContentGrid.Parent.RowDefinitions[0].Height = $script:SavedTopRowHeight
		$mainContentGrid.Parent.RowDefinitions[2].Height = $script:SavedStatusRowHeight
		$mainContentGrid.ColumnDefinitions[0].Width = $script:SavedLeftColumnWidth
		$mainContentGrid.ColumnDefinitions[1].Width = $script:SavedSplitterColumnWidth

		$fileListBorder.Visibility = 'Visible'
		$fileListSplitter.Visibility = 'Visible'
		$topToolbarBorder.Visibility = 'Visible'
		$statusBarMain.Visibility = 'Visible'

		$viewerPanelGrid.RowDefinitions[1].Height = $script:SavedMetaSplitterHeight
		$viewerPanelGrid.RowDefinitions[2].Height = $script:SavedMetaRowHeight
		$viewerMetaSplitter.Visibility = 'Visible'
		$propsBorder.Visibility = 'Visible'
		$metadataGrid.RowDefinitions[0].Height = $script:SavedPropsRowHeight
		$metadataGrid.RowDefinitions[1].Height = $script:SavedCommentRowHeight
		$commentBorder.Margin = '0'
		$btnCloseFullscreen.Visibility = 'Collapsed'

		$window.WindowStyle = $script:SavedWindowStyle
		$window.ResizeMode = $script:SavedResizeMode
		$window.Topmost = $script:SavedTopmost
		$window.WindowState = $script:SavedWindowState
		$btnToggleFullscreen.Content = 'Maximize'
		$btnToggleFullscreen.ToolTip = 'Maximize image area with bottom comment panel'
		$script:IsFullscreenMode = $false
	}

	$window.Dispatcher.BeginInvoke([Action]{
		$svImage.UpdateLayout()
		if ($script:ZoomMode -ne 'Custom' -or $script:IsFitPending) {
			Apply-FitMode
		}
		Update-DebugMetrics
	}, [System.Windows.Threading.DispatcherPriority]::Loaded) | Out-Null
}

function Update-Status {
	$count = $files.Count
	$totalBytes = 0L
	foreach ($item in $files) {
		if ($item -and $item.Size -is [long]) {
			$totalBytes += $item.Size
		}
	}

	$currentPath = ''
	$currentName = '(none)'
	if ($lbFiles.SelectedItem) {
		$currentPath = $lbFiles.SelectedItem.FullPath
		$currentName = $lbFiles.SelectedItem.Name
	}

	$diskFreeText = 'Disk Free: n/a'
	if ($currentPath) {
		try {
			$root = [IO.Path]::GetPathRoot($currentPath)
			if ($root -and $root.Length -ge 1) {
				$driveName = $root.TrimEnd('\\').TrimEnd(':')
				$drive = Get-PSDrive -Name $driveName -ErrorAction Stop
				$diskFreeText = "Disk Free: $(Format-Bytes ([long]$drive.Free))"
			}
		} catch {
		}
	}

	$txtCurrentFile.Text = "Current: $currentName"
	$txtCurrentFile.ToolTip = if ($currentPath) { $currentPath } else { 'No file selected.' }
	$runCurrentValue.Text = $currentName
	$runFilesValue.Text = [string]$count
	$runTotalValue.Text = Format-Bytes $totalBytes
	$runDiskValue.Text = $diskFreeText.Replace('Disk Free: ', '')
	Update-NavTooltips
}

function Set-Zoom {
	param(
		[double]$Value,
		[string]$Mode = 'Custom'
	)

	if ($Value -lt 0.05) { $Value = 0.05 }
	if ($Value -gt 20.0) { $Value = 20.0 }

	$script:CurrentZoom = $Value
	$script:ZoomMode = $Mode
	$scaleTransform.ScaleX = $Value
	$scaleTransform.ScaleY = $Value
	$txtZoom.Text = ('Zoom: {0:N0}%' -f ($Value * 100))
	Update-DebugMetrics
}

function Apply-FitMode {
	if (-not $script:CurrentBitmap) { return }
	if ($svImage.ViewportWidth -le 1 -or $svImage.ViewportHeight -le 1) {
		$script:IsFitPending = $true
		return
	}

	$imgW = [double]$script:CurrentBitmap.PixelWidth
	$imgH = [double]$script:CurrentBitmap.PixelHeight
	if ($imgW -le 0 -or $imgH -le 0) { return }

	$viewW = [double]$svImage.ViewportWidth
	$viewH = [double]$svImage.ViewportHeight

	switch ($script:ZoomMode) {
		'FitWidth' { $zoom = $viewW / $imgW }
		'FitHeight' { $zoom = $viewH / $imgH }
		default {
			$zoomW = $viewW / $imgW
			$zoomH = $viewH / $imgH
			$zoom = [Math]::Min($zoomW, $zoomH)
			$script:ZoomMode = 'Fit'
		}
	}

	Set-Zoom -Value $zoom -Mode $script:ZoomMode
	$svImage.ScrollToHorizontalOffset(0)
	$svImage.ScrollToVerticalOffset(0)
	$svImage.UpdateLayout()
	Update-DebugMetrics
	$script:IsFitPending = $false
}

function Set-ImageProperties {
	param([string]$Path)

	$meta = Get-JpegMetadataRows -Path $Path
	if ($script:IsCommentEditMode) {
		Set-CommentEditMode -Enable $false
	}
	$dgProps.ItemsSource = $meta.Rows
	$txtComment.Text = $meta.Comment
	$script:OriginalCommentText = $meta.Comment
	Update-CommentIndicator -CommentText $meta.Comment
}

function Load-Image {
	param([string]$Path)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		$imgViewer.Source = $null
		$script:CurrentBitmap = $null
		$dgProps.ItemsSource = $null
		$txtComment.Text = ''
		Update-Status
		return
	}

	$bitmap = $null
	$fs = $null
	try {
		$fs = New-Object System.IO.FileStream(
			$Path,
			[System.IO.FileMode]::Open,
			[System.IO.FileAccess]::Read,
			[System.IO.FileShare]::ReadWrite
		)

		$bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
		$bitmap.BeginInit()
		$bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
		$bitmap.CreateOptions = [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat
		$bitmap.StreamSource = $fs
		$bitmap.EndInit()
		$bitmap.Freeze()
	} catch {
		$imgViewer.Source = $null
		$script:CurrentBitmap = $null
		$txtStatus.Text = "Image load error: $($_.Exception.Message)"
		Set-ImageProperties -Path $Path
		return
	} finally {
		if ($fs) { $fs.Dispose() }
	}

	$script:CurrentBitmap = $bitmap
	$imgViewer.Source = $bitmap
	$imgViewer.HorizontalAlignment = 'Left'
	$imgViewer.VerticalAlignment = 'Top'
	$script:IsFitPending = $true

	if (-not $script:HasLoadedFirstImage) {
		$script:ZoomMode = 'Fit'
		Apply-FitMode
		$script:HasLoadedFirstImage = $true
	} elseif ($script:ZoomMode -eq 'Custom') {
		Set-Zoom -Value $script:CurrentZoom -Mode 'Custom'
	} else {
		Apply-FitMode
	}

	Set-ImageProperties -Path $Path
	[void]$window.Dispatcher.BeginInvoke(
		[Action]{
			$svImage.UpdateLayout()
			$imgViewer.HorizontalAlignment = 'Left'
			$imgViewer.VerticalAlignment = 'Top'
			$svImage.ScrollToHorizontalOffset(0)
			$svImage.ScrollToVerticalOffset(0)
			Update-DebugMetrics
		},
		[System.Windows.Threading.DispatcherPriority]::Loaded
	)
	Update-Status
}

function Select-Relative {
	param([int]$Delta)

	if ($files.Count -eq 0) { return }

	$currentIndex = $lbFiles.SelectedIndex
	if ($currentIndex -lt 0) {
		$lbFiles.SelectedIndex = 0
		return
	}

	$newIndex = Get-WrappedIndex -Index ($currentIndex + $Delta) -Count $files.Count

	if ($newIndex -ne $currentIndex) {
		$lbFiles.SelectedIndex = $newIndex
		$lbFiles.ScrollIntoView($lbFiles.SelectedItem)
	}
}

function Add-ImageItems {
	param(
		[System.IO.FileInfo[]]$FileInfos,
		[switch]$ClearFirst
	)

	if ($ClearFirst) {
		$files.Clear()
		if ($script:PendingListDetails) {
			$script:PendingListDetails.Clear()
		}
	}

	$existing = @{}
	foreach ($item in $files) {
		$existing[$item.FullPath.ToLowerInvariant()] = $true
	}

	foreach ($fi in $FileInfos) {
		if (-not $fi) { continue }
		if (-not (Test-Path -LiteralPath $fi.FullName -PathType Leaf)) { continue }
		if (-not (Get-IsJpegPath -Path $fi.FullName)) { continue }

		$key = $fi.FullName.ToLowerInvariant()
		if ($existing.ContainsKey($key)) { continue }

		$files.Add([pscustomobject]@{
			Name             = $fi.Name
			FullPath         = $fi.FullName
			Size             = [long]$fi.Length
			SizeDisplay      = Format-SizeForList -Bytes ([long]$fi.Length)
			LastModified     = $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm ddd')
			CompressionRatio = '...'
			HasComment       = $false
			CommentToolTip   = 'Loading JPEG comment...'
			HasDetailsHydrated = $false
		})
		$existing[$key] = $true
	}

	Start-ListDetailsHydration
	Update-Status
}

function Load-FolderAndSelectFile {
	param([string]$FilePath)

	$resolved = Resolve-Path -LiteralPath $FilePath
	$target = Get-Item -LiteralPath $resolved.Path

	if ($target.PSIsContainer) {
		$all = Get-JpegFilesInDirectory -DirectoryPath $target.FullName
		Add-ImageItems -FileInfos $all -ClearFirst
		if ($files.Count -gt 0) {
			$lbFiles.SelectedIndex = 0
		}
		return
	}

	if (-not (Get-IsJpegPath -Path $target.FullName)) {
		throw "The selected file is not a .jpg or .jpeg file: $($target.FullName)"
	}

	$allInDir = Get-JpegFilesInDirectory -DirectoryPath $target.DirectoryName
	Add-ImageItems -FileInfos $allInDir -ClearFirst

	for ($i = 0; $i -lt $files.Count; $i++) {
		if ($files[$i].FullPath -ieq $target.FullName) {
			$lbFiles.SelectedIndex = $i
			$lbFiles.ScrollIntoView($lbFiles.SelectedItem)
			break
		}
	}
}

function Import-DroppedPaths {
	param([string[]]$Paths)

	if (-not $Paths -or $Paths.Count -eq 0) { return }

	$buffer = New-Object System.Collections.Generic.List[System.IO.FileInfo]
	foreach ($path in $Paths) {
		if (-not (Test-Path -LiteralPath $path)) { continue }

		$item = Get-Item -LiteralPath $path
		if ($item.PSIsContainer) {
			$jpegInFolder = Get-JpegFilesInDirectory -DirectoryPath $item.FullName
			foreach ($file in $jpegInFolder) { [void]$buffer.Add($file) }
		} else {
			if (Get-IsJpegPath -Path $item.FullName) {
				[void]$buffer.Add($item)
			}
		}
	}

	Add-ImageItems -FileInfos $buffer.ToArray()
	if ($lbFiles.SelectedIndex -lt 0 -and $files.Count -gt 0) {
		$lbFiles.SelectedIndex = 0
	}
}

function Remove-SelectedFilesFromList {
	if ($files.Count -eq 0) {
		$txtStatus.Text = 'File list is empty; nothing to remove.'
		return
	}

	$selected = @($lbFiles.SelectedItems)
	if (-not $selected -or $selected.Count -eq 0) {
		if ($lbFiles.SelectedItem) {
			$selected = @($lbFiles.SelectedItem)
		} else {
			$txtStatus.Text = 'No selected file(s) to remove.'
			return
		}
	}

	$count = $selected.Count
	$message = if ($count -eq 1) {
		"Remove file from list?`n`n$($selected[0].Name)"
	} else {
		"Remove $count files from list?"
	}

	$result = [System.Windows.MessageBox]::Show(
		$message,
		'Confirm Remove',
		[System.Windows.MessageBoxButton]::YesNo,
		[System.Windows.MessageBoxImage]::Question
	)
	if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
		$txtStatus.Text = 'Remove canceled.'
		return
	}

	$anchorIndex = $lbFiles.SelectedIndex
	foreach ($item in $selected) {
		[void]$files.Remove($item)
	}

	if ($script:PendingListDetails) {
		$script:PendingListDetails.Clear()
		Start-ListDetailsHydration
	}

	if ($files.Count -eq 0) {
		$lbFiles.SelectedIndex = -1
		$imgViewer.Source = $null
		$script:CurrentBitmap = $null
		$dgProps.ItemsSource = $null
		$txtComment.Text = ''
		Update-CommentIndicator -CommentText ''
		Update-Status
		$txtStatus.Text = if ($count -eq 1) { 'Removed 1 file from list.' } else { "Removed $count files from list." }
		return
	}

	if ($anchorIndex -lt 0) { $anchorIndex = 0 }
	if ($anchorIndex -ge $files.Count) { $anchorIndex = $files.Count - 1 }
	$lbFiles.SelectedIndex = $anchorIndex
	$lbFiles.ScrollIntoView($lbFiles.SelectedItem)
	Update-Status
	$txtStatus.Text = if ($count -eq 1) { 'Removed 1 file from list.' } else { "Removed $count files from list." }
}

$lbFiles.Add_SelectionChanged({
	if ($lbFiles.SelectedItem) {
		Load-Image -Path $lbFiles.SelectedItem.FullPath
	} else {
		if ($script:IsCommentEditMode) {
			Set-CommentEditMode -Enable $false
		}
		$script:OriginalCommentText = ''
		Update-Status
	}
})

$lbFiles.Add_PreviewMouseRightButtonDown({
	param($sender, $e)
	$depObj = $e.OriginalSource -as [System.Windows.DependencyObject]
	if (-not $depObj) { return }

	$listViewItem = Get-AncestorOfType -Start $depObj -TargetType ([System.Windows.Controls.ListViewItem])
	if (-not $listViewItem) { return }

	$clickedItem = $listViewItem.DataContext
	if (-not $clickedItem) { return }

	if (-not $lbFiles.SelectedItems.Contains($clickedItem)) {
		$lbFiles.SelectedItems.Clear()
		$lbFiles.SelectedItem = $clickedItem
	}
})

$miRemoveFromList.Add_Click({
	Remove-SelectedFilesFromList
})

$btnToggleFullscreen.Add_Click({
	Set-FullscreenMode -Enable (-not $script:IsFullscreenMode)
})
$btnCloseFullscreen.Add_Click({
	Set-FullscreenMode -Enable $false
})

$btnPrev.Add_Click({ Select-Relative -Delta -1 })
$btnNext.Add_Click({ Select-Relative -Delta 1 })
$btnOverlayPrev.Add_Click({ Select-Relative -Delta -1 })
$btnOverlayNext.Add_Click({ Select-Relative -Delta 1 })

$btnFit.Add_Click({ $script:ZoomMode = 'Fit'; Apply-FitMode })
$btnFitWidth.Add_Click({ $script:ZoomMode = 'FitWidth'; Apply-FitMode })
$btnFitHeight.Add_Click({ $script:ZoomMode = 'FitHeight'; Apply-FitMode })
$btnResetView.Add_Click({
	$script:ZoomMode = 'Fit'
	Apply-FitMode
	$svImage.ScrollToHorizontalOffset(0)
	$svImage.ScrollToVerticalOffset(0)
})
$btnZoomOut.Add_Click({ Set-Zoom -Value ($script:CurrentZoom / 1.20) -Mode 'Custom' })
$btnZoomIn.Add_Click({ Set-Zoom -Value ($script:CurrentZoom * 1.20) -Mode 'Custom' })

$btnClearFiles.Add_Click({
	$files.Clear()
	if ($script:PendingListDetails) {
		$script:PendingListDetails.Clear()
	}
	if ($script:ListHydrateTimer -and $script:ListHydrateTimer.IsEnabled) {
		$script:ListHydrateTimer.Stop()
	}
	$lbFiles.SelectedIndex = -1
	$imgViewer.Source = $null
	$script:CurrentBitmap = $null
	$script:CurrentZoom = 1.0
	$txtZoom.Text = 'Zoom: 100%'
	$dgProps.ItemsSource = $null
	$txtComment.Text = ''
	Update-CommentIndicator -CommentText ''
	Update-Status
	$txtStatus.Text = 'Cleared loaded files and reset viewer state.'
})

$svImage.Add_PreviewMouseWheel({
	param($sender, $e)
	if (-not $script:CurrentBitmap) { return }

	if ($e.Delta -gt 0) {
		Set-Zoom -Value ($script:CurrentZoom * 1.12) -Mode 'Custom'
	} else {
		Set-Zoom -Value ($script:CurrentZoom / 1.12) -Mode 'Custom'
	}
	$e.Handled = $true
})

$svImage.Add_PreviewMouseLeftButtonDown({
	param($sender, $e)
	if ($e.ClickCount -ge 2) {
		$script:ZoomMode = 'FitWidth'
		Apply-FitMode
		$e.Handled = $true
		return
	}
	if (-not $script:CurrentBitmap) { return }
	$script:IsPanning = $true
	$script:PanStartPoint = $e.GetPosition($svImage)
	$script:PanStartH = $svImage.HorizontalOffset
	$script:PanStartV = $svImage.VerticalOffset
	$svImage.CaptureMouse()
	$svImage.Cursor = [System.Windows.Input.Cursors]::SizeAll
	$e.Handled = $true
})

$svImage.Add_PreviewMouseMove({
	param($sender, $e)
	if (-not $script:IsPanning -or -not $script:PanStartPoint) { return }
	$current = $e.GetPosition($svImage)
	$dx = $current.X - $script:PanStartPoint.X
	$dy = $current.Y - $script:PanStartPoint.Y
	$svImage.ScrollToHorizontalOffset($script:PanStartH - $dx)
	$svImage.ScrollToVerticalOffset($script:PanStartV - $dy)
	Update-DebugMetrics
	$e.Handled = $true
})

$svImage.Add_PreviewMouseLeftButtonUp({
	param($sender, $e)
	if (-not $script:IsPanning) { return }
	$script:IsPanning = $false
	$script:PanStartPoint = $null
	$svImage.ReleaseMouseCapture()
	$svImage.Cursor = [System.Windows.Input.Cursors]::Hand
	$e.Handled = $true
})

$svImage.Add_MouseLeave({
	if ($script:IsPanning) {
		$script:IsPanning = $false
		$script:PanStartPoint = $null
		$svImage.ReleaseMouseCapture()
	}
	$svImage.Cursor = [System.Windows.Input.Cursors]::Hand
})

$imageHost.Add_MouseEnter({
	$btnOverlayPrev.Visibility = 'Visible'
	$btnOverlayNext.Visibility = 'Visible'
})

$imageHost.Add_MouseLeave({
	$btnOverlayPrev.Visibility = 'Collapsed'
	$btnOverlayNext.Visibility = 'Collapsed'
})

$svImage.Add_SizeChanged({
	if ($script:ZoomMode -ne 'Custom' -or $script:IsFitPending) {
		Apply-FitMode
	}
	Update-DebugMetrics
})

$svImage.Add_ScrollChanged({ Update-DebugMetrics })

$viewerMetaSplitter.Add_PreviewMouseLeftButtonDown({
	param($sender, $e)
	if ($e.ClickCount -lt 2) { return }
	if ($script:IsFullscreenMode) { return }

	if (-not $script:IsPropsExpandedBySplitterToggle) {
		$script:BeforeExpandMetaRow0 = $metadataGrid.RowDefinitions[0].Height
		$script:BeforeExpandMetaRow1 = $metadataGrid.RowDefinitions[1].Height
		$metadataGrid.RowDefinitions[0].Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
		$metadataGrid.RowDefinitions[1].Height = New-Object System.Windows.GridLength(0)
		$script:IsPropsExpandedBySplitterToggle = $true
		$txtStatus.Text = 'Properties expanded (double-click splitter to restore).'
	} else {
		$metadataGrid.RowDefinitions[0].Height = $script:BeforeExpandMetaRow0
		$metadataGrid.RowDefinitions[1].Height = $script:BeforeExpandMetaRow1
		$script:IsPropsExpandedBySplitterToggle = $false
		$txtStatus.Text = 'Properties/comment split restored.'
	}

	Update-DebugMetrics
	$e.Handled = $true
})

$btnAddFiles.Add_Click({
	$ofd = New-Object Microsoft.Win32.OpenFileDialog
	$ofd.Filter = 'JPEG Files (*.jpg;*.jpeg)|*.jpg;*.jpeg|All Files (*.*)|*.*'
	$ofd.Multiselect = $true

	if ($ofd.ShowDialog()) {
		$chosen = @()
		foreach ($file in $ofd.FileNames) {
			$chosen += Get-Item -LiteralPath $file
		}
		Add-ImageItems -FileInfos $chosen
		if ($lbFiles.SelectedIndex -lt 0 -and $files.Count -gt 0) {
			$lbFiles.SelectedIndex = 0
		}
	}
})

$btnAddFolder.Add_Click({
	$fbd = New-Object System.Windows.Forms.FolderBrowserDialog
	$fbd.Description = 'Select folder with .jpg/.jpeg files'
	$picked = $fbd.ShowDialog()

	if ($picked -eq [System.Windows.Forms.DialogResult]::OK -and $fbd.SelectedPath) {
		$folderFiles = Get-JpegFilesInDirectory -DirectoryPath $fbd.SelectedPath
		Add-ImageItems -FileInfos $folderFiles
		if ($lbFiles.SelectedIndex -lt 0 -and $files.Count -gt 0) {
			$lbFiles.SelectedIndex = 0
		}
	}
})

$window.Add_PreviewDragOver({
	param($sender, $e)
	if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
		$e.Effects = [Windows.DragDropEffects]::Copy
	} else {
		$e.Effects = [Windows.DragDropEffects]::None
	}
	$e.Handled = $true
})

$window.Add_Drop({
	param($sender, $e)
	if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
		$paths = [string[]]$e.Data.GetData([Windows.DataFormats]::FileDrop)
		Import-DroppedPaths -Paths $paths
	}
})

$lbFiles.Add_PreviewDragOver({
	param($sender, $e)
	if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
		$e.Effects = [Windows.DragDropEffects]::Copy
	} else {
		$e.Effects = [Windows.DragDropEffects]::None
	}
	$e.Handled = $true
})

$lbFiles.Add_Drop({
	param($sender, $e)
	if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
		$paths = [string[]]$e.Data.GetData([Windows.DataFormats]::FileDrop)
		Import-DroppedPaths -Paths $paths
	}
	$e.Handled = $true
})

$dgProps.Add_MouseLeftButtonUp({
	param($sender, $e)

	$depObj = $e.OriginalSource -as [System.Windows.DependencyObject]
	if (-not $depObj) { return }

	$row = Get-AncestorOfType -Start $depObj -TargetType ([System.Windows.Controls.DataGridRow])
	if (-not $row) { return }

	$item = $row.Item
	if (-not $item) { return }

	if ($item.IsUrl -and $item.Url) {
		Start-Process -FilePath $item.Url
	}
})

$window.Add_KeyDown({
	param($sender, $e)
	if ($e.Key -eq 'Escape' -and $script:IsFullscreenMode) {
		Set-FullscreenMode -Enable $false
		$e.Handled = $true
	} elseif ($e.Key -eq 'Left') {
		Select-Relative -Delta -1
		$e.Handled = $true
	} elseif ($e.Key -eq 'Right') {
		Select-Relative -Delta 1
		$e.Handled = $true
	}
})

$btnCopyProps.Add_Click({
	$formatName = 'Text'
	if ($cmbCopyFormat.SelectedItem) {
		$formatName = [string]$cmbCopyFormat.SelectedItem.Content
	}

	$text = Convert-PropsToClipboardText -FormatName $formatName
	if (-not [string]::IsNullOrWhiteSpace($text)) {
		[System.Windows.Clipboard]::SetText($text)
		$txtStatus.Text = "Copied properties as $formatName."
	} else {
		$txtStatus.Text = 'No properties available to copy.'
	}
})

$btnCopyComment.Add_Click({
	if (-not [string]::IsNullOrWhiteSpace($txtComment.Text)) {
		[System.Windows.Clipboard]::SetText($txtComment.Text)
		$txtStatus.Text = 'Copied JPEG comment text to clipboard.'
	} else {
		$txtStatus.Text = 'JPEG comment is empty; nothing copied.'
	}
})

$btnEditComment.Add_Click({
	if (-not $lbFiles.SelectedItem) {
		$txtStatus.Text = 'Select an image before editing comment.'
		return
	}
	$script:OriginalCommentText = [string]$txtComment.Text
	Set-CommentEditMode -Enable $true
	$txtStatus.Text = 'Inline comment edit mode enabled.'
})

$btnRevertComment.Add_Click({
	if (-not $script:IsCommentEditMode) { return }
	$txtComment.Text = $script:OriginalCommentText
	Update-CommentIndicator -CommentText $txtComment.Text
	Update-CommentUrlRowsInGrid -CommentText $txtComment.Text
	Set-CommentEditMode -Enable $false
	$txtStatus.Text = 'Comment edits reverted.'
})

$btnSaveComment.Add_Click({
	if (-not $script:IsCommentEditMode) { return }
	if (-not $lbFiles.SelectedItem) {
		Set-CommentEditMode -Enable $false
		$txtStatus.Text = 'No selected image; comment changes not saved.'
		return
	}

	$selectedItem = $lbFiles.SelectedItem
	$path = [string]$selectedItem.FullPath
	$newComment = [string]$txtComment.Text

	try {
		Set-JpegComment -Path $path -CommentText $newComment
		Set-CommentEditMode -Enable $false
		Set-ImageProperties -Path $path
		$selectedItem.HasComment = (-not [string]::IsNullOrWhiteSpace($newComment))
		$selectedItem.CommentToolTip = if ([string]::IsNullOrWhiteSpace($newComment)) { 'No JPEG comment found.' } else { $newComment }
		$lbFiles.Items.Refresh()
		$txtStatus.Text = 'JPEG comment saved.'
	} catch {
		$txtStatus.Text = "Save failed: $($_.Exception.Message)"
	}
})

$btnCopyImage.Add_Click({
	if ($script:CurrentBitmap) {
		[System.Windows.Clipboard]::SetImage($script:CurrentBitmap)
		$txtStatus.Text = 'Copied image to clipboard.'
	} else {
		$txtStatus.Text = 'No image loaded; nothing copied.'
	}
})

$btnAbout.Add_Click({
	$script:DebugToggleButtonRef = $null
	Show-AboutDialog -Owner $window -AllowAppendUrl
})

$window.Add_SourceInitialized({
	if ($viewerSettings.Window.Width -gt 100) { $window.Width = $viewerSettings.Window.Width }
	if ($viewerSettings.Window.Height -gt 100) { $window.Height = $viewerSettings.Window.Height }
	if (-not [double]::IsNaN([double]$viewerSettings.Window.Left)) { $window.Left = [double]$viewerSettings.Window.Left }
	if (-not [double]::IsNaN([double]$viewerSettings.Window.Top)) { $window.Top = [double]$viewerSettings.Window.Top }
	if ($viewerSettings.Window.State -in @('Normal', 'Maximized')) {
		$window.WindowState = [System.Windows.WindowState]::$($viewerSettings.Window.State)
	}

	$desiredCopy = [string]$viewerSettings.LastCopyFormat
	if (-not [string]::IsNullOrWhiteSpace($desiredCopy)) {
		foreach ($item in $cmbCopyFormat.Items) {
			if ($item.Content -eq $desiredCopy) {
				$cmbCopyFormat.SelectedItem = $item
				break
			}
		}
	}

	$debugWindow.Left = $window.Left + $window.Width + 14
	$debugWindow.Top = $window.Top
	if ($viewerSettings.DebugWindow) {
		if ($viewerSettings.DebugWindow.Width -gt 100) { $debugWindow.Width = [double]$viewerSettings.DebugWindow.Width }
		if ($viewerSettings.DebugWindow.Height -gt 80) { $debugWindow.Height = [double]$viewerSettings.DebugWindow.Height }
		$debugWindow.Left = [double]$viewerSettings.DebugWindow.Left
		$debugWindow.Top = [double]$viewerSettings.DebugWindow.Top
	}
	Clamp-WindowToVisibleScreen -Window $debugWindow -DefaultLeft ($window.Left + $window.Width + 14) -DefaultTop $window.Top
	if (-not $debugWindow.IsVisible) {
		[void]$debugWindow.Show()
	}
	Update-DebugMetrics
})

$window.Add_Closing({
	if ($script:IsFullscreenMode) {
		Set-FullscreenMode -Enable $false
	}
	$selectedPath = ''
	if ($lbFiles.SelectedItem) { $selectedPath = [string]$lbFiles.SelectedItem.FullPath }
	$copyFormat = if ($cmbCopyFormat.SelectedItem) { [string]$cmbCopyFormat.SelectedItem.Content } else { 'Text' }
	Write-ViewerSettings -Settings $viewerSettings -Window $window -CurrentFiles $files -SelectedFile $selectedPath -CopyFormat $copyFormat -DebugWindow $debugWindow
	if ($debugWindow -and $debugWindow.IsVisible) { $debugWindow.Hide() }
})

Update-Status

Show-AboutDialog -Owner $window -AutoCloseSeconds 5

$startupImagePath = $ImageFile
if (-not $startupImagePath -and $ExtraArgs -and $ExtraArgs.Count -gt 0) {
	foreach ($arg in $ExtraArgs) {
		if ([string]::IsNullOrWhiteSpace($arg)) { continue }
		if (Test-Path -LiteralPath $arg -PathType Leaf -ErrorAction SilentlyContinue) {
			$startupImagePath = $arg
			break
		}
	}
}

if ($CommandLine -or $startupImagePath) {
	if ($startupImagePath) {
		try {
			Load-FolderAndSelectFile -FilePath $startupImagePath
		} catch {
			$txtStatus.Text = "Command-line image load failed: $($_.Exception.Message)"
		}
	} else {
		$txtStatus.Text = 'Command-line mode started without image path; use Add Files or Add Folder.'
	}
} elseif ($viewerSettings.LastFiles -and $viewerSettings.LastFiles.Count -gt 0) {
	$restore = @()
	foreach ($path in $viewerSettings.LastFiles) {
		if ($path -and (Test-Path -LiteralPath $path -PathType Leaf) -and (Get-IsJpegPath -Path $path)) {
			$restore += Get-Item -LiteralPath $path
		}
	}

	if ($restore.Count -gt 0) {
		Add-ImageItems -FileInfos $restore -ClearFirst
		$lbFiles.SelectedIndex = 0

		if ($viewerSettings.LastSelectedFile) {
			for ($i = 0; $i -lt $files.Count; $i++) {
				if ($files[$i].FullPath -ieq $viewerSettings.LastSelectedFile) {
					$lbFiles.SelectedIndex = $i
					break
				}
			}
		}
	}
}

[void]$window.ShowDialog()
