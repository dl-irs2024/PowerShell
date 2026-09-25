# TrackSessions.Reservations.SettingsDialog.ps1
# Phase 6: Settings Admin Panel
# WPF dialog for managing reservation system configuration

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SettingsPath,
    [Parameter(Mandatory = $true)]
    [string]$UsersPath
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Load current settings
$script:Settings = $null
$script:CurrentUser = $null
$script:IsAdmin = $false

function Load-Settings {
    try {
        $json = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
        return $json
    }
    catch {
        [System.Windows.MessageBox]::Show("Error loading settings: $_", 'Error', 'OK', 'Error') | Out-Null
        return $null
    }
}

function Load-CurrentUser {
    try {
        $usersJson = Get-Content -LiteralPath $UsersPath -Raw | ConvertFrom-Json
        $user = $usersJson | Where-Object { $_.SEID -eq $env:USERNAME }
        return $user
    }
    catch {
        return $null
    }
}

function Save-Settings {
    param([object]$SettingsObj)
    
    try {
        $json = $SettingsObj | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath $SettingsPath -Value $json -Encoding UTF8 -Force
        return $true
    }
    catch {
        [System.Windows.MessageBox]::Show("Error saving settings: $_", 'Error', 'OK', 'Error') | Out-Null
        return $false
    }
}

function Test-AdminAccess {
    $user = Load-CurrentUser
    if (-not $user) {
        [System.Windows.MessageBox]::Show("User $env:USERNAME not found in database", 'Access Denied', 'OK', 'Warning') | Out-Null
        return $false
    }
    if (-not $user.IsAdmin) {
        [System.Windows.MessageBox]::Show("This feature requires admin access. Contact your administrator.", 'Access Denied', 'OK', 'Warning') | Out-Null
        return $false
    }
    return $true
}

function Test-PathAccessibility {
    param([string]$Path)
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @{ Valid = $false; Message = 'Path is empty' }
    }
    
    try {
        if (Test-Path -LiteralPath $Path) {
            $item = Get-Item -LiteralPath $Path -Force
            if ($item.PSIsContainer) {
                # Try to write a temp file
                $tempFile = Join-Path $Path '.test-write'
                'test' | Set-Content -LiteralPath $tempFile -Force
                Remove-Item -LiteralPath $tempFile -Force
                return @{ Valid = $true; Message = 'Path is accessible and writable' }
            }
            else {
                return @{ Valid = $false; Message = 'Path exists but is not a directory' }
            }
        }
        else {
            return @{ Valid = $false; Message = 'Path does not exist' }
        }
    }
    catch {
        return @{ Valid = $false; Message = "Error: $_" }
    }
}

# XAML Dialog
[xml]$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Reservation System Settings'
        Width='600'
        Height='700'
        MinWidth='500'
        MinHeight='600'
        WindowStartupLocation='CenterScreen'
        Background='#F5F5F5'>
    <DockPanel Margin='12'>
        <!-- Header -->
        <TextBlock DockPanel.Dock='Top' Text='Reservation System Configuration' FontSize='16' FontWeight='Bold' Margin='0,0,0,16' Foreground='#0078d4'/>

        <!-- Tabs (implemented as RadioButtons) -->
        <StackPanel DockPanel.Dock='Top' Orientation='Horizontal' Margin='0,0,0,12'>
            <RadioButton Name='TabBusiness' Content='Business Hours' IsChecked='True' Margin='0,0,16,0' VerticalAlignment='Center'/>
            <RadioButton Name='TabPath' Content='Reservation Path' Margin='0,0,16,0' VerticalAlignment='Center'/>
            <RadioButton Name='TabAdmins' Content='Administrators' Margin='0,0,16,0' VerticalAlignment='Center'/>
            <RadioButton Name='TabEmail' Content='Email Settings' Margin='0,0,16,0' VerticalAlignment='Center'/>
            <RadioButton Name='TabOutlook' Content='Outlook' VerticalAlignment='Center'/>
        </StackPanel>

        <!-- Content area -->
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height='*'/>
                <RowDefinition Height='Auto'/>
            </Grid.RowDefinitions>

            <!-- Business Hours Tab -->
            <Grid Grid.Row='0' Name='BusinessHoursPanel'>
                <Grid.RowDefinitions>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='*'/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row='0' Text='Business Hours Configuration' FontWeight='Bold' Margin='0,0,0,12'/>

                <Grid Grid.Row='1' Margin='0,0,0,12'>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width='120'/>
                        <ColumnDefinition Width='*'/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column='0' Text='Start Time:' VerticalAlignment='Center'/>
                    <TextBox Grid.Column='1' Name='TxtBusinessStart' Placeholder='09:00' Padding='8'/>
                </Grid>

                <Grid Grid.Row='2' Margin='0,0,0,12'>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width='120'/>
                        <ColumnDefinition Width='*'/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column='0' Text='End Time:' VerticalAlignment='Center'/>
                    <TextBox Grid.Column='1' Name='TxtBusinessEnd' Placeholder='18:00' Padding='8'/>
                </Grid>

                <Grid Grid.Row='3'>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width='120'/>
                        <ColumnDefinition Width='*'/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column='0' Text='Time Slot (min):' VerticalAlignment='Center'/>
                    <Grid Grid.Column='1'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='80'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <ComboBox Grid.Column='0' Name='CmbTimeSlot'>
                            <ComboBoxItem>15</ComboBoxItem>
                            <ComboBoxItem>30</ComboBoxItem>
                            <ComboBoxItem>45</ComboBoxItem>
                            <ComboBoxItem>60</ComboBoxItem>
                        </ComboBox>
                    </Grid>
                </Grid>
            </Grid>

            <!-- Reservation Path Tab -->
            <Grid Grid.Row='0' Name='ReservationPathPanel' Visibility='Collapsed'>
                <Grid.RowDefinitions>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='*'/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row='0' Text='Reservation Path Configuration' FontWeight='Bold' Margin='0,0,0,12'/>

                <TextBlock Grid.Row='1' Text='Storage Path:' FontWeight='Bold' Margin='0,0,0,6'/>
                <TextBox Grid.Row='2' Name='TxtReservationPath' Padding='8' Margin='0,0,0,8'/>
                <TextBlock Grid.Row='3' Name='TxtPathStatus' Margin='0,0,0,0' Foreground='#666' FontSize='12'/>
            </Grid>

            <!-- Administrators Tab -->
            <Grid Grid.Row='0' Name='AdminsPanel' Visibility='Collapsed'>
                <Grid.RowDefinitions>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='*'/>
                    <RowDefinition Height='Auto'/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row='0' Text='Administrator Users' FontWeight='Bold' Margin='0,0,0,12'/>

                <Grid Grid.Row='1' Margin='0,0,0,12'>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width='*'/>
                        <ColumnDefinition Width='Auto'/>
                    </Grid.ColumnDefinitions>
                    <ComboBox Grid.Column='0' Name='CmbUsers' Margin='0,0,8,0'/>
                    <Button Grid.Column='1' Name='BtnAddAdmin' Content='Add Admin' Width='100' Height='28'/>
                </Grid>

                <ListBox Grid.Row='2' Name='ListAdmins'>
                    <ListBox.ItemTemplate>
                        <DataTemplate>
                            <Grid Width='{Binding RelativeSource={RelativeSource AncestorType=ListBox}, Path=ActualWidth}'>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width='*'/>
                                    <ColumnDefinition Width='80'/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Grid.Column='0' Text='{Binding}' VerticalAlignment='Center'/>
                                <Button Grid.Column='1' Content='Remove' Height='24' Padding='4' Click='RemoveAdminClick'/>
                            </Grid>
                        </DataTemplate>
                    </ListBox.ItemTemplate>
                </ListBox>
            </Grid>

            <!-- Email Distribution List Tab -->
            <Grid Grid.Row='0' Name='EmailPanel' Visibility='Collapsed'>
                <Grid.RowDefinitions>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='*'/>
                    <RowDefinition Height='Auto'/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row='0' Text='Email Notification Recipients' FontWeight='Bold' Margin='0,0,0,12'/>

                <Grid Grid.Row='1' Margin='0,0,0,12'>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width='*'/>
                        <ColumnDefinition Width='Auto'/>
                    </Grid.ColumnDefinitions>
                    <TextBox Grid.Column='0' Name='TxtEmail' Placeholder='email@example.com' Padding='8' Margin='0,0,8,0'/>
                    <Button Grid.Column='1' Name='BtnAddEmail' Content='Add Email' Width='100' Height='28'/>
                </Grid>

                <ListBox Grid.Row='3' Name='ListEmails'>
                    <ListBox.ItemTemplate>
                        <DataTemplate>
                            <Grid Width='{Binding RelativeSource={RelativeSource AncestorType=ListBox}, Path=ActualWidth}'>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width='*'/>
                                    <ColumnDefinition Width='80'/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Grid.Column='0' Text='{Binding}' VerticalAlignment='Center'/>
                                <Button Grid.Column='1' Content='Remove' Height='24' Padding='4' Click='RemoveEmailClick'/>
                            </Grid>
                        </DataTemplate>
                    </ListBox.ItemTemplate>
                </ListBox>
            </Grid>

            <!-- Outlook Tab -->
            <Grid Grid.Row='0' Name='OutlookPanel' Visibility='Collapsed'>
                <Grid.RowDefinitions>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='Auto'/>
                    <RowDefinition Height='*'/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row='0' Text='Outlook Integration Settings' FontWeight='Bold' Margin='0,0,0,12'/>

                <CheckBox Grid.Row='1' Name='ChkOutlookEnabled' Content='Enable Outlook Integration' Margin='0,0,0,12'/>
                <CheckBox Grid.Row='2' Name='ChkCreateEvents' Content='Create Calendar Events' Margin='0,0,0,12'/>
                <CheckBox Grid.Row='3' Name='ChkSendEmails' Content='Send Email Notifications' Margin='0,0,0,0'/>
            </Grid>

            <!-- Buttons -->
            <StackPanel Grid.Row='1' Orientation='Horizontal' HorizontalAlignment='Right' Gap='8' Margin='0,16,0,0'>
                <Button Name='BtnApply' Content='Apply' Width='100' Height='32' Background='#107c10' Foreground='White' FontWeight='Bold'/>
                <Button Name='BtnCancel' Content='Cancel' Width='100' Height='32'/>
            </StackPanel>
        </Grid>
    </DockPanel>
</Window>
"@

# Create window
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

# Get controls
$tabBusiness = $window.FindName('TabBusiness')
$tabPath = $window.FindName('TabPath')
$tabAdmins = $window.FindName('TabAdmins')
$tabEmail = $window.FindName('TabEmail')
$tabOutlook = $window.FindName('TabOutlook')

$businessPanel = $window.FindName('BusinessHoursPanel')
$pathPanel = $window.FindName('ReservationPathPanel')
$adminsPanel = $window.FindName('AdminsPanel')
$emailPanel = $window.FindName('EmailPanel')
$outlookPanel = $window.FindName('OutlookPanel')

$txtBusinessStart = $window.FindName('TxtBusinessStart')
$txtBusinessEnd = $window.FindName('TxtBusinessEnd')
$cmbTimeSlot = $window.FindName('CmbTimeSlot')

$txtReservationPath = $window.FindName('TxtReservationPath')
$txtPathStatus = $window.FindName('TxtPathStatus')

$cmbUsers = $window.FindName('CmbUsers')
$btnAddAdmin = $window.FindName('BtnAddAdmin')
$listAdmins = $window.FindName('ListAdmins')

$txtEmail = $window.FindName('TxtEmail')
$btnAddEmail = $window.FindName('BtnAddEmail')
$listEmails = $window.FindName('ListEmails')

$chkOutlookEnabled = $window.FindName('ChkOutlookEnabled')
$chkCreateEvents = $window.FindName('ChkCreateEvents')
$chkSendEmails = $window.FindName('ChkSendEmails')

$btnApply = $window.FindName('BtnApply')
$btnCancel = $window.FindName('BtnCancel')

# Check admin access
if (-not (Test-AdminAccess)) {
    $window.Close()
    return
}

# Load settings
$script:Settings = Load-Settings
if (-not $script:Settings) {
    $window.Close()
    return
}

# Populate UI from settings
function Load-UIFromSettings {
    if ($script:Settings.Reservations) {
        $txtBusinessStart.Text = $script:Settings.Reservations.BusinessHoursStart
        $txtBusinessEnd.Text = $script:Settings.Reservations.BusinessHoursEnd
        $cmbTimeSlot.SelectedItem = $script:Settings.Reservations.TimeSlotGranularity
    }

    if ($script:Settings.Tracking.ReservationPath) {
        $txtReservationPath.Text = $script:Settings.Tracking.ReservationPath
    }

    if ($script:Settings.Tracking.ReservationAdmins) {
        $listAdmins.ItemsSource = @($script:Settings.Tracking.ReservationAdmins)
    }

    if ($script:Settings.Outlook.EmailDistributionList) {
        $listEmails.ItemsSource = @($script:Settings.Outlook.EmailDistributionList)
    }

    $chkOutlookEnabled.IsChecked = $script:Settings.Outlook.Enabled
    $chkCreateEvents.IsChecked = $script:Settings.Outlook.CreateCalendarEvents
    $chkSendEmails.IsChecked = $script:Settings.Outlook.SendEmailNotifications

    # Load users for dropdown
    try {
        $usersJson = Get-Content -LiteralPath $UsersPath -Raw | ConvertFrom-Json
        $userList = @($usersJson | Select-Object -ExpandProperty SEID)
        $cmbUsers.ItemsSource = $userList
    }
    catch {
        Write-Warning "Could not load user list: $_"
    }
}

# Tab switching
$tabBusiness.Add_Checked({ 
    $businessPanel.Visibility = 'Visible'
    $pathPanel.Visibility = 'Collapsed'
    $adminsPanel.Visibility = 'Collapsed'
    $emailPanel.Visibility = 'Collapsed'
    $outlookPanel.Visibility = 'Collapsed'
})

$tabPath.Add_Checked({ 
    $businessPanel.Visibility = 'Collapsed'
    $pathPanel.Visibility = 'Visible'
    $adminsPanel.Visibility = 'Collapsed'
    $emailPanel.Visibility = 'Collapsed'
    $outlookPanel.Visibility = 'Collapsed'
})

$tabAdmins.Add_Checked({ 
    $businessPanel.Visibility = 'Collapsed'
    $pathPanel.Visibility = 'Collapsed'
    $adminsPanel.Visibility = 'Visible'
    $emailPanel.Visibility = 'Collapsed'
    $outlookPanel.Visibility = 'Collapsed'
})

$tabEmail.Add_Checked({ 
    $businessPanel.Visibility = 'Collapsed'
    $pathPanel.Visibility = 'Collapsed'
    $adminsPanel.Visibility = 'Collapsed'
    $emailPanel.Visibility = 'Visible'
    $outlookPanel.Visibility = 'Collapsed'
})

$tabOutlook.Add_Checked({ 
    $businessPanel.Visibility = 'Collapsed'
    $pathPanel.Visibility = 'Collapsed'
    $adminsPanel.Visibility = 'Collapsed'
    $emailPanel.Visibility = 'Collapsed'
    $outlookPanel.Visibility = 'Visible'
})

# Add admin button
$btnAddAdmin.Add_Click({
    if ($cmbUsers.SelectedItem) {
        $admin = $cmbUsers.SelectedItem
        if ($admin -notin $listAdmins.ItemsSource) {
            $admins = @($listAdmins.ItemsSource)
            $admins += $admin
            $listAdmins.ItemsSource = $admins
        }
        else {
            [System.Windows.MessageBox]::Show("$admin is already an admin", 'Duplicate', 'OK', 'Warning') | Out-Null
        }
    }
})

# Add email button
$btnAddEmail.Add_Click({
    $email = $txtEmail.Text.Trim()
    if ($email -and $email -match '^[^@]+@[^@]+$') {
        if ($email -notin $listEmails.ItemsSource) {
            $emails = @($listEmails.ItemsSource)
            $emails += $email
            $listEmails.ItemsSource = $emails
            $txtEmail.Clear()
        }
        else {
            [System.Windows.MessageBox]::Show("$email is already in the list", 'Duplicate', 'OK', 'Warning') | Out-Null
        }
    }
    else {
        [System.Windows.MessageBox]::Show("Please enter a valid email address", 'Invalid Email', 'OK', 'Warning') | Out-Null
    }
})

# Path validation
$txtReservationPath.Add_LostFocus({
    $result = Test-PathAccessibility -Path $txtReservationPath.Text
    if ($result.Valid) {
        $txtPathStatus.Foreground = '#107c10'
        $txtPathStatus.Text = "✓ $($result.Message)"
    }
    else {
        $txtPathStatus.Foreground = '#da3b01'
        $txtPathStatus.Text = "✗ $($result.Message)"
    }
})

# Apply button
$btnApply.Add_Click({
    # Validate business hours
    try {
        $start = [timespan]::Parse($txtBusinessStart.Text)
        $end = [timespan]::Parse($txtBusinessEnd.Text)
        if ($start -ge $end) {
            [System.Windows.MessageBox]::Show('Start time must be before end time', 'Invalid Time', 'OK', 'Error') | Out-Null
            return
        }
    }
    catch {
        [System.Windows.MessageBox]::Show('Invalid time format. Use HH:mm (e.g., 09:00)', 'Invalid Time', 'OK', 'Error') | Out-Null
        return
    }

    # Validate reservation path
    if ($txtReservationPath.Text) {
        $result = Test-PathAccessibility -Path $txtReservationPath.Text
        if (-not $result.Valid) {
            [System.Windows.MessageBox]::Show("Reservation path is not accessible: $($result.Message)", 'Invalid Path', 'OK', 'Error') | Out-Null
            return
        }
    }

    # Update settings
    $script:Settings.Reservations.BusinessHoursStart = $txtBusinessStart.Text
    $script:Settings.Reservations.BusinessHoursEnd = $txtBusinessEnd.Text
    $script:Settings.Reservations.TimeSlotGranularity = [int]$cmbTimeSlot.SelectedItem

    if ($txtReservationPath.Text) {
        $script:Settings.Tracking.ReservationPath = $txtReservationPath.Text
    }

    $script:Settings.Tracking.ReservationAdmins = @($listAdmins.ItemsSource)
    $script:Settings.Outlook.EmailDistributionList = @($listEmails.ItemsSource)

    $script:Settings.Outlook.Enabled = [bool]$chkOutlookEnabled.IsChecked
    $script:Settings.Outlook.CreateCalendarEvents = [bool]$chkCreateEvents.IsChecked
    $script:Settings.Outlook.SendEmailNotifications = [bool]$chkSendEmails.IsChecked

    # Save settings
    if (Save-Settings -SettingsObj $script:Settings) {
        [System.Windows.MessageBox]::Show('Settings saved successfully!', 'Success', 'OK', 'Information') | Out-Null
        $window.Close()
    }
})

# Cancel button
$btnCancel.Add_Click({ $window.Close() })

# Initialize
Load-UIFromSettings

# Show dialog
$window.ShowDialog() | Out-Null
