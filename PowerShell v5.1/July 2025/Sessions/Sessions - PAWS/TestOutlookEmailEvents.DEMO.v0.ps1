#requires -version 5.1

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Path to recent contacts cache
$recentContactsPath = "$PSScriptRoot\RecentContacts.json"

function Get-RecentContacts {
    if (Test-Path $recentContactsPath) {
        try {
            $contacts = Get-Content $recentContactsPath -Raw | ConvertFrom-Json
            return @($contacts)
        }
        catch { return @() }
    }
    return @()
}

function Add-RecentContact {
    param([string]$Email)
    if ([string]::IsNullOrWhiteSpace($Email)) { return }
    $contacts = @(Get-RecentContacts)
    $contacts = @($contacts | Where-Object { $_ -ne $Email })
    $contacts = @($Email) + $contacts
    $contacts = @($contacts | Select-Object -First 20)
    if ($contacts.Count -eq 1) {
        @($contacts[0]) | ConvertTo-Json | Out-File $recentContactsPath -Encoding UTF8 -Force
    } else {
        $contacts | ConvertTo-Json | Out-File $recentContactsPath -Encoding UTF8 -Force
    }
}

# Create main window
$window = New-Object System.Windows.Window
$window.Title = "Outlook Email & Events Creator"
$window.Width = 900
$window.Height = 700
$window.WindowStartupLocation = "CenterScreen"
$window.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::WhiteSmoke)

# Create main grid with 2 rows (content and status bar)
$mainGrid = New-Object System.Windows.Controls.Grid
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = 30}))

# Create TabControl
$tabControl = New-Object System.Windows.Controls.TabControl
$tabControl.Margin = New-Object System.Windows.Thickness(10)
[System.Windows.Controls.Grid]::SetRow($tabControl, 0)
$mainGrid.Children.Add($tabControl) | Out-Null

# ===== EMAIL TAB =====
$emailTab = New-Object System.Windows.Controls.TabItem
$emailTab.Header = "Email"

$emailScroll = New-Object System.Windows.Controls.ScrollViewer
$emailScroll.VerticalScrollBarVisibility = "Auto"

$emailPanel = New-Object System.Windows.Controls.StackPanel
$emailPanel.Margin = New-Object System.Windows.Thickness(20)
$emailPanel.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)

# Email Title
$emailTitle = New-Object System.Windows.Controls.TextBlock
$emailTitle.Text = "Email Creator"
$emailTitle.FontSize = 18
$emailTitle.FontWeight = "Bold"
$emailTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
$emailPanel.Children.Add($emailTitle) | Out-Null

# To field - COMBOBOX with autocomplete
$toLabel = New-Object System.Windows.Controls.TextBlock
$toLabel.Text = "To:"
$toLabel.FontWeight = "Bold"
$toLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$emailPanel.Children.Add($toLabel) | Out-Null

$emailToField = New-Object System.Windows.Controls.ComboBox
$emailToField.Name = "EmailTo"
$emailToField.Height = 35
$emailToField.Padding = New-Object System.Windows.Thickness(8)
$emailToField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$emailToField.IsEditable = $true
$emailToField.ToolTip = "Recent contacts or type email address"

# Load recent contacts
$recentContacts = Get-RecentContacts
foreach ($contact in $recentContacts) {
    $emailToField.Items.Add($contact) | Out-Null
}

# Add filtering on text change
$emailToField.Add_TextChanged({
    if ($emailToField.Text.Length -lt 1) {
        $emailToField.IsDropDownOpen = $false
        return
    }
    $text = $emailToField.Text
    $recentContacts = Get-RecentContacts
    $matches = @($recentContacts | Where-Object { $_ -like "$text*" })
    $emailToField.Items.Clear()
    foreach ($match in $matches) {
        $emailToField.Items.Add($match) | Out-Null
    }
    if ($matches.Count -gt 0) {
        $emailToField.IsDropDownOpen = $true
    }
})

$emailPanel.Children.Add($emailToField) | Out-Null

# CC field
$ccLabel = New-Object System.Windows.Controls.TextBlock
$ccLabel.Text = "CC:"
$ccLabel.FontWeight = "Bold"
$ccLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$emailPanel.Children.Add($ccLabel) | Out-Null

$emailCCField = New-Object System.Windows.Controls.TextBox
$emailCCField.Name = "EmailCC"
$emailCCField.Height = 35
$emailCCField.Padding = New-Object System.Windows.Thickness(8)
$emailCCField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$emailCCField.ToolTip = "CC recipients (comma-separated)"
$emailPanel.Children.Add($emailCCField) | Out-Null

# BCC field
$bccLabel = New-Object System.Windows.Controls.TextBlock
$bccLabel.Text = "BCC:"
$bccLabel.FontWeight = "Bold"
$bccLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$emailPanel.Children.Add($bccLabel) | Out-Null

$emailBCCField = New-Object System.Windows.Controls.TextBox
$emailBCCField.Name = "EmailBCC"
$emailBCCField.Height = 35
$emailBCCField.Padding = New-Object System.Windows.Thickness(8)
$emailBCCField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$emailBCCField.ToolTip = "BCC recipients (comma-separated)"
$emailPanel.Children.Add($emailBCCField) | Out-Null

# Subject field
$subjectLabel = New-Object System.Windows.Controls.TextBlock
$subjectLabel.Text = "Subject:"
$subjectLabel.FontWeight = "Bold"
$subjectLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$emailPanel.Children.Add($subjectLabel) | Out-Null

$emailSubjectField = New-Object System.Windows.Controls.TextBox
$emailSubjectField.Name = "EmailSubject"
$emailSubjectField.Height = 35
$emailSubjectField.Padding = New-Object System.Windows.Thickness(8)
$emailSubjectField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$emailPanel.Children.Add($emailSubjectField) | Out-Null

# Body field
$bodyLabel = New-Object System.Windows.Controls.TextBlock
$bodyLabel.Text = "Body:"
$bodyLabel.FontWeight = "Bold"
$bodyLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$emailPanel.Children.Add($bodyLabel) | Out-Null

$emailBodyField = New-Object System.Windows.Controls.TextBox
$emailBodyField.Name = "EmailBody"
$emailBodyField.Height = 150
$emailBodyField.Padding = New-Object System.Windows.Thickness(8)
$emailBodyField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$emailBodyField.TextWrapping = "Wrap"
$emailBodyField.VerticalScrollBarVisibility = "Auto"
$emailBodyField.AcceptsReturn = $true
$emailPanel.Children.Add($emailBodyField) | Out-Null

# Importance field
$importanceLabel = New-Object System.Windows.Controls.TextBlock
$importanceLabel.Text = "Importance:"
$importanceLabel.FontWeight = "Bold"
$importanceLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$emailPanel.Children.Add($importanceLabel) | Out-Null

$emailImportanceField = New-Object System.Windows.Controls.ComboBox
$emailImportanceField.Name = "EmailImportance"
$emailImportanceField.Height = 35
$emailImportanceField.Padding = New-Object System.Windows.Thickness(8)
$emailImportanceField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$emailImportanceField.ItemsSource = @("Normal", "High", "Low")
$emailImportanceField.SelectedIndex = 0
$emailPanel.Children.Add($emailImportanceField) | Out-Null

# Create Email Button
$createEmailBtn = New-Object System.Windows.Controls.Button
$createEmailBtn.Name = "CreateEmailBtn"
$createEmailBtn.Content = "Create Email in Outlook"
$createEmailBtn.Height = 40
$createEmailBtn.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#0078D4"))
$createEmailBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)
$createEmailBtn.FontWeight = "Bold"
$createEmailBtn.Margin = New-Object System.Windows.Thickness(0, 20, 0, 0)
$createEmailBtn.Cursor = "Hand"
$emailPanel.Children.Add($createEmailBtn) | Out-Null

$emailScroll.Content = $emailPanel
$emailTab.Content = $emailScroll
$tabControl.Items.Add($emailTab) | Out-Null

# ===== EVENTS TAB =====
$eventTab = New-Object System.Windows.Controls.TabItem
$eventTab.Header = "Events"

$eventScroll = New-Object System.Windows.Controls.ScrollViewer
$eventScroll.VerticalScrollBarVisibility = "Auto"

$eventPanel = New-Object System.Windows.Controls.StackPanel
$eventPanel.Margin = New-Object System.Windows.Thickness(20)
$eventPanel.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)

# Event Title
$eventTitle = New-Object System.Windows.Controls.TextBlock
$eventTitle.Text = "Event Creator"
$eventTitle.FontSize = 18
$eventTitle.FontWeight = "Bold"
$eventTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
$eventPanel.Children.Add($eventTitle) | Out-Null

# Event Subject
$eventSubjectLabel = New-Object System.Windows.Controls.TextBlock
$eventSubjectLabel.Text = "Subject:"
$eventSubjectLabel.FontWeight = "Bold"
$eventSubjectLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$eventPanel.Children.Add($eventSubjectLabel) | Out-Null

$eventSubjectField = New-Object System.Windows.Controls.TextBox
$eventSubjectField.Name = "EventSubject"
$eventSubjectField.Height = 35
$eventSubjectField.Padding = New-Object System.Windows.Thickness(8)
$eventSubjectField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$eventPanel.Children.Add($eventSubjectField) | Out-Null

# Start Date and Time
$startGrid = New-Object System.Windows.Controls.Grid
$startGrid.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$startGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "*"}))
$startGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "*"}))

$startDateLabel = New-Object System.Windows.Controls.TextBlock
$startDateLabel.Text = "Start Date:"
$startDateLabel.FontWeight = "Bold"
$startDateLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
[System.Windows.Controls.Grid]::SetColumn($startDateLabel, 0)
$startGrid.Children.Add($startDateLabel) | Out-Null

$eventStartDateField = New-Object System.Windows.Controls.DatePicker
$eventStartDateField.Name = "EventStartDate"
$eventStartDateField.Height = 35
$eventStartDateField.Padding = New-Object System.Windows.Thickness(8)
$eventStartDateField.Margin = New-Object System.Windows.Thickness(0, 30, 5, 0)
$eventStartDateField.SelectedDate = [DateTime]::Today
[System.Windows.Controls.Grid]::SetColumn($eventStartDateField, 0)
$startGrid.Children.Add($eventStartDateField) | Out-Null

$startTimeLabel = New-Object System.Windows.Controls.TextBlock
$startTimeLabel.Text = "Start Time:"
$startTimeLabel.FontWeight = "Bold"
$startTimeLabel.Margin = New-Object System.Windows.Thickness(5, 10, 0, 5)
[System.Windows.Controls.Grid]::SetColumn($startTimeLabel, 1)
$startGrid.Children.Add($startTimeLabel) | Out-Null

$eventStartTimeField = New-Object System.Windows.Controls.TextBox
$eventStartTimeField.Name = "EventStartTime"
$eventStartTimeField.Height = 35
$eventStartTimeField.Padding = New-Object System.Windows.Thickness(8)
$eventStartTimeField.Margin = New-Object System.Windows.Thickness(5, 30, 0, 0)
$eventStartTimeField.Text = "09:00 AM"
$eventStartTimeField.ToolTip = "HH:MM AM/PM"
[System.Windows.Controls.Grid]::SetColumn($eventStartTimeField, 1)
$startGrid.Children.Add($eventStartTimeField) | Out-Null

$eventPanel.Children.Add($startGrid) | Out-Null

# End Date and Time
$endGrid = New-Object System.Windows.Controls.Grid
$endGrid.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$endGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "*"}))
$endGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "*"}))

$endDateLabel = New-Object System.Windows.Controls.TextBlock
$endDateLabel.Text = "End Date:"
$endDateLabel.FontWeight = "Bold"
$endDateLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
[System.Windows.Controls.Grid]::SetColumn($endDateLabel, 0)
$endGrid.Children.Add($endDateLabel) | Out-Null

$eventEndDateField = New-Object System.Windows.Controls.DatePicker
$eventEndDateField.Name = "EventEndDate"
$eventEndDateField.Height = 35
$eventEndDateField.Padding = New-Object System.Windows.Thickness(8)
$eventEndDateField.Margin = New-Object System.Windows.Thickness(0, 30, 5, 0)
$eventEndDateField.SelectedDate = [DateTime]::Today.AddDays(1)
[System.Windows.Controls.Grid]::SetColumn($eventEndDateField, 0)
$endGrid.Children.Add($eventEndDateField) | Out-Null

$endTimeLabel = New-Object System.Windows.Controls.TextBlock
$endTimeLabel.Text = "End Time:"
$endTimeLabel.FontWeight = "Bold"
$endTimeLabel.Margin = New-Object System.Windows.Thickness(5, 10, 0, 5)
[System.Windows.Controls.Grid]::SetColumn($endTimeLabel, 1)
$endGrid.Children.Add($endTimeLabel) | Out-Null

$eventEndTimeField = New-Object System.Windows.Controls.TextBox
$eventEndTimeField.Name = "EventEndTime"
$eventEndTimeField.Height = 35
$eventEndTimeField.Padding = New-Object System.Windows.Thickness(8)
$eventEndTimeField.Margin = New-Object System.Windows.Thickness(5, 30, 0, 0)
$eventEndTimeField.Text = "10:00 AM"
$eventEndTimeField.ToolTip = "HH:MM AM/PM"
[System.Windows.Controls.Grid]::SetColumn($eventEndTimeField, 1)
$endGrid.Children.Add($eventEndTimeField) | Out-Null

$eventPanel.Children.Add($endGrid) | Out-Null

# Location field
$locationLabel = New-Object System.Windows.Controls.TextBlock
$locationLabel.Text = "Location:"
$locationLabel.FontWeight = "Bold"
$locationLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$eventPanel.Children.Add($locationLabel) | Out-Null

$eventLocationField = New-Object System.Windows.Controls.TextBox
$eventLocationField.Name = "EventLocation"
$eventLocationField.Height = 35
$eventLocationField.Padding = New-Object System.Windows.Thickness(8)
$eventLocationField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$eventPanel.Children.Add($eventLocationField) | Out-Null

# Attendees field
$attendeesLabel = New-Object System.Windows.Controls.TextBlock
$attendeesLabel.Text = "Attendees:"
$attendeesLabel.FontWeight = "Bold"
$attendeesLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$eventPanel.Children.Add($attendeesLabel) | Out-Null

$eventAttendeesField = New-Object System.Windows.Controls.TextBox
$eventAttendeesField.Name = "EventAttendees"
$eventAttendeesField.Height = 70
$eventAttendeesField.Padding = New-Object System.Windows.Thickness(8)
$eventAttendeesField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$eventAttendeesField.TextWrapping = "Wrap"
$eventAttendeesField.VerticalScrollBarVisibility = "Auto"
$eventAttendeesField.AcceptsReturn = $true
$eventAttendeesField.ToolTip = "Enter email addresses, one per line"
$eventPanel.Children.Add($eventAttendeesField) | Out-Null

# Description field
$descriptionLabel = New-Object System.Windows.Controls.TextBlock
$descriptionLabel.Text = "Description:"
$descriptionLabel.FontWeight = "Bold"
$descriptionLabel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
$eventPanel.Children.Add($descriptionLabel) | Out-Null

$eventDescriptionField = New-Object System.Windows.Controls.TextBox
$eventDescriptionField.Name = "EventDescription"
$eventDescriptionField.Height = 100
$eventDescriptionField.Padding = New-Object System.Windows.Thickness(8)
$eventDescriptionField.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
$eventDescriptionField.TextWrapping = "Wrap"
$eventDescriptionField.VerticalScrollBarVisibility = "Auto"
$eventDescriptionField.AcceptsReturn = $true
$eventPanel.Children.Add($eventDescriptionField) | Out-Null

# Reminder checkbox
$eventReminderCheckBox = New-Object System.Windows.Controls.CheckBox
$eventReminderCheckBox.Name = "EventReminder"
$eventReminderCheckBox.Content = "Remind 15 minutes before"
$eventReminderCheckBox.Margin = New-Object System.Windows.Thickness(0, 10, 0, 10)
$eventReminderCheckBox.IsChecked = $true
$eventPanel.Children.Add($eventReminderCheckBox) | Out-Null

# Create Event Button
$createEventBtn = New-Object System.Windows.Controls.Button
$createEventBtn.Name = "CreateEventBtn"
$createEventBtn.Content = "Create Event in Outlook"
$createEventBtn.Height = 40
$createEventBtn.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#107C10"))
$createEventBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)
$createEventBtn.FontWeight = "Bold"
$createEventBtn.Margin = New-Object System.Windows.Thickness(0, 20, 0, 0)
$createEventBtn.Cursor = "Hand"
$eventPanel.Children.Add($createEventBtn) | Out-Null

$eventScroll.Content = $eventPanel
$eventTab.Content = $eventScroll
$tabControl.Items.Add($eventTab) | Out-Null

# ===== STATUS BAR =====
$statusBarGrid = New-Object System.Windows.Controls.Grid
$statusBarGrid.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0"))
$statusBarGrid.Height = 30
[System.Windows.Controls.Grid]::SetRow($statusBarGrid, 1)
$mainGrid.Children.Add($statusBarGrid) | Out-Null

$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.Name = "StatusText"
$statusText.Text = "Status: Ready"
$statusText.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Black)
$statusText.Margin = New-Object System.Windows.Thickness(10, 5, 0, 0)
$statusText.VerticalAlignment = "Center"
$statusBarGrid.Children.Add($statusText) | Out-Null

$window.Content = $mainGrid

# ===== FUNCTIONS =====

# Function to check Outlook Installation
function Get-OutlookInfo {
    try {
        $outlookApp = New-Object -ComObject Outlook.Application -ErrorAction Stop
        $version = $outlookApp.Version
        $outlookApp = $null
        return @{
            Installed = $true
            Version = $version
            Message = "Outlook $version installed"
        }
    }
    catch {
        return @{
            Installed = $false
            Version = ""
            Message = "Outlook not installed"
        }
    }
}

# Function to create email in Outlook
function New-OutlookEmail {
    param(
        [string]$To,
        [string]$CC,
        [string]$BCC,
        [string]$Subject,
        [string]$Body,
        [string]$Importance
    )
    
    try {
        $outlookApp = New-Object -ComObject Outlook.Application
        $mailItem = $outlookApp.CreateItem(0)  # 0 = olMailItem
        
        $mailItem.To = $To
        $mailItem.CC = $CC
        $mailItem.BCC = $BCC
        $mailItem.Subject = $Subject
        $mailItem.Body = $Body
        
        # Set importance: 0=Low, 1=Normal, 2=High
        $importanceMap = @{
            "Low" = 0
            "Normal" = 1
            "High" = 2
        }
        $mailItem.Importance = $importanceMap[$Importance]
        
        $mailItem.Display($false)
        
        # Save to recent contacts
        Add-RecentContact -Email $To
        
        $statusText.Text = "Status: Email created successfully"
        [System.Windows.MessageBox]::Show("Email has been opened in Outlook and is ready to send.", "Success", "OK", "Information") | Out-Null
    }
    catch {
        $statusText.Text = "Status: Error creating email"
        [System.Windows.MessageBox]::Show("Error: $_", "Error", "OK", "Error") | Out-Null
    }
}

# Function to create event in Outlook
function New-OutlookEvent {
    param(
        [string]$Subject,
        [datetime]$StartDate,
        [string]$StartTime,
        [datetime]$EndDate,
        [string]$EndTime,
        [string]$Location,
        [string]$Attendees,
        [string]$Description,
        [bool]$Reminder
    )
    
    try {
        $outlookApp = New-Object -ComObject Outlook.Application
        $eventItem = $outlookApp.CreateItem(1)  # 1 = olAppointmentItem
        
        # Parse times
        $startDateTime = [DateTime]::Parse("$($StartDate.ToString('M/d/yyyy')) $StartTime")
        $endDateTime = [DateTime]::Parse("$($EndDate.ToString('M/d/yyyy')) $EndTime")
        
        $eventItem.Subject = $Subject
        $eventItem.Start = $startDateTime
        $eventItem.End = $endDateTime
        $eventItem.Location = $Location
        $eventItem.Body = $Description
        
        # Add attendees
        if (-not [string]::IsNullOrWhiteSpace($Attendees)) {
            $attendeeList = $Attendees -split "`n" | Where-Object { $_ -match '\S' }
            foreach ($attendee in $attendeeList) {
                $eventItem.Recipients.Add($attendee.Trim()) | Out-Null
            }
            $eventItem.Recipients.ResolveAll()
        }
        
        # Set reminder
        if ($Reminder) {
            $eventItem.ReminderSet = $true
            $eventItem.ReminderMinutesBeforeStart = 15
        }
        else {
            $eventItem.ReminderSet = $false
        }
        
        $eventItem.Display($false)
        
        $statusText.Text = "Status: Event created successfully"
        [System.Windows.MessageBox]::Show("Event has been opened in Outlook and is ready to send.", "Success", "OK", "Information") | Out-Null
    }
    catch {
        $statusText.Text = "Status: Error creating event"
        [System.Windows.MessageBox]::Show("Error: $_", "Error", "OK", "Error") | Out-Null
    }
}

# ===== EVENT HANDLERS =====

$createEmailBtn.Add_Click({
    if ([string]::IsNullOrWhiteSpace($emailToField.Text)) {
        [System.Windows.MessageBox]::Show("Please enter a recipient email address.", "Validation Error", "OK", "Warning") | Out-Null
        return
    }
    
    New-OutlookEmail -To $emailToField.Text `
                     -CC $emailCCField.Text `
                     -BCC $emailBCCField.Text `
                     -Subject $emailSubjectField.Text `
                     -Body $emailBodyField.Text `
                     -Importance $emailImportanceField.SelectedItem
})

$createEventBtn.Add_Click({
    if ([string]::IsNullOrWhiteSpace($eventSubjectField.Text)) {
        [System.Windows.MessageBox]::Show("Please enter an event subject.", "Validation Error", "OK", "Warning") | Out-Null
        return
    }
    
    if ($null -eq $eventStartDateField.SelectedDate) {
        [System.Windows.MessageBox]::Show("Please select a start date.", "Validation Error", "OK", "Warning") | Out-Null
        return
    }
    
    New-OutlookEvent -Subject $eventSubjectField.Text `
                     -StartDate $eventStartDateField.SelectedDate `
                     -StartTime $eventStartTimeField.Text `
                     -EndDate $eventEndDateField.SelectedDate `
                     -EndTime $eventEndTimeField.Text `
                     -Location $eventLocationField.Text `
                     -Attendees $eventAttendeesField.Text `
                     -Description $eventDescriptionField.Text `
                     -Reminder $eventReminderCheckBox.IsChecked
})

# Check Outlook on startup
$outlookInfo = Get-OutlookInfo
if ($outlookInfo.Installed) {
    $statusText.Text = "Status: $($outlookInfo.Message)"
    $statusText.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Green)
}
else {
    $statusText.Text = "Status: $($outlookInfo.Message) - Some features may not work"
    $statusText.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
}

# Show the window
$window.ShowDialog() | Out-Null

# Show the window
$window.ShowDialog() | Out-Null