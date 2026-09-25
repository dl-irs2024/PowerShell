# TrackSessions Row Filter Broke - Root Cause Analysis & Recommendations

**Date**: 2026-09-20  
**Issue**: Grid rows disappeared after implementing background job performance optimization  
**Resolution**: Restored synchronous `$refreshAction` call before `ShowDialog()`  
**Status**: ✅ WORKING - Shows 3 rows (1 disconnected, 2 logged out)

---

## Executive Summary

**What Happened**: Background job optimization inadvertently broke grid display by introducing variable scope issues and attempting to replace working grid logic with a new cached data approach.

**Root Cause**: Variable scope conflicts in nested DispatcherTimer callbacks + premature optimization of working code.

**Fix**: Minimal change - call original working `$refreshAction` after background jobs complete AND before `ShowDialog()`.

**Key Lesson**: **Optimize WHEN code runs, not HOW it works** - especially when dealing with complex WPF variable scoping.

---

## Detailed Root Cause Analysis

### 1. What Was Changed (Background Job Implementation)

**Original Working Pattern** (TrackSessions.Simulator CR1,roewsShoeLive.ps1):
```powershell
# Line 739: Blocking LDAP call
$userContext = Get-CurrentUserContext  # 1-3+ seconds blocked

# Line 2780: Before ShowDialog - synchronous refresh
& $refreshAction  # Calls Get-SessionGridRows, blocks for 2-5 seconds

# Line 2783: Window shows with data already loaded
[void]$window.ShowDialog()
```

**New Broken Pattern** (initial attempt):
```powershell
# Line 739: Fast identity (no LDAP)
$userContext = [pscustomobject]@{ ... }  # Instant

# Line 3408: Window shows immediately (fast!)
[void]$window.ShowDialog()

# Lines 3020-3175: ContentRendered event with background jobs
$script:userContextJob = Start-BackgroundUserContextJob
$script:sessionLoadJob = Start-BackgroundSessionLoadJob

# Nested DispatcherTimer callback tries to update grid
# BUT: Variable scope issues break everything
```

### 2. The Three Critical Failures

#### Failure #1: Variable Scope in DispatcherTimer Callbacks

**Problem**: Variables like `$machineName`, `$gridSessionFiles`, `$userContext` defined in outer script scope were NOT accessible inside nested DispatcherTimer callbacks.

**Why It Failed**:
```powershell
# Outer scope (script level)
$machineName = $env:COMPUTERNAME
$gridSessionFiles = $window.FindName('GridSessionFiles')

$script:pollTimer.Add_Tick({
    # Inner scope (timer callback) - NEW SCRIPTBLOCK CONTEXT
    # $machineName is NULL here!
    # $gridSessionFiles is NULL here!
    
    Update-SessionGridDataFromCache  # Function can't access these variables
})
```

**PowerShell Scope Rules**:
- Each scriptblock (`{}`) creates a NEW scope
- Variables from parent scope are NOT automatically captured
- Must explicitly capture with `$local:varName` or use `script:` prefix
- Timer callbacks run in isolated scope for thread safety

**Evidence**:
- Log showed: "Excluded machine (current): " (empty string)
- Grid update succeeded but with 0 rows
- No error messages - silent failure due to null variables

#### Failure #2: Attempting to Replace Working Grid Logic

**Original Working Function**: `Get-SessionGridRows` (lines 836-946)
- Reads files with `Get-ChildItem`
- Filters by machine name
- Computes session status
- Deduplicates by machine+user
- Returns array of row objects

**New Broken Function**: `Update-SessionGridDataFromCache` (lines 1438-1569)
- Attempted to process pre-loaded cache
- Required `$machineName` and `$gridSessionFiles` parameters
- Tried to replicate original logic but introduced subtle differences
- Variable capture issues prevented it from working

**Mistake**: Rewrote working logic instead of just calling it.

#### Failure #3: Order of Operations

**Working Version Order**:
1. Load all data synchronously (slow but complete)
2. Call `$refreshAction` to populate grid
3. Show window with data already displayed

**Broken Version Order**:
1. Show window immediately (fast but empty)
2. Start background jobs
3. Try to populate grid from callback (scope issues)
4. Grid remains empty

### 3. Why Initial "Fixes" Failed

**Attempt #1**: Added parameters to `Update-SessionGridDataFromCache`
- **Problem**: Still required passing variables from callback scope
- **Result**: More complexity, same scope issues

**Attempt #2**: Captured variables in callback
```powershell
$localMachineName = $machineName
$localGridSessionFiles = $gridSessionFiles
```
- **Problem**: Variables already null when captured
- **Result**: Captured null values

**Attempt #3**: Used `Update-SessionGridData` (original function)
- **Problem**: Still called from timer callback with scope issues
- **Result**: Function worked but couldn't access outer variables

### 4. The Working Solution

**Final Fix** (minimal change):
```powershell
# Line 3408: Call original $refreshAction BEFORE ShowDialog
& $refreshAction
Add-StartupTrace -Path $SettingsPath -EventName 'Before.ShowDialog' -Detail 'Initial refresh complete'

[void]$window.ShowDialog()
```

**Why This Works**:
1. ✅ All variables in scope (script level)
2. ✅ Uses proven working `$refreshAction` code
3. ✅ No timer callbacks or scope issues
4. ✅ Grid populated before window shows

**Trade-off**: Startup is slower (3-8 seconds) but **grid works correctly**.

---

## Recommendations for Future Development

### A. PowerShell Module Architecture

**Current Problem**: 3,400+ line monolithic script with complex variable dependencies.

**Recommended Structure**:

```
Sessions/
├── TrackSessions.ps1                     # Main entry point (< 500 lines)
├── Modules/
│   ├── TrackSessions.Core.psm1           # Core types & initialization
│   ├── TrackSessions.UserContext.psm1    # User/LDAP operations
│   ├── TrackSessions.SessionData.psm1    # Session file I/O
│   ├── TrackSessions.GridLogic.psm1      # Grid filtering & display
│   ├── TrackSessions.Reservations.psm1   # ✅ Already exists!
│   └── TrackSessions.UI.psm1             # WPF window management
```

**Module Benefits**:
- ✅ Explicit parameter passing (no hidden dependencies)
- ✅ Unit testable functions
- ✅ Easier to reason about scope
- ✅ Can reload modules without restarting app
- ✅ Share code between TrackSessions variants

**Migration Strategy**:
1. Start with new features in modules (don't rewrite working code)
2. Extract stable functions incrementally
3. Keep `$refreshAction` in main script (it works!)
4. Test each extraction thoroughly

### B. Variable Scope Management

**Rule #1: Make Functions Pure**

❌ **Bad** (hidden dependencies):
```powershell
function Update-SessionGrid {
    # Implicitly uses $gridSessionFiles, $machineName from outer scope
    $rows = Get-SessionGridRows -FolderPath $script:effectiveOutputFolder
    $gridSessionFiles.ItemsSource = $rows
}
```

✅ **Good** (explicit parameters):
```powershell
function Update-SessionGrid {
    param(
        [Parameter(Mandatory)][string]$FolderPath,
        [Parameter(Mandatory)]$GridControl,
        [string]$ExcludeMachineName = '',
        $UsersList = @()
    )
    
    $rows = Get-SessionGridRows -FolderPath $FolderPath -ExcludeMachineName $ExcludeMachineName
    $GridControl.ItemsSource = $rows
}
```

**Rule #2: Use Script-Scoped Variables for Shared State**

```powershell
# At script level
$script:currentMachineName = $env:COMPUTERNAME
$script:sessionCache = @{}
$script:userDatabase = @()

# Functions access via script: prefix
function Get-CachedData {
    return $script:sessionCache[$key]
}
```

**Rule #3: Avoid Variables in Timer Callbacks**

❌ **Dangerous** (scope issues):
```powershell
$timer.Add_Tick({
    # DON'T access outer scope variables here
    Update-Grid -Machine $machineName  # May be null!
})
```

✅ **Safe** (explicit capture or call functions):
```powershell
$timer.Add_Tick({
    # Call function that uses script-scoped variables
    Invoke-RefreshAction
})

function Invoke-RefreshAction {
    # This function has access to script scope
    Update-Grid -Machine $script:currentMachineName
}
```

### C. Grid Filtering Implementation Strategy

**Current State**: Single grid showing all machines (filtered by current machine exclusion).

**Desired Features**:
1. Filter by machine name (dropdown or search)
2. Filter by user (dropdown or search)
3. Filter by date range (today, this week, last 7 days, custom)
4. Filter by status (Logged In, Logged Out, Disconnected)
5. Combine multiple filters

**Recommended Approach: ICollectionView Filtering**

**Why ICollectionView**:
- ✅ Built-in WPF filtering (no manual loops)
- ✅ Efficient (filters view, not data)
- ✅ Supports multiple filter predicates
- ✅ Automatically updates UI
- ✅ No risk of losing data

**Implementation Pattern**:

```powershell
#region Grid Filtering Module (TrackSessions.GridLogic.psm1)

function Initialize-SessionGridFilters {
    param(
        [Parameter(Mandatory)]$GridControl
    )
    
    $gridView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($GridControl.ItemsSource)
    
    # Define filter predicate
    $filterPredicate = {
        param($item)
        
        # Machine filter
        if ($script:filterMachine -and $item.MachineName -ne $script:filterMachine) {
            return $false
        }
        
        # User filter
        if ($script:filterUser -and $item.UserId -ne $script:filterUser) {
            return $false
        }
        
        # Status filter
        if ($script:filterStatus -and $item.RowStatus -ne $script:filterStatus) {
            return $false
        }
        
        # Date filter
        if ($script:filterDateFrom -or $script:filterDateTo) {
            $activityDate = [DateTime]::Parse($item.LastActivity)
            if ($script:filterDateFrom -and $activityDate -lt $script:filterDateFrom) {
                return $false
            }
            if ($script:filterDateTo -and $activityDate -gt $script:filterDateTo) {
                return $false
            }
        }
        
        return $true
    }
    
    $gridView.Filter = $filterPredicate
}

function Set-SessionGridFilter {
    param(
        [Parameter(Mandatory)]$GridControl,
        [string]$MachineName = '',
        [string]$UserId = '',
        [string]$Status = '',
        [DateTime]$DateFrom = [DateTime]::MinValue,
        [DateTime]$DateTo = [DateTime]::MaxValue
    )
    
    # Update filter variables
    $script:filterMachine = $MachineName
    $script:filterUser = $UserId
    $script:filterStatus = $Status
    $script:filterDateFrom = $DateFrom
    $script:filterDateTo = $DateTo
    
    # Refresh view (triggers filter predicate)
    $gridView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($GridControl.ItemsSource)
    $gridView.Refresh()
}

function Clear-SessionGridFilters {
    param([Parameter(Mandatory)]$GridControl)
    
    $script:filterMachine = ''
    $script:filterUser = ''
    $script:filterStatus = ''
    $script:filterDateFrom = [DateTime]::MinValue
    $script:filterDateTo = [DateTime]::MaxValue
    
    $gridView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($GridControl.ItemsSource)
    $gridView.Refresh()
}

#endregion
```

**UI Implementation** (add above grid in XAML):

```xml
<!-- Filter Panel -->
<Border Grid.Row="0" Background="#F5F5F5" BorderBrush="#CCCCCC" 
        BorderThickness="0,0,0,1" Padding="8">
    <StackPanel Orientation="Horizontal">
        <Label Content="Machine:" VerticalAlignment="Center" Margin="0,0,4,0"/>
        <ComboBox Name="CmbFilterMachine" Width="150" Margin="0,0,16,0">
            <ComboBoxItem Content="(All)" IsSelected="True"/>
        </ComboBox>
        
        <Label Content="User:" VerticalAlignment="Center" Margin="0,0,4,0"/>
        <ComboBox Name="CmbFilterUser" Width="150" Margin="0,0,16,0">
            <ComboBoxItem Content="(All)" IsSelected="True"/>
        </ComboBox>
        
        <Label Content="Status:" VerticalAlignment="Center" Margin="0,0,4,0"/>
        <ComboBox Name="CmbFilterStatus" Width="120" Margin="0,0,16,0">
            <ComboBoxItem Content="(All)" IsSelected="True"/>
            <ComboBoxItem Content="Logged In"/>
            <ComboBoxItem Content="Logged Out"/>
            <ComboBoxItem Content="Disconnected"/>
        </ComboBox>
        
        <Label Content="Date:" VerticalAlignment="Center" Margin="0,0,4,0"/>
        <ComboBox Name="CmbFilterDate" Width="120" Margin="0,0,16,0">
            <ComboBoxItem Content="All Time" IsSelected="True"/>
            <ComboBoxItem Content="Today"/>
            <ComboBoxItem Content="Last 7 Days"/>
            <ComboBoxItem Content="This Week"/>
            <ComboBoxItem Content="Last 30 Days"/>
        </ComboBox>
        
        <Button Name="BtnApplyFilter" Content="Apply" Width="70" Height="24" Margin="0,0,8,0"/>
        <Button Name="BtnClearFilter" Content="Clear" Width="70" Height="24"/>
    </StackPanel>
</Border>
```

**Event Handlers**:

```powershell
$btnApplyFilter.Add_Click({
    $machine = if ($cmbFilterMachine.SelectedIndex -gt 0) { $cmbFilterMachine.SelectedItem.Content } else { '' }
    $user = if ($cmbFilterUser.SelectedIndex -gt 0) { $cmbFilterUser.SelectedItem.Content } else { '' }
    $status = if ($cmbFilterStatus.SelectedIndex -gt 0) { $cmbFilterStatus.SelectedItem.Content } else { '' }
    
    # Date logic
    $dateFrom = [DateTime]::MinValue
    $dateTo = [DateTime]::MaxValue
    switch ($cmbFilterDate.SelectedIndex) {
        1 { # Today
            $dateFrom = [DateTime]::Today
            $dateTo = [DateTime]::Today.AddDays(1)
        }
        2 { # Last 7 Days
            $dateFrom = [DateTime]::Today.AddDays(-7)
        }
        3 { # This Week (Sunday to Saturday)
            $dateFrom = [DateTime]::Today.AddDays(-([int][DateTime]::Today.DayOfWeek))
        }
        4 { # Last 30 Days
            $dateFrom = [DateTime]::Today.AddDays(-30)
        }
    }
    
    Set-SessionGridFilter -GridControl $gridSessionFiles -MachineName $machine -UserId $user -Status $status -DateFrom $dateFrom -DateTo $dateTo
})

$btnClearFilter.Add_Click({
    $cmbFilterMachine.SelectedIndex = 0
    $cmbFilterUser.SelectedIndex = 0
    $cmbFilterStatus.SelectedIndex = 0
    $cmbFilterDate.SelectedIndex = 0
    Clear-SessionGridFilters -GridControl $gridSessionFiles
})
```

**Benefits of This Approach**:
- ✅ **No risk of breaking existing grid logic** - filtering happens AFTER data is loaded
- ✅ **Fast** - filters view, doesn't re-read files
- ✅ **Testable** - filter functions are pure
- ✅ **Incremental** - add one filter at a time
- ✅ **Works with existing `$refreshAction`** - just call `$gridView.Refresh()` after refresh

### D. Integration with Reservation System

**Current State**: Reservation system exists in separate modules (Phase 2-7).

**Integration Points**:

1. **Show Reservations in Grid**
   - Add "Reserved" status to grid rows
   - Check if machine has active reservation for time slot
   - Display reservation owner in tooltip

2. **Filter by Reservation Status**
   - "Available" - no active reservations
   - "Reserved" - has active reservation
   - "My Reservations" - reserved by current user

3. **Click Row to Create Reservation**
   - Right-click grid row → "Reserve This Machine"
   - Pre-fills machine name and current user
   - Opens `TrackSessions.Reservations.CalendarDialog.ps1`

**Safe Implementation Pattern**:

```powershell
#region Reservation Integration (TrackSessions.ReservationUI.psm1)

function Get-MachineReservationStatus {
    param(
        [Parameter(Mandatory)][string]$MachineName,
        [DateTime]$CheckTime = [DateTime]::Now
    )
    
    # Use existing Phase 2 module
    $reservations = Get-Reservations -MachineName $MachineName -Status 'Active'
    
    foreach ($res in $reservations) {
        $resDate = [DateTime]::Parse($res.ReservationDate)
        $resStart = [DateTime]::Parse("$($res.ReservationDate) $($res.StartTime)")
        $resEnd = [DateTime]::Parse("$($res.ReservationDate) $($res.EndTime)")
        
        if ($CheckTime -ge $resStart -and $CheckTime -le $resEnd) {
            return @{
                IsReserved = $true
                ReservedBy = $res.UserDisplayName
                ReservationId = $res.ReservationId
                EndTime = $resEnd
            }
        }
    }
    
    return @{ IsReserved = $false }
}

function Add-ReservationContextMenu {
    param(
        [Parameter(Mandatory)]$GridControl
    )
    
    $contextMenu = New-Object System.Windows.Controls.ContextMenu
    
    $menuReserve = New-Object System.Windows.Controls.MenuItem
    $menuReserve.Header = 'Reserve This Machine...'
    $menuReserve.Add_Click({
        $selectedRow = $GridControl.SelectedItem
        if ($selectedRow) {
            Show-ReservationDialogForMachine -MachineName $selectedRow.MachineName
        }
    })
    $contextMenu.Items.Add($menuReserve) | Out-Null
    
    $menuViewReservations = New-Object System.Windows.Controls.MenuItem
    $menuViewReservations.Header = 'View Reservations...'
    $menuViewReservations.Add_Click({
        $selectedRow = $GridControl.SelectedItem
        if ($selectedRow) {
            Show-ReservationCalendar -MachineName $selectedRow.MachineName
        }
    })
    $contextMenu.Items.Add($menuViewReservations) | Out-Null
    
    $GridControl.ContextMenu = $contextMenu
}

#endregion
```

**Integration Steps** (safe, incremental):
1. ✅ Import existing `TrackSessions.Reservations.psm1`
2. ✅ Add "Reservation Status" column to grid (optional display)
3. ✅ Add context menu to grid rows
4. ✅ Test without modifying existing refresh logic
5. ✅ Add reservation filter to filter panel

### E. Status Icon Enhancement: Adding Green to Disconnected

**Current Icons**: 🔴 (Red), 🟡 (Yellow), 🔵 (Blue)

**Desired**: Add 🟢 (Green) icon to Disconnected state

**Current Status Mapping**:
- "Logged In" → 🟢 Green
- "Logged Out" → 🔴 Red  
- "Disconnected" → 🔵 Blue

**Proposed Change**: "Disconnected" → 🟢 Green + 🔵 Blue (dual icon)

**Safe Implementation**:

```powershell
# In Get-SessionStatusFromSnapshot function (lines 1153-1175)
function Get-SessionStatusFromSnapshot {
    param(
        [Parameter(Mandatory = $true)]$SnapshotObject,
        [Parameter(Mandatory = $true)][string]$SourceFilePath
    )
    
    $fileName = [System.IO.Path]::GetFileName($SourceFilePath)
    $sessionStatus = $SnapshotObject | Select-Object -ExpandProperty SessionStatus -ErrorAction SilentlyContinue
    $closeEvent = $SnapshotObject | Select-Object -ExpandProperty SessionCloseEvent -ErrorAction SilentlyContinue
    $closedAt = $SnapshotObject | Select-Object -ExpandProperty SessionClosedAtGmt -ErrorAction SilentlyContinue
    
    # Check if logged out
    if ($fileName -like '*.Logout.json' -or $sessionStatus -eq 'Closed' -or -not [string]::IsNullOrWhiteSpace($closedAt) -or -not [string]::IsNullOrWhiteSpace($closeEvent)) {
        return 'Logged Out'
    }
    
    # Check LastUpdatedAtGmt
    $lastUpdateRaw = $SnapshotObject | Select-Object -ExpandProperty LastUpdatedAtGmt -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($lastUpdateRaw)) {
        try {
            $lastUpdate = [datetime]::Parse($lastUpdateRaw, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
            $age = [DateTime]::UtcNow - $lastUpdate.ToUniversalTime()
            if ($age.TotalMinutes -ge 3) {
                return 'Disconnected'  # This is what we want to enhance
            }
        }
        catch {
        }
    }
    
    return 'Logged In'
}
```

**Option A: Add Icon to Status String**

```powershell
# When building grid rows
$rows += [pscustomobject]@{
    MachineName = $machineValue
    UserId = [string]$obj.UserId
    UserDisplayName = [string]$obj.UserDisplayName
    LastLogin = [string]$obj.CreatedAtGmt
    LastActivity = [string]$obj.LastUpdatedAtGmt
    RowStatus = if ($computedStatus -eq 'Disconnected') { '🟢🔵 Disconnected' } else { $computedStatus }
    StatusTimestamp = $statusTimestamp
    StatusTimestampDisplay = ("Status changed at: {0}" -f $statusTimestamp)
}
```

**Option B: Add Separate Icon Column**

```xml
<!-- In Grid XAML, add new column -->
<DataGridTemplateColumn Header="Icon" Width="50">
    <DataGridTemplateColumn.CellTemplate>
        <DataTemplate>
            <TextBlock FontSize="16" HorizontalAlignment="Center">
                <TextBlock.Style>
                    <Style TargetType="TextBlock">
                        <Style.Triggers>
                            <DataTrigger Binding="{Binding RowStatus}" Value="Logged In">
                                <Setter Property="Text" Value="🟢"/>
                            </DataTrigger>
                            <DataTrigger Binding="{Binding RowStatus}" Value="Logged Out">
                                <Setter Property="Text" Value="🔴"/>
                            </DataTrigger>
                            <DataTrigger Binding="{Binding RowStatus}" Value="Disconnected">
                                <Setter Property="Text" Value="🟢🔵"/>
                            </DataTrigger>
                        </Style.Triggers>
                    </Style>
                </TextBlock.Style>
            </TextBlock>
        </DataTemplate>
    </DataGridTemplateColumn.CellTemplate>
</DataGridTemplateColumn>
```

**Option C: Use Background Color** (most robust)

```xml
<DataGrid.RowStyle>
    <Style TargetType="DataGridRow">
        <Style.Triggers>
            <DataTrigger Binding="{Binding RowStatus}" Value="Logged In">
                <Setter Property="Background" Value="#E8F5E9"/>  <!-- Light green -->
            </DataTrigger>
            <DataTrigger Binding="{Binding RowStatus}" Value="Logged Out">
                <Setter Property="Background" Value="#FFEBEE"/>  <!-- Light red -->
            </DataTrigger>
            <DataTrigger Binding="{Binding RowStatus}" Value="Disconnected">
                <Setter Property="Background">
                    <Setter.Value>
                        <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                            <GradientStop Color="#E8F5E9" Offset="0.0"/>  <!-- Green -->
                            <GradientStop Color="#E3F2FD" Offset="1.0"/>  <!-- Blue -->
                        </LinearGradientBrush>
                    </Setter.Value>
                </Setter>
            </DataTrigger>
        </Style.Triggers>
    </Style>
</DataGrid.RowStyle>
```

**Recommendation**: Use Option C (background gradient) for "Disconnected" state.
- ✅ Clear visual distinction
- ✅ Accessible (doesn't rely on emoji rendering)
- ✅ Professional appearance
- ✅ Easy to implement
- ✅ No changes to data processing logic

---

## Testing Strategy for Future Changes

**Before Making Changes**:
1. ✅ Document current behavior (screenshot grid with test data)
2. ✅ Identify which files have actual test data
3. ✅ Create a backup copy of working version
4. ✅ Use descriptive filename: `TrackSessions.Simulator CR1.BEFORE-FilterChanges.ps1`

**During Development**:
1. ✅ Make ONE change at a time
2. ✅ Test immediately after each change
3. ✅ Check Debug Log for errors
4. ✅ Verify grid row count matches expected

**Test Cases** (save these in a test plan):
```powershell
# Test Data Setup:
# - Machine A: 1 file, Disconnected (3+ minutes old)
# - Machine B: 1 file, Logged Out (.Logout.json)
# - Machine C: 1 file, Logged In (< 3 minutes old)

# Expected Results:
# - 3 rows total
# - 1 Disconnected
# - 1 Logged Out
# - 1 Logged In
```

**Rollback Plan**:
- Keep `TrackSessions.Simulator CR1,roewsShoeLive.ps1` as known-good version
- If changes break grid, immediately revert to that file
- Don't try to "fix forward" when grid is broken - revert and start over

---

## Architecture Modernization Roadmap

### Phase 1: Extract Core Modules (Low Risk)
- ✅ `TrackSessions.Reservations.psm1` - Already exists, working
- 🔲 `TrackSessions.UserContext.psm1` - Extract user lookup functions
- 🔲 `TrackSessions.SessionData.psm1` - Extract file I/O functions
- 🔲 Keep `$refreshAction` in main script (don't touch it!)

### Phase 2: Add Filtering (Medium Risk)
- 🔲 Implement ICollectionView filtering
- 🔲 Add filter UI panel
- 🔲 Test thoroughly with actual data
- 🔲 Fallback: If broken, disable filters (feature flag)

### Phase 3: Background Job Optimization (High Risk)
- ⚠️ Only attempt after Phase 1 & 2 stable
- ⚠️ Keep synchronous version as fallback
- ⚠️ Use feature flag: `$script:UseAsyncLoading = $false` (default)
- ⚠️ Extensive testing required

### Phase 4: Advanced Features
- 🔲 Reservation integration
- 🔲 Multi-machine comparison view
- 🔲 Historical trend graphs
- 🔲 Export to Excel

---

## Key Takeaways

1. **Respect Working Code**: If it works, optimize WHEN it runs, not HOW.

2. **Variable Scope Matters**: PowerShell scriptblocks create new scopes - be explicit.

3. **Test with Real Data**: Synthetic data doesn't reveal filtering issues.

4. **One Change at a Time**: Grid worked, then broke after background jobs - easy to identify.

5. **ICollectionView for Filtering**: Built-in WPF feature prevents manual filtering bugs.

6. **Modules for Maintainability**: 3,400 lines is too much for one file.

7. **Feature Flags for Safety**: `$script:EnableNewFiltering = $false` allows quick rollback.

8. **Keep Known-Good Versions**: `TrackSessions.Simulator CR1,roewsShoeLive.ps1` is gold.

---

## Conclusion

The grid broke because we tried to optimize too many things at once (variable scope + new grid logic + background jobs). The fix was simple: go back to calling the proven working `$refreshAction`.

**For future filtering features**: Use ICollectionView filtering on top of existing grid data - don't replace the grid logic that works.

**For future performance optimization**: Optimize the file loading (background jobs) but keep the proven grid display logic unchanged.

**For future modules**: Extract functions incrementally without changing behavior - testability and maintainability come from structure, not rewriting.

---

**Document Version**: 1.0  
**Author**: Claude Code (Anthropic)  
**Review Status**: Ready for user review
