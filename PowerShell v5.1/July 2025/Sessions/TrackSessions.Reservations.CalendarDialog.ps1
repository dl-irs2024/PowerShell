# TrackSessions.Reservations.CalendarDialog.ps1
# Phase 4: WPF Calendar Dialog
# Provides calendar-based reservation management with conflict detection

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReservationPath,
    [Parameter(Mandatory = $true)]
    [string]$SettingsPath,
    [Parameter(Mandatory = $true)]
    [string]$UsersPath,
    [Parameter(Mandatory = $false)]
    [string]$SelectedMachine = '',
    [Parameter(Mandatory = $false)]
    [datetime]$InitialDate = [datetime]::Now
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Import reservation modules - force complete reload
$modulePath = $PSScriptRoot
$reservationModulePath = Join-Path $modulePath 'TrackSessions.Reservations.psm1'

# Remove any cached version of the module
Remove-Module TrackSessions.Reservations -Force -ErrorAction SilentlyContinue

# Import fresh
Import-Module $reservationModulePath -Force

# Module variables
$script:CurrentMonth = $InitialDate.Date.AddDays(-($InitialDate.Day - 1))
$script:SelectedDate = $InitialDate.Date
$script:ReservationPath = $ReservationPath
$script:SettingsPath = $SettingsPath
$script:UsersPath = $UsersPath
$script:AllReservations = @()
$script:TrackedMachines = @()
$script:CurrentUser = $env:USERNAME
$script:AutoRefreshTimer = $null
$script:RefreshIntervalSeconds = 30

<#
.SYNOPSIS
    Gets list of tracked machines from settings.
#>
function Get-TrackedMachines {
    try {
        $settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
        # Defensively check for Tracking property first
        if ($settings.PSObject.Properties.Name -contains 'Tracking') {
            if ($settings.Tracking.PSObject.Properties.Name -contains 'Machines') {
                return @($settings.Tracking.Machines | Select-Object -ExpandProperty ShortName)
            }
        }
        return @()
    }
    catch {
        Write-Warning "Failed to load machines: $_"
        return @()
    }
}

<#
.SYNOPSIS
    Loads all reservations from disk.
#>
function Load-AllReservations {
    try {
        $allRes = Get-Reservations -ReservationPath $ReservationPath -Status '*'
        return @($allRes)
    }
    catch {
        Write-Warning "Failed to load reservations: $_"
        return @()
    }
}

<#
.SYNOPSIS
    Gets reservations for a specific date and machine.
#>
function Get-DayReservations {
    param(
        [datetime]$Date,
        [string]$MachineName
    )

    $dateStr = $Date.ToString('yyyy-MM-dd')
    return @($script:AllReservations | Where-Object {
        $_.ReservationDate -eq $dateStr -and
        $_.MachineName -eq $MachineName -and
        $_.Status -eq 'Active'
    } | Sort-Object StartTime)
}

<#
.SYNOPSIS
    Gets available time slots for a date/machine.
#>
function Get-AvailableTimeSlots {
    param(
        [datetime]$Date,
        [string]$MachineName
    )

    $settings = Get-ReservationSettings -SettingsPath $SettingsPath
    $businessStart = [timespan]::Parse($settings.BusinessHoursStart)
    $businessEnd = [timespan]::Parse($settings.BusinessHoursEnd)
    $granularity = $settings.TimeSlotGranularity

    $slots = @()
    $currentTime = $businessStart

    while ($currentTime -lt $businessEnd) {
        $timeStr = $currentTime.ToString('hh\:mm')
        
        # Check if slot is available
        $endTime = $currentTime.Add([timespan]::FromMinutes($granularity))
        $conflict = Test-ReservationConflict -MachineName $MachineName `
            -ReservationDate $Date.ToString('yyyy-MM-dd') `
            -StartTime $timeStr `
            -EndTime $endTime.ToString('hh\:mm') `
            -ReservationPath $ReservationPath

        $slots += @{
            StartTime = $timeStr
            EndTime = $endTime.ToString('hh\:mm')
            Available = -not $conflict.HasConflict
            IsConflict = $conflict.HasConflict
        }

        $currentTime = $endTime
    }

    return $slots
}

# XAML for calendar dialog
[xml]$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Machine Reservations Calendar'
        Width='1200'
        Height='800'
        MinWidth='800'
        MinHeight='600'
        WindowStartupLocation='CenterScreen'
        Background='#F5F5F5'>
    <DockPanel Margin='12'>
        <!-- Toolbar -->
        <Grid DockPanel.Dock='Top' Margin='0,0,0,12' Height='40'>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width='Auto'/>
                <ColumnDefinition Width='Auto'/>
                <ColumnDefinition Width='Auto'/>
                <ColumnDefinition Width='*'/>
                <ColumnDefinition Width='Auto'/>
                <ColumnDefinition Width='Auto'/>
            </Grid.ColumnDefinitions>

            <TextBlock Grid.Column='0' VerticalAlignment='Center' Text='Machine:' Margin='0,0,8,0'/>
            <ComboBox Grid.Column='1' Name='CmbMachine' Width='200' Height='28' VerticalAlignment='Center' Margin='0,0,16,0'/>

            <TextBlock Grid.Column='2' VerticalAlignment='Center' Text='View:' Margin='0,0,8,0'/>
            <StackPanel Grid.Column='3' Orientation='Horizontal' VerticalAlignment='Center'>
                <RadioButton Name='RdoMonth' Content='Month' Margin='0,0,16,0' IsChecked='True' VerticalAlignment='Center'/>
                <RadioButton Name='RdoDay' Content='Day' Margin='0,0,16,0' VerticalAlignment='Center'/>
                <RadioButton Name='RdoList' Content='List' VerticalAlignment='Center'/>
            </StackPanel>

            <Button Grid.Column='4' Name='BtnRefresh' Content='Refresh' Width='80' Height='28' Margin='0,0,8,0' ToolTip='Refresh reservations'/>
            <Button Grid.Column='5' Name='BtnClose' Content='Close' Width='80' Height='28' ToolTip='Close calendar'/>
        </Grid>

        <!-- Main content area -->
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width='2*'/>
                <ColumnDefinition Width='*'/>
            </Grid.ColumnDefinitions>

            <!-- Calendar/Day/List views -->
            <Grid Grid.Column='0' Name='CalendarContainer'>
                <!-- Month View -->
                <Grid Name='MonthView'>
                    <Grid.RowDefinitions>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='*'/>
                    </Grid.RowDefinitions>

                    <!-- Month/Year header -->
                    <Grid Grid.Row='0' Margin='0,0,0,12'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='Auto'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='Auto'/>
                        </Grid.ColumnDefinitions>
                        <Button Grid.Column='0' Name='BtnPrevMonth' Content='←' Width='40' Height='32' ToolTip='Previous month'/>
                        <TextBlock Grid.Column='1' Name='TxtMonthYear' HorizontalAlignment='Center' VerticalAlignment='Center' FontSize='16' FontWeight='Bold'/>
                        <Button Grid.Column='2' Name='BtnNextMonth' Content='→' Width='40' Height='32' ToolTip='Next month'/>
                    </Grid>

                    <!-- Day headers -->
                    <Grid Grid.Row='1' Margin='0,0,0,8'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Grid.Column='0' Text='Mon' FontWeight='Bold' TextAlignment='Center' Padding='4'/>
                        <TextBlock Grid.Column='1' Text='Tue' FontWeight='Bold' TextAlignment='Center' Padding='4'/>
                        <TextBlock Grid.Column='2' Text='Wed' FontWeight='Bold' TextAlignment='Center' Padding='4'/>
                        <TextBlock Grid.Column='3' Text='Thu' FontWeight='Bold' TextAlignment='Center' Padding='4'/>
                        <TextBlock Grid.Column='4' Text='Fri' FontWeight='Bold' TextAlignment='Center' Padding='4'/>
                        <TextBlock Grid.Column='5' Text='Sat' FontWeight='Bold' TextAlignment='Center' Padding='4'/>
                        <TextBlock Grid.Column='6' Text='Sun' FontWeight='Bold' TextAlignment='Center' Padding='4'/>
                    </Grid>

                    <!-- Calendar grid (populated by code) -->
                    <Grid Grid.Row='2' Name='CalendarGrid'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                    </Grid>
                </Grid>

                <!-- Day View (time slots) -->
                <ScrollViewer Name='DayView' Visibility='Collapsed' VerticalScrollBarVisibility='Auto'>
                    <StackPanel Name='DayViewContent' Margin='8'/>
                </ScrollViewer>

                <!-- List View -->
                <Grid Name='ListView' Visibility='Collapsed'>
                    <Grid.RowDefinitions>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='*'/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row='0' Name='TxtListViewHeader' Margin='0,0,0,8' FontWeight='Bold'/>
                    <DataGrid Grid.Row='1' Name='GridReservations' AutoGenerateColumns='False' CanUserAddRows='False'>
                        <DataGrid.Columns>
                            <DataGridTextColumn Header='Date' Binding='{Binding ReservationDate}' Width='100'/>
                            <DataGridTextColumn Header='Time' Binding='{Binding StartTime}' Width='80'/>
                            <DataGridTextColumn Header='User' Binding='{Binding UserDisplayName}' Width='150'/>
                            <DataGridTextColumn Header='Status' Binding='{Binding Status}' Width='80'/>
                            <DataGridTextColumn Header='Comments' Binding='{Binding Comments}' Width='*'/>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>
            </Grid>

            <!-- Right panel: Reservation details -->
            <Border Grid.Column='1' Background='White' Margin='12,0,0,0' CornerRadius='4' Padding='12'>
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='*'/>
                        <RowDefinition Height='Auto'/>
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row='0' Text='New Reservation' FontSize='14' FontWeight='Bold' Margin='0,0,0,12'/>

                    <Grid Grid.Row='1' Margin='0,0,0,8'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='Auto'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Grid.Column='0' Text='Date:' FontWeight='Bold' Margin='0,0,8,0'/>
                        <TextBlock Grid.Column='1' Name='TxtSelectedDate' Foreground='#0078d4' FontWeight='SemiBold'/>
                    </Grid>

                    <TextBlock Grid.Row='2' Text='Start Time:' FontWeight='Bold'/>
                    <ComboBox Grid.Row='2' Name='CmbStartTime' Margin='0,0,0,8'/>

                    <TextBlock Grid.Row='3' Text='Duration:' FontWeight='Bold'/>
                    <ComboBox Grid.Row='3' Name='CmbDuration' Margin='0,0,0,8'>
                        <ComboBoxItem>30 minutes</ComboBoxItem>
                        <ComboBoxItem>1 hour</ComboBoxItem>
                        <ComboBoxItem>1.5 hours</ComboBoxItem>
                        <ComboBoxItem>2 hours</ComboBoxItem>
                    </ComboBox>

                    <TextBlock Grid.Row='4' Text='Comments:' FontWeight='Bold'/>
                    <TextBox Grid.Row='4' Name='TxtComments' Margin='0,0,0,8' Height='60' TextWrapping='Wrap' AcceptsReturn='True'/>

                    <Grid Grid.Row='5' Margin='0,0,0,8'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <CheckBox Grid.Column='0' Name='ChkOverride' Content='Admin Override' VerticalAlignment='Center'/>
                        <TextBlock Grid.Column='1' Name='TxtConflictWarning' Foreground='#da3b01' TextWrapping='Wrap' VerticalAlignment='Center'/>
                    </Grid>

                    <Border Grid.Row='6' Background='#f3f2f1' CornerRadius='4' Padding='8' Margin='0,0,0,8'>
                        <TextBlock Name='TxtWarning' TextWrapping='Wrap' FontSize='12' Foreground='#900000'/>
                    </Border>

                    <Button Grid.Row='9' Name='BtnCreateReservation' Content='Create Reservation' Height='32' Background='#0078d4' Foreground='White' FontWeight='Bold'/>
                </Grid>
            </Border>
        </Grid>
    </DockPanel>
</Window>
"@

# Create window
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

# Get controls
$cmbMachine = $window.FindName('CmbMachine')
$rdoMonth = $window.FindName('RdoMonth')
$rdoDay = $window.FindName('RdoDay')
$rdoList = $window.FindName('RdoList')
$btnRefresh = $window.FindName('BtnRefresh')
$btnClose = $window.FindName('BtnClose')
$btnPrevMonth = $window.FindName('BtnPrevMonth')
$btnNextMonth = $window.FindName('BtnNextMonth')
$txtMonthYear = $window.FindName('TxtMonthYear')
$calendarGrid = $window.FindName('CalendarGrid')
$monthView = $window.FindName('MonthView')
$dayView = $window.FindName('DayView')
$dayViewContent = $window.FindName('DayViewContent')
$listView = $window.FindName('ListView')
$gridReservations = $window.FindName('GridReservations')
$txtListViewHeader = $window.FindName('TxtListViewHeader')

$txtSelectedDate = $window.FindName('TxtSelectedDate')
$cmbStartTime = $window.FindName('CmbStartTime')
$cmbDuration = $window.FindName('CmbDuration')
$txtComments = $window.FindName('TxtComments')
$chkOverride = $window.FindName('ChkOverride')
$txtConflictWarning = $window.FindName('TxtConflictWarning')
$txtWarning = $window.FindName('TxtWarning')
$btnCreateReservation = $window.FindName('BtnCreateReservation')

# Store as script variables to ensure accessibility in all event handlers
$script:monthView = $monthView
$script:dayView = $dayView
$script:dayViewContent = $dayViewContent
$script:listView = $listView
$script:cmbMachine = $cmbMachine
$script:cmbStartTime = $cmbStartTime
$script:cmbDuration = $cmbDuration
$script:calendarGrid = $calendarGrid
$script:txtSelectedDate = $txtSelectedDate

<#
.SYNOPSIS
    Renders the month view calendar.
#>
function Render-MonthCalendar {
    $calendarGrid.Children.Clear()
    $calendarGrid.RowDefinitions.Clear()

    # Get first day of month and number of days
    $firstDay = $script:CurrentMonth
    $daysInMonth = [DateTime]::DaysInMonth($firstDay.Year, $firstDay.Month)
    $firstDayOfWeek = [int]$firstDay.DayOfWeek
    if ($firstDayOfWeek -eq 0) { $firstDayOfWeek = 7 }  # Sunday = 7, not 0
    $firstDayOfWeek--  # Convert to 0-based (Monday = 0)

    # Create row definitions
    $weeks = [Math]::Ceiling(($firstDayOfWeek + $daysInMonth) / 7)
    for ($i = 0; $i -lt $weeks; $i++) {
        $calendarGrid.RowDefinitions.Add([Windows.Controls.RowDefinition]@{ Height = '*' })
    }

    # Add day buttons
    $dayNum = 1
    $row = 0
    $col = $firstDayOfWeek

    while ($dayNum -le $daysInMonth) {
        $currentDate = $firstDay.AddDays($dayNum - 1)
        $dayNumCopy = $dayNum

        $button = New-Object Windows.Controls.Button
        $button.Margin = '2'
        $button.Padding = '8'
        $button.Tag = $currentDate  # Store date in Tag for event handler access
        $button.Background = if ($currentDate.Date -eq $script:SelectedDate.Date) { '#0078d4' } else { '#F3E5F5' }
        $button.BorderBrush = '#7B1FA2'
        $button.BorderThickness = '3'
        $button.Foreground = if ($currentDate.Date -eq $script:SelectedDate.Date) { 'White' } else { '#2C2C2C' }
        $button.Cursor = 'Hand'
        $button.HorizontalContentAlignment = 'Center'
        $button.VerticalContentAlignment = 'Top'

        # Get reservations for this day
        $dayReservations = @($script:AllReservations | Where-Object { 
            $_.ReservationDate -eq $currentDate.ToString('yyyy-MM-dd') -and
            $_.MachineName -eq $cmbMachine.SelectedItem -and
            $_.Status -eq 'Active'
        } | Sort-Object StartTime)

        # Build button content with day number and display names
        $contentPanel = New-Object Windows.Controls.StackPanel
        $contentPanel.Orientation = 'Vertical'
        $contentPanel.Margin = '2'

        # Day number - bold and larger
        $dayTextBlock = New-Object Windows.Controls.TextBlock
        $dayTextBlock.Text = $dayNum.ToString()
        $dayTextBlock.FontSize = 18
        $dayTextBlock.FontWeight = 'Bold'
        $dayTextBlock.Foreground = if ($currentDate.Date -eq $script:SelectedDate.Date) { 'White' } else { '#1F1F1F' }
        $dayTextBlock.HorizontalAlignment = 'Center'
        $dayTextBlock.Margin = '0,0,0,4'
        $contentPanel.Children.Add($dayTextBlock) | Out-Null

        # Display names for reservations
        foreach ($res in $dayReservations) {
            $nameTextBlock = New-Object Windows.Controls.TextBlock
            $nameTextBlock.Text = $res.UserDisplayName
            $nameTextBlock.FontSize = 10
            $nameTextBlock.Foreground = if ($currentDate.Date -eq $script:SelectedDate.Date) { 'White' } else { '#4B4B4B' }
            $nameTextBlock.TextWrapping = 'Wrap'
            $nameTextBlock.TextAlignment = 'Center'
            $nameTextBlock.Margin = '1,0,1,2'
            $contentPanel.Children.Add($nameTextBlock) | Out-Null
        }

        $button.Content = $contentPanel

        # Build tooltip showing reservation details
        $tooltipText = $currentDate.ToString('ddd, MMM d, yyyy')
        if ($dayReservations.Count -gt 0) {
            $tooltipText += "`nMachine: $($cmbMachine.SelectedItem)`n`nReservations:"
            foreach ($res in $dayReservations) {
                $tooltipText += "`n$($res.StartTime) - $($res.UserDisplayName)"
            }
        }
        
        $button.ToolTip = $tooltipText

        $button.Add_Click({
            $script:SelectedDate = $this.Tag
            $txtSelectedDate.Text = $this.Tag.ToString('ddd, MMM d, yyyy')
            Update-TimeSlots
            Render-MonthCalendar
        })

        [Windows.Controls.Grid]::SetRow($button, $row)
        [Windows.Controls.Grid]::SetColumn($button, $col)
        $calendarGrid.Children.Add($button) | Out-Null

        $dayNum++
        $col++
        if ($col -eq 7) {
            $col = 0
            $row++
        }
    }

    $txtMonthYear.Text = $script:CurrentMonth.ToString('MMMM yyyy')
}

<#
.SYNOPSIS
    Updates available time slots based on selected date/machine.
#>
function Update-TimeSlots {
    $cmbStartTime.Items.Clear()
    $cmbDuration.SelectedIndex = 0

    $slots = Get-AvailableTimeSlots -Date $script:SelectedDate -MachineName $cmbMachine.SelectedItem

    foreach ($slot in $slots) {
        $display = if ($slot.IsConflict) { "$($slot.StartTime) - CONFLICT" } else { $slot.StartTime }
        $item = New-Object Windows.Controls.ComboBoxItem
        $item.Content = $display
        $item.Tag = $slot
        $cmbStartTime.Items.Add($item) | Out-Null

        if (-not $slot.IsConflict) {
            if (-not $cmbStartTime.SelectedItem) {
                $cmbStartTime.SelectedItem = $item
            }
        }
    }
}

<#
.SYNOPSIS
    Renders the day view with hourly timeline.
#>
function Render-DayView {
    $dayViewContent.Children.Clear()

    $header = New-Object Windows.Controls.TextBlock
    $header.Text = "Reservations for $($script:SelectedDate.ToString('ddd, MMMM d, yyyy')) - $($cmbMachine.SelectedItem)"
    $header.FontWeight = 'Bold'
    $header.FontSize = 14
    $header.Margin = '0,0,0,12'
    $dayViewContent.Children.Add($header) | Out-Null

    $reservations = Get-DayReservations -Date $script:SelectedDate -MachineName $cmbMachine.SelectedItem

    if (@($reservations).Count -eq 0) {
        $noRes = New-Object Windows.Controls.TextBlock
        $noRes.Text = "No active reservations for this date"
        $noRes.Foreground = '#606e7a'
        $dayViewContent.Children.Add($noRes) | Out-Null
    }
    else {
        foreach ($res in $reservations) {
            $border = New-Object Windows.Controls.Border
            $border.Background = '#107c10'
            $border.CornerRadius = '4'
            $border.Padding = '8'
            $border.Margin = '0,0,0,8'

            $text = New-Object Windows.Controls.TextBlock
            $text.Foreground = 'White'
            $text.TextWrapping = 'Wrap'
            $text.Text = "$($res.StartTime) - $($res.EndTime): $($res.UserDisplayName)"
            if ($res.Comments) { $text.Text += " `n$($res.Comments)" }

            $border.Child = $text
            $dayViewContent.Children.Add($border) | Out-Null
        }
    }
}

<#
.SYNOPSIS
    Renders the list view.
#>
function Render-ListView {
    $filteredRes = @($script:AllReservations | Where-Object {
        $_.MachineName -eq $cmbMachine.SelectedItem -and
        $_.Status -eq 'Active'
    } | Sort-Object ReservationDate, StartTime)

    $gridReservations.ItemsSource = $filteredRes
    $txtListViewHeader.Text = "Showing $($filteredRes.Count) active reservations for $($cmbMachine.SelectedItem)"
}

<#
.SYNOPSIS
    Refreshes all data.
#>
function Refresh-Data {
    $script:AllReservations = Load-AllReservations
    Render-MonthCalendar
    Update-TimeSlots
    Render-DayView
    Render-ListView
}

# Event handlers
$btnRefresh.Add_Click({
    try {
        if (Get-Command Refresh-Data -ErrorAction SilentlyContinue) {
            Refresh-Data
        }
    }
    catch {
        [System.Windows.MessageBox]::Show("Error refreshing data: $_", 'Refresh Error', 'OK', 'Warning') | Out-Null
    }
})

$btnClose.Add_Click({
    if (Test-Path variable:\script:AutoRefreshTimer) {
        if ($script:AutoRefreshTimer) {
            $script:AutoRefreshTimer.Stop()
            # Note: DispatcherTimer doesn't have Dispose(), just Stop() is enough
        }
    }
    $window.Close()
})

$btnPrevMonth.Add_Click({
    $script:CurrentMonth = $script:CurrentMonth.AddMonths(-1)
    Render-MonthCalendar
})

$btnNextMonth.Add_Click({
    $script:CurrentMonth = $script:CurrentMonth.AddMonths(1)
    Render-MonthCalendar
})

$rdoMonth.Add_Checked({
    if ($script:monthView) {
        $script:monthView.Visibility = 'Visible'
        $script:dayView.Visibility = 'Collapsed'
        $script:listView.Visibility = 'Collapsed'
    }
})

$rdoDay.Add_Checked({
    if ($script:dayView) {
        $script:monthView.Visibility = 'Collapsed'
        $script:dayView.Visibility = 'Visible'
        $script:listView.Visibility = 'Collapsed'
        Render-DayView
    }
})

$rdoList.Add_Checked({
    if ($script:listView) {
        $script:monthView.Visibility = 'Collapsed'
        $script:dayView.Visibility = 'Collapsed'
        $script:listView.Visibility = 'Visible'
        Render-ListView
    }
})

$cmbMachine.Add_SelectionChanged({
    if ($cmbMachine.SelectedItem) {
        Update-TimeSlots
        Render-MonthCalendar
        Render-DayView
        Render-ListView
    }
})

$cmbStartTime.Add_SelectionChanged({
    # Check for conflicts and update warning
    if ($cmbStartTime.SelectedItem) {
        $slot = $cmbStartTime.SelectedItem.Tag
        if ($slot.IsConflict) {
            $txtWarning.Text = "⚠ Conflict detected! This time slot overlaps with an existing reservation. Admin override required."
            $txtWarning.Visibility = 'Visible'
            $chkOverride.IsEnabled = $true
        }
        else {
            $txtWarning.Text = ""
            $txtWarning.Visibility = 'Collapsed'
            $chkOverride.IsEnabled = $false
            $chkOverride.IsChecked = $false
        }
    }
})

$btnCreateReservation.Add_Click({
    if (-not $cmbMachine.SelectedItem -or -not $cmbStartTime.SelectedItem -or -not $cmbDuration.SelectedItem) {
        [System.Windows.MessageBox]::Show('Please select machine, start time, and duration', 'Missing Information', 'OK', 'Warning') | Out-Null
        return
    }

    $slot = $cmbStartTime.SelectedItem.Tag
    $durationMinutes = switch ($cmbDuration.SelectedItem.Content) {
        '30 minutes' { 30 }
        '1 hour' { 60 }
        '1.5 hours' { 90 }
        '2 hours' { 120 }
    }

    $endTime = ([timespan]::Parse($slot.StartTime)).Add([timespan]::FromMinutes($durationMinutes))

    try {
        # Get current user info
        $userDb = Get-UserDatabase -UsersPath $UsersPath
        $userRecord = $userDb | Where-Object { $_.SEID -eq $script:CurrentUser } | Select-Object -First 1
        
        if (-not $userRecord) {
            [System.Windows.MessageBox]::Show("User $script:CurrentUser not found in database", 'Error', 'OK', 'Error') | Out-Null
            return
        }

        # Check if admin override is needed and permitted
        $overrideWarning = $false
        if ($slot.IsConflict) {
            if (-not $chkOverride.IsChecked) {
                [System.Windows.MessageBox]::Show('Conflict detected. Check admin override to proceed.', 'Conflict', 'OK', 'Warning') | Out-Null
                return
            }
            if (-not $userRecord.IsAdmin) {
                [System.Windows.MessageBox]::Show('Only admins can override conflicts', 'Permission Denied', 'OK', 'Error') | Out-Null
                return
            }
            $overrideWarning = $true
        }

        # Create the reservation
        $result = New-Reservation `
            -MachineName $cmbMachine.SelectedItem `
            -UserId $script:CurrentUser `
            -UserDisplayName "$($userRecord.FirstName) $($userRecord.LastName)" `
            -UserEmail $userRecord.IRSEmail `
            -ReservationDate $script:SelectedDate.ToString('yyyy-MM-dd') `
            -StartTime $slot.StartTime `
            -EndTime $endTime.ToString('hh\:mm') `
            -Comments $txtComments.Text `
            -OverrideWarning $overrideWarning `
            -ReservationPath $ReservationPath `
            -SettingsPath $SettingsPath `
            -UsersPath $UsersPath

        [System.Windows.MessageBox]::Show("Reservation created successfully!`n`nID: $($result.ReservationId)", 'Success', 'OK', 'Information') | Out-Null

        # Clear form
        $txtComments.Clear()
        $chkOverride.IsChecked = $false

        # Refresh calendar
        try {
            if (Get-Command Refresh-Data -ErrorAction SilentlyContinue) {
                Refresh-Data
            }
        }
        catch {
            # Silently ignore refresh errors after reservation creation
        }
    }
    catch {
        [System.Windows.MessageBox]::Show("Error creating reservation: $_", 'Error', 'OK', 'Error') | Out-Null
    }
})

# Initialize
$script:TrackedMachines = Get-TrackedMachines
foreach ($machine in $script:TrackedMachines) {
    $cmbMachine.Items.Add($machine) | Out-Null
}

$txtSelectedDate.Text = $script:SelectedDate.ToString('ddd, MMM d, yyyy')

# Load data and render BEFORE setting SelectedIndex to avoid event handler errors
$script:AllReservations = Load-AllReservations
Render-MonthCalendar

# Now set SelectedIndex which triggers events
if ($SelectedMachine -and $cmbMachine.Items.Contains($SelectedMachine)) {
    $cmbMachine.SelectedItem = $SelectedMachine
}
elseif (@($cmbMachine.Items).Count -gt 0) {
    $cmbMachine.SelectedIndex = 0
}

$cmbDuration.SelectedIndex = 0
Update-TimeSlots

# Auto-refresh timer
$script:AutoRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:AutoRefreshTimer.Interval = [timespan]::FromSeconds($script:RefreshIntervalSeconds)
$script:AutoRefreshTimer.Add_Tick({
    try {
        if (Get-Command Refresh-Data -ErrorAction SilentlyContinue) {
            Refresh-Data
        }
    }
    catch {
        # Silently ignore errors during timer tick (e.g., during modal dialog)
    }
})
$script:AutoRefreshTimer.Start()

# Show dialog
$window.ShowDialog() | Out-Null
