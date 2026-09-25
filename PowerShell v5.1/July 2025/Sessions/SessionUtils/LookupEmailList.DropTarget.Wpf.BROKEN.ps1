#Requires -Version 5.1
<#
.SYNOPSIS
    Outlook Email Lookup Tool - WPF UI for extracting and resolving email recipient data.
    
.DESCRIPTION
    Drag-and-drop WPF utility that accepts Outlook email files (.msg), email text, or pasted
    recipient lists. Extracts email addresses and resolves user profiles via Outlook GAL
    with fallback to local Contacts and Active Directory.
    
.NOTES
    - Requires Outlook (optional; graceful fallback to ADSI if unavailable)
    - Drag-drop .msg files, .eml files, or paste email text
    - Click "Lookup" to resolve all addresses
    - Click "Export" to save results to CSV
    
.VERSION
    1.0.0
#>

param(
    [switch]$Verbose = $false
)

# Enable error handling
$ErrorActionPreference = 'Continue'
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

# Load module
$moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleFile = Join-Path $moduleDir 'EmailLookup.psm1'

if (-not (Test-Path $moduleFile)) {
    [System.Windows.MessageBox]::Show("EmailLookup.psm1 not found at: $moduleFile", "Error", 'OK', 'Error')
    exit 1
}

Import-Module $moduleFile -Force

# ============================================================================
# Global Variables
# ============================================================================

$script:AppPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:SettingsFile = Join-Path $AppPath 'LookupEmailList.Settings.json'
$script:ExtractedRecipients = @()
$script:ResolvedUsers = @()
$script:OutlookStatus = 'Unknown'

# ============================================================================
# Settings Management
# ============================================================================

function Load-AppSettings {
    if (Test-Path $script:SettingsFile) {
        try {
            $settings = Get-Content $script:SettingsFile -Raw | ConvertFrom-Json
            return $settings
        } catch {
            Write-Verbose "Error loading settings: $_"
        }
    }
    
    # Return defaults
    return @{
        Version = '1.0'
        Window = @{ Left = 100; Top = 100; Width = 1200; Height = 800; State = 'Normal' }
        LookupHistory = @()
        LastLookup = $null
    }
}

function Save-AppSettings {
    param($Settings)
    
    try {
        $json = $Settings | ConvertTo-Json -Depth 10
        Set-Content -Path $script:SettingsFile -Value $json -Force -ErrorAction Stop
        Write-Verbose "Settings saved to $script:SettingsFile"
    } catch {
        Write-Warning "Error saving settings: $_"
    }
}

# Load settings
$appSettings = Load-AppSettings

# ============================================================================
# WPF Window Setup
# ============================================================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# XAML UI Definition
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Outlook Email Lookup Tool"
        Width="1200" Height="800"
        Background="#F0F0F0"
        x:Name="MainWindow"
        WindowStartupLocation="Manual">
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="200" />
        </Grid.RowDefinitions>
        
        <!-- Input Section -->
        <Border Grid.Row="0" Background="White" Padding="15" BorderBrush="#CCCCCC" BorderThickness="0,0,0,1">
            <StackPanel Orientation="Vertical">
                <TextBlock Text="Drag &amp; Drop Email Files or Paste Email Text:" FontWeight="Bold" FontSize="12" Margin="0,0,0,10" />
                
                <TextBox x:Name="InputTextBox"
                         Height="60"
                         Padding="10"
                         AllowDrop="True"
                         TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto"
                         Background="White"
                         BorderBrush="#CCCCCC"
                         BorderThickness="1"
                         Foreground="#333333"
                         FontSize="11"
                         Margin="0,0,0,10" />
                
                <StackPanel Orientation="Horizontal">
                    <Button x:Name="LookupButton" Content="Lookup Addresses" Width="120" Height="32" Background="#0078D4" Foreground="White" FontWeight="Bold" Margin="0,0,10,0" />
                    <Button x:Name="ClearButton" Content="Clear" Width="80" Height="32" Background="#D3D3D3" Foreground="Black" Margin="0,0,10,0" />
                    <Button x:Name="ExportButton" Content="Export to CSV" Width="120" Height="32" Background="#107C10" Foreground="White" FontWeight="Bold" Margin="0,0,10,0" />
                    <TextBlock x:Name="StatusMessage" Text="Ready" VerticalAlignment="Center" Foreground="#666666" Margin="20,0,0,0" />
                </StackPanel>
            </StackPanel>
        </Border>
        
        <!-- Results DataGrid -->
        <DataGrid Grid.Row="1" x:Name="ResultsGrid"
                  AutoGenerateColumns="False"
                  CanUserAddRows="False"
                  CanUserDeleteRows="False"
                  GridLinesVisibility="All"
                  BorderBrush="#CCCCCC"
                  BorderThickness="1"
                  RowBackground="White"
                  AlternatingRowBackground="#F9F9F9"
                  HeadersVisibility="Column"
                  Margin="5">
            
            <DataGrid.Columns>
                <DataGridTextColumn Header="Display Name" Binding="{Binding DisplayName}" Width="150" />
                <DataGridTextColumn Header="Email" Binding="{Binding Email}" Width="200" />
                <DataGridTextColumn Header="Title" Binding="{Binding Title}" Width="120" />
                <DataGridTextColumn Header="Department" Binding="{Binding Department}" Width="120" />
                <DataGridTextColumn Header="Office" Binding="{Binding Office}" Width="100" />
                <DataGridTextColumn Header="Street Address" Binding="{Binding StreetAddress}" Width="120" />
                <DataGridTextColumn Header="State" Binding="{Binding State}" Width="60" />
                <DataGridTextColumn Header="Zip Code" Binding="{Binding ZipCode}" Width="80" />
                <DataGridTextColumn Header="Phone" Binding="{Binding Phone}" Width="110" />
                <DataGridTextColumn Header="Mobile Phone" Binding="{Binding MobilePhone}" Width="110" />
                <DataGridTextColumn Header="Time Zone" Binding="{Binding TimeZone}" Width="100" />
                <DataGridTextColumn Header="Manager" Binding="{Binding Manager}" Width="150" />
                <DataGridTextColumn Header="OOO" Binding="{Binding OutOfOfficeEnabled}" Width="60" />
                <DataGridTextColumn Header="Source" Binding="{Binding Source}" Width="100" />
            </DataGrid.Columns>
        </DataGrid>
        
        <!-- Status Bar -->
        <Border Grid.Row="2" Background="#E8E8E8" Padding="10" BorderBrush="#CCCCCC" BorderThickness="0,1,0,0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="Auto" />
                </Grid.ColumnDefinitions>
                
                <StackPanel Orientation="Horizontal" Grid.Column="0">
                    <TextBlock x:Name="StatusText" Text="Ready" Foreground="#333333" FontSize="11" VerticalAlignment="Center" Margin="0,0,20,0" />
                    <TextBlock x:Name="OutlookVersionText" Text="Outlook: Checking..." Foreground="#666666" FontSize="10" VerticalAlignment="Center" />
                </StackPanel>
                
                <TextBlock Grid.Column="1" x:Name="CountText" Text="0 / 0 results" Foreground="#666666" FontSize="10" VerticalAlignment="Center" />
            </Grid>
        </Border>

        <!-- Debug Panel -->
        <Border Grid.Row="3" Background="#1E1E1E" Padding="8" BorderBrush="#CCCCCC" BorderThickness="0,1,0,0">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto" />
                    <RowDefinition Height="*" />
                </Grid.RowDefinitions>
                
                <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,5">
                    <TextBlock Text="DEBUG: Drag-Drop Events &amp; Payload" FontWeight="Bold" FontSize="11" Foreground="#00FF00" Margin="0,0,20,0" />
                    <Button x:Name="ClearDebugButton" Content="Clear Debug" Width="80" Height="20" Background="#333333" Foreground="#00FF00" FontSize="9" Padding="5,2" />
                </StackPanel>
                
                <TextBox Grid.Row="1" x:Name="DebugLog"
                         TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto"
                         HorizontalScrollBarVisibility="Auto"
                         Background="#1E1E1E"
                         Foreground="#00FF00"
                         FontFamily="Courier New"
                         FontSize="9"
                         Padding="5"
                         IsReadOnly="True" />
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Load XAML
try {
    $reader = [System.Xml.XmlNodeReader]::new([System.Xml.XmlDocument]($xaml))
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    [System.Windows.MessageBox]::Show("Error parsing XAML: $_", "XAML Error", 'OK', 'Error')
    exit 1
}

# Verify window loaded
if (-not $window) {
    [System.Windows.MessageBox]::Show("Failed to create window from XAML", "Error", 'OK', 'Error')
    exit 1
}

# Get control references
try {
    $InputTextBox = $window.FindName('InputTextBox')
    $LookupButton = $window.FindName('LookupButton')
    $ClearButton = $window.FindName('ClearButton')
    $ExportButton = $window.FindName('ExportButton')
    $ResultsGrid = $window.FindName('ResultsGrid')
    $StatusText = $window.FindName('StatusText')
    $OutlookVersionText = $window.FindName('OutlookVersionText')
    $CountText = $window.FindName('CountText')
    $StatusMessage = $window.FindName('StatusMessage')
    $DebugLog = $window.FindName('DebugLog')
    $ClearDebugButton = $window.FindName('ClearDebugButton')
} catch {
    [System.Windows.MessageBox]::Show("Error finding controls: $_", "Error", 'OK', 'Error')
    exit 1
}

# ============================================================================
# Debug Helper Function
# ============================================================================

function Add-DebugMessage {
    param([string]$Message)
    try {
        $timestamp = Get-Date -Format 'HH:mm:ss.fff'
        $DebugLog.AppendText("[$timestamp] $Message`r`n")
        $DebugLog.ScrollToEnd()
    } catch {
        Write-Verbose "Error writing debug message: $_"
    }
}

# ============================================================================
# Window Initialization
# ============================================================================

# Restore window position from settings
try {
    $ws = $appSettings.Window
    if ($ws.Left -gt 0 -and $ws.Top -gt 0) {
        $maxLeft = [System.Windows.SystemParameters]::VirtualScreenWidth - 100
        $maxTop = [System.Windows.SystemParameters]::VirtualScreenHeight - 100
        $window.Left = [Math]::Max(0, [Math]::Min($ws.Left, $maxLeft))
        $window.Top = [Math]::Max(0, [Math]::Min($ws.Top, $maxTop))
    }
    if ($ws.Width -gt 200) { $window.Width = $ws.Width }
    if ($ws.Height -gt 200) { $window.Height = $ws.Height }
    if ($ws.State -eq 'Maximized') { $window.WindowState = 'Maximized' }
} catch {
    Write-Verbose "Could not restore window position: $_"
}

# ============================================================================
# Drag-Drop Handlers with Debug Logging
# ============================================================================

try {
    $InputTextBox.Add_PreviewDragOver({
        param($sender, $e)
        
        $mousePoint = $e.GetPosition($InputTextBox)
        $allFormats = $e.Data.GetFormats($false)
        
        Add-DebugMessage "DRAG OVER: X=$([int]$mousePoint.X) Y=$([int]$mousePoint.Y) | Formats: $($allFormats -join ', ')"
        
        # Log available format details
        foreach ($format in $allFormats) {
            try {
                $data = $e.Data.GetData($format)
                if ($data) {
                    $dataType = $data.GetType().Name
                    Add-DebugMessage "  Format: $format | Type: $dataType"
                    
                    if ($format -match 'Text|String|Unicode') {
                        $preview = $data.ToString()
                        $previewLen = [Math]::Min(100, $preview.Length)
                        $previewText = $preview.Substring(0, $previewLen)
                        Add-DebugMessage "  Content Preview: $previewText"
                    }
                }
            } catch {
                Add-DebugMessage "  Format: $format | Error reading: $($_.Exception.Message)"
            }
        }
        
        if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop) -or
            $e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::UnicodeText)) {
            $e.Effects = 'Copy'
            $e.Handled = $true
            Add-DebugMessage "  ✓ Accepted - Copy operation allowed"
        } else {
            $e.Effects = 'None'
            Add-DebugMessage "  ✗ Rejected - No UnicodeText/FileDrop format found"
        }
    })

    $InputTextBox.Add_PreviewDrop({
        param($sender, $e)
        
        Add-DebugMessage "DROP RECEIVED - Processing payload..."
        $allFormats = $e.Data.GetFormats($false)
        Add-DebugMessage "  Available formats: $($allFormats -join ', ')"
        
        $script:ExtractedRecipients = @()
        $extractedSomething = $false
        
        # Try all available formats
        foreach ($format in $allFormats) {
            try {
                $data = $e.Data.GetData($format)
                if ($data) {
                    Add-DebugMessage "  Attempting format: $format (Type: $($data.GetType().Name))"
                    
                    if ($format -eq [System.Windows.Forms.DataFormats]::FileDrop -or $format -match 'FileDrop') {
                        $files = $data
                        Add-DebugMessage "  Files detected: $($files.Count) file(s)"
                        foreach ($file in $files) {
                            Add-DebugMessage "    File: $file"
                            if ($file -match '\.(msg|eml)$') {
                                try {
                                    $recipients = Extract-RecipientsFromMsgFile $file
                                    $script:ExtractedRecipients += $recipients
                                    Add-DebugMessage "    ✓ Extracted $($recipients.Count) recipients from $file"
                                    $extractedSomething = $true
                                } catch {
                                    Add-DebugMessage "    ✗ Error extracting from $file : $_"
                                }
                            }
                        }
                    } elseif ($format -match 'Text|String|Unicode' -or $format -eq [System.Windows.Forms.DataFormats]::UnicodeText) {
                        $text = $data.ToString()
                        Add-DebugMessage "  Text detected - Length: $($text.Length) chars"
                        $previewLen = [Math]::Min(150, $text.Length)
                        $preview = $text.Substring(0, $previewLen)
                        Add-DebugMessage "  Content preview: $preview"
                        
                        try {
                            $InputTextBox.Text = $text
                            $recipients = Extract-RecipientsFromRawEmail $text
                            $script:ExtractedRecipients += $recipients
                            Add-DebugMessage "  ✓ Extracted $($recipients.Count) recipients from text"
                            $extractedSomething = $true
                        } catch {
                            Add-DebugMessage "  ✗ Error parsing text: $_"
                        }
                    }
                }
            } catch {
                Add-DebugMessage "  Format $format - Error: $($_.Exception.Message)"
            }
        }
        
        if ($extractedSomething) {
            Update-ExtractedRecipientsDisplay
            $StatusMessage.Text = "Extracted $($script:ExtractedRecipients.Count) recipients"
            Add-DebugMessage "FINAL: $($script:ExtractedRecipients.Count) total recipients extracted"
        } else {
            Add-DebugMessage "FINAL: No recipients could be extracted from any format"
        }
        
        $e.Handled = $true
    })
} catch {
    Write-Error "Error setting up drag-drop handlers: $_"
}

# ============================================================================
# Button Handlers
# ============================================================================

try {
    $LookupButton.Add_Click({
        if ($script:ExtractedRecipients.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No email addresses to look up. Drop files or paste text first.", "No Data", 'OK', 'Information')
            return
        }
        
        $StatusMessage.Text = "Looking up addresses..."
        $window.UpdateLayout()
        
        $script:ResolvedUsers = @()
        $successCount = 0
        
        foreach ($recipient in $script:ExtractedRecipients) {
            $email = $recipient.Email
            Write-Verbose "Looking up: $email"
            
            $user = Lookup-User $email
            
            if ($user) {
                $userObject = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    Email = $user.Email
                    Title = $user.Title
                    Department = $user.Department
                    Office = $user.Office
                    StreetAddress = $user.StreetAddress
                    State = $user.State
                    ZipCode = $user.ZipCode
                    Phone = $user.Phone
                    MobilePhone = $user.MobilePhone
                    TimeZone = $user.TimeZone
                    Manager = $user.Manager
                    OutOfOfficeEnabled = $user.OutOfOfficeEnabled
                    Source = $user.Source
                }
                
                $script:ResolvedUsers += $userObject
                $successCount++
            } else {
                # Add unresolved user placeholder
                $userObject = [PSCustomObject]@{
                    DisplayName = $email
                    Email = $email
                    Title = '[Not Found]'
                    Department = $null
                    Office = $null
                    StreetAddress = $null
                    State = $null
                    ZipCode = $null
                    Phone = $null
                    MobilePhone = $null
                    TimeZone = $null
                    Manager = $null
                    OutOfOfficeEnabled = $null
                    Source = 'Unresolved'
                }
                
                $script:ResolvedUsers += $userObject
            }
        }
        
        # Bind to DataGrid
        $ResultsGrid.ItemsSource = $script:ResolvedUsers
        
        $StatusMessage.Text = "Found $successCount of $($script:ExtractedRecipients.Count) results"
        $CountText.Text = "$successCount / $($script:ExtractedRecipients.Count) results"
        $StatusText.Text = "Lookup completed"
        
        # Save to history
        $appSettings.LastLookup = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Save-AppSettings $appSettings
    })

    $ClearButton.Add_Click({
        $InputTextBox.Text = ''
        $ResultsGrid.ItemsSource = @()
        $script:ExtractedRecipients = @()
        $script:ResolvedUsers = @()
        $StatusMessage.Text = 'Cleared'
        $StatusText.Text = 'Ready'
        $CountText.Text = '0 / 0 results'
    })

    $ExportButton.Add_Click({
        if ($script:ResolvedUsers.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No results to export. Run Lookup first.", "No Data", 'OK', 'Information')
            return
        }
        
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $exportFile = Join-Path $script:AppPath "EmailLookup_Export_$timestamp.csv"
        
        try {
            $script:ResolvedUsers | Export-Csv -Path $exportFile -NoTypeInformation -Force -ErrorAction Stop
            [System.Windows.MessageBox]::Show("Exported $($script:ResolvedUsers.Count) results to:`n`n$exportFile", "Export Successful", 'OK', 'Information')
            Write-Verbose "Exported to: $exportFile"
        } catch {
            [System.Windows.MessageBox]::Show("Error exporting: $_", "Export Failed", 'OK', 'Error')
        }
    })

    $ClearDebugButton.Add_Click({
        $DebugLog.Clear()
        Add-DebugMessage "Debug log cleared"
    })
} catch {
    Write-Error "Error setting up button handlers: $_"
}

# ============================================================================
# Helper Functions
# ============================================================================

function Update-ExtractedRecipientsDisplay {
    $uniqueEmails = $script:ExtractedRecipients | Select-Object -Property Email -Unique
    $emailList = @($uniqueEmails | ForEach-Object { $_.Email }) -join ', '
    
    if ($emailList.Length -gt 200) {
        $count = ($uniqueEmails | Measure-Object).Count
        $InputTextBox.Text = "$($emailList.Substring(0, 200))... (" + $count + " total)"
    } else {
        $InputTextBox.Text = $emailList
    }
}

function Update-OutlookStatus {
    try {
        $regCheck = Test-OutlookLegacyInstalled
        
        if ($regCheck.Installed) {
            $script:OutlookStatus = "Outlook $($regCheck.VersionName)"
        } else {
            $script:OutlookStatus = "Outlook not detected (using ADSI)"
        }
    } catch {
        $script:OutlookStatus = "Status check failed"
    }
    
    $OutlookVersionText.Text = "Outlook: $($script:OutlookStatus)"
}

# ============================================================================
# Window Events
# ============================================================================

try {
    $window.Add_Loaded({
        Write-Verbose "Window loaded"
        Update-OutlookStatus
        $StatusText.Text = 'Ready'
    })

    $window.Add_Closing({
        # Save window state
        $appSettings.Window.Left = [int]$window.Left
        $appSettings.Window.Top = [int]$window.Top
        $appSettings.Window.Width = [int]$window.Width
        $appSettings.Window.Height = [int]$window.Height
        $appSettings.Window.State = $window.WindowState.ToString()
        
        Save-AppSettings $appSettings
        
        # Cleanup
        Cleanup-OutlookConnection
        Write-Verbose "Application closing"
    })
} catch {
    Write-Error "Error setting up window event handlers: $_"
}

# ============================================================================
# Show Window
# ============================================================================

try {
    $window.ShowDialog() | Out-Null
} catch {
    Write-Error "Error displaying window: $_"
    [System.Windows.MessageBox]::Show("Error: $_", "Fatal Error", 'OK', 'Error')
}
