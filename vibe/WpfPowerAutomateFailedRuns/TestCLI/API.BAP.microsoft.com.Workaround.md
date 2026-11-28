# api.bap.microsoft.com – Workaround Guide

`api.bap.microsoft.com` is the **Business Application Platform (BAP)** admin API. In the `Microsoft.PowerApps.Administration.PowerShell` module it backs `Get-AdminPowerAppEnvironment` (environment list and environment owner). Every `Test-PA-CLI-*` script starts with that call, so if BAP is blocked or intercepted the tests stop at the first step.

> **Status of the evidence.** The root cause observed on the affected machine is a **proxy returning a non-JSON reply** (`Invalid JSON primitive: IRS.`). A direct probe to `api.bap.microsoft.com` through the proxy returned a normal JSON `401` (`MissingAuthorizationHeaderAndClientCertificate`), so the host is **reachable**; the module's own request is what gets the bad reply. Sections 1–2 fix that. Sections 3–6 are true *workarounds* for when BAP itself cannot be used. The workaround endpoints in sections 4–5 are standard public Power Platform URLs but were **not verified from your network** – `Test-PA-CLI-EnvironmentSources.ps1` tests them live.

---

## 1. Diagnose first (what is actually coming back)

Run any test script. The shared helper `PA-CLI-Debug.ps1`:

- wraps `Invoke-WebRequest`, `Invoke-RestMethod` and `ConvertFrom-Json` and logs every request/response the module makes;
- prints the **exact text** the JSON parser choked on (between `<<<START` and `<<<END>>>`);
- flags HTTP **407** and prints the `Proxy-Authenticate` header;
- makes a **direct call** with the module's token so you can compare module vs. raw.

Real example of the failure signature (captured by the trace; a proxy asking for NTLM credentials):

```text
10:10:41 [HTTP] --> Invoke-WebRequest Head https://login.microsoftonline.com/
10:10:41 [HDR ]     req header  Authorization : Bearer abcdefgh...<redacted>
10:10:41 [ERR ] !!! Invoke-WebRequest failed: System.Net.WebException: The remote server returned an error: (407) Proxy Authentication Required.
10:10:41 [BODY]     ErrorDetails (server body):
10:10:41 [BODY] IRS Proxy Authentication Required.
10:10:41 [ERR ]     HTTP status: 407 IRSauthenticationrequired
10:10:41 [ERR ]     *** 407 Proxy Authentication Required - the proxy rejected/lacked our credentials ***
10:10:41 [HDR ]     resp header Content-Type : text/html
10:10:41 [WARN]     Proxy-Authenticate: NTLM,Basic realm="DS"
```

If you see a `407`, or a body that is HTML/plain text, you have a **proxy authentication** problem, not a BAP outage.

---

## 2. Fix: give the PowerApps module proxy credentials (most likely fix)

The module sends requests with no proxy credentials. With an authenticating proxy that yields the text/HTML page seen above. Set the .NET default proxy **before** importing/using the module:

```powershell
# Windows PowerShell 5.1
[System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

Import-Module Microsoft.PowerApps.Administration.PowerShell -WarningAction SilentlyContinue
Add-PowerAppsAccount
Get-AdminPowerAppEnvironment | Select-Object DisplayName, EnvironmentName
```

`Initialize-PADebug` in `PA-CLI-Debug.ps1` already does this for every test script. If the trace still shows a 407 after this, the module may use a different HTTP stack for that call; send the trace output and check:

```powershell
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select ProxyEnable, ProxyServer, AutoConfigURL
netsh winhttp show proxy
# Optional: use the WinHTTP proxy settings as the IE ones
# netsh winhttp import proxy source=ie        (run elevated)
```

Ask the network team to allow (and not TLS-inspect/rewrite) these hosts:

| Host | Used for |
|---|---|
| `login.microsoftonline.com` | sign-in |
| `api.bap.microsoft.com` | environment list/owner (`Get-AdminPowerAppEnvironment`) |
| `api.flow.microsoft.com` | flows (`Get-AdminFlow`, `Get-AdminFlowOwnerRole`) |
| `api.powerapps.com` | connections/connectors (`Get-AdminPowerAppConnection`, `Get-AdminPowerAppConnector`) |

---

## 3. Workaround A – skip the environment listing: supply `-EnvironmentName`

Only the **environment list** needs BAP. The flow, connection and connector cmdlets take an environment name and call other hosts. So if you already know the name, every test accepts it and carries on when BAP fails:

```powershell
.\Test-PA-CLI-AdminFlow.ps1                  -EnvironmentName 'Default-<tenantGuid>'
.\Test-PA-CLI-AdminFlowOwnerRole.ps1         -EnvironmentName 'Default-<tenantGuid>'
.\Test-PA-CLI-AdminPowerAppConnection.ps1    -EnvironmentName 'Default-<tenantGuid>'
.\Test-PA-CLI-AdminPowerAppConnector.ps1     -EnvironmentName 'Default-<tenantGuid>'
```

Where to get the name without BAP:

- **Default environment:** `Default-<tenant id>` (the tenant id is in your sign-in token, `tid` claim – shown by `Show-PAToken`; the sources script derives it for you).
- **Power Platform admin center** (`https://admin.powerplatform.microsoft.com` → Environments → open one → *Environment ID*) – a browser may be allowed when PowerShell is not.
- **Maker portal URL:** `https://make.powerapps.com/environments/<EnvironmentName>/home`.
- A flow URL in Power Automate: `.../environments/<EnvironmentName>/flows/<flowId>`.

When the BAP call fails and `-EnvironmentName` is given, the script logs a yellow warning and uses a stub environment object. Consequence: the **environment owner** line is blank (that data comes only from BAP).

---

## 4. Workaround B – list environments from other hosts

`Test-PA-CLI-EnvironmentSources.ps1` signs in once and tries every source, then prints a ready-to-paste command:

| # | Source | Host | Returns |
|---|---|---|---|
| 1 | `Get-AdminPowerAppEnvironment` | api.bap.microsoft.com | all environments (admin) |
| 2 | BAP admin REST | api.bap.microsoft.com | same, raw (shows exactly what comes back) |
| 3 | PowerApps REST `/providers/Microsoft.PowerApps/environments` | api.powerapps.com | environments the user can see |
| 4 | Flow REST `/providers/Microsoft.ProcessSimple/environments` | api.flow.microsoft.com | environments the user can see |
| 5 | Dataverse global discovery `/api/discovery/v2.0/Instances` | globaldisco.crm.dynamics.com | environments with Dataverse |
| 6 | Derived `Default-<tid>` | (none – from token) | the Default environment |

Manual one-liner for source 4 using the module's token:

```powershell
$t = Get-JwtToken -Audience 'https://service.flow.microsoft.com/'      # from Microsoft.PowerApps.AuthModule
$h = @{ Authorization = "Bearer $t" }
(Invoke-RestMethod -Uri 'https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/environments?api-version=2016-11-01' -Headers $h).value |
    Select-Object name, @{n='DisplayName';e={$_.properties.displayName}}
```

Caveats: sources 3–5 only show environments the signed-in user can access (not the whole tenant), and they also depend on proxy settings working (section 2).

---

## 5. Workaround C – other ways to authenticate (if sign-in itself is the issue)

```powershell
# Specific tenant
Add-PowerAppsAccount -TenantID '<tenant-guid>'

# Service principal (no interactive sign-in; app must be registered as a Power Platform admin app)
Add-PowerAppsAccount -TenantID '<tenant-guid>' -ApplicationId '<app-id>' -ClientSecret '<secret>'

# Government/other clouds
Add-PowerAppsAccount -Endpoint usgov
```

Never hard-code secrets in scripts; read them from a vault or prompt.

---

## 6. Last resort – work offline

The repository's offline tools need no API at all:

- `Modules\WorkflowReview\WorkflowReview.psm1` reviews exported flow definitions (`WorkflowSamples\*.json`).
- `Invoke-CodeReview.ps1`, `Get-WorkflowDependencies.ps1`, `Export-WorkflowData.ps1`, `New-WorkflowRestartScript.ps1` operate on workflow objects you already have.

See [TestCLI Overview.md](<./TestCLI Overview.md>).

---

## Sample script (self-contained)

```powershell
# Minimal "can I reach BAP from here?" check. Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
[System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

$px  = [System.Net.WebRequest]::GetSystemWebProxy(); $px.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
$req = [System.Net.HttpWebRequest]::Create('https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2016-11-01')
$req.Proxy = $px
try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response }
$body = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
"HTTP {0} {1}  Content-Type: {2}" -f [int]$resp.StatusCode, $resp.StatusDescription, $resp.ContentType
$body.Substring(0, [Math]::Min(300, $body.Length))
```

Interpretation: `401` + JSON (`MissingAuthorizationHeader...`) = host reachable, fine. `407` or HTML = proxy problem (section 2). Timeout/DNS error = firewall.

## Sample output

The two samples below are **illustrative** of the shape of a healthy run (they were not captured from your tenant). Names, GUIDs and counts are made up. The 407 sample in section 1 is real captured output.

`Test-PA-CLI-EnvironmentSources.ps1` when BAP is blocked but other hosts work:

```text
10:20:11.402 [OK  ] login.microsoftonline.com HTTPS HEAD -> HTTP 200 OK (via proxy.example.gov:8080)
10:20:11.690 [OK  ] api.bap.microsoft.com HTTPS HEAD -> HTTP 404 Not Found (via proxy.example.gov:8080)
10:20:13.020 [ERR ] FAIL: 1. Get-AdminPowerAppEnvironment (module, BAP) - Exception calling "DeserializeObject" ... "Invalid JSON primitive: IRS."
10:20:13.610 [ERR ] FAIL: 2. BAP admin REST - HTTP 407 proxy authentication required
10:20:14.320 [OK  ] PASS: 3. PowerApps REST - 4 environment(s): Default-11111111-..., 22222222-..., 33333333-...
10:20:14.980 [OK  ] PASS: 4. Flow REST - 4 environment(s): Default-11111111-..., 22222222-..., 33333333-...
10:20:15.400 [ERR ] FAIL: 5. Dataverse global discovery - HTTP 403
10:20:15.402 [OK  ] PASS: 6. Derived Default environment - Default-11111111-1111-1111-1111-111111111111
======================  Recommendation  ======================
10:20:15.410 [OK  ] Use environment from '3. PowerApps REST': Default-11111111-1111-1111-1111-111111111111
10:20:15.411 [INFO] Run the other tests without the BAP listing:
10:20:15.412 [INFO]   .\Test-PA-CLI-AdminFlow.ps1 -EnvironmentName 'Default-11111111-1111-1111-1111-111111111111'
```

`Test-PA-CLI-AdminFlow.ps1 -EnvironmentName ...` continuing past a BAP failure:

```text
10:21:02.118 [WARN] BAP environment listing failed; continuing with -EnvironmentName 'Default-1111...' (owner details for the environment unavailable).
10:21:02.730 [OK  ] PASS: Get-AdminFlow -EnvironmentName Default-1111... - ok (612 ms)
10:21:02.731 [OK  ] PASS: Flow count - 37 flow(s)
10:21:02.733 [INFO]   a1b2c3d4-... | Daily Report | Enabled=True | OwnerId=9f8e7d6c-...
10:21:03.201 [OK  ] PASS: Get-AdminFlow -FlowName a1b2c3d4-... - ok (440 ms)
10:21:03.210 [WARN] Environment owner skipped: no CreatedBy data (environment came from -EnvironmentName, not from BAP).
```

(The environment-owner check is skipped with a warning when BAP is unavailable, because that data only comes from BAP.)

## Colored output

Console colors are lost when output is redirected or copied. Every script therefore also saves a **colored HTML report** to `TestCLI\Logs\<script>_<timestamp>.html` (open it in a browser). Colors: INFO cyan, OK green, WARN yellow, ERR red, HTTP magenta, BODY teal, HDR gold, DIM gray.

