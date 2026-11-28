# Debugging Power Automate Connections (How-To)

This guide shows how to fix each failure reported by **Settings → Test Connection** in
[WpfPowerAutomateFailedRuns.ps1](./WpfPowerAutomateFailedRuns.ps1) and how to check every likely cause.
Do the sections in order: each check depends on the one before it.

| Console message | Go to |
| --- | --- |
| `Running PowerShell 7.x (Core)` | [1. PowerShell edition](#1-powershell-edition) |
| `Execution policy is 'Restricted'/'AllSigned'` | [2. Execution policy](#2-execution-policy) |
| `<host> not reachable: ...` | [3. Network, proxy, TLS](#3-network-proxy-and-tls) |
| `Module ... is not installed` / `failed to import` | [4. Modules](#4-modules) |
| `Not signed in to Power Platform` | [5. Sign-in](#5-sign-in) |
| `Admin API call failed` / `0 environment(s) visible` | [6. Permissions](#6-permissions) |

> **Golden rule:** use **one Windows PowerShell 5.1 window** for everything: sign in, then start the
> inspector from that same window. Sign-in state is stored in the PowerShell process, so a sign-in done in
> a different window or in VS Code's terminal is not visible to the inspector.

---

## Example: the reported console output

```text
[X] login.microsoftonline.com not reachable
[X] api.bap.microsoft.com not reachable
[X] api.flow.microsoft.com not reachable
[X] www.powershellgallery.com not reachable
[OK] Module 'Microsoft.PowerApps.Administration.PowerShell' 2.0.198 loaded
[OK] Module 'Microsoft.PowerApps.PowerShell' 1.0.40 loaded
[X] Not signed in to Power Platform
```

What this means:

1. **The "not reachable" lines were very likely false alarms.** Older versions of the inspector
   opened a raw TCP connection to port 443. That bypasses the corporate proxy, so it fails on networks that
   only allow web traffic through a proxy. The modules installed from `www.powershellgallery.com` without
   trouble, which shows HTTPS works. The check now sends a real HTTPS request through your
   system proxy (the same way the PowerApps modules connect). Click **Test Connection** again; if hosts
   still fail, follow [section 3](#3-network-proxy-and-tls).
2. **"Not signed in" is expected** until you run `Add-PowerAppsAccount` in the same PowerShell process
   that runs the inspector. See [section 5](#5-sign-in).

The quickest fix to try:

```powershell
# Open "Windows PowerShell" (not PowerShell 7, not the VS Code terminal if it runs pwsh)
cd C:\Davis\vibe\Power-Automate\WpfPowerAutomateFailedRuns
Add-PowerAppsAccount                         # sign in when the prompt appears
.\WpfPowerAutomateFailedRuns.ps1 -Mode Live  # same window, so the sign-in is reused
```

---

## 1. PowerShell edition

The `Microsoft.PowerApps.*` modules support **Windows PowerShell 5.1** only.

```powershell
$PSVersionTable.PSEdition   # must be 'Desktop'
$PSVersionTable.PSVersion   # 5.1.x
```

Fix: start `powershell.exe` (blue icon), not `pwsh.exe`:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\WpfPowerAutomateFailedRuns.ps1 -Mode Live
```

In VS Code, select the **Windows PowerShell** profile in the terminal dropdown, or switch the
PowerShell extension session to *Windows PowerShell (x64)*.

---

## 2. Execution policy

```powershell
Get-ExecutionPolicy -List
```

Fix (current user only, no admin needed):

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

If a Group Policy enforces `MachinePolicy`/`UserPolicy`, you cannot override it. Use
`powershell.exe -ExecutionPolicy Bypass -File ...` for this session, or ask IT.

If files were downloaded (zip from the internet), unblock them:

```powershell
Get-ChildItem C:\Davis\vibe\Power-Automate\WpfPowerAutomateFailedRuns -Recurse | Unblock-File
```

---

## 3. Network, proxy, and TLS

### 3.1 Endpoints that must be reachable over HTTPS

| Host | Used for |
| --- | --- |
| `login.microsoftonline.com` | Entra ID (Azure AD) sign-in / tokens |
| `api.bap.microsoft.com` | Power Platform admin API (environments) |
| `api.flow.microsoft.com` | Power Automate API (flows, runs) |
| `api.powerapps.com` | Power Apps API (used by some module cmdlets) |
| `graph.microsoft.com` | Owner / user lookups |
| `www.powershellgallery.com` | Installing / updating modules only |

Government and China clouds use different hosts. Pass the matching `-Endpoint` to
`Add-PowerAppsAccount` (see [5.3](#53-sign-in-options)).

### 3.2 Test one endpoint by hand

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest https://login.microsoftonline.com -Method Head -UseBasicParsing -ProxyUseDefaultCredentials
```

| Result | Meaning |
| --- | --- |
| Any HTTP status (200, 302, 401, 403, 404, 405) | **Reachable.** The network is fine. |
| `502 Bad Gateway` / `504 Gateway Timeout` | Ambiguous: the reply may come from the **proxy** (it couldn't reach Microsoft) or from the service, which may just reject a bare `HEAD /`. If sign-in and `Get-AdminPowerAppEnvironment` work, ignore it. Otherwise check the `Server`/`Via` response headers or ask IT whether the proxy blocks the host. |
| `(407) Proxy Authentication Required` | Proxy needs credentials → [3.4](#34-proxy-requires-authentication-407) |
| `Unable to connect to the remote server` / timeout | Blocked or proxy not used → [3.3](#33-find-and-use-the-proxy) |
| `The remote name could not be resolved` | DNS problem → [3.5](#35-dns) |
| `Could not establish trust relationship for the SSL/TLS secure channel` | TLS inspection certificate → [3.6](#36-tls-version-and-ssl-inspection) |
| `The underlying connection was closed: An unexpected error occurred on a send` | TLS 1.2 not enabled → [3.6](#36-tls-version-and-ssl-inspection) |

### 3.3 Find and use the proxy

Windows has **two** proxy settings, and different tools read different ones:

```powershell
# 1) User / WinINET proxy (Internet Options) – used by PowerShell web cmdlets and the PowerApps modules
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' |
    Select-Object ProxyEnable, ProxyServer, ProxyOverride, AutoConfigURL

# 2) Machine / WinHTTP proxy – used by services and some system components
netsh winhttp show proxy

# Which proxy will .NET actually pick for a given URL?
$u = [Uri]'https://login.microsoftonline.com'
$p = [System.Net.WebRequest]::GetSystemWebProxy()
if ($p.IsBypassed($u)) { 'direct (no proxy)' } else { $p.GetProxy($u).AbsoluteUri }
```

If `AutoConfigURL` is set, a PAC script picks the proxy; download it to see the rules:

```powershell
(Invoke-WebRequest (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').AutoConfigURL -UseBasicParsing).Content
```

Make the current PowerShell session use the proxy explicitly (replace host/port):

```powershell
$proxy = New-Object System.Net.WebProxy('http://proxy.contoso.com:8080', $true)   # $true = bypass local
$proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
[System.Net.WebRequest]::DefaultWebProxy = $proxy
```

Run the lines above **in the same window** before `Add-PowerAppsAccount` and before starting the inspector.
To make it permanent, add them to your profile (`notepad $PROFILE`).

Copy the user proxy to WinHTTP if a component only reads WinHTTP (needs an elevated prompt):

```powershell
netsh winhttp import proxy source=ie
# undo:  netsh winhttp reset proxy
```

### 3.4 Proxy requires authentication (407)

1. First try your Windows login (works with most NTLM/Kerberos proxies):
   `$proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials`
2. If the proxy uses its own accounts:
   ```powershell
   [System.Net.WebRequest]::DefaultWebProxy.Credentials = (Get-Credential -Message 'Proxy credentials').GetNetworkCredential()
   ```
3. If neither works, ask IT to **allow-list the hosts in [3.1](#31-endpoints-that-must-be-reachable-over-https)**
   without authentication. The sign-in library may not pass proxy credentials on every request.

### 3.5 DNS

```powershell
Resolve-DnsName login.microsoftonline.com
Resolve-DnsName api.bap.microsoft.com
ipconfig /flushdns
```

If names don't resolve, check the VPN connection, the DNS servers (`Get-DnsClientServerAddress`), and the
`hosts` file (`C:\Windows\System32\drivers\etc\hosts`).

### 3.6 TLS version and SSL inspection

Windows PowerShell 5.1 can default to TLS 1.0, which Microsoft rejects. Enable TLS 1.2 for the session
(the inspector does this automatically during Test Connection):

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
```

Permanent machine-wide fix (elevated, then reboot or restart PowerShell):

```powershell
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'             -Name SchUseStrongCrypto -Value 1 -Type DWord
Set-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -Name SchUseStrongCrypto -Value 1 -Type DWord
```

If your company decrypts HTTPS traffic (Zscaler, Netskope, Palo Alto, and similar), the company root certificate
must be in **Trusted Root Certification Authorities**. Check who issued the certificate you are getting:

```powershell
$req = [Net.HttpWebRequest]::Create('https://login.microsoftonline.com'); $req.Method = 'HEAD'
try { $req.GetResponse().Close() } catch {}
$req.ServicePoint.Certificate | Format-List Subject, Issuer
```

If `Issuer` is your company's CA rather than Microsoft/DigiCert, IT must deploy that root certificate (or
exclude the hosts in [3.1](#31-endpoints-that-must-be-reachable-over-https) from inspection).

### 3.7 VPN, firewall, and security software

- Connect to (or disconnect from) the corporate VPN and test again. Split-tunnel VPNs often send
  Microsoft 365 traffic directly.
- Check whether endpoint security blocks `powershell.exe` from going online (Defender for Endpoint network
  protection, third-party firewalls). The event log or the security agent's console will show blocks.
- Home or guest networks with captive portals: open a browser and accept the portal first.

---

## 4. Modules

```powershell
Get-Module Microsoft.PowerApps* -ListAvailable | Sort-Object Name, Version | Format-Table Name, Version, Path
```

| Problem | Fix |
| --- | --- |
| Not installed | `Install-Module Microsoft.PowerApps.Administration.PowerShell, Microsoft.PowerApps.PowerShell -Scope CurrentUser -Force -AllowClobber` |
| `Install-Module` fails / no PSGallery | `[Net.ServicePointManager]::SecurityProtocol = 'Tls12'`, then `Install-PackageProvider NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force`, then `Set-PSRepository PSGallery -InstallationPolicy Trusted` |
| Old or several versions | `Uninstall-Module Microsoft.PowerApps.Administration.PowerShell -AllVersions -Force` then reinstall; or `Update-Module Microsoft.PowerApps.*` |
| `failed to import` / assembly already loaded | Start a **fresh** Windows PowerShell window and import the PowerApps modules **before** `Az`, `AzureAD`, `MSOnline`, `ExchangeOnlineManagement`, or `Microsoft.Graph`. These modules ship different versions of the same sign-in library (MSAL/ADAL), and the version loaded first wins. |
| Installed but blocked files | `Get-ChildItem (Split-Path (Get-Module Microsoft.PowerApps.Administration.PowerShell -ListAvailable)[0].Path) -Recurse \| Unblock-File` |
| No internet on this machine | On a connected PC: `Save-Module Microsoft.PowerApps.Administration.PowerShell, Microsoft.PowerApps.PowerShell -Path C:\Temp\Modules`, then copy the folders to `$HOME\Documents\WindowsPowerShell\Modules` |

---

## 5. Sign-in

### 5.1 Why the inspector says "Not signed in"

`Add-PowerAppsAccount` keeps the sign-in in a variable inside the current PowerShell process
(`$global:currentSession`). The inspector can only see it when both run **in the same process**:

| How you started the inspector | Sees an earlier `Add-PowerAppsAccount`? |
| --- | --- |
| `.\WpfPowerAutomateFailedRuns.ps1` typed in the window where you signed in | ✅ Yes |
| `powershell.exe -File .\WpfPowerAutomateFailedRuns.ps1` | ❌ No (new process) |
| Double-click / *Run with PowerShell* / VS Code *Run* (F5) in a different terminal | ❌ No |
| Signed in in PowerShell 7 or in another window | ❌ No |

While the inspector window is open its console is busy, so you can't type `Add-PowerAppsAccount` there.
Close the inspector, sign in, and start it again from the same window.

### 5.2 Verify the sign-in

```powershell
$global:currentSession | Format-List loggedIn, upn, tenantId, expiresOn
Get-AdminPowerAppEnvironment | Select-Object DisplayName, EnvironmentName -First 5
```

### 5.3 Sign-in options

```powershell
# Interactive (browser / account picker). Supports MFA.
Add-PowerAppsAccount

# A specific tenant (guest accounts, multiple tenants)
Add-PowerAppsAccount -TenantID '00000000-0000-0000-0000-000000000000'

# Sovereign clouds: prod (default), usgov (GCC), usgovhigh (GCC High), dod, china
Add-PowerAppsAccount -Endpoint usgov

# Username + password (fails if the account needs MFA or Conditional Access device checks)
$cred = Get-Credential
Add-PowerAppsAccount -Username $cred.UserName -Password $cred.Password

# Unattended: service principal (app registration) with a secret or certificate
Add-PowerAppsAccount -TenantID '<tenant-guid>' -ApplicationId '<app-id>' -ClientSecret '<secret>'
Add-PowerAppsAccount -TenantID '<tenant-guid>' -ApplicationId '<app-id>' -CertificateThumbprint '<thumbprint>'

# Start over
Remove-PowerAppsAccount
```

A service principal must first be registered as a Power Platform management app **by a Power Platform
admin** (one-time, interactive):

```powershell
Add-PowerAppsAccount
New-PowerAppManagementApp -ApplicationId '<app-id>'
```

### 5.4 Common sign-in errors

| Error / symptom | Cause | Fix |
| --- | --- | --- |
| No prompt appears | The prompt opened behind other windows | Alt+Tab or check the taskbar; or sign in again |
| `AADSTS50076` / `AADSTS50079` | MFA required | Use interactive `Add-PowerAppsAccount` (not `-Username/-Password`) |
| `AADSTS50020` | Account doesn't exist in that tenant (guest/B2B) | Add `-TenantID '<resource tenant>'` |
| `AADSTS53003` / `AADSTS53000` | Conditional Access: device not compliant / location blocked | Use a managed/compliant device or the corporate network; ask IT |
| `AADSTS700016` | App ID not found in tenant (service principal) | Check `-ApplicationId`/`-TenantID`; app must exist in that tenant |
| `AADSTS7000215` | Wrong client secret | Use the secret **value**, not the secret ID; check expiry |
| `AADSTS65001` | Consent not granted | Admin grants consent, or sign in once as admin |
| Sign-in works but token expires mid-session | Token lifetime (~1 hour) | Run `Add-PowerAppsAccount` again |
| Sign-in hangs behind proxy | Sign-in library cannot reach `login.microsoftonline.com` | Fix [section 3](#3-network-proxy-and-tls) first |

---

## 6. Permissions

`Get-AdminPowerAppEnvironment` and `Get-AdminFlow` are **admin** cmdlets. The signed-in account needs one of:

- **Power Platform Administrator** (Entra role) – all environments
- **Dynamics 365 Administrator** or **Global Administrator** – all environments
- **Environment Admin** (security role inside an environment) – only those environments

| Symptom | Fix |
| --- | --- |
| `403 Forbidden` / `Unauthorized` | Assign one of the roles above; then `Remove-PowerAppsAccount; Add-PowerAppsAccount` |
| `0 environment(s) visible` | Account has no admin rights anywhere; non-admins can use `Get-PowerAppEnvironment` / `Get-Flow` (own items only) |
| Role just assigned but still denied | Role changes can take up to an hour; sign out and in again |
| PIM (Privileged Identity Management) | Activate the role in the Entra portal first, then sign in again |

Check which roles you have: Entra admin center → **Users → (you) → Assigned roles**, or Power Platform admin
center → **Environments → (env) → Settings → Users + permissions → Security roles**.

---

## 7. Full self-check script

Paste into a **Windows PowerShell 5.1** window. It runs every check in order and stops at the first one that fails.

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
"PowerShell : $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
"ExecPolicy : $(Get-ExecutionPolicy)"

$p = [System.Net.WebRequest]::GetSystemWebProxy(); $p.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
foreach ($h in 'login.microsoftonline.com','api.bap.microsoft.com','api.flow.microsoft.com','api.powerapps.com','graph.microsoft.com') {
    $u = [Uri]"https://$h/"
    $route = if ($p.IsBypassed($u)) { 'direct' } else { $p.GetProxy($u).Authority }
    try {
        $r = Invoke-WebRequest $u -Method Head -UseBasicParsing -TimeoutSec 10 -ProxyUseDefaultCredentials -ErrorAction Stop
        "OK   $h ($($r.StatusCode), $route)"
    } catch {
        if ($_.Exception.Response) { "OK   $h ($([int]$_.Exception.Response.StatusCode), $route)" }
        else { "FAIL $h ($route): $($_.Exception.Message)" }
    }
}

Get-Module Microsoft.PowerApps* -ListAvailable | Select-Object Name, Version
Import-Module Microsoft.PowerApps.Administration.PowerShell, Microsoft.PowerApps.PowerShell -ErrorAction Stop

if (-not ($global:currentSession -and $global:currentSession.loggedIn)) { Add-PowerAppsAccount }
"Signed in  : $($global:currentSession.upn)  tenant $($global:currentSession.tenantId)"

$envs = @(Get-AdminPowerAppEnvironment -ErrorAction Stop)
"Environments visible: $($envs.Count)"
$envs | Select-Object DisplayName, EnvironmentName -First 10

# Everything OK? Start the inspector in this same window:
# .\WpfPowerAutomateFailedRuns.ps1 -Mode Live
```

---

## 8. Still stuck? Collect this before asking for help

```powershell
$PSVersionTable
Get-Module Microsoft.PowerApps* -ListAvailable | Format-Table Name, Version, Path
netsh winhttp show proxy
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select-Object ProxyEnable, ProxyServer, AutoConfigURL
$Error[0] | Format-List * -Force            # full details of the last error
```

Also use the inspector console's **Copy** button to grab the Test Connection output.
**Remove tenant IDs, user names, and secrets before sharing.**
