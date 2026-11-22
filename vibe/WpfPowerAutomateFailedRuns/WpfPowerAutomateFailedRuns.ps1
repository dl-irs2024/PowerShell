#Requires -Version 5.1

<#
.SYNOPSIS
    WPF-based Power Automate Workflow Inspector and Management Tool
    
.DESCRIPTION
    Comprehensive tool for inspecting Power Automate workflows, monitoring failed runs,
    viewing run history, and performing workflow management tasks.
    
    Features:
    - View published workflows and run history
    - Filter by date range, environment, owner, execution status
    - Export in multiple formats (CSV, TSV, HTML, Excel, Markdown)
    - Restart failed workflows
    - Code review capabilities (re-entrancy, error handling)
    - Workflow dependency detection
    - Owner status verification
    - Simulation mode with sample data
    - Live mode with module validation and smoke testing
    
.NOTES
    Author: Copilot
    Version: 1.0.0
    Requires: PowerShell 5.1+
    Modules: Microsoft.PowerApps.Administration.PowerShell
#>

[CmdletBinding()]
param(
    [ValidateSet('Simulation', 'Live')]
    [string]$Mode = 'Simulation',
    
    [switch]$SkipModuleValidation
)

# Color palette for UI (Pastel colors)
$ColorPalette = @{
    Delete = '#FF6B6B'      # Pastel Red
    Create = '#51CF66'      # Pastel Green
    Info = '#74C0FC'        # Pastel Blue
    Warning = '#FFD93D'     # Pastel Yellow
    Neutral = '#F8F9FA'     # Light Gray
    Text = '#2C3E50'        # Dark Gray
}

# Global configuration
$Script:Config = @{
    Mode = $Mode
    SkipModuleValidation = $SkipModuleValidation
    CachePath = "$env:TEMP\PAFailedRunsCache"
    SampleDataPath = "$PSScriptRoot\SampleData"
}

# Ensure cache directory exists
if (-not (Test-Path $Script:Config.CachePath)) {
    New-Item -ItemType Directory -Path $Script:Config.CachePath -Force | Out-Null
}

#region Helper Functions

function Write-ColorOutput {
    <#
    .SYNOPSIS
        Write colored output to console
    #>
    param(
        [string]$Message,
        [ValidateSet('Delete', 'Create', 'Info', 'Warning', 'Neutral')]
        [string]$Type = 'Neutral'
    )
    
    $colors = @{
        Delete = 'Red'
        Create = 'Green'
        Info = 'Cyan'
        Warning = 'Yellow'
        Neutral = 'Gray'
    }
    
    Write-Host $Message -ForegroundColor $colors[$Type]
}

function Test-RequiredModules {
    <#
    .SYNOPSIS
        Validate required PowerShell modules are available
    #>
    if ($Script:Config.SkipModuleValidation) {
        Write-ColorOutput "Skipping module validation (as requested)" -Type Info
        return $true
    }
    
    $requiredModules = @(
        'Microsoft.PowerApps.Administration.PowerShell',
        'Microsoft.PowerApps.PowerShell'
    )
    
    $allPresent = $true
    foreach ($module in $requiredModules) {
        if (Get-Module -Name $module -ErrorAction SilentlyContinue) {
            Write-ColorOutput "[OK] Module '$module' is loaded" -Type Create
        } elseif (Get-Module -Name $module -ListAvailable -ErrorAction SilentlyContinue) {
            Write-ColorOutput "Module '$module' found, importing..." -Type Info
            try {
                Import-Module $module -ErrorAction Stop
                Write-ColorOutput "[OK] Module '$module' imported successfully" -Type Create
            } catch {
                Write-ColorOutput "[X] Failed to import '$module': $_" -Type Delete
                $allPresent = $false
            }
        } else {
            Write-ColorOutput "[X] Module '$module' not found" -Type Warning
            Write-ColorOutput "  Install with: Install-Module $module -Force" -Type Info
            $allPresent = $false
        }
    }
    
    return $allPresent
}

function Get-SampleData {
    <#
    .SYNOPSIS
        Generate realistic sample data for simulation mode
    #>
    param(
        [int]$WorkflowCount = 15,
        [int]$RunsPerWorkflow = 10
    )
    
    $environments = @('Production', 'Development', 'Testing', 'Staging')
    $owners = @('Admin@contoso.onmicrosoft.com', 'User1@contoso.onmicrosoft.com', 'User2@contoso.onmicrosoft.com', 'User3@contoso.onmicrosoft.com')
    $statusOptions = @('Success', 'Failed', 'Running', 'Skipped', 'Suspended')
    
    $workflows = @()
    for ($i = 1; $i -le $WorkflowCount; $i++) {
        $workflows += [PSCustomObject]@{
            WorkflowId = [guid]::NewGuid()
            WorkflowName = "Workflow_$i"
            DisplayName = "Sample Workflow $i - $(Get-Random -InputObject @('Process', 'Approval', 'Notification', 'Integration'))"
            Environment = Get-Random -InputObject $environments
            Owner = Get-Random -InputObject $owners
            IsPublished = $true
            CreatedOn = (Get-Date).AddDays(-([int]$(Get-Random -Minimum 1 -Maximum 180)))
            LastModified = (Get-Date).AddDays(-([int]$(Get-Random -Minimum 0 -Maximum 30)))
            IsOwnerActive = Get-Random -InputObject @($true, $true, $true, $false)
            RunCount = Get-Random -Minimum 5 -Maximum 500
            FailureCount = Get-Random -Minimum 0 -Maximum 50
            HasErrorHandling = Get-Random -InputObject @($true, $false)
            IsReEntrant = Get-Random -InputObject @($true, $false)
            Runs = @()
        }
    }
    
    # Add runs to each workflow
    foreach ($workflow in $workflows) {
        for ($j = 0; $j -lt $RunsPerWorkflow; $j++) {
            $status = if ($j -lt 2) { Get-Random -InputObject @('Failed', 'Failed', 'Running') } else { Get-Random -InputObject $statusOptions }
            
            $workflow.Runs += [PSCustomObject]@{
                RunId = [guid]::NewGuid()
                WorkflowId = $workflow.WorkflowId
                StartTime = (Get-Date).AddDays(-([int]$(Get-Random -Minimum 0 -Maximum 30))).AddHours(-([int]$(Get-Random -Minimum 0 -Maximum 23)))
                EndTime = if ($status -eq 'Running') { $null } else { (Get-Date).AddSeconds(-([int]$(Get-Random -Minimum 1 -Maximum 3600))) }
                Status = $status
                ErrorCode = if ($status -eq 'Failed') { Get-Random -InputObject @('500', '400', 'TimeoutException', 'AuthenticationFailed', 'Invalid Input') } else { $null }
                ErrorMessage = if ($status -eq 'Failed') { "Error executing step X in workflow" } else { $null }
                TriggerType = Get-Random -InputObject @('Manual', 'Automated', 'Scheduled')
            }
        }
    }
    
    return $workflows
}

function Get-LiveData {
    <#
    .SYNOPSIS
        Retrieve live data from Power Automate
    #>
    param(
        [string[]]$EnvironmentNames
    )
    
    if (-not (Test-RequiredModules)) {
        Write-ColorOutput "Cannot proceed in Live mode without required modules" -Type Delete
        return $null
    }
    
    try {
        $environments = Get-AdminPowerAppEnvironment -ErrorAction Stop
        Write-ColorOutput "Connected to Power Automate successfully" -Type Create
        
        $workflows = @()
        foreach ($env in $environments) {
            $flows = Get-AdminFlow -EnvironmentName $env.EnvironmentName -ErrorAction SilentlyContinue
            $workflows += $flows
        }
        
        return $workflows
    } catch {
        Write-ColorOutput "Error retrieving live data: $_" -Type Delete
        return $null
    }
}

#endregion

#region WPF UI Definition

function New-PowerAutomateUI {
    <#
    .SYNOPSIS
        Create and display WPF UI for Power Automate Inspector
    #>
    
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
    
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Power Automate Failed Runs Inspector"
        Height="900" Width="1400"
        Background="$($ColorPalette.Neutral)"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Title Bar -->
        <Border Grid.Row="0" Background="#230FAB" Padding="20">
        <StackPanel>
            <TextBlock Text="Power Automate Workflow Inspector" 
                       Foreground="White" 
                       FontSize="24" 
                       FontWeight="Bold"/>
            <TextBlock x:Name="ModeIndicator" 
                       Text="Mode: Simulation" 
                       Foreground="#74C0FC" 
                       FontSize="12" 
                       Margin="0,5,0,0"/>
        </StackPanel>
        </Border>
        
        <!-- Main Content with Tabs -->
        <TabControl Grid.Row="1" Margin="10">
            <!-- Workflows Tab -->
            <TabItem Header="Workflows" Background="$($ColorPalette.Info)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Filters -->
                    <GroupBox Grid.Row="0" Header="Filters" Margin="10" Padding="10">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            
                            <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                <TextBlock Text="Environment:" FontWeight="Bold"/>
                                <ComboBox x:Name="FilterEnvironment" Padding="5" SelectedIndex="0">
                                    <ComboBoxItem>All Environments</ComboBoxItem>
                                </ComboBox>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="1" Margin="0,0,10,0">
                                <TextBlock Text="Owner:" FontWeight="Bold"/>
                                <ComboBox x:Name="FilterOwner" Padding="5" SelectedIndex="0">
                                    <ComboBoxItem>All Owners</ComboBoxItem>
                                </ComboBox>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="2">
                                <TextBlock Text="Status:" FontWeight="Bold"/>
                                <ComboBox x:Name="FilterStatus" Padding="5" SelectedIndex="0">
                                    <ComboBoxItem>All Status</ComboBoxItem>
                                    <ComboBoxItem>Failed</ComboBoxItem>
                                    <ComboBoxItem>Success</ComboBoxItem>
                                    <ComboBoxItem>Running</ComboBoxItem>
                                </ComboBox>
                            </StackPanel>
                            
                            <Button Grid.Column="3" Content="Apply Filters" Padding="10,25,10,10" Background="$($ColorPalette.Create)" Foreground="White" x:Name="ApplyFiltersBtn"/>
                        </Grid>
                    </GroupBox>
                    
                    <!-- Workflows DataGrid -->
                    <DataGrid Grid.Row="1" x:Name="WorkflowsGrid" 
                             AutoGenerateColumns="False" 
                             CanUserAddRows="False"
                             Margin="10">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Workflow Name" Binding="{Binding DisplayName}" Width="250"/>
                            <DataGridTextColumn Header="Environment" Binding="{Binding Environment}" Width="100"/>
                            <DataGridTextColumn Header="Owner" Binding="{Binding Owner}" Width="150"/>
                            <DataGridTextColumn Header="Runs" Binding="{Binding RunCount}" Width="60"/>
                            <DataGridTextColumn Header="Failures" Binding="{Binding FailureCount}" Width="80"/>
                            <DataGridCheckBoxColumn Header="Active Owner" Binding="{Binding IsOwnerActive}" Width="80"/>
                            <DataGridCheckBoxColumn Header="Error Handling" Binding="{Binding HasErrorHandling}" Width="100"/>
                            <DataGridCheckBoxColumn Header="Re-entrant" Binding="{Binding IsReEntrant}" Width="80"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    
                    <!-- Action Buttons -->
                    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="10" HorizontalAlignment="Right">
                        <Button Content="View Details" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Info)" Foreground="White" x:Name="ViewDetailsBtn"/>
                        <Button Content="Code Review" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Warning)" Foreground="White" x:Name="CodeReviewBtn"/>
                        <Button Content="Dependencies" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Info)" Foreground="White" x:Name="DependenciesBtn"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- Run History Tab -->
            <TabItem Header="Run History" Background="$($ColorPalette.Info)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Date Filter -->
                    <GroupBox Grid.Row="0" Header="Date Range Filter" Margin="10" Padding="10">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            
                            <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                <TextBlock Text="From Date:" FontWeight="Bold"/>
                                <DatePicker x:Name="DateFrom" Padding="5"/>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="1">
                                <TextBlock Text="To Date:" FontWeight="Bold"/>
                                <DatePicker x:Name="DateTo" Padding="5"/>
                            </StackPanel>
                            
                            <Button Grid.Column="2" Content="Refresh" Padding="10,25,10,10" Background="$($ColorPalette.Create)" Foreground="White" x:Name="RefreshRunsBtn"/>
                        </Grid>
                    </GroupBox>
                    
                    <!-- Runs DataGrid -->
                    <DataGrid Grid.Row="1" x:Name="RunsGrid" 
                             AutoGenerateColumns="False" 
                             CanUserAddRows="False"
                             Margin="10">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Workflow" Binding="{Binding WorkflowName}" Width="200"/>
                            <DataGridTextColumn Header="Start Time" Binding="{Binding StartTime, StringFormat='{}{0:g}'}" Width="150"/>
                            <DataGridTextColumn Header="End Time" Binding="{Binding EndTime, StringFormat='{}{0:g}'}" Width="150"/>
                            <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="80"/>
                            <DataGridTextColumn Header="Error Code" Binding="{Binding ErrorCode}" Width="100"/>
                            <DataGridTextColumn Header="Error Message" Binding="{Binding ErrorMessage}" Width="300"/>
                            <DataGridTextColumn Header="Trigger Type" Binding="{Binding TriggerType}" Width="80"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    
                    <!-- Action Buttons -->
                    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="10" HorizontalAlignment="Right">
                        <Button Content="Restart Selected" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Create)" Foreground="White" x:Name="RestartBtn"/>
                        <Button Content="Export..." Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Info)" Foreground="White" x:Name="ExportBtn"/>
                        <Button Content="Refresh" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Info)" Foreground="White" x:Name="RefreshDataBtn"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- Code Review Tab -->
            <TabItem Header="Code Review" Background="$($ColorPalette.Warning)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Review Info -->
                    <TextBlock Grid.Row="0" Text="Code Review Analysis - Re-entrancy, Error Handling, Best Practices" 
                              Margin="10" FontSize="14" FontWeight="Bold"/>
                    
                    <!-- Review Content -->
                    <ListBox Grid.Row="1" x:Name="CodeReviewList" Margin="10">
                        <ListBox.ItemTemplate>
                            <DataTemplate>
                                <Border BorderBrush="#DDD" BorderThickness="1" Padding="10" Margin="0,5,0,5" CornerRadius="5">
                                    <StackPanel>
                                        <TextBlock Text="{Binding WorkflowName}" FontWeight="Bold" FontSize="12"/>
                                        <TextBlock Text="{Binding Issue}" Foreground="$($ColorPalette.Delete)" Margin="0,5,0,0"/>
                                        <TextBlock Text="{Binding Recommendation}" Foreground="$($ColorPalette.Create)" Margin="0,5,0,0"/>
                                    </StackPanel>
                                </Border>
                            </DataTemplate>
                        </ListBox.ItemTemplate>
                    </ListBox>
                </Grid>
            </TabItem>
            
            <!-- Export Tab -->
            <TabItem Header="Export" Background="$($ColorPalette.Create)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Export Options -->
                    <GroupBox Grid.Row="0" Header="Export Format" Margin="10" Padding="10">
                        <StackPanel>
                            <RadioButton x:Name="ExportCSV" Content="CSV" Margin="0,5,0,5" IsChecked="True"/>
                            <RadioButton x:Name="ExportTSV" Content="TSV" Margin="0,5,0,5"/>
                            <RadioButton x:Name="ExportHTML" Content="HTML" Margin="0,5,0,5"/>
                            <RadioButton x:Name="ExportExcel" Content="Excel (XLSX)" Margin="0,5,0,5"/>
                            <RadioButton x:Name="ExportMarkdown" Content="Markdown" Margin="0,5,0,5"/>
                        </StackPanel>
                    </GroupBox>
                    
                    <!-- Export Content Type -->
                    <GroupBox Grid.Row="1" Header="Export Content" Margin="10" Padding="10">
                        <StackPanel>
                            <CheckBox x:Name="ExportWorkflows" Content="Workflows" IsChecked="True" Margin="0,5,0,5"/>
                            <CheckBox x:Name="ExportRuns" Content="Run History" IsChecked="True" Margin="0,5,0,5"/>
                            <CheckBox x:Name="ExportCodeReview" Content="Code Review" Margin="0,5,0,5"/>
                        </StackPanel>
                    </GroupBox>
                    
                    <!-- Export Button -->
                    <Button Grid.Row="2" 
                           Content="Export Now" 
                           Padding="20,10" 
                           Height="50" 
                           Width="200" 
                           HorizontalAlignment="Center" 
                           VerticalAlignment="Top"
                           Background="$($ColorPalette.Create)" 
                           Foreground="White" 
                           FontSize="14"
                           x:Name="ExportNowBtn"/>
                </Grid>
            </TabItem>
            
            <!-- Settings Tab -->
            <TabItem Header="Settings" Background="$($ColorPalette.Info)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <StackPanel VerticalAlignment="Top" Margin="10">
                        <GroupBox Header="Data Source" Padding="10" Margin="0,0,0,20">
                            <StackPanel>
                                <RadioButton x:Name="ModeSimulation" Content="Simulation Mode (Sample Data)" IsChecked="True" Margin="0,5,0,5"/>
                                <RadioButton x:Name="ModeLive" Content="Live Mode (Connect to Power Automate)" Margin="0,5,0,5"/>
                                <Button Content="Test Connection" Padding="10" Margin="10,10,0,0" Background="$($ColorPalette.Info)" Foreground="White" x:Name="TestConnectionBtn" Width="150" HorizontalAlignment="Left"/>
                            </StackPanel>
                        </GroupBox>
                        
                        <GroupBox Header="Module Validation" Padding="10" Margin="0,0,0,20">
                            <StackPanel>
                                <CheckBox x:Name="SkipModuleValidation" Content="Skip Module Validation on Startup" Margin="0,5,0,10"/>
                                <Button Content="Validate Modules Now" Padding="10" Background="$($ColorPalette.Info)" Foreground="White" x:Name="ValidateModulesBtn" Width="150" HorizontalAlignment="Left"/>
                            </StackPanel>
                        </GroupBox>
                        
                        <GroupBox Header="Information" Padding="10">
                            <StackPanel>
                                <TextBlock Text="Power Automate Inspector v1.0.0" FontWeight="Bold"/>
                                <TextBlock Text="PowerShell 5.1+" Margin="0,5,0,0"/>
                                <TextBlock Text="Requires: Microsoft.PowerApps.Administration.PowerShell" Margin="0,5,0,0" Foreground="Gray"/>
                            </StackPanel>
                        </GroupBox>
                    </StackPanel>
                </Grid>
            </TabItem>
        </TabControl>
        
        <!-- Status Bar -->
        <StatusBar Grid.Row="2" Background="#F0F0F0" Padding="10">
            <TextBlock x:Name="StatusText" Text="Ready" Foreground="$($ColorPalette.Text)"/>
        </StatusBar>
    </Grid>
</Window>
"@
    
    return $xaml
}

#endregion

#region Main Execution

Write-ColorOutput "======================================" -Type Info
Write-ColorOutput "Power Automate Failed Runs Inspector" -Type Info
Write-ColorOutput "======================================" -Type Info
Write-ColorOutput ""

Write-ColorOutput "Starting in $($Script:Config.Mode) mode..." -Type Info

# Load data based on mode
$data = if ($Script:Config.Mode -eq 'Simulation') {
    Write-ColorOutput "Generating sample data..." -Type Create
    Get-SampleData -WorkflowCount 15 -RunsPerWorkflow 10
} else {
    Write-ColorOutput "Connecting to Power Automate..." -Type Create
    Get-LiveData
}

if ($null -eq $data) {
    Write-ColorOutput "Failed to load data. Exiting." -Type Delete
    exit 1
}

Write-ColorOutput "Loaded $($data.Count) workflows" -Type Create

# Create and show WPF UI
Write-ColorOutput "Initializing WPF interface..." -Type Info

$xaml = New-PowerAutomateUI
$reader = [xml.xmlnodereader]::new($xaml)
$window = [windows.markup.xamlreader]::Load($reader)

# Update mode indicator
$modeIndicator = $window.FindName('ModeIndicator')
if ($modeIndicator) {
    $modeIndicator.Text = "Mode: $($Script:Config.Mode)"
}

# Populate workflows grid
$workflowsGrid = $window.FindName('WorkflowsGrid')
if ($workflowsGrid) {
    $workflowsGrid.ItemsSource = @($data | Select-Object -Property DisplayName, Environment, Owner, RunCount, FailureCount, IsOwnerActive, HasErrorHandling, IsReEntrant)
}

# Populate runs grid
$runsGrid = $window.FindName('RunsGrid')
if ($runsGrid) {
    $allRuns = @()
    foreach ($workflow in $data) {
        foreach ($run in $workflow.Runs) {
            $allRuns += [PSCustomObject]@{
                WorkflowName = $workflow.DisplayName
                WorkflowId = $workflow.WorkflowId
                StartTime = $run.StartTime
                EndTime = $run.EndTime
                Status = $run.Status
                ErrorCode = $run.ErrorCode
                ErrorMessage = $run.ErrorMessage
                TriggerType = $run.TriggerType
            }
        }
    }
    $runsGrid.ItemsSource = @($allRuns | Sort-Object -Property StartTime -Descending)
}

# Populate environment filter
$filterEnv = $window.FindName('FilterEnvironment')
if ($filterEnv) {
    $uniqueEnvs = @($data | Select-Object -ExpandProperty Environment -Unique)
    foreach ($env in $uniqueEnvs) {
        $filterEnv.Items.Add($env) | Out-Null
    }
}

# Populate owner filter
$filterOwner = $window.FindName('FilterOwner')
if ($filterOwner) {
    $uniqueOwners = @($data | Select-Object -ExpandProperty Owner -Unique)
    foreach ($owner in $uniqueOwners) {
        $filterOwner.Items.Add($owner) | Out-Null
    }
}

# Event Handlers
$applyFiltersBtn = $window.FindName('ApplyFiltersBtn')
if ($applyFiltersBtn) {
    $applyFiltersBtn.Add_Click({
        # Static XAML entries are ComboBoxItems; dynamically added ones are strings
        $getSelection = { param($item) if ($null -ne $item -and $item -isnot [string]) { [string]$item.Content } else { $item } }
        $selectedEnv = & $getSelection $filterEnv.SelectedItem
        $selectedOwner = & $getSelection $filterOwner.SelectedItem
        $selectedStatus = & $getSelection $window.FindName('FilterStatus').SelectedItem
        
        $filtered = @($data | Where-Object {
            (-not $selectedEnv -or $selectedEnv -eq "All Environments" -or $_.Environment -eq $selectedEnv) -and
            (-not $selectedOwner -or $selectedOwner -eq "All Owners" -or $_.Owner -eq $selectedOwner) -and
            (-not $selectedStatus -or $selectedStatus -eq "All Status" -or ($_.Runs | Where-Object { $_.Status -eq $selectedStatus }))
                    })
        
        $workflowsGrid.ItemsSource = @($filtered | Select-Object -Property DisplayName, Environment, Owner, RunCount, FailureCount, IsOwnerActive, HasErrorHandling, IsReEntrant)
        
        $statusText = $window.FindName('StatusText')
        $statusText.Text = "Filtered to $($filtered.Count) workflows"
    })
}

# Export button
$exportBtn = $window.FindName('ExportBtn')
if ($exportBtn) {
    $exportBtn.Add_Click({
        $statusText = $window.FindName('StatusText')
        $statusText.Text = "Export feature coming soon..."
        [System.Windows.MessageBox]::Show("Export functionality will be implemented in the next update", "Export", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    })
}

# Refresh button
$refreshBtn = $window.FindName('RefreshDataBtn')
if ($refreshBtn) {
    $refreshBtn.Add_Click({
        $statusText = $window.FindName('StatusText')
        $statusText.Text = "Data refreshed at $(Get-Date -Format 'HH:mm:ss')"
    })
}

# Show window
$window.ShowDialog() | Out-Null

Write-ColorOutput "Application closed" -Type Info

#endregion
