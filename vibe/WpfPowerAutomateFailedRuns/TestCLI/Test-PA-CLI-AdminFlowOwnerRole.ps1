<#
.SYNOPSIS
    Live test of Get-AdminFlowOwnerRole (Windows PowerShell 5.1, command line only).

.DESCRIPTION
    1. Signs in and lists environments (shows the environment owner).
    2. Finds the first environment that contains flows (or uses -EnvironmentName).
    3. For up to -Top flows calls Get-AdminFlowOwnerRole and checks that roles come back and that one has RoleType 'Owner'.
    Errors are logged in full (exception chain, HTTP status/body, 407 detection); output is color coded and saved
    as a colored HTML report in .\Logs. Read-only.

    Endpoints used: login.microsoftonline.com, api.bap.microsoft.com (environments), api.flow.microsoft.com (flows, roles).

.PARAMETER EnvironmentName
    Environment to test. Default: first environment that has flows. If the BAP listing fails, this name is used directly.

.PARAMETER TenantID
    Optional tenant GUID for sign-in.

.PARAMETER Top
    Number of flows whose owner roles are tested (default 3).

.EXAMPLE
    .\Test-PA-CLI-AdminFlowOwnerRole.ps1 -Top 5

.OUTPUTS
    Console output plus .\Logs\Test-PA-CLI-AdminFlowOwnerRole_<timestamp>.html. Exit code: 0 pass, 1 failure, 2 module missing.

.NOTES
    Requires Microsoft.PowerApps.Administration.PowerShell and an admin account. Shared logic: PA-CLI-Debug.ps1.
#>
[CmdletBinding()]
param([string]$EnvironmentName, [string]$TenantID, [int]$Top = 3)

$ErrorActionPreference = 'Stop'
$name = 'Test-PA-CLI-AdminFlowOwnerRole'
. (Join-Path $PSScriptRoot 'PA-CLI-Debug.ps1')

$session = Start-PATestSession -TenantID $TenantID -EnvironmentName $EnvironmentName
if ($session -eq 'MODULE') { exit 2 }
if (-not $session) { [void](Complete-PATestSession -Name $name); exit 1 }
$envs = @($session)
if ($EnvironmentName) { $envs = @($envs | Where-Object { $_.EnvironmentName -eq $EnvironmentName }) }
if ($envs.Count -eq 0) { Add-Result 'Select environment' $false "Not found: $EnvironmentName"; exit (Complete-PATestSession -Name $name) }

# Find the first environment that has flows. A failure in one environment (e.g. no permission) is not fatal.
Write-PAHeader 'Find an environment with flows'
$flows = @(); $envObj = $null
foreach ($e in $envs) {
    try { $flows = @(Get-AdminFlow -EnvironmentName $e.EnvironmentName -ErrorAction Stop) }
    catch { Write-PAError $_ "Get-AdminFlow in $($e.DisplayName)"; continue }
    Write-PALog INFO "$($e.DisplayName): $($flows.Count) flow(s)"
    if ($flows.Count -gt 0) { $envObj = $e; break }
}
if (-not $envObj) { Add-Result 'Find environment with flows' $false 'No flows found'; exit (Complete-PATestSession -Name $name) }
Write-PALog INFO ("Environment: {0} ({1})" -f $envObj.DisplayName, $envObj.EnvironmentName)
Write-PALog INFO ("Environment owner (CreatedBy): {0}" -f $envObj.CreatedBy.userPrincipalName)
Add-Result 'Get environment + flows' $true "$($flows.Count) flow(s)"

foreach ($f in ($flows | Select-Object -First $Top)) {
    Write-PALog INFO ("Flow: {0} ({1}) creator={2}" -f $f.DisplayName, $f.FlowName, $f.CreatedBy.userId)
    $roles = Invoke-Step "Get-AdminFlowOwnerRole -FlowName $($f.FlowName)" {
        @(Get-AdminFlowOwnerRole -EnvironmentName $envObj.EnvironmentName -FlowName $f.FlowName -ErrorAction Stop)
    }
    if ($null -eq $roles) { continue }
    Add-Result "Owner roles returned ($($f.DisplayName))" ($roles.Count -gt 0) "$($roles.Count) role(s)"
    foreach ($r in $roles) {
        Write-PALog INFO ("    {0} | PrincipalType={1} | PrincipalObjectId={2}" -f $r.RoleType, $r.PrincipalType, $r.PrincipalObjectId)
    }
    $owner = $roles | Where-Object { $_.RoleType -eq 'Owner' } | Select-Object -First 1
    Add-Result "Has Owner role ($($f.DisplayName))" ([bool]$owner) $(if ($owner) { $owner.PrincipalObjectId } else { 'none' })
}

exit (Complete-PATestSession -Name $name)
