<#
.SYNOPSIS
WPF UI for CompressSafeZip.ps1.

.DESCRIPTION
Provides a Windows PowerShell 5.1 desktop UI for both operations:
1) Create Safe Zip: append .txt to script-like extensions in archive.
2) Unzip and Restore (inverse): remove trailing .txt from .ps1.txt/.cmd.txt/
   .vbs.txt/.vmbs.txt while extracting to a folder.

Settings are saved to:
CompressSafeZip.Wpf.Settings.json

.EXAMPLE
.
\CompressSafeZip.Wpf.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null
Add-Type -AssemblyName System.Windows.Forms | Out-Null

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreScript = Join-Path $scriptRoot 'CompressSafeZip.ps1'
$settingsPath = Join-Path $scriptRoot (([System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)) + '.Settings.json')

# Compatibility shim: avoids failures if an external timer/event handler calls this name.
function Update-DebugClock {
    param()
}

if (-not (Test-Path -LiteralPath $coreScript)) {
    throw "Core script not found: $coreScript"
}

function Get-DefaultSettings {
    return [ordered]@{
        SourcePath = (Get-Location).Path
        OutputZipPath = ''
        Recurse = $false
        OpenOutputFolder = $true

        UnzipZipPath = ''
        UnzipDestinationPath = ''
        OpenUnzipFolder = $true

        WhatIf = $false

        LastLogPath = ''

        WindowLeft = $null
        WindowTop = $null
        WindowWidth = 1060
        WindowHeight = 760
    }
}

function Get-DefaultZipPath {
    param([Parameter(Mandatory = $true)][string]$SourcePath)

    $resolved = [System.IO.Path]::GetFullPath($SourcePath)
    $folderName = [System.IO.Path]::GetFileName($resolved.TrimEnd('\', '/'))
    if ([string]::IsNullOrWhiteSpace($folderName)) {
        $folderName = 'Archive'
    }

    $parent = [System.IO.Path]::GetDirectoryName($resolved)
    if ([string]::IsNullOrWhiteSpace($parent)) {
        $parent = $resolved
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return (Join-Path $parent ("{0}.{1}.safe.zip" -f $folderName, $stamp))
}

function Get-DefaultUnzipPath {
    param([Parameter(Mandatory = $true)][string]$ZipPath)

    $resolved = [System.IO.Path]::GetFullPath($ZipPath)
    $zipParent = [System.IO.Path]::GetDirectoryName($resolved)
    if ([string]::IsNullOrWhiteSpace($zipParent)) {
        $zipParent = (Get-Location).Path
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
    if ([string]::IsNullOrWhiteSpace($baseName)) {
        $baseName = 'Archive'
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return (Join-Path $zipParent ("{0}.restored.{1}" -f $baseName, $stamp))
}

function Read-Settings {
    $defaults = Get-DefaultSettings

    if (-not (Test-Path -LiteralPath $settingsPath)) {
        return [pscustomobject]$defaults
    }

    try {
        $raw = Get-Content -LiteralPath $settingsPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return [pscustomobject]$defaults
        }

        $data = ConvertFrom-Json -InputObject $raw
        foreach ($key in $defaults.Keys) {
            if ($null -eq $data.PSObject.Properties[$key]) {
                $data | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key]
            }
        }

        return $data
    }
    catch {
        return [pscustomobject]$defaults
    }
}

function Write-Settings {
    param([Parameter(Mandatory = $true)][hashtable]$Settings)

    $json = $Settings | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($settingsPath, $json, [System.Text.Encoding]::UTF8)
}

function Get-LogFolderPath {
    return (Join-Path $scriptRoot 'Logs')
}

function New-RunLogPath {
    param([Parameter(Mandatory = $true)][string]$OperationName)

    $folder = Get-LogFolderPath
    if (-not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeName = ($OperationName -replace '[^a-zA-Z0-9\-]+', '-')
    return (Join-Path $folder ("{0}.{1}.log.txt" -f $safeName, $stamp))
}

function Convert-RecordToLogLine {
    param([Parameter(Mandatory = $true)][object]$Record)

    if ($Record -is [System.Management.Automation.ErrorRecord]) {
        return ("ERROR: {0}" -f $Record.ToString())
    }

    if ($Record -is [System.Management.Automation.InformationRecord]) {
        return ("INFO: {0}" -f $Record.MessageData)
    }

    if ($Record -is [System.Management.Automation.WarningRecord]) {
        return ("WARNING: {0}" -f $Record.Message)
    }

    if ($Record -is [System.Management.Automation.VerboseRecord]) {
        return ("VERBOSE: {0}" -f $Record.Message)
    }

    if ($Record -is [System.Management.Automation.DebugRecord]) {
        return ("DEBUG: {0}" -f $Record.Message)
    }

    return [string]$Record
}

function Write-RunLog {
    param(
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)][string]$OperationName,
        [Parameter(Mandatory = $true)][hashtable]$OperationParameters,
        [Parameter(Mandatory = $false)][object[]]$OutputRecords,
        [Parameter(Mandatory = $false)][string]$ErrorMessage
    )

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine(("Timestamp: {0}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')))
    [void]$sb.AppendLine(("Operation: {0}" -f $OperationName))
    [void]$sb.AppendLine('Parameters:')

    foreach ($k in ($OperationParameters.Keys | Sort-Object)) {
        [void]$sb.AppendLine(("  {0} = {1}" -f $k, $OperationParameters[$k]))
    }

    if ($ErrorMessage) {
        [void]$sb.AppendLine('Result: FAILED')
        [void]$sb.AppendLine(("Error: {0}" -f $ErrorMessage))
    }
    else {
        [void]$sb.AppendLine('Result: SUCCESS')
    }

    [void]$sb.AppendLine('Output:')
    if ($OutputRecords -and $OutputRecords.Count -gt 0) {
        foreach ($record in $OutputRecords) {
            [void]$sb.AppendLine((Convert-RecordToLogLine -Record $record))
        }
    }
    else {
        [void]$sb.AppendLine('(no output)')
    }

    [System.IO.File]::WriteAllText($LogPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
}

function Show-LogDialog {
    param([Parameter(Mandatory = $true)][string]$LogPath)

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        [System.Windows.MessageBox]::Show('No log file found yet. Run Zip or Unzip first.', 'Log Output', 'OK', 'Information') | Out-Null
        return
    }

    $logText = Get-Content -LiteralPath $LogPath -Raw

    [xml]$dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Log Output"
        Width="900"
        Height="620"
        WindowStartupLocation="CenterOwner"
        Background="#FFFFFF"
        FontFamily="Consolas">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <TextBox x:Name="LogTextBox" Grid.Row="0" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" />
        <DockPanel Grid.Row="1" Margin="0,10,0,0">
            <TextBlock x:Name="LogPathText" VerticalAlignment="Center" Foreground="#52606D" TextTrimming="CharacterEllipsis" />
            <StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
                <Button x:Name="OpenLogFolderButton" Content="Open Log Folder" Margin="0,0,8,0" Padding="10,4" />
                <Button x:Name="CloseLogButton" Content="Close" Padding="10,4" />
            </StackPanel>
        </DockPanel>
    </Grid>
</Window>
"@

    $dialogReader = New-Object System.Xml.XmlNodeReader $dialogXaml
    $logWindow = [Windows.Markup.XamlReader]::Load($dialogReader)
    $logWindow.Owner = $window

    $logTextBox = $logWindow.FindName('LogTextBox')
    $logPathText = $logWindow.FindName('LogPathText')
    $openLogFolderButton = $logWindow.FindName('OpenLogFolderButton')
    $closeLogButton = $logWindow.FindName('CloseLogButton')

    $logTextBox.Text = $logText
    $logPathText.Text = $LogPath

    $openLogFolderButton.Add_Click({
        $dir = [System.IO.Path]::GetDirectoryName($LogPath)
        if (Test-Path -LiteralPath $dir) {
            Invoke-Item -LiteralPath $dir
        }
    })

    $closeLogButton.Add_Click({ $logWindow.Close() })

    $null = $logWindow.ShowDialog()
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Compress Safe Zip"
        Width="1060"
        Height="760"
        WindowStartupLocation="CenterScreen"
        Background="#F5F8FC"
        FontFamily="Segoe UI">
    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <Border Background="White" BorderBrush="#D7E0E8" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
            <StackPanel>
                <TextBlock Text="Compress Safe Zip" FontSize="22" FontWeight="Bold" Foreground="#12344D" />
                <TextBlock Margin="0,6,0,0" TextWrapping="Wrap" Foreground="#52606D">
                    Create safe archives and run the inverse operation (unzip and restore script extensions).
                </TextBlock>
            </StackPanel>
        </Border>

        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <StackPanel>
                <Border Background="White" BorderBrush="#D7E0E8" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
                    <StackPanel>
                        <TextBlock Text="Create Safe Zip" FontSize="16" FontWeight="Bold" Foreground="#12344D" Margin="0,0,0,10" />

                        <TextBlock Text="Source folder" FontWeight="Bold" Margin="0,0,0,4" />
                        <DockPanel Margin="0,0,0,10">
                            <Button x:Name="BrowseSourceButton" Content="Browse..." Width="90" DockPanel.Dock="Right" Margin="8,0,0,0" ToolTip="Pick the folder to compress into a safe zip archive." />
                            <TextBox x:Name="SourcePathTextBox" ToolTip="Folder to compress. Files with .ps1/.cmd/.vbs/.vmbs are archived as .txt-suffixed names." />
                        </DockPanel>

                        <TextBlock Text="Output zip" FontWeight="Bold" Margin="0,0,0,4" />
                        <DockPanel Margin="0,0,0,10">
                            <Button x:Name="AutoNameButton" Content="Auto Name" Width="90" DockPanel.Dock="Right" Margin="8,0,0,0" ToolTip="Generate a timestamped safe zip path from Source folder. Overwrites the Output zip field." />
                            <Button x:Name="BrowseOutputButton" Content="Browse..." Width="90" DockPanel.Dock="Right" Margin="8,0,0,0" ToolTip="Choose where the safe zip file should be written." />
                            <TextBox x:Name="OutputPathTextBox" ToolTip="Destination zip file path for Create Safe Zip." />
                        </DockPanel>

                        <DockPanel>
                            <Button x:Name="RunZipButton" Content="Create Safe Zip" Padding="14,6" DockPanel.Dock="Left" Background="#0A66C2" Foreground="White" ToolTip="Run forward operation: compress folder and append .txt to script extensions in archive." />
                            <CheckBox x:Name="RecurseCheckBox" Content="Include subfolders (Recurse)" Margin="12,6,0,0" ToolTip="When checked, include files from all subfolders." />
                            <CheckBox x:Name="OpenOutputFolderCheckBox" Content="Open output folder after success" Margin="14,6,0,0" ToolTip="Open the folder containing the created zip after completion." />
                        </DockPanel>
                    </StackPanel>
                </Border>

                <Border Background="White" BorderBrush="#D7E0E8" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
                    <StackPanel>
                        <TextBlock Text="Unzip and Restore (Inverse Operation)" FontSize="16" FontWeight="Bold" Foreground="#12344D" Margin="0,0,0,10" />

                        <TextBlock Text="Input safe zip" FontWeight="Bold" Margin="0,0,0,4" />
                        <DockPanel Margin="0,0,0,10">
                            <Button x:Name="BrowseUnzipZipButton" Content="Browse..." Width="90" DockPanel.Dock="Right" Margin="8,0,0,0" ToolTip="Select the safe zip archive to restore." />
                            <TextBox x:Name="UnzipZipPathTextBox" ToolTip="Path to the input safe zip file for inverse restore operation." />
                        </DockPanel>

                        <TextBlock Text="Destination folder" FontWeight="Bold" Margin="0,0,0,4" />
                        <DockPanel Margin="0,0,0,10">
                            <Button x:Name="AutoUnzipDestButton" Content="Auto Name" Width="90" DockPanel.Dock="Right" Margin="8,0,0,0" ToolTip="Generate a timestamped restore folder from Input safe zip. Overwrites Destination folder field." />
                            <Button x:Name="BrowseUnzipDestButton" Content="Browse..." Width="90" DockPanel.Dock="Right" Margin="8,0,0,0" ToolTip="Choose destination folder for extracted/restored files." />
                            <TextBox x:Name="UnzipDestinationPathTextBox" ToolTip="Folder where archive contents will be extracted and script extensions restored." />
                        </DockPanel>

                        <DockPanel>
                            <Button x:Name="RunUnzipButton" Content="Unzip and Restore" Padding="14,6" DockPanel.Dock="Left" Background="#2D7D46" Foreground="White" ToolTip="Run inverse operation: unzip and restore .ps1/.cmd/.vbs/.vmbs from .txt-suffixed names." />
                            <CheckBox x:Name="OpenUnzipFolderCheckBox" Content="Open destination folder after success" Margin="14,6,0,0" ToolTip="Open the restored destination folder after successful unzip/restore." />
                        </DockPanel>
                    </StackPanel>
                </Border>

                <Border Background="White" BorderBrush="#D7E0E8" BorderThickness="1" CornerRadius="10" Padding="12">
                    <DockPanel>
                        <CheckBox x:Name="WhatIfCheckBox" Content="WhatIf (preview only, no file changes)" Margin="0,0,18,0" DockPanel.Dock="Left" ToolTip="Preview actions for both Zip and Unzip operations without creating, deleting, or extracting files." />
                        <Button x:Name="ShowLogButton" Content="Log Output" DockPanel.Dock="Right" Padding="10,4" ToolTip="Open a dialog showing the most recent zip/unzip run log." />
                        <TextBlock x:Name="StatusTextBlock" VerticalAlignment="Center" Foreground="#52606D" TextWrapping="Wrap" />
                    </DockPanel>
                </Border>
            </StackPanel>
        </ScrollViewer>

        <TextBlock Grid.Row="2" Margin="0,10,0,0" Foreground="#6B7785" TextWrapping="Wrap">
            Safe script extension mapping: .ps1/.cmd/.vbs/.vmbs &lt;-&gt; .ps1.txt/.cmd.txt/.vbs.txt/.vmbs.txt
        </TextBlock>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$SourcePathTextBox = $window.FindName('SourcePathTextBox')
$OutputPathTextBox = $window.FindName('OutputPathTextBox')
$BrowseSourceButton = $window.FindName('BrowseSourceButton')
$BrowseOutputButton = $window.FindName('BrowseOutputButton')
$AutoNameButton = $window.FindName('AutoNameButton')
$RecurseCheckBox = $window.FindName('RecurseCheckBox')
$OpenOutputFolderCheckBox = $window.FindName('OpenOutputFolderCheckBox')
$RunZipButton = $window.FindName('RunZipButton')

$UnzipZipPathTextBox = $window.FindName('UnzipZipPathTextBox')
$UnzipDestinationPathTextBox = $window.FindName('UnzipDestinationPathTextBox')
$BrowseUnzipZipButton = $window.FindName('BrowseUnzipZipButton')
$BrowseUnzipDestButton = $window.FindName('BrowseUnzipDestButton')
$AutoUnzipDestButton = $window.FindName('AutoUnzipDestButton')
$OpenUnzipFolderCheckBox = $window.FindName('OpenUnzipFolderCheckBox')
$RunUnzipButton = $window.FindName('RunUnzipButton')

$WhatIfCheckBox = $window.FindName('WhatIfCheckBox')
$ShowLogButton = $window.FindName('ShowLogButton')
$StatusTextBlock = $window.FindName('StatusTextBlock')

$script:AppSettings = Read-Settings
$script:LastLogPath = ''

function Get-UiSettings {
    $windowLeft = $window.Left
    $windowTop = $window.Top
    $windowWidth = $window.Width
    $windowHeight = $window.Height

    if ($window.WindowState -ne [System.Windows.WindowState]::Normal) {
        $bounds = $window.RestoreBounds
        if ($bounds.Width -gt 0 -and $bounds.Height -gt 0) {
            $windowLeft = $bounds.Left
            $windowTop = $bounds.Top
            $windowWidth = $bounds.Width
            $windowHeight = $bounds.Height
        }
    }

    return @{
        SourcePath = [string]$SourcePathTextBox.Text
        OutputZipPath = [string]$OutputPathTextBox.Text
        Recurse = [bool]$RecurseCheckBox.IsChecked
        OpenOutputFolder = [bool]$OpenOutputFolderCheckBox.IsChecked

        UnzipZipPath = [string]$UnzipZipPathTextBox.Text
        UnzipDestinationPath = [string]$UnzipDestinationPathTextBox.Text
        OpenUnzipFolder = [bool]$OpenUnzipFolderCheckBox.IsChecked

        WhatIf = [bool]$WhatIfCheckBox.IsChecked

        LastLogPath = [string]$script:LastLogPath

        WindowLeft = $windowLeft
        WindowTop = $windowTop
        WindowWidth = $windowWidth
        WindowHeight = $windowHeight
    }
}

function Save-UiSettings {
    try {
        Write-Settings -Settings (Get-UiSettings)
    }
    catch {
        # Non-fatal.
    }
}

function Set-SettingsToUi {
    param([Parameter(Mandatory = $true)]$Settings)

    $SourcePathTextBox.Text = [string]$Settings.SourcePath
    $OutputPathTextBox.Text = [string]$Settings.OutputZipPath
    $RecurseCheckBox.IsChecked = [bool]$Settings.Recurse
    $OpenOutputFolderCheckBox.IsChecked = [bool]$Settings.OpenOutputFolder

    $UnzipZipPathTextBox.Text = [string]$Settings.UnzipZipPath
    $UnzipDestinationPathTextBox.Text = [string]$Settings.UnzipDestinationPath
    $OpenUnzipFolderCheckBox.IsChecked = [bool]$Settings.OpenUnzipFolder

    $WhatIfCheckBox.IsChecked = [bool]$Settings.WhatIf

    $script:LastLogPath = [string]$Settings.LastLogPath
}

function Set-WindowSettings {
    param([Parameter(Mandatory = $true)]$Settings)

    $width = 0.0
    $height = 0.0
    $left = 0.0
    $top = 0.0

    $hasWidth = [double]::TryParse([string]$Settings.WindowWidth, [ref]$width) -and $width -gt 300
    $hasHeight = [double]::TryParse([string]$Settings.WindowHeight, [ref]$height) -and $height -gt 300
    $hasLeft = [double]::TryParse([string]$Settings.WindowLeft, [ref]$left)
    $hasTop = [double]::TryParse([string]$Settings.WindowTop, [ref]$top)

    if ($hasWidth) {
        $window.Width = $width
    }
    if ($hasHeight) {
        $window.Height = $height
    }
    if ($hasLeft -and $hasTop) {
        $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
        $window.Left = $left
        $window.Top = $top
    }
}

$BrowseSourceButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select folder to archive'
    $dialog.ShowNewFolderButton = $false
    if (-not [string]::IsNullOrWhiteSpace($SourcePathTextBox.Text) -and (Test-Path -LiteralPath $SourcePathTextBox.Text)) {
        $dialog.SelectedPath = $SourcePathTextBox.Text
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $SourcePathTextBox.Text = $dialog.SelectedPath
        if ([string]::IsNullOrWhiteSpace($OutputPathTextBox.Text)) {
            $OutputPathTextBox.Text = Get-DefaultZipPath -SourcePath $dialog.SelectedPath
        }
        Save-UiSettings
    }
})

$BrowseOutputButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = 'Zip files (*.zip)|*.zip|All files (*.*)|*.*'
    $dialog.DefaultExt = '.zip'
    $dialog.AddExtension = $true
    if (-not [string]::IsNullOrWhiteSpace($OutputPathTextBox.Text)) {
        $dialog.FileName = [System.IO.Path]::GetFileName($OutputPathTextBox.Text)
        $outDir = [System.IO.Path]::GetDirectoryName($OutputPathTextBox.Text)
        if (-not [string]::IsNullOrWhiteSpace($outDir) -and (Test-Path -LiteralPath $outDir)) {
            $dialog.InitialDirectory = $outDir
        }
    }

    if ($dialog.ShowDialog() -eq $true) {
        $OutputPathTextBox.Text = $dialog.FileName
        Save-UiSettings
    }
})

$AutoNameButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($SourcePathTextBox.Text)) {
        $StatusTextBlock.Text = 'Enter a source folder first.'
        return
    }

    try {
        $OutputPathTextBox.Text = Get-DefaultZipPath -SourcePath $SourcePathTextBox.Text
        $StatusTextBlock.Text = 'Zip output path generated.'
        Save-UiSettings
    }
    catch {
        $StatusTextBlock.Text = $_.Exception.Message
    }
})

$BrowseUnzipZipButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = 'Zip files (*.zip)|*.zip|All files (*.*)|*.*'
    $dialog.Multiselect = $false

    if (-not [string]::IsNullOrWhiteSpace($UnzipZipPathTextBox.Text)) {
        $dialog.FileName = $UnzipZipPathTextBox.Text
    }

    if ($dialog.ShowDialog() -eq $true) {
        $UnzipZipPathTextBox.Text = $dialog.FileName
        if ([string]::IsNullOrWhiteSpace($UnzipDestinationPathTextBox.Text)) {
            $UnzipDestinationPathTextBox.Text = Get-DefaultUnzipPath -ZipPath $dialog.FileName
        }
        Save-UiSettings
    }
})

$BrowseUnzipDestButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select destination folder'
    $dialog.ShowNewFolderButton = $true
    if (-not [string]::IsNullOrWhiteSpace($UnzipDestinationPathTextBox.Text) -and (Test-Path -LiteralPath $UnzipDestinationPathTextBox.Text)) {
        $dialog.SelectedPath = $UnzipDestinationPathTextBox.Text
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $UnzipDestinationPathTextBox.Text = $dialog.SelectedPath
        Save-UiSettings
    }
})

$AutoUnzipDestButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($UnzipZipPathTextBox.Text)) {
        $StatusTextBlock.Text = 'Enter an input zip first.'
        return
    }

    try {
        $UnzipDestinationPathTextBox.Text = Get-DefaultUnzipPath -ZipPath $UnzipZipPathTextBox.Text
        $StatusTextBlock.Text = 'Unzip destination path generated.'
        Save-UiSettings
    }
    catch {
        $StatusTextBlock.Text = $_.Exception.Message
    }
})

$RunZipButton.Add_Click({
    try {
        $source = [string]$SourcePathTextBox.Text
        $output = [string]$OutputPathTextBox.Text

        if ([string]::IsNullOrWhiteSpace($source)) {
            throw 'Source folder is required.'
        }

        $source = [System.IO.Path]::GetFullPath($source)
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            throw "Source folder not found: $source"
        }

        if ([string]::IsNullOrWhiteSpace($output)) {
            $output = Get-DefaultZipPath -SourcePath $source
            $OutputPathTextBox.Text = $output
        }

        $params = @{
            SourcePath = $source
            OutputZipPath = $output
            Confirm = $false
        }

        if ([bool]$RecurseCheckBox.IsChecked) {
            $params.Recurse = $true
        }

        if ([bool]$WhatIfCheckBox.IsChecked) {
            $params.WhatIf = $true
        }

        $logPath = New-RunLogPath -OperationName 'zip'
        $script:LastLogPath = $logPath

        Save-UiSettings
        $StatusTextBlock.Text = 'Running zip...'

        $records = @()
        try {
            $records = @(& $coreScript @params *>&1)
            Write-RunLog -LogPath $logPath -OperationName 'Create Safe Zip' -OperationParameters $params -OutputRecords $records
        }
        catch {
            Write-RunLog -LogPath $logPath -OperationName 'Create Safe Zip' -OperationParameters $params -OutputRecords $records -ErrorMessage $_.Exception.Message
            throw
        }

        if ([bool]$WhatIfCheckBox.IsChecked) {
            $StatusTextBlock.Text = "Zip WhatIf completed. Log: $logPath"
        }
        else {
            $StatusTextBlock.Text = "Created: $output | Log: $logPath"
            if ([bool]$OpenOutputFolderCheckBox.IsChecked) {
                $dir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($output))
                if (Test-Path -LiteralPath $dir) {
                    Invoke-Item -LiteralPath $dir
                }
            }
        }

        Save-UiSettings
    }
    catch {
        $StatusTextBlock.Text = 'Zip failed.'
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Compress Safe Zip', 'OK', 'Error') | Out-Null
    }
})

$RunUnzipButton.Add_Click({
    try {
        $zipPath = [string]$UnzipZipPathTextBox.Text
        $destPath = [string]$UnzipDestinationPathTextBox.Text

        if ([string]::IsNullOrWhiteSpace($zipPath)) {
            throw 'Input zip path is required.'
        }

        $zipPath = [System.IO.Path]::GetFullPath($zipPath)
        if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
            throw "Input zip file not found: $zipPath"
        }

        if ([string]::IsNullOrWhiteSpace($destPath)) {
            $destPath = Get-DefaultUnzipPath -ZipPath $zipPath
            $UnzipDestinationPathTextBox.Text = $destPath
        }

        $params = @{
            ZipPath = $zipPath
            DestinationPath = $destPath
            Confirm = $false
        }

        if ([bool]$WhatIfCheckBox.IsChecked) {
            $params.WhatIf = $true
        }

        $logPath = New-RunLogPath -OperationName 'unzip-restore'
        $script:LastLogPath = $logPath

        Save-UiSettings
        $StatusTextBlock.Text = 'Running unzip/restore...'

        $records = @()
        try {
            $records = @(& $coreScript @params *>&1)
            Write-RunLog -LogPath $logPath -OperationName 'Unzip and Restore' -OperationParameters $params -OutputRecords $records
        }
        catch {
            Write-RunLog -LogPath $logPath -OperationName 'Unzip and Restore' -OperationParameters $params -OutputRecords $records -ErrorMessage $_.Exception.Message
            throw
        }

        if ([bool]$WhatIfCheckBox.IsChecked) {
            $StatusTextBlock.Text = "Unzip WhatIf completed. Log: $logPath"
        }
        else {
            $StatusTextBlock.Text = "Restored into: $destPath | Log: $logPath"
            if ([bool]$OpenUnzipFolderCheckBox.IsChecked) {
                $dir = [System.IO.Path]::GetFullPath($destPath)
                if (Test-Path -LiteralPath $dir) {
                    Invoke-Item -LiteralPath $dir
                }
            }
        }

        Save-UiSettings
    }
    catch {
        $StatusTextBlock.Text = 'Unzip failed.'
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Unzip and Restore', 'OK', 'Error') | Out-Null
    }
})

$ShowLogButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:LastLogPath)) {
        $StatusTextBlock.Text = 'No log captured yet. Run Zip or Unzip first.'
        return
    }

    Show-LogDialog -LogPath $script:LastLogPath
})

$window.Add_Closing({
    Save-UiSettings
})

$window.Add_ContentRendered({
    Set-WindowSettings -Settings $script:AppSettings
    Set-SettingsToUi -Settings $script:AppSettings

    if ([string]::IsNullOrWhiteSpace($SourcePathTextBox.Text)) {
        $SourcePathTextBox.Text = (Get-Location).Path
    }

    if ([string]::IsNullOrWhiteSpace($OutputPathTextBox.Text)) {
        try {
            $OutputPathTextBox.Text = Get-DefaultZipPath -SourcePath $SourcePathTextBox.Text
        }
        catch {
            # Ignore default path generation errors at startup.
        }
    }

    Save-UiSettings
})

$null = $window.ShowDialog()
