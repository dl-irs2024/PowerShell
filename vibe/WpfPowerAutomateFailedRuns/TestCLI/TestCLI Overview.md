# TestCLI Overview

Command-line (no UI) live tests for the Power Platform admin cmdlets, written for **Windows PowerShell 5.1**. Run them from this folder, for example `.\Test-PA-CLI-AdminFlow.ps1`.

All tests are **read-only**, sign in with `Add-PowerAppsAccount` (interactive), check for errors at every step, print color-coded output, and save a colored HTML report to `Logs\`. Exit codes: `0` all passed, `1` a failure, `2` module not installed.

Prerequisite: `Install-Module Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser -Force -AllowClobber` and a Power Platform admin account.

## Scripts in this folder

| Script | What it does | Cmdlets / endpoints | Key parameters |
|---|---|---|---|
| `Test-PA-CLI-AdminFlow.ps1` | Signs in, lists environments and environment owner, lists flows, checks the flow owner (`CreatedBy.userId`), looks up a single flow by name. | `Get-AdminPowerAppEnvironment`, `Get-AdminFlow` (bap, flow APIs) | `-EnvironmentName`, `-TenantID`, `-Top` |
| `Test-PA-CLI-AdminFlowOwnerRole.ps1` | Finds an environment with flows, then for up to `-Top` flows checks `Get-AdminFlowOwnerRole` returns roles and an `Owner`. | `Get-AdminFlow`, `Get-AdminFlowOwnerRole` | `-EnvironmentName`, `-TenantID`, `-Top` |
| `Test-PA-CLI-AdminPowerAppConnection.ps1` | Finds an environment with connections; checks fields, the connection owner (`CreatedBy`) and the `-ConnectorNameFilter` option. Zero connections = PASS. | `Get-AdminPowerAppConnection` (powerapps API) | `-EnvironmentName`, `-TenantID`, `-Top` |
| `Test-PA-CLI-AdminPowerAppConnector.ps1` | Finds an environment with custom connectors; checks fields and owner (`CreatedBy`). Zero connectors = PASS. | `Get-AdminPowerAppConnector` (powerapps API) | `-EnvironmentName`, `-TenantID`, `-Top` |
| `Test-PA-CLI-EnvironmentSources.ps1` | Tries every known way to list environments (BAP cmdlet, BAP REST, PowerApps REST, Flow REST, Dataverse discovery, derived `Default-<tid>`) and prints a ready-to-run command. Use it when `api.bap.microsoft.com` fails. | the sources listed | `-TenantID` |
| `PA-CLI-Debug.ps1` | **Not a test.** Shared library dot-sourced by the scripts above: color logging, HTML report, proxy credential setup, HTTP request/response tracing, network/token diagnostics, `Start-PATestSession`, `Invoke-Step`, `Add-Result`. | – | – |
| `API.BAP.microsoft.com.Workaround.md` | Why BAP matters, how to diagnose a 407/non-JSON reply, fixes and workarounds, samples. | – | – |
| `HowGetWorkflows.Explain.md` | **Doc, not a script.** Explains `Get-AdminFlow` per environment, the creator (`CreatedBy`) vs. co-owner (`Get-AdminFlowOwnerRole`) distinction, and filtering to one user. Includes a sample script (console/CSV/HTML output). | `Get-AdminFlow`, `Get-AdminFlowOwnerRole` | – |
| `HowGetRunHistory.Explain.md` | **Doc, not a script.** Explains `Get-FlowRun` single-flow vs. bulk mode (looping a flow list), with a sample script (console/CSV/HTML output). | `Get-FlowRun` | – |
| `Logs\` | Colored HTML reports, one per run. | – | – |

Every script has full comment-based help: `Get-Help .\Test-PA-CLI-AdminFlow.ps1 -Full`.

## What every test does (in order)

1. **Debug init** – sets proxy credentials (current Windows user), TLS 1.2, verbose output, installs the HTTP trace.
2. **Network diagnostics** – DNS + HTTPS check of login, BAP, Flow and PowerApps hosts (a `407` is shown in red).
3. **Import module and sign in** – then shows token user/tenant/audience/expiry.
4. **Get environment and owner** – `Get-AdminPowerAppEnvironment`; if it fails, a direct raw call is made and the exact reply is shown. With `-EnvironmentName` the test continues anyway.
5. **Cmdlet under test**, with a PASS/FAIL per check.
6. **Summary** – results, totals, path of the HTML report.

## Log colors

INFO cyan · OK green · WARN yellow · ERR red · HTTP magenta · BODY teal · HDR gold · DIM gray · section banners white. The HTML report keeps these colors.

## Other scripts in the project (one level up) that can be run

These are in `..\` and do not use the live admin API unless noted.

| Script | Purpose | Needs live API? |
|---|---|---|
| `..\WpfPowerAutomateFailedRuns.ps1` | The main WPF GUI: failed runs, environments, flows, test tab, settings. | Yes (and a UI) |
| `..\TestCommandLine\TestTabEnhancements.ps1` | Earlier test cmdlets for the GUI's Test tab: Get/Enable/Disable-AdminFlow, Get-AdminFlowOwnerRole, connections, connectors, environments. Includes **Enable/Disable** (changes state) – review before running. | Yes |
| `..\Modules\WorkflowReview\WorkflowReview.psm1` | Offline static review of flow definitions: `Import-WorkflowDefinition x.json \| Invoke-WorkflowReview \| Format-Table`. Sample inputs in `..\WorkflowSamples\*.json`. | **No** |
| `..\Invoke-CodeReview.ps1` | Re-entrancy, error handling and best-practice analysis of workflow objects. | No (works on objects you pass) |
| `..\Get-WorkflowDependencies.ps1` | Finds Canvas App, SharePoint trigger and cross-workflow dependencies. | No (objects) |
| `..\Export-WorkflowData.ps1` | Exports workflow/run data to CSV, TSV, HTML, Excel, Markdown. | No (objects) |
| `..\New-WorkflowRestartScript.ps1` | Generates timestamped scripts to restart failed workflows. The generated script restarts flows, so review it before running. | The generated script does |

The scripts that take workflow objects are function libraries (dot-source them, then call the functions). Where this table says "objects", the objects normally come from `Get-AdminFlow`, so you still need an API path for real data – see `API.BAP.microsoft.com.Workaround.md`.

## Troubleshooting quick reference

| Symptom | Meaning | Action |
|---|---|---|
| `Invalid JSON primitive: ...` | The module received text/HTML instead of JSON (usually a proxy page). | Read the `<<<START ... END>>>` block in the output. See Workaround guide sections 1–2. |
| `[ERR] *** 407 Proxy Authentication Required ***` | Proxy did not accept credentials. | Run from a domain-joined session, check proxy/PAC settings, ask network team to allow the hosts. |
| BAP step fails, others work | BAP blocked/intercepted. | `.\Test-PA-CLI-EnvironmentSources.ps1`, then `-EnvironmentName`. |
| `Get-AdminFlow` returns 0 flows | Account has no admin rights over that environment, or none exist. | Use a Power Platform / Environment admin account. |
