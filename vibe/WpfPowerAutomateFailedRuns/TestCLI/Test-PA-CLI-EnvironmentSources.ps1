<#
.SYNOPSIS
    Finds which Power Platform endpoints can list environments from THIS machine/network (Windows PowerShell 5.1).

.DESCRIPTION
    Use this when api.bap.microsoft.com is blocked, intercepted, or returns non-JSON (for example a proxy page
    that causes: Invalid JSON primitive). It signs in once and then tries every known way to obtain environment names:

      1. BAP admin cmdlet     Get-AdminPowerAppEnvironment            (api.bap.microsoft.com)  - what the other tests use
      2. BAP admin REST       .../scopes/admin/environments            (api.bap.microsoft.com)
      3. PowerApps REST       api.powerapps.com/.../environments       (user-visible environments)
      4. Flow REST            api.flow.microsoft.com/.../environments  (user-visible environments)
      5. Dataverse discovery  globaldisco.crm.dynamics.com             (environments that have Dataverse)
      6. Derived default      Default-<tenantId> from the token        (every tenant has a Default environment)

    Each source prints PASS/FAIL with the raw HTTP status, content type, body excerpt and environment names found.
    The script ends with a ready-to-paste command that runs the other tests with -EnvironmentName.
    Read-only. Output is color coded and saved as a colored HTML report in .\Logs.

.PARAMETER TenantID
    Optional tenant GUID for sign-in.

.EXAMPLE
    .\Test-PA-CLI-EnvironmentSources.ps1

.OUTPUTS
    Console output plus .\Logs\Test-PA-CLI-EnvironmentSources_<timestamp>.html. Exit code 0 if at least one source worked, else 1.

.NOTES
    Sources 3-5 return only environments the signed-in user can see, unlike the BAP admin listing which returns all.
    The token audiences/URLs for sources 3-5 follow the public Power Platform endpoints; whether your network
    allows them is exactly what this script tells you.
#>
[CmdletBinding()]
param([string]$TenantID)

$ErrorActionPreference = 'Stop'
$name = 'Test-PA-CLI-EnvironmentSources'
. (Join-Path $PSScriptRoot 'PA-CLI-Debug.ps1')

Initialize-PADebug
Show-PANetworkDiagnostics

# ---- module + sign-in ----
$module = 'Microsoft.PowerApps.Administration.PowerShell'
try { Import-Module $module -ErrorAction Stop -WarningAction SilentlyContinue }
catch { Write-PAError $_ "Import-Module $module"; Write-PALog ERR "Run: Install-Module $module -Scope CurrentUser -Force -AllowClobber"; exit 2 }
$ok = Invoke-Step 'Sign-in (Add-PowerAppsAccount)' {
    $p = @{}; if ($TenantID) { $p.TenantID = $TenantID }
    Add-PowerAppsAccount @p -ErrorAction Stop | Out-Null; $true
}
if (-not $ok) { [void](Complete-PATestSession -Name $name); exit 1 }
Show-PAToken

$found = @{}   # source name -> array of environment names

# Calls one REST source with a token for $Audience and extracts environment names from .value[].name
function Test-Source([string]$Label, [string]$Audience, [string]$Uri) {
    Write-PAHeader $Label
    $t = Get-PAToken $Audience
    if (-not $t) { Add-Result $Label $false "no token for $Audience"; return }
    Write-PALog HTTP "--> GET $Uri"
    $r = Invoke-PARawGet -Uri $Uri -Token $t
    if ($r.Error) { Add-Result $Label $false $r.Error; return }
    Write-PALog HTTP "<-- HTTP $($r.Status) $($r.StatusText) ContentType=$($r.ContentType) ($($r.Route))"
    Write-PALog BODY ("body ({0} chars):`n{1}" -f $r.Body.Length, (Format-PABody $r.Body))
    if ($r.Status -eq 407) { Add-Result $Label $false '407 proxy authentication required'; return }
    if (-not $r.Ok)        { Add-Result $Label $false "HTTP $($r.Status)"; return }
    if (-not $r.Json)      { Add-Result $Label $false "HTTP $($r.Status) but body is not JSON (proxy/HTML page?)"; return }
    # BAP/PowerApps/Flow return .value[].name ; Dataverse discovery returns .value[].UniqueName/FriendlyName
    $names = @($r.Json.value | ForEach-Object { if ($_.name) { $_.name } elseif ($_.EnvironmentId) { $_.EnvironmentId } })
    $script:found[$Label] = $names
    Add-Result $Label ($names.Count -gt 0) "$($names.Count) environment(s): $(($names | Select-Object -First 3) -join ', ')"
}

# 1. The module cmdlet (uses BAP)
$mod = Invoke-Step '1. Get-AdminPowerAppEnvironment (module, BAP)' {
    $e = @(Get-AdminPowerAppEnvironment -ErrorAction Stop)
    if ($e.Count -eq 0) { throw 'returned 0 environments' }
    $e
}
if ($mod) { $found['module'] = @($mod | ForEach-Object { $_.EnvironmentName }) }

# 2-5. Raw REST sources
Test-Source '2. BAP admin REST'          'https://service.powerapps.com/'        'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2016-11-01'
Test-Source '3. PowerApps REST'          'https://service.powerapps.com/'        'https://api.powerapps.com/providers/Microsoft.PowerApps/environments?api-version=2016-11-01'
Test-Source '4. Flow REST'               'https://service.flow.microsoft.com/'   'https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/environments?api-version=2016-11-01'
Test-Source '5. Dataverse global discovery' 'https://globaldisco.crm.dynamics.com/' 'https://globaldisco.crm.dynamics.com/api/discovery/v2.0/Instances'

# 6. Default environment name derived from the tenant id claim
Write-PAHeader '6. Derived Default environment'
$tok = Get-PAToken 'https://service.powerapps.com/'
if ($tok) {
    $tid = (ConvertFrom-PAJwt $tok).tid
    $default = "Default-$tid"
    $found['derived'] = @($default)
    Add-Result '6. Derived Default environment' $true $default
} else { Add-Result '6. Derived Default environment' $false 'no token' }

# ---- recommendation ----
Write-PAHeader 'Recommendation'
$best = $null
foreach ($k in 'module', '2. BAP admin REST', '3. PowerApps REST', '4. Flow REST', '5. Dataverse global discovery', 'derived') {
    if ($found.ContainsKey($k) -and $found[$k].Count -gt 0) { $best = $found[$k][0]; Write-PALog OK "Use environment from '$k': $best"; break }
}
if ($best) {
    Write-PALog INFO 'Run the other tests without the BAP listing:'
    foreach ($s in 'AdminFlow', 'AdminFlowOwnerRole', 'AdminPowerAppConnection', 'AdminPowerAppConnector') {
        Write-PALog INFO "  .\Test-PA-CLI-$s.ps1 -EnvironmentName '$best'"
    }
} else { Write-PALog ERR 'No source returned an environment. Check the network diagnostics and 407 messages above.' }

$code = Complete-PATestSession -Name $name
# Success = at least one way to get an environment name, even if some sources failed
if ($best) { exit 0 } else { exit 1 }
