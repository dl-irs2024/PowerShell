# How do I get run history?

This explains how to get run history for a Power Automate flow: a **single named flow**, and **bulk mode** where you loop over a list of flows (for example, one user's flows from [HowGetWorkflows.Explain.md](./HowGetWorkflows.Explain.md)). Samples reuse the helpers in [PA-CLI-Debug.ps1](./PA-CLI-Debug.ps1) for console color, CSV and HTML output, matching the style of the `Test-PA-CLI-*` scripts in this folder.

---

## 1. The cmdlet: `Get-FlowRun`

```powershell
Add-PowerAppsAccount
Get-FlowRun -EnvironmentName 'Default-<tenantGuid>' -FlowName '<flow-guid>'
```

Each run object includes:

| Property | Meaning |
|---|---|
| `FlowRunName` | the run's unique id |
| `Status` | `Succeeded`, `Failed`, `Running`, `Cancelled`, etc. |
| `StartTime` / `EndTime` | when the run happened |
| `Error` | populated for failed runs (string or an object with `.message`) — see the main app's `Get-LiveRuns` function in [WpfPowerAutomateFailedRuns.ps1](<../WpfPowerAutomateFailedRuns.ps1>) for a field that normalizes this |

`Get-FlowRun` is scoped to **one flow in one environment** — there is no "all runs in this environment" cmdlet. That is exactly why there are two modes below.

---

## 2. Single-flow mode

Use this when you already know which flow you care about (e.g. you're investigating one failing flow):

```powershell
Get-FlowRun -EnvironmentName $envName -FlowName $flowName -ErrorAction Stop |
    Select-Object FlowRunName, Status, StartTime, EndTime
```

## 3. Bulk mode (many flows)

There's no shortcut: you call `Get-FlowRun` **once per flow**. For a list of flows — say, everything one user owns, from [HowGetWorkflows.Explain.md](./HowGetWorkflows.Explain.md) — loop over them:

```powershell
$results = foreach ($flow in $ownerFlows) {
    @(Get-FlowRun -EnvironmentName $flow.EnvironmentName -FlowName $flow.FlowName -ErrorAction SilentlyContinue) |
        ForEach-Object { $_ | Add-Member -NotePropertyName FlowDisplayName -NotePropertyValue $flow.DisplayName -PassThru -Force }
}
```

**Cost warning:** this is N API calls for N flows. For a user with hundreds of flows, or across every flow in a large environment, this can be slow and may hit throttling. Mitigate by:
- narrowing the flow list first (by owner, as in doc 1, or by `Enabled -eq $true`),
- limiting runs per flow with `-Top` if your module version supports it, or trimming client-side with `Select-Object -First N`,
- adding a short `Start-Sleep -Milliseconds 200` between calls if you see throttling (HTTP 429) errors.

---

## 4. Sample script: single-flow and bulk modes with console/CSV/HTML output

```powershell
<#
.SYNOPSIS
    Get run history for one flow (-FlowName) or for every flow in a list (-FlowList, bulk mode),
    with console, CSV and HTML output. Windows PowerShell 5.1.
.PARAMETER EnvironmentName  Environment the flow(s) live in.
.PARAMETER FlowName         Single-flow mode: one flow's GUID.
.PARAMETER FlowList         Bulk mode: an array of flow objects with FlowName/DisplayName
                            (e.g. the filtered output of HowGetWorkflows.Explain.md's sample script).
.PARAMETER Top              Max runs kept per flow after retrieval (default 20).
#>
param(
    [Parameter(Mandatory)][string]$EnvironmentName,
    [string]$FlowName,
    [object[]]$FlowList,
    [int]$Top = 20
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PA-CLI-Debug.ps1')   # Write-PALog, Write-PAHeader, Save-PAReport
Initialize-PADebug

Import-Module Microsoft.PowerApps.Administration.PowerShell -WarningAction SilentlyContinue
Add-PowerAppsAccount

if (-not $FlowName -and -not $FlowList) { throw 'Provide either -FlowName (single-flow mode) or -FlowList (bulk mode).' }

# Normalize to one list of {FlowName, DisplayName} regardless of mode
$targets = if ($FlowName) {
    Write-PAHeader "Single-flow mode: $FlowName"
    @([pscustomobject]@{ FlowName = $FlowName; DisplayName = $FlowName })
} else {
    Write-PAHeader "Bulk mode: $($FlowList.Count) flow(s)"
    $FlowList
}

$allRuns = foreach ($t in $targets) {
    Write-PALog INFO "Get-FlowRun: $($t.DisplayName) ($($t.FlowName))"
    try {
        $runs = @(Get-FlowRun -EnvironmentName $EnvironmentName -FlowName $t.FlowName -ErrorAction Stop) |
            Select-Object -First $Top
        Write-PALog OK "  $($runs.Count) run(s)"
    } catch {
        Write-PAError $_ "Get-FlowRun for $($t.DisplayName)"
        continue
    }
    foreach ($r in $runs) {
        $errMsg = if ($r.Error -is [string]) { $r.Error } elseif ($r.Error.message) { $r.Error.message } else { $null }
        [pscustomobject]@{
            FlowName    = $t.FlowName
            DisplayName = $t.DisplayName
            RunId       = $r.FlowRunName
            Status      = $r.Status
            StartTime   = $r.StartTime
            EndTime     = $r.EndTime
            Error       = $errMsg
        }
    }
}

# ---- Console output (color-coded; failures in red) ----
Write-PAHeader 'Results'
foreach ($run in $allRuns) {
    $lvl = if ($run.Status -eq 'Failed') { 'ERR' } elseif ($run.Status -eq 'Succeeded') { 'OK' } else { 'INFO' }
    Write-PALog $lvl ("  {0} | {1} | {2} | {3}" -f $run.DisplayName, $run.Status, $run.StartTime, $(if ($run.Error) { $run.Error } else { '' }))
}
Write-PALog INFO "Total runs: $($allRuns.Count), Failed: $(@($allRuns | Where-Object Status -eq 'Failed').Count)"

# ---- CSV export ----
$csvPath = Join-Path $PSScriptRoot "Logs\RunHistory_$(Get-Date -Format yyyyMMdd-HHmmss).csv"
$allRuns | Export-Csv -Path $csvPath -NoTypeInformation
Write-PALog OK "CSV saved: $csvPath"

# ---- Colored HTML report ----
$htmlPath = Save-PAReport -Name 'HowGetRunHistory'
Write-PALog OK "HTML report saved: $htmlPath"
```

Usage:

```powershell
# Single-flow mode
.\RunHistory.ps1 -EnvironmentName Default-<tenantGuid> -FlowName '<flow-guid>'

# Bulk mode: combine with doc 1's owner filter to get one user's run history
$janeFlows = .\ListFlows.ps1 -EnvironmentName Default-<tenantGuid> -Owner jane.doe@contoso.com
.\RunHistory.ps1 -EnvironmentName Default-<tenantGuid> -FlowList $janeFlows -Top 10
```

(As with doc 1, this is a sample for the explanation, not a maintained script — see [TestCLI Overview.md](<./TestCLI Overview.md>) for what's already built.)

---

## 5. Caveats

- One API call per flow in bulk mode — there is no server-side "all runs across flows" query.
- `Get-FlowRun` typically returns only recent runs (retention is tenant/flow-plan dependent); it is not a full historical archive.
- Requires admin rights over the flow's environment.
- `Status` values and whether `Error` is populated can vary slightly by connector/trigger type — always null-check before reading `.Error.message`.

## See also

- [HowGetWorkflows.Explain.md](./HowGetWorkflows.Explain.md) — get the (optionally owner-filtered) flow list to feed into bulk mode.
- [API.BAP.microsoft.com.Workaround.md](./API.BAP.microsoft.com.Workaround.md) — fixes for admin API network failures.
- [TestCLI Overview.md](<./TestCLI Overview.md>) — all scripts/docs in this folder.
