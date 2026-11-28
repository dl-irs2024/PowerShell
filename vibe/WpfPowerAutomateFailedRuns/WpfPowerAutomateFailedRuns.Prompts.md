WpfPowerAutomateFailedRuns.Prompts.md



C:\\Davis\\vibe\\Power-Automate\\WpfPowerAutomateFailedRuns

WpfPowerAutomateFailedRuns.Prompts.md







PLAN

2:32 PM 11/19/2026

WpfPowerAutomateFailedRuns.Plan.md

PowerShell Power Automate inspector.

Create WpfPowerAutomateFailedRuns.ps1.

Create PowerShell 5.1 WPF to access Power Automate workflows.

Show run history, and published workflows.

Export in variety of formats, CSV, TSV, HTML, Excel, Markdown.

Show and filter by date range or Environment or Owner or Failed / execution status.

If possible show what might be missing in each workflow or at least flag it for "Code Review" later.

Allow a workflow to restart - if necessary create a dynamic PowerShell script for this purpose and add comments and fitting datestamped name.

Advanced functions can be to show if Workflow has dependencies including invoked by Canvas Apps or tied to SharePoint Lists.  Show if Owners are no longer active.

Use multiple tabs for each function group and same pastel colors as from prior project - Red changes or deletes something, green starts something, Blue informational.

Code Review can be a large area. Show the re-entrant state, proper error handling.  This can be expanded in future.

Add a simulation mode with realistic sample data. and a live mode that also test for prompt import of modules and can also "smoke test" a live connection.

We only want to deal with Power Automate for now. not any other part of the Microsoft cloud.

User profiles, Power Apps Canvas and data sources would be next, so there should be placeholders.





8:18 AM 11/23/2026

C:\\Davis\\vibe\\Power-Automate

git init



C:\\Davis\\vibe\\Power-Automate\\WpfPowerAutomateFailedRuns\\WpfPowerAutomateFailedRuns.ps1







MON 7:57 AM 11/23/2026

...

The test Connection doesn't do anything.

Do any of the other ps1 files test connection?

Test connection should show what's missing then add instructions on how to fix. If inline can be different console colors or use PowerShell comment # symbol.

can a common PowerShell console button or small text window be added as a common area above the status bar? It would be common to all of the tabs. Also the colors not have high contrast. Maybe more muted pastel and also dark or black letters instead of white.

Add zoom button in common area at bottom to zoom current tab and persist the zoom for each tab.









9:01 AM 11/23/2026

simulaton text should be blinking and can add a red blinking warning emoji or animated small gif to right. then graphic goes away when not Simulation (when Live mode)







9:57 AM 11/23/2026

67

Starting in Simulation mode...

Generating sample data...

Loaded 15 workflows

Initializing WPF interface...

==== Test Connection  2026-11-23 09:55:33 ====

\# Current mode is Simulation; these checks show what Live mode needs.

Checking PowerShell edition...

\[OK] Windows PowerShell 5.1.26100.9818

Checking execution policy...

\[OK] Execution policy is 'Bypass'

Checking network access (TCP 443)...

\[X] login.microsoftonline.com not reachable

\[X] api.bap.microsoft.com not reachable

\[X] api.flow.microsoft.com not reachable

\[X] www.powershellgallery.com not reachable

\# Fix: check VPN / firewall / proxy. Inspect the system proxy with:

netsh winhttp show proxy

\# If a proxy is required, let PowerShell use it with default credentials:

\[System.Net.WebRequest]::DefaultWebProxy.Credentials = \[System.Net.CredentialCache]::DefaultNetworkCredentials

Checking required modules...

\[OK] Module 'Microsoft.PowerApps.Administration.PowerShell' 2.0.198 loaded

\[OK] Module 'Microsoft.PowerApps.PowerShell' 1.0.40 loaded

Checking Power Platform sign-in...

\[X] Not signed in to Power Platform

\# Fix: sign in (opens a browser / account prompt), then click Test Connection again:

Add-PowerAppsAccount

\# For a specific tenant or sovereign cloud:

Add-PowerAppsAccount -Endpoint prod -TenantID '<tenant-guid>'

Checking Power Platform admin API access...

\[!] Skipped: not signed in

==== 5 problem(s) found. Run the commands above, then test again. ====





10:29 AM 11/23/2026 test changes on 67

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

10:50 AM 11/23/2026







10:58 AM 11/23/2026

Persist window size and active tab in JSON settings file - that is already there.

Live mode not getting data -would a refresh button on relevant tabs help?

Plus the pulsating Simulation still shows Simulation  when in Live mode.

Should Environments drop down listbox show all environments - there's thousands of them.

The run history dates should default to one week ago as start date and today as end date.

Each tab that has a Refresh button should have a date time stamp near or below - that shows last refresh.

Add screen tips every where possible.











11:46 AM 11/23/2026

PLAN

Can the settings or a new Test Tab show sample 5-10 Environment and also 5-10 Owner retrieval - and verbose PowerShell output - in the common PowerShell output area?

How do I make sure each part is working first.

The error below has no detail - if a Verbose mode in Settings tab helps go ahead and add it.

Error listing environments: Exception calling "DeserializeObject" with "1" argument(s): "Invalid JSON primitive: IRS."



For Run History is it current default Environment? or entire Tenant?  The Tenant or Environment should show or any other relevant  info.



11:55 AM 11/23/2026 implement with autopilot.





12:07 PM 11/23/2026

Fixes:

Environment doesn't load - there should be more detail (Screen tips) that shows why not loaded. Environment and Owners important enough to have own error or status line just below buttons.

Screentip should indicate that Environments need  to load first, then Owners.

New Help Tab should explain all this - presenting a local markdown file if possible.

On Test tab, clicking buttons don't show any issues or output. In this cases the top 5 and 2 extra buttons should have screen tips that show what the button does and immediate status and repeat that status - verbose in the PowerShell Console.

Setting tab should have a PowerShell Verbose mode.



12:24 PM 11/23/2026

Fix:

Should Add-PowerAppsAccount be inside the Session and other places like Environment loading logic?

It works outside the script.



12:25 PM 11/23/2026

PLAN

for code review - I assume I can pick a workflow from the Workflows or Run History tab.

So for now. add 5-7 test workflows - with different triggers and concurrency or re-entrant models. e.g. button triggered, re-entrant and somehow show each re-entrant count what woudl be best way.

The underlying format, if possible, should follow the exported workflow format when exporting from Power Automate. Create a WorkflowSamples sub-folder if that file format (JSON) works. Then I should be able to copy in other sample workflows later - for essentially off-line Code Review.

I just want to visualize workflow correctness.

Show presence of looping and other throttling actions.

Show number of wait actions and other risks that might cause it to time out

Code Review, if not already should be command line cmdlets and modular. I want to try to review expressions (dynamic content) and also WDL workflow definition language calls.

If I can mimic or invoke the workflow checker logic in Power Automate cloud UI that would be great.









3:04 PM 11/23/2026

NEXT

Add more sample workflows with more complexities, approval, wait states. parallel branches.

Show error handling exception handling and retries.

Document how the interface to existing rules work.

I want to formalize the rules database (engine).



I will have rule IDs, workflow IDs. rule names. and categories of rules.

Agentic interface is also a goal.





1:46 PM 11/24/2026

Test Tab enhancements.

Test these cmdlets - and prompt for real Environments.

Try to look up environments for current user.

Microsoft provides administrative PowerShell cmdlets including:

Get-AdminFlow

Enable-AdminFlow

Disable-AdminFlow

Get-AdminFlowOwnerRole

Get-AdminPowerAppConnection

Get-AdminPowerAppConnector



pac CLI is blocked - with 407 error - no time to fix, networking cannot find issue.

PowerShell works best.





\\\\Vp0wxsqm365as02\\SPS\\PAWS-Sessions







8:55 AM 11/25/2026

in WpfPowerAutomateFailedRuns\\TestCLI

write PowerShell 5.1 CLI (no UI) scripts that begin with Test-PA-CLI- that tests getting Environment, Getting owner.

And tests each of the cmdlets below - tests live. 

each script should sign in and have error checking.

Get-AdminFlow

Get-AdminFlowOwnerRole

Get-AdminPowerAppConnection

Get-AdminPowerAppConnector







Enable-AdminFlow

Disable-AdminFlow



9:32 AM 11/25/2026

67 debugging



🐞

PS C:\\PAWS\\PowerShell\\WpfPowerAutomateFailedRuns\\TestCLI> .\\Test-PA-CLI-AdminFlow.ps1

WARNING: The names of some imported commands from the module 'Microsoft.PowerApps.Administration.PowerShell' include

unapproved verbs that might make them less discoverable. To find the commands with unapproved verbs, run the

Import-Module command again with the Verbose parameter. For a list of approved verbs, type Get-Verb.

\[PASS] Sign-in (Add-PowerAppsAccount) - ok

\[FAIL] Get-AdminPowerAppEnvironment - Exception calling "DeserializeObject" with "1" argument(s): "Invalid JSON primitive: IRS."

Probe: HTTP 401 Unauthorized via proxy.web.irs.gov:8080

Probe body (first 300 chars): {"error":{"code":"MissingAuthorizationHeaderAndClientCertificate","message":"A client certificate or authorization header was not provided.","detailUrlType":"NotSpecified"}}

Hint: if the body is not JSON (401 JSON is normal), a proxy/security gateway is intercepting api.bap.microsoft.com. Allow it, or check VPN/proxy settings.

PS C:\\PAWS\\PowerShell\\WpfPowerAutomateFailedRuns\\TestCLI>





same error can mroe code be added to show the JSON and what is returned. we had 407 errors befor but I don't see here. add as much debugging, diagnosis as possbile. as much verbose output as possible. color code if possible.







9:48 AM 11/25/2026

can any color highlighting be preserved and how can I get around the api.bap - create a new markdown API.BAP.microsoft.com.Workaround.md with as much detail as possible, sample script, sample output.  What other scripts can be run? Create a TestCLI Overview.md that shows each script and what it does. finally add detailed PowerShell Help comments and comments anywhere in the code that is helpful.







### TEST APP

Create a test app new WPF 5.1



Allow selection for types and number of Environments, Owners and Workflows to simulate.











Plus simulate data.

New test App should do everything Test tab does plus load Environments, Owners.











>>

2:06 PM 11/24/2026

11:36 AM 11/23/2026

10:09 AM 11/23/2026

4:13 PM 11/19/2026

append above chat verbatim to

WpfPowerAutomateFailedRuns.Chat.md





Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned



\\\\Vp0wxsqm365as02\\SPS\\PAWS-Sessions



