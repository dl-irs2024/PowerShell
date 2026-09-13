## Plan: Fix v7 Settings Persistence

Stabilize v7 persistence by removing startup restore/save races, persisting Error dialog zoom into the existing settings JSON, and ensuring shutdown always flushes pending settings writes. This preserves current v7 features while matching v6 reliability for persisted state.

**Steps**
1. Phase 1 - Startup/Shutdown Persistence Order
2. Update startup sequence in the main script so settings restore happens before any forced save, and remove the immediate post-restore save that can overwrite restored values with transient defaults. This blocks all later persistence fixes.
3. Add an explicit final synchronous settings save during shutdown after debounce timer stop so pending geometry/checkbox changes are never dropped on app close. Depends on step 2.
4. Phase 2 - Window/Checkbox Persistence Robustness
5. Keep all checkbox values in the same JSON payload and verify Work Mode is included in both save and restore paths with no conditional skips during initialization. Parallel with step 3 once startup order is fixed.
6. Verify window geometry capture path prefers stable bounds during normal operation and safe fallback values during startup transitions, without clobbering valid multi-monitor negative coordinates. Depends on step 2.
7. Phase 3 - Error Dialog Zoom Persistence
8. Add Error dialog zoom value as a property in the same settings JSON file and wire restore during startup initialization of simple log dialog state.
9. Update zoom change handlers (plus/minus/reset) to trigger settings persistence so the font size survives restarts without waiting on unrelated window events. Parallel with step 6.
10. Phase 4 - Regression Safety and Validation
11. Validate setting file write/read cycles for: Work Mode, all checkboxes, window width/height/left/top, and Error dialog zoom in one end-to-end run.
12. Validate cold-start persistence: set values, close app, relaunch, verify restored values before user interaction.
13. Validate rapid close scenario: change zoom/window/Work Mode then close immediately; confirm shutdown flush preserved the latest values.

**Relevant files**
- c:/Users/YMJNB/OneDrive - Internal Revenue Service/Documents/PowerShell 2025/PowerShell v5.1/WPF PowerShell NC/TouchFiles/WpfTouchFiles5ChatGPT.v7.Sept2026.Lists.ps1 — adjust save/restore ordering, final flush, and zoom save/restore wiring in existing settings functions and dialog handlers.
- c:/Users/YMJNB/OneDrive - Internal Revenue Service/Documents/PowerShell 2025/PowerShell v5.1/WPF PowerShell NC/TouchFiles/WpfTouchFiles5ChatGPT.v7.Sept2026.Lists.settings.JSON — existing persistence target to keep as single source of truth (no new settings file).

**Verification**
1. Launch script, enable Work Mode + change other checkboxes + resize/move window + change Error dialog zoom, close app, relaunch, confirm all values restored.
2. Repeat with app closure immediately after changes to confirm shutdown save flush works.
3. Inspect JSON once after save to confirm all expected keys are present and updated together, including Error dialog zoom.
4. Run PowerShell diagnostics/lint for edited script region to ensure no new parser or runtime errors.

**Decisions**
- Included scope: persistence reliability for Work Mode, all checkboxes currently persisted, main window geometry, and Error dialog zoom in same JSON file.
- Excluded scope: redesign of UI, changes to v6 scripts, or migration to a new settings storage format.
- Assumption: existing settings file name/path remains unchanged and backward-compatible for older keys.

**Further Considerations**
1. Coordinate validation policy: keep current multi-monitor-safe negative coordinates and only reject extreme invalid values to avoid false resets.
2. Save trigger policy: keep debounced geometry saves but use immediate saves for discrete checkbox/zoom actions to maximize reliability.
