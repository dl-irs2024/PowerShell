<#
.SYNOPSIS
    Live test of Get-AdminFlow (Windows PowerShell 5.1, command line only).

.DESCRIPTION
    Signs in to Power Platform, lists environments (and their owner), then tests Get-AdminFlow:
      1. Sign-in (Add-PowerAppsAccount)
      2. Get-AdminPowerAppEnvironment and the environment owner (CreatedBy)
      3. Get-AdminFlow for the whole environment (count, names, flow owner = CreatedBy.userId)
      4. Get-AdminFlow -FlowName for a single flow
    Every step has error checking; failures are logged in full (exception chain, HTTP status/body, 407 detection)
    and the script continues where possible. All output is color coded and saved as a colored HTML report in
    .\Logs. Read-only: nothing is changed in the tenant.

    Endpoints used: login.microsoftonline.com (sign-in), api.bap.microsoft.com (environment list),
    api.flow.microsoft.com (flows). See API.BAP.microsoft.com.Workaround.md if the BAP host is a problem.

.PARAMETER EnvironmentName
    Environment to test (for example Default-<tenantGuid> or a GUID). Default: the first environment returned.
    If the BAP environment listing fails, this name is used directly so the flow test can still run.

.PARAMETER TenantID
    Optional tenant GUID passed to Add-PowerAppsAccount.

.PARAMETER Top
    Maximum number of flows to print (default 5).

.EXAMPLE
    .\Test-PA-CLI-AdminFlow.ps1
    Interactive sign-in, tests the first environment.

.EXAMPLE
    .\Test-PA-CLI-AdminFlow.ps1 -EnvironmentName Default-00000000-0000-0000-0000-000000000000 -Top 10

.OUTPUTS
    Console output plus .\Logs\Test-PA-CLI-AdminFlow_<timestamp>.html. Exit code: 0 all passed, 1 any failure, 2 module missing.

.NOTES
    Requires: Microsoft.PowerApps.Administration.PowerShell and a Power Platform admin (or Environment Admin) account.
    Shared logic lives in PA-CLI-Debug.ps1.
#>
[CmdletBinding()]
param([string]$EnvironmentName, [string]$TenantID, [int]$Top = 5)

$ErrorActionPreference = 'Stop'
$name = 'Test-PA-CLI-AdminFlow'
. (Join-Path $PSScriptRoot 'PA-CLI-Debug.ps1')   # logging, HTTP tracing, diagnostics, Add-Result/Invoke-Step

# ---- Steps 1-2: sign in and list environments ----
$session = Start-PATestSession -TenantID $TenantID -EnvironmentName $EnvironmentName
if ($session -eq 'MODULE') { exit 2 }
if (-not $session) { [void](Complete-PATestSession -Name $name); exit 1 }
$envs = @($session)

# Pick the environment under test
if (-not $EnvironmentName) { $EnvironmentName = $envs[0].EnvironmentName }
$envObj = $envs | Where-Object { $_.EnvironmentName -eq $EnvironmentName } | Select-Object -First 1
if (-not $envObj) { Add-Result 'Select environment' $false "Not found: $EnvironmentName"; exit (Complete-PATestSession -Name $name) }
Write-PALog INFO ("Environment: {0} ({1})" -f $envObj.DisplayName, $EnvironmentName)
Write-PALog INFO ("Environment owner (CreatedBy): {0}" -f $envObj.CreatedBy.userPrincipalName)
if ($envObj.CreatedBy) { Add-Result 'Get environment owner' $true ("CreatedBy=" + $envObj.CreatedBy.displayName) }
else { Write-PALog WARN 'Environment owner skipped: no CreatedBy data (environment came from -EnvironmentName, not from BAP).' }

# ---- Step 3: Get-AdminFlow for the environment ----
$flows = Invoke-Step "Get-AdminFlow -EnvironmentName $EnvironmentName" {
    @(Get-AdminFlow -EnvironmentName $EnvironmentName -ErrorAction Stop)
}
if ($null -ne $flows) {
    Add-Result 'Flow count' $true "$($flows.Count) flow(s)"
    $flows | Select-Object -First $Top | ForEach-Object {
        Write-PALog INFO ("  {0} | {1} | Enabled={2} | OwnerId={3}" -f $_.FlowName, $_.DisplayName, $_.Enabled, $_.CreatedBy.userId)
    }
    if ($flows.Count -gt 0) {
        $f = $flows[0]
        Add-Result 'Flow has FlowName/DisplayName' ([bool]($f.FlowName -and $f.DisplayName)) $f.DisplayName
        Add-Result 'Flow owner present (CreatedBy.userId)' ([bool]$f.CreatedBy.userId) "$($f.CreatedBy.userId)"

        # ---- Step 4: single-flow lookup ----
        [void](Invoke-Step "Get-AdminFlow -FlowName $($f.FlowName)" {
            $one = Get-AdminFlow -EnvironmentName $EnvironmentName -FlowName $f.FlowName -ErrorAction Stop
            if (-not $one) { throw 'Single flow lookup returned nothing.' }
        })
    }
}

exit (Complete-PATestSession -Name $name)
