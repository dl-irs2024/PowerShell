#Requires -Version 5.1
<#
.SYNOPSIS
    Outlook Email Lookup Tool - WPF UI with Debug Panel
    
.DESCRIPTION
    Drag-and-drop WPF utility that accepts Outlook email files (.msg), email text, or pasted
    recipient lists. Extracts email addresses with real-time debug logging of drag-drop events.
    
.VERSION
    1.1.0 - With Debug Panel
#>

param(
    [switch]$Verbose = $false
)

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

# Global Variables
$script:AppPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:SettingsFile = Join-Path $AppPath 'LookupEmailList.Settings.json'
$script:ExtractedRecipients = @()
$script:ResolvedUsers = @()
$script:OutlookStatus = 'Unknown'

# Helper Functions
function Extract-EmailAddress {
    <#
    .SYNOPSIS
        Extracts email address from formats like "Display Name <email@domain>" or plain email
    
    .PARAMETER Address
        Address string in format "Name <email>" or plain "email@domain"
    
    .OUTPUTS
        [string] Just the email address portion
    #>
    param([string]$Address)
    
    if ($Address -match '<([^>]+)>') {
        # Extract from angle brackets
        return $matches[1]
    }
    
    # Return as-is if no angle brackets
    return $Address.Trim()
}

# Simulation Data Generator
function Get-SimulatedUser {
    param([string]$Email)
    
    $firstNames = @('John', 'Jane', 'Michael', 'Sarah', 'David', 'Emily', 'James', 'Jessica', 'Robert', 'Jennifer')
    $lastNames = @('Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez')
    $titles = @('Senior Analyst', 'Manager', 'Director', 'Coordinator', 'Specialist', 'Officer', 'Administrator', 'Consultant', 'Engineer', 'Advisor')
    $departments = @('Finance', 'HR', 'IT', 'Operations', 'Legal', 'Compliance', 'Tax', 'Audit', 'Policy', 'Administration')
    $locations = @('Washington DC', 'New York', 'Philadelphia', 'Boston', 'Atlanta', 'Chicago', 'Denver', 'San Francisco', 'Los Angeles', 'Miami')
    $states = @('DC', 'NY', 'PA', 'MA', 'GA', 'IL', 'CO', 'CA', 'FL', 'TX')
    $timeZones = @('Eastern', 'Central', 'Mountain', 'Pacific')
    
    $rand = New-Object System.Random
    $displayName = "$($firstNames[$rand.Next($firstNames.Count)]) $($lastNames[$rand.Next($lastNames.Count)])"
    $office = $locations[$rand.Next($locations.Count)]
    $state = $states[$rand.Next($states.Count)]
    
    return @{
        DisplayName = $displayName
        Email = $Email
        Title = $titles[$rand.Next($titles.Count)]
        Department = $departments[$rand.Next($departments.Count)]
        Office = $office
        StreetAddress = "$($rand.Next(100, 9999)) $(('ABCDEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray() | Get-Random -Count 3) -join '') Street"
        State = $state
        ZipCode = $rand.Next(10000, 99999).ToString()
        Phone = "(202) $($rand.Next(100, 999))-$($rand.Next(1000, 9999))"
        MobilePhone = "(202) $($rand.Next(200, 999))-$($rand.Next(1000, 9999))"
        TimeZone = $timeZones[$rand.Next($timeZones.Count)]
        Manager = "$(($firstNames | Get-Random)) $(($lastNames | Get-Random))"
        OutOfOfficeEnabled = [bool]($rand.Next(0, 2))
        Source = 'Simulated Data'
    }
}

# Settings Management
function Load-AppSettings {
    if (Test-Path $script:SettingsFile) {
        try {
            return Get-Content $script:SettingsFile -Raw | ConvertFrom-Json
        } catch {
            Write-Verbose "Error loading settings: $_"
        }
    }
    return @{
        Version = '1.0'
        Window = @{ Left = 100; Top = 100; Width = 1200; Height = 1000; State = 'Normal' }
        LookupHistory = @()
        LastLookup = $null
    }
}

function Save-AppSettings {
    param($Settings)
    try {
        $json = $Settings | ConvertTo-Json -Depth 10
        Set-Content -Path $script:SettingsFile -Value $json -Force -ErrorAction Stop
        Write-Verbose "Settings saved"
    } catch {
        Write-Warning "Error saving settings: $_"
    }
}

$appSettings = Load-AppSettings

# Add required assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# XAML with Debug Panel
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Outlook Email Lookup Tool"
        Width="1200" Height="1000"
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
                <TextBlock Text="Drag and Drop Email Files or Paste Email Text:" FontWeight="Bold" FontSize="16" Margin="0,0,0,10" />
                <TextBox x:Name="InputTextBox" Height="70" Padding="10" AllowDrop="True" TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto" Background="White" BorderBrush="#CCCCCC" BorderThickness="1"
                         Foreground="#333333" FontSize="14" Margin="0,0,0,10" 
                         ToolTip="Drag and drop .msg/.eml files or paste email addresses (one per line or comma-separated).&#10;Supported formats: 'user@domain.com' or 'First Last &lt;user@domain.com&gt;'" />
                <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                    <CheckBox x:Name="SimulationModeCheckBox" Content="Simulation Mode (Sample Data)" VerticalAlignment="Center" 
                              Foreground="#0078D4" FontSize="12" Margin="0,0,20,0" 
                              ToolTip="When checked: Lookup generates random realistic sample data instantly without querying GAL/Contacts/AD.&#10;When unchecked: Lookup searches Outlook GAL → Local Contacts → Active Directory.&#10;Use simulation mode for UI testing, demos, or when lookups are unavailable." />
                </StackPanel>
                <StackPanel Orientation="Horizontal">
                    <Button x:Name="LookupButton" Content="Lookup Addresses" Width="140" Height="40" Background="#0078D4" Foreground="White" FontWeight="Bold" FontSize="12" Margin="0,0,10,0" 
                            ToolTip="Resolve all extracted email addresses.&#10;If Simulation Mode is ON: Populates grid with sample data (instant).&#10;If Simulation Mode is OFF: Searches GAL → Contacts → Active Directory (may be slower)." />
                    <Button x:Name="ClearButton" Content="Clear" Width="100" Height="40" Background="#D3D3D3" Foreground="Black" FontSize="12" Margin="0,0,10,0" 
                            ToolTip="Clear input text box, results grid, and debug panel. Reset to initial state." />
                    <Button x:Name="ExportButton" Content="Export to CSV" Width="140" Height="40" Background="#107C10" Foreground="White" FontWeight="Bold" FontSize="12" Margin="0,0,10,0" 
                            ToolTip="Export all results from grid to CSV file. Results include all 14 properties (name, email, title, department, office, address, state, zip, phones, timezone, manager, OOO status, source)." />
                    <TextBlock x:Name="StatusMessage" Text="Ready" VerticalAlignment="Center" Foreground="#666666" FontSize="12" Margin="20,0,0,0" />
                </StackPanel>
            </StackPanel>
        </Border>
        
        <!-- Results DataGrid - Simplified to 3 columns -->
        <DataGrid Grid.Row="1" x:Name="ResultsGrid" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False"
                  GridLinesVisibility="All" BorderBrush="#CCCCCC" BorderThickness="1" RowBackground="White"
                  AlternatingRowBackground="#F9F9F9" HeadersVisibility="Column" Margin="5"
                  ToolTip="Simplified view: Display Name, ID (Email), and Time Zone only. Sortable by clicking headers.">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Display Name" Binding="{Binding DisplayName}" Width="200" />
                <DataGridTextColumn Header="ID (Email)" Binding="{Binding Email}" Width="250" />
                <DataGridTextColumn Header="Time Zone" Binding="{Binding TimeZone}" Width="120" />
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
                    <TextBlock x:Name="StatusText" Text="Ready" Foreground="#333333" FontSize="13" VerticalAlignment="Center" Margin="0,0,20,0" 
                               ToolTip="Current operation status: Ready, Extracting, Looking up, Searching AD, Found results, etc." />
                    <TextBlock x:Name="OutlookVersionText" Text="Outlook: Checking..." Foreground="#666666" FontSize="13" VerticalAlignment="Center" 
                               ToolTip="Outlook version installed (2013/2016/2019/365) or Not Installed. Used for GAL lookups." />
                </StackPanel>
                <TextBlock Grid.Column="1" x:Name="CountText" Text="0 / 0 results" Foreground="#666666" FontSize="13" VerticalAlignment="Center" 
                           ToolTip="Format: (Successful Lookups) / (Total Emails Dropped). Shows percentage of addresses resolved." />
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
                    <TextBlock Text="DEBUG: Drag-Drop Events and Payload" FontWeight="Bold" FontSize="14" Foreground="#00FF00" Margin="0,0,20,0" 
                               ToolTip="Real-time diagnostics for drag-drop detection, format parsing, email extraction, and lookup attempts. Shows exact payload details." />
                    <Button x:Name="ClearDebugButton" Content="Clear Debug" Width="100" Height="26" Background="#333333" Foreground="#00FF00" FontSize="11" Padding="5,2" 
                            ToolTip="Clear all debug messages. Useful for focusing on new tests." />
                </StackPanel>
                <TextBox Grid.Row="1" x:Name="DebugLog" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                         Background="#1E1E1E" Foreground="#00FF00" FontFamily="Courier New" FontSize="12" Padding="5" IsReadOnly="True" 
                         ToolTip="Debug output shows: DRAG events (formats available), DROP events (extraction steps), LOOKUP events (GAL/Contacts/ADSI attempts), and RESULT (success/failure with reason)." />
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

if (-not $window) {
    [System.Windows.MessageBox]::Show("Failed to create window", "Error", 'OK', 'Error')
    exit 1
}

# Get control references
try {
    $InputTextBox = $window.FindName('InputTextBox')
    $LookupButton = $window.FindName('LookupButton')
    $ClearButton = $window.FindName('ClearButton')
    $ExportButton = $window.FindName('ExportButton')
    $ResultsGrid = $window.FindName('ResultsGrid')
    $SimulationModeCheckBox = $window.FindName('SimulationModeCheckBox')
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

# Debug Helper Function
function Add-DebugMessage {
    param([string]$Message)
    try {
        $timestamp = Get-Date -Format 'HH:mm:ss.fff'
        $DebugLog.AppendText("[$timestamp] $Message`r`n")
        $DebugLog.ScrollToEnd()
    } catch {
        Write-Verbose "Debug log error: $_"
    }
}

# Window Initialization
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

# Drag-Drop Handlers
try {
    $InputTextBox.Add_PreviewDragOver({
        param($sender, $e)
        $mousePoint = $e.GetPosition($InputTextBox)
        $allFormats = $e.Data.GetFormats($false)
        Add-DebugMessage "DRAG: X=$([int]$mousePoint.X) Y=$([int]$mousePoint.Y) | Formats: $($allFormats -join ', ')"
        
        foreach ($format in $allFormats) {
            try {
                $data = $e.Data.GetData($format)
                if ($data) {
                    $dataType = $data.GetType().Name
                    Add-DebugMessage "  Format: $format | Type: $dataType"
                    if ($format -match 'Text|String') {
                        $preview = $data.ToString().Substring(0, [Math]::Min(80, $data.ToString().Length))
                        Add-DebugMessage "  Preview: $preview"
                    }
                }
            } catch {
                Add-DebugMessage "  Error reading format: $_"
            }
        }
        
        if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop) -or
            $e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::UnicodeText)) {
            $e.Effects = 'Copy'
            Add-DebugMessage "  [ACCEPT] Copy allowed"
        } else {
            $e.Effects = 'None'
            Add-DebugMessage "  [REJECT] No supported format"
        }
        $e.Handled = $true
    })

    $InputTextBox.Add_PreviewDrop({
        param($sender, $e)
        Add-DebugMessage "DROP: Processing payload..."
        $allFormats = $e.Data.GetFormats($false)
        
        $script:ExtractedRecipients = @()
        
        foreach ($format in $allFormats) {
            try {
                $data = $e.Data.GetData($format)
                if ($data) {
                    Add-DebugMessage "  Try format: $format"
                    
                    if ($format -eq [System.Windows.Forms.DataFormats]::FileDrop -or $format -match 'FileDrop') {
                        $files = $data
                        foreach ($file in $files) {
                            if ($file -match '\.(msg|eml)$') {
                                try {
                                    $recipients = Extract-RecipientsFromMsgFile $file
                                    $script:ExtractedRecipients += $recipients
                                    Add-DebugMessage "    [OK] Got $($recipients.Count) from file"
                                } catch {
                                    Add-DebugMessage "    [ERROR] $_"
                                }
                            }
                        }
                    } elseif ($format -match 'MsOffice.*Recipient' -or $format -eq 'MsOffice 8.0 Recipient') {
                        # Handle Outlook structured recipient object
                        try {
                            Add-DebugMessage "    [MsOffice Recipient] Attempting to parse structured recipient..."
                            if ($data -is [System.IO.Stream]) {
                                $reader = New-Object System.IO.StreamReader($data)
                                $recipientText = $reader.ReadToEnd()
                                $reader.Close()
                                Add-DebugMessage "      [Stream] Read: $recipientText"
                            } else {
                                $recipientText = $data.ToString()
                            }
                            
                            # Extract email from recipient text
                            $emailPattern = '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
                            $emailMatch = [regex]::Match($recipientText, $emailPattern)
                            
                            if ($emailMatch.Success) {
                                $script:ExtractedRecipients += @{
                                    Email = $emailMatch.Value
                                    DisplayName = $recipientText
                                    Type = 'MsOffice'
                                }
                                Add-DebugMessage "    [MsOffice] Got 1 from structured recipient"
                            } else {
                                Add-DebugMessage "    [MsOffice] No email found in recipient data"
                            }
                        } catch {
                            Add-DebugMessage "    [MsOffice ERROR] $_"
                        }
                    } elseif ($format -match 'Text|String|Unicode' -or $format -eq [System.Windows.Forms.DataFormats]::UnicodeText) {
                        $text = $data.ToString()
                        $InputTextBox.Text = $text
                        try {
                            # First try RFC 2822 headers (To:, Cc:, Bcc:)
                            $recipients = Extract-RecipientsFromRawEmail $text
                            
                            # If no RFC headers found, try plain email addresses
                            if ($recipients.Count -eq 0) {
                                Add-DebugMessage "    [RFC parse] No RFC headers found, trying plain email extraction..."
                                $emailPattern = '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
                                $matches = [regex]::Matches($text, $emailPattern)
                                
                                foreach ($match in $matches) {
                                    $recipients += @{
                                        Email = $match.Value
                                        DisplayName = $match.Value
                                        Type = 'Plain'
                                    }
                                }
                            }
                            
                            $script:ExtractedRecipients += $recipients
                            Add-DebugMessage "    [OK] Got $($recipients.Count) from text"
                        } catch {
                            Add-DebugMessage "    [ERROR] $_"
                        }
                    }
                }
            } catch {
                Add-DebugMessage "  Format error: $_"
            }
        }
        
        # Deduplicate all extracted recipients across all formats
        if ($script:ExtractedRecipients.Count -gt 0) {
            $uniqueRecipients = @()
            $emailsAdded = @{}
            foreach ($r in $script:ExtractedRecipients) {
                if (-not $emailsAdded.ContainsKey($r.Email)) {
                    $uniqueRecipients += $r
                    $emailsAdded[$r.Email] = $true
                }
            }
            $script:ExtractedRecipients = $uniqueRecipients
            
            $InputTextBox.Text = ($script:ExtractedRecipients | ForEach-Object { $_.Email }) -join ', '
            $StatusMessage.Text = "Extracted $($script:ExtractedRecipients.Count) recipients"
            Add-DebugMessage "DONE: $($script:ExtractedRecipients.Count) unique recipients (deduped)"
        }
        $e.Handled = $true
    })
} catch {
    Write-Error "Drag-drop error: $_"
}

# Button Handlers
try {
    $LookupButton.Add_Click({
        # If no extracted recipients from drag-drop, try to extract from text input
        if ($script:ExtractedRecipients.Count -eq 0) {
            $inputText = $InputTextBox.Text.Trim()
            if ([string]::IsNullOrEmpty($inputText)) {
                [System.Windows.MessageBox]::Show("Please paste or drag-drop email addresses first", "No Input", 'OK', 'Information')
                return
            }
            
            # Extract emails from pasted text using regex
            $emailPattern = '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
            $foundEmails = [regex]::Matches($inputText, $emailPattern) | ForEach-Object { $_.Value }
            
            if ($foundEmails.Count -eq 0) {
                [System.Windows.MessageBox]::Show("No valid email addresses found in text", "Parse Error", 'OK', 'Warning')
                return
            }
            
            # Populate ExtractedRecipients from text
            $script:ExtractedRecipients = @()
            foreach ($email in $foundEmails) {
                $script:ExtractedRecipients += @{ Email = $email }
            }
            Add-DebugMessage "Extracted $($script:ExtractedRecipients.Count) email(s) from pasted text"
        }
        
        $StatusMessage.Text = "Looking up..."
        $window.UpdateLayout()
        $script:ResolvedUsers = @()
        $success = 0
        $methodCounts = @{ 'Simulated' = 0; 'GAL' = 0; 'Contacts' = 0; 'ADSI' = 0 }
        
        foreach ($recipient in $script:ExtractedRecipients) {
            $emailToLookup = Extract-EmailAddress $recipient.Email
            $user = $null
            $methodUsed = $null
            
            if ($SimulationModeCheckBox.IsChecked) {
                Add-DebugMessage "[LOOKUP] SIMULATION MODE for: `"$emailToLookup`""
                Write-Host "[LOOKUP] Generating sample data..." -ForegroundColor Cyan
                $user = Get-SimulatedUser $emailToLookup
                $methodUsed = 'Simulated'
            } else {
                Add-DebugMessage "[LOOKUP] Starting real lookup chain for: `"$emailToLookup`""
                Write-Host "[LOOKUP] Method 1/3: Trying GAL (Outlook COM)..." -ForegroundColor Cyan
                
                # Try GAL
                $user = Resolve-UserViaGAL $emailToLookup
                if ($user) {
                    Add-DebugMessage "  [OK GAL] Found: $($user.DisplayName)"
                    Write-Host "  [OK] Found in GAL!" -ForegroundColor Green
                    $methodUsed = 'GAL'
                } else {
                    Add-DebugMessage "  [FAIL GAL] No match"
                    Write-Host "  [FAIL] Not in GAL, trying Contacts..." -ForegroundColor Yellow
                }
                
                # Try Contacts if GAL failed
                if (-not $user) {
                    Write-Host "[LOOKUP] Method 2/3: Trying Outlook Contacts..." -ForegroundColor Cyan
                    $user = Get-UserFromContacts $emailToLookup
                    if ($user) {
                        Add-DebugMessage "  [OK Contacts] Found: $($user.DisplayName)"
                        Write-Host "  [OK] Found in Contacts!" -ForegroundColor Green
                        $methodUsed = 'Contacts'
                    } else {
                        Add-DebugMessage "  [FAIL Contacts] No match"
                        Write-Host "  [FAIL] Not in Contacts, trying ADSI..." -ForegroundColor Yellow
                    }
                }
                
                # Try ADSI if Contacts failed
                if (-not $user) {
                    Write-Host "[LOOKUP] Method 3/3: Trying Active Directory (ADSI)..." -ForegroundColor Cyan
                    Add-DebugMessage "  [ADSI] Searching Active Directory..."
                    $user = Get-UserFromADSI $emailToLookup
                    if ($user) {
                        Add-DebugMessage "  [OK ADSI] Found: $($user.DisplayName)"
                        Write-Host "  [OK] Found in AD!" -ForegroundColor Green
                        $methodUsed = 'ADSI'
                    } else {
                        Add-DebugMessage "  [FAIL ADSI] No match (tried mail + UPN)"
                        Write-Host "  [FAIL] Not in AD either - email not found anywhere" -ForegroundColor Red
                    }
                }
            }
            
            # Final result
            if ($user) {
                if ($methodUsed) {
                    Add-DebugMessage "  [RESULT] SUCCESS - Method: $methodUsed"
                    if ($methodCounts.ContainsKey($methodUsed)) {
                        $methodCounts[$methodUsed]++
                    }
                }
                $script:ResolvedUsers += [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    Email = $user.Email
                    TimeZone = $user.TimeZone
                }
                $success++
            } else {
                Add-DebugMessage "  [RESULT] FAILED - No match found in any source (GAL/Contacts/ADSI)"
            }
        }
        
        $ResultsGrid.ItemsSource = $script:ResolvedUsers
        $CountText.Text = "$success / $($script:ExtractedRecipients.Count) results"
        
        # Build method summary for status bar
        $methodSummary = @()
        if ($methodCounts['Simulated'] -gt 0) { $methodSummary += "Simulated: $($methodCounts['Simulated'])" }
        if ($methodCounts['GAL'] -gt 0) { $methodSummary += "GAL: $($methodCounts['GAL'])" }
        if ($methodCounts['Contacts'] -gt 0) { $methodSummary += "Contacts: $($methodCounts['Contacts'])" }
        if ($methodCounts['ADSI'] -gt 0) { $methodSummary += "ADSI: $($methodCounts['ADSI'])" }
        
        $methodString = if ($methodSummary.Count -gt 0) { " [$($methodSummary -join ', ')]" } else { "" }
        $StatusMessage.Text = "Found $success of $($script:ExtractedRecipients.Count)$methodString"
        $appSettings.LastLookup = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Save-AppSettings $appSettings
    })

    $ClearButton.Add_Click({
        $InputTextBox.Text = ''
        $ResultsGrid.ItemsSource = @()
        $script:ExtractedRecipients = @()
        $script:ResolvedUsers = @()
        $StatusMessage.Text = 'Cleared'
        $CountText.Text = '0 / 0 results'
    })

    $ExportButton.Add_Click({
        if ($script:ResolvedUsers.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No results to export", "Info", 'OK', 'Information')
            return
        }
        
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $exportFile = Join-Path $script:AppPath "EmailLookup_Export_$timestamp.csv"
        
        try {
            $script:ResolvedUsers | Export-Csv -Path $exportFile -NoTypeInformation -Force
            [System.Windows.MessageBox]::Show("Exported to: $exportFile", "Success", 'OK', 'Information')
        } catch {
            [System.Windows.MessageBox]::Show("Export error: $_", "Error", 'OK', 'Error')
        }
    })

    $ClearDebugButton.Add_Click({
        $DebugLog.Clear()
        Add-DebugMessage "Debug cleared"
    })
} catch {
    Write-Error "Button handler error: $_"
}

# Window Events
try {
    $window.Add_Loaded({
        Add-DebugMessage "[INIT] Window loaded - Starting Outlook COM initialization..."
        Write-Host "[INIT] Testing Outlook COM..." -ForegroundColor Green
        try {
            Write-Verbose "[INIT] Attempting Outlook COM initialization..."
            Add-DebugMessage "[INIT] Testing Outlook COM connection..."
            
            $comAvailable = Initialize-OutlookConnection
            
            if ($comAvailable) {
                Write-Verbose "[INIT] Outlook COM connection successful!"
                Add-DebugMessage "[INIT] [OK] Outlook COM initialized successfully"
                
                $regCheck = Test-OutlookLegacyInstalled
                if ($regCheck.Installed) {
                    $status = "Outlook: $($regCheck.VersionName) (Ready for GAL lookup)"
                    Write-Host "[OK] Outlook COM Available: $status" -ForegroundColor Green
                } else {
                    $version = if ($script:OutlookApp) { $script:OutlookApp.Version } else { "unknown" }
                    $status = "Outlook: Available (v$version, registry check skipped)"
                }
                $OutlookVersionText.Text = $status
                Add-DebugMessage "[INIT] [OK] $status"
            } else {
                $status = "Outlook: Not available (using ADSI fallback)"
                Write-Host "[FAIL] Outlook COM unavailable - falling back to ADSI" -ForegroundColor Yellow
                Add-DebugMessage "[INIT] [FAIL] Outlook COM unavailable - $status"
                $OutlookVersionText.Text = $status
            }
        } catch {
            Write-Host "[FAIL] Outlook error: $_" -ForegroundColor Red
            Add-DebugMessage "[INIT] [FAIL] Outlook detection error: $_"
            $OutlookVersionText.Text = "Outlook: Error during check (using ADSI)"
        }
        Add-DebugMessage "[INIT] Ready for lookups. Paste email or drag from Outlook."
    })

    $window.Add_Closing({
        $appSettings.Window.Left = [int]$window.Left
        $appSettings.Window.Top = [int]$window.Top
        $appSettings.Window.Width = [int]$window.Width
        $appSettings.Window.Height = [int]$window.Height
        $appSettings.Window.State = $window.WindowState.ToString()
        Save-AppSettings $appSettings
        Cleanup-OutlookConnection
    })
} catch {
    Write-Error "Window event error: $_"
}

# Show window
$window.ShowDialog() | Out-Null
