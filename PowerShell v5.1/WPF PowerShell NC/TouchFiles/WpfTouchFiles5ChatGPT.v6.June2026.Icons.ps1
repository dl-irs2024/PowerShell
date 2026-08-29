# WpfTouchFiles5ChatGPT.v6.June2026.icons.ps1
# broken about and error 🤖🤖
# claaude takes over. Mon 6-29-2026 about dialog and error works again.
# WpfTouchFiles5ChatGPT.v6.June2026.ps1
# WpfTouchFiles5ChatGPT5.ps1


<#

---------------------------
Touch Files - About Error
---------------------------
About dialog failed.
You cannot call a method on a null-valued expression.
ErrorId: TFERR-20260701012402-00001
---------------------------
OK   
---------------------------

#>
<#
.SYNOPSIS
    Touch file timestamps and file attributes from a WPF desktop interface.

.DESCRIPTION
    Provides a drag-and-drop WPF UI to queue files and run bulk operations including
    timestamp touch, NTFS compression toggle, EFS encryption toggle, and Hidden
    attribute toggle. The script also tracks diagnostics, stores optional window
    placement settings, and shows a session diagnostics window with transcript output.

.NOTES
    Designed for Windows PowerShell 5.1 and STA mode because WPF requires STA.
    The script restarts itself in STA when needed.

.EXAMPLE
    PS> .\WpfTouchFiles5ChatGPT.v6.June2026.Icons.ps1
    Launches the Touch Files UI and allows drag/drop or Add File selection.
#>

# UI sizing constants (pixel units).
$script:mainWindowMinWidthPixels = 300.0

# Initialize trace logging flag early so Write-TraceLog can check it.
$script:traceEnabled = ($env:TOUCHFILES_TRACE -eq '1')

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
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem

# Define a strongly typed data model only once per session to support two-way binding.
if (-not ([System.Management.Automation.PSTypeName]'TouchFileItemV20260623').Type) {
    Add-Type @"
using System;
using System.ComponentModel;

public class TouchFileItemV20260623 : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;
    string fullPath, baseName, displayPath, lastModified, size, attributes, comment, commentSupportEmoji;
    bool isSelected, commentReadOnly, commentSupported;

    public TouchFileItemV20260623()
    {
        baseName = string.Empty;
        fullPath = string.Empty;
        displayPath = string.Empty;
        lastModified = string.Empty;
        size = string.Empty;
        attributes = string.Empty;
        comment = string.Empty;
        commentSupportEmoji = "✅";
        isSelected = false;
        commentReadOnly = false;
        commentSupported = true;
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

    public string Comment
    {
        get { return comment; }
        set { if (comment != value) { comment = value; Notify("Comment"); } }
    }

    public bool CommentReadOnly
    {
        get { return commentReadOnly; }
        set { if (commentReadOnly != value) { commentReadOnly = value; Notify("CommentReadOnly"); } }
    }

    public bool CommentSupported
    {
        get { return commentSupported; }
        set { if (commentSupported != value) { commentSupported = value; Notify("CommentSupported"); } }
    }

    public string CommentSupportEmoji
    {
        get { return commentSupportEmoji; }
        set { if (commentSupportEmoji != value) { commentSupportEmoji = value; Notify("CommentSupportEmoji"); } }
    }

    public bool IsSelected
    {
        get { return isSelected; }
        set { if (isSelected != value) { isSelected = value; Notify("IsSelected"); } }
    }
}
"@
}

# Load native shell icon helpers once so we can reuse a built-in Windows folder icon.
if (-not ([System.Management.Automation.PSTypeName]'ShellIconNative').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ShellIconNative
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct SHFILEINFO
    {
        public IntPtr hIcon;
        public int iIcon;
        public uint dwAttributes;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string szDisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)]
        public string szTypeName;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SHGetFileInfo(
        string pszPath,
        uint dwFileAttributes,
        out SHFILEINFO psfi,
        uint cbFileInfo,
        uint uFlags);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
"@
}

<#
.SYNOPSIS
    Converts a byte count into a readable size string.

.DESCRIPTION
    Formats an input byte value into B, KB, MB, or GB using one decimal place
    for KB and above.

.PARAMETER Bytes
    The file size in bytes.

.OUTPUTS
    System.String
#>
function Format-Size {
    param([long]$Bytes)
    switch ($Bytes) {
        {$_ -lt 1KB} { return "$Bytes B" }
        {$_ -lt 1MB} { return "{0:N1} KB" -f ($Bytes/1KB) }
        {$_ -lt 1GB} { return "{0:N1} MB" -f ($Bytes/1MB) }
        default      { return "{0:N1} GB" -f ($Bytes/1GB) }
    }
}

<#
.SYNOPSIS
    Converts file attributes into compact letter codes.

.DESCRIPTION
    Maps selected System.IO.FileAttributes flags to a short status string used by
    the UI (for example A, R, H, C, E). Returns N when no mapped flags are present.

.PARAMETER Attributes
    File attributes to evaluate.

.OUTPUTS
    System.String
#>
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

<#
.SYNOPSIS
    Writes trace-level diagnostic messages when tracing is enabled.

.DESCRIPTION
    Outputs timestamped log messages to the console when the TOUCHFILES_TRACE
    environment variable is set to '1'. Supports multiple log levels.

.PARAMETER Message
    The message to log.

.PARAMETER Level
    Log level (TRACE, INFO, WARN, ERROR). Default is TRACE.
#>
function Write-TraceLog {
    param(
        [string]$Message,
        [ValidateSet('TRACE','INFO','WARN','ERROR')]
        [string]$Level = 'TRACE'
    )

    if (-not $script:traceEnabled) { return }
    if ([string]::IsNullOrWhiteSpace($Message)) { return }

    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
    Write-Host "[$stamp] [$Level] $Message"
}

function New-XamlXmlNodeReader {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$XmlDocument,
        [string]$Context = 'XAML'
    )

    if (-not $XmlDocument) {
        throw "$Context XML document is null."
    }

    $node = if ($XmlDocument.DocumentElement) { $XmlDocument.DocumentElement } else { $XmlDocument }
    if (-not $node) {
        throw "$Context XML does not contain a document element."
    }

    return [System.Xml.XmlNodeReader]::new([System.Xml.XmlNode]$node)
}

<#
.SYNOPSIS
    Gets the built-in Windows small folder icon.

.DESCRIPTION
    Uses SHGetFileInfo from shell32 to retrieve the system folder icon and converts
    it into a frozen WPF ImageSource for safe UI reuse.

.OUTPUTS
    System.Windows.Media.ImageSource
#>
function Get-WindowsFolderIcon {
    $shgfiIcon = 0x000000100
    $shgfiSmallIcon = 0x000000001
    $shgfiUseFileAttributes = 0x000000010
    $fileAttributeDirectory = 0x00000010

    $info = New-Object ShellIconNative+SHFILEINFO
    $result = [ShellIconNative]::SHGetFileInfo(
        'C:\',
        $fileAttributeDirectory,
        [ref]$info,
        [uint32][Runtime.InteropServices.Marshal]::SizeOf([type]'ShellIconNative+SHFILEINFO'),
        ($shgfiIcon -bor $shgfiSmallIcon -bor $shgfiUseFileAttributes)
    )

    if ($result -eq [IntPtr]::Zero -or $info.hIcon -eq [IntPtr]::Zero) {
        return $null
    }

    try {
        $iconSource = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
            $info.hIcon,
            [System.Windows.Int32Rect]::Empty,
            [System.Windows.Media.Imaging.BitmapSizeOptions]::FromWidthAndHeight(16, 16)
        )
        $iconSource.Freeze()
        return $iconSource
    }
    finally {
        [ShellIconNative]::DestroyIcon($info.hIcon) | Out-Null
    }
}

<#
.SYNOPSIS
    Builds the application icon from a Windows folder icon plus clock overlay.

.DESCRIPTION
    Draws a small blue clock marker over the system folder icon to represent file
    update/touch behavior. Returns a frozen bitmap suitable for both window and UI
    image usage.

.OUTPUTS
    System.Windows.Media.Imaging.RenderTargetBitmap
#>
function New-WindowFolderClockIcon {
    $folderIcon = Get-WindowsFolderIcon
    if (-not $folderIcon) { return $null }

    $size = 16
    $surface = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($size, $size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $visual = New-Object System.Windows.Media.DrawingVisual
    $context = $visual.RenderOpen()

    $context.DrawImage($folderIcon, [System.Windows.Rect]::new(0, 0, $size, $size))

    $clockFill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0x0A, 0x63, 0xB6))
    $clockFill.Freeze()
    $clockBorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xFF, 0xFF, 0xFF))
    $clockBorderBrush.Freeze()
    $clockBorderPen = New-Object System.Windows.Media.Pen($clockBorderBrush, 0.9)
    $clockBorderPen.Freeze()

    $cx = 12.1
    $cy = 11.9
    $radius = 3.4
    $context.DrawEllipse($clockFill, $clockBorderPen, [System.Windows.Point]::new($cx, $cy), $radius, $radius)

    $handBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xFF, 0xFF, 0xFF))
    $handBrush.Freeze()
    $handPen = New-Object System.Windows.Media.Pen($handBrush, 1.0)
    $handPen.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $handPen.EndLineCap = [System.Windows.Media.PenLineCap]::Round
    $handPen.Freeze()

    $context.DrawLine($handPen, [System.Windows.Point]::new($cx, $cy), [System.Windows.Point]::new($cx, ($cy - 1.8)))
    $context.DrawLine($handPen, [System.Windows.Point]::new($cx, $cy), [System.Windows.Point]::new(($cx + 1.5), ($cy + 0.9)))

    $context.Close()
    $surface.Render($visual)
    $surface.Freeze()
    return $surface
}

# Locate and load the associated XAML definition that describes the UI layout.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$xamlPath  = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.Icons.xaml'

if (-not (Test-Path -LiteralPath $xamlPath -PathType Leaf)) {
    throw "Main window XAML file was not found: '$xamlPath'."
}

$reader = $null
try {
    $xamlText = Get-Content -LiteralPath $xamlPath -Raw -ErrorAction Stop
    [xml]$xaml = $xamlText
    $reader = New-XamlXmlNodeReader -XmlDocument $xaml -Context 'Main window XAML'
    $window = [Windows.Markup.XamlReader]::Load($reader)
}
catch {
    [System.Windows.MessageBox]::Show(
        "Main window XAML failed to load from '$xamlPath'.`r`n$($_.Exception.Message)",
        'Touch Files Startup Error',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
    throw
}
finally {
    if ($reader) { $reader.Dispose() }
}

if (-not $window) {
    throw "Main window XAML failed to load from '$xamlPath'."
}

$windowIcon = New-WindowFolderClockIcon
if ($windowIcon) {
    $window.Icon = $windowIcon
}

# Cache key WPF controls for later event wiring and state updates.
$imgAppIconLarge = $window.FindName('ImgAppIconLarge')
$headerClickArea = $window.FindName('HeaderClickArea')
$headerLogoBorder = $window.FindName('HeaderLogoBorder')
$txtAppTitle = $window.FindName('TxtAppTitle')
$btnDockNarrow = $window.FindName('BtnDockNarrow')
$btnDockHalf = $window.FindName('BtnDockHalf')
$btnNextMonitor = $window.FindName('BtnNextMonitor')
$btnAbout = $window.FindName('BtnAbout')
if ($btnAbout) {
    Write-TraceLog -Message 'BtnAbout button found and cached' -Level INFO
    $scriptPathForTooltip = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptPathForTooltip)) {
        $scriptPathForTooltip = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.Icons.ps1'
    }
    $btnAbout.ToolTip = "About Touch Files`n$scriptPathForTooltip"
}
else {
    Write-TraceLog -Message 'WARNING: BtnAbout button not found in XAML' -Level WARN
}
$btnAdd    = $window.FindName('BtnAdd')
$btnTouch  = $window.FindName('BtnTouch')
$btnToggle = $window.FindName('BtnToggleCompression')
$btnEnc    = $window.FindName('BtnToggleEncryption')
$btnReadOnly = $window.FindName('BtnToggleReadOnly')
$btnDateStamp = $window.FindName('BtnDateStamp')
$btnHidden = $window.FindName('BtnToggleHidden')
$btnClear  = $window.FindName('BtnClear')
$btnRefresh = $null
$fileList  = $window.FindName('FileListView')
$fileCardList = $window.FindName('FileCardList')
$fileTableBorder = $window.FindName('FileTableBorder')
$fileCardBorder = $window.FindName('FileCardBorder')
$instructionRow = $window.FindName('InstructionRow')
$lblStatus = $window.FindName('LblStatus')
$lblSelectedStatus = $window.FindName('LblSelectedStatus')
$lblNow    = $window.FindName('LblNow')
$btnErrorLog = $window.FindName('BtnErrorLog')
$errorDot = $window.FindName('ErrorDot')
$lblDiagnostics = $window.FindName('LblDiagnostics')
$lblWindowMetrics = $window.FindName('LblWindowMetrics')
$footerWrapPanel = $window.FindName('FooterWrapPanel')
$chkSelectAll = $window.FindName('ChkSelectAll')
$chkCompactMode = $window.FindName('ChkCompactMode')
$chkClearOnDrop = $window.FindName('ChkClearOnDrop')
$script:chkRememberWindow = $window.FindName('ChkRememberWindow')
$chkAlwaysOnTop = $window.FindName('ChkAlwaysOnTop')
$btnCommentDiag = $window.FindName('BtnCommentDiag')
$btnVersionHistory = $null
$txtLastErrorId = $null
$btnCopyLastErrorId = $null

if ($btnAbout -and ($btnAbout.Parent -is [System.Windows.Controls.Panel])) {
    $btnVersionHistory = New-Object System.Windows.Controls.Button
    if ($btnAbout.Style) { $btnVersionHistory.Style = $btnAbout.Style }
    if ($btnAbout.FontFamily) { $btnVersionHistory.FontFamily = $btnAbout.FontFamily }
    $btnVersionHistory.Width = 26
    $btnVersionHistory.Height = 26
    $btnVersionHistory.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
    $btnVersionHistory.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $btnVersionHistory.FontSize = 12
    $btnVersionHistory.FontWeight = [System.Windows.FontWeights]::SemiBold
    $btnVersionHistory.Content = 'V'
    $btnVersionHistory.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnVersionHistory.ToolTip = 'Append version metrics row to Icons.versions.md'

    $headerButtonPanel = [System.Windows.Controls.Panel]$btnAbout.Parent
    $insertAt = $headerButtonPanel.Children.IndexOf($btnAbout)
    if ($insertAt -ge 0) {
        $headerButtonPanel.Children.Insert($insertAt, $btnVersionHistory)
    }
    else {
        [void]$headerButtonPanel.Children.Add($btnVersionHistory)
    }
}

if ($btnClear -and ($btnClear.Parent -is [System.Windows.Controls.Panel])) {
    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Name = 'BtnRefresh'
    if ($btnClear.Style) { $btnRefresh.Style = $btnClear.Style }
    $btnRefresh.Content = 'Refresh'
    $btnRefresh.Tag = [string][char]0xE72C
    $btnRefresh.ToolTip = 'Refresh all entries, whether seelected or not. Selections are kept'

    $commandPanel = [System.Windows.Controls.Panel]$btnClear.Parent
    $clearIndex = $commandPanel.Children.IndexOf($btnClear)
    if ($clearIndex -ge 0) {
        $commandPanel.Children.Insert($clearIndex, $btnRefresh)
    }
    else {
        [void]$commandPanel.Children.Add($btnRefresh)
    }
}

if ($imgAppIconLarge -and $windowIcon) {
    $imgAppIconLarge.Source = $windowIcon
}

if ($footerWrapPanel -and ($footerWrapPanel -is [System.Windows.Controls.Panel])) {
    $errorIdBanner = New-Object System.Windows.Controls.Border
    $errorIdBanner.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
    $errorIdBanner.Padding = New-Object System.Windows.Thickness(6, 1, 6, 1)
    $errorIdBanner.CornerRadius = New-Object System.Windows.CornerRadius(4)
    $errorIdBanner.BorderThickness = New-Object System.Windows.Thickness(1)
    $errorIdBanner.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xCF, 0xD7, 0xDF))
    $errorIdBanner.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xF5, 0xF7, 0xFA))

    $errorIdRow = New-Object System.Windows.Controls.StackPanel
    $errorIdRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal

    $lblErrorIdPrefix = New-Object System.Windows.Controls.TextBlock
    $lblErrorIdPrefix.Text = 'ErrID:'
    $lblErrorIdPrefix.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
    $lblErrorIdPrefix.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $lblErrorIdPrefix.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0x55, 0x55, 0x55))
    [void]$errorIdRow.Children.Add($lblErrorIdPrefix)

    $txtLastErrorId = New-Object System.Windows.Controls.TextBox
    $txtLastErrorId.Text = 'none'
    $txtLastErrorId.Width = 190
    $txtLastErrorId.Height = 20
    $txtLastErrorId.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
    $txtLastErrorId.IsReadOnly = $true
    $txtLastErrorId.IsReadOnlyCaretVisible = $true
    $txtLastErrorId.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
    $txtLastErrorId.FontFamily = New-Object System.Windows.Media.FontFamily('Consolas')
    $txtLastErrorId.FontSize = 11
    $txtLastErrorId.ToolTip = 'Latest error ID. Select and copy, or use Copy.'
    [void]$errorIdRow.Children.Add($txtLastErrorId)

    $btnCopyLastErrorId = New-Object System.Windows.Controls.Button
    $btnCopyLastErrorId.Content = 'Copy'
    $btnCopyLastErrorId.MinWidth = 40
    $btnCopyLastErrorId.Height = 20
    $btnCopyLastErrorId.Padding = New-Object System.Windows.Thickness(4, 0, 4, 0)
    $btnCopyLastErrorId.ToolTip = 'Copy latest error ID to clipboard.'
    $btnCopyLastErrorId.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnCopyLastErrorId.IsEnabled = $false
    [void]$errorIdRow.Children.Add($btnCopyLastErrorId)

    $errorIdBanner.Child = $errorIdRow

    if ($lblWindowMetrics) {
        $insertIndex = $footerWrapPanel.Children.IndexOf($lblWindowMetrics)
        if ($insertIndex -ge 0) {
            $footerWrapPanel.Children.Insert($insertIndex, $errorIdBanner)
        }
        else {
            [void]$footerWrapPanel.Children.Add($errorIdBanner)
        }
    }
    else {
        [void]$footerWrapPanel.Children.Add($errorIdBanner)
    }

    $btnCopyLastErrorId.Add_Click({
        try {
            if ($txtLastErrorId -and -not [string]::IsNullOrWhiteSpace($txtLastErrorId.Text) -and $txtLastErrorId.Text -ne 'none') {
                if (Get-Command -Name Set-Clipboard -ErrorAction SilentlyContinue) {
                    Set-Clipboard -Value $txtLastErrorId.Text
                }
                else {
                    [System.Windows.Clipboard]::SetText($txtLastErrorId.Text)
                }
            }
        }
        catch {
            Add-ErrorLog -Context 'Copy latest error ID failed' -ErrorRecord $_
        }
    })
}

# Flags support suppressing re-entrant events when bulk-updating selection state.
$script:suppressSelectAllEvent = $false
$script:bulkSelectionUpdate   = $false
$script:compactMode           = $false
$script:errorLogEntries       = New-Object 'System.Collections.ObjectModel.ObservableCollection[string]'
$script:errorLogWindow        = $null
$script:errorListBox          = $null
$script:transcriptTextBox     = $null
$script:sessionOutputEntries  = New-Object 'System.Collections.ObjectModel.ObservableCollection[string]'
$script:sessionTranscriptPath = Join-Path $env:TEMP ("TouchFiles-session-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:sessionTranscriptActive = $false
$script:sessionTranscriptStartError = $null
$script:windowMetricsHideTimer = $null
$script:windowMetricsOverlayWindow = $null
$script:windowMetricsOverlayTextTop = $null
$script:windowMetricsOverlayTextBottom = $null
$script:windowMetricsOverlayTextThird = $null
$script:windowMetricsOverlayTextFourth = $null
$script:windowMetricsOverlayWidthPercent = 0.385
$script:windowMetricsOverlayMinWidth = 209
$script:windowMetricsOverlayMaxWidth = 462
$script:windowMetricsOverlayWidthLocked = $false
$script:dockMode = 'none'
$script:dockNarrowWidth = 300.0
$script:windowOverlayDimOpacity = 0.72
$script:windowDimmedForOverlay = $false
$script:mainWindowBaseOpacity = 1.0
$script:windowSettingsPath = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.window.json'
$script:versionsHistoryPath = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.Icons.versions.md'
$script:commandButtonDefaults = @{}
$script:iconOnlyButtonWidth = 44
$script:commentSupportedEmoji = '✅'
$script:commentNotSupportedEmoji = '🚫'
$script:lastCommentSource = 'None'
$script:lastCommentWriteVerification = @{}
$script:lastErrorId = $null
$script:errorSequence = 0
$script:loadCommentsDuringAdd = ($env:TOUCHFILES_LOAD_COMMENTS_ON_ADD -eq '1')
$script:refreshInProgress = $false
$script:refreshTimer = $null

function Write-SessionOutput {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    if ([string]::IsNullOrWhiteSpace($Message)) { return }
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $script:sessionOutputEntries.Add("[$stamp] [$Level] # ▶️ $Message")

    if ($script:errorLogWindow -and $script:errorLogWindow.IsVisible) {
        Refresh-ErrorLogWindowContent
    }
}

function Get-VersionHistoryMetrics {
    param(
        [string]$Ps1Path,
        [string]$MdPath,
        [string]$XamlPath,
        [string]$JsonPath
    )

    foreach ($path in @($Ps1Path, $MdPath, $XamlPath, $JsonPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required file not found: $path"
        }
    }

    $ps1Lines = (Get-Content -LiteralPath $Ps1Path).Count
    $mdLines = (Get-Content -LiteralPath $MdPath).Count
    $xamlLines = (Get-Content -LiteralPath $XamlPath).Count
    $jsonLines = (Get-Content -LiteralPath $JsonPath).Count
    $functionCount = (Select-String -LiteralPath $Ps1Path -Pattern '^\s*function\s+[A-Za-z0-9_-]+' -AllMatches).Count
    [xml]$xamlXml = Get-Content -LiteralPath $XamlPath -Raw
    $xamlElementCount = $xamlXml.SelectNodes('//*').Count

    [ordered]@{
        Date = (Get-Date).ToString('yyyy-MM-dd')
        Ps1Lines = $ps1Lines
        MdLines = $mdLines
        XamlLines = $xamlLines
        JsonLines = $jsonLines
        Ps1Functions = $functionCount
        XamlElements = $xamlElementCount
    }
}

function Ensure-VersionsHistoryFile {
    param([string]$VersionsPath)

    if (Test-Path -LiteralPath $VersionsPath -PathType Leaf) {
        return
    }

    $scaffold = @(
        '# WpfTouchFiles5ChatGPT v6 June2026 Icons - Versions',
        '',
        'This file is an append-only version history for the Icons build.',
        '',
        '## Version History',
        '',
        '| Date | Version | PS1 Lines | MD Lines | XAML Lines | JSON Lines | PS1 Functions | XAML Elements | Notes |',
        '|---|---|---:|---:|---:|---:|---:|---:|---|',
        '',
        '## Append Template',
        '',
        '| YYYY-MM-DD | vX.Y.Z-icons | 0 | 0 | 0 | 0 | 0 | 0 | short change note |'
    )
    Set-Content -LiteralPath $VersionsPath -Value $scaffold -Encoding UTF8
}

function Add-VersionHistorySnapshot {
    param(
        [string]$Version,
        [string]$Notes = 'Auto snapshot from app button.'
    )

    try {
        $ps1Path = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.Icons.ps1'
        $mdPath = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.Icons.md'
        $xamlPathLocal = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.Icons.xaml'
        $jsonPath = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.window.json'

        Ensure-VersionsHistoryFile -VersionsPath $script:versionsHistoryPath
        $metrics = Get-VersionHistoryMetrics -Ps1Path $ps1Path -MdPath $mdPath -XamlPath $xamlPathLocal -JsonPath $jsonPath

        $versionText = if ([string]::IsNullOrWhiteSpace($Version)) {
            "v6.June2026-icons-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
        }
        else {
            $Version.Trim()
        }

        $noteText = if ([string]::IsNullOrWhiteSpace($Notes)) {
            'Auto snapshot from app button.'
        }
        else {
            $Notes.Trim()
        }
        $noteText = $noteText -replace '\|', '/'

        $row = "| $($metrics.Date) | $versionText | $($metrics.Ps1Lines) | $($metrics.MdLines) | $($metrics.XamlLines) | $($metrics.JsonLines) | $($metrics.Ps1Functions) | $($metrics.XamlElements) | $noteText |"

        $content = Get-Content -LiteralPath $script:versionsHistoryPath
        $appendTemplateIndex = [Array]::IndexOf($content, '## Append Template')
        $insertIndex = $content.Count

        if ($appendTemplateIndex -ge 0) {
            $lastTableRowIndex = -1
            for ($i = 0; $i -lt $appendTemplateIndex; $i++) {
                if ($content[$i] -match '^\|') {
                    $lastTableRowIndex = $i
                }
            }

            if ($lastTableRowIndex -ge 0) {
                $insertIndex = $lastTableRowIndex + 1
            }
            else {
                $insertIndex = $appendTemplateIndex
            }
        }

        $newContent = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $content.Count; $i++) {
            if ($i -eq $insertIndex) {
                [void]$newContent.Add($row)
            }
            [void]$newContent.Add($content[$i])
        }

        if ($insertIndex -ge $content.Count) {
            [void]$newContent.Add($row)
        }

        Set-Content -LiteralPath $script:versionsHistoryPath -Value $newContent -Encoding UTF8
        Write-SessionOutput -Message "Version snapshot appended to $script:versionsHistoryPath"
        if ($lblStatus) {
            $lblStatus.Text = "Version row appended: $versionText"
        }
        return $true
    }
    catch {
        Add-ErrorLog -Context 'Version snapshot append failed' -ErrorRecord $_
        return $false
    }
}

try {
    Start-Transcript -LiteralPath $script:sessionTranscriptPath -ErrorAction Stop | Out-Null
    $script:sessionTranscriptActive = $true
}
catch {
    $script:sessionTranscriptActive = $false
    $script:sessionTranscriptStartError = $_.Exception.Message
}

if ($script:sessionTranscriptActive) {
    Write-SessionOutput -Message "Session started. Transcript active at $script:sessionTranscriptPath"
}
else {
    Write-SessionOutput -Level WARN -Message 'Session started. Transcript is not active in this host.'
    if ($script:sessionTranscriptStartError) {
        Write-SessionOutput -Level WARN -Message "Transcript start error: $($script:sessionTranscriptStartError)"
    }
}

# Milliseconds to keep move/resize metrics visible after user interaction stops.
$script:windowMetricsHideDelayMs = 850

# Monitor item property changes so UI state stays in sync with checkbox toggles.
$itemPropertyChangedHandler   = [System.ComponentModel.PropertyChangedEventHandler]{
    param($sourceObject,$changeArgs)
    if ($changeArgs.PropertyName -eq 'IsSelected' -and -not $script:bulkSelectionUpdate) {
        Update-UiState
    }
}

# Backing collection for the ListView; supports binding and change notifications.
$fileItems = New-Object 'System.Collections.ObjectModel.ObservableCollection[TouchFileItemV20260623]'
$fileList.ItemsSource = $fileItems
if ($fileCardList) { $fileCardList.ItemsSource = $fileItems }
$collectionView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($fileItems)

# Convenience accessor to force bindings to refresh when data changes.
function Update-View { $collectionView.Refresh() }

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

# Show diagnostics text only when the window has enough horizontal space.
function Update-DiagnosticsVisibility {
    if (-not $lblDiagnostics) { return }
    $lblDiagnostics.Visibility = if ($window.ActualWidth -ge 640) {
        [System.Windows.Visibility]::Visible
    }
    else {
        [System.Windows.Visibility]::Collapsed
    }
}

<#
.SYNOPSIS
    Reads saved window placement settings.

.DESCRIPTION
    Loads persisted window size/location JSON from disk when available. Returns
    null if the file is missing or unreadable.

.OUTPUTS
    PSCustomObject
#>
function Get-WindowSettings {
    if (-not (Test-Path -LiteralPath $script:windowSettingsPath -PathType Leaf)) { return $null }
    try {
        Get-Content -LiteralPath $script:windowSettingsPath -Raw | ConvertFrom-Json
    }
    catch {
        Add-ErrorLog -Context 'Window settings read failed' -ErrorRecord $_
        $null
    }
}

<#
.SYNOPSIS
    Saves window remember-state and placement.

.DESCRIPTION
    Persists the checkbox state and current window size/location to JSON so the
    next script launch can restore placement.
#>
function Save-WindowSettings {
    $remember = $script:chkRememberWindow -and ($script:chkRememberWindow.IsChecked -eq $true)
    $compactMode = $chkCompactMode -and ($chkCompactMode.IsChecked -eq $true)
    $clearBeforeDrop = $chkClearOnDrop -and ($chkClearOnDrop.IsChecked -eq $true)
    $alwaysOnTop = $chkAlwaysOnTop -and ($chkAlwaysOnTop.IsChecked -eq $true)

    $data = [ordered]@{
        RememberWindow = $remember
        CompactMode = $compactMode
        ClearBeforeDrop = $clearBeforeDrop
        AlwaysOnTop = $alwaysOnTop
        Width = [double][Math]::Round($window.ActualWidth, 2)
        Height = [double][Math]::Round($window.ActualHeight, 2)
        Left = [double][Math]::Round($window.Left, 2)
        Top = [double][Math]::Round($window.Top, 2)
    }

    try {
        $json = $data | ConvertTo-Json
        Set-Content -LiteralPath $script:windowSettingsPath -Value $json -Encoding UTF8
    }
    catch {
        Add-ErrorLog -Context 'Window settings save failed' -ErrorRecord $_
    }
}

<#
.SYNOPSIS
    Restores window placement from saved settings.

.DESCRIPTION
    Applies saved bounds only when remember-state is enabled and all coordinates
    are valid. Constrains restored position to the visible work area.
#>
function Restore-WindowSettings {
    $settings = Get-WindowSettings
    if (-not $settings) { return }

    $remember = ($settings.RememberWindow -eq $true)
    if ($script:chkRememberWindow) {
        $script:chkRememberWindow.IsChecked = $remember
    }

    if ($chkCompactMode -and $null -ne $settings.CompactMode) {
        $chkCompactMode.IsChecked = ($settings.CompactMode -eq $true)
    }
    if ($chkClearOnDrop -and $null -ne $settings.ClearBeforeDrop) {
        $chkClearOnDrop.IsChecked = ($settings.ClearBeforeDrop -eq $true)
    }
    if ($chkAlwaysOnTop -and $null -ne $settings.AlwaysOnTop) {
        $chkAlwaysOnTop.IsChecked = ($settings.AlwaysOnTop -eq $true)
    }

    if ($chkAlwaysOnTop) {
        $window.Topmost = ($chkAlwaysOnTop.IsChecked -eq $true)
    }
    $script:compactMode = $chkCompactMode -and ($chkCompactMode.IsChecked -eq $true)
    Set-PathVisibility -HidePaths $script:compactMode

    if (-not $remember) { return }
    if ($null -eq $settings.Width -or $null -eq $settings.Height -or $null -eq $settings.Left -or $null -eq $settings.Top) { return }

    $workArea = [System.Windows.SystemParameters]::WorkArea
    $targetWidth = [Math]::Min([Math]::Max([double]$settings.Width, $window.MinWidth), $workArea.Width)
    $targetHeight = [Math]::Min([Math]::Max([double]$settings.Height, $window.MinHeight), $workArea.Height)
    $maxLeft = $workArea.X + $workArea.Width - $targetWidth
    $maxTop = $workArea.Y + $workArea.Height - $targetHeight
    $targetLeft = [Math]::Min([Math]::Max([double]$settings.Left, $workArea.X), $maxLeft)
    $targetTop = [Math]::Min([Math]::Max([double]$settings.Top, $workArea.Y), $maxTop)

    $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $window.Width = $targetWidth
    $window.Height = $targetHeight
    $window.Left = $targetLeft
    $window.Top = $targetTop
}

# Resolve the monitor that currently hosts the main window.
function Get-CurrentMonitor {
    try {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
        if ($helper.Handle -ne [IntPtr]::Zero) {
            return [System.Windows.Forms.Screen]::FromHandle($helper.Handle)
        }
    }
    catch {
        # Fall back to primary monitor.
    }
    return [System.Windows.Forms.Screen]::PrimaryScreen
}

# Resolve current WPF DPI scale so monitor pixel coordinates can be translated safely.
function Get-WindowDpiScale {
    try {
        $dpi = [System.Windows.Media.VisualTreeHelper]::GetDpi($window)
        return [PSCustomObject]@{
            X = [double]$dpi.DpiScaleX
            Y = [double]$dpi.DpiScaleY
        }
    }
    catch {
        return [PSCustomObject]@{ X = 1.0; Y = 1.0 }
    }
}

# Convert a WinForms screen working rectangle (pixels) into WPF DIPs.
function Convert-ScreenWorkingAreaToDip {
    param([System.Drawing.Rectangle]$WorkingArea)

    $scale = Get-WindowDpiScale
    [PSCustomObject]@{
        Left = [double]$WorkingArea.Left / $scale.X
        Top = [double]$WorkingArea.Top / $scale.Y
        Width = [double]$WorkingArea.Width / $scale.X
        Height = [double]$WorkingArea.Height / $scale.Y
    }
}

# Convert a desired pixel width into WPF DIPs for accurate docking width.
function Convert-PixelsToDipX {
    param([double]$Pixels)
    $scale = Get-WindowDpiScale
    if ($scale.X -le 0) { return $Pixels }
    return [double]$Pixels / $scale.X
}

# Enforce minimum window width using a pixel-based constant, converted to WPF DIPs.
function Set-WindowMinimumWidth {
    if (-not $window) { return }

    $minWidthDip = Convert-PixelsToDipX -Pixels $script:mainWindowMinWidthPixels
    if ($minWidthDip -le 0) { $minWidthDip = $script:mainWindowMinWidthPixels }

    $window.MinWidth = [double][Math]::Round($minWidthDip, 2)
}

# Return the next monitor in sequence, wrapping from last back to first.
function Get-NextMonitor {
    $screens = [System.Windows.Forms.Screen]::AllScreens
    if (-not $screens -or $screens.Count -eq 0) {
        return [System.Windows.Forms.Screen]::PrimaryScreen
    }

    $current = Get-CurrentMonitor
    $index = 0
    for ($i = 0; $i -lt $screens.Count; $i++) {
        if ($screens[$i].DeviceName -eq $current.DeviceName) {
            $index = $i
            break
        }
    }

    $nextIndex = ($index + 1) % $screens.Count
    return $screens[$nextIndex]
}

# Dock the window to a monitor edge using predefined layouts.
function Set-WindowDockMode {
    param(
        [ValidateSet('narrow-left','narrow-right','half-left','half-right')]
        [string]$Mode,
        [System.Windows.Forms.Screen]$Screen
    )

    if (-not $Screen) { $Screen = Get-CurrentMonitor }
    if (-not $Screen) { return }

    Set-WindowMinimumWidth

    $work = Convert-ScreenWorkingAreaToDip -WorkingArea $Screen.WorkingArea
    $workLeft = [double]$work.Left
    $workTop = [double]$work.Top
    $workWidth = [double]$work.Width
    $workHeight = [double]$work.Height
    # Use a literal WPF width value for narrow docking (no DPI conversion).
    $dockNarrowWidthDip = [double]$script:dockNarrowWidth

    $targetWidth = switch ($Mode) {
        'narrow-left'  { [Math]::Max($window.MinWidth, [Math]::Min($dockNarrowWidthDip, $workWidth)) }
        'narrow-right' { [Math]::Max($window.MinWidth, [Math]::Min($dockNarrowWidthDip, $workWidth)) }
        'half-left'    { [Math]::Max($window.MinWidth, [Math]::Round($workWidth / 2, 0)) }
        'half-right'   { [Math]::Max($window.MinWidth, [Math]::Round($workWidth / 2, 0)) }
    }

    if ($targetWidth -gt $workWidth) { $targetWidth = $workWidth }

    $targetLeft = if ($Mode -in @('narrow-right','half-right')) {
        $workLeft + $workWidth - $targetWidth
    }
    else {
        $workLeft
    }

    $window.WindowState = [System.Windows.WindowState]::Normal
    $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $window.Width = $targetWidth
    $window.Height = [Math]::Max($window.MinHeight, $workHeight)
    $window.Left = $targetLeft
    $window.Top = $workTop

    $script:dockMode = $Mode
    Save-WindowSettings
}

# Move window to the next monitor while preserving active dock mode when present.
function Move-WindowToNextMonitor {
    $next = Get-NextMonitor
    if (-not $next) { return }

    Set-WindowMinimumWidth

    if ($script:dockMode -in @('narrow-left','narrow-right','half-left','half-right')) {
        Set-WindowDockMode -Mode $script:dockMode -Screen $next
        return
    }

    $current = Get-CurrentMonitor
    $curWork = if ($current) { Convert-ScreenWorkingAreaToDip -WorkingArea $current.WorkingArea } else { $null }
    $nextWork = Convert-ScreenWorkingAreaToDip -WorkingArea $next.WorkingArea

    $window.WindowState = [System.Windows.WindowState]::Normal
    $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual

    $newWidth = [Math]::Min($window.Width, [double]$nextWork.Width)
    $newHeight = [Math]::Min($window.Height, [double]$nextWork.Height)

    $denX = 1.0
    $denY = 1.0
    $relX = 0.0
    $relY = 0.0
    if ($curWork) {
        $denX = [Math]::Max(1.0, ([double]$curWork.Width - [double]$window.Width))
        $denY = [Math]::Max(1.0, ([double]$curWork.Height - [double]$window.Height))
        $relX = ([double]$window.Left - [double]$curWork.Left) / $denX
        $relY = ([double]$window.Top - [double]$curWork.Top) / $denY
    }

    if ($relX -lt 0) { $relX = 0 }
    if ($relX -gt 1) { $relX = 1 }
    if ($relY -lt 0) { $relY = 0 }
    if ($relY -gt 1) { $relY = 1 }

    $maxLeft = [double]$nextWork.Left + [double]$nextWork.Width - $newWidth
    $maxTop = [double]$nextWork.Top + [double]$nextWork.Height - $newHeight
    $newLeft = [double]$nextWork.Left + ($relX * [Math]::Max(1.0, ([double]$nextWork.Width - $newWidth)))
    $newTop = [double]$nextWork.Top + ($relY * [Math]::Max(1.0, ([double]$nextWork.Height - $newHeight)))
    $newLeft = [Math]::Max([double]$nextWork.Left, [Math]::Min($newLeft, $maxLeft))
    $newTop = [Math]::Max([double]$nextWork.Top, [Math]::Min($newTop, $maxTop))

    $window.Width = $newWidth
    $window.Height = $newHeight
    $window.Left = $newLeft
    $window.Top = $newTop
    Save-WindowSettings
}

# Convert byte counts to human-readable MB/GB strings for About details.
function Format-MemorySize {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    return '{0:N2} MB' -f ($Bytes / 1MB)
}

# Build a best-effort changelog for edits in the last 7 days.
function Get-RecentChangesText {
    param(
        [DateTime]$Since,
        [string]$ScriptFile,
        [string]$XamlFile
    )

    $sinceStamp = $Since.ToString('yyyy-MM-dd')
    $targetNames = @([System.IO.Path]::GetFileName($ScriptFile), [System.IO.Path]::GetFileName($XamlFile))

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add("File timestamp summary (git history disabled for performance):")
    $lines.Add('')
    foreach ($path in @($ScriptFile, $XamlFile)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
            if ($item) {
                $changed = if ($item.LastWriteTime -ge $Since) { 'Updated within 7 days' } else { 'No update in last 7 days' }
                $lines.Add(("{0}: {1} ({2})" -f $item.Name, $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $changed))
            }
        }
    }

    return ($lines -join [Environment]::NewLine)
}

# Build and display an About dialog with runtime, platform, and change details.
function Show-AboutDialog {
    Write-TraceLog -Message "=== Show-AboutDialog function called ===" -Level INFO
    try {
        Write-TraceLog -Message "Inside try block, starting About dialog generation" -Level INFO
        $scriptPathForAbout = $PSCommandPath
        if ([string]::IsNullOrWhiteSpace($scriptPathForAbout)) {
            $scriptPathForAbout = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT.v6.June2026.Icons.ps1'
        }

        $scriptItem = if (Test-Path -LiteralPath $scriptPathForAbout -PathType Leaf) {
            Get-Item -LiteralPath $scriptPathForAbout -ErrorAction SilentlyContinue
        }
        else {
            $null
        }

        $xamlItem = if (Test-Path -LiteralPath $xamlPath -PathType Leaf) {
            Get-Item -LiteralPath $xamlPath -ErrorAction SilentlyContinue
        }
        else {
            $null
        }

        $psVersion = if ($PSVersionTable -and $PSVersionTable.PSVersion) {
            $PSVersionTable.PSVersion.ToString()
        }
        else {
            'Unknown'
        }

        $osText = if ([System.Environment]::OSVersion) {
            [System.Environment]::OSVersion.VersionString
        }
        else {
            'Unknown'
        }
        $osInfo = $null
        try {
            $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop -OperationTimeoutSec 2
            if ($osInfo -and $osInfo.Caption) {
                $osText = "{0} (Build {1})" -f $osInfo.Caption, $osInfo.BuildNumber
            }
        }
        catch {
            # Keep fallback OS text.
        }

        $wpfVersion = 'Unknown'
        try {
            $wpfVersion = ([System.Reflection.Assembly]::GetAssembly([System.Windows.Window]).GetName().Version).ToString()
        }
        catch {
            # Keep unknown when reflection fails.
        }

        $dotNetVersion = if ([System.Environment]::Version) {
            [System.Environment]::Version.ToString()
        }
        else {
            'Unknown'
        }
        try {
            $dotNetRuntime = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
            if (-not [string]::IsNullOrWhiteSpace($dotNetRuntime)) {
                $dotNetVersion = "$dotNetVersion ($dotNetRuntime)"
            }
        }
        catch {
            # Keep fallback runtime text.
        }

        $freePhysicalBytes = [double]0
        $freePhysicalText = 'Unknown'
        try {
            if ($osInfo -and $null -ne $osInfo.FreePhysicalMemory) {
                $freePhysicalBytes = [double]$osInfo.FreePhysicalMemory * 1KB
                $freePhysicalText = Format-MemorySize -Bytes $freePhysicalBytes
            }
            elseif ($null -eq $osInfo) {
                $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop -OperationTimeoutSec 2
                if ($osInfo -and $null -ne $osInfo.FreePhysicalMemory) {
                    $freePhysicalBytes = [double]$osInfo.FreePhysicalMemory * 1KB
                    $freePhysicalText = Format-MemorySize -Bytes $freePhysicalBytes
                }
            }
        }
        catch {
            # Keep unknown memory values.
        }

        $psProcess = Get-Process -Id $PID -ErrorAction SilentlyContinue
        $psWorkingSetText = 'Unknown'
        $psPrivateText = 'Unknown'
        if ($psProcess) {
            $psWorkingSetText = Format-MemorySize -Bytes ([double]$psProcess.WorkingSet64)
            $psPrivateText = Format-MemorySize -Bytes ([double]$psProcess.PrivateMemorySize64)
        }

        $availableToPsText = $freePhysicalText

        $changesText = 'No change entries available'
        try {
            $changesText = Get-RecentChangesText -Since ((Get-Date).AddDays(-7)) -ScriptFile $scriptPathForAbout -XamlFile $xamlPath
        }
        catch {
            $changesText = "Unable to read change history: $($_.Exception.Message)"
        }

        $ps1ModifiedText = if ($scriptItem) {
            $scriptItem.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        }
        else {
            'Unknown'
        }

        $xamlModifiedText = if ($xamlItem) {
            $xamlItem.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        }
        else {
            'Unknown'
        }

        $psMemoryText = "Working set: $psWorkingSetText   Private: $psPrivateText"
        $featureSummaryText = @"
    FEATURE SUMMARY

    - Drag/drop and Add File workflows for queueing files
    - Bulk touch operation for Last Modified timestamps
    - Compression, Encryption, and Hidden attribute toggles
    - Editable file comments with metadata and ADS fallback paths
    - Single-file comment diagnostics with copyable report
    - Error log window with transcript view
    - Responsive table/card layouts for wide and narrow windows
    - Docking shortcuts, next-monitor move, and persisted window settings
    - Version snapshot append button and version history markdown tracking
    "@
        $knownBugsFutureText = @"
    KNOWN BUGS, FUTURE ENHANCEMENTS

    Known Bugs:
    - Comments still do not write for some Word file scenarios.
    - Shell metadata visibility can differ from COM/OpenXML values by file type.

    Future Enhancements:
    - Add per-source success/failure badges for comment write paths.
    - Add retry path using alternate Word save format options.
    - Add an explicit Save Comment button for deterministic commit.
    - Add background async refresh option for very large file lists.
    - Add export button for diagnostics and verification history.
    "@

        $stamp = Get-Date
        $stampText = $stamp.ToString('dddd, yyyy-MM-dd HH:mm:ss')
        $clipboardLines = New-Object 'System.Collections.Generic.List[string]'
        $clipboardLines.Add('📋 Touch Files About Report')
        $clipboardLines.Add("Generated: $stampText")
        $clipboardLines.Add('')
        $clipboardLines.Add('=== System and Runtime Info ===')
        $clipboardLines.Add("Script path: $scriptPathForAbout")
        $clipboardLines.Add("PS1 last modified: $ps1ModifiedText")
        $clipboardLines.Add("XAML last modified: $xamlModifiedText")
        $clipboardLines.Add("PowerShell version: $psVersion")
        $clipboardLines.Add("Windows version: $osText")
        $clipboardLines.Add("WPF version: $wpfVersion")
        $clipboardLines.Add(".NET version: $dotNetVersion")
        $clipboardLines.Add("Free system memory: $freePhysicalText")
        $clipboardLines.Add("PowerShell memory in use: $psMemoryText")
        $clipboardLines.Add("Memory available to PowerShell: $availableToPsText")
        $clipboardLines.Add('')
        $clipboardLines.Add('=== Comment Storage ===')
        $clipboardLines.Add('Comments are stored in NTFS Alternate Data Streams (ADS) on the file itself.')
        $clipboardLines.Add('')
        $clipboardLines.Add('Editor policy: supported file types are editable; not supported types are read-only.')
        $clipboardLines.Add('Storage note: ADS can still persist comments on NTFS volumes.')
        $clipboardLines.Add('')
        $clipboardLines.Add('Native metadata support by file type:')
        $clipboardLines.Add("  $($script:commentSupportedEmoji) Office: .docx, .xlsx, .pptx (Title, Subject, Comments fields)")
        $clipboardLines.Add("  $($script:commentSupportedEmoji) Documents: .pdf, .odt, .rtf (embedded metadata)")
        $clipboardLines.Add("  $($script:commentSupportedEmoji) Images: .jpg, .png, .gif, .bmp (EXIF, IPTC, XMP)")
        $clipboardLines.Add("  $($script:commentSupportedEmoji) Audio: .mp3, .wav, .flac, .m4a (ID3, WMA tags)")
        $clipboardLines.Add("  $($script:commentSupportedEmoji) Video: .mp4, .mkv, .avi (embedded metadata)")
        $clipboardLines.Add("  $($script:commentNotSupportedEmoji) Text: .txt (no native metadata)")
        $clipboardLines.Add("  $($script:commentNotSupportedEmoji) Code: .ps1, .py, .js, .cs (no native metadata)")
        $clipboardLines.Add("  $($script:commentNotSupportedEmoji) Executables: .exe, .dll (no native metadata)")
        $clipboardLines.Add("  $($script:commentNotSupportedEmoji) Archives: .zip, .rar, .7z (no native metadata)")
        $clipboardLines.Add('')
        $clipboardLines.Add('=== Version History (last 7 days) ===')
        if ([string]::IsNullOrWhiteSpace($changesText)) {
            $clipboardLines.Add('(No change entries available)')
        }
        else {
            $splitLines = $changesText -split "`r?`n"
            if ($splitLines) {
                $clipboardLines.AddRange($splitLines)
            }
        }
        $clipboardText = $clipboardLines -join [Environment]::NewLine
        $clipLen = if ($clipboardText) { $clipboardText.Length } else { 0 }
        Write-TraceLog -Message "clipboardText created successfully, length: $clipLen" -Level INFO

        Write-TraceLog -Message "Loading About dialog XAML from external file" -Level INFO
        if ([string]::IsNullOrWhiteSpace($scriptDir)) {
            throw "Script directory path is not available."
        }
        $aboutXamlPath = Join-Path $scriptDir 'AboutDialog.xaml'
        Write-TraceLog -Message "About XAML path: $aboutXamlPath" -Level INFO
        if (-not (Test-Path -LiteralPath $aboutXamlPath -PathType Leaf)) {
            throw "About dialog XAML file not found: $aboutXamlPath"
        }
        $aboutXaml = Get-Content -LiteralPath $aboutXamlPath -Raw -ErrorAction Stop
        $xamlLen = if ($aboutXaml) { $aboutXaml.Length } else { 0 }
        Write-TraceLog -Message "About XAML loaded from file, length: $xamlLen" -Level INFO

        Write-TraceLog -Message "About XAML here-string created. Checking variable..." -Level INFO
        Write-TraceLog -Message "aboutXaml null? $($null -eq $aboutXaml), Empty? $([string]::IsNullOrEmpty($aboutXaml)), Whitespace? $([string]::IsNullOrWhiteSpace($aboutXaml))" -Level INFO

        $aboutWindow = $null
        try {
            $xamlType = if ($null -eq $aboutXaml) { 'NULL' } else { $aboutXaml.GetType().Name }
            $xamlLen = if ($null -eq $aboutXaml) { 'N/A' } else { $aboutXaml.Length }
            $xamlNullOrWhitespace = [string]::IsNullOrWhiteSpace($aboutXaml)
            Write-TraceLog -Message "About XAML defined. Type: $xamlType, Length: $xamlLen, IsNullOrWhiteSpace: $xamlNullOrWhitespace" -Level INFO

            if ([string]::IsNullOrWhiteSpace($aboutXaml)) {
                Write-TraceLog -Message "ERROR: About XAML is null or whitespace!" -Level ERROR
                throw 'About XAML string is null or empty.'
            }

            Write-TraceLog -Message "Parsing About XAML..." -Level INFO
            $aboutWindow = [Windows.Markup.XamlReader]::Parse($aboutXaml)
            Write-TraceLog -Message "About XAML parsed successfully" -Level INFO
        }
        catch {
            Write-TraceLog -Message "About XAML Parse failed: $($_.Exception.Message)" -Level ERROR
            if ($aboutXaml) {
                Write-TraceLog -Message "XAML length: $($aboutXaml.Length)" -Level ERROR
                Write-TraceLog -Message "First 200 chars: $($aboutXaml.Substring(0, [Math]::Min(200, $aboutXaml.Length)))" -Level ERROR
            }
            else {
                Write-TraceLog -Message "XAML variable is NULL" -Level ERROR
            }
            throw
        }
        if (-not $aboutWindow) {
            throw 'About XAML load returned null window.'
        }
        $aboutWindow.Owner = $window

        if ($window.Icon) {
            $aboutWindow.Icon = $window.Icon
        }

        $txtScriptPath = $aboutWindow.FindName('TxtScriptPath')
        if ($txtScriptPath) { $txtScriptPath.Text = $scriptPathForAbout }
        $txtPs1Modified = $aboutWindow.FindName('TxtPs1Modified')
        if ($txtPs1Modified) { $txtPs1Modified.Text = $ps1ModifiedText }
        $txtXamlModified = $aboutWindow.FindName('TxtXamlModified')
        if ($txtXamlModified) { $txtXamlModified.Text = $xamlModifiedText }
        $txtPsVersion = $aboutWindow.FindName('TxtPsVersion')
        if ($txtPsVersion) { $txtPsVersion.Text = $psVersion }
        $txtWindowsVersion = $aboutWindow.FindName('TxtWindowsVersion')
        if ($txtWindowsVersion) { $txtWindowsVersion.Text = $osText }
        $txtWpfVersion = $aboutWindow.FindName('TxtWpfVersion')
        if ($txtWpfVersion) { $txtWpfVersion.Text = $wpfVersion }
        $txtDotNetVersion = $aboutWindow.FindName('TxtDotNetVersion')
        if ($txtDotNetVersion) { $txtDotNetVersion.Text = $dotNetVersion }
        $txtFreeMemory = $aboutWindow.FindName('TxtFreeMemory')
        if ($txtFreeMemory) { $txtFreeMemory.Text = $freePhysicalText }
        $txtPowerShellMemory = $aboutWindow.FindName('TxtPowerShellMemory')
        if ($txtPowerShellMemory) { $txtPowerShellMemory.Text = $psMemoryText }
        $txtPowerShellAvailable = $aboutWindow.FindName('TxtPowerShellAvailableMemory')
        if ($txtPowerShellAvailable) { $txtPowerShellAvailable.Text = $availableToPsText }
        $txtRecentChanges = $aboutWindow.FindName('TxtRecentChanges')
        if ($txtRecentChanges) { $txtRecentChanges.Text = $changesText }
        $txtFeatureSummary = $aboutWindow.FindName('TxtFeatureSummary')
        if ($txtFeatureSummary) { $txtFeatureSummary.Text = $featureSummaryText }
        $txtKnownBugsFuture = $aboutWindow.FindName('TxtKnownBugsFuture')
        if ($txtKnownBugsFuture) { $txtKnownBugsFuture.Text = $knownBugsFutureText }

        $fileTypeInfo = @"
COMMENT STORAGE METHOD
Comments are stored in NTFS Alternate Data Streams (ADS) - a file stream named ':TouchFileComment'
This method works on any file on NTFS volumes, regardless of file type.

SUPPORTED FILE TYPES
Editor policy: ✅ supported file types are editable, and 🚫 not supported file types are read-only.
Storage note: ADS can still persist comments on NTFS volumes.

NATIVE METADATA SUPPORT (File Type Specific)
The following file types have native metadata fields in addition to ADS storage:

Office Documents:
    ✅ .docx, .xlsx, .pptx - Title, Subject, Comments, Author, Category
    ✅ .odt (LibreOffice) - Author, Title, Subject

Document Formats:
    ✅ .pdf - PDF metadata (Creator, Producer, Subject, Keywords)
    ✅ .rtf - Embedded properties

Images:
    ✅ .jpg, .jpeg - EXIF, IPTC, XMP metadata
    ✅ .png - PNG metadata (Title, Description, Comment)
    ✅ .gif, .bmp - Limited native support

Audio Files:
    ✅ .mp3 - ID3 tags (Title, Artist, Album, Comment)
    ✅ .wav - LIST INFO chunk (Title, Subject, Comment)
    ✅ .flac - Vorbis comments
    ✅ .m4a - iTunes/MP4 metadata

Video Files:
    ✅ .mp4 - MP4 metadata atoms (Title, Comment)
    ✅ .mkv - Matroska tags (Title, Comments)
    ✅ .avi - AVI metadata

NOT SUPPORTED (No Native Metadata)
    🚫 .txt - Plain text files
    🚫 .ps1, .py, .js, .cs, etc. - Code/script files
    🚫 .exe, .dll - Executables (security/signature concerns)
    🚫 .zip, .rar, .7z - Archive formats
    🚫 Binary files without defined metadata standards

RECOMMENDATION
Use ADS-based comments for universal compatibility. They persist with the file on NTFS volumes
and work with any file type. For file types with native metadata, both storage methods can coexist.
"@
        $txtCommentFileTypes = $aboutWindow.FindName('TxtCommentFileTypes')
        if ($txtCommentFileTypes) { $txtCommentFileTypes.Text = $fileTypeInfo }

        $btnAboutCopy = $aboutWindow.FindName('BtnAboutCopy')
        if ($btnAboutCopy) {
            $textToCopy = $clipboardText
            $btnAboutCopy.Add_Click({
                try {
                    if (-not $textToCopy) {
                        [System.Windows.MessageBox]::Show('No content to copy.', 'Touch Files', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                        return
                    }
                    if (Get-Command -Name Set-Clipboard -ErrorAction SilentlyContinue) {
                        Set-Clipboard -Value $textToCopy
                    }
                    else {
                        [System.Windows.Clipboard]::SetText($textToCopy)
                    }
                    [System.Windows.MessageBox]::Show('About details copied to clipboard.', 'Touch Files', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
                }
                catch {
                    Add-ErrorLog -Context 'Copy About info to clipboard failed' -ErrorRecord $_
                    [System.Windows.MessageBox]::Show('Unable to copy About details to clipboard.', 'Touch Files', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                }
            })
        }

        $btnAboutClose = $aboutWindow.FindName('BtnAboutClose')
        if ($btnAboutClose) {
            $closeDialog = $aboutWindow
            $btnAboutClose.Add_Click({
                if ($closeDialog) {
                    $closeDialog.Close()
                }
            })
        }

        if ($aboutWindow) {
            $aboutWindow.ShowDialog() | Out-Null
        }
    }
    catch {
        Add-ErrorLog -Context 'About dialog failed' -ErrorRecord $_
        [void][System.Windows.MessageBox]::Show(
            "About dialog failed.`r`n$($_.Exception.Message)`r`n`r`nErrorId: $($script:lastErrorId)",
            'Touch Files - About Error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# Calculate the overlay width once from the main window and optionally lock it.
function Set-WindowMetricsOverlayWidth {
    param([bool]$LockWidth = $false)

    if (-not $script:windowMetricsOverlayWindow) { return }

    $targetWidth = [Math]::Round($window.ActualWidth * $script:windowMetricsOverlayWidthPercent)
    $targetWidth = [Math]::Max($script:windowMetricsOverlayMinWidth, [Math]::Min($script:windowMetricsOverlayMaxWidth, $targetWidth))
    if ([Math]::Abs($script:windowMetricsOverlayWindow.Width - $targetWidth) -ge 1) {
        $script:windowMetricsOverlayWindow.Width = $targetWidth
    }

    if ($LockWidth) {
        $script:windowMetricsOverlayWidthLocked = $true
    }
}

# Show live size/position while the window is being resized or moved.
function Update-WindowMetricsText {
    if (-not $lblWindowMetrics) { return }
    $dpiScale = Get-WindowDpiScale

    $wDip = [int][Math]::Round($window.ActualWidth)
    $hDip = [int][Math]::Round($window.ActualHeight)
    $xDip = [int][Math]::Round($window.Left)
    $yDip = [int][Math]::Round($window.Top)

    $wPx = [int][Math]::Round($window.ActualWidth * $dpiScale.X)
    $hPx = [int][Math]::Round($window.ActualHeight * $dpiScale.Y)
    $xPx = [int][Math]::Round($window.Left * $dpiScale.X)
    $yPx = [int][Math]::Round($window.Top * $dpiScale.Y)

    # output text to the floating dialog
    $lblWindowMetrics.Text = "W:$wDip dip/$wPx px H:$hDip dip/$hPx px X:$xDip dip/$xPx px Y:$yDip dip/$yPx px"
#\/
    if ($script:windowMetricsOverlayTextTop) {
        $script:windowMetricsOverlayTextTop.Text = "W:$wDip dip/$wPx px"
    }
    if ($script:windowMetricsOverlayTextBottom) {
        $script:windowMetricsOverlayTextBottom.Text = "H:$hDip dip/$hPx px"
    }
    if ($script:windowMetricsOverlayTextThird) {
        $script:windowMetricsOverlayTextThird.Text = "X:$xDip dip/$xPx px"
    }
    if ($script:windowMetricsOverlayTextFourth) {
        $script:windowMetricsOverlayTextFourth.Text = "Y:$yDip dip/$yPx px"
    }

    if ($script:windowMetricsOverlayWindow -and -not $script:windowMetricsOverlayWidthLocked) {
        Set-WindowMetricsOverlayWidth
    }

    if ($script:windowMetricsOverlayWindow -and $script:windowMetricsOverlayWindow.IsVisible) {
        $overlayX = $window.Left + (($window.ActualWidth - $script:windowMetricsOverlayWindow.ActualWidth) / 2)
        $overlayY = $window.Top + (($window.ActualHeight - $script:windowMetricsOverlayWindow.ActualHeight) / 2)
        $script:windowMetricsOverlayWindow.Left = [Math]::Round($overlayX)
        $script:windowMetricsOverlayWindow.Top = [Math]::Round($overlayY)
    }
}

# Temporarily dim the main window while the overlay is visible.
function Set-MainWindowOverlayDimming {
    param([bool]$Dim)

    if (-not $window) { return }

    if ($Dim) {
        if (-not $script:windowDimmedForOverlay) {
            $script:mainWindowBaseOpacity = $window.Opacity
            $window.Opacity = [Math]::Max(0.2, [Math]::Min(1.0, [double]$script:windowOverlayDimOpacity))
            $script:windowDimmedForOverlay = $true
        }
    }
    else {
        if ($script:windowDimmedForOverlay) {
            $window.Opacity = $script:mainWindowBaseOpacity
            $script:windowDimmedForOverlay = $false
        }
    }
}

# Create a transparent, centered hover badge that mirrors W,H,X,Y in comma format.
function Initialize-WindowMetricsOverlay {
    if ($script:windowMetricsOverlayWindow) { return }

    [xml]$overlayXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Width="340"
    Height="150"
        WindowStyle="None"
        ResizeMode="NoResize"
        AllowsTransparency="True"
        Background="Transparent"
        ShowInTaskbar="False"
        ShowActivated="False"
        Topmost="True"
        IsHitTestVisible="False"
        Focusable="False"
        WindowStartupLocation="Manual">
    <Border CornerRadius="12"
            BorderBrush="#AA1C1C1C"
            BorderThickness="1"
            Background="#CCF9FBFD"
            Padding="8,8">
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="32"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Canvas Grid.Column="0" Width="22" Height="22" HorizontalAlignment="Center" VerticalAlignment="Center">
                <Line X1="11" Y1="3" X2="11" Y2="19" Stroke="#1F5FA6" StrokeThickness="1.8"/>
                <Line X1="3" Y1="11" X2="19" Y2="11" Stroke="#1F5FA6" StrokeThickness="1.8"/>
                <Polygon Points="11,0 8.5,4 13.5,4" Fill="#1F5FA6"/>
                <Polygon Points="11,22 8.5,18 13.5,18" Fill="#1F5FA6"/>
                <Polygon Points="0,11 4,8.5 4,13.5" Fill="#1F5FA6"/>
                <Polygon Points="22,11 18,8.5 18,13.5" Fill="#1F5FA6"/>
            </Canvas>

                        <Grid Grid.Column="1"
                                    VerticalAlignment="Center"
                                    HorizontalAlignment="Center"
                                    Width="272">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <TextBlock x:Name="TxtMetricsOverlayTop"
                           Grid.Row="0"
                           Text="W:0"
                           FontFamily="Consolas"
                           FontSize="16"
                           FontWeight="SemiBold"
                           Foreground="#102A43"
                           TextAlignment="Center"
                           HorizontalAlignment="Stretch"/>
                <TextBlock x:Name="TxtMetricsOverlayBottom"
                           Grid.Row="1"
                           Text="H:0"
                           FontFamily="Consolas"
                           FontSize="16"
                           FontWeight="SemiBold"
                           Foreground="#102A43"
                           TextAlignment="Center"
                           HorizontalAlignment="Stretch"/>
                <TextBlock x:Name="TxtMetricsOverlayThird"
                           Grid.Row="2"
                           Text="X:0"
                           FontFamily="Consolas"
                           FontSize="16"
                           FontWeight="SemiBold"
                           Foreground="#102A43"
                           TextAlignment="Center"
                           HorizontalAlignment="Stretch"/>
                <TextBlock x:Name="TxtMetricsOverlayFourth"
                           Grid.Row="3"
                           Text="Y:0"
                           FontFamily="Consolas"
                           FontSize="16"
                           FontWeight="SemiBold"
                           Foreground="#102A43"
                           TextAlignment="Center"
                           HorizontalAlignment="Stretch"/>
                <TextBlock Grid.Row="4"
                           Text="Device Indepedent Pixel"
                           FontFamily="Consolas"
                           FontSize="10"
                           Foreground="#102A43"
                           TextAlignment="Center"
                           HorizontalAlignment="Stretch"/>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

    $overlayReader = New-XamlXmlNodeReader -XmlDocument $overlayXaml -Context 'Window metrics overlay XAML'
    $script:windowMetricsOverlayWindow = [Windows.Markup.XamlReader]::Load($overlayReader)
    $script:windowMetricsOverlayTextTop = $script:windowMetricsOverlayWindow.FindName('TxtMetricsOverlayTop')
    $script:windowMetricsOverlayTextBottom = $script:windowMetricsOverlayWindow.FindName('TxtMetricsOverlayBottom')
    $script:windowMetricsOverlayTextThird = $script:windowMetricsOverlayWindow.FindName('TxtMetricsOverlayThird')
    $script:windowMetricsOverlayTextFourth = $script:windowMetricsOverlayWindow.FindName('TxtMetricsOverlayFourth')

    $script:windowMetricsOverlayWindow.Add_Closed({
        Set-MainWindowOverlayDimming -Dim $false
        $script:windowMetricsOverlayWindow = $null
        $script:windowMetricsOverlayTextTop = $null
        $script:windowMetricsOverlayTextBottom = $null
        $script:windowMetricsOverlayTextThird = $null
        $script:windowMetricsOverlayTextFourth = $null
    })
}

# Keep metrics visible briefly while movement/resizing events are firing.
function Show-WindowMetricsTemporarily {
    if (-not $lblWindowMetrics) { return }

    if ($script:windowMetricsOverlayWindow -and -not $script:windowMetricsOverlayWindow.IsVisible) {
        $script:windowMetricsOverlayWindow.Show()
    }

    if ($script:windowMetricsOverlayWindow -and $script:windowMetricsOverlayWindow.IsVisible) {
        Set-MainWindowOverlayDimming -Dim $true
    }

    Update-WindowMetricsText
    $lblWindowMetrics.Visibility = [System.Windows.Visibility]::Visible
    if ($script:windowMetricsHideTimer) {
        $script:windowMetricsHideTimer.Stop()
        $script:windowMetricsHideTimer.Start()
    }
}

# Keep the status bar error icon in sync with the current error count.
function Update-ErrorIndicator {
    if (-not $btnErrorLog) { return }
    $errorCount = $script:errorLogEntries.Count

    if ($errorCount -gt 0) {
        $lastEntry = $script:errorLogEntries[$errorCount - 1]

        if ($lblDiagnostics) {
            $lblDiagnostics.Text = "Errors: $errorCount"
            $lblDiagnostics.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xA4,0x26,0x2C))
            $lblDiagnostics.ToolTip = "Latest: $lastEntry"
        }

        if ($errorDot) {
            $errorDot.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xD8,0x3B,0x01))
            $errorDot.Stroke = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xA4,0x26,0x2C))
        }

        $btnErrorLog.Opacity = 1.0
        $btnErrorLog.ToolTip = "Show error log ($errorCount)"
    }
    else {
        if ($lblDiagnostics) {
            $lblDiagnostics.Text = 'No errors'
            $lblDiagnostics.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0x66,0x66,0x66))
            $lblDiagnostics.ToolTip = 'No errors logged for this session.'
        }

        if ($errorDot) {
            $errorDot.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xA0,0xA0,0xA0))
            $errorDot.Stroke = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0x7A,0x7A,0x7A))
        }

        $btnErrorLog.Opacity = 0.55
        $btnErrorLog.ToolTip = 'Show error log (no errors logged)'
    }

    $btnErrorLog.Visibility = [System.Windows.Visibility]::Visible
    Update-DiagnosticsVisibility
}

<#
.SYNOPSIS
    Adds a timestamped diagnostics entry.

.DESCRIPTION
    Captures an error message from either an ErrorRecord or plain text, appends it
    to the diagnostics collection, and refreshes diagnostics UI indicators.

.PARAMETER Context
    Short context label describing where the error occurred.

.PARAMETER ErrorRecord
    PowerShell ErrorRecord associated with the failure.

.PARAMETER Message
    Optional plain-text detail when no ErrorRecord is available.
#>
function Add-ErrorLog {
    param(
        [string]$Context,
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Message
    )

    $detail = $null
    $sourceLocation = 'unknown'
    $sourceCommand = 'unknown'

    if ($ErrorRecord) {
        $detail = if ($ErrorRecord.Exception -and $ErrorRecord.Exception.Message) {
            $ErrorRecord.Exception.Message
        }
        else {
            $ErrorRecord.ToString()
        }

        if ($ErrorRecord.InvocationInfo) {
            $inv = $ErrorRecord.InvocationInfo
            $sourceCommand = if ($inv.MyCommand -and $inv.MyCommand.Name) {
                $inv.MyCommand.Name
            }
            elseif (-not [string]::IsNullOrWhiteSpace($inv.InvocationName)) {
                $inv.InvocationName
            }
            else {
                'unknown'
            }

            $sourceFile = if (-not [string]::IsNullOrWhiteSpace($inv.ScriptName)) {
                [System.IO.Path]::GetFileName($inv.ScriptName)
            }
            else {
                '<interactive>'
            }

            $sourceLine = if ($inv.ScriptLineNumber -gt 0) { $inv.ScriptLineNumber } else { 0 }
            $sourceLocation = "${sourceFile}:$sourceLine"
        }
    }
    elseif ($Message) {
        $detail = $Message
    }
    else {
        $detail = 'Unknown error'
    }

    if ($sourceLocation -eq 'unknown') {
        $stack = Get-PSCallStack
        if ($stack -and $stack.Count -gt 1) {
            $caller = $stack[1]
            $sourceCommand = if (-not [string]::IsNullOrWhiteSpace($caller.Command)) { $caller.Command } else { 'unknown' }
            $sourceFile = if (-not [string]::IsNullOrWhiteSpace($caller.ScriptName)) {
                [System.IO.Path]::GetFileName($caller.ScriptName)
            }
            else {
                '<interactive>'
            }
            $sourceLine = if ($caller.ScriptLineNumber -gt 0) { $caller.ScriptLineNumber } else { 0 }
            $sourceLocation = "${sourceFile}:$sourceLine"
        }
    }

    $script:errorSequence++
    $errorId = "TFERR-{0}-{1:D5}" -f (Get-Date).ToString('yyyyMMddHHmmss'), $script:errorSequence
    $script:lastErrorId = $errorId

    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry = "[$stamp] [$errorId] $Context :: $detail :: at $sourceCommand ($sourceLocation)"
    $script:errorLogEntries.Add($entry)
    Write-SessionOutput -Level ERROR -Message "[$errorId] $Context :: $detail :: at $sourceCommand ($sourceLocation)"
    Update-LastErrorIdBanner

    if ($lblStatus) {
        $lblStatus.Text = "Error logged: $Context ($errorId)"
    }

    if ($script:errorLogWindow -and $script:errorLogWindow.IsVisible) {
        Refresh-ErrorLogWindowContent
    }

    Update-ErrorIndicator
}

<#
.SYNOPSIS
    Creates display text for the diagnostics transcript pane.

.DESCRIPTION
    Reads the current session transcript file and returns a formatted text block for
    the diagnostics window. Includes friendly status text for missing/empty content.

.OUTPUTS
    System.String
#>
function Get-SessionTranscriptText {
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add('=== Session Output (In-Memory) ===')
    if ($script:sessionOutputEntries.Count -gt 0) {
        foreach ($line in $script:sessionOutputEntries) {
            $lines.Add($line)
        }
    }
    else {
        $lines.Add('(No session output has been captured yet.)')
    }
    $lines.Add('')

    $lines.Add('=== PowerShell Session Output ===')
    $lines.Add("Transcript: $script:sessionTranscriptPath")
    if ($script:sessionTranscriptStartError) {
        $lines.Add("Transcript start error: $($script:sessionTranscriptStartError)")
    }
    $lines.Add('')

    if (Test-Path -LiteralPath $script:sessionTranscriptPath -PathType Leaf) {
        try {
            $transcript = Get-Content -LiteralPath $script:sessionTranscriptPath -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($transcript)) {
                $lines.Add('(Transcript file exists, but no output has been captured yet.)')
            }
            else {
                foreach ($line in ($transcript -split "`r?`n")) {
                    $lines.Add($line)
                }
            }
        }
        catch {
            $lines.Add("(Failed to read transcript: $($_.Exception.Message))")
        }
    }
    else {
        $lines.Add('(Transcript file is not available for this session.)')
    }

    $lines -join [System.Environment]::NewLine
}

<#
.SYNOPSIS
    Refreshes diagnostics window panes.

.DESCRIPTION
    Synchronizes the error list and transcript text pane whenever diagnostics data
    changes. Anchors the error list view to the first entry when present.
#>
function Refresh-ErrorLogWindowContent {
    if ($script:errorListBox) {
        $errorText = $script:errorLogEntries -join [Environment]::NewLine
        $script:errorListBox.Text = $errorText
        $script:errorListBox.ScrollToHome()
    }

    if ($script:transcriptTextBox) {
        $script:transcriptTextBox.Text = Get-SessionTranscriptText
        $script:transcriptTextBox.ScrollToHome()
    }
}

# Show a reusable modeless window containing all captured errors.
function Show-ErrorLogWindow {
    if ($script:errorLogWindow -and $script:errorLogWindow.IsVisible) {
        $script:errorLogWindow.Activate()
        return
    }

    [xml]$logXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Touch Files Error Log"
        Height="460"
        Width="680"
        MinHeight="320"
        MinWidth="440"
        WindowStartupLocation="CenterOwner"
        ShowInTaskbar="False"
        ResizeMode="CanResizeWithGrip">
    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0"
                   Text="Session diagnostics"
                   FontWeight="SemiBold"
                   Margin="0,0,0,8"/>
        <Grid Grid.Row="1">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="2*"/>
                <RowDefinition Height="8"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="3*"/>
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0"
                       Text="Errors"
                       FontWeight="SemiBold"
                       Margin="0,0,0,4"/>
            <TextBox x:Name="TxtErrors"
                     Grid.Row="1"
                     FontFamily="Consolas"
                     IsReadOnly="True"
                     AcceptsReturn="True"
                     TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto"
                     HorizontalScrollBarVisibility="Auto"
                     BorderBrush="#C8C8C8"
                     BorderThickness="1"/>
            <GridSplitter Grid.Row="2"
                          Height="8"
                          HorizontalAlignment="Stretch"
                          VerticalAlignment="Center"
                          ResizeBehavior="PreviousAndNext"
                          Background="#E5E5E5"/>
            <TextBlock Grid.Row="3"
                       Text="PowerShell Session Output"
                       FontWeight="SemiBold"
                       Margin="0,6,0,4"/>
            <TextBox x:Name="TxtTranscript"
                     Grid.Row="4"
                     FontFamily="Consolas"
                     IsReadOnly="True"
                     AcceptsReturn="True"
                     AcceptsTab="True"
                     TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto"
                     HorizontalScrollBarVisibility="Auto"
                     BorderBrush="#C8C8C8"
                     BorderThickness="1"/>
        </Grid>
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="BtnRefreshLog" Content="Refresh" MinWidth="85" Margin="0,0,8,0"/>
            <Button x:Name="BtnClearErrors" Content="Clear Log" MinWidth="95" Margin="0,0,8,0"/>
            <Button x:Name="BtnCloseLog" Content="Close" MinWidth="85" IsDefault="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $logReader = New-XamlXmlNodeReader -XmlDocument $logXaml -Context 'Error log window XAML'
    $script:errorLogWindow = [Windows.Markup.XamlReader]::Load($logReader)
    $script:errorLogWindow.Owner = $window

    $script:errorListBox = $script:errorLogWindow.FindName('TxtErrors')
    $script:transcriptTextBox = $script:errorLogWindow.FindName('TxtTranscript')
    $btnCloseLog = $script:errorLogWindow.FindName('BtnCloseLog')
    $btnClearErrors = $script:errorLogWindow.FindName('BtnClearErrors')
    $btnRefreshLog = $script:errorLogWindow.FindName('BtnRefreshLog')

    Refresh-ErrorLogWindowContent

    if ($btnCloseLog) {
        $btnCloseLog.Add_Click({
            $script:errorLogWindow.Close()
        })
    }

    if ($btnRefreshLog) {
        $btnRefreshLog.Add_Click({
            Refresh-ErrorLogWindowContent
        })
    }

    if ($btnClearErrors) {
        $btnClearErrors.Add_Click({
            $script:errorLogEntries.Clear()
            Update-ErrorIndicator
            Update-UiState
            Refresh-ErrorLogWindowContent
        })
    }

    $script:errorLogWindow.Add_Closed({
        $script:errorLogWindow = $null
        $script:errorListBox = $null
        $script:transcriptTextBox = $null
    })

    $script:errorLogWindow.Show() | Out-Null
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

    Update-CommandButtonLabelMode -IconOnly $isNarrow
}

# Toggle command buttons between full labels and icon-only text while preserving tooltips.
function Update-CommandButtonLabelMode {
    param([bool]$IconOnly)

    $buttons = @($btnAdd, $btnTouch, $btnToggle, $btnEnc, $btnReadOnly, $btnDateStamp, $btnHidden, $btnRefresh, $btnClear) | Where-Object { $_ }
    foreach ($button in $buttons) {
        $name = $button.Name
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        if (-not $script:commandButtonDefaults.ContainsKey($name)) {
            $script:commandButtonDefaults[$name] = [PSCustomObject]@{
                Content = [string]$button.Content
                MinWidth = [double]$button.MinWidth
                Padding = $button.Padding
            }
        }

        $defaults = $script:commandButtonDefaults[$name]
        if ($IconOnly) {
            $button.Content = ''
            $button.MinWidth = $script:iconOnlyButtonWidth
            $button.Padding = New-Object System.Windows.Thickness(8,0,8,0)
        }
        else {
            $button.Content = $defaults.Content
            $button.MinWidth = $defaults.MinWidth
            $button.Padding = $defaults.Padding
        }
    }
}

<#
.SYNOPSIS
    Recursively finds visual children of a given type.

.DESCRIPTION
    Traverses the WPF visual tree below a parent element and returns all matching
    descendants for the requested child type.

.PARAMETER Parent
    Root visual node to traverse.

.PARAMETER ChildType
    .NET type to match while traversing.

.OUTPUTS
    System.Object[]
#>
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
function Set-PathVisibility {
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
    if ($script:refreshInProgress -and (-not $script:refreshTimer -or -not $script:refreshTimer.IsEnabled)) {
        # Recover from stale busy state if refresh timer has stopped unexpectedly.
        $script:refreshInProgress = $false
        $script:refreshTimer = $null
        [System.Windows.Input.Mouse]::OverrideCursor = $null
        Write-TraceLog -Level WARN -Message 'Recovered stale refresh busy-state (timer not active).'
    }

    $selectedCount = (Get-SelectedItems).Count
    $hasFiles = $fileItems.Count -gt 0
    $hasSelection = $selectedCount -gt 0
    $isBusy = $script:refreshInProgress -eq $true

    $btnTouch.IsEnabled  = (-not $isBusy) -and $hasSelection
    $btnToggle.IsEnabled = (-not $isBusy) -and $hasSelection
    if ($btnEnc)       { $btnEnc.IsEnabled       = (-not $isBusy) -and $hasSelection }
    if ($btnReadOnly)  { $btnReadOnly.IsEnabled  = (-not $isBusy) -and $hasSelection }
    if ($btnDateStamp) { $btnDateStamp.IsEnabled = (-not $isBusy) -and $hasSelection }
    if ($btnHidden)    { $btnHidden.IsEnabled    = (-not $isBusy) -and $hasSelection }
    if ($btnRefresh) { $btnRefresh.IsEnabled = (-not $isBusy) -and $hasFiles }
    if ($btnCommentDiag) {
        $btnCommentDiag.Visibility = if ($selectedCount -eq 1) {
            [System.Windows.Visibility]::Visible
        }
        else {
            [System.Windows.Visibility]::Collapsed
        }
    }
    $btnClear.IsEnabled  = (-not $isBusy) -and $hasFiles
    if ($isBusy) {
        $lblStatus.Text = "Refresh in progress..."
    }
    else {
        $lblStatus.Text = if ($hasFiles) { "Files loaded: $($fileItems.Count)" } else { "Ready" }
    }
    if ($lblSelectedStatus) { $lblSelectedStatus.Text = "Files selected: $selectedCount" }
    Sync-SelectAll
    Update-ErrorIndicator
}

function Test-OpenXmlCommentExtension {
    param([string]$FilePath)
    $openXmlExtensions = @(
        '.docx', '.docm', '.dotx', '.dotm',
        '.xlsx', '.xlsm', '.xltx', '.xltm',
        '.pptx', '.pptm', '.potx', '.potm'
    )
    $ext = [System.IO.Path]::GetExtension($FilePath)
    if ([string]::IsNullOrWhiteSpace($ext)) { return $false }
    return $openXmlExtensions -contains $ext.ToLowerInvariant()
}

function Get-OpenXmlCoreComment {
    param([string]$FilePath)
    $zip = $null
    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return '' }
        $zip = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        $entry = $zip.GetEntry('docProps/core.xml')
        if (-not $entry) { return '' }

        $stream = $entry.Open()
        try {
            $reader = New-Object System.IO.StreamReader($stream)
            $xmlText = $reader.ReadToEnd()
            $reader.Dispose()
        }
        finally {
            $stream.Dispose()
        }

        if ([string]::IsNullOrWhiteSpace($xmlText)) { return '' }
        [xml]$xml = $xmlText
        $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $ns.AddNamespace('cp', 'http://schemas.openxmlformats.org/package/2006/metadata/core-properties')
        $ns.AddNamespace('dc', 'http://purl.org/dc/elements/1.1/')
        $xpaths = @(
            '/cp:coreProperties/dc:description',
            '/cp:coreProperties/dc:subject',
            '/cp:coreProperties/cp:keywords'
        )
        foreach ($xpath in $xpaths) {
            $node = $xml.SelectSingleNode($xpath, $ns)
            if ($node -and -not [string]::IsNullOrWhiteSpace($node.InnerText)) {
                return $node.InnerText.Trim()
            }
        }
        return ''
    }
    catch {
        return ''
    }
    finally {
        if ($zip) { $zip.Dispose() }
    }
}

function Set-OpenXmlCoreComment {
    param(
        [string]$FilePath,
        [string]$Comment
    )

    $zip = $null
    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return $false }
        $zip = [System.IO.Compression.ZipFile]::Open($FilePath, [System.IO.Compression.ZipArchiveMode]::Update)
        $entry = $zip.GetEntry('docProps/core.xml')
        if (-not $entry) { return $false }

        $stream = $entry.Open()
        try {
            $reader = New-Object System.IO.StreamReader($stream)
            $xmlText = $reader.ReadToEnd()
            $reader.Dispose()
        }
        finally {
            $stream.Dispose()
        }

        [xml]$xml = $xmlText
        $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $ns.AddNamespace('cp', 'http://schemas.openxmlformats.org/package/2006/metadata/core-properties')
        $ns.AddNamespace('dc', 'http://purl.org/dc/elements/1.1/')

        $coreNode = $xml.SelectSingleNode('/cp:coreProperties', $ns)
        if (-not $coreNode) { return $false }

        $descriptionNode = $xml.SelectSingleNode('/cp:coreProperties/dc:description', $ns)
        if (-not $descriptionNode) {
            $descriptionNode = $xml.CreateElement('dc', 'description', 'http://purl.org/dc/elements/1.1/')
            [void]$coreNode.AppendChild($descriptionNode)
        }

        $subjectNode = $xml.SelectSingleNode('/cp:coreProperties/dc:subject', $ns)
        if (-not $subjectNode) {
            $subjectNode = $xml.CreateElement('dc', 'subject', 'http://purl.org/dc/elements/1.1/')
            [void]$coreNode.AppendChild($subjectNode)
        }

        $keywordsNode = $xml.SelectSingleNode('/cp:coreProperties/cp:keywords', $ns)
        if (-not $keywordsNode) {
            $keywordsNode = $xml.CreateElement('cp', 'keywords', 'http://schemas.openxmlformats.org/package/2006/metadata/core-properties')
            [void]$coreNode.AppendChild($keywordsNode)
        }

        $commentValue = if ($null -eq $Comment) { '' } else { [string]$Comment }
        $descriptionNode.InnerText = $commentValue
        $subjectNode.InnerText = $commentValue
        $keywordsNode.InnerText = $commentValue

        $updatedXml = $xml.OuterXml
        $entry.Delete()
        $newEntry = $zip.CreateEntry('docProps/core.xml', [System.IO.Compression.CompressionLevel]::Optimal)
        $newStream = $newEntry.Open()
        try {
            $encoding = New-Object System.Text.UTF8Encoding($false)
            $writer = New-Object System.IO.StreamWriter($newStream, $encoding)
            $writer.Write($updatedXml)
            $writer.Flush()
            $writer.Dispose()
        }
        finally {
            $newStream.Dispose()
        }

        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($zip) { $zip.Dispose() }
    }
}

function Test-StartupHelperFunctions {
    param(
        [string[]]$RequiredFunctions = @(
            'Write-SessionOutput',
            'Add-ErrorLog',
            'Get-SelectedItems',
            'Update-ErrorIndicator',
            'Update-UiState',
            'Test-OpenXmlCommentExtension',
            'Get-OpenXmlCoreComment',
            'Set-OpenXmlCoreComment',
            'Get-FileComment',
            'Get-ShellExplorerComment',
            'Get-FileCommentDiagnosticsReport',
            'Show-CommentDiagnosticsWindow'
        )
    )

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($functionName in $RequiredFunctions) {
        $command = Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue
        if (-not $command) {
            [void]$missing.Add($functionName)
        }
    }

    $writeSessionOutputCommand = Get-Command -Name 'Write-SessionOutput' -CommandType Function -ErrorAction SilentlyContinue
    $addErrorLogCommand = Get-Command -Name 'Add-ErrorLog' -CommandType Function -ErrorAction SilentlyContinue

    if ($missing.Count -eq 0) {
        if ($writeSessionOutputCommand) {
            & $writeSessionOutputCommand -Message "Startup helper verification passed for $($RequiredFunctions.Count) function(s)."
        }
        return $true
    }

    $missingList = $missing -join ', '
    $message = "Startup verification failed. Missing helper function(s): $missingList"
    if ($addErrorLogCommand) {
        & $addErrorLogCommand -Context 'Startup helper verification failed' -Message $message
    }
    elseif ($writeSessionOutputCommand) {
        & $writeSessionOutputCommand -Level ERROR -Message $message
    }
    else {
        Write-Error -Message $message
    }

    if ($lblStatus) {
        $lblStatus.Text = 'Startup check failed. See error log.'
    }

    [void][System.Windows.MessageBox]::Show(
        "$message`r`n`r`nThe main window will not open until the required helper functions are available.",
        'Touch Files Startup Check',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )

    return $false
}

function Get-FileCommentDiagnosticsReport {
    param([string]$FilePath)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Touch Files Comment Diagnostics')
    $lines.Add("Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
    $lines.Add("File: $FilePath")
    $lines.Add('')

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        $lines.Add('File not found.')
        return ($lines -join [Environment]::NewLine)
    }

    $openXmlComment = ''
    $wordComComment = ''
    if (Test-OpenXmlCommentExtension -FilePath $FilePath) {
        $openXmlComment = Get-OpenXmlCoreComment -FilePath $FilePath
    }
    if (Test-WordCommentExtension -FilePath $FilePath) {
        $wordComComment = Get-WordDocumentComment -FilePath $FilePath
    }

    $shellComment = Get-ShellExplorerComment -FilePath $FilePath
    $currentComment = Get-FileComment -FilePath $FilePath

    $lines.Add('Summary')
    $lines.Add("- OpenXML comment read: $(if ([string]::IsNullOrWhiteSpace($openXmlComment)) { '<empty>' } else { $openXmlComment })")
    $lines.Add("- Word COM comment read: $(if ([string]::IsNullOrWhiteSpace($wordComComment)) { '<empty>' } else { $wordComComment })")
    $lines.Add("- Shell comment read:   $(if ([string]::IsNullOrWhiteSpace($shellComment)) { '<empty>' } else { $shellComment })")
    $lines.Add("- App selected comment: $(if ([string]::IsNullOrWhiteSpace($currentComment)) { '<empty>' } else { $currentComment })")
    $lines.Add("- Last source used:     $script:lastCommentSource")
    $lines.Add('')

    $lines.Add('Last write verification (session)')
    if ($script:lastCommentWriteVerification.ContainsKey($FilePath)) {
        $verify = $script:lastCommentWriteVerification[$FilePath]
        $lines.Add("- Timestamp:            $($verify.Timestamp)")
        $lines.Add("- Expected comment:     $(if ([string]::IsNullOrWhiteSpace($verify.ExpectedComment)) { '<empty>' } else { $verify.ExpectedComment })")
        $lines.Add("- Verification result:  $(if ($verify.Verified) { 'PASS' } else { 'FAIL' })")
        $lines.Add("- Matched source:       $($verify.MatchedSource)")
        $lines.Add("- Verify OpenXML:       $(if ([string]::IsNullOrWhiteSpace($verify.OpenXmlRead)) { '<empty>' } else { $verify.OpenXmlRead })")
        $lines.Add("- Verify Word COM:      $(if ([string]::IsNullOrWhiteSpace($verify.WordComRead)) { '<empty>' } else { $verify.WordComRead })")
        $lines.Add("- Verify Excel COM:     $(if ([string]::IsNullOrWhiteSpace($verify.ExcelComRead)) { '<empty>' } else { $verify.ExcelComRead })")
        $lines.Add("- Verify NTFS ADS:      $(if ([string]::IsNullOrWhiteSpace($verify.AdsRead)) { '<empty>' } else { $verify.AdsRead })")
        $lines.Add("- Verify App Read:      $(if ([string]::IsNullOrWhiteSpace($verify.AppRead)) { '<empty>' } else { $verify.AppRead })")
    }
    else {
        $lines.Add('- No write verification record exists yet for this file in this session.')
    }
    $lines.Add('')

    try {
        $shell = New-Object -ComObject Shell.Application
        $folderPath = [System.IO.Path]::GetDirectoryName($FilePath)
        $leafName = [System.IO.Path]::GetFileName($FilePath)
        $folder = $shell.Namespace($folderPath)
        $item = if ($folder) { $folder.ParseName($leafName) } else { $null }

        if (-not $folder -or -not $item) {
            $lines.Add('Shell metadata unavailable for this file path.')
            return ($lines -join [Environment]::NewLine)
        }

        $lines.Add('ExtendedProperty probes')
        $propertyNames = @(
            'System.Comment',
            'System.Document.Comment',
            'System.Subject',
            'System.Document.Subject',
            'System.Keywords',
            'System.Document.Keywords',
            'System.Title',
            'System.FileDescription'
        )
        foreach ($propertyName in $propertyNames) {
            try {
                $value = [string]$item.ExtendedProperty($propertyName)
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $lines.Add("- $propertyName = <empty>")
                }
                else {
                    $lines.Add("- $propertyName = $($value.Trim())")
                }
            }
            catch {
                $lines.Add("- $propertyName = <error: $($_.Exception.Message)>")
            }
        }

        $lines.Add('')
        $lines.Add('Explorer columns (non-empty, comment-related)')
        $matched = 0
        for ($i = 0; $i -lt 320; $i++) {
            $columnName = [string]$folder.GetDetailsOf($null, $i)
            if ([string]::IsNullOrWhiteSpace($columnName)) { continue }
            if ($columnName -notmatch '(?i)comment|subject|keyword|title|tag') { continue }
            $columnValue = [string]$folder.GetDetailsOf($item, $i)
            if ([string]::IsNullOrWhiteSpace($columnValue)) { continue }
            $lines.Add("- [$i] $columnName = $($columnValue.Trim())")
            $matched++
        }

        if ($matched -eq 0) {
            $lines.Add('- No non-empty comment-related columns found in first 320 indices.')
        }
    }
    catch {
        $lines.Add('')
        $lines.Add("Shell diagnostics error: $($_.Exception.Message)")
    }

    return ($lines -join [Environment]::NewLine)
}

function Show-CommentDiagnosticsWindow {
    param(
        [string]$FilePath,
        [string]$ReportText
    )

    [xml]$diagXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Comment Diagnostics"
        Width="900"
        Height="620"
        MinWidth="640"
        MinHeight="420"
        WindowStartupLocation="CenterOwner"
        ShowInTaskbar="False"
        ResizeMode="CanResizeWithGrip">
    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="TxtDiagHeader"
                   Grid.Row="0"
                   Margin="0,0,0,8"
                   FontWeight="SemiBold"
                   TextWrapping="Wrap"/>
        <TextBox x:Name="TxtDiagReport"
                 Grid.Row="1"
                 FontFamily="Consolas"
                 IsReadOnly="True"
                 AcceptsReturn="True"
                 AcceptsTab="True"
                 TextWrapping="NoWrap"
                 VerticalScrollBarVisibility="Auto"
                 HorizontalScrollBarVisibility="Auto"
                 BorderBrush="#C8C8C8"
                 BorderThickness="1"/>
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="BtnDiagCopy" Content="Copy Report" MinWidth="100" Margin="0,0,8,0"/>
            <Button x:Name="BtnDiagClose" Content="Close" MinWidth="85" IsDefault="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $diagReader = New-XamlXmlNodeReader -XmlDocument $diagXaml -Context 'Comment diagnostics XAML'
    $diagWindow = [Windows.Markup.XamlReader]::Load($diagReader)
    $diagWindow.Owner = $window

    $txtDiagHeader = $diagWindow.FindName('TxtDiagHeader')
    $txtDiagReport = $diagWindow.FindName('TxtDiagReport')
    $btnDiagCopy = $diagWindow.FindName('BtnDiagCopy')
    $btnDiagClose = $diagWindow.FindName('BtnDiagClose')

    if ($txtDiagHeader) { $txtDiagHeader.Text = "File: $FilePath" }
    if ($txtDiagReport) { $txtDiagReport.Text = $ReportText }

    if ($btnDiagCopy) {
        $btnDiagCopy.Add_Click({
            try {
                if (Get-Command -Name Set-Clipboard -ErrorAction SilentlyContinue) {
                    Set-Clipboard -Value $ReportText
                }
                else {
                    [System.Windows.Clipboard]::SetText($ReportText)
                }
            }
            catch {
                Add-ErrorLog -Context 'Copy comment diagnostics report failed' -ErrorRecord $_
            }
        })
    }

    if ($btnDiagClose) {
        $btnDiagClose.Add_Click({ $diagWindow.Close() })
    }

    $diagWindow.ShowDialog() | Out-Null
}

<#
.SYNOPSIS
    Read a comment from an NTFS alternate data stream on a file.

.DESCRIPTION
    Retrieves a stored comment from the file's ':TouchFileComment' stream.
    Returns empty string if stream does not exist or on error.

.PARAMETER FilePath
    Full path to the file.

.OUTPUTS
    System.String
#>
function Get-FileComment {
    param([string]$FilePath)

    $script:lastCommentSource = 'None'

    if (Test-OpenXmlCommentExtension -FilePath $FilePath) {
        $openXmlComment = Get-OpenXmlCoreComment -FilePath $FilePath
        if (-not [string]::IsNullOrWhiteSpace($openXmlComment)) {
            $script:lastCommentSource = 'OpenXML core.xml (description/subject/keywords)'
            return $openXmlComment
        }
    }

    if (Test-ExcelCommentExtension -FilePath $FilePath) {
        $excelComment = Get-ExcelWorkbookComment -FilePath $FilePath
        if (-not [string]::IsNullOrWhiteSpace($excelComment)) {
            $script:lastCommentSource = 'Excel COM BuiltinDocumentProperties'
            return $excelComment
        }
    }

    if (Test-WordCommentExtension -FilePath $FilePath) {
        $wordComment = Get-WordDocumentComment -FilePath $FilePath
        if (-not [string]::IsNullOrWhiteSpace($wordComment)) {
            $script:lastCommentSource = 'Word COM BuiltinDocumentProperties'
            return $wordComment
        }
    }

    $shellComment = Get-ShellExplorerComment -FilePath $FilePath
    if (-not [string]::IsNullOrWhiteSpace($shellComment)) {
        $script:lastCommentSource = 'Windows Explorer shell property'
        return $shellComment
    }

    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return '' }
        $streamPath = "$FilePath:TouchFileComment"
        if (Test-Path -LiteralPath $streamPath -PathType Leaf) {
            $content = Get-Content -LiteralPath $streamPath -Raw -ErrorAction Stop
            if ($content) {
                $script:lastCommentSource = 'NTFS ADS :TouchFileComment'
                return $content.Trim()
            }
            return ''
        }
    }
    catch {
        # Silently fail; file may be on non-NTFS volume or inaccessible
    }
    return ''
}

function Invoke-CommentWriteVerification {
    param(
        [string]$FilePath,
        [string]$ExpectedComment
    )

    $expected = if ($null -eq $ExpectedComment) { '' } else { [string]$ExpectedComment }
    $expected = $expected.Trim()

    $openXmlComment = ''
    $wordComComment = ''
    $excelComComment = ''
    $adsComment = ''

    if (Test-OpenXmlCommentExtension -FilePath $FilePath) {
        $openXmlComment = Get-OpenXmlCoreComment -FilePath $FilePath
    }
    if (Test-WordCommentExtension -FilePath $FilePath) {
        $wordComComment = Get-WordDocumentComment -FilePath $FilePath
    }
    if (Test-ExcelCommentExtension -FilePath $FilePath) {
        $excelComComment = Get-ExcelWorkbookComment -FilePath $FilePath
    }

    try {
        $streamPath = "$FilePath:TouchFileComment"
        if (Test-Path -LiteralPath $streamPath -PathType Leaf) {
            $adsRaw = Get-Content -LiteralPath $streamPath -Raw -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($adsRaw)) {
                $adsComment = $adsRaw.Trim()
            }
        }
    }
    catch {
        $adsComment = ''
    }

    $appComment = Get-FileComment -FilePath $FilePath
    $reads = [ordered]@{
        'OpenXML' = $openXmlComment
        'Word COM' = $wordComComment
        'Excel COM' = $excelComComment
        'NTFS ADS' = $adsComment
        'App Selected' = $appComment
    }

    $verified = $false
    $matchedSource = 'None'
    if ([string]::IsNullOrWhiteSpace($expected)) {
        $allEmpty = $true
        foreach ($entry in $reads.GetEnumerator()) {
            if (-not [string]::IsNullOrWhiteSpace([string]$entry.Value)) {
                $allEmpty = $false
                break
            }
        }
        $verified = $allEmpty
        if ($verified) {
            $matchedSource = 'All sources empty'
        }
    }
    else {
        foreach ($entry in $reads.GetEnumerator()) {
            $value = if ($null -eq $entry.Value) { '' } else { [string]$entry.Value }
            if ($value.Trim() -ceq $expected) {
                $verified = $true
                $matchedSource = $entry.Key
                break
            }
        }
    }

    $script:lastCommentWriteVerification[$FilePath] = [ordered]@{
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ExpectedComment = $expected
        Verified = $verified
        MatchedSource = $matchedSource
        OpenXmlRead = $openXmlComment
        WordComRead = $wordComComment
        ExcelComRead = $excelComComment
        AdsRead = $adsComment
        AppRead = $appComment
    }

    return $verified
}

<#
.SYNOPSIS
    Write a comment to an NTFS alternate data stream on a file.

.DESCRIPTION
    Stores a comment in the file's ':TouchFileComment' stream. Works on any NTFS file.
    Silently fails if the volume is not NTFS or the file is inaccessible.

.PARAMETER FilePath
    Full path to the file.

.PARAMETER Comment
    Comment text to store. If empty, the stream is left as-is.
#>
function Set-FileComment {
    param(
        [string]$FilePath,
        [string]$Comment
    )

    # TODO: Comments still do not write.

    $openXmlWriteSucceeded = $false
    $wordComWriteSucceeded = $false
    $excelWriteSucceeded = $false
    $adsWriteSucceeded = $false
    $commentValue = if ($null -eq $Comment) { '' } else { [string]$Comment }
    $trimmedComment = $commentValue.Trim()

    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return }

        if (Test-OpenXmlCommentExtension -FilePath $FilePath) {
            $openXmlWriteSucceeded = Set-OpenXmlCoreComment -FilePath $FilePath -Comment $trimmedComment
        }

        if (Test-WordCommentExtension -FilePath $FilePath) {
            $wordComWriteSucceeded = Set-WordDocumentComment -FilePath $FilePath -Comment $trimmedComment
        }

        if (Test-ExcelCommentExtension -FilePath $FilePath) {
            $excelWriteSucceeded = Set-ExcelWorkbookComment -FilePath $FilePath -Comment $trimmedComment
        }

        $streamPath = "$FilePath:TouchFileComment"
        if ([string]::IsNullOrWhiteSpace($trimmedComment)) {
            if (Test-Path -LiteralPath $streamPath -PathType Leaf) {
                Remove-Item -LiteralPath $streamPath -Force -ErrorAction SilentlyContinue
            }
            $adsWriteSucceeded = $true
        }

        if (-not [string]::IsNullOrWhiteSpace($trimmedComment)) {
            try {
                $trimmedComment | Set-Content -LiteralPath $streamPath -NoNewline -ErrorAction Stop
                $adsWriteSucceeded = $true
            }
            catch {
                $adsWriteSucceeded = $false
            }
        }

        $writeVerified = Invoke-CommentWriteVerification -FilePath $FilePath -ExpectedComment $trimmedComment

        if (-not ($openXmlWriteSucceeded -or $wordComWriteSucceeded -or $excelWriteSucceeded -or $adsWriteSucceeded)) {
            Add-ErrorLog -Context "Comment save failed for '$FilePath'" -Message 'No comment persistence method succeeded (OpenXML, Word COM, Excel COM, or NTFS ADS).'
        }
        elseif (-not $writeVerified) {
            $verify = $script:lastCommentWriteVerification[$FilePath]
            Add-ErrorLog -Context "Comment save verification failed for '$FilePath'" -Message "Expected '$($verify.ExpectedComment)' but immediate read-back did not match."
        }
    }
    catch {
        Add-ErrorLog -Context "Comment save failed for '$FilePath'" -ErrorRecord $_
    }
}

function Test-WordCommentExtension {
    param([string]$FilePath)
    $wordExtensions = @('.docx', '.docm', '.dotx', '.dotm', '.doc', '.dot')
    $ext = [System.IO.Path]::GetExtension($FilePath)
    if ([string]::IsNullOrWhiteSpace($ext)) { return $false }
    return $wordExtensions -contains $ext.ToLowerInvariant()
}

function Test-ExcelCommentExtension {
    param([string]$FilePath)
    $excelExtensions = @('.xlsx', '.xlsm', '.xlsb', '.xls')
    $ext = [System.IO.Path]::GetExtension($FilePath)
    if ([string]::IsNullOrWhiteSpace($ext)) { return $false }
    return $excelExtensions -contains $ext.ToLowerInvariant()
}

function Set-WordDocumentComment {
    param(
        [string]$FilePath,
        [string]$Comment
    )

    $word = $null
    $document = $null
    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return $false }
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $document = $word.Documents.Open($FilePath, $false, $false)

        $commentValue = if ($null -eq $Comment) { '' } else { [string]$Comment }
        $propertyIndexes = @(5, 2, 4)
        $propertyNames = @('Comments', 'Subject', 'Keywords')
        $writeAny = $false

        foreach ($propertyIndex in $propertyIndexes) {
            try {
                $prop = $document.BuiltInDocumentProperties.Item($propertyIndex)
                if ($null -ne $prop) {
                    $prop.Value = $commentValue
                    $writeAny = $true
                }
            }
            catch {
                # Continue probing alternate property access methods.
            }
        }

        foreach ($propertyName in $propertyNames) {
            try {
                $prop = $document.BuiltInDocumentProperties.Item($propertyName)
                if ($null -ne $prop) {
                    $prop.Value = $commentValue
                    $writeAny = $true
                }
            }
            catch {
                # Best effort for Word metadata writes.
            }
        }

        if ($writeAny) {
            $document.Saved = $false
            $document.Save()
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
    finally {
        if ($document) {
            $document.Close($true) | Out-Null
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($document)
        }
        if ($word) {
            $word.Quit()
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word)
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Get-WordDocumentComment {
    param([string]$FilePath)

    $word = $null
    $document = $null
    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return '' }
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $document = $word.Documents.Open($FilePath, $false, $true)

        foreach ($propertyIndex in @(5, 2, 4)) {
            try {
                $prop = $document.BuiltInDocumentProperties.Item($propertyIndex)
                $value = if ($null -ne $prop -and $null -ne $prop.Value) { [string]$prop.Value } else { '' }
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value.Trim()
                }
            }
            catch {
                # Continue probing Word properties.
            }
        }

        foreach ($propertyName in @('Comments', 'Subject', 'Keywords')) {
            try {
                $prop = $document.BuiltInDocumentProperties.Item($propertyName)
                $value = if ($null -ne $prop -and $null -ne $prop.Value) { [string]$prop.Value } else { '' }
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value.Trim()
                }
            }
            catch {
                # Continue probing Word properties.
            }
        }
        return ''
    }
    catch {
        return ''
    }
    finally {
        if ($document) {
            $document.Close($false) | Out-Null
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($document)
        }
        if ($word) {
            $word.Quit()
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word)
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Get-ShellExplorerComment {
    param([string]$FilePath)
    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return '' }
        $extension = [System.IO.Path]::GetExtension($FilePath)
        $isWordOpenXml = $false
        if (-not [string]::IsNullOrWhiteSpace($extension)) {
            $isWordOpenXml = @('.docx', '.docm', '.dotx', '.dotm') -contains $extension.ToLowerInvariant()
        }

        $shell = New-Object -ComObject Shell.Application
        $folderPath = [System.IO.Path]::GetDirectoryName($FilePath)
        $leafName = [System.IO.Path]::GetFileName($FilePath)
        $folder = $shell.Namespace($folderPath)
        if (-not $folder) { return '' }
        $item = $folder.ParseName($leafName)
        if (-not $item) { return '' }

        # Try common canonical property names first.
        $propertyCandidates = @(
            'System.Comment',
            'System.Document.Comment',
            'System.FileDescription',
            'Comments'
        )
        foreach ($propName in $propertyCandidates) {
            try {
                $value = [string]$item.ExtendedProperty($propName)
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value.Trim()
                }
            }
            catch {
                # Continue probing other property names.
            }
        }

        # Targeted Word fallback: some files expose Explorer's visible comment
        # via related document properties instead of System.Comment.
        if ($isWordOpenXml) {
            $wordPropertyCandidates = @(
                'System.Document.Comment',
                'System.Subject',
                'System.Document.Subject',
                'System.Keywords',
                'System.Document.Keywords',
                'System.Title'
            )

            foreach ($propName in $wordPropertyCandidates) {
                try {
                    $value = [string]$item.ExtendedProperty($propName)
                    if (-not [string]::IsNullOrWhiteSpace($value)) {
                        return $value.Trim()
                    }
                }
                catch {
                    # Continue probing Word-specific property names.
                }
            }
        }

        # Fall back to Explorer column text by locating the Comments column.
        for ($i = 0; $i -lt 320; $i++) {
            $columnName = [string]$folder.GetDetailsOf($null, $i)
            if ([string]::IsNullOrWhiteSpace($columnName)) { continue }
            if ($columnName -match '^(Comment|Comments)$') {
                $columnValue = [string]$folder.GetDetailsOf($item, $i)
                if (-not [string]::IsNullOrWhiteSpace($columnValue)) {
                    return $columnValue.Trim()
                }
            }
        }

        # Targeted Word fallback for localized/custom Explorer views where the
        # visible comment can come from Subject/Keywords columns.
        if ($isWordOpenXml) {
            for ($i = 0; $i -lt 320; $i++) {
                $columnName = [string]$folder.GetDetailsOf($null, $i)
                if ([string]::IsNullOrWhiteSpace($columnName)) { continue }
                if ($columnName -match '^(Subject|Tag|Tags|Keyword|Keywords)$') {
                    $columnValue = [string]$folder.GetDetailsOf($item, $i)
                    if (-not [string]::IsNullOrWhiteSpace($columnValue)) {
                        return $columnValue.Trim()
                    }
                }
            }
        }

        return ''
    }
    catch {
        return ''
    }
}

function Get-ExcelWorkbookComment {
    param([string]$FilePath)
    $excel = $null
    $workbook = $null
    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return '' }
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $workbook = $excel.Workbooks.Open($FilePath, 0, $true)

        # Prefer numeric built-in property IDs because localized Office installs
        # may not expose stable English property names.
        $propertyIndexes = @(6, 2)
        foreach ($propertyIndex in $propertyIndexes) {
            try {
                $prop = $workbook.BuiltinDocumentProperties.Item($propertyIndex)
                $value = if ($null -ne $prop -and $null -ne $prop.Value) { [string]$prop.Value } else { '' }
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value.Trim()
                }
            }
            catch {
                # Continue probing alternate metadata slots.
            }
        }

        $propertyNames = @('Comments', 'Comment', 'Subject')
        foreach ($propertyName in $propertyNames) {
            try {
                $prop = $workbook.BuiltinDocumentProperties.Item($propertyName)
                $value = if ($null -ne $prop -and $null -ne $prop.Value) { [string]$prop.Value } else { '' }
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value.Trim()
                }
            }
            catch {
                # Continue probing alternate property names.
            }
        }

        return ''
    }
    catch {
        return ''
    }
    finally {
        if ($workbook) {
            $workbook.Close($false) | Out-Null
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        }
        if ($excel) {
            $excel.Quit()
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Set-ExcelWorkbookComment {
    param(
        [string]$FilePath,
        [string]$Comment
    )

    $excel = $null
    $workbook = $null
    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return $false }
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $workbook = $excel.Workbooks.Open($FilePath, 0, $false)

        $commentValue = if ($null -eq $Comment) { '' } else { [string]$Comment }

        # Write by numeric ID for locale-safe metadata updates.
        $propertyIndexes = @(6, 2)
        foreach ($propertyIndex in $propertyIndexes) {
            try {
                $prop = $workbook.BuiltinDocumentProperties.Item($propertyIndex)
                if ($null -ne $prop) {
                    $prop.Value = $commentValue
                }
            }
            catch {
                # Best effort for workbook metadata writes.
            }
        }

        $propertyNames = @('Comments', 'Comment', 'Subject')
        foreach ($propertyName in $propertyNames) {
            try {
                $prop = $workbook.BuiltinDocumentProperties.Item($propertyName)
                if ($null -ne $prop) {
                    $prop.Value = $commentValue
                }
            }
            catch {
                # Best effort for workbook metadata writes.
            }
        }

        $workbook.Save()
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($workbook) {
            $workbook.Close($true) | Out-Null
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        }
        if ($excel) {
            $excel.Quit()
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

<#
.SYNOPSIS
    Returns whether a file extension supports native metadata comments.

.DESCRIPTION
    Used by the comment editor to mark unsupported types as read-only with a
    visible indicator.

.PARAMETER FilePath
    Full path to the file.

.OUTPUTS
    System.Boolean
#>
function Test-CommentNativeSupport {
    param([string]$FilePath)

    $supportedExtensions = @(
        '.doc','.docx','.docm','.dot','.dotx','.dotm',
        '.xlsx','.xlsm','.xlsb','.xls',
        '.pptx','.pptm','.potx','.potm','.odt',
        '.pdf','.rtf',
        '.jpg','.jpeg','.png','.gif','.bmp',
        '.mp3','.wav','.flac','.m4a',
        '.mp4','.mkv','.avi'
    )

    $extension = [System.IO.Path]::GetExtension($FilePath)
    if ([string]::IsNullOrWhiteSpace($extension)) { return $false }
    return $supportedExtensions -contains $extension.ToLowerInvariant()
}

<#
.SYNOPSIS
    Adds file paths to the UI collection.

.DESCRIPTION
    Validates incoming paths, ignores duplicates, reads metadata, and appends new
    TouchFileItem rows to the observable collection.

.PARAMETER Paths
    One or more file paths to add.
#>
function Add-Files {
    param([string[]]$Paths)
    Write-SessionOutput -Message "Add-Files requested for $($Paths.Count) path(s)."
    Write-TraceLog -Message "Add-Files start. Count=$($Paths.Count) LoadCommentsDuringAdd=$script:loadCommentsDuringAdd"
    $added = 0
    $lastLoadedCommentSource = 'None'
    $script:bulkSelectionUpdate = $true
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Write-SessionOutput -Level WARN -Message "Skipped non-file path: $path"
            continue
        }
        try {
            $info = Get-Item -LiteralPath $path -ErrorAction Stop
        }
        catch {
            Write-SessionOutput -Level ERROR -Message "Failed to read path: $path"
            Add-ErrorLog -Context "Could not read file '$path'" -ErrorRecord $_
            continue
        }
        $full = $info.FullName
        if ($fileItems | Where-Object { $_.FullPath -eq $full }) {
            Write-SessionOutput -Message "Skipped duplicate file: $full"
            continue
        }
        $item = New-Object TouchFileItemV20260623
        $item.FullPath     = $info.FullName
        $item.BaseName     = [System.IO.Path]::GetFileName($info.FullName)
        $item.DisplayPath  = $info.FullName
        $item.LastModified = $info.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        $item.Size         = Format-Size $info.Length
        $item.Attributes   = Get-AttributeLetters -Attributes $info.Attributes
        $item.CommentSupported = Test-CommentNativeSupport -FilePath $info.FullName
        $item.CommentReadOnly = -not $item.CommentSupported
        $item.CommentSupportEmoji = if ($item.CommentSupported) { $script:commentSupportedEmoji } else { $script:commentNotSupportedEmoji }
        # Avoid UI lockups from COM-heavy metadata reads during drag/drop add.
        # Set TOUCHFILES_LOAD_COMMENTS_ON_ADD=1 to restore eager comment loading.
        if ($script:loadCommentsDuringAdd) {
            $item.Comment = Get-FileComment -FilePath $info.FullName
            $lastLoadedCommentSource = $script:lastCommentSource
        }
        else {
            $item.Comment = ''
            $lastLoadedCommentSource = 'Deferred'
        }
        $item.IsSelected   = $true
        $item.add_PropertyChanged($itemPropertyChangedHandler)
        $fileItems.Add($item)
        Write-TraceLog -Message "Added item: $full"
        Write-SessionOutput -Message "Added file: $full"
        $added++
    }
    $script:bulkSelectionUpdate = $false
    if ($added) { $lblStatus.Text = "Added $added file(s). Last comment source: $lastLoadedCommentSource" }
    Write-TraceLog -Level INFO -Message "Add-Files complete. Added=$added LastCommentSource=$lastLoadedCommentSource"
    Write-SessionOutput -Message "Add-Files completed. Added $added file(s)."
    Update-UiState
}

function Refresh-FileEntries {
    if ($script:refreshInProgress) {
        Write-SessionOutput -Level WARN -Message 'Refresh already in progress.'
        Write-TraceLog -Level WARN -Message 'Refresh request ignored because a refresh is already in progress.'
        return
    }

    Write-SessionOutput -Message 'Refresh command started for all entries.'
    $selectedPaths = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $fileItems) {
        if ($entry.IsSelected -and -not [string]::IsNullOrWhiteSpace($entry.FullPath)) {
            [void]$selectedPaths.Add($entry.FullPath)
        }
    }

    $entries = @($fileItems)
    $total = $entries.Count
    Write-TraceLog -Level INFO -Message "Refresh starting. Total entries: $total"
    if ($total -eq 0) {
        $lblStatus.Text = 'No entries to refresh.'
        Write-TraceLog -Message 'Refresh ended early because no entries were present.'
        return
    }

    $script:refreshInProgress = $true
    if ($btnRefresh) { $btnRefresh.IsEnabled = $false }
    Update-UiState
    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait

    $updated = 0
    $missing = 0
    $index = 0
    # Keep each UI tick small so the window remains interactive while refreshing.
    $batchSize = 8
    $refreshTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:refreshTimer = $refreshTimer
    $refreshTimer.Interval = [TimeSpan]::FromMilliseconds(20)
    $refreshTimer.Add_Tick({
        try {
            $processedThisTick = 0
            $script:bulkSelectionUpdate = $true
            $tickStart = [System.Diagnostics.Stopwatch]::StartNew()

            while ($processedThisTick -lt $batchSize -and $index -lt $total) {
                $entry = $entries[$index]
                $index++
                $processedThisTick++

                if (-not $entry -or [string]::IsNullOrWhiteSpace($entry.FullPath)) { continue }
                Write-TraceLog -Message "Refresh inspecting: $($entry.FullPath)"

                if (-not (Test-Path -LiteralPath $entry.FullPath -PathType Leaf)) {
                    $entry.LastModified = '<missing>'
                    $entry.Size = '<missing>'
                    $entry.Attributes = '<missing>'
                    $entry.Comment = ''
                    $entry.IsSelected = $selectedPaths.Contains($entry.FullPath)
                    $missing++
                    Write-TraceLog -Level WARN -Message "Refresh missing file: $($entry.FullPath)"
                    continue
                }

                try {
                    $info = Get-Item -LiteralPath $entry.FullPath -ErrorAction Stop
                    $entry.BaseName = [System.IO.Path]::GetFileName($info.FullName)
                    $entry.DisplayPath = $info.FullName
                    $entry.LastModified = $info.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                    $entry.Size = Format-Size $info.Length
                    $entry.Attributes = Get-AttributeLetters -Attributes $info.Attributes
                    $entry.CommentSupported = Test-CommentNativeSupport -FilePath $info.FullName
                    $entry.CommentReadOnly = -not $entry.CommentSupported
                    $entry.CommentSupportEmoji = if ($entry.CommentSupported) { $script:commentSupportedEmoji } else { $script:commentNotSupportedEmoji }
                    # Keep refresh responsive: preserve existing comments and avoid COM-heavy
                    # metadata reads during bulk refresh.
                    $entry.IsSelected = $selectedPaths.Contains($entry.FullPath)
                    $updated++
                    Write-TraceLog -Message "Refresh updated: $($entry.FullPath)"
                }
                catch {
                    Write-TraceLog -Level ERROR -Message "Refresh failed for $($entry.FullPath): $($_.Exception.Message)"
                    Add-ErrorLog -Context "Refresh failed for '$($entry.FullPath)'" -ErrorRecord $_
                }
            }

            $tickStart.Stop()
            Write-TraceLog -Message "Refresh tick complete. Processed=$processedThisTick Index=$index/$total DurationMs=$($tickStart.ElapsedMilliseconds)"

            if ($lblStatus) {
                $lblStatus.Text = "Refreshing $index/$total ... Updated: $updated Missing: $missing"
            }

            if ($index -ge $total) {
                $refreshTimer.Stop()
                $script:refreshInProgress = $false
                $script:refreshTimer = $null
                if ($btnRefresh) { $btnRefresh.IsEnabled = $true }
                [System.Windows.Input.Mouse]::OverrideCursor = $null
                Write-TraceLog -Level INFO -Message "Refresh finished. Updated=$updated Missing=$missing"
                if ($lblStatus) {
                    $lblStatus.Text = "Refreshed $updated file(s). Missing: $missing. Selections kept. Comments preserved."
                }
                Write-SessionOutput -Message "Refresh command completed. Updated: $updated Missing: $missing"
                Update-UiState
                Flash-ListViews
            }
        }
        catch {
            $refreshTimer.Stop()
            $script:refreshInProgress = $false
            $script:refreshTimer = $null
            if ($btnRefresh) { $btnRefresh.IsEnabled = $true }
            [System.Windows.Input.Mouse]::OverrideCursor = $null
            Write-TraceLog -Level ERROR -Message "Refresh timer failed: $($_.Exception.Message)"
            Add-ErrorLog -Context 'Refresh timer failed' -ErrorRecord $_
            if ($lblStatus) {
                $lblStatus.Text = 'Refresh stopped due to an error. See diagnostics.'
            }
        }
        finally {
            $script:bulkSelectionUpdate = $false
        }
    })
    $refreshTimer.Start()
}

function Test-RefreshIsolation {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths,
        [int]$BatchSize = 25
    )

    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    $results = New-Object System.Collections.Generic.List[object]
    $index = 0

    foreach ($path in $Paths) {
        $index++
        $swItem = [System.Diagnostics.Stopwatch]::StartNew()
        $status = 'OK'
        $detail = ''
        $exists = $false
        $size = $null

        try {
            $exists = Test-Path -LiteralPath $path -PathType Leaf
            if (-not $exists) {
                $status = 'Missing'
                $detail = 'Path does not exist.'
            }
            else {
                $info = Get-Item -LiteralPath $path -ErrorAction Stop
                $size = $info.Length
                [void](Get-AttributeLetters -Attributes $info.Attributes)
                [void](Test-CommentNativeSupport -FilePath $info.FullName)
            }
        }
        catch {
            $status = 'Error'
            $detail = $_.Exception.Message
        }
        finally {
            $swItem.Stop()
        }

        $row = [PSCustomObject]@{
            Index = $index
            Status = $status
            ElapsedMs = $swItem.ElapsedMilliseconds
            Exists = $exists
            Size = $size
            Path = $path
            Detail = $detail
        }
        $results.Add($row) | Out-Null

        if (($index % [Math]::Max(1, $BatchSize)) -eq 0) {
            Write-Host ("Processed {0}/{1} ..." -f $index, $Paths.Count)
        }
    }

    $swTotal.Stop()
    Write-Host ("Isolation test complete. Files={0} TotalMs={1}" -f $Paths.Count, $swTotal.ElapsedMilliseconds)
    return $results
}

function Flash-ListViews {
    try {
        $targets = @($fileTableBorder, $fileCardBorder) | Where-Object {
            $_ -and $_.Visibility -eq [System.Windows.Visibility]::Visible
        }
        if (-not $targets -or $targets.Count -eq 0) { return }

        $highlightBorder = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xF5, 0xC8, 0x42))
        $highlightBackground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xFF, 0xF2, 0xC2))
        $states = New-Object System.Collections.Generic.List[object]

        foreach ($target in $targets) {
            $states.Add([PSCustomObject]@{
                Target = $target
                Background = $target.Background
                BorderBrush = $target.BorderBrush
                BorderThickness = $target.BorderThickness
            }) | Out-Null

            $target.Background = $highlightBackground
            $target.BorderBrush = $highlightBorder
            $target.BorderThickness = New-Object System.Windows.Thickness(2)
        }

        $flashTimer = New-Object System.Windows.Threading.DispatcherTimer
        $flashTimer.Interval = [TimeSpan]::FromMilliseconds(500)
        $flashTimer.Add_Tick({
            $flashTimer.Stop()
            foreach ($state in $states) {
                $state.Target.Background = $state.Background
                $state.Target.BorderBrush = $state.BorderBrush
                $state.Target.BorderThickness = $state.BorderThickness
            }
        })
        $flashTimer.Start()
    }
    catch {
        # Flash feedback is best effort only.
    }
}

# Provide Explorer drag-over feedback so the UI reports whether dropping is permitted.
$dragOverHandler = {
    param($sourceObject,$dragArgs)
    if ($dragArgs.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $dragArgs.Effects = [System.Windows.DragDropEffects]::Copy
    } else {
        $dragArgs.Effects = [System.Windows.DragDropEffects]::None
    }
    $dragArgs.Handled = $true
}

# Accept dropped files and forward them into the Add-Files pipeline.
$dropHandler = {
    param($sourceObject,$dropArgs)
    try {
        if ($dropArgs.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            if ($chkClearOnDrop -and $chkClearOnDrop.IsChecked -eq $true) {
                Write-SessionOutput -Message "Drop operation requested clear-before-drop."
                $fileItems.Clear()
                Update-UiState
            }
            $files = $dropArgs.Data.GetData([System.Windows.DataFormats]::FileDrop)
            Write-SessionOutput -Message "Drop received $($files.Count) file(s)."
            Add-Files -Paths $files
        }
    }
    catch {
        Add-ErrorLog -Context 'Failed during drag/drop processing' -ErrorRecord $_
    }
    finally {
        # Defensive reset in case a prior operation left an override cursor active.
        [System.Windows.Input.Mouse]::OverrideCursor = $null
        if ($script:refreshInProgress -and (-not $script:refreshTimer -or -not $script:refreshTimer.IsEnabled)) {
            $script:refreshInProgress = $false
            $script:refreshTimer = $null
            Write-TraceLog -Level WARN -Message 'Drop handler cleared stale refresh busy-state.'
        }
        Update-UiState
    }
    $dropArgs.Handled = $true
}

$fileList.Add_PreviewDragOver($dragOverHandler)
$fileList.Add_Drop($dropHandler)
if ($fileCardList) {
    $fileCardList.Add_PreviewDragOver($dragOverHandler)
    $fileCardList.Add_Drop($dropHandler)
}

# Save comments when TextBox loses focus (grid view).
$fileList.Add_LostKeyboardFocus({
    param($sourceObject,$focusArgs)
    try {
        $textBox = $focusArgs.Source -as [System.Windows.Controls.TextBox]
        if ($textBox) {
            $textValue = if ($null -eq $textBox.Text) { '' } else { [string]$textBox.Text }
            $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($textBox)
            while ($parent -and -not ($parent -is [System.Windows.Controls.ListViewItem])) {
                $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
            }
            if ($parent) {
                $item = $parent.DataContext -as [TouchFileItemV20260623]
                if ($item -and $item.FullPath) {
                    $item.Comment = $textValue
                    Set-FileComment -FilePath $item.FullPath -Comment $textValue
                }
            }
        }
    }
    catch {
        # Silently ignore errors in focus/save logic
    }
})

# Save comments when TextBox loses focus (card view).
if ($fileCardList) {
    $fileCardList.Add_LostKeyboardFocus({
        param($sourceObject,$focusArgs)
        try {
            $textBox = $focusArgs.Source -as [System.Windows.Controls.TextBox]
            if ($textBox) {
                $textValue = if ($null -eq $textBox.Text) { '' } else { [string]$textBox.Text }
                $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($textBox)
                while ($parent -and -not ($parent -is [System.Windows.Controls.ListBoxItem])) {
                    $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
                }
                if ($parent) {
                    $item = $parent.DataContext -as [TouchFileItemV20260623]
                    if ($item -and $item.FullPath) {
                        $item.Comment = $textValue
                        Set-FileComment -FilePath $item.FullPath -Comment $textValue
                    }
                }
            }
        }
        catch {
            # Silently ignore errors in focus/save logic
        }
    })
}

# Push files from the OpenFileDialog into the collection, honoring multiselect.
$btnAdd.Add_Click({
    try {
        Write-SessionOutput -Message 'Add File dialog opened.'
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Multiselect = $true
        if ($dlg.ShowDialog()) {
            Write-SessionOutput -Message "Add File dialog selected $($dlg.FileNames.Count) file(s)."
            Add-Files -Paths $dlg.FileNames
        }
        else {
            Write-SessionOutput -Message 'Add File dialog cancelled by user.'
        }
    }
    catch {
        Add-ErrorLog -Context 'Add File dialog failed' -ErrorRecord $_
    }
})

# Update LastWriteTime for the currently selected rows, refreshing metadata after each write.
$btnTouch.Add_Click({
    $selected = Get-SelectedItems
    if (-not $selected) {
        $lblStatus.Text = "Select one or more files to touch"
        Write-SessionOutput -Level WARN -Message 'Touch command skipped. No files selected.'
        return
    }
    Write-SessionOutput -Message "Touch command started for $($selected.Count) selected file(s)."
    $now = Get-Date
    $touched = 0
    foreach ($item in $selected) {
        try {
            if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
            $file = Get-Item -LiteralPath $item.FullPath -ErrorAction Stop
            $file.LastWriteTime = $now
            $item.LastModified = $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            $item.Size = Format-Size $file.Length
            $item.Attributes = Get-AttributeLetters -Attributes $file.Attributes
            Write-SessionOutput -Message "Touched file: $($item.FullPath)"
            $touched++
        }
        catch {
            Add-ErrorLog -Context "Touch failed for '$($item.FullPath)'" -ErrorRecord $_
        }
    }
    $lblStatus.Text = if ($touched) { "Touched $touched selected file(s)" } else { "No selected files touched" }
    Write-SessionOutput -Message "Touch command completed. Success count: $touched"
    Update-UiState
})

# Toggle NTFS compression via compact.exe for each selected file, then refresh attributes.
$btnToggle.Add_Click({
    $selected = Get-SelectedItems
    if (-not $selected) {
        Write-SessionOutput -Level WARN -Message 'Compression command skipped. No files selected.'
        return
    }
    Write-SessionOutput -Message "Compression command started for $($selected.Count) selected file(s)."
    $compressionSuccess = 0
    $compressionFailed = 0
    foreach ($item in $selected) {
        try {
            if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
            $file = Get-Item -LiteralPath $item.FullPath -ErrorAction Stop
            $isCompressed = $file.Attributes.HasFlag([System.IO.FileAttributes]::Compressed)
            $compactArgs = if ($isCompressed) { @('/U','/I','/Q',"`"$($file.FullName)`"") } else { @('/C','/I','/Q',"`"$($file.FullName)`"") }
            $compactProcess = Start-Process -FilePath "$env:SystemRoot\System32\compact.exe" -ArgumentList $compactArgs -NoNewWindow -PassThru -Wait
            if ($compactProcess.ExitCode -ne 0) {
                throw "compact.exe exited with code $($compactProcess.ExitCode)."
            }
            $file = Get-Item -LiteralPath $item.FullPath -ErrorAction Stop
            $item.Attributes = Get-AttributeLetters -Attributes $file.Attributes
            $item.Size = Format-Size $file.Length
            Write-SessionOutput -Message "Compression toggled: $($item.FullPath)"
            $compressionSuccess++
        }
        catch {
            $compressionFailed++
            Add-ErrorLog -Context "Compression toggle failed for '$($item.FullPath)'" -ErrorRecord $_
        }
    }

    if ($compressionSuccess -lt $selected.Count) {
        $lblStatus.Text = "Compression incomplete: succeeded $compressionSuccess of $($selected.Count); failed $compressionFailed"
        Add-ErrorLog -Context 'Compression summary mismatch' -Message "Only $compressionSuccess of $($selected.Count) selected file(s) completed compression toggle."
    }
    else {
        $lblStatus.Text = "Toggled compression on $compressionSuccess file(s)"
    }
    Write-SessionOutput -Message "Compression command completed. Success: $compressionSuccess Failed: $compressionFailed"
    Update-UiState
})
# Add encryption toggle handler
if ($btnEnc) {
    $btnEnc.Add_Click({
        $selected = Get-SelectedItems
        if (-not $selected) {
            Write-SessionOutput -Level WARN -Message 'Encryption command skipped. No files selected.'
            return
        }
        Write-SessionOutput -Message "Encryption command started for $($selected.Count) selected file(s)."
        foreach ($item in $selected) {
            try {
                if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
                $file = Get-Item -LiteralPath $item.FullPath -ErrorAction Stop
                $isEncrypted = $file.Attributes.HasFlag([System.IO.FileAttributes]::Encrypted)
                $cipherArgs = if ($isEncrypted) { @('/D', "`"$($file.FullName)`"") } else { @('/E', "`"$($file.FullName)`"") }
                $cipherProcess = Start-Process -FilePath "$env:SystemRoot\System32\cipher.exe" -ArgumentList $cipherArgs -NoNewWindow -PassThru -Wait
                if ($cipherProcess.ExitCode -ne 0) {
                    throw "cipher.exe exited with code $($cipherProcess.ExitCode)."
                }
                $file = Get-Item -LiteralPath $item.FullPath -ErrorAction Stop
                $item.Attributes = Get-AttributeLetters -Attributes $file.Attributes
                Write-SessionOutput -Message "Encryption toggled: $($item.FullPath)"
            }
            catch {
                Add-ErrorLog -Context "Encryption toggle failed for '$($item.FullPath)'" -ErrorRecord $_
            }
        }
        $lblStatus.Text = "Toggled encryption on $($selected.Count) file(s)"
        Write-SessionOutput -Message "Encryption command completed for $($selected.Count) file(s)."
        Update-UiState
    })
}
# Add read-only attribute toggle handler
if ($btnReadOnly) {
    $btnReadOnly.Add_Click({
        $selected = Get-SelectedItems
        if (-not $selected) {
            Write-SessionOutput -Level WARN -Message 'Read-Only command skipped. No files selected.'
            return
        }
        Write-SessionOutput -Message "Read-Only command started for $($selected.Count) selected file(s)."
        foreach ($item in $selected) {
            if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
            try {
                $currentAttributes = [System.IO.File]::GetAttributes($item.FullPath)
                $newAttributes = $currentAttributes -bxor [System.IO.FileAttributes]::ReadOnly
                [System.IO.File]::SetAttributes($item.FullPath, $newAttributes)
                $item.Attributes = Get-AttributeLetters -Attributes $newAttributes
                Write-SessionOutput -Message "Read-Only toggled: $($item.FullPath)"
            }
            catch {
                Add-ErrorLog -Context "Read-Only toggle failed for '$($item.FullPath)'" -ErrorRecord $_
                continue
            }
        }
        $lblStatus.Text = "Toggled read-only on $($selected.Count) file(s)"
        Write-SessionOutput -Message "Read-Only command completed for $($selected.Count) file(s)."
        Update-UiState
    })
}
# Add date stamp to file name handler (adds or removes date stamp)
if ($btnDateStamp) {
    $btnDateStamp.Add_Click({
        $selected = Get-SelectedItems
        if (-not $selected) {
            Write-SessionOutput -Level WARN -Message 'Date Stamp command skipped. No files selected.'
            return
        }

        $dateStamp = (Get-Date).ToString('yyyy-MM-dd-ddd')
        $successCount = 0
        $failCount = 0
        $isRemoveMode = ($selected.Count -eq 1)

        if ($isRemoveMode) {
            $item = $selected[0]
            if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) {
                Write-SessionOutput -Level WARN -Message 'Date Stamp command skipped. File does not exist.'
                $lblStatus.Text = "Date stamp failed: file not found"
                return
            }

            try {
                $fileInfo = Get-Item -LiteralPath $item.FullPath -ErrorAction Stop
                $directory = $fileInfo.DirectoryName
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileInfo.Name)
                $extension = $fileInfo.Extension

                if ($baseName -match '^(.+)-\d{4}-\d{2}-\d{2}-\w{3}$') {
                    $newBaseName = $matches[1]
                    $newFileName = "$newBaseName$extension"
                    $newFullPath = Join-Path $directory $newFileName

                    if (Test-Path -LiteralPath $newFullPath) {
                        Write-SessionOutput -Level WARN -Message "Cannot remove date stamp: target file already exists: $newFullPath"
                        $lblStatus.Text = "Date stamp removal failed: target exists"
                        return
                    }

                    Rename-Item -LiteralPath $item.FullPath -NewName $newFileName -ErrorAction Stop

                    $item.FullPath = $newFullPath
                    $item.BaseName = $newBaseName + $extension
                    $item.DisplayPath = $newFullPath

                    Write-SessionOutput -Message "Date stamp removed: $($fileInfo.Name) -> $newFileName"
                    $lblStatus.Text = "Date stamp removed from file"
                }
                else {
                    $newBaseName = "$baseName-$dateStamp"
                    $newFileName = "$newBaseName$extension"
                    $newFullPath = Join-Path $directory $newFileName

                    if (Test-Path -LiteralPath $newFullPath) {
                        Write-SessionOutput -Level WARN -Message "Cannot add date stamp: target file already exists: $newFullPath"
                        $lblStatus.Text = "Date stamp failed: target exists"
                        return
                    }

                    Rename-Item -LiteralPath $item.FullPath -NewName $newFileName -ErrorAction Stop

                    $item.FullPath = $newFullPath
                    $item.BaseName = $newBaseName + $extension
                    $item.DisplayPath = $newFullPath

                    Write-SessionOutput -Message "Date stamped: $($fileInfo.Name) -> $newFileName"
                    $lblStatus.Text = "Date stamp added to file"
                }
            }
            catch {
                Add-ErrorLog -Context "Date stamp operation failed for '$($item.FullPath)'" -ErrorRecord $_
                $lblStatus.Text = "Date stamp operation failed"
            }
        }
        else {
            Write-SessionOutput -Message "Date Stamp command started for $($selected.Count) selected file(s)."

            foreach ($item in $selected) {
                if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) {
                    $failCount++
                    continue
                }
                try {
                    $fileInfo = Get-Item -LiteralPath $item.FullPath -ErrorAction Stop
                    $directory = $fileInfo.DirectoryName
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileInfo.Name)
                    $extension = $fileInfo.Extension

                    if ($baseName -match '\d{4}-\d{2}-\d{2}-\w{3}$') {
                        Write-SessionOutput -Level WARN -Message "Skipped (already has date stamp): $($item.FullPath)"
                        $failCount++
                        continue
                    }

                    $newBaseName = "$baseName-$dateStamp"
                    $newFileName = "$newBaseName$extension"
                    $newFullPath = Join-Path $directory $newFileName

                    if (Test-Path -LiteralPath $newFullPath) {
                        Write-SessionOutput -Level WARN -Message "Skipped (target exists): $newFullPath"
                        $failCount++
                        continue
                    }

                    Rename-Item -LiteralPath $item.FullPath -NewName $newFileName -ErrorAction Stop

                    $item.FullPath = $newFullPath
                    $item.BaseName = $newBaseName + $extension
                    $item.DisplayPath = $newFullPath

                    Write-SessionOutput -Message "Date stamped: $($fileInfo.Name) -> $newFileName"
                    $successCount++
                }
                catch {
                    Add-ErrorLog -Context "Date stamp failed for '$($item.FullPath)'" -ErrorRecord $_
                    $failCount++
                    continue
                }
            }

            if ($successCount -gt 0) {
                $lblStatus.Text = "Date stamped $successCount file(s)"
                if ($failCount -gt 0) {
                    $lblStatus.Text += " ($failCount failed/skipped)"
                }
            }
            else {
                $lblStatus.Text = "Date stamp failed for all selected files"
            }
            Write-SessionOutput -Message "Date Stamp command completed: $successCount succeeded, $failCount failed/skipped."
        }

        Update-UiState
    })
}
# Add hidden attribute toggle handler
if ($btnHidden) {
    $btnHidden.Add_Click({
        $selected = Get-SelectedItems
        if (-not $selected) {
            Write-SessionOutput -Level WARN -Message 'Hidden command skipped. No files selected.'
            return
        }
        Write-SessionOutput -Message "Hidden command started for $($selected.Count) selected file(s)."
        foreach ($item in $selected) {
            if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
            try {
                $currentAttributes = [System.IO.File]::GetAttributes($item.FullPath)
                $newAttributes = $currentAttributes -bxor [System.IO.FileAttributes]::Hidden
                [System.IO.File]::SetAttributes($item.FullPath, $newAttributes)
                $item.Attributes = Get-AttributeLetters -Attributes $newAttributes
                Write-SessionOutput -Message "Hidden toggled: $($item.FullPath)"
            }
            catch {
                Add-ErrorLog -Context "Hidden toggle failed for '$($item.FullPath)'" -ErrorRecord $_
                continue
            }
        }
        $lblStatus.Text = "Toggled hidden on $($selected.Count) file(s)"
        Write-SessionOutput -Message "Hidden command completed for $($selected.Count) file(s)."
        Update-UiState
    })
}

# Refresh all entries while preserving selection state.
if ($btnRefresh) {
    $btnRefresh.Add_Click({
        Refresh-FileEntries
    })
}

# Remove every entry from the collection and reset UI indicators.
$btnClear.Add_Click({
    if ($script:refreshTimer) {
        try { $script:refreshTimer.Stop() } catch {}
        $script:refreshTimer = $null
    }
    $script:refreshInProgress = $false
    [System.Windows.Input.Mouse]::OverrideCursor = $null

    $removed = $fileItems.Count
    $fileItems.Clear()
    Write-SessionOutput -Message "Clear command removed $removed file(s) from the list."
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
        Set-PathVisibility -HidePaths $script:compactMode
        Save-WindowSettings
    })
}

if ($chkClearOnDrop) {
    $chkClearOnDrop.Add_Click({ Save-WindowSettings })
}

if ($script:chkRememberWindow) {
    $script:chkRememberWindow.Add_Click({ Save-WindowSettings })
}

if ($chkAlwaysOnTop) {
    $chkAlwaysOnTop.Add_Click({
        $window.Topmost = ($chkAlwaysOnTop.IsChecked -eq $true)
        Save-WindowSettings
    })
}

if ($btnCommentDiag) {
    $btnCommentDiag.Add_Click({
        try {
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait

            $focusedTextBox = [System.Windows.Input.Keyboard]::FocusedElement -as [System.Windows.Controls.TextBox]
            if ($focusedTextBox) {
                $binding = $focusedTextBox.GetBindingExpression([System.Windows.Controls.TextBox]::TextProperty)
                if ($binding) { $binding.UpdateSource() }
            }

            $selected = Get-SelectedItems
            if ($selected.Count -ne 1) {
                return
            }

            $targetItem = $selected[0]
            if (-not $targetItem -or [string]::IsNullOrWhiteSpace($targetItem.FullPath)) {
                return
            }

            # Ensure diagnostics reflects the latest in-editor value.
            Set-FileComment -FilePath $targetItem.FullPath -Comment $targetItem.Comment

            Write-SessionOutput -Message "Comment diagnostics requested for: $($targetItem.FullPath)"
            $report = Get-FileCommentDiagnosticsReport -FilePath $targetItem.FullPath
            Show-CommentDiagnosticsWindow -FilePath $targetItem.FullPath -ReportText $report
        }
        catch {
            Add-ErrorLog -Context 'Comment diagnostics button failed' -ErrorRecord $_
        }
        finally {
            [System.Windows.Input.Mouse]::OverrideCursor = $null
        }
    })
}

if ($btnErrorLog) {
    $btnErrorLog.Add_Click({ Show-ErrorLogWindow })
}

if ($btnDockNarrow) {
    $btnDockNarrow.Add_Click({
        if ($script:dockMode -eq 'narrow-left') {
            Set-WindowDockMode -Mode 'narrow-right'
        }
        else {
            Set-WindowDockMode -Mode 'narrow-left'
        }
    })
}

if ($btnDockHalf) {
    $btnDockHalf.Add_Click({
        if ($script:dockMode -eq 'half-left') {
            Set-WindowDockMode -Mode 'half-right'
        }
        else {
            Set-WindowDockMode -Mode 'half-left'
        }
    })
}

if ($btnNextMonitor) {
    $btnNextMonitor.Add_Click({ Move-WindowToNextMonitor })
}

if ($btnAbout) {
    Write-TraceLog -Message 'Registering About button click handler' -Level INFO
    $btnAbout.Add_Click({
        try {
            Write-TraceLog -Message 'About button clicked' -Level INFO
            Show-AboutDialog
        }
        catch {
            Add-ErrorLog -Context 'About button click handler' -ErrorRecord $_
            [System.Windows.MessageBox]::Show(
                "About button handler failed.`r`n$($_.Exception.Message)`r`n`r`nErrorId: $($script:lastErrorId)",
                'Touch Files - About Button Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
        }
    })
}
else {
    Write-TraceLog -Message 'WARNING: Cannot register About button handler - button is null' -Level WARN
}

if ($btnVersionHistory) {
    $btnVersionHistory.Add_Click({
        $confirmResult = [System.Windows.MessageBox]::Show(
            "Append a new version metrics row to:`r`n$script:versionsHistoryPath",
            'Append Version Snapshot',
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        if ($confirmResult -ne [System.Windows.MessageBoxResult]::Yes) {
            return
        }

        try {
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            $ok = Add-VersionHistorySnapshot
            if ($ok) {
                [void][System.Windows.MessageBox]::Show(
                    "Version metrics row appended successfully.`r`n`r`nFile:`r`n$script:versionsHistoryPath",
                    'Version Snapshot Appended',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
            }
            else {
                [void][System.Windows.MessageBox]::Show(
                    "Append failed. Check diagnostics/error log for details.",
                    'Version Snapshot Failed',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                )
            }
        }
        finally {
            [System.Windows.Input.Mouse]::OverrideCursor = $null
        }
    })
}

if ($headerClickArea) {
    Write-TraceLog -Message 'Registering HeaderClickArea MouseLeftButtonUp handler for About dialog' -Level INFO
    $headerClickArea.Add_MouseLeftButtonUp({
        try {
            Write-TraceLog -Message 'HeaderClickArea clicked - opening About dialog' -Level INFO
            Show-AboutDialog
        }
        catch {
            Add-ErrorLog -Context 'HeaderClickArea click handler' -ErrorRecord $_
            [System.Windows.MessageBox]::Show(
                "Header click handler failed.`r`n$($_.Exception.Message)`r`n`r`nErrorId: $($script:lastErrorId)",
                'Touch Files - Header Click Error',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
        }
    })
}
else {
    Write-TraceLog -Message 'WARNING: HeaderClickArea not found - cannot register click handler' -Level WARN
}

if ($headerLogoBorder) {
    $headerLogoBorder.Add_MouseLeftButtonUp({ Show-AboutDialog })
}

if ($txtAppTitle) {
    $txtAppTitle.Add_MouseLeftButtonUp({ Show-AboutDialog })
}

if ($env:TOUCHFILES_ISOLATE_REFRESH -eq '1') {
    $isolationPaths = @()

    if (-not [string]::IsNullOrWhiteSpace($env:TOUCHFILES_ISOLATE_PATHS_FILE) -and
        (Test-Path -LiteralPath $env:TOUCHFILES_ISOLATE_PATHS_FILE -PathType Leaf)) {
        $isolationPaths = @(
            Get-Content -LiteralPath $env:TOUCHFILES_ISOLATE_PATHS_FILE |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:TOUCHFILES_ISOLATE_PATHS)) {
        $isolationPaths = @(
            $env:TOUCHFILES_ISOLATE_PATHS.Split(';') |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    if (-not $isolationPaths -or $isolationPaths.Count -eq 0) {
        Write-Host 'Isolation mode enabled, but no input paths were provided.'
        Write-Host 'Set TOUCHFILES_ISOLATE_PATHS (semicolon-separated) or TOUCHFILES_ISOLATE_PATHS_FILE (one path per line).'
        return
    }

    Write-Host "Isolation mode running for $($isolationPaths.Count) path(s)..."
    $isolationResults = Test-RefreshIsolation -Paths $isolationPaths
    $slowest = @($isolationResults | Sort-Object ElapsedMs -Descending | Select-Object -First 20)
    if ($slowest.Count -gt 0) {
        Write-Host ''
        Write-Host 'Top 20 slowest paths:'
        $slowest | Format-Table Index, Status, ElapsedMs, Exists, Path -AutoSize
    }
    return
}

# Initialize the UI to a clean state and display the initial timestamp.
Update-UiState
Update-ResponsiveLayout
Update-PathColumnWidth
$lblNow.Text = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
Initialize-WindowMetricsOverlay
Set-WindowMinimumWidth
Restore-WindowSettings

if (-not (Test-StartupHelperFunctions)) {
    return
}

# Keep dispatcher-level UI exceptions from terminating the main dialog.
$window.Dispatcher.Add_UnhandledException({
    param($senderObject, $dispatcherArgs)
    try {
        $uiErrorMessage = if ($dispatcherArgs -and $dispatcherArgs.Exception) {
            [string]$dispatcherArgs.Exception.Message
        }
        else {
            'Unknown unhandled UI exception.'
        }
        Add-ErrorLog -Context 'Unhandled UI exception' -Message $uiErrorMessage
    }
    catch {
        # Last-resort guard: avoid recursive exception handling failures.
    }

    if ($dispatcherArgs) {
        $dispatcherArgs.Handled = $true
    }

    if ($lblStatus) {
        $lblStatus.Text = 'Recovered from UI error. Check diagnostics.'
    }
})

# Re-evaluate responsive breakpoints whenever the user resizes the window.
$window.Add_SizeChanged({
    try {
        Update-ResponsiveLayout
        Update-PathColumnWidth
        Update-DiagnosticsVisibility
        Show-WindowMetricsTemporarily
    }
    catch {
        try { Add-ErrorLog -Context 'SizeChanged handler failed' -ErrorRecord $_ } catch {}
    }
})

# Track live X/Y values while the window moves.
$window.Add_LocationChanged({
    try {
        Show-WindowMetricsTemporarily
    }
    catch {
        try { Add-ErrorLog -Context 'LocationChanged handler failed' -ErrorRecord $_ } catch {}
    }
})

# Re-apply sizing once layout is fully realized.
$window.Add_ContentRendered({
    try {
        Update-ResponsiveLayout
        Update-PathColumnWidth
        Update-DiagnosticsVisibility
        Set-WindowMetricsOverlayWidth -LockWidth $true
        Update-WindowMetricsText
    }
    catch {
        try { Add-ErrorLog -Context 'ContentRendered handler failed' -ErrorRecord $_ } catch {}
    }
})

# Timer keeps the footer clock current while the window remains open.
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    try {
        if ($lblNow) {
            $lblNow.Text = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
    }
    catch {
        try { Add-ErrorLog -Context 'Footer timer tick failed' -ErrorRecord $_ } catch {}
    }
})
$timer.Start()

# Hide move/resize metrics shortly after interactions stop.
$script:windowMetricsHideTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:windowMetricsHideTimer.Interval = [TimeSpan]::FromMilliseconds($script:windowMetricsHideDelayMs)
$script:windowMetricsHideTimer.Add_Tick({
    try {
        $script:windowMetricsHideTimer.Stop()
        if ($lblWindowMetrics) {
            $lblWindowMetrics.Visibility = [System.Windows.Visibility]::Collapsed
        }
        if ($script:windowMetricsOverlayWindow -and $script:windowMetricsOverlayWindow.IsVisible) {
            $script:windowMetricsOverlayWindow.Hide()
        }
        Set-MainWindowOverlayDimming -Dim $false
    }
    catch {
        try { Add-ErrorLog -Context 'Window metrics hide timer failed' -ErrorRecord $_ } catch {}
    }
})

# Display the WPF window and tear down the timer when the dialog closes.
if (-not $window) {
    throw 'Main window object is null before ShowDialog.'
}

try { $window.ShowDialog() | Out-Null }
finally {
    Save-WindowSettings
    $timer.Stop()
    if ($script:sessionTranscriptActive) {
        try {
            Stop-Transcript | Out-Null
        }
        catch {
            $script:sessionTranscriptActive = $false
        }
        finally {
            $script:sessionTranscriptActive = $false
        }
    }
    if ($script:windowMetricsHideTimer) { $script:windowMetricsHideTimer.Stop() }
    Set-MainWindowOverlayDimming -Dim $false
    if ($script:windowMetricsOverlayWindow) { $script:windowMetricsOverlayWindow.Close() }
}

function Update-LastErrorIdBanner {
    if (-not $txtLastErrorId) { return }

    if ([string]::IsNullOrWhiteSpace($script:lastErrorId)) {
        $txtLastErrorId.Text = 'none'
        if ($btnCopyLastErrorId) { $btnCopyLastErrorId.IsEnabled = $false }
    }
    else {
        $txtLastErrorId.Text = $script:lastErrorId
        if ($btnCopyLastErrorId) { $btnCopyLastErrorId.IsEnabled = $true }
    }
}