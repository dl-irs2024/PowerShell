<#

.SYNOPSIS
WPF test harness for HtmlToc.WordToJson.ps1.
 
.DESCRIPTION
Provides a simple UI to test Word .docx conversion into HtmlToc JSON sections.

Run in Windows PowerShell 5.1.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null
Add-Type -AssemblyName System.Windows.Forms | Out-Null

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$converterScript = Join-Path $scriptRoot 'HtmlToc.WordToJson.ps1'
$settingsPath = Join-Path $scriptRoot 'HtmlToc.WordToJson.WpfTest.Settings.json'

if (-not (Test-Path -LiteralPath $converterScript)) {
    throw "HtmlToc.WordToJson.ps1 was not found next to this script: $converterScript"
}

function Get-AutoOutputPath {
    param([Parameter(Mandatory = $true)][string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return ''
    }

    $dir = [System.IO.Path]::GetDirectoryName($InputPath)
    $name = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    if ([string]::IsNullOrWhiteSpace($dir) -or [string]::IsNullOrWhiteSpace($name)) {
        return ''
    }

    return Join-Path $dir ("{0}.sections.json" -f $name)
}

function Append-Log {
    param([Parameter(Mandatory = $true)][string]$Message)

    $stamp = Get-Date -Format 'HH:mm:ss'
    $LogTextBox.AppendText("[$stamp] $Message`r`n")
    $LogTextBox.ScrollToEnd()
}

function Get-DefaultSettings {
    return [ordered]@{
        LastInputPath   = ''
        LastOutputPath  = ''
        DefaultTitle    = 'Introduction'
        DefaultLevel    = 1
        Force           = $true
        PassThru        = $false
        OpenOutput      = $true
    }
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

        $fromFile = ConvertFrom-Json -InputObject $raw
        foreach ($k in $defaults.Keys) {
            if ($null -eq $fromFile.PSObject.Properties[$k]) {
                $fromFile | Add-Member -NotePropertyName $k -NotePropertyValue $defaults[$k]
            }
        }

        return $fromFile
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

function Set-ComboByValue {
    param(
        [Parameter(Mandatory = $true)]$Combo,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $target = $Value.Trim().ToLowerInvariant()
    foreach ($item in $Combo.Items) {
        $content = ''
        if ($item -is [System.Windows.Controls.ComboBoxItem] -and $item.Content) {
            $content = [string]$item.Content
        }
        else {
            $content = [string]$item
        }

        if ($content.Trim().ToLowerInvariant() -eq $target) {
            $Combo.SelectedItem = $item
            return
        }
    }
}

function Get-ComboValue {
    param([Parameter(Mandatory = $true)]$Combo)

    $item = $Combo.SelectedItem
    if ($null -eq $item) { return '' }

    if ($item -is [System.Windows.Controls.ComboBoxItem] -and $item.Content) {
        return [string]$item.Content
    }
    return [string]$item
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HtmlToc WordToJson WPF Test"
        Height="620"
        Width="980"
        WindowStartupLocation="CenterScreen"
        Background="#F4F8FB"
        FontFamily="Segoe UI">
    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#FFFFFF" BorderBrush="#D7E0E8" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
            <StackPanel>
                <TextBlock Text="HtmlToc WordToJson Test Harness" FontSize="21" FontWeight="Bold" Foreground="#12344D" />
                <TextBlock Margin="0,6,0,0" TextWrapping="Wrap" Foreground="#52606D">
                    Select a Word .docx file, choose conversion options, then click Convert.
                </TextBlock>
            </StackPanel>
        </Border>

        <TextBlock Grid.Row="1" Text="Input .docx file" FontWeight="Bold" Margin="0,0,0,4" />
        <DockPanel Grid.Row="2" Margin="0,0,0,10">
            <TextBox x:Name="InputPathTextBox" Margin="0,0,8,0" />
            <Button x:Name="BrowseInputButton" Content="Browse..." Width="100" DockPanel.Dock="Right" />
        </DockPanel>

        <TextBlock Grid.Row="3" Text="Output JSON file" FontWeight="Bold" Margin="0,0,0,4" />
        <DockPanel Grid.Row="4" Margin="0,0,0,10">
            <TextBox x:Name="OutputPathTextBox" Margin="0,0,8,0" />
            <Button x:Name="AutoNameButton" Content="Auto Name" Width="100" Margin="0,0,8,0" DockPanel.Dock="Right" />
            <Button x:Name="BrowseOutputButton" Content="Browse..." Width="100" DockPanel.Dock="Right" />
        </DockPanel>

        <Grid Grid.Row="5" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="2*" />
                <ColumnDefinition Width="1*" />
                <ColumnDefinition Width="2*" />
            </Grid.ColumnDefinitions>

            <StackPanel Grid.Column="0" Margin="0,0,12,0">
                <TextBlock Text="Default section title (for content before first heading)" FontWeight="Bold" Margin="0,0,0,4" />
                <TextBox x:Name="DefaultTitleTextBox" Text="Introduction" />
            </StackPanel>

            <StackPanel Grid.Column="1" Margin="0,0,12,0">
                <TextBlock Text="Default level" FontWeight="Bold" Margin="0,0,0,4" />
                <ComboBox x:Name="DefaultLevelComboBox" SelectedIndex="0">
                    <ComboBoxItem Content="1" />
                    <ComboBoxItem Content="2" />
                    <ComboBoxItem Content="3" />
                    <ComboBoxItem Content="4" />
                    <ComboBoxItem Content="5" />
                    <ComboBoxItem Content="6" />
                </ComboBox>
            </StackPanel>

            <StackPanel Grid.Column="2">
                <CheckBox x:Name="ForceCheckBox" Content="Overwrite output if it exists (-Force)" IsChecked="True" Margin="0,0,0,6" />
                <CheckBox x:Name="PassThruCheckBox" Content="Return section objects (-PassThru)" IsChecked="False" Margin="0,0,0,6" />
                <CheckBox x:Name="OpenOutputCheckBox" Content="Open output file after conversion" IsChecked="True" Margin="0,0,0,6" />
            </StackPanel>
        </Grid>

        <GroupBox Grid.Row="6" Header="Run Log" Padding="8" Margin="0,0,0,10">
            <TextBox x:Name="LogTextBox"
                     IsReadOnly="True"
                     TextWrapping="Wrap"
                     AcceptsReturn="True"
                     VerticalScrollBarVisibility="Auto"
                     HorizontalScrollBarVisibility="Auto"
                     Background="#FCFDFF"
                     BorderBrush="#D7E0E8"
                     BorderThickness="1"
                     FontFamily="Consolas"
                     FontSize="12" />
        </GroupBox>

        <StackPanel Grid.Row="7" Orientation="Horizontal">
            <Button x:Name="ConvertButton" Content="Convert" Width="120" Padding="12,6" Margin="0,0,10,0" Background="#0A66C2" Foreground="White" />
            <Button x:Name="OpenOutputFolderButton" Content="Open Output Folder" Width="150" Padding="12,6" Margin="0,0,10,0" />
            <TextBlock x:Name="StatusTextBlock" VerticalAlignment="Center" Foreground="#52606D" />
        </StackPanel>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$InputPathTextBox = $window.FindName('InputPathTextBox')
$OutputPathTextBox = $window.FindName('OutputPathTextBox')
$BrowseInputButton = $window.FindName('BrowseInputButton')
$BrowseOutputButton = $window.FindName('BrowseOutputButton')
$AutoNameButton = $window.FindName('AutoNameButton')
$DefaultTitleTextBox = $window.FindName('DefaultTitleTextBox')
$DefaultLevelComboBox = $window.FindName('DefaultLevelComboBox')
$ForceCheckBox = $window.FindName('ForceCheckBox')
$PassThruCheckBox = $window.FindName('PassThruCheckBox')
$OpenOutputCheckBox = $window.FindName('OpenOutputCheckBox')
$LogTextBox = $window.FindName('LogTextBox')
$ConvertButton = $window.FindName('ConvertButton')
$OpenOutputFolderButton = $window.FindName('OpenOutputFolderButton')
$StatusTextBlock = $window.FindName('StatusTextBlock')

$script:AppSettings = Read-Settings

function Get-UiSettings {
    $levelText = Get-ComboValue -Combo $DefaultLevelComboBox
    $level = 1
    if (-not [string]::IsNullOrWhiteSpace($levelText)) {
        $parsed = 1
        if ([int]::TryParse($levelText, [ref]$parsed)) {
            $level = [Math]::Min([Math]::Max($parsed, 1), 6)
        }
    }

    return @{
        LastInputPath   = [string]$InputPathTextBox.Text
        LastOutputPath  = [string]$OutputPathTextBox.Text
        DefaultTitle    = [string]$DefaultTitleTextBox.Text
        DefaultLevel    = $level
        Force           = [bool]$ForceCheckBox.IsChecked
        PassThru        = [bool]$PassThruCheckBox.IsChecked
        OpenOutput      = [bool]$OpenOutputCheckBox.IsChecked
    }
}

function Save-UiSettings {
    try {
        Write-Settings -Settings (Get-UiSettings)
    }
    catch {
        # Non-fatal: settings persistence should not block conversion.
    }
}

function Apply-SettingsToUi {
    param([Parameter(Mandatory = $true)]$Settings)

    if (-not [string]::IsNullOrWhiteSpace([string]$Settings.LastInputPath)) {
        $InputPathTextBox.Text = [string]$Settings.LastInputPath
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Settings.LastOutputPath)) {
        $OutputPathTextBox.Text = [string]$Settings.LastOutputPath
    }

    $DefaultTitleTextBox.Text = [string]$Settings.DefaultTitle
    $ForceCheckBox.IsChecked = [bool]$Settings.Force
    $PassThruCheckBox.IsChecked = [bool]$Settings.PassThru
    $OpenOutputCheckBox.IsChecked = [bool]$Settings.OpenOutput

    $level = [string]([Math]::Min([Math]::Max([int]$Settings.DefaultLevel, 1), 6))
    Set-ComboByValue -Combo $DefaultLevelComboBox -Value $level
}

$BrowseInputButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select Word .docx file'
    $dialog.Filter = 'Word Documents (*.docx)|*.docx|All Files (*.*)|*.*'
    $dialog.CheckFileExists = $true
    $dialog.Multiselect = $false

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $InputPathTextBox.Text = $dialog.FileName
        if ([string]::IsNullOrWhiteSpace($OutputPathTextBox.Text)) {
            $OutputPathTextBox.Text = Get-AutoOutputPath -InputPath $dialog.FileName
        }
        Append-Log -Message ("Selected input: {0}" -f $dialog.FileName)
        Save-UiSettings
    }
})

$BrowseOutputButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = 'Choose output JSON file'
    $dialog.Filter = 'JSON Files (*.json)|*.json|All Files (*.*)|*.*'
    $dialog.OverwritePrompt = $false

    if (-not [string]::IsNullOrWhiteSpace($OutputPathTextBox.Text)) {
        try {
            $dialog.InitialDirectory = [System.IO.Path]::GetDirectoryName($OutputPathTextBox.Text)
            $dialog.FileName = [System.IO.Path]::GetFileName($OutputPathTextBox.Text)
        }
        catch {
            # Keep defaults if prefill fails.
        }
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $OutputPathTextBox.Text = $dialog.FileName
        Append-Log -Message ("Selected output: {0}" -f $dialog.FileName)
        Save-UiSettings
    }
})

$AutoNameButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($InputPathTextBox.Text)) {
        [System.Windows.MessageBox]::Show('Choose an input .docx file first.', 'Missing input', 'OK', 'Warning') | Out-Null
        return
    }

    $autoOutput = Get-AutoOutputPath -InputPath $InputPathTextBox.Text
    if (-not [string]::IsNullOrWhiteSpace($autoOutput)) {
        $OutputPathTextBox.Text = $autoOutput
        Append-Log -Message ("Auto output path: {0}" -f $autoOutput)
        Save-UiSettings
    }
})

$OpenOutputFolderButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($OutputPathTextBox.Text)) {
        [System.Windows.MessageBox]::Show('Output path is empty.', 'No output path', 'OK', 'Warning') | Out-Null
        return
    }

    $dir = [System.IO.Path]::GetDirectoryName($OutputPathTextBox.Text)
    if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path -LiteralPath $dir)) {
        Invoke-Item -LiteralPath $dir
    }
    else {
        [System.Windows.MessageBox]::Show('Output folder does not exist yet.', 'Folder not found', 'OK', 'Information') | Out-Null
    }
})

$ConvertButton.Add_Click({
    $inputPath = [string]$InputPathTextBox.Text
    $outputPath = [string]$OutputPathTextBox.Text
    $defaultTitle = [string]$DefaultTitleTextBox.Text

    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        [System.Windows.MessageBox]::Show('Input .docx file is required.', 'Missing input', 'OK', 'Warning') | Out-Null
        return
    }

    if (-not (Test-Path -LiteralPath $inputPath)) {
        [System.Windows.MessageBox]::Show('Input file does not exist.', 'Missing input', 'OK', 'Warning') | Out-Null
        return
    }

    if ([System.IO.Path]::GetExtension($inputPath).ToLowerInvariant() -ne '.docx') {
        [System.Windows.MessageBox]::Show('Input file must be a .docx document.', 'Invalid input', 'OK', 'Warning') | Out-Null
        return
    }

    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        $outputPath = Get-AutoOutputPath -InputPath $inputPath
        $OutputPathTextBox.Text = $outputPath
    }

    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        [System.Windows.MessageBox]::Show('Output JSON path is required.', 'Missing output', 'OK', 'Warning') | Out-Null
        return
    }

    if ([string]::IsNullOrWhiteSpace($defaultTitle)) {
        $defaultTitle = 'Introduction'
        $DefaultTitleTextBox.Text = $defaultTitle
    }

    $selectedLevelItem = $DefaultLevelComboBox.SelectedItem
    $defaultLevel = 1
    if ($selectedLevelItem -is [System.Windows.Controls.ComboBoxItem]) {
        $defaultLevel = [int][string]$selectedLevelItem.Content
    }
    elseif ($selectedLevelItem) {
        $defaultLevel = [int][string]$selectedLevelItem
    }

    $invokeParams = @{
        InputPath = $inputPath
        OutputPath = $outputPath
        DefaultTitle = $defaultTitle
        DefaultLevel = $defaultLevel
    }

    if ([bool]$ForceCheckBox.IsChecked) {
        $invokeParams.Force = $true
    }
    if ([bool]$PassThruCheckBox.IsChecked) {
        $invokeParams.PassThru = $true
    }

    $StatusTextBlock.Text = 'Converting...'
    Append-Log -Message ("Starting conversion: {0}" -f $inputPath)
    Save-UiSettings

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = & $converterScript @invokeParams
        $sw.Stop()

        if (-not (Test-Path -LiteralPath $outputPath)) {
            throw "Conversion completed but output file was not found: $outputPath"
        }

        $count = 0
        if ($null -ne $result) {
            $count = @($result).Count
        }
        elseif (Test-Path -LiteralPath $outputPath) {
            $jsonResult = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
            $count = @($jsonResult).Count
        }

        Append-Log -Message ("Completed in {0} ms. Sections: {1}" -f $sw.ElapsedMilliseconds, $count)
        Append-Log -Message ("Output: {0}" -f $outputPath)
        $StatusTextBlock.Text = ("Done ({0} sections)" -f $count)
        Save-UiSettings

        if ([bool]$OpenOutputCheckBox.IsChecked) {
            Invoke-Item -LiteralPath $outputPath
        }
    }
    catch {
        if ($sw.IsRunning) { $sw.Stop() }
        $StatusTextBlock.Text = 'Conversion failed.'
        Append-Log -Message ("Failed: {0}" -f $_.Exception.Message)
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Conversion failed', 'OK', 'Error') | Out-Null
    }
})

$window.Add_ContentRendered({
    Apply-SettingsToUi -Settings $script:AppSettings
    $StatusTextBlock.Text = 'Ready.'
    Append-Log -Message ("Using converter script: {0}" -f $converterScript)
    Append-Log -Message ("Settings file: {0}" -f $settingsPath)
    Save-UiSettings
})

$window.Add_Closing({
    Save-UiSettings
})

$null = $window.ShowDialog()
