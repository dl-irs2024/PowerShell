## Plan: Fast CSV Preview Loading

Improve preview responsiveness for large CSV files by loading only an initial 500 rows, enabling true DataGrid virtualization, and avoiding full-file row scans on initial display. Keep editor behavior unchanged for now to reduce risk.

**Steps**
1. Phase 1 - Baseline and guardrails
2. Add lightweight timing/status instrumentation in preview load flow to compare before/after behavior (load start, rows rendered, elapsed ms).
3. Keep current editor flow untouched; only preview and file-list stats paths are in scope.
4. Phase 2 - Virtualized preview rendering
5. Update DataGrid virtualization settings for preview so WPF can recycle row containers and avoid rendering all rows at once. This includes enabling row virtualization and ensuring logical scrolling is active (current code disables it).
6. Keep existing custom headers/frozen-column behavior, but verify no setting forces de-virtualization.
7. Phase 3 - Initial-row cap loading (500 rows)
8. Add a preview-specific CSV reader function that returns only header + first N data rows (default 500), building the same DataTable schema used today for compatibility with existing column setup code.
9. Wire Show-Preview to call this capped reader, update title/status to indicate shown rows vs total known rows when available.
10. Persist initial preview row cap in app settings with default 500, so it can be adjusted later without code changes.
11. Phase 4 - Fast file stats path
12. Replace expensive full-file line counting in file list stats with a lightweight approach for initial display (for example: skip row count on first add and compute lazily on selection, or use a streamed line counter that does not materialize file content).
13. Ensure the UI can show unknown/pending row counts gracefully without blocking drag/drop add operations.
14. Phase 5 - Optional next iteration (not in this change)
15. If needed after measurement, add real paging controls (page index + page size) as a follow-up. Current requested behavior is virtual scrolling + initial cap only.

**Relevant files**
- [CSV/SampleCsvEditor.ps1](CSV/SampleCsvEditor.ps1) - reuse/adjust Import-CsvTable, Show-Preview, Get-CsvFileStats, Set-DataGridColumns, and preview DataGrid XAML settings.

**Verification**
1. Load a large CSV (for example 100k+ rows) and confirm preview appears quickly with only 500 rows initially visible.
2. Confirm scrolling remains smooth and memory growth is reduced compared to baseline.
3. Confirm column headers, frozen-column toggles, sort behavior, and banding still work in preview.
4. Confirm opening editor still loads full table exactly as before.
5. Confirm file list add/drop no longer stalls due to row counting; status updates remain accurate.
6. Verify no new runtime errors via existing crash log path and normal preview/editor workflows.

**Decisions**
- Included: Preview grid performance only.
- Included: Initial preview cap of 500 rows.
- Included: Virtual scrolling behavior for preview.
- Excluded: Editor window paging/partial-load behavior.
- Excluded: Full paging UI controls in this iteration.

**Further Considerations**
1. Row-count display policy recommendation: show "Rows: 500 shown" immediately and update total asynchronously only when needed.
2. Save-as-you-see policy recommendation: keep preview read-only as-is; no editing from capped dataset to avoid partial-save confusion.
3. Follow-up threshold recommendation: if preview load exceeds 1.5s on common files after this change, prioritize adding explicit paging controls next.

## Initial Performance Findings (Observed Before Changes)

1. Full-file CSV materialization into `DataTable` on preview and editor load:
	- `Import-CsvTable` imported all rows and copied each field into a new `DataTable` row (`Import-CsvTable` in `SampleCsvEditor.ps1`).
	- Preview (`Show-Preview`) and editor (`Show-EditorWindow`) both used this full-load path.
	- Impact: startup lag and high memory use on large CSV files.

2. Full-file row counting during file list add:
	- Original `Get-CsvFileStats` counted lines with full content enumeration (`Get-Content ... | Measure-Object -Line`).
	- `Add-CsvFiles` called this for each discovered CSV while adding.
	- Impact: drag/drop add stalls when many or large CSV files are added.

3. Virtualization effectively disabled in key paths:
	- Grid setup used `ScrollViewer.CanContentScroll = $false`, which prevents normal logical scrolling virtualization behavior.
	- Editor grid explicitly had `EnableColumnVirtualization = "False"` and `CanContentScroll($false)`.
	- Impact: more visual container work and lower scrolling/render performance on large datasets.

4. Preview always loaded complete data even though preview is read-only:
	- No initial cap/paging behavior existed before this pass.
	- Impact: unnecessary cost for first paint where user only needs early rows to begin inspection.

## Implemented Delta (This Pass)

1. Added persisted preview row cap setting:
	- New setting key `PreviewRowLimit` with default `500`.
	- Validated/clamped by `Get-ValidPreviewRowLimit` (50..50000).

2. Added capped preview loader:
	- New `Import-CsvTablePreview -MaxRows` function.
	- Builds the same `DataTable` shape (including `__RowNumber`) for compatibility, but stops at the configured row limit.

3. Updated preview flow to use capped load + virtualization path:
	- `Show-Preview` now calls `Import-CsvTablePreview`.
	- `Set-DataGridColumns` gained `-EnableLogicalScrolling` and applies row/column virtualization + recycling mode when enabled.
	- Preview DataGrid XAML now sets virtualization flags and `ScrollViewer.CanContentScroll="True"`.
	- Status/title now indicate row cap behavior and measured preview load time.

4. Reduced bulk add overhead via lazy row counts:
	- `Get-CsvFileStats` now supports `-SkipRowCount` and uses streaming text read for headers and optional line counting.
	- `Add-CsvFiles` uses `-SkipRowCount` for initial list population.
	- Exact row count is refreshed on selection via `Refresh-SelectedFileStats`.

## Scope Notes

1. Editor remains full-load for now (intentional for lower-risk first phase).
2. Explicit paging UI (`Prev/Next` and page size controls) is not implemented yet.
3. Next recommended milestone: optional paging controls if preview load remains above target thresholds.
