<#
.SYNOPSIS
    Live test of Get-AdminPowerAppConnection (Windows PowerShell 5.1, command line only).

.DESCRIPTION
    1. Signs in and lists environments (shows the environment owner).
    2. Finds the first environment that has connections (or uses -EnvironmentName).
    3. Tests Get-AdminPowerAppConnection: count, name/connector fields, connection owner (CreatedBy), and the
       -ConnectorNameFilter option.
    An environment with zero connections is reported as PASS (an empty result is valid). Errors are logged in full;
    output is color coded and saved as a colored HTML report in .\Logs. Read-only.

    Endpoints used: login.microsoftonline.com, api.bap.microsoft.com (environments), api.powerapps.com (connections).

.PARAMETER EnvironmentName
    Environment to test. Default: first environment that has connections. If the BAP listing fails, this name is used directly.

.PARAMETER TenantID
    Optional tenant GUID for sign-in.

.PARAMETER Top
    Maximum connections printed (default 10).

.EXAMPLE
    .\Test-PA-CLI-AdminPowerAppConnection.ps1 -EnvironmentName Default-00000000-0000-0000-0000-000000000000

.OUTPUTS
    Console output plus .\Logs\Test-PA-CLI-AdminPowerAppConnection_<timestamp>.html. Exit code: 0 pass, 1 failure, 2 module missing.

.NOTES
    Requires Microsoft.PowerApps.Administration.PowerShell and an admin account. Shared logic: PA-CLI-Debug.ps1.
#>
[CmdletBinding()]
param([string]$EnvironmentName, [string]$TenantID, [int]$Top = 10)

$ErrorActionPreference = 'Stop'
$name = 'Test-PA-CLI-AdminPowerAppConnection'
. (Join-Path $PSScriptRoot 'PA-CLI-Debug.ps1')

$session = Start-PATestSession -TenantID $TenantID -EnvironmentName $EnvironmentName
if ($session -eq 'MODULE') { exit 2 }
if (-not $session) { [void](Complete-PATestSession -Name $name); exit 1 }
$envs = @($session)
if ($EnvironmentName) { $envs = @($envs | Where-Object { $_.EnvironmentName -eq $EnvironmentName }) }
if ($envs.Count -eq 0) { Add-Result 'Select environment' $false "Not found: $EnvironmentName"; exit (Complete-PATestSession -Name $name) }

# Look for an environment with connections; $anyOk tracks whether the cmdlet worked at all
Write-PAHeader 'Find an environment with connections'
$conns = @(); $envObj = $null; $anyOk = $false
foreach ($e in $envs) {
    try { $conns = @(Get-AdminPowerAppConnection -EnvironmentName $e.EnvironmentName -ErrorAction Stop); $anyOk = $true }
    catch { Write-PAError $_ "Get-AdminPowerAppConnection in $($e.DisplayName)"; continue }
    Write-PALog INFO "$($e.DisplayName): $($conns.Count) connection(s)"
    if ($conns.Count -gt 0) { $envObj = $e; break }
}
if (-not $anyOk) { Add-Result 'Get-AdminPowerAppConnection' $false 'Failed in every environment tried'; exit (Complete-PATestSession -Name $name) }
if (-not $envObj) {
    $envObj = $envs[0]
    Add-Result 'Get-AdminPowerAppConnection' $true "0 connections in $($envObj.DisplayName)"
} else {
    Add-Result "Get-AdminPowerAppConnection -EnvironmentName $($envObj.EnvironmentName)" $true "$($conns.Count) connection(s)"
}
Write-PALog INFO ("Environment: {0} ({1})" -f $envObj.DisplayName, $envObj.EnvironmentName)
Write-PALog INFO ("Environment owner (CreatedBy): {0}" -f $envObj.CreatedBy.userPrincipalName)

foreach ($c in ($conns | Select-Object -First $Top)) {
    Write-PALog INFO ("  {0} | {1} | Owner={2} ({3})" -f $c.ConnectionName, $c.ConnectorName, $c.CreatedBy.userPrincipalName, $c.CreatedBy.id)
}
if ($conns.Count -gt 0) {
    $c = $conns[0]
    Add-Result 'Connection has name + connector' ([bool]($c.ConnectionName -and $c.ConnectorName)) "$($c.ConnectionName) / $($c.ConnectorName)"
    Add-Result 'Connection owner present (CreatedBy)' ([bool]$c.CreatedBy) "$($c.CreatedBy.userPrincipalName)"
    [void](Invoke-Step "Get-AdminPowerAppConnection -ConnectorNameFilter $($c.ConnectorName)" {
        $f = @(Get-AdminPowerAppConnection -EnvironmentName $envObj.EnvironmentName -ConnectorNameFilter $c.ConnectorName -ErrorAction Stop)
        if ($f.Count -eq 0) { throw 'Filter returned nothing.' }
    })
}

exit (Complete-PATestSession -Name $name)
