# Ideas: Avoid PowerShell Parser Errors Like the Sort-Indicator Failure

## What Happened

The parser error came from non-ASCII arrow characters in code strings (`↑`, `↓`) being saved/decoded as mojibake (`â†‘`, `â†“`) in one environment path. Once mangled, the quote parsing broke and PowerShell reported cascading brace/token errors.

## Practical Ways To Avoid This

1. Use ASCII-only UI markers in script literals.
- Prefer ` (Asc)` / ` (Desc)` over glyphs like arrows.
- This is the safest fix for mixed editor/terminal/encoding environments.

2. Keep script file encoding stable.
- Save `.ps1` files as UTF-8 (with BOM for Windows PowerShell 5.1 compatibility across tools).
- Avoid switching between tools that silently rewrite encoding.

3. Add a pre-run parser check before launch.
- Command:
```powershell
$null = $errors = $tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  'TouchFiles/WpfTouchFiles5ChatGPT.v7.Sept2026.Lists.ps1',
  [ref]$tokens,
  [ref]$errors
) | Out-Null
if ($errors.Count -gt 0) { $errors | Format-List * }
```
- Run this after edits and before app startup.

4. Add a quick non-ASCII detector for `.ps1` files.
- Command:
```powershell
$path = 'TouchFiles/WpfTouchFiles5ChatGPT.v7.Sept2026.Lists.ps1'
$text = Get-Content -LiteralPath $path -Raw
if ($text -match '[^\u0000-\u007F]') {
  Write-Warning "Non-ASCII characters found in $path"
}
```
- Keep non-ASCII only where absolutely necessary.

5. Guard risky UI text transformations.
- Centralize sort suffixes in variables (`(Asc)`, `(Desc)`) so replacements happen in one place.
- Avoid repeated inline literals that are easy to miss.

6. Treat first parse error as root cause.
- Later brace/token errors are often cascade failures.
- Fix earliest line/char parser error first, then re-parse.

7. Keep debug popups behind environment flags.
- You already do this pattern well.
- Continue using env toggles to avoid hard-coded debug literals everywhere.

## Suggested Team Convention

- Script source (`.ps1`): ASCII-only unless there is a hard requirement.
- UI-visible glyphs: use ASCII equivalents in script, reserve symbols for XAML/resources if needed.
- Commit gate: parser check + non-ASCII check for modified PowerShell files.

## Optional Automation

Create a helper script (example name: `TouchFiles/Test-ParseAndAscii.ps1`) that runs both checks and exits non-zero if either fails. This can be run manually or from your launch `.cmd` before starting the WPF app.

## Work Mode Persistence: How It Should Work, Why It Breaks, and What To Check

### How persistence is intended to work

1. `Save-WindowSettings` writes all UI state into one JSON file:
- `WpfTouchFiles5ChatGPT.v7.Sept2026.Lists.settings.JSON`
- Includes `WorkMode`, `RememberWindow`, window bounds, and other checkboxes.

2. `Restore-WindowSettings` reads that JSON at startup and applies:
- `ChkWorkMode.IsChecked`
- Internal runtime flag: `$script:workModeEnabled`
- Then layout/column code uses `workModeEnabled` to adjust visible controls.

3. On user interactions, save triggers run with reason tags (recent updates):
- checkbox clicks
- debounce save tick (size/location)
- shutdown final flush
- other explicit save points

### Why Work Mode can still appear "not persisting"

1. App restart gap (most common in this project flow).
- If an old instance is still running, new code isn’t active.
- User changes may be tested against stale logic.

2. Save blocked by geometry edge-case before recent hardening.
- Earlier versions could skip whole save when geometry was invalid/off-screen.
- Result: `WorkMode` checkbox changes looked unsaved even though click handler fired.

3. Multiple save triggers racing during startup.
- If restore is followed too quickly by conflicting save paths, restored values can be overwritten.
- This was previously seen around startup ordering and has been partially mitigated.

4. Settings file corruption or partial write.
- If JSON is empty/truncated/corrupt, restore falls back to defaults.
- Then Work Mode appears to "forget" state.

5. UI state mismatch between checkbox and runtime flag.
- If `ChkWorkMode.IsChecked` and `$script:workModeEnabled` get out of sync, layout may not reflect persisted value.

### Current known risk points to monitor

1. `Save-WindowSettings` writes under many triggers.
- Good for reliability, but can hide ordering bugs.

2. Any startup save that occurs before full restore/state stabilization.
- Can overwrite correct persisted values with defaults.

3. Any exception in save path that is swallowed after logging.
- User sees behavior regression, but app continues running.

### Practical debug checklist (fast)

1. Ensure only one app instance is running.

2. Turn on diagnostics:
- `TOUCHFILES_VERBOSE=1`
- optional `TOUCHFILES_TRACE=1`

3. Change Work Mode, then close app normally.

4. Verify JSON contains expected key/value:
- `"WorkMode": true` (or false)

5. Relaunch and inspect Error dialog transcript for:
- `Settings loaded: ... WorkMode=...`
- `Settings applied: ... WorkMode=...`
- `Save-WindowSettings reason='...' ... WorkMode=...`

6. If values differ between loaded/applied/saved lines, note the first mismatch; that is usually the true break point.

### Hardening ideas if issue persists

1. Add a startup guard flag:
- Do not allow non-essential saves until restore completes.

2. Serialize startup sequence explicitly:
- load settings -> apply controls -> set runtime flags -> enable save triggers.

3. Add atomic settings write pattern:
- write to temp file, then replace target.
- reduces partial/corrupt JSON outcomes.

4. Add a one-line integrity stamp in settings payload:
- timestamp + write reason + app version.
- helps correlate wrong overwrites quickly.

5. Add a dedicated "Persisted state snapshot" command in Error dialog.
- dumps current in-memory values plus on-disk JSON values side-by-side.

### Bottom line

Work Mode persistence depends on three things staying aligned:
- on-disk JSON (`WorkMode`),
- checkbox value (`ChkWorkMode.IsChecked`),
- runtime flag (`$script:workModeEnabled`).

When users report failure, compare these three in order. The first divergence identifies the actual defect stage.

## Local Notes Rich Text and Emoji Ideas (WPF)

### Why emojis may not show full color today

1. Current Local Notes editor uses WPF `TextBox` in a `GridView` cell.
- `TextBox` is plain text only (no rich formatting model).

2. Color emoji rendering depends on font fallback and platform text stack behavior.
- Some emoji sequences render monochrome or fallback glyphs in WPF controls.
- ZWJ sequences and variation selectors can degrade if fallback font path is limited.

3. If the chosen text font does not support COLR/CBDT emoji well, WPF falls back to non-color glyphs.

### Practical options for richer Local Notes

1. Keep `TextBox` but improve emoji appearance (lowest risk).
- Set a font stack that prioritizes emoji-capable fonts where possible.
- Keep storage as plain string in `.List.JSON` (no schema change).
- Good for quick wins, still no bold/italic/colors per word.

2. Switch Local Notes editor to `RichTextBox` with plain-text persistence (medium risk).
- Editing becomes richer in UI.
- On save, serialize as text-only extraction for compatibility.
- Loses formatting after reload unless additional format field is stored.

3. Add dual persistence: plain text + rich payload (higher value, higher complexity).
- Store:
  - `LocalNotes` (plain text)
  - `LocalNotesRichXaml` (optional rich document)
- Backward compatible with existing files.
- Allows opt-in rich rendering while preserving old behavior.

4. Use markdown-style lightweight formatting instead of full RichTextBox.
- Keep `TextBox` editor and render styled preview in a separate panel.
- Smaller complexity than full rich editing in each grid cell.

### Recommended phased approach

1. Phase 1: Improve emoji display only.
- Add explicit `FontFamily` for Local Notes editor that favors emoji support.
- Verify with sample notes containing multi-codepoint emojis.

2. Phase 2: Add optional rich note mode in a side editor (not inline cell).
- Keep grid cell simple for performance.
- Open selected note in a dedicated `RichTextBox` panel/dialog.

3. Phase 3: If needed, persist `LocalNotesRichXaml` alongside plain text.
- Maintain strict fallback path so older lists still load cleanly.

### Performance and UX cautions

1. `RichTextBox` inside every row can be heavy for large lists.
- Prefer one shared editor for selected row rather than per-row rich control.

2. Keep autosave path tested.
- Rich payload can increase JSON size and serialization time.

3. Preserve copy/paste compatibility.
- Ensure plain text extraction remains reliable when rich formatting exists.
