<#
.SYNOPSIS
    Shared helper library for the Test-PA-CLI-*.ps1 scripts (dot-source it; PowerShell 5.1 compatible).

.DESCRIPTION
    This file is NOT a test. It is dot-sourced by every Test-PA-CLI-*.ps1 script:

        . (Join-Path $PSScriptRoot 'PA-CLI-Debug.ps1')

    It provides:
      * Color-coded logging (Write-PALog / Write-PAHeader) that is ALSO captured in memory and saved as a
        colored HTML report (Save-PAReport) so the color highlighting survives after the console closes.
      * Proxy setup: the PowerApps modules send requests without proxy credentials. On networks with an
        authenticating proxy (NTLM) that produces "407 Proxy Authentication Required" as an HTML/text page,
        which the module then fails to parse ("Invalid JSON primitive: ..."). Initialize-PADebug sets the
        .NET default proxy to the system proxy with the current Windows credentials.
      * HTTP tracing: Invoke-WebRequest, Invoke-RestMethod and ConvertFrom-Json are wrapped (session only) so
        every request the modules make, and the exact text that failed JSON parsing, is logged.
      * Network, token and direct-API diagnostics.
      * Test session helpers (Start-PATestSession / Complete-PATestSession / Add-Result / Invoke-Step).

    Every function is defined in the global scope on purpose: the wrappers are called from inside the
    PowerApps modules, which cannot see script-scope functions.

.NOTES
    Log level colors: INFO cyan, OK green, WARN yellow, ERR red, HTTP magenta, BODY dark cyan,
    HDR dark yellow, DIM gray, HEAD white.
    Reports are written to .\Logs\<script>_<timestamp>.html (next to this file).
#>

# ----------------------------------------------------------------------------------------------
# Shared state (global so module-invoked wrappers can reach it)
# ----------------------------------------------------------------------------------------------
$global:PA_Results   = New-Object System.Collections.ArrayList   # test results (Test/Status/Detail)
$global:PA_LogLines  = New-Object System.Collections.ArrayList   # every log line, for the HTML report
$global:PA_MaxBody   = 4000                                      # max chars of any HTTP body printed
$global:PA_HelperDir = $PSScriptRoot

# Level -> console color. The same names drive the HTML report colors below.
$global:PA_Colors = @{
    INFO = 'Cyan'; OK = 'Green'; WARN = 'Yellow'; ERR = 'Red'; HTTP = 'Magenta'
    BODY = 'DarkCyan'; HDR = 'DarkYellow'; DIM = 'DarkGray'; HEAD = 'White'
}
$global:PA_HtmlColors = @{
    INFO = '#00bcd4'; OK = '#4caf50'; WARN = '#ffc107'; ERR = '#ff5252'; HTTP = '#e040fb'
    BODY = '#4db6ac'; HDR = '#c0a040'; DIM = '#888888'; HEAD = '#ffffff'
}

# ----------------------------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------------------------
function global:Write-PALog {
    <#
    .SYNOPSIS  Writes one color-coded, time-stamped log line (multi-line text is split) and records it for the HTML report.
    .PARAMETER Level    INFO, OK, WARN, ERR, HTTP, BODY, HDR, DIM or HEAD.
    .PARAMETER Message  Text to log.
    .EXAMPLE   Write-PALog WARN 'Proxy requires authentication'
    #>
    param([string]$Level, [string]$Message)
    $color = $global:PA_Colors[$Level]; if (-not $color) { $color = 'Gray' }
    foreach ($line in ($Message -split "`r?`n")) {
        $stamp = Get-Date -Format 'HH:mm:ss.fff'
        Write-Host ("{0} [{1,-4}] {2}" -f $stamp, $Level, $line) -ForegroundColor $color
        [void]$global:PA_LogLines.Add([pscustomobject]@{ Time = $stamp; Level = $Level; Text = $line })
    }
}

function global:Write-PAHeader {
    <#
    .SYNOPSIS  Prints (and records) a white section banner so each phase is easy to find in long output.
    #>
    param([string]$Text)
    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor White
    Write-Host "  $Text" -ForegroundColor White
    Write-Host ('=' * 78) -ForegroundColor White
    [void]$global:PA_LogLines.Add([pscustomobject]@{ Time = ''; Level = 'HEAD'; Text = ('=' * 20) + "  $Text  " + ('=' * 20) })
}

function global:Save-PAReport {
    <#
    .SYNOPSIS  Saves everything logged so far as a colored HTML file (colors are lost in plain text/redirected output; this keeps them).
    .PARAMETER Name  Base name for the file, normally the script name.
    .OUTPUTS   Full path of the HTML file, or $null on failure.
    .EXAMPLE   Save-PAReport -Name 'Test-PA-CLI-AdminFlow'
    #>
    param([string]$Name = 'Test-PA-CLI')
    try {
        $dir = Join-Path $global:PA_HelperDir 'Logs'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $path = Join-Path $dir ("{0}_{1:yyyyMMdd-HHmmss}.html" -f $Name, (Get-Date))
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("<!DOCTYPE html><html><head><meta charset='utf-8'><title>$Name</title></head>")
        [void]$sb.AppendLine("<body style='background:#1e1e1e;color:#ccc;font-family:Consolas,monospace;font-size:13px'><pre>")
        foreach ($l in $global:PA_LogLines) {
            $c = $global:PA_HtmlColors[$l.Level]; if (-not $c) { $c = '#cccccc' }
            $t = [System.Net.WebUtility]::HtmlEncode(("{0} [{1,-4}] {2}" -f $l.Time, $l.Level, $l.Text))
            [void]$sb.AppendLine("<span style='color:$c'>$t</span>")
        }
        [void]$sb.AppendLine('</pre></body></html>')
        [IO.File]::WriteAllText($path, $sb.ToString(), (New-Object System.Text.UTF8Encoding $true))
        return $path
    } catch { Write-Host "Could not save HTML report: $($_.Exception.Message)" -ForegroundColor Red; return $null }
}

function global:Format-PABody {
    <#
    .SYNOPSIS  Returns text safe to print: truncated to PA_MaxBody characters and pretty-printed when it is valid JSON.
    #>
    param([object]$Text)
    if ($null -eq $Text) { return '<null>' }
    $s = [string]$Text
    $len = $s.Length
    if ($len -gt $global:PA_MaxBody) { $s = $s.Substring(0, $global:PA_MaxBody) + "`n...<truncated, total $len chars>" }
    $trim = $s.TrimStart()
    if ($trim.StartsWith('{') -or $trim.StartsWith('[')) {
        # Use the real cmdlet by full name so the tracing wrapper is not invoked recursively.
        try { $s = ($s | Microsoft.PowerShell.Utility\ConvertFrom-Json | ConvertTo-Json -Depth 6) } catch { }
    }
    return $s
}

function global:Get-PAArgValue {
    <#
    .SYNOPSIS  Finds the value that follows -Name in an unbound $args array (used by the HTTP wrappers).
    #>
    param($ArgList, [string]$Name)
    for ($i = 0; $i -lt ($ArgList.Count - 1); $i++) {
        if (("$($ArgList[$i])") -ieq "-$Name") { return $ArgList[$i + 1] }
    }
    return $null
}

function global:Write-PARequest {
    <#
    .SYNOPSIS  Logs an outgoing HTTP request (method, URL, headers, body). Authorization values are redacted.
    #>
    param([string]$Cmd, $ArgList)
    $uri = Get-PAArgValue $ArgList 'Uri'
    if (-not $uri) {
        # Uri may have been passed positionally
        foreach ($a in $ArgList) { if (($a -is [string] -and $a -notmatch '^-') -or $a -is [uri]) { $uri = $a; break } }
    }
    $method = Get-PAArgValue $ArgList 'Method'; if (-not $method) { $method = 'GET' }
    Write-PALog HTTP "--> $Cmd $method $uri"
    $h = Get-PAArgValue $ArgList 'Headers'
    if ($h -is [System.Collections.IDictionary]) {
        foreach ($k in $h.Keys) {
            $v = [string]$h[$k]
            if ($k -match 'Authorization') { $v = $v.Substring(0, [Math]::Min(15, $v.Length)) + '...<redacted>' }
            Write-PALog HDR "    req header  $k : $v"
        }
    }
    $body = Get-PAArgValue $ArgList 'Body'
    if ($body) { Write-PALog BODY ("    req body: " + (Format-PABody $body)) }
}

function global:Write-PAError {
    <#
    .SYNOPSIS  Logs everything useful about an ErrorRecord: exception chain, location, stack, server error body, HTTP status and headers.
    .DESCRIPTION  Specifically calls out HTTP 407 (proxy authentication) and prints the Proxy-Authenticate header.
    .PARAMETER ErrorRecord  Usually $_ inside a catch block.
    .PARAMETER Where        Short description of what was being attempted.
    #>
    param($ErrorRecord, [string]$Where)
    $ex = $ErrorRecord.Exception
    Write-PALog ERR "!!! $Where failed: $($ex.GetType().FullName): $($ex.Message)"
    $depth = 0; $inner = $ex.InnerException
    while ($inner) {
        $depth++
        Write-PALog ERR ("    inner[{0}] {1}: {2}" -f $depth, $inner.GetType().FullName, $inner.Message)
        $inner = $inner.InnerException
    }
    if ($ErrorRecord.InvocationInfo) { Write-PALog DIM ("    at: " + ($ErrorRecord.InvocationInfo.PositionMessage -replace "`r?`n", ' | ')) }
    if ($ErrorRecord.ScriptStackTrace) { Write-PALog DIM ("    stack: " + ($ErrorRecord.ScriptStackTrace -replace "`r?`n", ' | ')) }
    # In Windows PowerShell 5.1 the server's error body is placed in ErrorDetails
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        Write-PALog BODY ("    ErrorDetails (server body):`n" + (Format-PABody $ErrorRecord.ErrorDetails.Message))
    }
    $resp = $null
    if ($ex -is [System.Net.WebException]) { $resp = $ex.Response } elseif ($ex.PSObject.Properties['Response']) { $resp = $ex.Response }
    if ($resp) {
        try {
            $code = [int]$resp.StatusCode
            Write-PALog ERR "    HTTP status: $code $($resp.StatusDescription)"
            if ($code -eq 407) { Write-PALog ERR '    *** 407 Proxy Authentication Required - the proxy rejected/lacked our credentials ***' }
            foreach ($k in $resp.Headers.AllKeys) { Write-PALog HDR "    resp header $k : $($resp.Headers[$k])" }
            if ($resp.Headers['Proxy-Authenticate']) { Write-PALog WARN "    Proxy-Authenticate: $($resp.Headers['Proxy-Authenticate'])" }
            if ($resp.GetResponseStream().CanRead) {
                $b = (New-Object System.IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
                Write-PALog BODY ("    error body:`n" + (Format-PABody $b))
            }
        } catch { Write-PALog DIM "    (could not read error response: $($_.Exception.Message))" }
    }
}

# ----------------------------------------------------------------------------------------------
# HTTP tracing (wraps cmdlets for the lifetime of the session)
# ----------------------------------------------------------------------------------------------
function global:Install-PAHttpTrace {
    <#
    .SYNOPSIS  Shadows Invoke-WebRequest, Invoke-RestMethod and ConvertFrom-Json with logging wrappers.
    .DESCRIPTION
        PowerShell resolves Function before Cmdlet, and the PowerApps modules fall back to the global scope,
        so these global functions see every call the modules make. Each wrapper forwards all arguments
        unchanged to the real cmdlet, so behavior is not altered - only logged.
        Undo with: Remove-Item Function:\Invoke-WebRequest,Function:\Invoke-RestMethod,Function:\ConvertFrom-Json
    #>
    function global:Invoke-WebRequest {
        $cmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Invoke-WebRequest', 'Cmdlet')
        Write-PARequest 'Invoke-WebRequest' $args
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            $r = & $cmd @args
            Write-PALog HTTP ("<-- HTTP {0} {1} ({2} ms)" -f $r.StatusCode, $r.StatusDescription, $sw.ElapsedMilliseconds)
            foreach ($k in $r.Headers.Keys) { Write-PALog HDR "    resp header $k : $($r.Headers[$k])" }
            Write-PALog BODY ("    resp body ({0} chars):`n{1}" -f ([string]$r.Content).Length, (Format-PABody $r.Content))
            $r
        } catch { Write-PAError $_ 'Invoke-WebRequest'; throw }
    }
    function global:Invoke-RestMethod {
        $cmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Invoke-RestMethod', 'Cmdlet')
        Write-PARequest 'Invoke-RestMethod' $args
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            $r = & $cmd @args
            Write-PALog HTTP ("<-- Invoke-RestMethod returned {0} ({1} ms)" -f $(if ($r) { $r.GetType().Name } else { 'null' }), $sw.ElapsedMilliseconds)
            # A [string] result means the server did not send JSON (proxy/HTML/text page)
            if ($r -is [string]) {
                Write-PALog WARN '    Response was a STRING, not parsed JSON (likely a proxy/HTML/text page):'
                Write-PALog BODY (Format-PABody $r)
            } else { try { Write-PALog BODY ("    resp: " + (Format-PABody ($r | ConvertTo-Json -Depth 4))) } catch { } }
            $r
        } catch { Write-PAError $_ 'Invoke-RestMethod'; throw }
    }
    function global:ConvertFrom-Json {
        # Buffers the pipeline so that, on failure, the exact text can be shown. This is the text behind
        # errors like: Exception calling "DeserializeObject" ... "Invalid JSON primitive: IRS."
        param([Parameter(ValueFromPipeline = $true)][object]$InputObject)
        begin   { $buf = New-Object System.Collections.ArrayList }
        process { [void]$buf.Add($InputObject) }
        end {
            $text = ($buf | ForEach-Object { [string]$_ }) -join "`n"
            try { $text | Microsoft.PowerShell.Utility\ConvertFrom-Json }
            catch {
                Write-PALog ERR '!!! ConvertFrom-Json could not parse this text (THIS is what the module received):'
                Write-PALog BODY ("<<<START ({0} chars)>>>`n{1}`n<<<END>>>" -f $text.Length, (Format-PABody $text))
                if ($text -match '<html|<!DOCTYPE') { Write-PALog WARN '    Looks like HTML - a proxy/gateway/captive-portal page.' }
                if ($text -match '407|Proxy Authentication') { Write-PALog ERR '    Mentions 407 / proxy authentication.' }
                throw
            }
        }
    }
    Write-PALog OK 'HTTP trace installed (Invoke-WebRequest, Invoke-RestMethod, ConvertFrom-Json are wrapped for this session).'
}

# ----------------------------------------------------------------------------------------------
# Initialization and diagnostics
# ----------------------------------------------------------------------------------------------
function global:Initialize-PADebug {
    <#
    .SYNOPSIS  Prepares the session: proxy credentials, TLS 1.2, verbose output, environment dump, HTTP tracing.
    .EXAMPLE   Initialize-PADebug
    #>
    Write-PAHeader 'Environment / proxy setup'
    # Use the system (IE/WinINET) proxy and authenticate to it as the current Windows user.
    [System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    $global:VerbosePreference = 'Continue'   # show the modules' Write-Verbose output
    Write-PALog INFO "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition)), CLR $($PSVersionTable.CLRVersion)"
    Write-PALog INFO "User: $env:USERDOMAIN\$env:USERNAME  Machine: $env:COMPUTERNAME"
    Write-PALog INFO "SecurityProtocol: $([System.Net.ServicePointManager]::SecurityProtocol)"
    Write-PALog INFO 'Default proxy credentials: DefaultNetworkCredentials (current Windows user)'
    try {
        $ie = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
        Write-PALog INFO "IE proxy: ProxyEnable=$($ie.ProxyEnable) ProxyServer=$($ie.ProxyServer) AutoConfigURL=$($ie.AutoConfigURL) ProxyOverride=$($ie.ProxyOverride)"
    } catch { Write-PALog WARN "Could not read IE proxy settings: $($_.Exception.Message)" }
    try { (netsh winhttp show proxy) | Where-Object { $_ } | ForEach-Object { Write-PALog INFO "winhttp: $_" } } catch { }
    foreach ($n in 'HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY', 'ALL_PROXY') {
        $v = [Environment]::GetEnvironmentVariable($n); if ($v) { Write-PALog INFO "env $n = $v" }
    }
    Install-PAHttpTrace
}

function global:Invoke-PARawGet {
    <#
    .SYNOPSIS  GET a URL through the system proxy (with Windows credentials) and return the raw status/body, never throwing on HTTP errors.
    .PARAMETER Uri    URL to call.
    .PARAMETER Token  Optional bearer token (sent as Authorization; never logged in full).
    .OUTPUTS   PSCustomObject: Ok, Status, StatusText, ContentType, Headers, Body, Json, Error, Route
    .EXAMPLE   Invoke-PARawGet -Uri 'https://api.bap.microsoft.com/' | Format-List
    #>
    param([Parameter(Mandatory)][string]$Uri, [string]$Token)
    $o = [pscustomobject]@{ Ok = $false; Status = 0; StatusText = ''; ContentType = ''; Headers = @{}; Body = ''; Json = $null; Error = $null; Route = '' }
    $px = [System.Net.WebRequest]::GetSystemWebProxy(); $px.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    try {
        $req = [System.Net.HttpWebRequest]::Create($Uri)
        $req.Proxy = $px; $req.Timeout = 30000; $req.Accept = 'application/json'
        if ($Token) { $req.Headers.Add('Authorization', "Bearer $Token") }
        $o.Route = if ($px.IsBypassed($req.RequestUri)) { 'direct' } else { 'via ' + $px.GetProxy($req.RequestUri).Authority }
        try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response; if (-not $resp) { throw } }
        $o.Status = [int]$resp.StatusCode; $o.StatusText = $resp.StatusDescription; $o.ContentType = $resp.ContentType
        foreach ($k in $resp.Headers.AllKeys) { $o.Headers[$k] = $resp.Headers[$k] }
        $o.Body = (New-Object System.IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
        $resp.Close()
        $o.Ok = ($o.Status -ge 200 -and $o.Status -lt 300)
        try { $o.Json = $o.Body | Microsoft.PowerShell.Utility\ConvertFrom-Json } catch { }
    } catch { $o.Error = $_.Exception.Message }
    return $o
}

function global:Show-PANetworkDiagnostics {
    <#
    .SYNOPSIS  For each Power Platform host: DNS lookup, route (direct/proxy) and an HTTPS HEAD request. HTTP 407 is shown in red.
    .DESCRIPTION  Any HTTP answer (even 401/403/404) proves the host is reachable; 407 means the proxy refused us.
    #>
    Write-PAHeader 'Network diagnostics (DNS / TCP / HTTPS via proxy)'
    $hosts = 'login.microsoftonline.com', 'api.bap.microsoft.com', 'api.flow.microsoft.com', 'api.powerapps.com'
    $px = [System.Net.WebRequest]::GetSystemWebProxy(); $px.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    foreach ($h in $hosts) {
        $uri = [uri]"https://$h/"
        $route = if ($px.IsBypassed($uri)) { 'direct' } else { 'via ' + $px.GetProxy($uri).Authority }
        try {
            $ips = [System.Net.Dns]::GetHostAddresses($h) | ForEach-Object { $_.IPAddressToString }
            Write-PALog INFO "$h DNS -> $($ips -join ', ') ($route)"
        } catch { Write-PALog WARN "$h DNS failed: $($_.Exception.Message)" }
        try {
            $req = [System.Net.HttpWebRequest]::Create($uri); $req.Method = 'HEAD'; $req.Proxy = $px; $req.Timeout = 20000
            try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response; if (-not $resp) { throw } }
            $code = [int]$resp.StatusCode
            $lvl = 'OK'; if ($code -eq 407) { $lvl = 'ERR' } elseif ($code -ge 500) { $lvl = 'WARN' }
            Write-PALog $lvl "$h HTTPS HEAD -> HTTP $code $($resp.StatusDescription) ($route) Server=$($resp.Headers['Server']) ContentType=$($resp.ContentType)"
            if ($code -eq 407) { Write-PALog ERR "    Proxy-Authenticate: $($resp.Headers['Proxy-Authenticate'])" }
            $resp.Close()
        } catch { Write-PALog ERR "$h HTTPS HEAD failed: $($_.Exception.Message)" }
    }
}

function global:ConvertFrom-PAJwt {
    <#
    .SYNOPSIS  Decodes the payload (claims) of a JWT. The signature is NOT validated - for display only.
    #>
    param([string]$Token)
    $p = $Token.Split('.')[1].Replace('-', '+').Replace('_', '/')
    switch ($p.Length % 4) { 2 { $p += '==' } 3 { $p += '=' } }   # restore base64 padding
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | Microsoft.PowerShell.Utility\ConvertFrom-Json
}

function global:Get-PAToken {
    <#
    .SYNOPSIS  Returns a bearer token for an audience using the module's current sign-in session, or $null.
    .PARAMETER Audience  e.g. https://service.powerapps.com/  or  https://service.flow.microsoft.com/
    .NOTES  Get-JwtToken lives in Microsoft.PowerApps.AuthModule (an unapproved verb - that is why Import-Module warns).
    #>
    param([string]$Audience)
    if (-not (Get-Command Get-JwtToken -ErrorAction SilentlyContinue)) {
        Write-PALog WARN 'Get-JwtToken not available (sign in first); cannot get a token.'; return $null
    }
    try { return (Get-JwtToken -Audience $Audience) } catch { Write-PAError $_ "Get-JwtToken $Audience"; return $null }
}

function global:Show-PAToken {
    <#
    .SYNOPSIS  Shows who is signed in: user, tenant, audience, scopes and expiry for the PowerApps and BAP audiences.
    #>
    Write-PAHeader 'Token / session diagnostics'
    foreach ($aud in 'https://service.powerapps.com/', 'https://api.bap.microsoft.com/') {
        $t = Get-PAToken $aud
        if (-not $t) { continue }
        try {
            $c = ConvertFrom-PAJwt $t
            $exp = [DateTimeOffset]::FromUnixTimeSeconds([long]$c.exp).LocalDateTime
            Write-PALog OK ("token aud={0} upn={1} tid={2} appid={3} exp={4}" -f $c.aud, $(if ($c.upn) { $c.upn } else { $c.unique_name }), $c.tid, $c.appid, $exp)
            if ($exp -lt (Get-Date)) { Write-PALog ERR '    token is EXPIRED' }
            if ($c.scp) { Write-PALog INFO "    scopes: $($c.scp)" }
            if ($c.roles) { Write-PALog INFO "    roles: $($c.roles -join ', ')" }
        } catch { Write-PAError $_ "decode token for $aud" }
    }
}

function global:Test-PADirectApi {
    <#
    .SYNOPSIS  Calls the BAP environments API directly with the module's token, bypassing the module's JSON parsing, and prints the raw reply.
    .DESCRIPTION  Compare this with the traced module request to see whether the module or the network is at fault.
    #>
    Write-PAHeader 'Direct API call (module token, raw response)'
    $t = Get-PAToken 'https://service.powerapps.com/'
    if (-not $t) { Write-PALog ERR 'No token; cannot do direct call.'; return }
    $uri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2016-11-01'
    Write-PALog HTTP "--> GET $uri"
    $r = Invoke-PARawGet -Uri $uri -Token $t
    if ($r.Error) { Write-PALog ERR "Request failed: $($r.Error)"; return }
    Write-PALog HTTP "<-- HTTP $($r.Status) $($r.StatusText) ContentType=$($r.ContentType) ($($r.Route))"
    foreach ($k in $r.Headers.Keys) { Write-PALog HDR "    resp header $k : $($r.Headers[$k])" }
    Write-PALog $(if ($r.Ok) { 'OK' } else { 'ERR' }) ("body ({0} chars):`n{1}" -f $r.Body.Length, (Format-PABody $r.Body))
    if ($r.Json) { Write-PALog OK "Body is valid JSON; environments: $(@($r.Json.value).Count)" } else { Write-PALog ERR 'Body is NOT valid JSON.' }
}

# ----------------------------------------------------------------------------------------------
# Test session helpers
# ----------------------------------------------------------------------------------------------
function global:Add-Result {
    <#
    .SYNOPSIS  Records and prints one PASS/FAIL result.
    #>
    param($Name, [bool]$Ok, $Detail)
    [void]$global:PA_Results.Add([pscustomobject]@{ Test = $Name; Status = $(if ($Ok) { 'PASS' } else { 'FAIL' }); Detail = $Detail })
    Write-PALog $(if ($Ok) { 'OK' } else { 'ERR' }) ("{0}: {1} - {2}" -f $(if ($Ok) { 'PASS' } else { 'FAIL' }), $Name, $Detail)
}

function global:Invoke-Step {
    <#
    .SYNOPSIS  Runs a scriptblock as a named test step: prints a banner, times it, logs any error in full, records PASS/FAIL.
    .OUTPUTS   The scriptblock's output, or $null if it threw.
    .EXAMPLE   $flows = Invoke-Step 'Get-AdminFlow' { @(Get-AdminFlow -EnvironmentName $env) }
    #>
    param($Name, [scriptblock]$Action)
    Write-PAHeader $Name
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { $r = & $Action; Add-Result $Name $true ("ok ({0} ms)" -f $sw.ElapsedMilliseconds); return $r }
    catch { Write-PAError $_ $Name; Add-Result $Name $false $_.Exception.Message; return $null }
}

function global:Start-PATestSession {
    <#
    .SYNOPSIS  Common start of every test: debug init, network checks, module import, sign-in, token info, environment lookup.
    .PARAMETER TenantID          Optional tenant GUID passed to Add-PowerAppsAccount.
    .PARAMETER EnvironmentName   Optional environment to use. If the BAP environment listing fails, this name is used
                                 directly (a stub object) so tests that do not need BAP can still run. See
                                 API.BAP.microsoft.com.Workaround.md.
    .PARAMETER SkipNetworkChecks Skip the DNS/HTTPS host probes.
    .OUTPUTS   Array of environment objects, or $null when the session cannot continue (caller should exit 1).
               Module import failure returns the string 'MODULE' (caller should exit 2).
    #>
    param([string]$TenantID, [string]$EnvironmentName, [switch]$SkipNetworkChecks)
    Initialize-PADebug
    if (-not $SkipNetworkChecks) { Show-PANetworkDiagnostics }

    $module = 'Microsoft.PowerApps.Administration.PowerShell'
    Write-PAHeader "Import $module"
    try {
        # -WarningAction hides the harmless "unapproved verbs" warning
        Import-Module $module -ErrorAction Stop -WarningAction SilentlyContinue
        Get-Module Microsoft.PowerApps.* | ForEach-Object { Write-PALog INFO "loaded $($_.Name) $($_.Version)" }
    } catch {
        Write-PAError $_ "Import-Module $module"
        Write-PALog ERR "Run: Install-Module $module -Scope CurrentUser -Force -AllowClobber"
        return 'MODULE'
    }

    $signedIn = Invoke-Step 'Sign-in (Add-PowerAppsAccount)' {
        $p = @{}; if ($TenantID) { $p.TenantID = $TenantID }
        Add-PowerAppsAccount @p -ErrorAction Stop | Out-Null
        $true
    }
    if (-not $signedIn) { return $null }
    Show-PAToken

    $envs = Invoke-Step 'Get-AdminPowerAppEnvironment' {
        $e = @(Get-AdminPowerAppEnvironment -ErrorAction Stop)
        if ($e.Count -eq 0) { throw 'No environments returned (need Power Platform admin account).' }
        Write-PALog OK "Environments: $($e.Count)"
        $e
    }
    if ($envs) { return $envs }

    Test-PADirectApi
    if ($EnvironmentName) {
        # BAP workaround: carry on with just the name the user supplied
        Write-PALog WARN "BAP environment listing failed; continuing with -EnvironmentName '$EnvironmentName' (owner details for the environment unavailable)."
        return @([pscustomobject]@{ EnvironmentName = $EnvironmentName; DisplayName = $EnvironmentName; CreatedBy = $null })
    }
    Write-PALog WARN 'Re-run with -EnvironmentName <name> to skip the BAP listing, or run Test-PA-CLI-EnvironmentSources.ps1 to find another way to list environments. See API.BAP.microsoft.com.Workaround.md.'
    return $null
}

function global:Complete-PATestSession {
    <#
    .SYNOPSIS  Prints the results table and totals, saves the colored HTML report, and returns the process exit code (0 pass, 1 any failure).
    .EXAMPLE   exit (Complete-PATestSession -Name 'Test-PA-CLI-AdminFlow')
    #>
    param([string]$Name = 'Test-PA-CLI')
    Write-PAHeader 'Summary'
    $fail = @($global:PA_Results | Where-Object Status -eq 'FAIL').Count
    $pass = $global:PA_Results.Count - $fail
    foreach ($r in $global:PA_Results) {
        Write-PALog $(if ($r.Status -eq 'PASS') { 'OK' } else { 'ERR' }) ("{0}  {1}  {2}" -f $r.Status, $r.Test, $r.Detail)
    }
    Write-PALog $(if ($fail) { 'ERR' } else { 'OK' }) "Done: $pass passed, $fail failed"
    $path = Save-PAReport -Name $Name
    if ($path) { Write-PALog INFO "Colored HTML report: $path" }
    if ($fail) { return 1 } else { return 0 }
}
