Sessions\\CR3\\TrackSessions.CR3.Prompts.md



8:38 PM 9/23/2026 CR2 refactor failed, waste of time.



C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\July 2025\\Sessions\\CR3\\TrackSessions.CR3.Prompts.md









7:17 PM 9/23/2026

CR3

write detailed Sessions\\CR3\\TrackSessions.CR3.Main.Refactor.md on how to make code changes faster without using PowerShell modules. As that broke the event model on CR2.  How about PowerShell Regions and extracting XAML for starters. That should be safe.





8:38 PM 9/23/2026 checkin CR3

Add initial markdown prompts and settings configuration for TrackSessions



\- Created TrackSessions.CR3.Prompts.md to outline refactoring ideas for faster code changes without PowerShell modules.

\- Introduced TrackSessions.Settings.json to define application layout, tracking machines, and startup trace events.







9:10 PM 9/23/2026

Using ideas from Sessions\\CR3\\TrackSessions.CR3.Main.Refactor.md

Refactor out the XAML files and make sure they are clearly named and top of each XAML file should have comments that explain where the XAML is used and events wired in. If possible, list the PowerShell functions or cmdlets that uses this XAML.



9:11 PM 9/23/2026

Where is the Setting path stored?

and this PowerShell was used before to edit users. Can it be used again?

Sessions\\CR3\\TrackSessions.UserEditor.ps1





10:33 PM 9/23/2026

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\July 2025\\Sessions\\CR3\\TrackSessions.CR3.Main.ps1

10:06 PM 9/23/2026

just above \[CmdletBinding()] line 27 - add comment block that explains all the functions, which ones are event driven to support XAML. the starting line of each function plus any other oddities like C# or HTML injection.





10:33 PM 9/23/2026

using Sessions\\TrackSessions.RowFilterBroke.Ideas.md fix the filter logic. nothing shows.



11:28 PM 9/23/2026

nothng is seen - there should be at least 3 entries, there are 3 machines in the UNC.



Plus make the grid show at least 4 forw plus header row. increase height of app if necessary.





1:17 PM 9/24/2026

in settings add a debug control group that includse Show all Sessions and show the actual filter in the Log output - as it changes. and when the refreshes occur. 





3:44 PM 9/24/2026

append above chat verbatim and formatted to

Sessions\\CR3\\TrackSessions.CR3.Chat.md









>>

9:29 PM 9/23/2026

append above chat verbatim and formatted to

Sessions\\CR3\\TrackSessions.CR3.Chat.md





\\\\Vp0wxsqm365as02\\SPS\\PAWS-Sessions\\TestSimulate

\\\\Vp0wxsqm365as02\\SPS\\PAWS-Sessions



Sessions\\CR2\\TrackSessions.Refactor.0923.Ideas.md

**Sessions\\CR2\\TrackSessions.Refactor.0923.Results.md**



🔮

Sessions\\TrackSessions.RowFilterBroke.Ideas.md



Sessions\\CR3\\TrackSessions.CR3.Prompts.md





