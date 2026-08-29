
# WpfFolderSizeBrowser.v3.ps1

# July 2026
# prior version July 2025
# WPF Folder Size Browser v3
# This script creates a WPF application using PowerShell to display folder sizes and allows navigation through folders.

<#
.SYNOPSIS
    WPF Folder Size Browser v3 - Displays folder sizes and allows navigation through folders.

.DESCRIPTION
    This script creates a WPF application using PowerShell to display folder sizes and allows navigation through folders.
    It includes features such as a progress dialog, wait cursor, sortable columns, and double-click navigation.
    
    Key Features:
    - Real-time folder size calculation with progress indication
    - Recursive and non-recursive folder size scanning options
    - Sortable columns with visual indicators
    - Navigation through folder hierarchy with Up button and double-click
    - Integration with Windows Explorer
    - Clipboard functionality for path copying
    - Responsive UI layout that adapts to window resizing

.PARAMETER None
    No parameters are required for this script.

.EXAMPLE
    Run the script directly in PowerShell:
        .\WpfFolderSizeBrowser.v2.ps1

.NOTES
    - Compatible with PowerShell 5.1 and .NET 6.0 or earlier.
    - Requires Windows Presentation Framework (WPF) support.
    - Ensure the script is run with appropriate permissions to access folder paths.
    - Performance may vary based on folder structure and recursion settings.

.LINK
    https://github.com/joboneact
#>

# Import required .NET assemblies for WPF functionality
# These assemblies provide the core WPF classes and controls
Add-Type -AssemblyName PresentationFramework  # Core WPF framework
Add-Type -AssemblyName PresentationCore       # WPF core components
Add-Type -AssemblyName WindowsBase            # Base WPF classes

<#
.SYNOPSIS
    Retrieves folder sizes for immediate child folders.

.DESCRIPTION
    This function calculates the size of immediate child folders within the specified path.
    It returns a collection of folder objects with comprehensive size information including
    bytes, megabytes, gigabytes, and human-readable display formats.

.PARAMETER Path
    The file system path of the folder to analyze for child folder sizes.

.EXAMPLE
    Get-FolderSizes -Path "C:\Users"
    Retrieves the sizes of all immediate child folders within "C:\Users".

.NOTES
    - Uses Get-ChildItem and Measure-Object to calculate folder sizes recursively.
    - Handles errors silently for inaccessible folders using -ErrorAction SilentlyContinue.
    - Returns sorted results by size in descending order for better visibility.
    - Includes multiple size format options for different display needs.
#>
function Get-FolderSizes {
    param([string]$Path)
    
    # Get all directories in the specified path and process each one
    Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        # Calculate total size by recursively getting all files and summing their lengths
        $folderSize = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                       Measure-Object -Property Length -Sum).Sum
        
        # Handle null values from empty folders or access denied scenarios
        if ($folderSize -eq $null) { $folderSize = 0 }
        
        # Create a custom object with comprehensive folder information
        [PSCustomObject]@{
            Name = $_.Name                                    # Folder display name
            FullPath = $_.FullName                           # Complete file system path
            SizeBytes = $folderSize                          # Raw size in bytes
            SizeMB = [math]::Round($folderSize / 1MB, 2)     # Size in megabytes (rounded)
            SizeGB = [math]::Round($folderSize / 1GB, 3)     # Size in gigabytes (rounded)
            # Human-readable size with appropriate unit suffix
            DisplaySize = if ($folderSize -gt 1GB) { 
                "$([math]::Round($folderSize / 1GB, 2)) GB" 
            } elseif ($folderSize -gt 1MB) { 
                "$([math]::Round($folderSize / 1MB, 2)) MB" 
            } elseif ($folderSize -gt 1KB) { 
                "$([math]::Round($folderSize / 1KB, 2)) KB" 
            } else { 
                "$folderSize bytes" 
            }
        }
    } | Sort-Object SizeBytes -Descending  # Sort by size for better visual hierarchy
}

<#
.SYNOPSIS
    Sorts folder data based on the specified column and direction.

.DESCRIPTION
    This function provides flexible sorting capabilities for folder data collections.
    It supports both ascending and descending sort orders for any specified column property.

.PARAMETER data
    The collection of folder data objects to sort.

.PARAMETER column
    The property name to sort by (e.g., "Name", "SizeBytes", "SizeMB").

.PARAMETER direction
    The sort direction - either "Ascending" or "Descending".

.EXAMPLE
    Sort-FolderData -data $folderData -column "SizeBytes" -direction "Descending"
    Sorts the folder data by size in descending order (largest first).

.EXAMPLE
    Sort-FolderData -data $folderData -column "Name" -direction "Ascending"
    Sorts the folder data alphabetically by name.

.NOTES
    - Uses PowerShell's Sort-Object cmdlet for reliable sorting.
    - Maintains object integrity during sorting operations.
    - Essential for column header click sorting functionality.
#>
function Sort-FolderData {
    param($data, $column, $direction)
    
    # Apply sorting based on direction parameter
    if ($direction -eq "Ascending") {
        $result = @($data | Sort-Object $column)
    } else {
        $result = @($data | Sort-Object $column -Descending)
    }
    return $result
}

<#
.SYNOPSIS
    Displays a modal progress dialog with a determinate progress bar.

.DESCRIPTION
    This function creates and displays a WPF progress dialog window with a progress bar
    that can be updated during long-running operations. The dialog provides visual
    feedback to users during folder size calculation processes.

.PARAMETER Message
    The descriptive message to display above the progress bar.

.EXAMPLE
    Show-ProgressDialogToImplement -Message "Refreshing folder sizes..."
    Displays a progress dialog with the specified message.

.NOTES
    - Uses inline XAML to define the dialog structure.
    - Returns a window object that can be manipulated by the caller.
    - Progress bar is determinate (0-100%) for accurate progress indication.
    - Dialog is modal and centered on screen for better user experience.
#>
function Show-ProgressDialogToImplement {
    param([string]$Message)
    throw [System.NotImplementedException]::new("Show-ProgressDialogToImplement is a placeholder and must be reimplemented before use.")
}

function Invoke-BackgroundRunspaceToImplement {
    param([scriptblock]$ScriptBlock)

    throw [System.NotImplementedException]::new("Invoke-BackgroundRunspaceToImplement is a placeholder and must be reimplemented before use.")
}

<#
.SYNOPSIS
    Displays a detailed exception dialog with clipboard functionality.

.DESCRIPTION
    This function creates and displays a modal dialog showing exception details
    with options to copy the error information to the clipboard for troubleshooting.

.PARAMETER Exception
    The exception object containing error details to display.

.PARAMETER Context
    Additional context information about when/where the error occurred.

.EXAMPLE
    Show-ExceptionDialog -Exception $_.Exception -Context "Folder size calculation"
    Displays an exception dialog with the error details and context.

.NOTES
    - Modal dialog blocks user interaction until dismissed
    - Provides copy to clipboard functionality for error reporting
    - Shows detailed error information for troubleshooting
#>
function Show-ExceptionDialog {
    param(
        [System.Exception]$Exception,
        [string]$Context = "Application Error"
    )

    # Create detailed error message with context and technical details
    $errorDetails = @"
Context: $Context
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Error Message: $($Exception.Message)

Exception Type: $($Exception.GetType().FullName)

Stack Trace:
$($Exception.StackTrace)

PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $([System.Environment]::OSVersion.VersionString)
"@

    # Define XAML for the exception dialog window
    $exceptionXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Application Error" Height="400" Width="600"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResize">
    <Grid>
        <!-- Define 3-row layout for organized error display -->
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>  <!-- Header with error icon and title -->
            <RowDefinition Height="*"/>     <!-- Main content area with error details -->
            <RowDefinition Height="Auto"/>  <!-- Button panel for user actions -->
        </Grid.RowDefinitions>
        
        <!-- Header section with error information -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10" Background="#FFF3CD">
            <!-- Error icon for visual indication -->
            <TextBlock Text="⚠️" FontSize="24" Margin="5" VerticalAlignment="Center"/>
            <!-- Error title and brief description -->
            <StackPanel Margin="10,5">
                <TextBlock Text="An Error Occurred" FontSize="16" FontWeight="Bold"/>
                <TextBlock Text="$Context" FontSize="12" Foreground="DarkRed"/>
            </StackPanel>
        </StackPanel>
        
        <!-- Main content area with scrollable error details -->
        <ScrollViewer Grid.Row="1" Margin="10" VerticalScrollBarVisibility="Auto">
            <!-- Text box containing full error information -->
            <TextBox Name="ErrorTextBox" Text="$errorDetails" 
                     IsReadOnly="True" TextWrapping="Wrap" 
                     FontFamily="Consolas" FontSize="10"
                     Background="LightGray" BorderThickness="1"/>
        </ScrollViewer>
        
        <!-- Button panel for user actions -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" 
                    HorizontalAlignment="Right" Margin="10">
            <!-- Copy to clipboard button -->
            <Button Name="CopyButton" Content="Copy to Clipboard" 
                    Width="120" Height="30" Margin="5"/>
            <!-- Close dialog button -->
            <Button Name="CloseButton" Content="Close" 
                    Width="80" Height="30" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
"@

    try {
        # Parse XAML and create the exception dialog window
        $reader = [System.Xml.XmlNodeReader]::new([xml]$exceptionXaml)
        $exceptionWindow = [Windows.Markup.XamlReader]::Load($reader)
        
        # Get references to dialog controls
        $errorTextBox = $exceptionWindow.FindName("ErrorTextBox")
        $copyButton = $exceptionWindow.FindName("CopyButton")
        $closeButton = $exceptionWindow.FindName("CloseButton")
        
        # Event handler for copy to clipboard button
        $copyButton.Add_Click({
            try {
                # Copy error details to system clipboard
                Set-Clipboard -Value $errorDetails
                
                # Provide visual feedback of successful copy
                $copyButton.Content = "Copied!"
                $copyButton.IsEnabled = $false
                
                # Reset button after 2 seconds
                $timer = New-Object System.Windows.Threading.DispatcherTimer
                $timer.Interval = [TimeSpan]::FromSeconds(2)
                $timer.Add_Tick({
                    $copyButton.Content = "Copy to Clipboard"
                    $copyButton.IsEnabled = $true
                    $timer.Stop()
                })
                $timer.Start()
            } catch {
                # Handle clipboard access errors
                $copyButton.Content = "Copy Failed"
            }
        })
        
        # Event handler for close button
        $closeButton.Add_Click({
            $exceptionWindow.Close()
        })
        
        # Display the exception dialog as modal
        $exceptionWindow.ShowDialog()
        
    } catch {
        # Fallback: If dialog creation fails, show basic message box
        [System.Windows.MessageBox]::Show(
            "Error Details:`n$($Exception.Message)", 
            "Application Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# Define the main application window using XAML
# This creates a comprehensive file browser interface with responsive design
$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Folder Size Browser (WPF) July 2026 v3" Height="550" Width="750"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <!-- Define a 4-row grid layout for organized content structure -->
        <Grid.RowDefinitions>
            <!-- Row 0: Navigation controls and options (Auto-sized based on content) -->
            <RowDefinition Height="Auto"/>
            <!-- Row 1: Main content area with folder list (Takes remaining space) -->
            <RowDefinition Height="*"/>
            <!-- Row 2: Status information display (Auto-sized) -->
            <RowDefinition Height="Auto"/>
            <!-- Row 3: Application status bar (Auto-sized) -->
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Responsive top area with wrapped current path and wrapped controls -->
        <Grid Grid.Row="0" Margin="10">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Current path display expands and wraps when window is narrow -->
            <Label Grid.Row="0" Grid.Column="0" Content="Current Path:" VerticalAlignment="Top" Margin="0,0,8,0" ToolTip="Shows the active folder path being scanned."/>
            <TextBox Name="PathTextBox"
                     Grid.Row="0"
                     Grid.Column="1"
                     Margin="0,0,0,6"
                     IsReadOnly="True"
                     TextWrapping="Wrap"
                     AcceptsReturn="True"
                     VerticalScrollBarVisibility="Disabled"
                     MinHeight="28"
                     MaxHeight="84"
                     ToolTip="Current folder path. Path wraps on narrow windows."/>

            <!-- Controls remain responsive by wrapping to next line as needed -->
            <WrapPanel Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" Orientation="Horizontal">
                <!-- Navigation button to move up one folder level -->
                <Button Name="UpButton" Content="Up" Width="50" Margin="0,0,5,5" ToolTip="Go to the parent folder. This action also turns Recurse off for faster navigation."/>
                <!-- Manual refresh button to recalculate folder sizes -->
                <Button Name="RefreshButton" Content="Refresh" Width="70" Margin="0,0,5,5" ToolTip="Recalculate folder sizes for the current path."/>
                <!-- Integration button to open current folder in Windows Explorer -->
                <Button Name="RevealButton" Content="Reveal in Explorer" Width="120" Margin="0,0,5,5" ToolTip="Open the current folder in Windows Explorer."/>
                <!-- Utility button to copy current path to clipboard -->
                <Button Name="CopyPathButton" Content="Copy Path" Width="80" Margin="0,0,5,5" ToolTip="Copy the current folder path to clipboard."/>
                <!-- Charts button to show volume and folder distribution -->
                <Button Name="ChartsButton" Content="Charts ⏳" Width="80" Margin="0,0,5,5" ToolTip="Open charts for volume usage and current folder distribution."/>
                <!-- Option checkbox to enable/disable recursive folder scanning -->
                <!-- Default checked for comprehensive size calculation -->
                <CheckBox Name="RecurseCheckBox" Content="Recurse Subfolders ⏳" IsChecked="True" Margin="0,4,0,5" ToolTip="Up button forces off; Refresh can take awhile. Chart and Export may take longer and Mouse wait cursor will show."/>
            </WrapPanel>

            <!-- Export row remains responsive by wrapping on narrow window widths -->
            <WrapPanel Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="2" Orientation="Horizontal">
                <Button Name="ExportButton" Content="Export Selected or Current Folder" Width="220" Margin="0,0,5,5" ToolTip="Export current folder or selected folder rows using the chosen format."/>
                <ComboBox Name="ExportFormatComboBox" Width="120" Margin="0,0,5,5" SelectedIndex="0" ToolTip="Choose export format: CSV, XLSX, Markdown, or HTML.">
                    <ComboBoxItem Content="CSV"/>
                    <ComboBoxItem Content="XLSX"/>
                    <ComboBoxItem Content="Markdown"/>
                    <ComboBoxItem Content="HTML"/>
                </ComboBox>
                <CheckBox Name="IncludeAttributeNamesCheckBox" Content="Include Attribute Names" IsChecked="False" Margin="0,4,0,5" ToolTip="Add a second exported attributes column with full descriptive names."/>
            </WrapPanel>
        </Grid>
        
        <!-- Main data display area using ListView with GridView for tabular data -->
        <ListView Name="FolderListView" Grid.Row="1" Margin="10" AlternationCount="2" SelectionMode="Extended" ToolTip="Double-click a row to open that folder. Use Ctrl/Shift to select multiple rows for export.">
            <!-- Style entire row bold when folder has subfolders, with alternating backgrounds -->
            <ListView.ItemContainerStyle>
                <Style TargetType="ListViewItem">
                    <Setter Property="Background" Value="White"/>
                    <Setter Property="Foreground" Value="Black"/>
                    <Style.Triggers>
                        <Trigger Property="ItemsControl.AlternationIndex" Value="1">
                            <Setter Property="Background" Value="#f0f0f0"/>
                        </Trigger>
                        <!-- High-contrast selected row style for readability over alternating backgrounds -->
                        <Trigger Property="IsSelected" Value="True">
                            <Setter Property="Background" Value="#5B2A86"/>
                            <Setter Property="Foreground" Value="White"/>
                        </Trigger>
                        <DataTrigger Binding="{Binding HasSubfolders}" Value="Yes">
                            <Setter Property="FontWeight" Value="Bold"/>
                        </DataTrigger>
                    </Style.Triggers>
                </Style>
            </ListView.ItemContainerStyle>
            <ListView.View>
                <!-- GridView provides column-based data presentation -->
                <GridView>
                    <!-- Primary column showing folder names -->
                    <!-- Widths are adjusted dynamically to fit available space -->
                    <GridViewColumn x:Name="FolderNameColumn" Header="Folder Name" Width="300">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock Text="{Binding Name}">
                                    <TextBlock.ToolTip>
                                        <ToolTip>
                                            <StackPanel Width="300">
                                                <TextBlock Text="{Binding Name}" FontWeight="Bold" Margin="0,0,0,8"/>
                                                <TextBlock Text="{Binding DisplaySize, StringFormat='Total Size: {0}'}" Margin="0,0,0,4"/>
                                                <TextBlock Text="{Binding ImmediateSubfolderCount, StringFormat='Child Folders: {0}'}" Margin="0,0,0,8"/>
                                                <TextBlock Text="{Binding FullPath}" TextWrapping="Wrap" Foreground="Gray" FontSize="10"/>
                                            </StackPanel>
                                        </ToolTip>
                                    </TextBlock.ToolTip>
                                </TextBlock>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <!-- Human-readable size column with automatic unit formatting -->
                    <GridViewColumn x:Name="DisplaySizeColumn" Header="Size" Width="150" DisplayMemberBinding="{Binding DisplaySize}"/>
                    <!-- Numeric size column in megabytes for precise comparison -->
                    <GridViewColumn x:Name="SizeMbColumn" Header="Size (MB)" Width="100" DisplayMemberBinding="{Binding SizeMB}"/>
                    <!-- Information column indicating presence of subdirectories -->
                    <GridViewColumn x:Name="HasSubfoldersColumn" Header="Has Subfolders" Width="150" DisplayMemberBinding="{Binding HasSubfolders}"/>
                </GridView>
            </ListView.View>
        </ListView>
        
        <!-- Status information panel showing last refresh timestamp -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="10,5">
            <!-- Bold label for visual emphasis -->
            <Label Content="Last Refreshed:" FontWeight="Bold" ToolTip="Timestamp of the most recent refresh."/>
            <!-- Dynamic label updated with each refresh operation -->
            <Label Name="LastRefreshedLabel" Content="Never" ToolTip="Updated after each refresh, navigation, or error."/>
        </StackPanel>
        
        <!-- Application status bar for operation feedback and error messages -->
        <StatusBar Grid.Row="3">
            <!-- General application messages -->
            <StatusBarItem Name="StatusText" Content="Ready" ToolTip="Current operation status and progress messages."/>
            <!-- Always-visible drive capacity summary shown in green -->
            <StatusBarItem Name="VolumeStatusText" Foreground="Green" HorizontalAlignment="Right" Content="Drive info unavailable" ToolTip="Drive total and free space for the current path volume."/>
        </StatusBar>
    </Grid>
</Window>
"@

# Parse the XAML and create the main window object
# XmlNodeReader provides efficient XAML parsing
$reader = [System.Xml.XmlNodeReader]::new([xml]$XAML)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Retrieve references to named controls for event handling and manipulation
# These references enable programmatic control of UI elements
$pathTextBox = $window.FindName("PathTextBox")           # Path display textbox
$upButton = $window.FindName("UpButton")                 # Parent folder navigation
$refreshButton = $window.FindName("RefreshButton")       # Manual refresh trigger
$revealButton = $window.FindName("RevealButton")         # Explorer integration
$copyPathButton = $window.FindName("CopyPathButton")     # Clipboard functionality
$chartsButton = $window.FindName("ChartsButton")         # Charts display button
$recurseCheckBox = $window.FindName("RecurseCheckBox")   # Recursion option control
$exportButton = $window.FindName("ExportButton")         # Export selected/current folder button
$exportFormatComboBox = $window.FindName("ExportFormatComboBox") # Export format selector
$includeAttributeNamesCheckBox = $window.FindName("IncludeAttributeNamesCheckBox") # Optional second attributes column
$folderListView = $window.FindName("FolderListView")     # Main data display
$folderNameColumn = $window.FindName("FolderNameColumn") # Folder name column
$displaySizeColumn = $window.FindName("DisplaySizeColumn") # Human-readable size column
$sizeMbColumn = $window.FindName("SizeMbColumn")         # Numeric MB size column
$hasSubfoldersColumn = $window.FindName("HasSubfoldersColumn") # Subfolder indicator column
$statusText = $window.FindName("StatusText")             # Status message display
$volumeStatusText = $window.FindName("VolumeStatusText") # Drive total/free display
$lastRefreshedLabel = $window.FindName("LastRefreshedLabel") # Timestamp display

# Initialize application state variables
# These variables maintain the current application state across operations
$currentPath = (Get-Location).Path                       # Start with current working directory
$currentSortColumn = "SizeBytes"                         # Default sort by size
$currentSortDirection = "Descending"                     # Largest folders first
$scriptFilePath = if ($PSCommandPath) {
    $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
}
else {
    Join-Path -Path (Get-Location).Path -ChildPath "WpfFolderSizeBrowser.v3.ps1"
}

# Persist settings in a consistent JSON file alongside the script.
$settingsDirectoryPath = Split-Path -Parent $scriptFilePath
$settingsFilePath = Join-Path -Path $settingsDirectoryPath -ChildPath "WpfFolderSizeBrowser.Settings.json"
$legacySettingsFilePaths = @(
    (Join-Path -Path $settingsDirectoryPath -ChildPath "WpfFolderSizeBrowser.v3.settings.json"),
    ([System.IO.Path]::ChangeExtension($scriptFilePath, ".json"))
)

function Load-AppSettings {
    param([string]$FilePath)

    try {
        if (Test-Path -LiteralPath $FilePath) {
            return (Get-Content -LiteralPath $FilePath -Raw | ConvertFrom-Json)
        }
    }
    catch {
        Write-Warning "Unable to read settings file '$FilePath': $($_.Exception.Message)"
    }

    return $null
}

function Save-AppSettings {
    param(
        [string]$FilePath,
        [string]$CurrentPath,
        [bool]$RecurseEnabled,
        [bool]$IncludeAttributeNames,
        [string]$ExportFormat,
        [string]$SortColumn,
        [string]$SortDirection
    )

    try {
        $bounds = $window.RestoreBounds
        if ($bounds.Width -le 0 -or $bounds.Height -le 0) {
            $bounds = [System.Windows.Rect]::new($window.Left, $window.Top, $window.Width, $window.Height)
        }

        $settingsObject = [PSCustomObject]@{
            version = 1
            lastUpdated = (Get-Date).ToString("o")
            currentPath = $CurrentPath
            recurseSubfolders = $RecurseEnabled
            includeAttributeNames = $IncludeAttributeNames
            exportFormat = $ExportFormat
            sortColumn = $SortColumn
            sortDirection = $SortDirection
            window = [PSCustomObject]@{
                left = [math]::Round($bounds.Left, 2)
                top = [math]::Round($bounds.Top, 2)
                width = [math]::Round($bounds.Width, 2)
                height = [math]::Round($bounds.Height, 2)
                state = $window.WindowState.ToString()
            }
        }

        $settingsObject | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $FilePath -Encoding UTF8
    }
    catch {
        Write-Warning "Unable to save settings file '$FilePath': $($_.Exception.Message)"
    }
}

function Format-ByteSize {
    param([double]$Bytes)

    if ($Bytes -ge 1TB) {
        return "{0:N2} TB" -f ($Bytes / 1TB)
    }
    elseif ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }

    return "{0:N0} bytes" -f $Bytes
}

function Update-VolumeStatus {
    param([string]$Path)

    try {
        $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
        $rootPath = [System.IO.Path]::GetPathRoot($resolvedPath)

        if ([string]::IsNullOrWhiteSpace($rootPath)) {
            throw "Unable to determine drive root for path: $Path"
        }

        $driveInfo = [System.IO.DriveInfo]::new($rootPath)
        $totalSize = Format-ByteSize -Bytes $driveInfo.TotalSize
        $freeSpace = Format-ByteSize -Bytes $driveInfo.AvailableFreeSpace

        # Keep the entire volume status green while emphasizing free space in bold.
        $volumeStatusBlock = [System.Windows.Controls.TextBlock]::new()
        $volumeStatusBlock.Foreground = [System.Windows.Media.Brushes]::Green
        [void]$volumeStatusBlock.Inlines.Add([System.Windows.Documents.Run]::new("Drive $rootPath Total: $totalSize | "))
        $freeSpaceRun = [System.Windows.Documents.Run]::new("Free: $freeSpace")
        $freeSpaceRun.FontWeight = [System.Windows.FontWeights]::Bold
        [void]$volumeStatusBlock.Inlines.Add($freeSpaceRun)

        $volumeStatusText.Content = $volumeStatusBlock
    }
    catch {
        $volumeStatusText.Content = "Drive info unavailable"
    }
}

$script:statusResetTimer = $null

function Show-TemporaryStatusMessage {
    param(
        [string]$TemporaryMessage,
        [string]$FinalMessage = "Ready",
        [int]$Seconds = 5
    )

    $statusText.Content = $TemporaryMessage

    # Reset any existing timer so repeated exports do not overlap status transitions.
    if ($script:statusResetTimer) {
        try { $script:statusResetTimer.Stop() } catch { }
        $script:statusResetTimer = $null
    }

    $script:statusResetTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:statusResetTimer.Interval = [TimeSpan]::FromSeconds([math]::Max($Seconds, 1))
    $script:statusResetTimer.Add_Tick({
        $statusText.Content = $FinalMessage
        $script:statusResetTimer.Stop()
        $script:statusResetTimer = $null
    })
    $script:statusResetTimer.Start()
}

function Update-ColumnWidths {
    # Calculate width available to the GridView after ListView margins, borders, and scrollbar.
    $availableWidth = [math]::Max($folderListView.ActualWidth - 40, 320)

    # If all four columns cannot fit their minimum widths, hide Size and rebalance.
    $minNameAll = 170
    $minSize = 88
    $minSizeMbAll = 82
    $minSubAll = 120
    $minTotalAllColumns = $minNameAll + $minSize + $minSizeMbAll + $minSubAll

    if ($availableWidth -lt $minTotalAllColumns) {
        $nameWidth = [math]::Max([math]::Round($availableWidth * 0.62, 0), 120)
        $sizeMbWidth = [math]::Max([math]::Round($availableWidth * 0.15, 0), 80)
        $subfoldersWidth = [math]::Max($availableWidth - $nameWidth - $sizeMbWidth, 100)

        $folderNameColumn.Width = $nameWidth
        $displaySizeColumn.Width = 0
        $sizeMbColumn.Width = $sizeMbWidth
        $hasSubfoldersColumn.Width = $subfoldersWidth
        return
    }

    # Tuned ratio profile for full four-column display.
    $nameWidth = [math]::Max([math]::Round($availableWidth * 0.50, 0), $minNameAll)
    $sizeWidth = [math]::Max([math]::Round($availableWidth * 0.16, 0), $minSize)
    $sizeMbWidth = [math]::Max([math]::Round($availableWidth * 0.12, 0), $minSizeMbAll)
    $subfoldersWidth = [math]::Max($availableWidth - $nameWidth - $sizeWidth - $sizeMbWidth, $minSubAll)

    $folderNameColumn.Width = $nameWidth
    $displaySizeColumn.Width = $sizeWidth
    $sizeMbColumn.Width = $sizeMbWidth
    $hasSubfoldersColumn.Width = $subfoldersWidth
}

$appSettings = Load-AppSettings -FilePath $settingsFilePath
if (-not $appSettings) {
    foreach ($legacySettingsFilePath in $legacySettingsFilePaths) {
        if (Test-Path -LiteralPath $legacySettingsFilePath) {
            $appSettings = Load-AppSettings -FilePath $legacySettingsFilePath
            if ($appSettings) {
                break
            }
        }
    }
}
if ($appSettings) {
    if ($appSettings.currentPath -and (Test-Path -LiteralPath $appSettings.currentPath)) {
        $currentPath = $appSettings.currentPath
    }

    if ($null -ne $appSettings.recurseSubfolders) {
        $recurseCheckBox.IsChecked = [bool]$appSettings.recurseSubfolders
    }

    if ($null -ne $appSettings.includeAttributeNames) {
        $includeAttributeNamesCheckBox.IsChecked = [bool]$appSettings.includeAttributeNames
    }

    if ($appSettings.exportFormat) {
        $selectedExportFormat = [string]$appSettings.exportFormat
        $matchingItem = $null

        foreach ($comboItem in $exportFormatComboBox.Items) {
            if ($comboItem -is [System.Windows.Controls.ComboBoxItem] -and [string]$comboItem.Content -eq $selectedExportFormat) {
                $matchingItem = $comboItem
                break
            }
        }

        if ($matchingItem) {
            $exportFormatComboBox.SelectedItem = $matchingItem
        }
    }

    if ($appSettings.sortColumn) {
        $currentSortColumn = $appSettings.sortColumn
    }

    if ($appSettings.sortDirection) {
        $currentSortDirection = $appSettings.sortDirection
    }

    if ($appSettings.window) {
        $window.WindowStartupLocation = "Manual"

        if ($appSettings.window.width -and $appSettings.window.width -ge 500) {
            $window.Width = [double]$appSettings.window.width
        }

        if ($appSettings.window.height -and $appSettings.window.height -ge 350) {
            $window.Height = [double]$appSettings.window.height
        }

        if ($null -ne $appSettings.window.left) {
            $window.Left = [double]$appSettings.window.left
        }

        if ($null -ne $appSettings.window.top) {
            $window.Top = [double]$appSettings.window.top
        }

        if ($appSettings.window.state -eq "Maximized") {
            $window.WindowState = [System.Windows.WindowState]::Maximized
        }
    }
}

<#
.SYNOPSIS
    Updates the main display with current folder sizes and comprehensive progress feedback.

.DESCRIPTION
    This is the core function that orchestrates the folder scanning process. It provides
    visual feedback through a progress dialog, calculates folder sizes based on recursion
    settings, and updates the main ListView with sorted results.

.PARAMETER Path
    The file system path to analyze and display folder information for.

.EXAMPLE
    Update-Display -Path "C:\Users"
    Analyzes and displays folder sizes for all immediate subdirectories of C:\Users.

.NOTES
    - Shows modal progress dialog during operation for user feedback
    - Respects the recursion checkbox setting for size calculation depth
    - Updates progress bar incrementally for better user experience
    - Handles errors gracefully with appropriate user messaging
    - Automatically sorts results based on current sort settings
#>
function Update-Display {
    param([string]$Path)

    # Progress dialog is intentionally stubbed out; use blocking scan flow.
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    $statusText.Content = "Loading..."
    $pathTextBox.Text = $Path
    Update-VolumeStatus -Path $Path

    try {
        $folders = @(Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue)
        $folderCount = $folders.Count
        $processedCount = 0
        $totalFilesFound = 0
        $totalSizeBytes = 0
        $folderData = @()

        foreach ($folder in $folders) {
            try {
                $allFiles = if ($recurseCheckBox.IsChecked) {
                    @(Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue)
                } else {
                    @(Get-ChildItem -Path $folder.FullName -File -ErrorAction SilentlyContinue)
                }

                $fileCount = $allFiles.Count
                $totalFilesFound += $fileCount

                $folderSize = if ($allFiles.Count -gt 0) {
                    ($allFiles | Measure-Object -Property Length -Sum).Sum
                } else { 0 }
                if ($null -eq $folderSize) { $folderSize = 0 }
                $totalSizeBytes += $folderSize

                $hasSubfolders = if ((Get-ChildItem -Path $folder.FullName -Directory -ErrorAction SilentlyContinue).Count -gt 0) {
                    "Yes"
                } else {
                    "No"
                }

                $immediateSubfolderCount = (Get-ChildItem -Path $folder.FullName -Directory -ErrorAction SilentlyContinue).Count

                $displaySize = if ($folderSize -gt 1GB) {
                    "$([math]::Round($folderSize / 1GB, 2)) GB"
                } elseif ($folderSize -gt 1MB) {
                    "$([math]::Round($folderSize / 1MB, 2)) MB"
                } elseif ($folderSize -gt 1KB) {
                    "$([math]::Round($folderSize / 1KB, 2)) KB"
                } else {
                    "$folderSize bytes"
                }

                $folderData += [PSCustomObject]@{
                    Name = $folder.Name
                    FullPath = $folder.FullName
                    SizeBytes = $folderSize
                    SizeMB = [math]::Round($folderSize / 1MB, 2)
                    DisplaySize = $displaySize
                    HasSubfolders = $hasSubfolders
                    ImmediateSubfolderCount = $immediateSubfolderCount
                }
            }
            catch {
                Write-Warning "Error processing folder '$($folder.Name)': $($_.Exception.Message)"
            }

            $processedCount++
            if ($folderCount -gt 0) {
                $statusText.Content = "Loading... $processedCount/$folderCount folders"
            }
        }

        $sortedFolders = Sort-FolderData -data $folderData -column $currentSortColumn -direction $currentSortDirection
        if ($sortedFolders -isnot [Array]) {
            $sortedFolders = @($sortedFolders)
        }

        $folderListView.ItemsSource = $sortedFolders

        $totalSizeDisplay = if ($totalSizeBytes -gt 1GB) {
            "$([math]::Round($totalSizeBytes / 1GB, 2)) GB"
        } elseif ($totalSizeBytes -gt 1MB) {
            "$([math]::Round($totalSizeBytes / 1MB, 2)) MB"
        } elseif ($totalSizeBytes -gt 1KB) {
            "$([math]::Round($totalSizeBytes / 1KB, 2)) KB"
        } else {
            "$totalSizeBytes bytes"
        }

        $statusText.Content = "Found $($folderData.Count) folders | $totalFilesFound files | Total: $totalSizeDisplay"
        $lastRefreshedLabel.Content = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        $statusText.Content = "Error: $($_.Exception.Message)"
        $lastRefreshedLabel.Content = "Error at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Show-ExceptionDialog -Exception $_.Exception -Context "Folder size calculation for path: $Path"
    }
    finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
}

function Get-SelectedExportFormat {
    $selectedItem = $exportFormatComboBox.SelectedItem

    if ($selectedItem -is [System.Windows.Controls.ComboBoxItem]) {
        return [string]$selectedItem.Content
    }

    if ($selectedItem) {
        return [string]$selectedItem
    }

    return "CSV"
}

function Update-ExportButtonLabel {
    $selectedCount = @($folderListView.SelectedItems).Count

    if ($selectedCount -gt 0) {
        $exportButton.Content = "Export Selected Folder(s)"
    }
    else {
        $exportButton.Content = "Export Current Folder"
    }
}

function Get-DirectorySizeBytes {
    param(
        [string]$FolderPath,
        [bool]$RecurseEnabled = $true
    )

    try {
        $files = if ($RecurseEnabled) {
            Get-ChildItem -LiteralPath $FolderPath -Recurse -File -ErrorAction SilentlyContinue
        }
        else {
            Get-ChildItem -LiteralPath $FolderPath -File -ErrorAction SilentlyContinue
        }

        $sum = ($files |
               Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { return 0 }
        return [double]$sum
    }
    catch {
        return 0
    }
}

function Get-ExplorerAttributeMap {
    @(
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::ReadOnly;        Letter = 'R'; Name = 'ReadOnly' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::Hidden;          Letter = 'H'; Name = 'Hidden' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::System;          Letter = 'S'; Name = 'System' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::Archive;         Letter = 'A'; Name = 'Archive' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::Compressed;      Letter = 'C'; Name = 'Compressed' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::Encrypted;       Letter = 'E'; Name = 'Encrypted' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::Temporary;       Letter = 'T'; Name = 'Temporary' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::Offline;         Letter = 'O'; Name = 'Offline' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::NotContentIndexed; Letter = 'I'; Name = 'NotContentIndexed' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::ReparsePoint;    Letter = 'L'; Name = 'ReparsePoint' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::Directory;       Letter = 'D'; Name = 'Directory' },
        [PSCustomObject]@{ Flag = [System.IO.FileAttributes]::Normal;          Letter = 'N'; Name = 'Normal' }
    )
}

function Convert-FileAttributesToExplorerFlags {
    param([System.IO.FileAttributes]$Attributes)

    $letters = @()

    $attributeMap = Get-ExplorerAttributeMap

    foreach ($entry in $attributeMap) {
        if (($Attributes -band $entry.Flag) -eq $entry.Flag) {
            $letters += $entry.Letter
        }
    }

    if ($letters.Count -eq 0) {
        return '-'
    }

    return ($letters -join '')
}

function Convert-FileAttributesToExplorerNames {
    param([System.IO.FileAttributes]$Attributes)

    $names = @()
    $attributeMap = Get-ExplorerAttributeMap

    foreach ($entry in $attributeMap) {
        if (($Attributes -band $entry.Flag) -eq $entry.Flag) {
            $names += $entry.Name
        }
    }

    if ($names.Count -eq 0) {
        return '-'
    }

    return ($names -join ', ')
}

function Get-FolderReportRows {
    param(
        [string]$RootPath,
        [int]$Level = 0,
        [bool]$RecurseEnabled = $true,
        [bool]$IncludeChildRows = $true
    )

    $rows = @()

    if (-not (Test-Path -LiteralPath $RootPath)) {
        return $rows
    }

    try {
        $folderItem = Get-Item -LiteralPath $RootPath -ErrorAction Stop
    }
    catch {
        return $rows
    }

    $folderName = if ([string]::IsNullOrWhiteSpace($folderItem.Name)) {
        $folderItem.FullName
    }
    else {
        $folderItem.Name
    }

    $sizeBytes = Get-DirectorySizeBytes -FolderPath $folderItem.FullName -RecurseEnabled $RecurseEnabled
    $children = @(Get-ChildItem -LiteralPath $folderItem.FullName -Directory -ErrorAction SilentlyContinue | Sort-Object Name)

    $rows += [PSCustomObject]@{
        FileName = $folderName
        AbsolutePath = $folderItem.FullName
        SizeKB = [math]::Round($sizeBytes / 1KB, 2)
        SizeGB = [math]::Round($sizeBytes / 1GB, 4)
        ModifiedDateTime = (Get-Date -Date $folderItem.LastWriteTime -Format "ddd yyyy-MM-dd HH:mm:ss")
        CreatedDateTime = (Get-Date -Date $folderItem.CreationTime -Format "ddd yyyy-MM-dd HH:mm:ss")
        Attributes = Convert-FileAttributesToExplorerFlags -Attributes $folderItem.Attributes
        AttributesNames = Convert-FileAttributesToExplorerNames -Attributes $folderItem.Attributes
        SubFolderCount = $children.Count
        Level = $Level
    }

    if ($IncludeChildRows) {
        if ($RecurseEnabled) {
            foreach ($child in $children) {
                $rows += Get-FolderReportRows -RootPath $child.FullName -Level ($Level + 1) -RecurseEnabled $true -IncludeChildRows $true
            }
        }
        else {
            # Non-recursive export includes only immediate children beneath the root.
            foreach ($child in $children) {
                $rows += Get-FolderReportRows -RootPath $child.FullName -Level ($Level + 1) -RecurseEnabled $false -IncludeChildRows $false
            }
        }
    }

    return $rows
}

function ConvertTo-MarkdownSafeCell {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return "" }

    return ($Value -replace "\|", "\\|" -replace "`r`n|`n|`r", "<br>")
}

function Convert-PathToFileUri {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        if (Test-Path -LiteralPath $fullPath -PathType Container) {
            $fullPath = $fullPath.TrimEnd([char[]]'\\/') + '\\'
        }
        return ([System.Uri]::new($fullPath)).AbsoluteUri
    }
    catch {
        try {
            return ([System.Uri]::new($Path)).AbsoluteUri
        }
        catch {
            return ""
        }
    }
}

function Convert-PathToExcelHyperlinkFormula {
    param(
        [string]$Path,
        [string]$DisplayText = "Open in Explorer"
    )

    $folderUri = Convert-PathToFileUri -Path $Path
    if ([string]::IsNullOrWhiteSpace($folderUri)) {
        return ""
    }

    $effectiveDisplayText = if ([string]::IsNullOrWhiteSpace($DisplayText)) { $Path } else { $DisplayText }
    $safeUri = $folderUri.Replace('"', '""')
    $safeDisplayText = ([string]$effectiveDisplayText).Replace('"', '""')

    return "=HYPERLINK(""$safeUri"",""$safeDisplayText"")"
}

function Export-FolderReportCsv {
    param(
        [array]$Rows,
        [string]$OutputPath,
        [bool]$IncludeAttributeNames = $false
    )

    $exportRows = foreach ($row in $Rows) {
        $record = [ordered]@{
            FileName = [string]$row.FileName
            AbsolutePath = [string]$row.AbsolutePath
            SizeKB = [double]$row.SizeKB
            SizeGB = [double]$row.SizeGB
            ModifiedDateTime = [string]$row.ModifiedDateTime
            CreatedDateTime = [string]$row.CreatedDateTime
            Attributes = [string]$row.Attributes
        }

        if ($IncludeAttributeNames) {
            $record.AttributesNames = [string]$row.AttributesNames
        }

        $record.SubFolderCount = [int]$row.SubFolderCount
        $record.OpenInExplorerExcel = Convert-PathToExcelHyperlinkFormula -Path ([string]$row.AbsolutePath) -DisplayText "Open in Explorer"

        [PSCustomObject]$record
    }

    $exportRows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
}

function Export-FolderReportXlsx {
    param(
        [array]$Rows,
        [string]$OutputPath,
        [string]$RootPath,
        [bool]$RecurseEnabled = $true,
        [bool]$IncludeAttributeNames = $false
    )

    $excel = $null
    $workbook = $null
    $worksheet = $null

    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false

        $workbook = $excel.Workbooks.Add()
        $worksheet = $workbook.Worksheets.Item(1)
        $worksheet.Name = "Folder Report"

        $headers = @(
            'File Name',
            'Absolute Path',
            'Size KB',
            'Size GB',
            'Modified',
            'Created',
            'Attributes (Flags)',
            'Sub-Folders'
        )

        if ($IncludeAttributeNames) {
            $headers = @(
                'File Name',
                'Absolute Path',
                'Size KB',
                'Size GB',
                'Modified',
                'Created',
                'Attributes (Flags)',
                'Attributes (Names)',
                'Sub-Folders'
            )
        }

        $worksheet.Cells.Item(1, 1).Value2 = "Root Path"
        $worksheet.Cells.Item(1, 2).Value2 = [string]$RootPath
        $worksheet.Cells.Item(2, 1).Value2 = "Generated"
        $worksheet.Cells.Item(2, 2).Value2 = (Get-Date -Format 'ddd yyyy-MM-dd HH:mm:ss')
        $worksheet.Cells.Item(3, 1).Value2 = "Recurse Subfolders"
        $worksheet.Cells.Item(3, 2).Value2 = if ($RecurseEnabled) { "Checked" } else { "Unchecked" }
        $worksheet.Range("A1:A3").Font.Bold = $true

        $headerRow = 5
        for ($col = 0; $col -lt $headers.Count; $col++) {
            $worksheet.Cells.Item($headerRow, $col + 1).Value2 = $headers[$col]
        }

        $worksheet.Cells.Item($headerRow, 1).EntireRow.Font.Bold = $true
        $worksheet.Cells.Item($headerRow, 1).EntireRow.Interior.ColorIndex = 15

        $rowIndex = $headerRow + 1
        foreach ($row in $Rows) {
            $colIndex = 1
            $worksheet.Cells.Item($rowIndex, $colIndex++).Value2 = [string]$row.FileName
            $absolutePathCell = $worksheet.Cells.Item($rowIndex, $colIndex++)
            $absolutePathDisplay = [string]$row.AbsolutePath
            $absolutePathCell.Value2 = $absolutePathDisplay
            $worksheet.Cells.Item($rowIndex, $colIndex++).Value2 = [double]$row.SizeKB
            $worksheet.Cells.Item($rowIndex, $colIndex++).Value2 = [double]$row.SizeGB
            $worksheet.Cells.Item($rowIndex, $colIndex++).Value2 = [string]$row.ModifiedDateTime
            $worksheet.Cells.Item($rowIndex, $colIndex++).Value2 = [string]$row.CreatedDateTime
            $worksheet.Cells.Item($rowIndex, $colIndex++).Value2 = [string]$row.Attributes
            if ($IncludeAttributeNames) {
                $worksheet.Cells.Item($rowIndex, $colIndex++).Value2 = [string]$row.AttributesNames
            }
            $worksheet.Cells.Item($rowIndex, $colIndex++).Value2 = [int]$row.SubFolderCount

            $folderPath = [string]$row.AbsolutePath
            if (-not [string]::IsNullOrWhiteSpace($folderPath)) {
                try {
                    $absolutePathFormula = Convert-PathToExcelHyperlinkFormula -Path $folderPath -DisplayText $absolutePathDisplay
                    if (-not [string]::IsNullOrWhiteSpace($absolutePathFormula)) {
                        # Use formula hyperlinks so Excel reliably renders Absolute Path as clickable text.
                        $absolutePathCell.Formula = $absolutePathFormula
                    }
                }
                catch {
                    # Keep export resilient even if hyperlink injection fails for a specific row.
                }
            }

            $rowIndex++
        }

        $lastDataRow = [math]::Max($Rows.Count + $headerRow, $headerRow + 1)
        $lastColumnLetter = if ($IncludeAttributeNames) { 'I' } else { 'H' }
        $usedRange = $worksheet.Range("A$headerRow", "$lastColumnLetter$lastDataRow")
        $usedRange.Borders.LineStyle = 1
        $usedRange.AutoFilter() | Out-Null

        $worksheet.Columns.Item(3).NumberFormat = "#,##0.00"
        $worksheet.Columns.Item(4).NumberFormat = "#,##0.0000"
        $subFolderColumn = if ($IncludeAttributeNames) { 9 } else { 8 }
        $worksheet.Columns.Item($subFolderColumn).NumberFormat = "0"
        $worksheet.Columns.AutoFit() | Out-Null

        $worksheet.Activate() | Out-Null
        $excel.ActiveWindow.SplitRow = $headerRow
        $excel.ActiveWindow.FreezePanes = $true

        # 51 = xlOpenXMLWorkbook (.xlsx)
        $workbook.SaveAs($OutputPath, 51)
    }
    finally {
        if ($workbook) {
            $workbook.Close($true)
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        }

        if ($worksheet) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet)
        }

        if ($excel) {
            $excel.Quit()
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        }

        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Export-FolderReportMarkdown {
    param(
        [array]$Rows,
        [string]$OutputPath,
        [string]$RootPath,
        [bool]$RecurseEnabled = $true,
        [bool]$IncludeAttributeNames = $false
    )

    $headerColumns = @('File Name', 'Absolute Path', 'Size KB', 'Size GB', 'Modified', 'Created', 'Attributes')
    if ($IncludeAttributeNames) {
        $headerColumns += 'Attributes Names'
    }
    $headerColumns += 'Sub-Folders'

    $alignmentColumns = @('---', '---', '---:', '---:', '---', '---', '---')
    if ($IncludeAttributeNames) {
        $alignmentColumns += '---'
    }
    $alignmentColumns += '---:'

    $lines = @(
        "# Folder Report",
        "",
        "Root Path: $RootPath",
        "Generated: $(Get-Date -Format 'ddd yyyy-MM-dd HH:mm:ss')",
        "Recurse Subfolders: $(if ($RecurseEnabled) { 'Checked' } else { 'Unchecked' })",
        "",
        "| $($headerColumns -join ' | ') |",
        "| $($alignmentColumns -join ' | ') |"
    )

    foreach ($row in $Rows) {
        $folderUri = Convert-PathToFileUri -Path $row.AbsolutePath
        $fileNameText = ConvertTo-MarkdownSafeCell $row.FileName
        $absolutePathText = ConvertTo-MarkdownSafeCell $row.AbsolutePath

        $fileNameCell = if ([string]::IsNullOrWhiteSpace($folderUri)) {
            $fileNameText
        }
        else {
            "[$fileNameText]($folderUri)"
        }

        $absolutePathCell = if ([string]::IsNullOrWhiteSpace($folderUri)) {
            $absolutePathText
        }
        else {
            "[$absolutePathText]($folderUri)"
        }

        $cells = @(
            $fileNameCell,
            $absolutePathCell,
            $row.SizeKB,
            $row.SizeGB,
            (ConvertTo-MarkdownSafeCell $row.ModifiedDateTime),
            (ConvertTo-MarkdownSafeCell $row.CreatedDateTime),
            (ConvertTo-MarkdownSafeCell $row.Attributes)
        )

        if ($IncludeAttributeNames) {
            $cells += (ConvertTo-MarkdownSafeCell $row.AttributesNames)
        }

        $cells += $row.SubFolderCount
        $lines += "| $($cells -join ' | ') |"
    }

    $lines | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

function Export-FolderReportHtml {
    param(
        [array]$Rows,
        [string]$OutputPath,
        [string]$RootPath,
        [bool]$RecurseEnabled = $true,
        [bool]$IncludeAttributeNames = $false
    )

    $rowHtml = foreach ($row in $Rows) {
        $indentPixels = [int]($row.Level * 20)
        $levelText = [string]$row.Level
        $nameText = [System.Net.WebUtility]::HtmlEncode([string]$row.FileName)
        $pathText = [System.Net.WebUtility]::HtmlEncode([string]$row.AbsolutePath)
        $folderUri = Convert-PathToFileUri -Path $row.AbsolutePath
        $folderUriEncoded = [System.Net.WebUtility]::HtmlEncode($folderUri)
        $modText = [System.Net.WebUtility]::HtmlEncode([string]$row.ModifiedDateTime)
        $createText = [System.Net.WebUtility]::HtmlEncode([string]$row.CreatedDateTime)
        $attrText = [System.Net.WebUtility]::HtmlEncode([string]$row.Attributes)
        $attrNamesText = [System.Net.WebUtility]::HtmlEncode([string]$row.AttributesNames)

        $nameDisplay = "<span style='padding-left:${indentPixels}px;display:inline-block;'>$nameText</span>"
        if (-not [string]::IsNullOrWhiteSpace($folderUri)) {
            $nameDisplay = "<a href='$folderUriEncoded'>$nameDisplay</a>"
            $pathText = "<a href='$folderUriEncoded'>$pathText</a>"
        }

        $attrNamesCell = ""
        if ($IncludeAttributeNames) {
            $attrNamesCell = "<td>$attrNamesText</td>"
        }

        @"
        <tr>
            <td class="num">$levelText</td>
            <td>$nameDisplay</td>
            <td>$pathText</td>
            <td class="num">$($row.SizeKB)</td>
            <td class="num">$($row.SizeGB)</td>
            <td>$modText</td>
            <td>$createText</td>
            <td>$attrText</td>
            $attrNamesCell
            <td class="num">$($row.SubFolderCount)</td>
        </tr>
"@
    }

    $attributeNamesHeader = ""
    if ($IncludeAttributeNames) {
        $attributeNamesHeader = "<th>Attributes (Names)</th>"
    }

    $rootPathEncoded = [System.Net.WebUtility]::HtmlEncode($RootPath)
    $generated = [System.Net.WebUtility]::HtmlEncode((Get-Date -Format 'ddd yyyy-MM-dd HH:mm:ss'))

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>Folder Report</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; background: #fafafa; color: #222; }
        h1 { margin-bottom: 6px; }
        .meta { margin-bottom: 16px; color: #444; }
        table { border-collapse: collapse; width: 100%; background: #fff; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; vertical-align: top; }
        th { background: #f2f2f2; }
        .num { text-align: right; }
        tr:nth-child(even) td { background: #fcfcfc; }
    </style>
</head>
<body>
    <h1>Folder Report</h1>
    <div class="meta"><strong>Root Path:</strong> $rootPathEncoded<br/><strong>Generated:</strong> $generated<br/><strong>Recurse Subfolders:</strong> $(if ($RecurseEnabled) { 'Checked' } else { 'Unchecked' })</div>
    <table>
        <thead>
            <tr>
                <th>Level</th>
                <th>File Name</th>
                <th>Absolute Path</th>
                <th>Size KB</th>
                <th>Size GB</th>
                <th>Modified</th>
                <th>Created</th>
                <th>Attributes (Flags)</th>
                $attributeNamesHeader
                <th>Sub-Folders</th>
            </tr>
        </thead>
        <tbody>
$($rowHtml -join [Environment]::NewLine)
        </tbody>
    </table>
</body>
</html>
"@

    $html | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

function Open-ExportedReport {
    param(
        [string]$ExportPath,
        [string]$Format
    )

    switch ($Format) {
        "CSV" {
            $excelCommand = Get-Command -Name "excel.exe" -ErrorAction SilentlyContinue
            if ($excelCommand) {
                Start-Process -FilePath $excelCommand.Source -ArgumentList @("`"$ExportPath`"") | Out-Null
            }
            else {
                Start-Process -FilePath $ExportPath | Out-Null
            }
        }
        "XLSX" {
            $excelCommand = Get-Command -Name "excel.exe" -ErrorAction SilentlyContinue
            if ($excelCommand) {
                Start-Process -FilePath $excelCommand.Source -ArgumentList @("`"$ExportPath`"") | Out-Null
            }
            else {
                Start-Process -FilePath $ExportPath | Out-Null
            }
        }
        "Markdown" {
            Start-Process -FilePath "notepad.exe" -ArgumentList @("`"$ExportPath`"") | Out-Null
        }
        "HTML" {
            $edgePath = $null
            $edgeCommand = Get-Command -Name "msedge.exe" -ErrorAction SilentlyContinue
            if ($edgeCommand) {
                $edgePath = $edgeCommand.Source
            }
            else {
                $candidatePaths = @(
                    (Join-Path -Path ${env:ProgramFiles} -ChildPath "Microsoft\Edge\Application\msedge.exe"),
                    (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Microsoft\Edge\Application\msedge.exe")
                )

                foreach ($candidatePath in $candidatePaths) {
                    if (Test-Path -LiteralPath $candidatePath) {
                        $edgePath = $candidatePath
                        break
                    }
                }
            }

            if ($edgePath) {
                Start-Process -FilePath $edgePath -ArgumentList @("`"$ExportPath`"") | Out-Null
            }
            else {
                Start-Process -FilePath $ExportPath | Out-Null
            }
        }
        default {
            Start-Process -FilePath $ExportPath | Out-Null
        }
    }
}

# Helper function to draw pie slices on a canvas
function Draw-PieChart {
    param($Canvas, $Data, $Colors, $Title)
    
    $Canvas.Children.Clear()
    
    $total = ($Data.Values | Measure-Object -Sum).Sum
    if ($total -eq 0) { return }
    
    $centerX = 150
    $centerY = 150
    $radius = 120
    
    # Title
    $titleBlock = [System.Windows.Controls.TextBlock]::new()
    $titleBlock.Text = $Title
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = [System.Windows.FontWeights]::Bold
    $titleBlock.Foreground = [System.Windows.Media.Brushes]::Black
    [System.Windows.Controls.Canvas]::SetLeft($titleBlock, 50)
    [System.Windows.Controls.Canvas]::SetTop($titleBlock, 10)
    $Canvas.Children.Add($titleBlock) | Out-Null
    
    $startAngle = -90
    $colorIndex = 0
    
    foreach ($item in $Data.GetEnumerator()) {
        $value = $item.Value
        $percentage = ($value / $total) * 100
        $sliceAngle = ($value / $total) * 360
        $endAngle = $startAngle + $sliceAngle
        
        # Create pie slice using Path
        $isLargeArc = if ($sliceAngle -gt 180) { "1" } else { "0" }
        
        $startRad = [Math]::PI * $startAngle / 180
        $endRad = [Math]::PI * $endAngle / 180
        
        $x1 = $centerX + $radius * [Math]::Cos($startRad)
        $y1 = $centerY + $radius * [Math]::Sin($startRad)
        $x2 = $centerX + $radius * [Math]::Cos($endRad)
        $y2 = $centerY + $radius * [Math]::Sin($endRad)
        
        $pathData = "M $centerX $centerY L $x1 $y1 A $radius $radius 0 $isLargeArc 1 $x2 $y2 Z"
        
        $path = [System.Windows.Shapes.Path]::new()
        $path.Data = [System.Windows.Media.Geometry]::Parse($pathData)
        $path.Fill = $colors[$colorIndex % $colors.Count]
        $path.Stroke = [System.Windows.Media.Brushes]::White
        $path.StrokeThickness = 2
        
        $Canvas.Children.Add($path) | Out-Null
        
        # Add label
        $labelAngle = $startAngle + $sliceAngle / 2
        $labelRad = [Math]::PI * $labelAngle / 180
        $labelX = $centerX + ($radius * 0.65) * [Math]::Cos($labelRad) - 20
        $labelY = $centerY + ($radius * 0.65) * [Math]::Sin($labelRad) - 10
        
        $label = [System.Windows.Controls.TextBlock]::new()
        $label.Text = "$([Math]::Round($percentage, 1))%"
        $label.FontSize = 9
        $label.Foreground = [System.Windows.Media.Brushes]::White
        $label.FontWeight = [System.Windows.FontWeights]::Bold
        [System.Windows.Controls.Canvas]::SetLeft($label, $labelX)
        [System.Windows.Controls.Canvas]::SetTop($label, $labelY)
        $Canvas.Children.Add($label) | Out-Null
        
        # Add legend entry
        $legendY = 290 + ($colorIndex * 18)
        $legendRect = [System.Windows.Shapes.Rectangle]::new()
        $legendRect.Width = 15
        $legendRect.Height = 15
        $legendRect.Fill = $colors[$colorIndex % $colors.Count]
        [System.Windows.Controls.Canvas]::SetLeft($legendRect, 10)
        [System.Windows.Controls.Canvas]::SetTop($legendRect, $legendY)
        $Canvas.Children.Add($legendRect) | Out-Null
        
        $legendText = [System.Windows.Controls.TextBlock]::new()
        $legendText.Text = "$($item.Name): $('{0:N0}' -f $value) bytes"
        $legendText.FontSize = 10
        [System.Windows.Controls.Canvas]::SetLeft($legendText, 30)
        [System.Windows.Controls.Canvas]::SetTop($legendText, $legendY)
        $Canvas.Children.Add($legendText) | Out-Null
        
        $startAngle = $endAngle
        $colorIndex++
    }
}

# Event handler for Export button - exports selected folder or current path in selected format
$exportButton.Add_Click({
    try {
        $selectedPaths = @(
            $folderListView.SelectedItems |
                Where-Object { $_ -and $_.FullPath -and (Test-Path -LiteralPath $_.FullPath) } |
                ForEach-Object { $_.FullPath }
        )

        $exportRootPaths = if ($selectedPaths.Count -gt 0) {
            @($selectedPaths | Select-Object -Unique)
        }
        else {
            @($script:currentPath)
        }

        # Normalize export roots to a stable string array to avoid scalar/string indexing edge cases.
        [string[]]$exportRootPaths = @($exportRootPaths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        if ($exportRootPaths.Count -eq 0) {
            $exportRootPaths = @([string]$script:currentPath)
        }

        $primaryExportRootPath = [string]($exportRootPaths | Select-Object -First 1)

        $selectedFormat = Get-SelectedExportFormat
        $includeAttributeNames = [bool]$includeAttributeNamesCheckBox.IsChecked
        $recurseForExport = [bool]$recurseCheckBox.IsChecked
        if ($exportRootPaths.Count -gt 1) {
            $statusText.Content = "Building $selectedFormat report for $($exportRootPaths.Count) selected folders ..."
        }
        else {
            $statusText.Content = "Building $selectedFormat report for $primaryExportRootPath ..."
        }
        $window.Cursor = [System.Windows.Input.Cursors]::Wait

        $reportRows = @()
        foreach ($exportRootPath in $exportRootPaths) {
            $reportRows += @(Get-FolderReportRows -RootPath $exportRootPath -RecurseEnabled $recurseForExport -IncludeChildRows $true)
        }

        if ($reportRows.Count -eq 0) {
            $statusText.Content = "No folders found to export for selected scope."
            return
        }

        $folderLeaf = if ($exportRootPaths.Count -gt 1) {
            "MultipleFolders"
        }
        else {
            [System.IO.Path]::GetFileName($primaryExportRootPath.TrimEnd([char[]]'\\/'))
        }

        if ([string]::IsNullOrWhiteSpace($folderLeaf)) {
            $folderLeaf = ($primaryExportRootPath -replace '[:\\/]+', '_').Trim('_')
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $saveDialog = [Microsoft.Win32.SaveFileDialog]::new()

        switch ($selectedFormat) {
            "XLSX" {
                $saveDialog.Filter = "Excel Workbook (*.xlsx)|*.xlsx"
                $saveDialog.DefaultExt = ".xlsx"
                $saveDialog.FileName = "FolderReport_${folderLeaf}_$timestamp.xlsx"
            }
            "Markdown" {
                $saveDialog.Filter = "Markdown Files (*.md)|*.md"
                $saveDialog.DefaultExt = ".md"
                $saveDialog.FileName = "FolderReport_${folderLeaf}_$timestamp.md"
            }
            "HTML" {
                $saveDialog.Filter = "HTML Files (*.html)|*.html"
                $saveDialog.DefaultExt = ".html"
                $saveDialog.FileName = "FolderReport_${folderLeaf}_$timestamp.html"
            }
            default {
                $saveDialog.Filter = "CSV Files (*.csv)|*.csv"
                $saveDialog.DefaultExt = ".csv"
                $saveDialog.FileName = "FolderReport_${folderLeaf}_$timestamp.csv"
            }
        }

        $saveDialog.InitialDirectory = if (Test-Path -LiteralPath $primaryExportRootPath) { $primaryExportRootPath } else { $script:currentPath }

        if ($saveDialog.ShowDialog() -ne $true) {
            $statusText.Content = "Export canceled."
            return
        }

        switch ($selectedFormat) {
            "XLSX" {
                $rootLabel = if ($exportRootPaths.Count -gt 1) {
                    "Multiple Folders ($($exportRootPaths.Count))"
                }
                else {
                    $primaryExportRootPath
                }
                Export-FolderReportXlsx -Rows $reportRows -OutputPath $saveDialog.FileName -RootPath $rootLabel -RecurseEnabled $recurseForExport -IncludeAttributeNames $includeAttributeNames
            }
            "Markdown" {
                $rootLabel = if ($exportRootPaths.Count -gt 1) {
                    "Multiple Folders ($($exportRootPaths.Count))"
                }
                else {
                    $primaryExportRootPath
                }
                Export-FolderReportMarkdown -Rows $reportRows -OutputPath $saveDialog.FileName -RootPath $rootLabel -RecurseEnabled $recurseForExport -IncludeAttributeNames $includeAttributeNames
            }
            "HTML" {
                $rootLabel = if ($exportRootPaths.Count -gt 1) {
                    "Multiple Folders ($($exportRootPaths.Count))"
                }
                else {
                    $primaryExportRootPath
                }
                Export-FolderReportHtml -Rows $reportRows -OutputPath $saveDialog.FileName -RootPath $rootLabel -RecurseEnabled $recurseForExport -IncludeAttributeNames $includeAttributeNames
            }
            default { Export-FolderReportCsv -Rows $reportRows -OutputPath $saveDialog.FileName -IncludeAttributeNames $includeAttributeNames }
        }

        Open-ExportedReport -ExportPath $saveDialog.FileName -Format $selectedFormat

        Show-TemporaryStatusMessage -TemporaryMessage "Export complete: $($saveDialog.FileName)" -FinalMessage "Finished 🏁💽" -Seconds 5
    }
    catch {
        $statusText.Content = "Export error: $($_.Exception.Message)"
        Show-ExceptionDialog -Exception $_.Exception -Context "Exporting folder report"
    }
    finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
})

# Event handler for Charts button - displays volume and folder distribution
$chartsButton.Add_Click({
    try {
        # Collect folder data for right pie chart
        $folders = @(Get-ChildItem -Path $currentPath -Directory -ErrorAction SilentlyContinue)
        $folderData = @{}
        $totalFolderSize = 0
        
        foreach ($folder in $folders) {
            $folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if ($null -eq $folderSize) { $folderSize = 0 }
            $folderData[$folder.Name] = $folderSize
            $totalFolderSize += $folderSize
        }
        
        # Add files in current path
        $filesSize = (Get-ChildItem -Path $currentPath -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $filesSize) { $filesSize = 0 }
        if ($filesSize -gt 0) {
            $folderData["Files in $([System.IO.Path]::GetFileName($currentPath))"] = $filesSize
        }
        
        # Get volume data for left pie chart
        $rootPath = [System.IO.Path]::GetPathRoot($currentPath)
        $driveInfo = [System.IO.DriveInfo]::new($rootPath)
        
        $currentFolderSize = (Get-ChildItem -Path $currentPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $currentFolderSize) { $currentFolderSize = 0 }
        
        $freeSpace = $driveInfo.AvailableFreeSpace
        $usedSpace = $driveInfo.TotalSize - $freeSpace
        
        $volumeData = @{
            "Current Path" = $currentFolderSize
            "Other Data" = $usedSpace - $currentFolderSize
            "Free Space" = $freeSpace
        }
        
        # Create charts window XAML
        $chartsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Volume &amp; Folder Charts" Height="550" Width="850"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResize">
    <Grid Background="White">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        
        <Canvas Name="VolumeChart" Grid.Column="0" Background="#f5f5f5" Margin="10"/>
        <Canvas Name="FolderChart" Grid.Column="1" Background="#f5f5f5" Margin="10"/>
    </Grid>
</Window>
"@
        
        $reader = [System.Xml.XmlNodeReader]::new([xml]$chartsXaml)
        $chartsWindow = [Windows.Markup.XamlReader]::Load($reader)
        
        $volumeCanvas = $chartsWindow.FindName("VolumeChart")
        $folderCanvas = $chartsWindow.FindName("FolderChart")
        
        # Color palettes
        $volumeColors = @(
            [System.Windows.Media.Brushes]::SkyBlue,
            [System.Windows.Media.Brushes]::LightGray,
            [System.Windows.Media.Brushes]::LimeGreen
        )
        
        $folderColors = @(
            [System.Windows.Media.Brushes]::LightCoral,
            [System.Windows.Media.Brushes]::Gold,
            [System.Windows.Media.Brushes]::LightSeaGreen,
            [System.Windows.Media.Brushes]::Plum,
            [System.Windows.Media.Brushes]::Salmon,
            [System.Windows.Media.Brushes]::Khaki,
            [System.Windows.Media.Brushes]::CornflowerBlue,
            [System.Windows.Media.Brushes]::MediumOrchid
        )
        
        Draw-PieChart -Canvas $volumeCanvas -Data $volumeData -Colors $volumeColors -Title "Volume Space Distribution"
        
        if ($folderData.Count -gt 0) {
            Draw-PieChart -Canvas $folderCanvas -Data $folderData -Colors $folderColors -Title "Current Path Contents"
        }
        
        $chartsWindow.ShowDialog() | Out-Null
    }
    catch {
        $statusText.Content = "Error generating charts: $($_.Exception.Message)"
    }
})

# Event handler for Up button - navigates to parent directory
# Automatically disables recursion for better performance when navigating up
$upButton.Add_Click({
    # Get parent directory path
    $parent = Split-Path -Parent $currentPath
    
    # Verify parent exists and is accessible
    if ($parent -and (Test-Path $parent)) {
        # Update current path to parent directory
        $script:currentPath = $parent
        
        # Disable recursion when navigating up to improve performance
        # Large parent directories can be slow with recursion enabled
        $recurseCheckBox.IsChecked = $false
        
        # Refresh display with new path
        Update-Display $currentPath
    }
})

# Event handler for Refresh button - recalculates current directory
$refreshButton.Add_Click({
    Update-Display $currentPath
})

# Event handler for Copy Path button - copies current path to system clipboard
$copyPathButton.Add_Click({
    try {
        # Use PowerShell clipboard functionality to copy path
        Set-Clipboard -Value $currentPath
        
        # Provide user confirmation of successful copy operation
        $statusText.Content = "Path copied to clipboard: $currentPath"
    } catch {
        # Show detailed exception dialog for clipboard errors
        Show-ExceptionDialog -Exception $_.Exception -Context "Copying path to clipboard"
    }
})

# Event handler for Reveal in Explorer button - opens current path in Windows Explorer
$revealButton.Add_Click({
    try {
        # Verify path exists before attempting to open
        if (Test-Path $currentPath) {
            # Launch Windows Explorer with current path
            Start-Process explorer.exe $currentPath
        } else {
            # Display error message for invalid paths
            $statusText.Content = "Error: Path does not exist."
        }
    } catch {
        # Show detailed exception dialog for Explorer launch errors
        Show-ExceptionDialog -Exception $_.Exception -Context "Opening folder in Windows Explorer"
    }
})

# Event handler for ListView double-click - enables folder navigation by double-clicking
# This provides intuitive navigation similar to Windows Explorer
$folderListView.AddHandler([System.Windows.Controls.ListView]::MouseDoubleClickEvent, [System.Windows.Input.MouseButtonEventHandler]{
    param($eventSender, $eventArgs)

    # Get the currently selected folder item
    $selectedItem = $folderListView.SelectedItem
    
    # Verify a valid folder is selected with a complete path
    if ($selectedItem -and $selectedItem.FullPath) {
        # Update current path to the selected folder
        $script:currentPath = $selectedItem.FullPath
        
        # Refresh display to show contents of selected folder
        Update-Display $currentPath
    } else {
        # Display error message for invalid selections
        $statusText.Content = "Error: Unable to open folder."
    }
})

# Keep export button text in sync with folder selection.
$folderListView.Add_SelectionChanged({
    Update-ExportButtonLabel
})

# Keep folder columns responsive as the window resizes.
$window.Add_SizeChanged({
    Update-ColumnWidths
})

# Persist user preferences and layout when the window closes.
$window.Add_Closing({
    Save-AppSettings -FilePath $settingsFilePath `
                     -CurrentPath $script:currentPath `
                     -RecurseEnabled ([bool]$recurseCheckBox.IsChecked) `
                     -IncludeAttributeNames ([bool]$includeAttributeNamesCheckBox.IsChecked) `
                     -ExportFormat (Get-SelectedExportFormat) `
                     -SortColumn $script:currentSortColumn `
                     -SortDirection $script:currentSortDirection
})

# Perform initial application load with current working directory
Update-ColumnWidths
Update-Display $currentPath
Update-ExportButtonLabel

# Display the main window and start the WPF message loop
# ShowDialog() makes the window modal and blocks until closed
$window.ShowDialog()


