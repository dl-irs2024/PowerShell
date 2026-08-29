Viewers\\WpfJpegViewer.Prompts.md





C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\Viewers\\





2:05 PM 8/16/2026

create a PowerShell 5.1 WPF jpeg file view that can handle .jpg and .jpeg image files. there should be a command line mode that can view one file - then iterate to next / previous file. That commmand line can be invoked with -CommandLine with -ImageFile as image parameter.
The viewwer should should current files on left, and allow drag and drop from Windows File Explorer. The Viewer should appear on right with default fit to pane.  There should be a vertical splitter.  The viewer should have Fit, Fit Width and Fit Heigh buttons as well as zoon in and out. Mouse wheel should zoon in and out.
All properties of the JPEG file should appear in a grid below.  The actual comment should be in a text box.  Any URLs in the commments should be appended to the properties grid and be clickable.
The viewer should have Previous and Next chevrons that show when mouse hovers - and iterates through all files in left files view.
The status bar should show number of files loaded, total size, current path, disk space free.

729 lines initial



3:00 PM 8/16/2026 Jpeg Viewer.

to right of JPEG Properites should be a Copy button. Copy with Combobox: Text, PSObject format, CSV, TSV Tab separated.
All screen controls should have screen tips.
The Chevrons look like some foreign character. use animated icons that pulsate.
The JPEG Comment at bottom should have Copy button and screen tip copy as text to clipboard.
there be a WpfJpegViewer.Prompts.Settings.json created or updated that has window position and size and other settings, including last files loaded.
When image first loaded - there should be a Fit operation that makes it visible.
Allow mouse left button click to move image as well.

1046 lines....



3:32 PM 8/16/2026
add a tiny Reset View button next (reset zoom to fit + scroll offsets to top-left) for quick recovery after heavy panning/zooming.

to right of Add Folder - add a Clear button with screen tip - clear files. The Fit (defualt) view should always show top edge of image and/or left edge of image.  Fit Width should show top edge abutting top of viewing areas. Fit height should do the same.
There should be a colorful JPEG logo splash screen for few seconds and a clickable link(s) to JPEG spec, comment spec and maybe Windows implementations.
The app should have an about buttom lower left that shows same splash screen. The About page should have a button - Append temporary test JPEG URL to Comment and update the Properties list.
In properties, after File name row - there should be at least one URL property and indicate None if no URLs.

3:50 PM 8/16/2026
the splash screen should stay at least 5 seconds unless mouse button clicked within.
The File list should have a new narrow column that has a yellow dog-eared document icon -only if there is a JPEG comment.  that same icon should appear to left of JPEG Comment at bottom.
The URL rows should be highlighted light blue.
The image still appears off screen. the top edge of image should always abut the top edge of the image viewing area (upon loading)









3:16 PM 8/26/2026 2271 lines

Add a pastel green Paste button next to two Add buttons on upper left. This should show a dialog that allows Paste image from clipboard, then assign JPEG default properties and textbox for the JPEG comment. Then Save or Cancel buttons (following app pastel colors).

Save button should present standard Windows Save As dialog with default .jpg format (and .jpeg). Save should invoke the Comment embedding logic in the Edit dialog from home app screen.



3:27 PM 8/26/2026

The new Paste dialog already has current clipboard. The Save says there is no image.  The only case if no image is if clipboard is empty or a non-image format.

⏭️

Added comments and email to Rick
9:32 PM 8/28/2026



**Sample Microsoft Graph JPEG - PROMPT**



create a wire frame diagram black and white JPEG with subtle hints of darker cold colors showing Microsoft Graph and all the interfaces and products.  We are GCC Standard.
The diagram should show how authentication works and how an app may need to be registered or multiple ways this can happen. It should show the purpose of Microsoft Graph and other layers such as Graph Connector and related layers like PowerShell modules. It can be a big diagram.  Also put this prompt inside as a JPEG Comment.





++



10:01 PM 8/26/2026

In Paste dialog - after entering comment and clicking Save - the image saves, but there's no comment. I get this error and Paste dialog stays open

\---------------------------

Save JPEG Error

\---------------------------

Failed to save JPEG: Exception calling "FromFile" with "1" argument(s): "Out of memory."

\---------------------------

OK

\---------------------------



works....





10:20 PM 8/26/2026

For Paste dialog, once Save button click and successful, dialog can be closed. Else dialog should remain open.



The Loaded JPEG Files grid should include H column for Height of JPEG graphic and W column for Width. Plus add a DPI column.



The Loaded JPEG Files grid should become a card mode that shows all info in a card format. This make the grid a responsive (RWD) grid.





10:24 PM 8/26/2026

The new cards in Loaded JPEG files look great. They should wrap around and not be truncated.

When the grid becomes wider than 1.5 card width - the columns should show again. the colors for W H and DPI should be reused for the Column colors in tabular (not card view).



10:57 PM 8/26/2026

\- Cards currently use fixed width (`286`) for consistent readability. I can make width adapt to panel size if you want a denser fluid layout.  Cards should warp and not be cut off. change to Grid / tabular view when width of Loaded JPEG files grid is wider than 1.5 cards.





11:06 PM 8/26/2026

&#x20;tune the threshold from 1.5 to 1.4 or 1.6 so switching feels more natural with your splitter behavior.





11:11 PM 8/26/2026

The original grid had headers and sizeable columns.  also clicking head to sort would be nice.



11:22 PM 8/26/2026

The small modeless JPEG Viewer dialog should have date and time - readable format with day of week as a small status bar.  Size of current JPEG. Zoom should be on new line.

Should use same comment icon to indicate if there is a comment plus show length of comment.

If resources allow, show a small thumbnail of the JPEG image in upper right of dialog.

Plus add a small pulsating Target icon at lower right.







11:45 PM 8/26/2026 2965 lines

The popup Viewer Dialog (modeless) looks great.

The pulsating should be brighter colors into pulse into other bright colors in spectrum since background is black.

The dialog should be taller.

A new button or icon under Image / View Metrics label at top should make dialog jump to other screen (show Jump graphic) and also Minimize graphic alongside.







12:00 AM 8/27/2026

the JPEG Viewer dialog should have a different icon like a Red Target.  The pulsating lower right graphic is still too hard to see. make  the background contrast as it pulsates.  The height should be like 75% taller on startup.  All dialogs should have their size and location persisted in the WpfJpegViewer.Settings.json file.





12:24 AM 8/27/2026

the rainbow target animation lower right is stlll not visbile. use bright colors only and put a rainbow small square bounding box that also has bright gradient colors for the box border. make border 4 pixels thick.





claude

5:07 AM 8/27/2026

pwsh



done

compare

WpfJpegViewer.BrokenStartup.PasteDialog.BROKEN.ps1

WpfJpegViewer.NoPaste.DEMO.ps1

the startup is broken the Demo.ps1 works and the Broken.ps1 shows the modeless dialogs and the splash dialog but no main app.

Create a new WpfJpegViewer.Paste.FIXSTART.ps1 version that tries to fix it plus a WpfJpegViewer.Paste.FIXSTART.md that has ongoing notes, plans to fix, approaches, results.





11:58 PM 8/28/2026 claude

the graphic area is not scaling properly - with I click Fit Width - it is like 30% of the graphics pane - it is some DPI to screen DPI issue?





12:13 AM 8/29/2026 claude

In the image pane right - the mouse doesn't move image left and right - only up and down. the scrolls bars are not working right.

Add JFIF extension support.

In Loaded JPEG files, the cards don't wrap.

In left Grid view (and card view) - show any heights and widths that match standard XGA, VGA etc.







12:33 AM 8/29/2026 claude

The app blows up when I open the modeless debug window from the About dialog.



JPEG Properties label - should have total properties after - and refresh if properties change.

Green Copy Image button should move up and be to right of Copy Properties.







6:56 AM 8/29/2026 SAT

claude

The graphic area scrolling good. but the right edge gets clipped and bottom edge - as if some mask or metric off. 



In main app and also Edit mode at bottom, the JPEG Comment - should show length of comment after the label - and refresh if the length changes.  During Edit mode, the length should change as user types or cuts or pastes text in.





7:29 AM 8/29/2026 claude

the app still blows up after I start, then choose About then click Debug.

The Debug window shows for like 7 seconds then app disappears.



The lower right Debug floating window should have a more animated rainbow of colors. maybe increase frame rate and color breadth.



The Fit area looks great but when I zoom out the right and bottom edges of graphic getting clipped.







8:09 AM 8/29/2026 claude

same thing when opening About dialog then modeless debug, the app blows up. the app (all 3 windows) disappear.



About dialog

About dialog show the standard screen acronyms and their height and width dimensions.

About dialog should have a Info scrolling text box that explains DPI, DIP and other pixel / density. Explains JFIF plus aspect ratios.





start button issues. PowerShell launch stacks up in call stack.

restart VS Code.



8:37 AM 8/29/2026

about dialog.

the animated graphic is just covered up with new text control. restore to original then add "downward chevron" to expand dialog that shows the new text box. the Chevron should become a collapse button.



The modeless debug dialog still disappears after awhile. it was working before.

Can you append and show a detailed summary in WpfJpegViewer.Chat.md as to how all the events work - in each dialog and main screen. and what could cause app to lock up or crash?

Is the animated lower right colorful graph in Debug dialog causing issues?





8:59 AM 8/29/2026

card view should be responsive and cards should wrap inside the left pane and never be obscured.



Click about now gets this error.

\---------------------------

WpfJpegViewer Fatal Error

\---------------------------

Main window run failed: Exception calling "Load" with "1" argument(s): "Cannot set unknown member 'System.Windows.Shapes.Path.StrokeLineCap'."



at Show-AboutDialog, C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\Viewers\\WpfJpegViewer.Paste.FIXSTART.ps1: line 1213

at <ScriptBlock>, C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\Viewers\\WpfJpegViewer.Paste.FIXSTART.ps1: line 3636

at <ScriptBlock>, C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\Viewers\\WpfJpegViewer.Paste.FIXSTART.ps1: line 3806

at <ScriptBlock>, <No file>: line 1

\---------------------------

OK   

\---------------------------







9:11 AM 8/29/2026

card view should be responsive and cards should wrap inside the left pane and never be obscured.



Click about now gets this error.

\---------------------------

WpfJpegViewer Fatal Error

\---------------------------

Main window run failed: Exception calling "Load" with "1" argument(s): "Cannot set unknown member 'System.Windows.Shapes.Path.StrokeLineCap'."



at Show-AboutDialog, \\WPF PowerShell NC\\Viewers\\WpfJpegViewer.Paste.FIXSTART.ps1: line 1213

at <ScriptBlock>, \\WPF PowerShell NC\\Viewers\\WpfJpegViewer.Paste.FIXSTART.ps1: line 3636

at <ScriptBlock>, \\WPF PowerShell NC\\Viewers\\WpfJpegViewer.Paste.FIXSTART.ps1: line 3806

at <ScriptBlock>, <No file>: line 1

\---------------------------

OK

\---------------------------





9:11 AM 8/29/2026

cards still don't wrap - use the width of left pane.  card view should not have any scroll bars. but grid view of left pane should.

The about dialog doesn't have the animation like before. 

There should be a "down chevon" to vertically epand the dialog to show the rich text explanation. and then allow collapse.



9:33 AM 8/29/2026

cards should all be same width and anything long like filename should wrap within the card. 

The whole window position and size is not persisted.





compacting



9:49 AM 8/29/2026 claude

there is about dialog XAML on new odd right pane.

The prior version was correct.





9:57 AM 8/29/2026 claude not change



10:19 AM 8/29/2026 try GitHub Copilot

the vertical splitter should split 50% when double clicked, then double-click again to 25% then double-click back to original split position.



The About dialog still doesn't have original graphic. The explanatory text should not be displayed but use a Down chevron to expand dialog by 50% or more. then allow collapse.

The Display Technology Reference should be combined with the expanded rich text below....and not show by default.



When main window Maximize is clicked the maximized window should show JPEG comments to fill space above.  Close button should read Close Maximized.











\+





▶️



**NEXT (9:53 PM 8/28/2026 Fri)**




(1:09 PM 8/29/2026)

Debug still blows up after few second - Claude and GitHub Copilot tries to fix.





/

Fit buttons: Fit, Fit Width , Fit Height and R buttons are not fitting to the actual image pane width.
Fit doesn't work - Fit Width, Fit Height.

Missing scroll bars.

It looks like the viewport or coordinate space is off.

It seems the perceived width is less than actual screen width.

Maybe some graphic DPI (or DIP) to screen DPI (or DIP) calculation is needed.















**@@@ Refactor**

The startup is slow - it seemed reasonable like a week ago before the Paste dialog and other enhancements.





\+

also make Save prefill the dialog filename from the first line of the comment (sanitized) instead of timestamp naming.





++?

the top edge of image should always show when file clicked.
The About Folder locks up the app.
The Prev Next should be a new control group that aligns with the image viewer (same width.  Then create another control group for 3 buttons: Add Files, Add Folder and Clear.



If the image still appears shifted for a specific file, send me that file’s dimensions/orientation metadata case and I’ll add an EXIF orientation normalization pass during load.





?? does Github strip JPEG comments?





C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\WPF PowerShell NC\\Viewers\\WpfJpegViewer.Prompts.md







>>

12:42 AM 8/27/2026

11:17 PM 8/26/2026

append above chat to WpfJpegViewer.Chat.md along with line number count of WpfJpegViewer.ps1





10:18 AM 8/29/2026

8:20 AM 8/29/2026

12:29 AM 8/29/2026

append above chat to WpfJpegViewer.Chat.md along with line number count of Viewers\\WpfJpegViewer.Paste.FIXSTART.ps1 - note that **Claude Code** made changes.





