# Power Automate Failed Runs Inspector - Help

This page is read from `WpfPowerAutomateFailedRuns.Help.md` next to the script. Edit the file and press **Reload** to see changes.

## Modes

- **Simulation** (pulsing indicator): generated sample data. Nothing is read from Power Automate.
- **Live** (steady indicator): reads from your tenant with the PowerApps admin modules. Needs a sign-in (`Add-PowerAppsAccount`) and an admin role.
- Switch on **Settings > Data Source**. Live mode holds **one environment at a time**.

## Load order (important)

Things load in this order, and each depends on the one before it:

1. **Environments** - the list of environments in the tenant.
2. **Flows** - the flows of the one selected environment.
3. **Owners** - the distinct creators of those flows. Owners cannot load until Environments and Flows have.
4. **Runs** - run history of the listed flows (press Refresh on Run History).

If a step did not load, the line under the Workflows filters says **why** (red text). Hover over that line, the Environment box or the Owner box for the full reason and the order reminder.

## Workflows tab

- **Environment** box: type to search, the list shows at most 50 matches (tenants can have thousands).
- **Refresh**: reloads the flows of the selected environment. If Environments never loaded it retries them first.
- The **Environments:** and **Owners:** status lines show OK (green), loading (grey) or NOT loaded with the reason (red).

## Run History tab

- Covers **ONE environment**: only the flows listed on Workflows, not the whole tenant. The scope line above the grid shows the environment, signed-in user, tenant and date range.
- Dates default to one week ago through today.
- Each Refresh button has a **Last refreshed** time stamp next to it.

## Test tab - check each part first

Hover over any button for what it does and its **latest status**. The same status is written to the PowerShell Console.

1. **Prerequisites** - PowerShell edition, execution policy, network, modules, sign-in, admin API.
2. **Sample Environments** - lists environments and shows the first N. Also fills the Environment list on Workflows.
3. **Sample Flows** - flows of the selected environment, first N.
4. **Sample Owners** - top N owners by number of flows (needs step 3).
5. **Sample Runs** - latest N runs of the first flow (needs step 3).
- **Raw HTTP probe** - calls the environments REST endpoint directly and prints HTTP status, content type and the start of the body.
- **Run all** - steps 1 to 5, stopping at the first failure.

Sample size (1-10) applies to every sample step. The grids below show the outcome of each step and the sample items.

## Verbose mode

**Settings > PowerShell Verbose Mode** turns on PowerShell verbose output:

- `$VerbosePreference` is set to `Continue` and every Live cmdlet runs with `-Verbose`.
- The console shows each call with timing, the cmdlet verbose lines, and errors with the exception chain, error id and stack trace.
- The choice is saved in the settings file.

## Sign-in

A sign-in done in your own terminal does not carry over: the session lives in the PowerShell process. The app signs in itself.

- In Live mode, loading Environments or Flows signs in automatically (a sign-in window may open) when there is no session.
- **Settings > Power Platform Sign-in** has **Sign in** / **Sign out**, the cloud endpoint (`prod`, `usgov`, `usgovhigh`, `dod`...) and an optional Tenant ID. Both are saved in the settings file.

## Code Review tab (offline workflow review)

Reviews a flow definition statically; nothing is executed.

- **Source**: pick a file from `WorkflowSamples\`, or **Browse...** to any exported flow `.json`, `definition.json` or portal export `.zip`. **Rescan** after copying new files into `WorkflowSamples\`.
- **Review selected flow**: reviews the flow selected on Workflows or Run History (also the **Code Review** buttons there). Live mode downloads its definition with `Get-AdminFlow`; Simulation mode maps it to a sample file.
- **Badges**: trigger, re-entrant runs (trigger concurrency), worst-case parallelism (runs x Apply-to-each parallelism), loops, waits and worst-case waiting time, connector and HTTP calls, findings.
- **Tree**: every action, coloured by its worst finding (red High, orange Medium, blue Low). Clicking a finding highlights its action.
- **Rules**: concurrency/re-entrancy, variable races in parallel loops, nested loops, Until limits, throttling (parallel calls, retry policy), wait and timeout exposure (30-day run limit, synchronous Response, webhooks), error handling (Try/Catch via runAfter), and expressions (unknown functions, unbalanced brackets, null-unsafe access, missing or not-yet-run action references, undefined variables, `item()` outside loops, hard-coded tokens/GUIDs/URLs). Thresholds are in one table at the top of `Modules\WorkflowReview\WorkflowReview.psm1`.
- **Flow Checker (experimental)**: tries the cloud Flow Checker. It has no public API, so it may report that it is unavailable; the local rules are the dependable review.

Command line (no GUI):

    Import-Module .\Modules\WorkflowReview\WorkflowReview.psm1
    Get-ChildItem .\WorkflowSamples\*.json | Import-WorkflowDefinition | Invoke-WorkflowReview | ForEach-Object { $_.Summary }
    Import-WorkflowDefinition .\WorkflowSamples\07-Expression-Risks.json | Test-WorkflowExpressions | Format-Table
    Import-WorkflowDefinition x.json | Invoke-WorkflowReview | Export-WorkflowReviewReport -Path r.html -Format Html

Cmdlets: `Import-WorkflowDefinition`, `Get-WorkflowStructure`, `Test-WorkflowConcurrency`, `Test-WorkflowLooping`, `Test-WorkflowThrottling`, `Test-WorkflowTimeouts`, `Test-WorkflowErrorHandling`, `Test-WorkflowExpressions`, `Invoke-WorkflowReview`, `Export-WorkflowReviewReport`.

## Troubleshooting

- **Invalid JSON primitive: IRS.** (or similar): the service answered with text that is not JSON, usually a proxy, firewall or sign-in page. Run **Test > Raw HTTP probe**. HTML or plain text means something between you and the API is answering; a JSON 401 means the endpoint is reachable but the token was not accepted.
- **Environments NOT loaded - modules missing**: use **Settings > Validate Modules Now**, or install with `Install-Module Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser`.
- **Environments NOT loaded - 0 returned**: sign in with a Power Platform admin account (`Add-PowerAppsAccount`).
- **Owners NOT loaded**: load Environments first, select one, then press Refresh.
- **Test buttons show nothing**: open the Console (status bar toggle). Every step prints a header, a status line and `[OK]` or `[X]`.

## Settings file

Window size, active tab, zoom, selected environment, Verbose mode and test sample size are saved in `%APPDATA%\PAFailedRunsInspector\settings.json`.
