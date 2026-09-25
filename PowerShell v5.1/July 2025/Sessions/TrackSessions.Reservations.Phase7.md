# TrackSessions Reservations - Phase 7: Recurring Reservations

**Status**: ✅ Complete  
**Created**: 2026-09-09  
**Module**: TrackSessions.Reservations.Recurring.psm1  
**Related**: Phase 2 (CRUD), Phase 4 (UI), Phase 5 (Viewer), Phase 6 (Settings)

---

## Overview

**Phase 7** extends the reservation system to support **recurring patterns** (daily, weekly, monthly reservations). Users can now create a single reservation entry that automatically generates multiple instances across a date range.

### Key Features

✅ **Recurrence Patterns**: None (one-time), Daily, Weekly, Monthly  
✅ **Date Range Control**: Set start date, end date, or occurrence count  
✅ **Occurrence Generation**: Automatically creates JSON files for each instance  
✅ **Series Management**: Cancel entire series or skip individual occurrences  
✅ **iCalendar RRULE**: RFC 5545 compatibility for calendar export  
✅ **Exception Handling**: Skip specific dates without affecting series  
✅ **Audit Trail**: SeriesId embedded in all occurrences for tracking  

---

## Architecture

### Phase 7 Module: TrackSessions.Reservations.Recurring.psm1

**7 Core Functions**:

| Function | Purpose | Returns |
|----------|---------|---------|
| **Get-RecurrencePatterns** | Define enum values | PSCustomObject with None, Daily, Weekly, Monthly |
| **Test-RecurrenceSettings** | Validate inputs | @{ Valid, Message, Errors[] } |
| **Get-RecurrenceOccurrences** | Generate dates | DateTime[] array of all occurrences |
| **ConvertTo-ICalendarRRule** | RFC 5545 format | String RRULE (e.g., FREQ=WEEKLY;UNTIL=...) |
| **New-RecurringReservation** | Create series | PSCustomObject[] with date, ReservationId, SeriesId, Status |
| **Remove-RecurringReservationSeries** | Cancel all | PSCustomObject[] with result per reservation |
| **Skip-RecurrenceOccurrence** | Cancel single date | PSCustomObject with skip status |

---

## Data Model Extension

### Reservation File Naming

Recurring reservations use the same naming convention as Phase 2, but **Comments field includes SeriesId**:

```
Reservation.{Machine}.{UserId}.{Date}.{StartTime}.{EndTime}.{Status}.json

Example for recurring series:
Reservation.PAWS66.YMJNB.20260910.100000.120000.Active.json
  Comments: "Team standup [Series: a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6]"

Reservation.PAWS66.YMJNB.20260911.100000.120000.Active.json
  Comments: "Team standup [Series: a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6]"
```

### JSON Fields for Recurrence

Standard Phase 2 schema + optional recurrence metadata:

```json
{
  "ReservationId": "uuid",
  "MachineName": "PAWS66",
  "UserId": "YMJNB",
  "UserDisplayName": "Davis Smith",
  "ReservationDate": "2026-09-10",
  "StartTime": "10:00",
  "EndTime": "12:00",
  "Status": "Active",
  "Comments": "Team standup [Series: a1b2c3d4-...]",
  "CreatedAtGmt": "2026-09-09T14:30:00.000Z",
  "LastModifiedAtGmt": "2026-09-09T14:30:00.000Z",
  "OverrideWarning": false,
  "CancelledAtGmt": null,
  "CancelledByUserId": null,
  "CancellationReason": null,
  
  // Optional recurrence metadata (informational)
  "SeriesId": "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6",
  "RecurrencePattern": "Weekly",
  "RecurrenceRRule": "RRULE:FREQ=WEEKLY;UNTIL=20261231T235959Z;BYDAY=WE"
}
```

---

## Recurrence Patterns

### 1. None (One-Time)
```powershell
# Single reservation, no recurrence
New-RecurringReservation `
  -RecurrencePattern "None" `
  -StartDate "2026-09-10" `
  # EndDate, MaxOccurrences, DayOfWeek, DayOfMonth ignored
```

**Occurrences**: 1 (only StartDate)

### 2. Daily
```powershell
# Every day for 2 weeks
New-RecurringReservation `
  -RecurrencePattern "Daily" `
  -StartDate "2026-09-10" `
  -EndDate "2026-09-24"
  
# Alternative: Exact count
New-RecurringReservation `
  -RecurrencePattern "Daily" `
  -StartDate "2026-09-10" `
  -MaxOccurrences 14
```

**Occurrences**: 15 (Sep 10, 11, 12, ..., 24)

### 3. Weekly
```powershell
# Every Wednesday for 3 months
New-RecurringReservation `
  -RecurrencePattern "Weekly" `
  -StartDate "2026-09-10" `
  -DayOfWeek "Wednesday" `
  -EndDate "2026-12-09"
  
# Requirement: First occurrence must match DayOfWeek
# If StartDate is Tuesday but DayOfWeek is Wednesday,
# first occurrence will be next Wednesday (Sep 16)
```

**Occurrences**: All Wednesdays from Sep 16 through Dec 9

**Valid DayOfWeek values**: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday

### 4. Monthly
```powershell
# Same day of month, every month
New-RecurringReservation `
  -RecurrencePattern "Monthly" `
  -StartDate "2026-09-15" `
  -DayOfMonth 15 `
  -EndDate "2026-12-15"
```

**Occurrences**: 15th of Sep, Oct, Nov, Dec

**Edge Case**: If DayOfMonth=31 and February occurs, that month is skipped (Feb 31 doesn't exist)

---

## Validation Rules

### RecurrenceSettings Validation

| Rule | Requirement | Example |
|------|-------------|---------|
| **Pattern** | Must be: None, Daily, Weekly, Monthly | `Daily` ✅, `Biweekly` ❌ |
| **StartDate** | Format yyyy-MM-dd, valid date | `2026-09-10` ✅, `9/10/26` ❌ |
| **EndDate** | Must be > StartDate, optional | `2026-12-31` ✅, `2026-09-10` ❌ |
| **MaxOccurrences** | Must be > 0, optional | `10` ✅, `0` ❌, `-5` ❌ |
| **DayOfWeek** | Required for Weekly pattern | `Wednesday` ✅, `Wed` ❌ |
| **DayOfMonth** | Required for Monthly, 1-31 | `15` ✅, `32` ❌ |

### Creation Validation

Each individual occurrence also validates via Phase 2 `New-Reservation`:
- Business hours (within configured start/end)
- Time slot granularity (30-min alignment)
- Conflict detection (unless OverrideWarning=true)
- User permissions (owner or admin)

**Behavior on conflict**: If `OverrideWarning=$true`, series continues despite conflicts. If `$false`, conflicting dates still create reservations (Phase 2 behavior unchanged).

---

## Usage Examples

### Example 1: Weekly Team Standup

Create a weekly Wednesday 10:00-10:30 standup for 13 weeks:

```powershell
$params = @{
    MachineName = 'PAWS66'
    UserId = 'YMJNB'
    UserDisplayName = 'Davis Smith'
    RecurrencePattern = 'Weekly'
    StartDate = '2026-09-16'      # First Wednesday
    DayOfWeek = 'Wednesday'
    EndDate = '2026-12-16'
    StartTime = '10:00'
    EndTime = '10:30'
    Comments = 'Team standup'
    SettingsPath = 'C:\SessionTracker\TrackSessions.Settings.json'
    ReservationPath = 'C:\SessionTracker\Reservations'
}

$results = New-RecurringReservation @params

# Output:
# Date         ReservationId                        SeriesId                             Status  Error
# ----         ---------------                      --------                             ------  -----
# 2026-09-16   a1b2c3d4-e5f6-4789-b012-c3d4e5f6g7  x9y8z7w6-v5u4-t3s2-r1q0-p9o8n7m6   Success
# 2026-09-23   e5f6g7h8-i9j0-4k1l-m2n3-o4p5q6r7s8  x9y8z7w6-v5u4-t3s2-r1q0-p9o8n7m6   Success
# 2026-09-30   i9j0k1l2-m3n4-4o5p-q6r7-s8t9u0v1w2  x9y8z7w6-v5u4-t3s2-r1q0-p9o8n7m6   Success
# ... (13 total)
```

### Example 2: Daily Maintenance Window (Fixed Count)

```powershell
$params = @{
    MachineName = 'MAINTENANCE-01'
    UserId = 'ADMIN'
    UserDisplayName = 'System Administrator'
    RecurrencePattern = 'Daily'
    StartDate = '2026-09-10'
    MaxOccurrences = 7           # One week only
    StartTime = '22:00'
    EndTime = '23:00'
    Comments = 'Night maintenance window'
    SettingsPath = 'C:\SessionTracker\TrackSessions.Settings.json'
    ReservationPath = 'C:\SessionTracker\Reservations'
}

$results = New-RecurringReservation @params

# Output: 7 reservations for Sep 10-16, 22:00-23:00
```

### Example 3: Cancel a Series

```powershell
$seriesId = 'x9y8z7w6-v5u4-t3s2-r1q0-p9o8n7m6'

$results = Remove-RecurringReservationSeries `
    -SeriesId $seriesId `
    -CancellationReason 'Team project cancelled' `
    -CancelledByUserId 'YMJNB' `
    -SettingsPath 'C:\SessionTracker\TrackSessions.Settings.json' `
    -ReservationPath 'C:\SessionTracker\Reservations'

# All 13 reservations marked as Cancelled
```

### Example 4: Skip One Occurrence

```powershell
# Team standup on Sep 23 cancelled due to holiday, others continue
$result = Skip-RecurrenceOccurrence `
    -SeriesId 'x9y8z7w6-v5u4-t3s2-r1q0-p9o8n7m6' `
    -OccurrenceDate '2026-09-23' `
    -CancelledByUserId 'YMJNB' `
    -SettingsPath 'C:\SessionTracker\TrackSessions.Settings.json' `
    -ReservationPath 'C:\SessionTracker\Reservations'

# Output: Sep 23 reservation marked Cancelled, series continues
```

---

## iCalendar RRULE Support

### Generated RRULE Examples

| Pattern | RRULE |
|---------|-------|
| Daily until Dec 31, 2026 | `RRULE:FREQ=DAILY;UNTIL=20261231T235959Z` |
| Weekly Wednesday until Dec 31 | `RRULE:FREQ=WEEKLY;UNTIL=20261231T235959Z;BYDAY=WE` |
| Monthly 15th, max 12 occurrences | `RRULE:FREQ=MONTHLY;COUNT=12;BYMONTHDAY=15` |

### Calendar Integration (Phase 3 Extension)

When Phase 3 Outlook integration processes recurring reservations:
1. Each individual occurrence creates a separate calendar event
2. SeriesId stored in event description or custom property
3. RRULE embedded in .ics attachment for calendar app compatibility

---

## Integration with Other Phases

### Phase 2 (CRUD Module)
- Phase 7 calls `New-Reservation`, `Cancel-Reservation`, `Get-Reservations` internally
- No changes needed to Phase 2; fully backward compatible

### Phase 3 (Outlook)
- Phase 3 processes each occurrence individually (unchanged)
- RRULE stored as metadata (informational only for calendars)

### Phase 4 (WPF Calendar Dialog)
- **Future Enhancement**: Add "Recurrence" tab to Create Reservation dialog
  - Pattern selector (None/Daily/Weekly/Monthly)
  - Date range inputs (Start, End)
  - Pattern-specific inputs (DayOfWeek, DayOfMonth)
  - Preview of generated occurrences
- Calls `New-RecurringReservation` instead of `New-Reservation`

### Phase 5 (HTML Viewer)
- Displays individual occurrences (unchanged from Phase 2)
- SeriesId visible in Comments field (optional: group by series)
- **Future Enhancement**: Series management UI (cancel all, skip occurrence)

### Phase 6 (Settings)
- No changes required
- All recurrence rules validated against business hours

---

## Error Handling

### Validation Errors

All validation errors returned in `@{ Valid=$false; Errors=@(...) }` format:

```powershell
$validation = Test-RecurrenceSettings `
    -RecurrencePattern 'Weekly' `
    -StartDate '2026-09-10' `
    -DayOfWeek 'Funday'  # Invalid

if (-not $validation.Valid) {
    Write-Error $validation.Message
    # Output: "Recurrence validation failed: Invalid DayOfWeek: Funday"
    $validation.Errors | ForEach-Object { Write-Host "  - $_" }
}
```

### Partial Failures in Series Creation

If one occurrence fails to create, others continue:

```powershell
$results = New-RecurringReservation @params

# Check for failures:
$failed = $results | Where-Object { $_.Status -eq 'Failed' }
if ($failed) {
    Write-Host "Warning: $($failed.Count) of $($results.Count) occurrences failed:"
    $failed | ForEach-Object { Write-Host "  $($_.Date): $($_.Error)" }
}
```

---

## Testing

### Unit Tests

```powershell
# Test 1: Validate recurrence settings
$v = Test-RecurrenceSettings `
    -RecurrencePattern 'Weekly' `
    -StartDate '2026-09-16' `
    -DayOfWeek 'Wednesday'
Assert-True $v.Valid

# Test 2: Generate daily occurrences
$dates = Get-RecurrenceOccurrences `
    -RecurrencePattern 'Daily' `
    -StartDate '2026-09-10' `
    -MaxOccurrences 5
Assert-Equal 5 $dates.Count

# Test 3: RRULE generation
$rrule = ConvertTo-ICalendarRRule `
    -RecurrencePattern 'Weekly' `
    -DayOfWeek 'Wednesday' `
    -EndDate '2026-12-31'
Assert-Like $rrule '*FREQ=WEEKLY*BYDAY=WE*'
```

### Integration Tests

```powershell
# Test: Create weekly series and verify files
$results = New-RecurringReservation @weeklyParams
$results | ForEach-Object {
    $filePath = Join-Path $ReservationPath `
        "Reservation.PAWS66.YMJNB.$($_.Date.Replace('-', '')).*.Active.json"
    Assert-True (Test-Path $filePath)
}

# Test: Cancel series
$cancelResults = Remove-RecurringReservationSeries -SeriesId $seriesId
$cancelled = $cancelResults | Where-Object { $_.Status -eq 'Cancelled' }
Assert-Equal $cancelled.Count $results.Count
```

---

## Performance Considerations

### Occurrence Generation
- Daily pattern for 1 year: ~365 iterations (instant)
- Weekly pattern for 5 years: ~260 iterations (instant)
- Monthly pattern for 10 years: ~120 iterations (instant)

### File I/O
- Each occurrence creates one JSON + one HTML file
- 100 occurrences = 200 files in ReservationPath
- **Recommendation**: Archive old reservations quarterly to maintain <5000 files

### Conflict Detection
- Each occurrence calls Phase 2's `Test-ReservationConflict`
- If 50 occurrences conflict with existing reservations, all 50 are still created
- **Tip**: Use `OverrideWarning=$true` for non-conflicting patterns (maintenance windows)

---

## Migration & Backward Compatibility

### Backward Compatibility

✅ **Fully compatible** with Phase 1-6:
- Existing one-time reservations unaffected
- New SeriesId field optional (not required for non-recurring)
- Phase 2-6 code unchanged

### Migrating Existing Reservations

Not supported (not necessary). Users can:
1. Keep existing one-time reservations as-is
2. Create new recurring series for future bookings
3. Manual bulk operations using Get-Reservations + Cancel-Reservation

---

## Future Enhancements

### Phase 7.1 - UI Integration
- Add "Recurrence" tab to Phase 4 Calendar Dialog
- Preview grid showing all generated occurrences
- Warnings for conflicts in series

### Phase 7.2 - Advanced Exception Handling
- Modify-RecurrenceOccurrence (change start/end time for specific date)
- Exception dates stored separately (JSON array)
- Better series tracking in UI

### Phase 7.3 - Performance Optimization
- Database backend for large series (>1000 occurrences)
- Lazy loading of occurrences in viewer
- Archive old reservations

---

## Summary

**Phase 7** adds enterprise-grade recurring reservation support to TrackSessions:

✅ 7 core functions for recurrence management  
✅ 4 pattern types (None, Daily, Weekly, Monthly)  
✅ RFC 5545 iCalendar RRULE support  
✅ Flexible date range control (EndDate or MaxOccurrences)  
✅ Series management (cancel all, skip single)  
✅ Validation with helpful error messages  
✅ Full backward compatibility with Phases 1-6  

**Production Ready**: All validation, error handling, and edge cases covered.

---

**Last Updated**: 2026-09-09, 15:45 UTC  
**Related Files**:
- [TrackSessions.Reservations.Recurring.psm1](TrackSessions.Reservations.Recurring.psm1)
- [Phase 2 CRUD](TrackSessions.Reservations.Phase2.md)
- [Phase 4 UI](TrackSessions.Reservations.Phase4.md)
