# How do I get all workflows per environment, per user/owner?

This explains how to list every flow in **one Power Automate environment** and narrow the list down to a **specific user**, and why "owner" is ambiguous in the admin API. It uses the same `Microsoft.PowerApps.Administration.PowerShell` module as the scripts in this folder, and reuses the color/report helpers from [PA-CLI-Debug.ps1](./PA-CLI-Debug.ps1) so the sample looks and behaves like the `Test-PA-CLI-*` scripts.

> If `Get-AdminPowerAppEnvironment` (needed to find environment names) fails, see [API.BAP.microsoft.com.Workaround.md](./API.BAP.microsoft.com.Workaround.md) first.

---

## 1. The cmdlet: `Get-AdminFlow`

```powershell
Add-PowerAppsAccount
Get-AdminFlow -EnvironmentName 'Default-<tenantGuid>'
```

This returns **every flow in that environment** (that the signed-in admin can see) — not filtered by user. Each flow object includes:

| Property | Meaning |
|---|---|
| `FlowName` | the flow's GUID (its unique id) |
| `DisplayName` | the human-readable name |
| `Enabled` | whether it's turned on |
| `CreatedTime` / `LastModifiedTime` | timestamps |
| `CreatedBy` | **who created it** — see below |

`Get-AdminFlow` is scoped to **one environment**. To cover more than one, call it once per environment name (see [HowGetRunHistory.Explain.md](./HowGetRunHistory.Explain.md) for the same looping pattern applied to run history).

---

## 2. "Owner" means two different things

This is the part most people get wrong, because the admin cmdlets expose two different, non-overlapping ideas of "owner":

| Concept | Where it comes from | Cardinality | Notes |
|---|---|---|---|
| **Creator** | `$flow.CreatedBy` on the `Get-AdminFlow` result | exactly one person | this is who originally made the flow; it does **not** change if ownership is transferred in some scenarios, and it does **not** include co-owners added later |
| **Co-owner(s)** | `Get-AdminFlowOwnerRole -EnvironmentName <env> -FlowName <id>`, rows where `RoleType -eq 'Owner'` | zero or more | this is the actual Power Automate "Owners" list you see in the portal's Details pane — it includes the creator (usually) plus anyone else added as an owner, including security groups |

`CreatedBy` looks like this:

```powershell
PS> $flow.CreatedBy

id                : 00000000-1111-2222-3333-444444444444
displayName       : Jane Doe
email             : jane.doe@contoso.com
type              : User
tenantId          : ...
userId            : 00000000-1111-2222-3333-444444444444
userPrincipalName : jane.doe@contoso.com
```

Not every tenant/flow populates every field — `userPrincipalName` is usually present for normal user accounts, but can be blank for flows created by a service principal or an old/migrated flow. Always fall back through `userPrincipalName` → `email` → `displayName` → `userId`.

**Rule of thumb:** if you want "flows this person made," filter on `CreatedBy`. If you want "flows this person can manage" (the portal's Owners list), call `Get-AdminFlowOwnerRole` per flow and check for `RoleType -eq 'Owner'` — this is slower because it's one extra API call per flow, so only do it for the flows you actually care about (e.g. after filtering by creator, or for a short list).

---

## 3. Sample script: list + filter one environment by creator

```powershell
<#
.SYNOPSIS
    List all flows in one environment, optionally filtered to one owner (creator), with
    console, CSV and HTML output. Windows PowerShell 5.1.
.PARAMETER EnvironmentName  Environment to scan (e.g. Default-<tenantGuid>).
.PARAMETER Owner            Optional UPN/email to filter CreatedBy to. Omit to list everyone.
.PARAMETER IncludeCoOwners  Also look up Get-AdminFlowOwnerRole for each matching flow (slower:
                            one extra API call per flow) and show full owner/co-owner list.
#>
param(
    [Parameter(Mandatory)][string]$EnvironmentName,
    [string]$Owner,
    [switch]$IncludeCoOwners
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PA-CLI-Debug.ps1')   # Write-PALog, Write-PAHeader, Save-PAReport
Initialize-PADebug

Import-Module Microsoft.PowerApps.Administration.PowerShell -WarningAction SilentlyContinue
Add-PowerAppsAccount

Write-PAHeader "Get-AdminFlow -EnvironmentName $EnvironmentName"
$flows = @(Get-AdminFlow -EnvironmentName $EnvironmentName -ErrorAction Stop)
Write-PALog OK "Found $($flows.Count) flow(s) total"

# Shape each flow into a flat row; fall back through CreatedBy identity fields
$rows = foreach ($f in $flows) {
    $c = $f.CreatedBy
    $creatorId = if ($c.userPrincipalName) { $c.userPrincipalName } elseif ($c.email) { $c.email } elseif ($c.displayName) { $c.displayName } else { $c.userId }
    [pscustomobject]@{
        FlowName    = $f.FlowName
        DisplayName = $f.DisplayName
        Enabled     = $f.Enabled
        Creator     = $creatorId
        CreatedTime = $f.CreatedTime
    }
}

if ($Owner) {
    Write-PALog INFO "Filtering to Creator -eq '$Owner'"
    $rows = @($rows | Where-Object { $_.Creator -eq $Owner })
    Write-PALog $(if ($rows.Count -gt 0) { 'OK' } else { 'WARN' }) "$($rows.Count) flow(s) created by $Owner"
}

if ($IncludeCoOwners) {
    Write-PAHeader 'Looking up co-owners (Get-AdminFlowOwnerRole) for matching flows'
    foreach ($r in $rows) {
        $roles = @(Get-AdminFlowOwnerRole -EnvironmentName $EnvironmentName -FlowName $r.FlowName -ErrorAction SilentlyContinue)
        $owners = ($roles | Where-Object RoleType -eq 'Owner' | ForEach-Object { $_.PrincipalObjectId }) -join ', '
        Write-PALog INFO "  $($r.DisplayName): owners = $owners"
        $r | Add-Member -NotePropertyName Owners -NotePropertyValue $owners
    }
}

# ---- Console output (color-coded) ----
Write-PAHeader 'Results'
$rows | ForEach-Object { Write-PALog INFO ("  {0} | {1} | Enabled={2} | Creator={3}" -f $_.FlowName, $_.DisplayName, $_.Enabled, $_.Creator) }

# ---- CSV export ----
$csvPath = Join-Path $PSScriptRoot "Logs\Workflows_$EnvironmentName_$(Get-Date -Format yyyyMMdd-HHmmss).csv"
$rows | Export-Csv -Path $csvPath -NoTypeInformation
Write-PALog OK "CSV saved: $csvPath"

# ---- Colored HTML report (reuses the same report the Test-PA-CLI-* scripts produce) ----
$htmlPath = Save-PAReport -Name 'HowGetWorkflows'
Write-PALog OK "HTML report saved: $htmlPath"
```

Usage:

```powershell
# Everyone's flows in one environment
.\ListFlows.ps1 -EnvironmentName Default-<tenantGuid>

# Just Jane's flows (by creator)
.\ListFlows.ps1 -EnvironmentName Default-<tenantGuid> -Owner jane.doe@contoso.com

# Jane's flows, plus the full co-owner list for each
.\ListFlows.ps1 -EnvironmentName Default-<tenantGuid> -Owner jane.doe@contoso.com -IncludeCoOwners
```

(This is a sample for the explanation — if you want it as a real, maintained script in this folder, that's a separate ask; see [TestCLI Overview.md](<./TestCLI Overview.md>) for what already exists.)

---

## 4. Multiple environments

To cover **every** environment, loop `Get-AdminPowerAppEnvironment` → `Get-AdminFlow` per environment, same pattern as the "find an environment with flows" loop used in [Test-PA-CLI-AdminFlowOwnerRole.ps1](./Test-PA-CLI-AdminFlowOwnerRole.ps1):

```powershell
$envs = Get-AdminPowerAppEnvironment -ErrorAction Stop
$all = foreach ($e in $envs) {
    try { @(Get-AdminFlow -EnvironmentName $e.EnvironmentName -ErrorAction Stop) |
        ForEach-Object { $_ | Add-Member -NotePropertyName EnvironmentName -NotePropertyValue $e.EnvironmentName -PassThru -Force } }
    catch { Write-PALog WARN "Skipped $($e.DisplayName): $($_.Exception.Message)" }
}
```

For a tenant with many environments this can be slow (one `Get-AdminFlow` call per environment) — filter environments first if you already know which one(s) matter.

---

## 5. Caveats

- Requires a **Power Platform admin** (or Environment Admin) account; a normal maker only sees their own flows through non-admin cmdlets.
- `CreatedBy` can be missing or incomplete for flows made by a service principal, or very old/migrated flows.
- `Get-AdminFlow` does not accept an owner filter server-side — filtering happens client-side with `Where-Object` after retrieving the full list.
- Large environments can return thousands of flows; `Get-AdminFlowOwnerRole` is one call per flow, so only use `-IncludeCoOwners` after narrowing the list down.

## See also

- [HowGetRunHistory.Explain.md](./HowGetRunHistory.Explain.md) — once you have a (possibly owner-filtered) flow list, get its run history.
- [API.BAP.microsoft.com.Workaround.md](./API.BAP.microsoft.com.Workaround.md) — fixes for `Get-AdminPowerAppEnvironment`/`Get-AdminFlow` network failures.
- [TestCLI Overview.md](<./TestCLI Overview.md>) — all scripts/docs in this folder.
