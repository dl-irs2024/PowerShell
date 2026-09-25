C:\\Users\\YMJNB\\OneDrive - Internal Revenue Service\\Documents\\PowerShell 2025\\PowerShell v5.1\\July 2025\\Sessions\\SessionUtils\\SessionUtils.Prompts.md

SessionUtils\\SessionUtils.Prompts.md



7:07 AM 9/12/2026
write a PowerShell 5.1 WPF utility.

that accepts a dropped list of files names - from an Outlook legacy email message. Or the same pasted string.

Then uses Outlook COM or similar - to look up each email address as an object. and put in a list box.

Each email address object or user profile should have the same info visible in Outlook.

Verify that Outlook legacy is installed with a status bar and version.





Plan interview



as many properties as posisble. at least SEID or User ID, Display first and last name, street address, state, zip code, time zone. area code. manager SEID and email address. Manager time zone. user presence. if user has out of office set in Outlook. Depart or division. desk and mobile phone. URL to Teams chat window.





Q\&A

Q: When you say 'list of file names from an Outlook legacy email message,' do you mean

A: Drag-and-drop actual email files (.msg, .eml) to extract recipients - Accept email message files and extract sender/recipients, Paste a raw email string (recipient list, CC, BCC fields) - Accept copy-pasted text from Outlook email header

Q: What Outlook properties should display for each contact/mailbox user? (e.g., Name, Email, Title, Department, Office Location, Phone)

A: as many properties as posisble.







7:33 AM 9/12/2026

SessionUtils\\SessionUtils.Prompts.md

SessionUtils\\SessionUtils.Plan.md







8:47 AM 9/12/2026



8:53 AM 9/12/2026

PLAN

the drag and drop shows a drag mouse cursor when hover top box but nothign drops. I have a Legacy outllook email window open and a name that has underscore. when I drop that name into email body , it shows display name and <first.last@email.com> formatted address.

Can a debug window - docked at bottom - be shown that shows - live- the drag coordinates and the contents of the drag payload - is that the Windows clipboard? and then show the drop target operation. Maybe a sepaate debug text control?

So the debug panel at bottom with have one or two text controls that have vertical scroll bar and show PowerShell like console output.





9:26 AM 9/12/2026

drag and drop works with debug panel. also make all fonts and text on controls and grid, 30 % bigger - at last 2 points font size extra.





9:32 AM 9/12/2026

Lookup fails with successful dropped address like

First Last MI <First.MI.Last@irs.gov>

But the lookup says no address recognized. above is valid and email address in angle brackets should be parsed out - in the parsing logic (don't change the text box) before lookup.





9:56 AM 9/12/2026 check in

feat: Implement Outlook Email Lookup Tool with WPF UI



\- Created LookupEmailList.DropTarget.Wpf.ps1 for drag-and-drop email resolution.

\- Added EmailLookup.psm1 module for Outlook COM interactions and recipient extraction.

\- Implemented settings management with LookupEmailList.Settings.json for UI state persistence.

\- Developed a DataGrid to display user profile data including email, title, and presence status.

\- Integrated a debug panel to log drag-and-drop events and payload details.

\- Ensured fallback mechanisms for user lookups via GAL, local Contacts, and ADSI.

\- Added export functionality to save results as CSV.

\- Documented implementation plan and verification steps in SessionUtils.Plan.md.





10:00 AM 9/12/2026

the look up error should show the exact email address the PowerShell used - in double quotes. and why lookup failed. What function was called and result?

Look up still fails but looks like email address parsed right.





First Last MI [First.MI.Last@irs.gov](mailto:First.MI.Last@irs.gov)







10:08 AM 9/12/2026

\[10:08:00.875] Debug cleared

\[10:08:07.503] DRAG: X=243 Y=45 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.507]   Format: UnicodeText | Type: String

\[10:08:07.508]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.510]   Format: Text | Type: String

\[10:08:07.511]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.515]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.520]   \[ACCEPT] Copy allowed

\[10:08:07.525] DRAG: X=224 Y=34 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.531]   Format: UnicodeText | Type: String

\[10:08:07.533]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.535]   Format: Text | Type: String

\[10:08:07.536]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.539]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.545]   \[ACCEPT] Copy allowed

\[10:08:07.548] DRAG: X=204 Y=18 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.552]   Format: UnicodeText | Type: String

\[10:08:07.553]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.556]   Format: Text | Type: String

\[10:08:07.557]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.560]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.566]   \[ACCEPT] Copy allowed

\[10:08:07.569] DRAG: X=198 Y=14 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.573]   Format: UnicodeText | Type: String

\[10:08:07.574]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.577]   Format: Text | Type: String

\[10:08:07.578]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.594]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.600]   \[ACCEPT] Copy allowed

\[10:08:07.604] DRAG: X=198 Y=12 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.608]   Format: UnicodeText | Type: String

\[10:08:07.609]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.612]   Format: Text | Type: String

\[10:08:07.613]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.616]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.619]   \[ACCEPT] Copy allowed

\[10:08:07.671] DRAG: X=198 Y=12 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.675]   Format: UnicodeText | Type: String

\[10:08:07.677]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.679]   Format: Text | Type: String

\[10:08:07.681]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.684]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.689]   \[ACCEPT] Copy allowed

\[10:08:07.726] DRAG: X=198 Y=12 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.729]   Format: UnicodeText | Type: String

\[10:08:07.731]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.733]   Format: Text | Type: String

\[10:08:07.734]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.737]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.742]   \[ACCEPT] Copy allowed

\[10:08:07.745] DRAG: X=198 Y=13 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.752]   Format: UnicodeText | Type: String

\[10:08:07.753]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.757]   Format: Text | Type: String

\[10:08:07.758]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.761]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.767]   \[ACCEPT] Copy allowed

\[10:08:07.771] DRAG: X=198 Y=16 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.776]   Format: UnicodeText | Type: String

\[10:08:07.778]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.782]   Format: Text | Type: String

\[10:08:07.783]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.786]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.791]   \[ACCEPT] Copy allowed

\[10:08:07.795] DRAG: X=196 Y=18 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.801]   Format: UnicodeText | Type: String

\[10:08:07.802]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.806]   Format: Text | Type: String

\[10:08:07.807]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.810]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.817]   \[ACCEPT] Copy allowed

\[10:08:07.820] DRAG: X=196 Y=20 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.824]   Format: UnicodeText | Type: String

\[10:08:07.826]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.829]   Format: Text | Type: String

\[10:08:07.830]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.833]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.838]   \[ACCEPT] Copy allowed

\[10:08:07.841] DRAG: X=196 Y=21 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.846]   Format: UnicodeText | Type: String

\[10:08:07.848]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.850]   Format: Text | Type: String

\[10:08:07.852]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.854]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.858]   \[ACCEPT] Copy allowed

\[10:08:07.863] DRAG: X=196 Y=23 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.869]   Format: UnicodeText | Type: String

\[10:08:07.870]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.873]   Format: Text | Type: String

\[10:08:07.874]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.878]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.882]   \[ACCEPT] Copy allowed

\[10:08:07.887] DRAG: X=196 Y=25 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.892]   Format: UnicodeText | Type: String

\[10:08:07.894]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.896]   Format: Text | Type: String

\[10:08:07.897]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.899]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.902]   \[ACCEPT] Copy allowed

\[10:08:07.905] DRAG: X=196 Y=26 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.909]   Format: UnicodeText | Type: String

\[10:08:07.910]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.913]   Format: Text | Type: String

\[10:08:07.914]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.916]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.919]   \[ACCEPT] Copy allowed

\[10:08:07.922] DRAG: X=196 Y=27 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.926]   Format: UnicodeText | Type: String

\[10:08:07.927]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.929]   Format: Text | Type: String

\[10:08:07.930]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.932]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.935]   \[ACCEPT] Copy allowed

\[10:08:07.938] DRAG: X=196 Y=28 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:07.942]   Format: UnicodeText | Type: String

\[10:08:07.943]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.948]   Format: Text | Type: String

\[10:08:07.950]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:07.952]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:07.954]   \[ACCEPT] Copy allowed

\[10:08:08.020] DRAG: X=196 Y=28 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:08.024]   Format: UnicodeText | Type: String

\[10:08:08.025]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.028]   Format: Text | Type: String

\[10:08:08.029]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.031]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:08.035]   \[ACCEPT] Copy allowed

\[10:08:08.099] DRAG: X=196 Y=28 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:08.103]   Format: UnicodeText | Type: String

\[10:08:08.104]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.106]   Format: Text | Type: String

\[10:08:08.107]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.109]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:08.112]   \[ACCEPT] Copy allowed

\[10:08:08.179] DRAG: X=196 Y=28 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:08.183]   Format: UnicodeText | Type: String

\[10:08:08.185]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.187]   Format: Text | Type: String

\[10:08:08.189]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.192]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:08.196]   \[ACCEPT] Copy allowed

\[10:08:08.258] DRAG: X=196 Y=28 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:08.261]   Format: UnicodeText | Type: String

\[10:08:08.262]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.265]   Format: Text | Type: String

\[10:08:08.266]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.268]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:08.271]   \[ACCEPT] Copy allowed

\[10:08:08.337] DRAG: X=196 Y=28 | Formats: MsOffice 8.0 Recipient, UnicodeText, Text, Recipient SIP Format

\[10:08:08.340]   Format: UnicodeText | Type: String

\[10:08:08.342]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.344]   Format: Text | Type: String

\[10:08:08.345]   Preview: Davis (Dave) Lee <Davis.S.Lee@irs.gov>

\[10:08:08.347]   Format: Recipient SIP Format | Type: MemoryStream

\[10:08:08.350]   \[ACCEPT] Copy allowed

\[10:08:08.367] DROP: Processing payload...

\[10:08:08.370]   Try format: UnicodeText

\[10:08:08.372]     \[RFC parse] No RFC headers found, trying plain email extraction...

\[10:08:08.375]     \[OK] Got 1 from text

\[10:08:08.377]   Try format: Text

\[10:08:08.378]     \[RFC parse] No RFC headers found, trying plain email extraction...

\[10:08:08.379]     \[OK] Got 1 from text

\[10:08:08.381]   Try format: Recipient SIP Format

\[10:08:08.383] DONE: 2 recipients

\[10:08:10.007] LOOKUP: Calling Lookup-User for email: "Davis.S.Lee@irs.gov"

\[10:08:10.021]   \[GAL] No match for: "Davis.S.Lee@irs.gov"

\[10:08:10.223]   \[Contacts] No match for: "Davis.S.Lee@irs.gov"

\[10:08:10.743]   \[ADSI] No match for: "Davis.S.Lee@irs.gov"

\[10:08:10.744]   \[RESULT] FAILED - No match found in any source (GAL/Contacts/ADSI)

\[10:08:10.745] LOOKUP: Calling Lookup-User for email: "Davis.S.Lee@irs.gov"

\[10:08:10.753]   \[GAL] No match for: "Davis.S.Lee@irs.gov"

\[10:08:10.950]   \[Contacts] No match for: "Davis.S.Lee@irs.gov"

\[10:08:11.444]   \[ADSI] No match for: "Davis.S.Lee@irs.gov"

\[10:08:11.445]   \[RESULT] FAILED - No match found in any source (GAL/Contacts/ADSI)





10:19 AM 9/12/2026

Davis.S.Lee@irs.gov







10:20 AM 9/12/2026

add anything that helps. still no Lookup results.

Can there be simulated or sample results - with a Simulation or WhatIf checkbox at top?



\[10:19:28.815] Debug cleared

\[10:19:29.772] LOOKUP: Calling Lookup-User for email: "Davis.S.Lee@irs.gov"

\[10:19:29.800]   \[GAL] No match for: "Davis.S.Lee@irs.gov"

\[10:19:30.388]   \[Contacts] No match for: "Davis.S.Lee@irs.gov"

\[10:19:30.389]   \[ADSI] Attempting LDAP search (mail + UPN fallback)...

\[10:19:30.740]   \[ADSI] No match for: "Davis.S.Lee@irs.gov" (tried mail, UPN)

\[10:19:30.741]   \[RESULT] FAILED - No match found in any source (GAL/Contacts/ADSI)







10:36 AM 9/12/2026

I paste in email and click simulation and Load - dialog say nothing to load.

Also says Outlook not installed but it is. Can you talk to Outlook COM  it worked before.







Can you use COM to talk to local Outlook legacy - it's already running?







10:56 AM 9/12/2026

PLAN

still nothing loads - what can be done? I have used PowerShell 5.1 to communicate with Outlook (or Outlook COM ) before. Does it have to be running?

can more vebose output be shown?



I just want display name, ID and time zone. for now.







11:35 AM 9/12/2026

PLAN

in new OutlookEmail.Explain.md explain how outlook itself looks up email addresses and user profiles? does it try emaiil first? The email addresses in Email windows have an underscore.



How do external apps lookup user profiles via email addresses?







12:10 PM 9/12/2026

Explain why this Sessions\\Sessions - PAWS\\TestOutlookEmailEvents.ps1 works in generating outlook email message - does it use COM?  So why can't I use similar logic to lookup an email address information - that is, look up user profile in GAL via Outlook app that is running?

Explain by creating Sessions\\Sessions - PAWS\\TestOutlookEmailEvents.Explain.md





1:33 PM 9/12/2026

create a new documenet React.Explain.md and explain react plus similar libraries. how is react supported in m365 and all Microsoft SDKs and programminglanguages? what is next for react?







++

Clear should clear current List name and description.









Davis.S.Lee@irs.gov



>>>

10:11 AM 9/12/2026

add above chat output to SessionUtils.Chat.md and preserve formatting and verbatim text. and summarized what changed including files touched.







### Reference







First Last MI [First.MI.Last@irs.gov](mailto:First.MI.Last@irs.gov)















