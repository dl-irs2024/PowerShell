<#
.SYNOPSIS
    Live test of Get-AdminPowerAppConnector (Windows PowerShell 5.1, command line only).

.DESCRIPTION
    1. Signs in and lists environments (shows the environment owner).
    2. Finds the first environment that has custom connectors (or uses -EnvironmentName).
    3. Tests Get-AdminPowerAppConnector: count, name/display-name fields and the connector owner (CreatedBy).
    An environment with zero custom connectors is reported as PASS (an empty result is valid). Errors are logged in
    full; output is color coded and saved as a colored HTML report in .\Logs. Read-only.

    Endpoints used: login.microsoftonline.com, api.bap.microsoft.com (environments), api.powerapps.com (connectors).

.PARAMETER EnvironmentName
    Environment to test. Default: first environment that has custom connectors. If the BAP listing fails, this name is used directly.

.PARAMETER TenantID
    Optional tenant GUID for sign-in.

.PARAMETER Top
    Maximum connectors printed (default 10).

.EXAMPLE
    .\Test-PA-CLI-AdminPowerAppConnector.ps1

.OUTPUTS
    Console output plus .\Logs\Test-PA-CLI-AdminPowerAppConnector_<timestamp>.html. Exit code: 0 pass, 1 failure, 2 module missing.

.NOTES
    Requires Microsoft.PowerApps.Administration.PowerShell and an admin account. Shared logic: PA-CLI-Debug.ps1.
#>
[CmdletBinding()]
param([string]$EnvironmentName, [string]$TenantID, [int]$Top = 10)

$ErrorActionPreference = 'Stop'
$name = 'Test-PA-CLI-AdminPowerAppConnector'
. (Join-Path $PSScriptRoot 'PA-CLI-Debug.ps1')

$session = Start-PATestSession -TenantID $TenantID -EnvironmentName $EnvironmentName
if ($session -eq 'MODULE') { exit 2 }
if (-not $session) { [void](Complete-PATestSession -Name $name); exit 1 }
$envs = @($session)
if ($EnvironmentName) { $envs = @($envs | Where-Object { $_.EnvironmentName -eq $EnvironmentName }) }
if ($envs.Count -eq 0) { Add-Result 'Select environment' $false "Not found: $EnvironmentName"; exit (Complete-PATestSession -Name $name) }

Write-PAHeader 'Find an environment with custom connectors'
$connectors = @(); $envObj = $null; $anyOk = $false
foreach ($e in $envs) {
    try { $connectors = @(Get-AdminPowerAppConnector -EnvironmentName $e.EnvironmentName -ErrorAction Stop); $anyOk = $true }
    catch { Write-PAError $_ "Get-AdminPowerAppConnector in $($e.DisplayName)"; continue }
    Write-PALog INFO "$($e.DisplayName): $($connectors.Count) custom connector(s)"
    if ($connectors.Count -gt 0) { $envObj = $e; break }
}
if (-not $anyOk) { Add-Result 'Get-AdminPowerAppConnector' $false 'Failed in every environment tried'; exit (Complete-PATestSession -Name $name) }
if (-not $envObj) {
    $envObj = $envs[0]
    Add-Result 'Get-AdminPowerAppConnector' $true "0 custom connectors in $($envObj.DisplayName)"
} else {
    Add-Result "Get-AdminPowerAppConnector -EnvironmentName $($envObj.EnvironmentName)" $true "$($connectors.Count) connector(s)"
}
Write-PALog INFO ("Environment: {0} ({1})" -f $envObj.DisplayName, $envObj.EnvironmentName)
Write-PALog INFO ("Environment owner (CreatedBy): {0}" -f $envObj.CreatedBy.userPrincipalName)

foreach ($c in ($connectors | Select-Object -First $Top)) {
    Write-PALog INFO ("  {0} | {1} | Owner={2}" -f $c.ConnectorName, $c.DisplayName, $c.CreatedBy.userPrincipalName)
}
if ($connectors.Count -gt 0) {
    $c = $connectors[0]
    Add-Result 'Connector has name + display name' ([bool]($c.ConnectorName -and $c.DisplayName)) "$($c.ConnectorName) / $($c.DisplayName)"
    Add-Result 'Connector owner present (CreatedBy)' ([bool]$c.CreatedBy) "$($c.CreatedBy.userPrincipalName)"
}

exit (Complete-PATestSession -Name $name)
