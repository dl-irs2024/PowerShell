12:41 AM 8/24/2026 csv editor demo for Tuesday?

write a new CSV editor using PowwerShell 5.1 and WPF.  Allow drag and drop into grid, show last update, file size and also number of rows and number of columns.
Then allow a preview of each CSV by clicking.
The preview should appear on right. and allow zooming with + and - zoom buttons.
All columns should have a checkbox that freezes the column by sliding it to left.
then there should be Open in New Window that shows a new window that allow inline editing plus a Save and Revert Button. Plus Open in Excel button. The new window should have same checkboxes in each column header for freeze columns.



124a
same error "the property DefaultView cannot be found on the object" when I click on a row.
Also all controls and New Window should have screen tips. the dropped or added files on left should be persisted - as should all zoom views.

139a
edited cells shoudl have purple color. then the Revert button is enabled. Close should Confirm Save or Revert changes. Multiple New Windows should be allowed. Show memory usage for PowerShell in New Window status bar at bottom plus rowa, columns and size of CSV file.



804 lines



157a
add a banding setting - global to main preview and all open New Windows.
Banding check box should alternate row colors.  The file name should be clear at top of each New Window - in bold.



still errors 211a
982 lines



7:53 AM 8/24/2026

add total files loaded in status bar. Plus free PowerShell memory. to left of zoom buttons add Run PowerShell, and Copy CSV Names  Run PowerShell should export each selected CSV to HTML and open in Edge and Copy CSV Names should copy selected CSV names to clipboard with full path, double quotes and commas.





Monday

11:34 PM 8/24/2026 1266 lines plus XAML included

12:09 AM 8/25/2026

rows over 100 or columns over 20 should show red in left grid.

added a static, always docked Rows column to left and top should have always docked Column letter like Excel - starting with A - above existing labels.

both rows column and column letter row at top should be a motif called GridHeaders and set to light purple.

For New Window - the horizontal scroll bar is obscured or missing.  the same docked Rows column at left and docked Column lettered row/ header at top should be there - above existing labels.

The New Window and Main should indicate if "Excel Installed" with Yes or No and screen tip should show version and location of Excel executable.



12:15 AM 8/25/2026

Excel Installed on main app should be in status bar, not at top.

New Window zoom Plus mis-behaves, it changes the current value to lower, but should just increment - similar to main page. the New Window status bar has Incorrect Excel Installed.



\---------------------------

Unhandled UI Error

\---------------------------

An unexpected UI error occurred. Details were written to:

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.crash.log



The variable '$statusTimer' cannot be retrieved because it has not been set.

\---------------------------

OK

\---------------------------





12:36 AM 8/25/2026 1544 lines





12:40 AM 8/25/2026

the column freezing stopped work on both main and New Wndow. the horizont scroll bar stopped working

The left files grid should be back to normal it does not need extra Column A B C and the rows should return to left of column number column





12:43 AM 8/25/2026

when I click on a row in upper left files view, nothing happens in the CSV preview - it was working great before the A B C column headers were added. How can I prevent this in the future?





12:47 AM 8/25/2026

in New Window all works great except the horizontal scroll bar does not adjust to width of non docked columns horizontal scroll bar works great in main app on the right preview. Else all looks great. only focus on the New Window horizontal scroll bar.



I also see this when I close New Window.







1:02 AM 8/25/2026

works great - when I revert a changed cell that correctly turns purple - i  get this error



\---------------------------

Unhandled UI Error

\---------------------------

An unexpected UI error occurred. Details were written to:

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.crash.log



Exception setting "FontSize": "'0' is not a valid value for property 'FontSize'."

\---------------------------

OK

\---------------------------





1:05 AM 8/25/2026

when I click different rows, there should be a wait cursor. until the new CSV is loaded.

when i Uncheck Bands in main or New - there should be no bands at all.





1:09 AM 8/25/2026

The wait cursor is too short when I click difffernt CSV files on left.

The Revert shows fonts too small - should be 100% when I Revert.



When I close the New Window I still get



\---------------------------

Unhandled UI Error

\---------------------------

An unexpected UI error occurred. Details were written to:

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.crash.log



You cannot call a method on a null-valued expression.

\---------------------------

OK

\---------------------------





8:25 AM 8/25/2026 TUE

still get

\---------------------------

Unhandled UI Error

\---------------------------

An unexpected UI error occurred. Details were written to:

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.crash.log



You cannot call a method on a null-valued expression.

\---------------------------

OK

\---------------------------



when closing New Window





Closing New Window

\---------------------------

Unhandled UI Error

\---------------------------

An unexpected UI error occurred. Details were written to:

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.crash.log



You cannot call a method on a null-valued expression.

\---------------------------

OK

\---------------------------





1:13 PM 8/25/2026 GitHub Copilot.

Revert should have wait cursor.

In New Window with Inline Editing - File at upper left should be INLINE EDIT File and bold and larger font for visibility.

Then to left of Save - there should be a count of cells changed (cells that are purple).





1:17 PM 8/25/2026 still see error below after Claude Code fixed.



1:46 PM 8/25/2026

**claude made changes**

still see

\---------------------------

Unhandled UI Error

\---------------------------

An unexpected UI error occurred. Details were written to:

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.crash.log



You cannot call a method on a null-valued expression.

\---------------------------

OK

\---------------------------





\---------------------------

Unhandled UI Error

\---------------------------

An unexpected UI error occurred. Details were written to:

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.crash.log



You cannot call a method on a null-valued expression.

\---------------------------

OK

\---------------------------







\+

\---------------------------

Unhandled UI Error

\---------------------------

An unexpected UI error occurred. Details were written to:

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.crash.log



Cannot bind argument to parameter 'Settings' because it is null.

\---------------------------

OK

\---------------------------



\---------------------------

Unhandled UI Error

\---------------------------

An unexpected UI error occurred. Details were written to:

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.crash.log



Cannot bind argument to parameter 'Settings' because it is null.

\---------------------------

OK

\---------------------------





2:35 PM 8/25/2026 Claude

CSV\\SampleCsvEditor.ps1

To left of Banding check box on Main app only, add a Chart checkbox- when checked a combobox shows: Pie, Pie Explored, Bar, Stacked Bar, Line, Scatter, then allow a 2D selection in the right pane.

Also make the vertical bar between left file and right preview a vertical splitter.





3:03 PM 8/25/2026

2169 lines





2:48 PM 8/25/2026



3:19 PM 8/25/2026

the New Windows Inline Editor no longer displays a wait cursor displays.





**Plan**

6:51 AM 8/26/2026 Plan

what ideas are there for improving performance of loadig the CSV files? Can the rows be paged - or just limit rows on initial viewing?



append above changes to SampleCsvEditor.Plan.md and also the part where the initial performance issues were found such as the DataTable usage.



C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.ps1

now 2301 lines.



7:38 AM 8/26/2026 testing





⏭️





7:59 AM 8/26/2026 GitHub Copilot

Columns on left not displaying count.



The Chart checkbox should enable and disable 2D selection mode. When unchecked, there should be row selection mode.

Then after a 2D selection, the Combobox should enable.

when a Choice is made the popup modal chart window displays.

After the window is closed. the 2D selection should remain and user can choose another choice in combo box.



Main window missing Add Files dialog when I can add one or more CSV files from a selection - this should be standard dialog.





8:06 AM 8/26/2026

8:08 AM 8/26/2026 



App window should never be clipped. should restore previous size and location.



Add color pastel color scheme to buttons and dark borders like 4 point. Pastel Blue for zoom and edit and load. Pastel Green for zoom. pastel red for cancel, save, revert.





For Chart on main app.

Added vertical and horizontal legends.

Add colored legend like a typical chart.

Create in Excel should have a wait cursor.

the Pie charts and Exploded Pie chart don't look like pie charts.

the 2D rectangle should persist when the combo box changes - and if a 2D selection is already there, a combo box change should produce a new modal window.





Lost prompt

C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV\\SampleCsvEditor.ps1



cd "C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\CSV"







The New Window is missing the Banding setting that is global. There should be a Banding checkbox at the top.

Only one New Window should open per file.







\+



\+

Allow casual browsing of folder and show CSV info.

Support TSV - tab separated in future.

\+

The entire app and New Windows should be larger by 30% - start with fonts - make then about 3 points larger.







# Claude Code

Claude-code and Claude dependency

Claude not installed right and won't reinstall. 11:54 PM 8/24/2026

Then GitHub Copilot

create various sample CSV files in sub-folder of current CSV folder. Call sub-folder Sample-CSV.  Create CSV files of varying rows and varius columns, such as address data, product tracking data, time billing, population data. create as man as a couple dozen to couple hundred rows.





Claude Code

Error: Subprocess initialization did not complete within 60000ms — check authentication and network connectivity
View output logs · Troubleshooting resources





>>

1:17 PM 8/25/2026 TUE

12:49 AM 8/25/2026

12:33 AM 8/25/2026

11:55 PM 8/24/2026 MON

2:11A MON
141a Mon
114a
append above chat and changes and summary using markdown formatting and emojis to CSV\\SampleCsvEditor.Chats.md.  include total lines of all PowerShell files, and XAML.







##### Claude Code version



2:58 PM 8/25/2026

1:43 PM 8/25/2026

append above chat and changes and summary using markdown formatting and emojis to CSV\\SampleCsvEditor.Claude.Chats.md.  include total lines of all PowerShell files, and XAML. But not files with "Copy" towards end, those are backup copies.

