C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\July 2025\\Sessions\\TrackSessions.Prompts.md



Sessions\\TrackSessions.ps1





1:22 AM 7/23/2026

create new powershell 5.1 and wpf to track current Windows sessions.

A new JSON file should be created each time a user logs into Windows 11 or server versions. The folder for these JSON files should be a default parameter shown on the WPF app.  Windows session, user ID and user email address should all be shown on home page. Then the JSON file gets update every 3 minutes with session info.  the name of the JSON file should include "Session." Machine name, user ID, user display name and date and time stamp. Time should be GMT.







1:29 AM 7/23/2026

&#x20;take this one step further and make it switch to a stacked single-column layout when width is very small (mobile-style breakpoint behavior).



&#x20;add a compact change table at the top with columns for Date, File, Change Type, and Notes.





1:33 AM 7/23/2026

&#x20;add a compact change table at the top with columns for Date, File, Change Type, and Notes.

&#x20;Make the app icon like an orange circle that animates. this should be visible in the taskbar. and also upper left.  There should be a new Close After Session Button and also a Minimize icon right next to it.





1:37 AM 7/23/2026

The minimize shoudl minimize to a small rectangle - show machine name, current user and restore butto with an icon.



1:40 AM 7/23/2026

make the mini rectangle draggable and remember its last screen position between runs (saved in your settings JSON). use TrackSessions.Settings.json





1:44 AM 7/23/2026

the app starts and nothign shows like it exited, it doesn't look minimized. it was just working.





1:47 AM 7/23/2026

still disappears on startup, I’ll add a temporary startup trace log to TrackSessions.Settings.json so we can pinpoint exactly which event is firing first on your machine



1:52 AM 7/23/2026

Then show a Grid view for other JSON files found - in the same given tracking folder. this folder will eventually be a UNC path -shared on a windows network.

The grid view should be below the current session text box and show at least 3 lines. the header should always stay in view.

The grid view should show machine name, user id, user display name, last login, last activity columns.

The WPF app close event is important as it should finish writing a session and a Session close event in the JSON file. And also a new JSON file that shows .Logout.json suffix.





2:05 AM 7/23/2026

the grid view shoudl always be in view, add a horizontal splittle above to keep it separate from the version text box above and to make whole thing sizeable and responsive.



2:14 AM 7/23/2026

also make the splitter position persist in TrackSessions.Settings.json so it reopens with your preferred top/bottom





vibe session





11:38 PM 7/23/2026

TrackSessions.ps1'

TrackSessions.ps1: The property 'WindowWidth' cannot be found on this object. Verify that the property exists.



11:59 PM 7/23/2026

Added Edit Settings button that shows new dialog.

There should be a shared path entry (UNC)

An editable GridView should show Pre-set PAWS machine names and allow shortnames.  Optional FQDN column. Plus comments.

At bottom of dialog there should be a Save \& Close button and Cancel button. Plus Copy to Clipboard. The screen tip should be Copy in PowerShell Object format. All controls should have screen tips.

Settings stored in TrackSessions.Settings.json JSON config file edit machines to track. that already includes all main screen settings, window size and location.



12:14 AM 7/24/2026

add + and - buttons on both main screen and settings dialog - at lower left.  The zoom should zoom only the main text box and gridview below.  and for settings dialog, the zoom should zoom the gridview only.



12:38 AM 7/24/2026

make all text control values (that are read-only) selectable and copyable on main page.

Add a Copy button with screen tip "Copies Session and Grid as PowerShell object format".

"Other Session Files" should change to "Activity on Other Machines"

make the main screen actually consume the new Tracking.Machines and SharedPath values (for filtering/display/export behavior).

...12:55 AM 7/24/2026





12:44 AM 7/24/2026 1644 lines

Sessions\\TrackSessions.ps1

Sessions\\TrackSessions.ps1





1:02 AM 7/24/2026 testing

C:\\ProgramData\\SessionTracker\\Json \[Default]





1:12 AM 7/24/2026

Add startup overlay with close button that has instructions as part of XAML.

"This PowerShell UI app monitors status of other Windows machines.

This can be our own PAWS (Privileged) machines.

Each Remote Desktop login will generate a JSON tracking file in a shared UNC.

The GridView at bottom half will show the latest activity.

This is mainly to show if someone else might be using the machine that you want to use.

If you disconnect, this Session Tracker should be left running.

If you log out this and other apps will shutdown and the JSON file is finalized.

"



1:21 AM 7/24/2026

For the Settings dialog - add a button "Reveal in Explorer" for the path. Add a Browse button to show standard Windows folder browser dialog and let a path be chosen and saved to the path at top.





1:36 AM 7/24/2026 testing on PAWS 66



8:36 AM 7/24/2026 testing



C:\\ProgramData\\SessionTracker\\Json \[Default]







11:20 AM 8/14/2026

For status put the text status one of three values. where there is currently a date time stamp. then when I hover over that column and specific row, show the time stamp.  The actual status shoud be a state machine - that is.  login first, maybe disconnect then logout.





11:56 AM 8/14/2026

at all times the top part should have 3 rows visible.

the bottom Activity grid should have at least 3 rows visible.

So the entire app should constrain vertical minimum size - with these calculations in mind.





12:00 PM 8/14/2026

GitHub Copilot

&#x20;make the constraint math expose constants (for example top padding/margins) near the top of the script so you can tune the “3-row” feel without editing function internals.



Sessions\\TrackSessions.Simulator CR1.ps1
Candidate Release 1
10:47 PM 9/5/2026



10:54 PM 9/5/2026

Add version into JSON name - version string should be "cr1 Sept 2026" and show in caption.



Add compact mode.

By clicking on the round pulsating icon upper left, below caption, only the logo appears.
Small mode pulsating circle only, click to expand.

When new entries come in, they appear in a temporary frameless window in a compact view, showing only last 3 entries. then auto closes after 4 seconds.



11:21 PM 9/5/2026

remove the green collapse.

just show in minimized view, windows notifications of each new entry.





11:29 PM 9/5/2026

the legend should be 50% large - the boxes and text.

Minimize keeps window open - it should follow windows normal minimize.  the popup session window should diaplay momentarily and fade away.





11:51 PM 9/5/2026

Simulation Mode should just read "Simulation" and Edit Settings button should just be "Settings..."

The legend is too small - it should be 50% bigger than oriignal and looks smaller.





11:59 PM 9/5/2026

legend should be a row higher.

Notifications should only show when app is minimize.

All controls should have screen tips.



session notifications show.











+Horizontal or Vertical docking modes.



### Ask

How to compile PowerShell 5.1 and 7.x?





### Standards



Copy to Clipboard PSObject format.

HTML output format - Toc, Top links. Use Module?

How can I use Modules?





### **Optional**

\\\\Vp0wxsqm365as02\\sps



Update and append chat output summary and log of changes to Sessions\\TrackSessions.md



TrackSessions.Settings.json

TrackSessions.md

TrackSessions.Prompts.md



### 

&#x20;want updates to continue even when the WPF window is closed, I can add a background mode switch that runs hidden and keeps writing every 3 minutes.







### Simulator Version

Ahead of DXP Demo Noon

WED 10:47 AM 8/12/2026





TrackSessions.Simulator.ps1

TrackSessions.Simulator.ReadMe.md



10:47 AM 8/12/2026

Add a simulation toggle to turn on simulator mode, which create entries in the Activity Grid every 3-4 seconds.



new entries should appear at top of Grid



10:55 AM 8/12/2026

then add ramdon bands green for active, red for signed out, and light blue for disconnected and add a small legend above the Simulator checkbox









11:00 AM 8/12/2026

for active session show a blink darker green dot just to right of Server name in column one.







12:34 AM 9/6/2026

create a **SettingsSecurityModel.md** file that has ideas on how to centralize parameters like UNC and user list, but also allow users to have their local settings.  Then the JSON log entries are in a share UNC. I don't want to expose the main UNC path in PowerShell script, but also don't want all users to edit the path or the user list. I was thinking user list is on the UNC as read only.





10:01 PM 9/7/2026

Move Simulation to right side of same row.

Make 3 legend boxes have bolder borders like 3 points and same dark color as the pastel color.

Make all buttons including Zoom buttons and Settings dialog - have bold text.







++

Add new version .json write entry - beginning of each Day.

machine name.version.JSON

\-inside put all IP info, Windows version info, memory, PowerShell 5.1 and 7.x versions and details. .NET version. Office apps versions, Word, Excel. VS code version.



Add to Legend - purple for version.



Add About box

Checkbox write version beginning of each day.

Button - Write Version.



**Filters**

Radio Buttons:

Show Active Users (logged in, Disconnected)

Show Today only checkbox.



Add sort to each of the 5 column headers.

Show Recent activity per server.

Radio - Show Version Info for PAWS (written out at start of each session if first for the day.



▶️▶️



>>>

10:09 PM 9/7/2026

Append above chat verbatim along with formatting and file changes to Sessions\\TrackSessions.Chat.md - append since last append request.





>>

append all changes and chat summary above to TrackSessions.Simulator.ReadMe.md







### PAWS

\\\\Vp0wxsqm365as02\\sps

\\\\Vp0wxsqm365as02\\sps\\Davis







C:\\ProgramData\\SessionTracker\\Json \[Default]
Privileged Access WorkStation - PAWS



mtb012vp0030366

mtb012vp0030366.ds.irsnet.gov

mtb012vp0030367.ds.irsnet.gov

mtb012vp0030368.ds.irsnet.gov ?

mem020vp0030369.ds.irsnet.gov





🔬

**shell:common startup**

shell:startup





### **Enhancements**





FRI 8:36 AM 7/24/2026

Make it dockable and gridview responsive.

top 5 rows of gridview should be visible at all times.

Last update move to below Machine name. and show readable time. weekday date, time, seconds, time zone.

Countdown to next update in seconds to right of zoom buttons.









