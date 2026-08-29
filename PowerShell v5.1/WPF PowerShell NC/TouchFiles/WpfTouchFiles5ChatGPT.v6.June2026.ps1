# WpfTouchFiles5ChatGPT.v6.June2026.ps1
# WpfTouchFiles5ChatGPT5.ps1

<#
.SYNOPSIS
    Touch files via WPF UI with drag & drop.
#>


# Ensure the script always runs in anSTA runspace so WPF can operate correctly.
if ($Host.Runspace.ApartmentState -ne 'STA') {
    $psi = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        FileName = (Get-Process -Id $PID).Path
        Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        UseShellExecute = $true
    }
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

# Load the core WPF assemblies that provide windowing, controls, and rendering.
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

# Define a strongly typed data model only once per session to support two-way binding.
if (-not ([System.Management.Automation.PSTypeName]'TouchFileItem').Type) {
    Add-Type @"
using System;
using System.ComponentModel;

public class TouchFileItem : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;
    string fullPath, baseName, displayPath, lastModified, size, attributes;
    bool isSelected;

    public TouchFileItem()
    {
        baseName = string.Empty;
        fullPath = string.Empty;
        displayPath = string.Empty;
        lastModified = string.Empty;
        size = string.Empty;
        attributes = string.Empty;
        isSelected = false;
    }

    void Notify(string name)
    {
        var handler = PropertyChanged;
        if (handler != null)
        {
            handler(this, new PropertyChangedEventArgs(name));
        }
    }

    public string FullPath
    {
        get { return fullPath; }
        set { if (fullPath != value) { fullPath = value; Notify("FullPath"); } }
    }

    public string DisplayPath
    {
        get { return displayPath; }
        set { if (displayPath != value) { displayPath = value; Notify("DisplayPath"); } }
    }

    public string BaseName
    {
        get { return baseName; }
        set { if (baseName != value) { baseName = value; Notify("BaseName"); } }
    }

    public string LastModified
    {
        get { return lastModified; }
        set { if (lastModified != value) { lastModified = value; Notify("LastModified"); } }
    }

    public string Size
    {
        get { return size; }
        set { if (size != value) { size = value; Notify("Size"); } }
    }

    public string Attributes
    {
        get { return attributes; }
        set { if (attributes != value) { attributes = value; Notify("Attributes"); } }
    }

    public bool IsSelected
    {
        get { return isSelected; }
        set { if (isSelected != value) { isSelected = value; Notify("IsSelected"); } }
    }
}
"@
}

# Convert raw byte counts into human-readable size strings (KB/MB/GB).
function Format-Size {
    param([long]$Bytes)
    switch ($Bytes) {
        {$_ -lt 1KB} { return "$Bytes B" }
        {$_ -lt 1MB} { return "{0:N1} KB" -f ($Bytes/1KB) }
        {$_ -lt 1GB} { return "{0:N1} MB" -f ($Bytes/1MB) }
        default      { return "{0:N1} GB" -f ($Bytes/1GB) }
    }
}

# Translate file system attributes into compact letter codes (e.g., A, R, C).
function Get-AttributeLetters {
    param([System.IO.FileAttributes]$Attributes)
    $map = @{
        Archive    = 'A'
        ReadOnly   = 'R'
        Hidden     = 'H'
        System     = 'S'
        Compressed = 'C'
        Encrypted  = 'E'
    }
    $letters = foreach ($entry in $map.GetEnumerator()) {
        if ($Attributes.HasFlag([System.IO.FileAttributes]::$($entry.Key))) { $entry.Value }
    }
    if ($letters) { ($letters -join '') } else { 'N' }
}

# Locate and load the associated XAML definition that describes the UI layout.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$xamlFileName = 'WpfTouchFiles5ChatGPT.v6.June2026.xaml'
$xamlPath  = Join-Path $scriptDir $xamlFileName

if (-not (Test-Path -LiteralPath $xamlPath -PathType Leaf)) {
    throw "Required non-icons XAML was not found: $xamlPath"
}

[xml]$xaml = Get-Content $xamlPath
$reader   = New-Object System.Xml.XmlNodeReader $xaml
$window   = [Windows.Markup.XamlReader]::Load($reader)

# Cache key WPF controls for later event wiring and state updates.
$btnAdd    = $window.FindName('BtnAdd')
$btnTouch  = $window.FindName('BtnTouch')
$btnToggle = $window.FindName('BtnToggleCompression')
$btnEnc    = $window.FindName('BtnToggleEncryption')
$btnHidden = $window.FindName('BtnToggleHidden')
$btnClear  = $window.FindName('BtnClear')
$fileList  = $window.FindName('FileListView')
$fileCardList = $window.FindName('FileCardList')
$fileTableBorder = $window.FindName('FileTableBorder')
$fileCardBorder = $window.FindName('FileCardBorder')
$instructionRow = $window.FindName('InstructionRow')
$lblStatus = $window.FindName('LblStatus')
$lblNow    = $window.FindName('LblNow')
$chkSelectAll = $window.FindName('ChkSelectAll')
$chkCompactMode = $window.FindName('ChkCompactMode')
$chkClearOnDrop = $window.FindName('ChkClearOnDrop')

# Flags support suppressing re-entrant events when bulk-updating selection state.
$script:suppressSelectAllEvent = $false
$script:bulkSelectionUpdate   = $false
$script:compactMode           = $false

# Monitor item property changes so UI state stays in sync with checkbox toggles.
$itemPropertyChangedHandler   = [System.ComponentModel.PropertyChangedEventHandler]{
    param($sender,$eventArgs)
    if ($eventArgs.PropertyName -eq 'IsSelected' -and -not $script:bulkSelectionUpdate) {
        Update-UiState
    }
}

# Backing collection for the ListView; supports binding and change notifications.
$fileItems = New-Object 'System.Collections.ObjectModel.ObservableCollection[TouchFileItem]'
$fileList.ItemsSource = $fileItems
if ($fileCardList) { $fileCardList.ItemsSource = $fileItems }
$collectionView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($fileItems)

# Convenience accessor to force bindings to refresh when data changes.
function Refresh-View { $collectionView.Refresh() }

# Return all items that have the selection checkbox enabled.
function Get-SelectedItems {
    @($fileItems | Where-Object { $_.IsSelected })
}

# Reflect current selections in the Select All checkbox (checked / unchecked / indeterminate).
function Sync-SelectAll {
    if (-not $chkSelectAll) { return }
    $script:suppressSelectAllEvent = $true
    $selected = (Get-SelectedItems).Count
    switch ($selected) {
        0 { $chkSelectAll.IsChecked = $false }
        { $_ -eq $fileItems.Count } { $chkSelectAll.IsChecked = $true }
        default { $chkSelectAll.IsChecked = $null }
    }
    $script:suppressSelectAllEvent = $false
}

# Apply the same selection state to every row, respecting bulk-update flags.
function Set-AllSelection {
    param([bool]$Select)
    if ($fileItems.Count -eq 0) { return }
    $script:bulkSelectionUpdate = $true
    foreach ($item in $fileItems) { $item.IsSelected = $Select }
    $script:bulkSelectionUpdate = $false
    Update-UiState
}

# Swap between table and card layouts for narrow windows and reclaim space on short windows.
function Update-ResponsiveLayout {
    $isNarrow = $window.ActualWidth -le 400
    if ($fileTableBorder -and $fileCardBorder) {
        $fileTableBorder.Visibility = if ($isNarrow) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
        $fileCardBorder.Visibility  = if ($isNarrow) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    }

    if ($instructionRow) {
        $instructionRow.Visibility = if ($window.ActualHeight -lt 360) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
    }
}

# Recursively walk the visual tree to find all children of a given type.
function Find-AllChildrenByType {
    param([System.Windows.DependencyObject]$Parent, [Type]$ChildType)
    $children = @()
    if ($ChildType -and $ChildType.IsInstanceOfType($Parent)) { $children += $Parent }
    try {
        $count = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Parent)
        for ($i = 0; $i -lt $count; $i++) {
            $child = [System.Windows.Media.VisualTreeHelper]::GetChild($Parent, $i)
            $children += Find-AllChildrenByType -Parent $child -ChildType $ChildType
        }
    } catch {
        # Ignore errors in tree traversal
    }
    $children
}

# Toggle visibility of full paths in grid and card views based on compact mode.
function Toggle-PathVisibility {
    param([bool]$HidePaths)
    
    # Toggle in grid view
    if ($fileList) {
        for ($i = 0; $i -lt $fileList.Items.Count; $i++) {
            $container = $fileList.ItemContainerGenerator.ContainerFromIndex($i)
            if ($container) {
                $textBlocks = Find-AllChildrenByType -Parent $container -ChildType ([System.Windows.Controls.TextBlock])
                foreach ($tb in $textBlocks) {
                    # Hide/show TextBlocks with gray foreground (the full DisplayPath)
                    if ($tb.Foreground -is [System.Windows.Media.SolidColorBrush]) {
                        $color = $tb.Foreground.Color
                        if ($color.R -eq 0x55 -and $color.G -eq 0x55 -and $color.B -eq 0x55) {
                            $tb.Visibility = if ($HidePaths) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
                        }
                    }
                }
            }
        }
    }
    
    # Toggle in card view
    if ($fileCardList) {
        for ($i = 0; $i -lt $fileCardList.Items.Count; $i++) {
            $container = $fileCardList.ItemContainerGenerator.ContainerFromIndex($i)
            if ($container) {
                $textBlocks = Find-AllChildrenByType -Parent $container -ChildType ([System.Windows.Controls.TextBlock])
                foreach ($tb in $textBlocks) {
                    if ($tb.Foreground -is [System.Windows.Media.SolidColorBrush]) {
                        $color = $tb.Foreground.Color
                        if ($color.R -eq 0x55 -and $color.G -eq 0x55 -and $color.B -eq 0x55) {
                            $tb.Visibility = if ($HidePaths) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
                        }
                    }
                }
            }
        }
    }
}

# Keep the path column balanced as the window resizes by consuming remaining table width.
function Update-PathColumnWidth {
    if (-not $fileList) { return }
    $gridView = $fileList.View -as [System.Windows.Controls.GridView]
    if (-not $gridView) { return }
    if ($gridView.Columns.Count -lt 5) { return }

    $pathColumn = $gridView.Columns[1]
    if (-not $pathColumn) { return }

    # Reserve a buffer for borders, padding, and possible vertical scrollbar.
    $chromeBuffer = 42
    $available = $fileList.ActualWidth - $chromeBuffer
    if ($available -le 0) { return }

    $fixedWidth = 0
    for ($i = 0; $i -lt $gridView.Columns.Count; $i++) {
        if ($i -ne 1) {
            $fixedWidth += $gridView.Columns[$i].Width
        }
    }

    $target = [Math]::Max(140, $available - $fixedWidth)
    if ([Math]::Abs($pathColumn.Width - $target) -ge 1) {
        $pathColumn.Width = $target
    }
}

# Update button enablement, status text, and select-all state in one place.
function Update-UiState {
    $btnTouch.IsEnabled  = $true
    $btnToggle.IsEnabled = $true
    if ($btnEnc)    { $btnEnc.IsEnabled    = $true }
    if ($btnHidden) { $btnHidden.IsEnabled = $true }
    $btnClear.IsEnabled  = $fileItems.Count -gt 0
    $lblStatus.Text = if ($fileItems.Count) { "Files loaded: $($fileItems.Count)" } else { "Ready" }
    Sync-SelectAll
}

# Normalize each incoming path, skip duplicates, and push new rows into the UI model.
function Add-Files {
    param([string[]]$Paths)
    $added = 0
    $script:bulkSelectionUpdate = $true
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        try {
            $info = Get-Item -LiteralPath $path -ErrorAction Stop
        }
        catch {
            continue
        }
        $full = $info.FullName
        if ($fileItems | Where-Object { $_.FullPath -eq $full }) { continue }
        $item = New-Object TouchFileItem
        $item.FullPath     = $info.FullName
        $item.BaseName     = [System.IO.Path]::GetFileName($info.FullName)
        $item.DisplayPath  = $info.FullName
        $item.LastModified = $info.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        $item.Size         = Format-Size $info.Length
        $item.Attributes   = Get-AttributeLetters -Attributes $info.Attributes
        $item.IsSelected   = $true
        $item.add_PropertyChanged($itemPropertyChangedHandler)
        $fileItems.Add($item)
        $added++
    }
    $script:bulkSelectionUpdate = $false
    if ($added) { $lblStatus.Text = "Added $added file(s)" }
    Update-UiState
}

# Provide Explorer drag-over feedback so the UI reports whether dropping is permitted.
$dragOverHandler = {
    param($sender,$e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
    } else {
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    $e.Handled = $true
}

# Accept dropped files and forward them into the Add-Files pipeline.
$dropHandler = {
    param($sender,$e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        if ($chkClearOnDrop -and $chkClearOnDrop.IsChecked -eq $true) {
            $fileItems.Clear()
            Update-UiState
        }
        $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        Add-Files -Paths $files
    }
    $e.Handled = $true
}

$fileList.Add_PreviewDragOver($dragOverHandler)
$fileList.Add_Drop($dropHandler)
if ($fileCardList) {
    $fileCardList.Add_PreviewDragOver($dragOverHandler)
    $fileCardList.Add_Drop($dropHandler)
}

# Push files from the OpenFileDialog into the collection, honoring multiselect.
$btnAdd.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog()) {
        Add-Files -Paths $dlg.FileNames
    }
})

# Update LastWriteTime for the currently selected rows, refreshing metadata after each write.
$btnTouch.Add_Click({
    $selected = Get-SelectedItems
    if (-not $selected) {
        $lblStatus.Text = "Select one or more files to touch"
        return
    }
    $now = Get-Date
    $touched = 0
    foreach ($item in $selected) {
        if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
        $file = Get-Item -LiteralPath $item.FullPath
        $file.LastWriteTime = $now
        $item.LastModified = $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        $item.Size = Format-Size $file.Length
        $item.Attributes = Get-AttributeLetters -Attributes $file.Attributes
        $touched++
    }
    $lblStatus.Text = if ($touched) { "Touched $touched selected file(s)" } else { "No selected files touched" }
    Update-UiState
})

# Toggle NTFS compression via compact.exe for each selected file, then refresh attributes.
$btnToggle.Add_Click({
    $selected = Get-SelectedItems
    if (-not $selected) { return }
    foreach ($item in $selected) {
        if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
        $file = Get-Item -LiteralPath $item.FullPath
        $isCompressed = $file.Attributes.HasFlag([System.IO.FileAttributes]::Compressed)
        $compactArgs = if ($isCompressed) { @('/U','/I','/Q',"`"$($file.FullName)`"") } else { @('/C','/I','/Q',"`"$($file.FullName)`"") }
        Start-Process -FilePath "$env:SystemRoot\System32\compact.exe" -ArgumentList $compactArgs -NoNewWindow -Wait | Out-Null
        $file = Get-Item -LiteralPath $item.FullPath
        $item.Attributes = Get-AttributeLetters -Attributes $file.Attributes
        $item.Size = Format-Size $file.Length
    }
    $lblStatus.Text = "Toggled compression on $($selected.Count) file(s)"
    Update-UiState
})
# Add encryption toggle handler
if ($btnEnc) {
    $btnEnc.Add_Click({
        $selected = Get-SelectedItems
        if (-not $selected) { return }
        foreach ($item in $selected) {
            if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
            $file = Get-Item -LiteralPath $item.FullPath
            $isEncrypted = $file.Attributes.HasFlag([System.IO.FileAttributes]::Encrypted)
            $cipherArgs = if ($isEncrypted) { @('/D', "`"$($file.FullName)`"") } else { @('/E', "`"$($file.FullName)`"") }
            Start-Process -FilePath "$env:SystemRoot\System32\cipher.exe" -ArgumentList $cipherArgs -NoNewWindow -Wait | Out-Null
            $file = Get-Item -LiteralPath $item.FullPath
            $item.Attributes = Get-AttributeLetters -Attributes $file.Attributes
        }
        $lblStatus.Text = "Toggled encryption on $($selected.Count) file(s)"
        Update-UiState
    })
}
# Add hidden attribute toggle handler
if ($btnHidden) {
    $btnHidden.Add_Click({
        $selected = Get-SelectedItems
        if (-not $selected) { return }
        foreach ($item in $selected) {
            if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
            try {
                $currentAttributes = [System.IO.File]::GetAttributes($item.FullPath)
                $newAttributes = $currentAttributes -bxor [System.IO.FileAttributes]::Hidden
                [System.IO.File]::SetAttributes($item.FullPath, $newAttributes)
                $item.Attributes = Get-AttributeLetters -Attributes $newAttributes
            }
            catch {
                continue
            }
        }
        $lblStatus.Text = "Toggled hidden on $($selected.Count) file(s)"
        Update-UiState
    })
}

# Remove every entry from the collection and reset UI indicators.
$btnClear.Add_Click({
    $fileItems.Clear()
    Update-UiState
})

# Master checkbox to select or clear all rows without affecting button enablement.
$chkSelectAll.Add_Click({
    if ($script:suppressSelectAllEvent) { return }
    Set-AllSelection -Select ($chkSelectAll.IsChecked -eq $true)
})

# Toggle compact mode to show or hide full paths.
if ($chkCompactMode) {
    $chkCompactMode.Add_Click({
        $script:compactMode = $chkCompactMode.IsChecked -eq $true
        Toggle-PathVisibility -HidePaths $script:compactMode
    })
}

# Initialize the UI to a clean state and display the initial timestamp.
Update-UiState
Update-ResponsiveLayout
Update-PathColumnWidth
$lblNow.Text = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

# Re-evaluate responsive breakpoints whenever the user resizes the window.
$window.Add_SizeChanged({
    Update-ResponsiveLayout
    Update-PathColumnWidth
})

# Re-apply sizing once layout is fully realized.
$window.Add_ContentRendered({
    Update-ResponsiveLayout
    Update-PathColumnWidth
})

# Timer keeps the footer clock current while the window remains open.
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({ $lblNow.Text = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') })
$timer.Start()

# Display the WPF window and tear down the timer when the dialog closes.
try { $window.ShowDialog() | Out-Null }
finally { $timer.Stop() }