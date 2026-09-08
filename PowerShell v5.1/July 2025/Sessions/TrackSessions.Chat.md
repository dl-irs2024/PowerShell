## 2026-09-07 Append

### User Request

Move Simulation to right side of same row.
Make 3 legend boxes have bolder borders like 3 points and same dark color as the pastel color.
Make all buttons including Zoom buttons and Settings dialog - have bold text.

### Assistant Response

Applied all three UI requests in [Sessions/TrackSessions.Simulator CR1.ps1](Sessions/TrackSessions.Simulator%20CR1.ps1).

What changed:
1. Simulation moved to the right side of the same row
- Converted the row into a 2-column Grid.
- Left side now contains zoom controls + status text.
- Simulation checkbox is now right-aligned in column 2.
- Updated at [Sessions/TrackSessions.Simulator CR1.ps1](Sessions/TrackSessions.Simulator%20CR1.ps1#L832).

2. Legend boxes now have bolder, darker borders
- All 3 legend color boxes changed from BorderThickness 1 to 3.
- Border colors updated to darker tones matching each pastel group:
  - Logged In: #3F8E5A
  - Logged Out: #B45B66
  - Disconnected: #4F7FAF
- Updated at [Sessions/TrackSessions.Simulator CR1.ps1](Sessions/TrackSessions.Simulator%20CR1.ps1#L823).

3. All buttons now use bold text (including Zoom + Settings dialog)
- Added a window-level Button style (FontWeight=Bold) in:
  - Main window resources at [Sessions/TrackSessions.Simulator CR1.ps1](Sessions/TrackSessions.Simulator%20CR1.ps1#L652)
  - Mini window resources at [Sessions/TrackSessions.Simulator CR1.ps1](Sessions/TrackSessions.Simulator%20CR1.ps1#L899)
  - Settings dialog resources at [Sessions/TrackSessions.Simulator CR1.ps1](Sessions/TrackSessions.Simulator%20CR1.ps1#L1270)
- This automatically bolds all buttons in those windows, including zoom buttons and settings dialog buttons.

Validation:
- Checked diagnostics for the file; no new errors from this change.
- Existing warning remains unrelated: unapproved verb in function name Append-StartupTrace.

### File Changes Included

- Updated file: Sessions/TrackSessions.Simulator CR1.ps1
- UI updates included in this append:
  - Simulation checkbox moved to right side of row
  - Legend borders increased to thickness 3 and darkened
  - Bold button style applied in main, mini, and settings windows
