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

the grid view should always be in view, add a horizontal splittle above to keep it separate from the version text box above and to make whole thing sizeable and responsive.



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





### Wave 2 Features - Requirements Solidified



1:39 PM 9/14/2026



Track Sessions
Create Entry every 3 minutes:
machine name, user email. date/time, status.json
Status: logged in, logged out, disconnected.
Grid display:
Show all users:
machine name sort latest first - last 10 per machine.
if last 2 logged in - effective status = logged in.
if no activity over (constant 3 minutes) = disconnected
if logged out - effective logged out.
...
per machine show.
...
Reservations:
only today and future displayed.
show all machines, chrono order.
allow cancel?
button to email user or text ! are you online?
Calendar shows all PAWS by default.
New Reservation. pick PAWS.
...
PAWS and Non paws mode:
Use server list - where stored? central.
If machine name FQDN in list than PAWS mode.
Non-paws. show only paws, not log local anything but can reserve!
...
Main display - can filter by PAWS.
show reservations at top for now. Tool tip show comments/notes.
...
User List -central? Admin mode edit.
Not change much, backup.
...
Admin mode;
edit users, edit servers.
Can cancel users, delete entries.
??where HTML reservation seen?
...
may need Admin folder - that only some can write. sub-folder.
...
Admin folder has server and user list.
Allow for special case machines. maybe another class.
Allow for recurring reservations or week advance.
...
Admin Mode:
Archive entries old than a month to Daily.Archives sub-folder.
...
Reservation:
create email.
Create calendar event. somehow check.

....
Simulation mode - create entries logged in, logged in, skip time 3 minutes, logged out - in that order with random users. and per machine name.
...
Simulation mode - reservations.
Create random entries every hour.

...









### Merge after Old Release to Rizu etc - 9-17-2026



C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\July 2025\\Sessions\\TrackSessions.Simulator CR1.merge.ps1



7:17 AM 9/18/2026 FRI

The Disconnected session (blue) is not showing. it should follow same logic as

Sessions\\PAWS-Candidates\\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1





7:31 AM 9/18/2026 Disconnected Blue works.

for the machine grid status - there should always be 4 rows displays and also display header - then adjust starting horizontal grid splitter to shink size of top if necessary.





8:10 AM 9/18/2026

the vertical size of the app should be sized to fix 4 rows and then the top part above grid can be shrunk, I will addres the vertical height of that area next.



8:16 AM 9/18/2026 vs code crashed onedrive concurrent.





### Scheduling Feature 9-11-2026





New UNC File - Machine name, FQDN, User ID - First.Last - WeekDay-mm-dd-yyyy.StartTime,EndTime.EDT.







Sessions\\TrackSessions.ps1



1:11 AM 9/11/2026 FRI



add a Reservation into legend to the right, make it Purple color.



For Reservation Window the Date overlaps the actual blue date, which should be moved to right.

When I hover over a day, it should show Display names, Time Slot and Machine name. This info can be retrieve by querying shared path and filtering by date.



1:30 AM 9/11/2026

Reservation Window - The Days of Month should be bolder and larger. Each square should have a light purple pastel background and 3 pt bold border - darker purple (matches the legend color).

The Display names should be shown under each date.





>>

append above chat output verbatim along with formatting to Sessions\\TrackSessions.Chat.md and include change summaries and files affected.





**PLAN**

Reservations should show today and maybe tomorrow

Filter on Today. Upcoming, Past. maybe All - radio buttons.





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

7/27/2026 works David Fishman

\\\\Vp0wxsqm365as02\\sps

\\\\Vp0wxsqm365as02\\sps\\Davis

4:39 AM 9/8/2026 blocked







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





### User Editor - TUE 9/8/2026



Sessions\\TrackSessions.UserEditor.ps1



4:39 AM 9/8/2026

8:00 AM 9/8/2026

Create new WPF PowerShell 5.1 in Sessions\\TrackSessions.UserEditor.ps1 to show list of users stored in new users file TrackSessions.Users.json.

A user grid should display: SEID, First Name, last name, Status, IRS Email, SEID Email, Timezone, Products, Last Login, Last PAWS Used, Last Modified, Created.

Then when row clicked (single select), and Edit... button or double-clicked, an Edit User dialog pops up (that is modal).

SEID, First Name, Last name should be string.

Status should be combobox: FTE, Contractor.

IRS Email should end in @irs.gov

SEID Email should prefill SEID field and append @ds.irsnet.gov.

Timezone should be combbox:  include CA time and also Atlantic, Puerto Rico time, Texas, Utah, and Washington DC named cities and time zone codes.

Have a check box for Daylight savings time.

Products should be multi-select combo: SharePoint, Power Platform, OneDrive, Entra.

Last Login is date time field, formatted as www dd/mm/yyyy hh:mm

where www is day of week.

Last PAWS is FQDN of the last PAWS used from the shared settings???

Last modified is this entry last modified date time field, formatted as www dd/mm/yyyy hh:mm

where www is day of week.

Date created is date this entry created date time field, formatted as www dd/mm/yyyy hh:mm

where www is day of week.





8:20 AM 9/8/2026

8:28 AM 9/8/2026

in New / Edit dialog add a Load button that takes the SEID and tries to find the rest of the row information.



DONE

&#x20;Load optionally query an external source (AD/Graph/CSV) when no local SEID match exists.





10:57 AM 9/8/2026 1357 lines

Make Purple the SEID and also IRS email field - if I enter Last First \[First.Last@irs.gov](mailto:First.Last@irs.gov) -- or similar into IRS email - look up rest of fields if all blank.





11:14 AM 9/8/2026

if I enter Last First \[First.Last@irs.gov](mailto:First.Last@irs.gov) -- or similar into IRS email - including look up the SEID.

Patterson Richard L [Richard.Patterson@irs.gov](mailto:Richard.Patterson@irs.gov)



11:18 AM 9/8/2026

It still wants SEID first - maybe have SEID unknown checkbox or disable SEID  and then lookup vira email as above. Email partial lookup working.





11:57 AM 9/8/2026

when pasting an SEID - make it all uppercase

make label text for `SEID` and `IRS Email` bold to match the stronger input styling.





**NEXT**

Remember size and location of window in TrackSessions.UserEditor.Settings.json





Sessions\\TrackSessions.UserEditor.ps1



Patterson Richard L [Richard.Patterson@irs.gov](mailto:Richard.Patterson@irs.gov)

Patterson Richard L [Richard.Patterson@irs.gov](mailto:Richard.Patterson@irs.gov)

Graves Ross M IV [Rossie.M.GravesIV2@irs.gov](mailto:Rossie.M.GravesIV2@irs.gov)

Iaco Keith A [Keith.A.Iaco@irs.gov](mailto:Keith.A.Iaco@irs.gov)

Le Trung T [Trung.T.Le@irs.gov](mailto:Trung.T.Le@irs.gov); Slack Jennifer [Jennifer.Slack@irs.gov](mailto:Jennifer.Slack@irs.gov); Bynum Shalonda N [Shalonda.N.Bynum@irs.gov](mailto:Shalonda.N.Bynum@irs.gov); Gupta Rizu [Rizu.Gupta@irs.gov](mailto:Rizu.Gupta@irs.gov); Zurita Mike [mike.zurita@irs.gov](mailto:mike.zurita@irs.gov); Wright Desiree D [Desiree.D.Wright@irs.gov](mailto:Desiree.D.Wright@irs.gov); Guttenberg Ronald C [Ronald.C.Guttenberg@irs.gov](mailto:Ronald.C.Guttenberg@irs.gov); Weeks Benjamin C [Benjamin.C.Weeks@irs.gov](mailto:Benjamin.C.Weeks@irs.gov); Stewart Alphonso [Alphonso.Stewart@irs.gov](mailto:Alphonso.Stewart@irs.gov); Brooks Patrice [Patrice.M.Gantt@irs.gov](mailto:Patrice.M.Gantt@irs.gov); Fletcher Jeff [Jeff.Fletcher@irs.gov](mailto:Jeff.Fletcher@irs.gov); Porter Anthony E [Anthony.E.Porter2@irs.gov](mailto:Anthony.E.Porter2@irs.gov); Flores Rivera Roberto [Roberto.FloresRivera@irs.gov](mailto:Roberto.FloresRivera@irs.gov); Irizarry Silva Efrain [Efrain.IrizarrySilva@irs.gov](mailto:Efrain.IrizarrySilva@irs.gov); Perez Ruiz Omar A [Omar.A.PerezRuiz@irs.gov](mailto:Omar.A.PerezRuiz@irs.gov); Rosa Apicella Carlos J [Carlos.J.RosaApicella@irs.gov](mailto:Carlos.J.RosaApicella@irs.gov); Medina Vargas Juan S [Juan.S.MedinaVargas@irs.gov](mailto:Juan.S.MedinaVargas@irs.gov); Hays Jaime C [Jaime.C.Hays@irs.gov](mailto:Jaime.C.Hays@irs.gov); Ahmed Imran [Imran.Ahmed@irs.gov](mailto:Imran.Ahmed@irs.gov); Tuitt Khanequa S [Khanequa.S.Tuitt@irs.gov](mailto:Khanequa.S.Tuitt@irs.gov)



Rizu

1b3nb

1B3NB







12:36 PM 9/8/2026

Create TrackSessions.UserEditor.Lookup-SEID.CLI.ps1 - that takes -SEID parameter and returns all information discoverable - copying and using logic in TrackSessions.UserEditor.ps1

&#x20;



# Reservation Mode - Sept 2026





how can I add a calendar and scheduled reservations for a given machine. I want to create a reservation entry in the shared path. Per machine per user per time slot.  We can allow only one day at a time.  So the filename of that JSON reservation (or it can be HTML) entry can hold required into and then use that to show calendar. Can filter on today or past events.
Cancelled events maybe would have the JSON / HTML file renamed?

So if HTML is used it could have a richer interface and render inside the TrackSessiosn (a new dialog) or even Edge or default browser.

So I already have logic that can create a local Event using Outlook legacy installed locally. That could be bound to a calendar and also email rest of team.

A recurring status would be good - also in the file name. The idea is that someone could just browse the shared path (but not make changes) and can see reservations right away.

So all files in Shared Path can now have the status somewhere in the file name. "RESERVED" or we already have ACTIVE or LOGGED OUT or DISCONNECTED.



Plan
C:\\Development\\scoop\\apps\\vscode\\1.132.0\\data\\user-data\\User\\workspaceStorage\\16510a99bf26fae74065628114e9b4ac\\GitHub.copilot-chat\\memory-tool\\memories\\N2U5NWFkYzEtYWQ2ZC00YmNjLTk5OWItOGI0NGFlMThmMTE5\\tracksessions\_exploration.md

10:10p
Append to TrackSessions.Reserve.Chat.md above verbatim chat with formatting. Preserve file changes.



Implement the PowerShell reservation module with CRUD functions and permission checks.





???
C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\BUGruops.BW.EnterpriseProxy.5-5-2025.ps1



12:20a thu 9-10-2026

i don't see anythng on my calendar where did the new Reservaton get created? it is supposed to be in Outlook Calendar and also entry in shared folder.  which will eventually be unc path.



C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\July 2025\\Sessions\\Reservations\\

Try creating a reservation again, and check:

Folder: C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\July 2025\\Sessions\\Reservations\\ (should have the .json file)
Outlook: Check your Calendar folder for event with subject \[RESERVED] {MachineName} - {UserName}
If it still doesn't appear in Outlook, it could be:

Outlook not running
Wrong calendar name (currently set to "Calendar" — verify this in your Outlook)
Outlook COM interface blocked/unavailable
Let me know what you find!



check iin
12:55a Thu 9-10-2026

Add IsAdmin field to user records and new user entry in TrackSessions.Users.json

* Added "IsAdmin" field to existing user records to indicate admin status.
* Introduced a new user entry for Richard Patterson with relevant details and IsAdmin set to false.



12:58 AM 9/11/2026
For User editor, always make SEID field upper case after entry and when reloading.



6:22 AM 9/11/2026

Error launching Reservations: Exception calling "ShowDialog" with 0 arguments. Cannot bind argument to parameter jsonPath because it is empty string.





6:40 AM 9/11/2026 checkin

Enhance TrackSessions functionality and user experience



\- Updated TrackSessions.Prompts.md with new reservation features and UI improvements.

\- Modified TrackSessions.Reservations.CalendarDialog.ps1 to improve date display and tooltip information for reservations.

\- Adjusted TrackSessions.Settings.json to include new machine configurations and logging details.

\- Enhanced TrackSessions.UserEditor functionality to ensure SEID is always stored and displayed in uppercase.

\- Added new user entries in TrackSessions.Users.json and created a backup file for user data.

\- Improved TrackSessions.Simulator CR1.ps1 to include a new reservation legend in the UI.

\- Documented changes and user requests in TrackSessions.UserEditor.Chat.md for better tracking of modifications.







**fix merged file from Rizu version to current Reservations**





3:20 AM 9/19/2026

3:20 AM 9/19/2026



Main window:

for status bar, use user Display name.

Same for User Display Name column - lookup from user list in JSON file ( that Manage Users... button edits).

For Machine name column - show short name and description when hovered.

When adding user the dialog locks up.





3:38 AM 9/19/2026

4:03 AM 9/19/2026

on main screen, User Display name should be looke dup from User ID.

So User ID is SEID below and Display name is FirstName plus LastName.

Then do sameon the Activity on Other Machines grid for the User Display Name column.

Sessions\\TrackSessions.Users.json

&#x20;       "SEID":  "YMJNB",

&#x20;       "FirstName":  "Davis",

&#x20;       "LastName":  "Lee",







4:14 AM 9/19/2026

enlarge vertically the Activity other machine grid to always show 4 rows and show header too - so adjust and increase height of whole app.





4:27 AM 9/19/2026

for disconnected add a similar blue pulsating dot to machine name - right side - as with existing green dot for logged in. for screentip show FQDN for machine name.





4:43 AM 9/19/2026

still now rows - check prior logic. the screentips and blue dot should not have affected filtering the blue dot should be rendered after filtering.  the logged out red not displaying so it looks like machine name screentip - that should not have affect rows being suppressed.











9:48 AM 9/19/2026 merge back to

Sessions\\TrackSessions.Simulator CR1.ps1



11:17 AM 9/19/2026 fixed rows

Sessions\\TrackSessions.Simulator CR1.ps1







\+▶️

7:58 AM 9/11/2026

Manage Users button main page should get for Admin mode people only.



Admin buttons \& controls have a dark Blue bold rectangle. Make that color a constant and tell me the RBG value.

Debug buttons \& controls have a dark Green bold rectangle. Make that color a constant and tell me the RBG value.



Main window should have status bar. current day of week, date time, time zone.

Current user and SEID.

Current Machine name.







11:33 AM 9/19/2026 claude code

app is sluggish on startup and refreshing grid. Tey to fix and also create TrackSessions.Performance.md or update with performance findings and suggestions or plan for improvement.











>>

Append to TrackSessions.Chat.md above verbatim chat with formatting. Preserve file changes.









### SessionUtils - 



11:48 AM 9/19/2026

Sessions\\SessionUtils\\CreateEmailEventAndTeamsChat.Prototype.ps1

claude

Create WPF PowerShell 5.1 to load or enter sample email address and sample calendar event.

Plus show that Outlook and Teams installed - with screen tip showing version and date install / release details.

For Email (make it Email tab)

Create an Outlook email with To, CC, BB, Subject and Body - using Outlook COM.

This not a mailto link.

For Event tab:

Show event date, time, Subject and body. Plus other settigns.

Then Create Event button should use Outlook COM to create that event - ready for use to click Send.

For Teams Tab:

Using same email address, open Teams chat window (if installed) ready for typing. if possible have a Message field in this WPF app that also pre-fills the new Teams window.



12:12 PM 9/19/2026 add

claude code  plan mode



Bottom should have shared controls above a status bar, Current user ID, user email address.

Status bar, should show Outlook and Teams install info.

&#x20;plus show current date time.

All controls should have screen tips.

Each of 3 create buttons should be docked to bottom of each tab (above the shared area).

There are odd wing-ding like Unicode like character before each tab name - why is that and how can I prevent?



For Teams tab how would I add a reference to a Group or Meeting or Channel chat such as

https://teams.microsoft.com/l/chat/19:1203fd26b4cf4b06a8b51ae2b82c4a38@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D

instead of an email address?



Add ideas to SessionUtils.Ideas.md





2:04 PM 9/19/2026

create event button on 2nd tab should dock to bottom of tab but above common area which is above status bar.





2:36 PM 9/19/2026



2:44 PM 9/19/2026 checkin

Add TrackSessions.Prompts.md for session tracking features and enhancements



\- Created a new markdown file to document prompts and requirements for the TrackSessions PowerShell application.

\- Included detailed specifications for tracking Windows sessions, user information, and JSON file management.

\- Documented UI enhancements, including layout adjustments for mobile responsiveness and compact mode.

\- Added features for user settings management, session notifications, and grid view improvements.

\- Specified requirements for admin functionalities, user editing, and reservation management.

\- Included notes on performance improvements and user experience enhancements.





2:37 PM 9/19/2026 

PLAN

Claude code

Sessions\\SessionUtils\\CreateEmailEventAndTeamsChat.Prototype.ps1

claude

Lay out a plan to send Windows notifications. add to 4th tab - or additional Notify tab.

HOw can I create sample notifications?

How does notification framework work?

How do multiple notifications work and from same app?

How about grouping and also silencing notifications?

Do notifications get lost?

How can I make a notification persist or customize the small UI in the lower right corner?

Is there a security model for Windows Notifications?

What if I am using more than one machine?

Explain all details about Windows notifications in Windows.Notify.Explain.md.



Notifications not seen.

1:10 AM 9/20/2026

no notifications are sent - can a diagnostic log window help - a Log dialog with Log button in the common space ablove status bar? the log dialog should have Copy, Clear and Close.  Plus - + zoom buttons for font size and show current font size.  Plus all controls should have screen tips.







Notifications

11:26 PM 9/19/2026

How to view Action Center?

Only for current user?





checkin

1:37 AM 9/20/2026

feat: Enhance Outlook Email Lookup Documentation and UI Improvements



\- Added comprehensive documentation on how Outlook and external applications look up email addresses and user profiles, detailing search methods, underscore usage, and external app integration.

\- Implemented UI enhancements in TrackSessions, including:

&#x20; - Moved simulation controls to the right side of the row and adjusted layout for better usability.

&#x20; - Updated legend boxes with bolder borders and darker colors for improved visibility.

&#x20; - Applied bold text styling to all buttons, including Zoom and Settings dialogs.

&#x20; - Enhanced calendar UI with larger, bolder day numbers, light purple backgrounds, and display names under each date.

&#x20; - Fixed compile errors and added display name lookup functionality via SEID.

&#x20; - Improved grid layout to ensure visibility of all session data and added timestamp with timezone.

&#x20; - Introduced diagnostic logging for troubleshooting notification issues, including a log dialog with copy, clear, and zoom functionalities.









>>

Append to TrackSessions.Chat.md above verbatim chat with formatting. Preserve file changes.



Append to TrackSessions.Chat.md above verbatim chat with formatting. Preserve file changes. Note that Claude Code made changes.



This file

TrackSessions.Prompts.md



Notifications above.







### Email, Event, Teams Plan



7:09 PM 9/19/2026



This file

TrackSessions.Prompts.md



▶️▶️▶️

Settings for Notification

Assume Outlook and Teams installed

**User List**

Columns - New

Checkboxes - Guest User

Checkboxes - Email Notify, Event Notify, Teams Notify.



**Group List**

Columns

Name, Group Email (Distribution or Teams), Teams link

Email Distribution List, Event DL, Teams email URL





Use this for Email templates

Sessions\\SessionUtils\\CreateEmailEventAndTeamsChat.Prototype.ps1







PLAN 

claude code

8:01 PM 9/19/2026 SAT


Questions

8:02 PM 9/19/2026

Outlook.DistributionLists.Explain.md

Do outlook distribution lists work same in both Email and Events?

We have legacy Outlook on Windows 11.

Break down all group email and event options and also if the same distribution lists can be used in Teams.

What about return email - how an I capture or detect if a Distribution list is outdated?

So we have \& ampersand - prefixed and also Asterisk prefixed Distribution lists or groups. Is that a common naming convention?

What is a common naming convention?





9:56 PM 9/19/2026 mbr

claude code

crreate v2 of this markdown that has headers and subheaders like 1 2 and 3 levels that can work as pdf headings and bookmarks . then after each heading put a Top intralink that jumps to top.then add glossary bottom.  at top put executive summary.





10:42 PM 9/19/2026

Sessions\\SessionUtils\\Outlook.DistributionLists.Explain.v2.md

and pdf generated





11:51 PM 9/19/2026 check in

Add documentation for session tracking features in TrackSessions.Prompts.md



\- Created a new markdown file to outline prompts and requirements for the TrackSessions PowerShell application.

\- Included specifications for tracking Windows sessions, user information, and JSON file management.

\- Documented UI enhancements for mobile responsiveness and compact mode.

\- Added features for user settings management, session notifications, and grid view improvements.

\- Specified requirements for admin functionalities, user editing, and reservation management.

\- Included notes on performance improvements and user experience enhancements.







3:02 AM 9/20/2026

claude code

PLAN

the app is slow or blocks UI on startup and upon first refresh.

Also tell me what modules or cmdlets or functions handle settings, users and reservations - put that into TrackSessions.Modules.md





7:54 AM 9/20/2026 sun test runs

it is faster except the filtering or similar made all the rows disappear - ther was one logged out row and two disconnected rows.  Can you do a careful compare and see what changed?





8:09 AM 9/20/2026

yes session path correct \\\\Vp0wxsqm365as02\\SPS\\PAWS-Sessions\\TestSimulate

FIles are there, it was just working. something changed in the filter



The main grid is broken.



there is error in terminal when Log... button clicked and Log dialog won't open, but that wasn't seen or checked before.



TrackSessions.Simulator CR1.ps1'

C:\\Users\\YMJNB\\OneDrive - Internal Revenue 

Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\July 

2025\\Sessions\\TrackSessions.Simulator CR1.ps1 : Exception calling 

"ShowDialog" with "0" argument(s): "The property 'Padding' cannot 

be found on this object. Verify that the property exists and can 

be set."

At line:1 char:1

\+ . 'C:\\Users\\YMJNB\\OneDrive - Internal Revenue 

Service\\Documents\\Power ...

\+ \~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~

\~\~\~\~

&#x20;   + CategoryInfo          : NotSpecified: (:) \[TrackSessions.Sim 

&#x20;  ulator CR1.ps1], MethodInvocationException

&#x20;   + FullyQualifiedErrorId : RuntimeException,TrackSessions.Simul 

&#x20;  ator CR1.ps1

The main grid is broken.





8:22 AM 9/20/2026 still broken

main grid broken, don't add more code - check what changed it was working fine. check filter at leat get a countof shared folder.



8:25 AM 9/20/2026

no rows seen - it is simple fetch JSON and filter using original rules. make minimal changes but track any new changes.



no rows seen

Compare against "TrackSessions.Simulator CR1,roewsShoeLive.ps1" rows are working. - shows one machine disconnected and two machines logged out.  Itis always most recent entries and one per machine.

It is straightforward.



8:46 AM 9/20/2026 check again.

WORKS again





8:50 AM 9/20/2026 claude 

wonderful it works - can you summary in great detail into TrackSessions.RowFilterBroke.Ideas.md, what caused the problem and recommendations. I can start using more PowerShell modules to make code manageable. I may want to add more filtering states such as per Machine name, per user. per day, per week. and you can see I have reservation logic.  make suggestions on how this can be refined and not break any more.  I also want to add the green icon into bhe blue disconnected state.

SO do not make any PowerShell changes. Only create **TrackSessions.RowFilterBroke.Ideas.m**d







8:54 AM 9/20/2026

Append to TrackSessions.Chat.md above verbatim chat with formatting. Preserve file changes. Note that Claude Code made changes.



9:36 AM 9/20/2026 checkin

Refactor code structure for improved readability and maintainability





9:48 AM 9/20/2026 

claude.

Settings... button locks up or not clickable.







Make top part and entire app window taller - to make sure at least 4 rows visible plus header row makes 5 visible.

status bar should have Display Name where "User:" label is.

Add screentips to all controls - or verify.

Change "Manage Users..." button to "Users..."

Change "Reservations..." button to "Reserve..."

"Users..." button has Admin mode. make that global so we can use it other places. This is per session and per user.





9:49 AM 9/20/2026

claude

PLAN

I want to add new columns to User List. NEmail, NEvent, NTeams







>>

Append to TrackSessions.Chat.md above verbatim chat with formatting. Preserve file changes.



8:54 AM 9/20/2026

Append to TrackSessions.Chat.md above verbatim chat with formatting. Preserve file changes. Note that Claude Code made changes.





# Merge released earlier version Wed 9-16-2026

# Fri 9-18-2026 merge

# changes between

# Sessions\\PAWS-Candidates\\TrackSessions.Simulator CR1.PreReserve.2026-09-07.ps1

# and

# Sessions\\PAWS-Candidates\\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1



This file

TrackSessions.Prompts.md





12:32a
Compare changes between
Sessions\\PAWS-Candidates\\TrackSessions.Simulator CR1.PreReserve.2026-09-07.ps1
and
Sessions\\PAWS-Candidates\\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1
Show what is different first - by summarizing to
Sessions\\PAWS-Candidates\\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.Diff.md
The markdown should be merge-ready -it should used to merge into a later version of TrackSessions. Don't merge anything yet.



12:44a Fri 9-18-2026
Using
Sessions\\PAWS-Candidates\\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.Diff.md
merge changes into
Sessions\\TrackSessions.Simulator CR1.merge.ps1
and try to validate against
Sessions\\PAWS-Candidates\\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1



merge done 1:06a

the Session grid should show only the latest entry for each machine and user combination. Only one entry.



Then ask to proceed.



**Analyze Settings and File Writes**



WED 8:05 AM 9/16/2026

..

In new Sessions\\TrackSessions.Simulator.CR1.Settings.Explain.md

Explain how the settings currently work.

I want a shared copy of users - which include who is administrator. Plus a list of machine names to Track usage.

Then the share UNC path has various entries for each event such as login, logout, disconnect.



So one key issue is what happens when UNC is not set but I want users (all pre-defined) and machine names (also all pre-defined).



Plus there are possible other shared settings and local user level settings.













Sessions\\TrackSessions.Simulator.CR1.ps1



##### **++Next**





Sessions\\TrackSessions.Simulator.CR1.ps1





Admin buttons \& controls have a dark Blue bold rectangle. Make that color a constant and tell me the RBG value.

Debug buttons \& controls have a dark Green bold rectangle. Make that color a constant and tell me the RBG value.



Main window should have status bar. current day of week, date time, time zone.

Current user and SEID.

Current Machine name.









Session Track Home:

top six lines should be reduce.

User Display name should use User Name - referenced by User ID (characters after \\)

Then User ID should be in parenthesis after User Display Name.

Current JSON File should just have JSON Output Folder part highlighted bold. Then teh JSON Output Folder (default) entry is not needed.

Last Update (GMT) should be in status bar with 3-character day of week and Time Zone.



Settings... and Manage Users... button should be Admin level and show color noted above - Blue Bold rectangle and use the constant defined.

Simulation should also be Admin - make text and checkbox Blue color and text bold.



Refresh Now button should just be Refresh

Zoom buttons should be before and to left of Legend - on same line.



Status bar should have Last Update time and second elapsed in parentheses.













>>

Append to TrackSessions.Chat.md above verbatim chat with formatting. Preserve file changes.





### Architect



5:09 AM 9/11/2026

write a detailed TrackSessions.Architect.md to explain and use Mermaid diagrams how the whole app works. list all powershell modules, scripts and settings including JSON files. Detail when each JSON is update by which PowerShell script and also function. Plus sequence diagrams for seeing state of each user and machine. how reservations work.







# ToDo

Calendar Create not there. Trace?
Disable Schedule button for now.



>>

Sessions\\TrackSessions.UserEditor.Chat.md

Append to TrackSessions.UserEditor.Chat.md above verbatim chat with formatting. Preserve file changes.







### **Enhancements**





FRI 8:36 AM 7/24/2026

Make it dockable and gridview responsive.

top 5 rows of gridview should be visible at all times.

Last update move to below Machine name. and show readable time. weekday date, time, seconds, time zone.

Countdown to next update in seconds to right of zoom buttons.

