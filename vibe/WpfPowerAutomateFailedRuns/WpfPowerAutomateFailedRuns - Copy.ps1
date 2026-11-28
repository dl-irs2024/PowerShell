#Requires -Version 5.1

<#
.SYNOPSIS
    WPF-based Power Automate Workflow Inspector and Management Tool
    
.DESCRIPTION
    Comprehensive tool for inspecting Power Automate workflows, monitoring failed runs,
    viewing run history, and performing workflow management tasks.
    
    Features:
    - View published workflows and run history
    - Filter by date range, environment, owner, execution status
    - Export in multiple formats (CSV, TSV, HTML, Excel, Markdown)
    - Restart failed workflows
    - Code review capabilities (re-entrancy, error handling)
    - Workflow dependency detection
    - Owner status verification
    - Simulation mode with sample data
    - Live mode with module validation and smoke testing
    
.NOTES
    Author: Copilot
    Version: 1.0.0
    Requires: PowerShell 5.1+
    Modules: Microsoft.PowerApps.Administration.PowerShell
#>

[CmdletBinding()]
param(
    [ValidateSet('Simulation', 'Live')]
    [string]$Mode = 'Simulation',
    
    [switch]$SkipModuleValidation
)

# Color palette for UI (muted pastels, used with dark text)
$ColorPalette = @{
    Delete = '#F2C4C4'      # Muted pastel red
    Create = '#C6E3C6'      # Muted pastel green
    Info = '#C5DAEE'        # Muted pastel blue
    Warning = '#F3E6B5'     # Muted pastel yellow
    Neutral = '#F7F7F5'     # Off-white
    Header = '#D5D0EA'      # Muted lavender (title bar)
    Text = '#1E1E1E'        # Near-black text
    DeleteText = '#9B2C2C'  # Dark red text on light background
    CreateText = '#1E6B34'  # Dark green text on light background
}

# Console text colors (dark shades readable on the light console background)
$Script:ConsoleColors = @{
    Delete = '#A12622'
    Create = '#1E6B34'
    Info = '#1F4E79'
    Warning = '#8A5A00'
    Neutral = '#333333'
    Comment = '#6B7B6B'
    Command = '#5B2C83'
}

# Global configuration
$Script:Config = @{
    Mode = $Mode
    SkipModuleValidation = $SkipModuleValidation
    CachePath = "$env:TEMP\PAFailedRunsCache"
    SampleDataPath = "$PSScriptRoot\SampleData"
    ScriptPath = $PSCommandPath
    SettingsPath = Join-Path $env:APPDATA 'PAFailedRunsInspector\settings.json'
}

# UI console target (set once the window exists) and buffer of messages written before that
$Script:ConsoleBox = $null
$Script:ConsoleBuffer = New-Object System.Collections.Generic.List[object]

# Ensure cache directory exists
if (-not (Test-Path $Script:Config.CachePath)) {
    New-Item -ItemType Directory -Path $Script:Config.CachePath -Force | Out-Null
}

#region Helper Functions

function Write-ColorOutput {
    <#
    .SYNOPSIS
        Write colored output to console
    #>
    param(
        [string]$Message,
        [ValidateSet('Delete', 'Create', 'Info', 'Warning', 'Neutral', 'Comment', 'Command')]
        [string]$Type = 'Neutral'
    )
    
    $colors = @{
        Delete = 'Red'
        Create = 'Green'
        Info = 'Cyan'
        Warning = 'Yellow'
        Neutral = 'Gray'
        Comment = 'DarkGray'
        Command = 'White'
    }
    
    Write-Host $Message -ForegroundColor $colors[$Type]
    
    if ($Script:ConsoleBox) {
        Write-UiConsole -Message $Message -Type $Type
    } else {
        $Script:ConsoleBuffer.Add(@($Message, $Type))
    }
}

function Write-UiConsole {
    <#
    .SYNOPSIS
        Append a colored line to the in-window PowerShell console
    #>
    param(
        [string]$Message,
        [string]$Type = 'Neutral'
    )
    
    $box = $Script:ConsoleBox
    $run = New-Object System.Windows.Documents.Run($Message)
    $run.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Script:ConsoleColors[$Type])
    if ($Type -eq 'Comment') { $run.FontStyle = [System.Windows.FontStyles]::Italic }
    if ($Type -eq 'Command') { $run.FontWeight = [System.Windows.FontWeights]::SemiBold }
    
    $paragraph = New-Object System.Windows.Documents.Paragraph($run)
    $paragraph.Margin = New-Object System.Windows.Thickness(0)
    $box.Document.Blocks.Add($paragraph)
    $box.ScrollToEnd()
    
    # Let WPF render now so long-running checks show progress line by line
    $box.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

function Test-HttpsEndpoint {
    <#
    .SYNOPSIS
        HTTPS reachability check that honors the system (IE/WinINET) proxy, like the PowerApps modules do.
        Any HTTP response (even 401/403/404) proves the host is reachable; 407 means the proxy rejected us.
    #>
    param(
        [string]$HostName,
        [int]$TimeoutMs = 8000
    )
    
    # Windows PowerShell 5.1 may default to TLS 1.0, which Microsoft endpoints reject
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    
    $uri = [Uri]"https://$HostName/"
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $route = if ($proxy.IsBypassed($uri)) { 'direct' } else { "via proxy $($proxy.GetProxy($uri).Authority)" }
    
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.Method = 'HEAD'
    $request.Timeout = $TimeoutMs
    $request.AllowAutoRedirect = $false
    $request.Proxy = $proxy
    
    try {
        $response = $request.GetResponse()
        $status = [int]$response.StatusCode
        $response.Close()
        return [PSCustomObject]@{ Reachable = $true; Detail = "HTTP $status, $route" }
    } catch {
        $ex = $_.Exception
        while ($ex -and $ex -isnot [System.Net.WebException]) { $ex = $ex.InnerException }
        if ($ex -and $ex.Response) {
            $status = [int]$ex.Response.StatusCode
            $ex.Response.Close()
            if ($status -eq 407) {
                return [PSCustomObject]@{ Reachable = $false; Detail = "HTTP 407 proxy authentication required, $route" }
            }
            $note = if ($status -in 502, 504) { ' - may be a proxy gateway error; see HowTo section 3.2' } else { '' }
            return [PSCustomObject]@{ Reachable = $true; Detail = "HTTP $status, $route$note" }
        }
        $reason = if ($ex) { "$($ex.Status): $($ex.Message)" } else { $_.Exception.Message }
        return [PSCustomObject]@{ Reachable = $false; Detail = "$reason ($route)" }
    }
}

function Test-PowerAutomateConnection {
    <#
    .SYNOPSIS
        Check everything Live mode needs and print how to fix anything missing
    .OUTPUTS
        Number of problems found
    #>
    $problems = 0
    $requiredModules = @(
        'Microsoft.PowerApps.Administration.PowerShell',
        'Microsoft.PowerApps.PowerShell'
    )
    
    Write-ColorOutput "==== Test Connection  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" -Type Info
    if ($Script:Config.Mode -ne 'Live') {
        Write-ColorOutput "# Current mode is Simulation; these checks show what Live mode needs." -Type Comment
    }
    
    # 1. PowerShell edition
    Write-ColorOutput "Checking PowerShell edition..." -Type Neutral
    if ($PSVersionTable.PSEdition -eq 'Core') {
        Write-ColorOutput "[X] Running PowerShell $($PSVersionTable.PSVersion) (Core). The PowerApps admin modules are only supported on Windows PowerShell 5.1." -Type Delete
        Write-ColorOutput "# Fix: launch the inspector from Windows PowerShell:" -Type Comment
        Write-ColorOutput "powershell.exe -ExecutionPolicy Bypass -File `"$($Script:Config.ScriptPath)`" -Mode Live" -Type Command
        $problems++
    } else {
        Write-ColorOutput "[OK] Windows PowerShell $($PSVersionTable.PSVersion)" -Type Create
    }
    
    # 2. Execution policy
    Write-ColorOutput "Checking execution policy..." -Type Neutral
    $policy = Get-ExecutionPolicy
    if ($policy -in @('Restricted', 'AllSigned')) {
        Write-ColorOutput "[X] Execution policy is '$policy'; module scripts may be blocked." -Type Delete
        Write-ColorOutput "# Fix: allow locally installed / signed remote scripts for your account:" -Type Comment
        Write-ColorOutput "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned" -Type Command
        $problems++
    } else {
        Write-ColorOutput "[OK] Execution policy is '$policy'" -Type Create
    }
    
    # 3. Network reachability
    Write-ColorOutput "Checking network access (HTTPS via system proxy settings)..." -Type Neutral
    $endpoints = @('login.microsoftonline.com', 'api.bap.microsoft.com', 'api.flow.microsoft.com', 'www.powershellgallery.com')
    $networkFailed = $false
    foreach ($endpoint in $endpoints) {
        $result = Test-HttpsEndpoint -HostName $endpoint
        if ($result.Reachable) {
            Write-ColorOutput "[OK] $endpoint reachable ($($result.Detail))" -Type Create
        } else {
            Write-ColorOutput "[X] $endpoint not reachable: $($result.Detail)" -Type Delete
            $networkFailed = $true
            $problems++
        }
    }
    if ($networkFailed) {
        Write-ColorOutput "# Fix: check VPN / firewall / proxy. See DebugPowerAutomateConnections.HowTo.md, section 3." -Type Comment
        Write-ColorOutput "# Show the proxy your user account uses (Internet Options) and the machine-wide WinHTTP proxy:" -Type Comment
        Write-ColorOutput "Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select-Object ProxyEnable, ProxyServer, AutoConfigURL" -Type Command
        Write-ColorOutput "netsh winhttp show proxy" -Type Command
        Write-ColorOutput "# Test one endpoint by hand:" -Type Comment
        Write-ColorOutput "Invoke-WebRequest https://login.microsoftonline.com -Method Head -UseBasicParsing -ProxyUseDefaultCredentials" -Type Command
    }
    
    # 4. Modules installed and importable
    Write-ColorOutput "Checking required modules..." -Type Neutral
    $modulesReady = $true
    $missingModules = @()
    foreach ($module in $requiredModules) {
        $installed = Get-Module -Name $module -ListAvailable -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $installed) {
            Write-ColorOutput "[X] Module '$module' is not installed" -Type Delete
            $missingModules += $module
            $modulesReady = $false
            $problems++
            continue
        }
        if (-not (Get-Module -Name $module)) {
            try {
                Import-Module $module -ErrorAction Stop
            } catch {
                Write-ColorOutput "[X] Module '$module' $($installed.Version) is installed but failed to import: $($_.Exception.Message)" -Type Delete
                Write-ColorOutput "# Fix: reinstall the module, then restart PowerShell:" -Type Comment
                Write-ColorOutput "Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber" -Type Command
                $modulesReady = $false
                $problems++
                continue
            }
        }
        Write-ColorOutput "[OK] Module '$module' $($installed.Version) loaded" -Type Create
    }
    if ($missingModules.Count -gt 0) {
        Write-ColorOutput "# Fix: install the missing module(s) for your account:" -Type Comment
        foreach ($module in $missingModules) {
            Write-ColorOutput "Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber" -Type Command
        }
        Write-ColorOutput "# If Install-Module fails on Windows PowerShell 5.1, enable TLS 1.2 and the NuGet provider first:" -Type Comment
        Write-ColorOutput "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12" -Type Command
        Write-ColorOutput "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force" -Type Command
    }
    
    # 5. Signed in (the PowerApps auth module stores the session in $global:currentSession)
    Write-ColorOutput "Checking Power Platform sign-in..." -Type Neutral
    $signedIn = $false
    if (-not $modulesReady) {
        Write-ColorOutput "[!] Skipped: required modules are not available" -Type Warning
    } elseif ((Test-PaSignedIn) -or ($Script:Config.Mode -eq 'Live' -and (Connect-PaSession))) {
        Write-ColorOutput "[OK] $(Get-PaSessionSummary)" -Type Create
        $signedIn = $true
    } else {
        Write-ColorOutput "[X] Not signed in to Power Platform (in this PowerShell process)" -Type Delete
        Write-ColorOutput "# Use Settings > Sign in. A sign-in done in another window does not carry over to this app. Alternatively, in ONE Windows PowerShell window:" -Type Comment
        Write-ColorOutput "Add-PowerAppsAccount" -Type Command
        Write-ColorOutput "& `"$($Script:Config.ScriptPath)`" -Mode Live" -Type Command
        Write-ColorOutput "# For a specific tenant or sovereign cloud (prod, usgov, usgovhigh, dod, china):" -Type Comment
        Write-ColorOutput "Add-PowerAppsAccount -Endpoint prod -TenantID '<tenant-guid>'" -Type Command
        Write-ColorOutput "# More options: DebugPowerAutomateConnections.HowTo.md, section 5." -Type Comment
        $problems++
    }
    
    # 6. API smoke test
    Write-ColorOutput "Checking Power Platform admin API access..." -Type Neutral
    if (-not $signedIn) {
        Write-ColorOutput "[!] Skipped: not signed in" -Type Warning
    } else {
        try {
            $environments = @(Get-AdminPowerAppEnvironment -ErrorAction Stop)
            Write-ColorOutput "[OK] Admin API reachable, $($environments.Count) environment(s) visible" -Type Create
            if ($environments.Count -eq 0) {
                Write-ColorOutput "# No environments returned: your account may lack admin rights in this tenant." -Type Comment
            }
        } catch {
            Write-ColorOutput "[X] Admin API call failed: $($_.Exception.Message)" -Type Delete
            Write-ColorOutput "# Fix: the account needs the Power Platform Administrator (or Dynamics 365 / Global) admin role," -Type Comment
            Write-ColorOutput "# or Environment Admin on the environments you want to inspect. Re-sign in after a role change:" -Type Comment
            Write-ColorOutput "Remove-PowerAppsAccount; Add-PowerAppsAccount" -Type Command
            $problems++
        }
    }
    
    if ($problems -eq 0) {
        Write-ColorOutput "==== All checks passed. Live mode is ready. ====" -Type Create
    } else {
        Write-ColorOutput "==== $problems problem(s) found. Run the commands above, then test again. ====" -Type Warning
    }
    
    return $problems
}

function Test-PaSignedIn {
    return [bool]($global:currentSession -and $global:currentSession.loggedIn)
}

function Get-PaSessionSummary {
    if (-not (Test-PaSignedIn)) { return 'Not signed in' }
    $s = $global:currentSession
    $who = if ($s.upn) { $s.upn } else { 'current user' }
    $tenant = if ($s.tenantId) { " | tenant $($s.tenantId)" } else { '' }
    $exp = if ($s.expiresOn) { " | token expires $($s.expiresOn)" } else { '' }
    return "Signed in as $who$tenant$exp"
}

function Connect-PaSession {
    <#
    .SYNOPSIS
        Make sure this process has a Power Platform session; run Add-PowerAppsAccount (interactive) when it does not.
        The sign-in belongs to the PowerShell process, so a sign-in done in another window does not count.
    #>
    param([switch]$Force)
    
    if (-not $Force -and (Test-PaSignedIn)) { return $true }
    
    if (-not (Get-Command Add-PowerAppsAccount -ErrorAction SilentlyContinue)) {
        $Script:LastLiveError = 'Add-PowerAppsAccount not found - install Microsoft.PowerApps.Administration.PowerShell (Settings > Validate Modules Now)'
        Write-ColorOutput "[X] $Script:LastLiveError" -Type Delete
        return $false
    }
    
    $params = @{}
    if ($Script:Settings -and $Script:Settings.Endpoint) { $params.Endpoint = $Script:Settings.Endpoint }
    if ($Script:Settings -and $Script:Settings.TenantId) { $params.TenantID = $Script:Settings.TenantId }
    $cmd = 'Add-PowerAppsAccount' + $(foreach ($k in $params.Keys) { " -$k '$($params[$k])'" })
    Write-ColorOutput "Not signed in to Power Platform in this process. Signing in (a browser / sign-in window may open)..." -Type Warning
    Write-ColorOutput $cmd -Type Command
    try {
        Add-PowerAppsAccount @params -ErrorAction Stop | Out-Null
    } catch {
        $Script:LastLiveError = "sign-in failed: $($_.Exception.Message)"
        Write-ErrorDetail -Context 'Sign-in failed' -ErrorRecord $_
        return $false
    }
    if (Test-PaSignedIn) {
        Write-ColorOutput "[OK] $(Get-PaSessionSummary)" -Type Create
        return $true
    }
    $Script:LastLiveError = 'sign-in did not complete (cancelled, or the account has no Power Platform session)'
    Write-ColorOutput "[X] $Script:LastLiveError" -Type Delete
    return $false
}

function Get-InspectorSettings {
    <#
    .SYNOPSIS
        Load persisted UI settings (per-tab zoom, console visibility, window bounds, active tab, environment)
    #>
    $settings = @{ TabZoom = @{}; ConsoleVisible = $true; Window = @{}; ActiveTab = $null; EnvironmentName = $null; Verbose = $false; TestSampleSize = 5; Endpoint = $null; TenantId = $null }
    if (Test-Path $Script:Config.SettingsPath) {
        try {
            $json = Get-Content -Path $Script:Config.SettingsPath -Raw | ConvertFrom-Json
            if ($json.TabZoom) {
                foreach ($prop in $json.TabZoom.PSObject.Properties) {
                    $settings.TabZoom[$prop.Name] = [double]$prop.Value
                }
            }
            if ($json.Window) {
                foreach ($prop in $json.Window.PSObject.Properties) {
                    $settings.Window[$prop.Name] = $prop.Value
                }
            }
            if ($json.ActiveTab) { $settings.ActiveTab = [string]$json.ActiveTab }
            if ($json.EnvironmentName) { $settings.EnvironmentName = [string]$json.EnvironmentName }
            if ($null -ne $json.ConsoleVisible) { $settings.ConsoleVisible = [bool]$json.ConsoleVisible }
            if ($null -ne $json.Verbose) { $settings.Verbose = [bool]$json.Verbose }
            if ($json.Endpoint) { $settings.Endpoint = [string]$json.Endpoint }
            if ($json.TenantId) { $settings.TenantId = [string]$json.TenantId }
            if ($json.TestSampleSize) { $settings.TestSampleSize = [int][math]::Max(1, [math]::Min(10, [int]$json.TestSampleSize)) }
        } catch {
            Write-Host "Ignoring unreadable settings file: $_" -ForegroundColor Yellow
        }
    }
    return $settings
}

function Save-InspectorSettings {
    param([hashtable]$Settings)
    
    $dir = Split-Path $Script:Config.SettingsPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Settings | ConvertTo-Json -Depth 3 | Set-Content -Path $Script:Config.SettingsPath -Encoding UTF8
}

function Test-VerboseMode {
    return [bool]($Script:Settings -and $Script:Settings.Verbose)
}

function Set-PowerShellVerbose {
    # Verbose mode is PowerShell's own: every cmdlet (including module internals) writes its Write-Verbose output
    $global:VerbosePreference = if (Test-VerboseMode) { 'Continue' } else { 'SilentlyContinue' }
}

function Write-ErrorDetail {
    <#
    .SYNOPSIS
        Print a one-line error, plus full detail (exception chain, location, stack) in Verbose mode
    #>
    param(
        [string]$Context,
        $ErrorRecord
    )
    
    $ex = $ErrorRecord.Exception
    Write-ColorOutput "$Context`: $($ex.Message)" -Type Delete
    
    if ($ex.Message -match 'Invalid JSON primitive') {
        Write-ColorOutput "# The service answered with something that is not JSON (e.g. a proxy block page, sign-in redirect or error text)." -Type Comment
        Write-ColorOutput "# Test tab > 'Raw HTTP probe' shows the actual status and body so you can see what came back." -Type Comment
    }
    
    if (-not (Test-VerboseMode)) {
        Write-ColorOutput "# Turn on Settings > PowerShell Verbose Mode for exception types, inner errors and stack trace." -Type Comment
        return
    }
    
    $depth = 0
    for ($cur = $ex; $cur; $cur = $cur.InnerException) {
        Write-ColorOutput "  [$depth] $($cur.GetType().FullName): $($cur.Message)" -Type Warning
        $depth++
    }
    if ($ErrorRecord.CategoryInfo) { Write-ColorOutput "  Category: $($ErrorRecord.CategoryInfo)" -Type Neutral }
    if ($ErrorRecord.FullyQualifiedErrorId) { Write-ColorOutput "  ErrorId: $($ErrorRecord.FullyQualifiedErrorId)" -Type Neutral }
    if ($ErrorRecord.InvocationInfo -and $ErrorRecord.InvocationInfo.PositionMessage) {
        foreach ($line in ($ErrorRecord.InvocationInfo.PositionMessage -split "`r?`n")) { Write-ColorOutput "  $line" -Type Neutral }
    }
    if ($ErrorRecord.ScriptStackTrace) {
        foreach ($line in ($ErrorRecord.ScriptStackTrace -split "`r?`n")) { Write-ColorOutput "  $line" -Type Neutral }
    }
}

function Invoke-PaCall {
    <#
    .SYNOPSIS
        Run a Live-mode call; in Verbose mode log it with timing and show the cmdlet's verbose stream in the console.
        Errors propagate to the caller.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    
    if (-not (Test-VerboseMode)) { return & $Action }
    
    Write-ColorOutput "> $Name" -Type Command
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $output = New-Object System.Collections.Generic.List[object]
    try {
        # Merge the verbose stream so it can be routed into the shared console
        & $Action 4>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.VerboseRecord]) {
                Write-ColorOutput "  VERBOSE: $($_.Message)" -Type Comment
            } else {
                $output.Add($_)
            }
        }
    } finally {
        Write-ColorOutput "  ($($watch.ElapsedMilliseconds) ms)" -Type Comment
    }
    return $output.ToArray()
}

function Test-RequiredModules {
    <#
    .SYNOPSIS
        Validate required PowerShell modules are available
    #>
    if ($Script:Config.SkipModuleValidation) {
        Write-ColorOutput "Skipping module validation (as requested)" -Type Info
        return $true
    }
    
    $requiredModules = @(
        'Microsoft.PowerApps.Administration.PowerShell',
        'Microsoft.PowerApps.PowerShell'
    )
    
    $allPresent = $true
    foreach ($module in $requiredModules) {
        if (Get-Module -Name $module -ErrorAction SilentlyContinue) {
            Write-ColorOutput "[OK] Module '$module' is loaded" -Type Create
        } elseif (Get-Module -Name $module -ListAvailable -ErrorAction SilentlyContinue) {
            Write-ColorOutput "Module '$module' found, importing..." -Type Info
            try {
                Import-Module $module -ErrorAction Stop
                Write-ColorOutput "[OK] Module '$module' imported successfully" -Type Create
            } catch {
                Write-ColorOutput "[X] Failed to import '$module': $_" -Type Delete
                $allPresent = $false
            }
        } else {
            Write-ColorOutput "[X] Module '$module' not found" -Type Warning
            Write-ColorOutput "# Fix: install it for your account:" -Type Comment
            Write-ColorOutput "Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber" -Type Command
            $allPresent = $false
        }
    }
    
    return $allPresent
}

function Get-SampleData {
    <#
    .SYNOPSIS
        Generate realistic sample data for simulation mode
    #>
    param(
        [int]$WorkflowCount = 15,
        [int]$RunsPerWorkflow = 10
    )
    
    $environments = @('Production', 'Development', 'Testing', 'Staging')
    $owners = @('Admin@contoso.onmicrosoft.com', 'User1@contoso.onmicrosoft.com', 'User2@contoso.onmicrosoft.com', 'User3@contoso.onmicrosoft.com')
    $statusOptions = @('Success', 'Failed', 'Running', 'Skipped', 'Suspended')
    
    $workflows = @()
    for ($i = 1; $i -le $WorkflowCount; $i++) {
        $envName = Get-Random -InputObject $environments
        $workflows += [PSCustomObject]@{
            WorkflowId = [guid]::NewGuid()
            WorkflowName = "Workflow_$i"
            DisplayName = "Sample Workflow $i - $(Get-Random -InputObject @('Process', 'Approval', 'Notification', 'Integration'))"
            Environment = $envName
            EnvironmentName = $envName
            Owner = Get-Random -InputObject $owners
            IsPublished = $true
            CreatedOn = (Get-Date).AddDays(-([int]$(Get-Random -Minimum 1 -Maximum 180)))
            LastModified = (Get-Date).AddDays(-([int]$(Get-Random -Minimum 0 -Maximum 30)))
            IsOwnerActive = Get-Random -InputObject @($true, $true, $true, $false)
            RunCount = Get-Random -Minimum 5 -Maximum 500
            FailureCount = Get-Random -Minimum 0 -Maximum 50
            HasErrorHandling = Get-Random -InputObject @($true, $false)
            IsReEntrant = Get-Random -InputObject @($true, $false)
            Runs = @()
        }
    }
    
    # Add runs to each workflow
    foreach ($workflow in $workflows) {
        for ($j = 0; $j -lt $RunsPerWorkflow; $j++) {
            $status = if ($j -lt 2) { Get-Random -InputObject @('Failed', 'Failed', 'Running') } else { Get-Random -InputObject $statusOptions }
            
            $workflow.Runs += [PSCustomObject]@{
                RunId = [guid]::NewGuid()
                WorkflowId = $workflow.WorkflowId
                StartTime = (Get-Date).AddDays(-([int]$(Get-Random -Minimum 0 -Maximum 30))).AddHours(-([int]$(Get-Random -Minimum 0 -Maximum 23)))
                EndTime = if ($status -eq 'Running') { $null } else { (Get-Date).AddSeconds(-([int]$(Get-Random -Minimum 1 -Maximum 3600))) }
                Status = $status
                ErrorCode = if ($status -eq 'Failed') { Get-Random -InputObject @('500', '400', 'TimeoutException', 'AuthenticationFailed', 'Invalid Input') } else { $null }
                ErrorMessage = if ($status -eq 'Failed') { "Error executing step X in workflow" } else { $null }
                TriggerType = Get-Random -InputObject @('Manual', 'Automated', 'Scheduled')
            }
        }
    }
    
    return $workflows
}

function Get-LiveEnvironments {
    <#
    .SYNOPSIS
        List Power Platform environments (default environment first)
    #>
    $Script:LastLiveError = $null
    if (-not (Test-RequiredModules)) {
        $Script:LastLiveError = 'required PowerShell modules are missing or failed to load (Settings > Validate Modules Now)'
        Write-ColorOutput "Cannot list environments without the required modules" -Type Delete
        return $null
    }
    if (-not (Connect-PaSession)) { return $null }
    
    try {
        $environments = @(Invoke-PaCall -Name 'Get-AdminPowerAppEnvironment' -Action { Get-AdminPowerAppEnvironment -ErrorAction Stop -Verbose:(Test-VerboseMode) })
    } catch {
        $Script:LastLiveError = $_.Exception.Message
        Write-ErrorDetail -Context 'Error listing environments' -ErrorRecord $_
        Write-ColorOutput "# Fix: Settings tab > Test Connection shows what is missing (sign-in, admin role, network)." -Type Comment
        return $null
    }
    
    if ($environments.Count -eq 0) {
        $Script:LastLiveError = 'the call succeeded but returned 0 environments (sign in with a Power Platform admin account: Add-PowerAppsAccount)'
        Write-ColorOutput "No environments returned: $Script:LastLiveError" -Type Warning
    }
    
    $list = foreach ($e in $environments) {
        $display = if ($e.DisplayName) { [string]$e.DisplayName } else { [string]$e.EnvironmentName }
        [PSCustomObject]@{
            Label       = "$display ($($e.EnvironmentName))"
            DisplayName = $display
            Name        = [string]$e.EnvironmentName
            IsDefault   = [bool]$e.IsDefault
        }
    }
    return @($list | Sort-Object -Property @{ Expression = 'IsDefault'; Descending = $true }, Label)
}

function ConvertTo-SafeDate {
    param($Value)
    if ($null -eq $Value -or "$Value" -eq '') { return $null }
    try { return [datetime]$Value } catch { return $null }
}

function Get-LiveData {
    <#
    .SYNOPSIS
        Retrieve the flows of ONE environment from Power Automate, shaped like the sample data
    #>
    param(
        [Parameter(Mandatory)]$Environment
    )
    
    $Script:LastLiveError = $null
    if (-not (Test-RequiredModules)) {
        $Script:LastLiveError = 'required PowerShell modules are missing or failed to load (Settings > Validate Modules Now)'
        Write-ColorOutput "Cannot proceed in Live mode without required modules" -Type Delete
        return $null
    }
    if (-not (Connect-PaSession)) { return $null }
    
    try {
        Write-ColorOutput "Loading flows for environment '$($Environment.DisplayName)'..." -Type Info
        $envName = $Environment.Name
        $flows = @(Invoke-PaCall -Name "Get-AdminFlow -EnvironmentName $envName" -Action { Get-AdminFlow -EnvironmentName $envName -ErrorAction Stop -Verbose:(Test-VerboseMode) })
    } catch {
        $Script:LastLiveError = $_.Exception.Message
        Write-ErrorDetail -Context 'Error retrieving flows' -ErrorRecord $_
        Write-ColorOutput "# Fix: Settings tab > Test Connection shows what is missing (sign-in, admin role, network)." -Type Comment
        return $null
    }
    
    $workflows = foreach ($f in $flows) {
        $creator = $f.CreatedBy
        $owner = if ($creator.userPrincipalName) { $creator.userPrincipalName } elseif ($creator.email) { $creator.email } elseif ($creator.displayName) { $creator.displayName } else { $creator.userId }
        [PSCustomObject]@{
            WorkflowId       = $f.FlowName
            WorkflowName     = $f.FlowName
            DisplayName      = if ($f.DisplayName) { $f.DisplayName } else { $f.FlowName }
            Environment      = $Environment.DisplayName
            EnvironmentName  = $Environment.Name
            Owner            = [string]$owner
            IsPublished      = [bool]$f.Enabled
            CreatedOn        = ConvertTo-SafeDate $f.CreatedTime
            LastModified     = ConvertTo-SafeDate $f.LastModifiedTime
            IsOwnerActive    = $null
            RunCount         = $null
            FailureCount     = $null
            HasErrorHandling = $null
            IsReEntrant      = $null
            Runs             = @()
        }
    }
    
    Write-ColorOutput "Loaded $(@($workflows).Count) flow(s)" -Type Create
    return @($workflows)
}

function Get-LiveRuns {
    <#
    .SYNOPSIS
        Retrieve run history for one live workflow (returns $null if the call failed)
    #>
    param(
        [Parameter(Mandatory)]$Workflow
    )
    
    $Script:LastLiveError = $null
    if (-not (Test-PaSignedIn)) {
        $Script:LastLiveError = 'not signed in (Settings > Sign in)'
        Write-ColorOutput "Cannot read runs: $Script:LastLiveError" -Type Delete
        return $null
    }
    
    try {
        $envName = $Workflow.EnvironmentName
        $flowName = $Workflow.WorkflowId
        $runs = @(Invoke-PaCall -Name "Get-FlowRun -EnvironmentName $envName -FlowName $flowName" -Action { Get-FlowRun -EnvironmentName $envName -FlowName $flowName -ErrorAction Stop -Verbose:(Test-VerboseMode) })
    } catch {
        $Script:LastLiveError = $_.Exception.Message
        Write-ErrorDetail -Context "[X] $($Workflow.DisplayName)" -ErrorRecord $_
        return $null
    }
    
    return @(foreach ($r in $runs) {
        $errorMessage = if ($r.Error -is [string]) { $r.Error } elseif ($r.Error.message) { $r.Error.message } else { $null }
        [PSCustomObject]@{
            RunId        = $r.FlowRunName
            WorkflowId   = $Workflow.WorkflowId
            StartTime    = ConvertTo-SafeDate $r.StartTime
            EndTime      = ConvertTo-SafeDate $r.EndTime
            Status       = [string]$r.Status
            ErrorCode    = $r.Code
            ErrorMessage = $errorMessage
            TriggerType  = $r.Internal.properties.trigger.name
        }
    })
}

#endregion

#region WPF UI Definition

function New-PowerAutomateUI {
    <#
    .SYNOPSIS
        Create and display WPF UI for Power Automate Inspector
    #>
    
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
    
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Power Automate Failed Runs Inspector"
        Height="900" Width="1400"
        Background="$($ColorPalette.Neutral)"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*" MinHeight="150"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition x:Name="ConsoleRow" Height="170"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Title Bar -->
        <Border Grid.Row="0" Background="$($ColorPalette.Header)" Padding="20">
        <StackPanel>
            <TextBlock Text="Power Automate Workflow Inspector" 
                       Foreground="$($ColorPalette.Text)" 
                       FontSize="24" 
                       FontWeight="Bold"/>
            <StackPanel Orientation="Horizontal" Margin="0,5,0,0">
                <TextBlock x:Name="ModeIndicator" 
                           Text="Mode: Simulation" 
                           Foreground="#3A3A5A" 
                           FontSize="12"
                           VerticalAlignment="Center"
                           ToolTip="Current data source. Simulation = sample data, Live = Power Automate. Change it on the Settings tab."/>
                <TextBlock x:Name="SimulationWarning"
                           Text="&#x26A0;"
                           FontFamily="Segoe UI Symbol"
                           Foreground="#D32F2F"
                           FontSize="16"
                           FontWeight="Bold"
                           Margin="8,0,0,0"
                           VerticalAlignment="Center"
                           ToolTip="Simulation mode: showing sample data, not live Power Automate data"/>
            </StackPanel>
        </StackPanel>
        </Border>
        
        <!-- Main Content with Tabs -->
        <TabControl Grid.Row="1" Margin="10" x:Name="MainTabs" ToolTip="Switch between inspector views">
            <TabControl.Resources>
                <Style TargetType="TabItem">
                    <Setter Property="HeaderTemplate">
                        <Setter.Value>
                            <DataTemplate>
                                <TextBlock Text="{Binding}" ToolTip="{Binding RelativeSource={RelativeSource AncestorType=TabItem}, Path=Tag}"/>
                            </DataTemplate>
                        </Setter.Value>
                    </Setter>
                </Style>
            </TabControl.Resources>
            <!-- Workflows Tab -->
            <TabItem Header="Workflows" Tag="Flows in the selected environment with owner, run and failure counts" Background="$($ColorPalette.Info)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Filters -->
                    <GroupBox Grid.Row="0" Header="Filters" Margin="10,10,10,0" Padding="10" ToolTip="Choose which environment to load and narrow the list. Load Environments first, then Owners (owners come from the flows of the selected environment).">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="1.5*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            
                            <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                <TextBlock Text="1. Environment:" FontWeight="Bold" ToolTip="Step 1: environments load first. Live mode loads flows for this one environment only."/>
                                <TextBox x:Name="FilterEnvSearch" Padding="3" Margin="0,0,0,3" ToolTip="Type part of an environment name or ID to narrow the list below"/>
                                <ComboBox x:Name="FilterEnvironment" Padding="5" DisplayMemberPath="Label" ToolTip="Step 1: environments load first. Only the first matches are listed; use the search box above to find others."/>
                                <TextBlock x:Name="EnvCountText" Text="" Foreground="Gray" FontSize="11" ToolTip="How many environments match the search"/>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="1" Margin="0,0,10,0">
                                <TextBlock Text="2. Owner:" FontWeight="Bold" ToolTip="Step 2: owners are filled from the flows of the selected environment, so Environments must load first."/>
                                <ComboBox x:Name="FilterOwner" Padding="5" SelectedIndex="0" ToolTip="Step 2: owners appear after Environments and flows have loaded. Filters the list by flow owner.">
                                    <ComboBoxItem>All Owners</ComboBoxItem>
                                </ComboBox>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="2" Margin="0,0,10,0">
                                <TextBlock Text="Status:" FontWeight="Bold" ToolTip="Show only flows that have at least one run with this status"/>
                                <ComboBox x:Name="FilterStatus" Padding="5" SelectedIndex="0" ToolTip="Filter by run status (needs run history; press Refresh on Run History in Live mode)">
                                    <ComboBoxItem>All Status</ComboBoxItem>
                                    <ComboBoxItem>Failed</ComboBoxItem>
                                    <ComboBoxItem>Success</ComboBoxItem>
                                    <ComboBoxItem>Running</ComboBoxItem>
                                </ComboBox>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="3">
                                <Button Content="Apply Filters" Padding="10,4" Background="$($ColorPalette.Create)" Foreground="$($ColorPalette.Text)" x:Name="ApplyFiltersBtn" ToolTip="Apply the owner and status filters to the loaded flows"/>
                                <Button Content="Refresh" Padding="10,4" Margin="0,5,0,0" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" x:Name="RefreshWorkflowsBtn" ToolTip="Reload flows for the selected environment (Live) or regenerate sample data (Simulation)"/>
                                <TextBlock x:Name="WorkflowsRefreshed" Text="Last refreshed: never" FontSize="11" Foreground="Gray" Margin="0,3,0,0" ToolTip="When the workflow list was last reloaded"/>
                            </StackPanel>
                        </Grid>
                    </GroupBox>
                    
                    <!-- Environment / Owner load status (hover for the full reason) -->
                    <StackPanel Grid.Row="1" Margin="12,4,12,0">
                        <TextBlock x:Name="EnvStatusText" Text="Environments: not loaded yet" TextWrapping="Wrap" FontSize="12" ToolTip="Environments load first. Hover after a load to see why it failed."/>
                        <TextBlock x:Name="OwnerStatusText" Text="Owners: waiting for Environments" TextWrapping="Wrap" FontSize="12" ToolTip="Owners load after Environments and flows. Hover after a load to see why it failed."/>
                    </StackPanel>
                    
                    <!-- Workflows DataGrid -->
                    <DataGrid Grid.Row="2" x:Name="WorkflowsGrid" 
                             AutoGenerateColumns="False" 
                             CanUserAddRows="False"
                             Margin="10"
                             ToolTip="Workflows matching the current filters">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Workflow Name" Binding="{Binding DisplayName}" Width="250"/>
                            <DataGridTextColumn Header="Environment" Binding="{Binding Environment}" Width="100"/>
                            <DataGridTextColumn Header="Owner" Binding="{Binding Owner}" Width="150"/>
                            <DataGridTextColumn Header="Runs" Binding="{Binding RunCount}" Width="60"/>
                            <DataGridTextColumn Header="Failures" Binding="{Binding FailureCount}" Width="80"/>
                            <DataGridCheckBoxColumn Header="Active Owner" Binding="{Binding IsOwnerActive}" Width="80"/>
                            <DataGridCheckBoxColumn Header="Error Handling" Binding="{Binding HasErrorHandling}" Width="100"/>
                            <DataGridCheckBoxColumn Header="Re-entrant" Binding="{Binding IsReEntrant}" Width="80"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    
                    <!-- Action Buttons -->
                    <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="10" HorizontalAlignment="Right">
                        <Button Content="View Details" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" x:Name="ViewDetailsBtn" ToolTip="Show details of the selected workflow"/>
                        <Button Content="Code Review" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Warning)" Foreground="$($ColorPalette.Text)" x:Name="CodeReviewBtn" ToolTip="Open the Code Review tab for the selected workflow (loads its definition, or a sample in Simulation mode)"/>
                        <Button Content="Dependencies" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" x:Name="DependenciesBtn" ToolTip="Show what the selected workflow depends on"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- Run History Tab -->
            <TabItem Header="Run History" Tag="Runs of the listed workflows within a date range" Background="$($ColorPalette.Info)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Date Filter -->
                    <GroupBox Grid.Row="0" Header="Date Range Filter" Margin="10" Padding="10" ToolTip="Only runs that started within this range are shown (default: last 7 days)">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            
                            <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                <TextBlock Text="From Date:" FontWeight="Bold" ToolTip="First day to include (default: one week ago)"/>
                                <DatePicker x:Name="DateFrom" Padding="5" ToolTip="First day to include (default: one week ago)"/>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="1" Margin="0,0,10,0">
                                <TextBlock Text="To Date:" FontWeight="Bold" ToolTip="Last day to include, through end of day (default: today)"/>
                                <DatePicker x:Name="DateTo" Padding="5" ToolTip="Last day to include, through end of day (default: today)"/>
                            </StackPanel>
                            
                            <StackPanel Grid.Column="2">
                                <Button Content="Refresh" Padding="10,4" Background="$($ColorPalette.Create)" Foreground="$($ColorPalette.Text)" x:Name="RefreshRunsBtn" ToolTip="Reload run history for the workflows listed on the Workflows tab"/>
                                <TextBlock x:Name="RunsRefreshed" Text="Last refreshed: never" FontSize="11" Foreground="Gray" Margin="0,3,0,0" ToolTip="When run history was last reloaded"/>
                            </StackPanel>
                        </Grid>
                    </GroupBox>
                    
                    <TextBlock Grid.Row="1" x:Name="RunsScopeText" Margin="12,0,10,0" FontWeight="SemiBold" TextWrapping="Wrap" Text="Scope: (not loaded)" ToolTip="Which environment and tenant the runs below come from. Runs are loaded only for flows listed on the Workflows tab (one environment), not the whole tenant."/>
                    
                    <!-- Runs DataGrid -->
                    <DataGrid Grid.Row="2" x:Name="RunsGrid" 
                             AutoGenerateColumns="False" 
                             CanUserAddRows="False"
                             Margin="10"
                             ToolTip="Runs within the selected date range, newest first">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Workflow" Binding="{Binding WorkflowName}" Width="200"/>
                            <DataGridTextColumn Header="Start Time" Binding="{Binding StartTime, StringFormat='{}{0:g}'}" Width="150"/>
                            <DataGridTextColumn Header="End Time" Binding="{Binding EndTime, StringFormat='{}{0:g}'}" Width="150"/>
                            <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="80"/>
                            <DataGridTextColumn Header="Error Code" Binding="{Binding ErrorCode}" Width="100"/>
                            <DataGridTextColumn Header="Error Message" Binding="{Binding ErrorMessage}" Width="300"/>
                            <DataGridTextColumn Header="Trigger Type" Binding="{Binding TriggerType}" Width="80"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    
                    <!-- Action Buttons -->
                    <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="10" HorizontalAlignment="Right">
                        <Button Content="Code Review" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Warning)" Foreground="$($ColorPalette.Text)" x:Name="CodeReviewRunsBtn" ToolTip="Open the Code Review tab for the flow of the selected run"/>
                        <Button Content="Restart Selected" Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Create)" Foreground="$($ColorPalette.Text)" x:Name="RestartBtn" ToolTip="Restart the selected failed run"/>
                        <Button Content="Export..." Padding="10" Margin="0,0,5,0" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" x:Name="ExportBtn" ToolTip="Export the runs shown in the grid"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- Code Review Tab -->
            <TabItem Header="Code Review" Tag="Re-entrancy, error handling and best-practice findings" Background="$($ColorPalette.Warning)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Review Info -->
                    <TextBlock Grid.Row="0" Text="Code Review Analysis - Re-entrancy, Error Handling, Best Practices" 
                              Margin="10" FontSize="14" FontWeight="Bold" ToolTip="Findings for the reviewed workflows"/>
                    
                    <!-- Review Content -->
                    <Grid Grid.Row="1" Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <WrapPanel Grid.Row="0" Margin="0,0,0,6">
                            <TextBlock Text="Source:" VerticalAlignment="Center" Margin="0,0,5,0" FontWeight="Bold" ToolTip="Sample or exported flow definition (.json / .zip) to review offline"/>
                            <ComboBox x:Name="CRSource" Width="330" DisplayMemberPath="Label" Margin="0,0,5,0" ToolTip="Files from the WorkflowSamples folder. Copy exported flow .json files there and click Rescan."/>
                            <Button x:Name="CRRescan" Content="Rescan" Padding="8,3" Margin="0,0,5,0" ToolTip="Reload the list from the WorkflowSamples folder"/>
                            <Button x:Name="CRBrowse" Content="Browse..." Padding="8,3" Margin="0,0,5,0" ToolTip="Pick any exported flow .json (definition.json or portal export .zip)"/>
                            <Button x:Name="CRReviewSource" Content="Review source" Padding="10,3" Margin="0,0,15,0" Background="$($ColorPalette.Warning)" ToolTip="Run all review rules on the chosen source file"/>
                            <Button x:Name="CRReviewSelected" Content="Review selected flow" Padding="10,3" Margin="0,0,5,0" Background="$($ColorPalette.Warning)" ToolTip="Review the flow selected on Workflows or Run History (Live: downloads its definition; Simulation: maps to a sample file)"/>
                            <Button x:Name="CRExport" Content="Export report..." Padding="10,3" Margin="0,0,5,0" ToolTip="Save the last review as Markdown, CSV or HTML"/>
                            <Button x:Name="CRChecker" Content="Flow Checker (experimental)" Padding="10,3" Margin="0,0,5,0" ToolTip="Try the Power Automate cloud Flow Checker for the selected live flow. Unofficial endpoint - may be unavailable; the local rules above are the dependable review."/>
                        </WrapPanel>
                        <StackPanel Grid.Row="1" Margin="0,0,0,6">
                            <TextBlock x:Name="CRTitle" Text="No review yet - pick a source and click Review" FontWeight="Bold" FontSize="13" TextWrapping="Wrap" ToolTip="Flow being reviewed"/>
                            <WrapPanel x:Name="CRBadges" Margin="0,4,0,0"/>
                        </StackPanel>
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="5"/>
                                <ColumnDefinition Width="3*"/>
                            </Grid.ColumnDefinitions>
                            <TreeView x:Name="CRTree" Grid.Column="0" ToolTip="Flow structure. Colour = worst finding on that action (red High, orange Medium, blue Low). Hover for details."/>
                            <GridSplitter Grid.Column="1" Width="5" HorizontalAlignment="Stretch"/>
                            <DataGrid x:Name="CodeReviewList" Grid.Column="2" AutoGenerateColumns="False" CanUserAddRows="False" IsReadOnly="True" ToolTip="Findings. Click a row to highlight the action in the tree.">
                                <DataGrid.RowStyle>
                                    <Style TargetType="DataGridRow">
                                        <Style.Triggers>
                                            <DataTrigger Binding="{Binding Severity}" Value="High"><Setter Property="Background" Value="#FDE0E0"/></DataTrigger>
                                            <DataTrigger Binding="{Binding Severity}" Value="Medium"><Setter Property="Background" Value="#FFF0CC"/></DataTrigger>
                                            <DataTrigger Binding="{Binding Severity}" Value="Low"><Setter Property="Background" Value="#E8F0FF"/></DataTrigger>
                                        </Style.Triggers>
                                    </Style>
                                </DataGrid.RowStyle>
                                <DataGrid.Columns>
                                    <DataGridTextColumn Header="Severity" Binding="{Binding Severity}" Width="65"/>
                                    <DataGridTextColumn Header="Rule" Binding="{Binding Rule}" Width="130"/>
                                    <DataGridTextColumn Header="Action" Binding="{Binding Action}" Width="120"/>
                                    <DataGridTextColumn Header="Finding" Binding="{Binding Message}" Width="260"><DataGridTextColumn.ElementStyle><Style TargetType="TextBlock"><Setter Property="TextWrapping" Value="Wrap"/></Style></DataGridTextColumn.ElementStyle></DataGridTextColumn>
                                    <DataGridTextColumn Header="Recommendation" Binding="{Binding Recommendation}" Width="260"><DataGridTextColumn.ElementStyle><Style TargetType="TextBlock"><Setter Property="TextWrapping" Value="Wrap"/></Style></DataGridTextColumn.ElementStyle></DataGridTextColumn>
                                    <DataGridTextColumn Header="Source" Binding="{Binding Source}" Width="70"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </Grid>
                    </Grid>
                    <ListBox Visibility="Collapsed" Grid.Row="1" x:Name="CodeReviewLegacy">
                        <ListBox.ItemTemplate>
                            <DataTemplate>
                                <Border BorderBrush="#DDD" BorderThickness="1" Padding="10" Margin="0,5,0,5" CornerRadius="5">
                                    <StackPanel>
                                        <TextBlock Text="{Binding WorkflowName}" FontWeight="Bold" FontSize="12"/>
                                        <TextBlock Text="{Binding Issue}" Foreground="$($ColorPalette.DeleteText)" Margin="0,5,0,0"/>
                                        <TextBlock Text="{Binding Recommendation}" Foreground="$($ColorPalette.CreateText)" Margin="0,5,0,0"/>
                                    </StackPanel>
                                </Border>
                            </DataTemplate>
                        </ListBox.ItemTemplate>
                    </ListBox>
                </Grid>
            </TabItem>
            
            <!-- Export Tab -->
            <TabItem Header="Export" Tag="Choose a format and content, then export" Background="$($ColorPalette.Create)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Export Options -->
                    <GroupBox Grid.Row="0" Header="Export Format" Margin="10" Padding="10" ToolTip="File format for the export">
                        <StackPanel>
                            <RadioButton x:Name="ExportCSV" Content="CSV" Margin="0,5,0,5" IsChecked="True" ToolTip="Comma-separated values"/>
                            <RadioButton x:Name="ExportTSV" Content="TSV" Margin="0,5,0,5" ToolTip="Tab-separated values"/>
                            <RadioButton x:Name="ExportHTML" Content="HTML" Margin="0,5,0,5" ToolTip="Web page with tables"/>
                            <RadioButton x:Name="ExportExcel" Content="Excel (XLSX)" Margin="0,5,0,5" ToolTip="Excel workbook"/>
                            <RadioButton x:Name="ExportMarkdown" Content="Markdown" Margin="0,5,0,5" ToolTip="Markdown tables"/>
                        </StackPanel>
                    </GroupBox>
                    
                    <!-- Export Content Type -->
                    <GroupBox Grid.Row="1" Header="Export Content" Margin="10" Padding="10" ToolTip="What to include in the export">
                        <StackPanel>
                            <CheckBox x:Name="ExportWorkflows" Content="Workflows" IsChecked="True" Margin="0,5,0,5" ToolTip="Include the workflow list"/>
                            <CheckBox x:Name="ExportRuns" Content="Run History" IsChecked="True" Margin="0,5,0,5" ToolTip="Include run history"/>
                            <CheckBox x:Name="ExportCodeReview" Content="Code Review" Margin="0,5,0,5" ToolTip="Include code review findings"/>
                        </StackPanel>
                    </GroupBox>
                    
                    <!-- Export Button -->
                    <Button Grid.Row="2" 
                           Content="Export Now" 
                           Padding="20,10" 
                           Height="50" 
                           Width="200" 
                           HorizontalAlignment="Center" 
                           VerticalAlignment="Top"
                           Background="$($ColorPalette.Create)" 
                           Foreground="$($ColorPalette.Text)" 
                           FontSize="14"
                           x:Name="ExportNowBtn" ToolTip="Export the selected content in the selected format"/>
                </Grid>
            </TabItem>
            
            <!-- Test Tab -->
            <TabItem Header="Test" Tag="Check each Live-mode step on a small sample before using the other tabs" Background="$($ColorPalette.Warning)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    
                    <TextBlock Grid.Row="0" Margin="10,10,10,0" TextWrapping="Wrap" Foreground="Gray"
                               Text="Run the steps in order: Environments load first, then Flows, then Owners, then Runs. Each button's screen tip shows what it does and its latest status; the same status goes to the PowerShell console below (with detail when Verbose mode is on in Settings)."
                               ToolTip="Each step depends on the one before it"/>
                    
                    <GroupBox Grid.Row="1" Header="Steps" Margin="10" Padding="10" ToolTip="Run one step at a time, or all of them">
                        <WrapPanel>
                            <StackPanel Orientation="Horizontal" Margin="0,0,15,5" ToolTip="How many items each sample step retrieves (1-10)">
                                <TextBlock Text="Sample size:" VerticalAlignment="Center" FontWeight="Bold" Margin="0,0,5,0"/>
                                <ComboBox x:Name="TestSampleSize" Width="50" SelectedIndex="4">
                                    <ComboBoxItem>1</ComboBoxItem><ComboBoxItem>2</ComboBoxItem><ComboBoxItem>3</ComboBoxItem><ComboBoxItem>4</ComboBoxItem><ComboBoxItem>5</ComboBoxItem>
                                    <ComboBoxItem>6</ComboBoxItem><ComboBoxItem>7</ComboBoxItem><ComboBoxItem>8</ComboBoxItem><ComboBoxItem>9</ComboBoxItem><ComboBoxItem>10</ComboBoxItem>
                                </ComboBox>
                            </StackPanel>
                            <Button x:Name="TestPrereqBtn" Content="1. Prerequisites" Padding="10,4" Margin="0,0,5,5" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)"                             ToolTip="Step 1 - Checks PowerShell edition, execution policy, network, modules, sign-in and admin API access. Run this first."/>
                                                        <Button x:Name="TestEnvsBtn" Content="2. Sample Environments" Padding="10,4" Margin="0,0,5,5" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Step 2 - Lists environments and shows the first N. Also fills the Environment list on Workflows. Needs step 1 to pass."/>
                                                        <Button x:Name="TestFlowsBtn" Content="3. Sample Flows" Padding="10,4" Margin="0,0,5,5" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Step 3 - Gets the flows of the environment selected on Workflows and shows the first N. Needs an environment (step 2)."/>
                                                        <Button x:Name="TestOwnersBtn" Content="4. Sample Owners" Padding="10,4" Margin="0,0,5,5" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Step 4 - Shows the top N owners (flow creators) from the flows of step 3. Environments load first, then Flows, then Owners."/>
                                                        <Button x:Name="TestRunsBtn" Content="5. Sample Runs" Padding="10,4" Margin="0,0,5,5" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Step 5 - Gets the runs of the first flow from step 3 and shows the latest N."/>
                                                        <Button x:Name="TestProbeBtn" Content="Raw HTTP probe" Padding="10,4" Margin="0,0,5,5" Background="$($ColorPalette.Warning)" Foreground="$($ColorPalette.Text)" ToolTip="Extra - Calls the environments REST endpoint directly and shows status, content type and the start of the body. Use it when a step fails with 'Invalid JSON primitive'."/>
                                                        <Button x:Name="TestAllBtn" Content="Run all" Padding="10,4" Margin="10,0,5,5" Background="$($ColorPalette.Create)" Foreground="$($ColorPalette.Text)" ToolTip="Extra - Runs steps 1-5 in order and stops at the first failure."/>
                        </WrapPanel>
                    </GroupBox>
                    
                                                <TextBlock Grid.Row="2" x:Name="TestStatusText" Margin="12,0,12,5" TextWrapping="Wrap" FontWeight="SemiBold" Foreground="#5A5A5A" Text="Status: no step run yet" ToolTip="Status of the most recent step"/>
                    
                                                <DataGrid Grid.Row="3" x:Name="TestResultsGrid" Margin="10,0,10,5" AutoGenerateColumns="False" CanUserAddRows="False" IsReadOnly="True" ToolTip="Outcome of each step that was run">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Time" Binding="{Binding Time}" Width="70"/>
                            <DataGridTextColumn Header="Step" Binding="{Binding Step}" Width="170"/>
                            <DataGridTextColumn Header="Result" Binding="{Binding Result}" Width="70"/>
                            <DataGridTextColumn Header="ms" Binding="{Binding Ms}" Width="60"/>
                            <DataGridTextColumn Header="Detail" Binding="{Binding Detail}" Width="*"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    
                    <DataGrid Grid.Row="4" x:Name="TestSampleGrid" Margin="10,0,10,10" AutoGenerateColumns="True" CanUserAddRows="False" IsReadOnly="True" ToolTip="The sample items returned by the last step"/>
                </Grid>
            </TabItem>
            
            <!-- Settings Tab -->
            <TabItem Header="Settings" Tag="Data source, connection test and module validation" Background="$($ColorPalette.Info)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel VerticalAlignment="Top" Margin="10">
                        <GroupBox Header="Data Source" Padding="10" Margin="0,0,0,20" ToolTip="Choose where data comes from">
                            <StackPanel>
                                <RadioButton x:Name="ModeSimulation" Content="Simulation Mode (Sample Data)" IsChecked="True" Margin="0,5,0,5" ToolTip="Use generated sample data; nothing is read from Power Automate"/>
                                <RadioButton x:Name="ModeLive" Content="Live Mode (Connect to Power Automate)" Margin="0,5,0,5" ToolTip="Read environments, flows and runs from Power Automate (needs the PowerApps modules and a sign-in)"/>
                                <Button Content="Test Connection" Padding="10" Margin="10,10,0,0" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" x:Name="TestConnectionBtn" Width="150" HorizontalAlignment="Left" ToolTip="Check PowerShell, network, modules, sign-in and admin API access; fixes are shown in the console"/>
                            </StackPanel>
                        </GroupBox>
                        
                        <GroupBox Header="Power Platform Sign-in" Padding="10" Margin="0,0,0,20" ToolTip="Add-PowerAppsAccount runs inside this app. A sign-in made in another PowerShell window does not carry over.">
                            <StackPanel>
                                <TextBlock x:Name="SignInState" Text="Not signed in" FontWeight="SemiBold" TextWrapping="Wrap" ToolTip="Current Power Platform session of this app"/>
                                <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
                                    <Button x:Name="SignInBtn" Content="Sign in" Width="100" Padding="8,4" Margin="0,0,5,0" Background="$($ColorPalette.Create)" Foreground="$($ColorPalette.Text)" ToolTip="Run Add-PowerAppsAccount (opens the Microsoft sign-in window)"/>
                                    <Button x:Name="SignOutBtn" Content="Sign out" Width="100" Padding="8,4" Background="$($ColorPalette.Warning)" Foreground="$($ColorPalette.Text)" ToolTip="Run Remove-PowerAppsAccount"/>
                                </StackPanel>
                                <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
                                    <TextBlock Text="Endpoint:" VerticalAlignment="Center" Margin="0,0,5,0" ToolTip="Cloud: prod, usgov, usgovhigh, dod, china. Leave blank for prod."/>
                                    <ComboBox x:Name="SignInEndpoint" Width="110" IsEditable="True" Margin="0,0,15,0" ToolTip="Cloud: prod, usgov, usgovhigh, dod, china. Leave blank for the default (prod).">
                                        <ComboBoxItem>prod</ComboBoxItem><ComboBoxItem>usgov</ComboBoxItem><ComboBoxItem>usgovhigh</ComboBoxItem><ComboBoxItem>dod</ComboBoxItem><ComboBoxItem>china</ComboBoxItem>
                                    </ComboBox>
                                    <TextBlock Text="Tenant ID:" VerticalAlignment="Center" Margin="0,0,5,0" ToolTip="Optional tenant GUID to sign in to"/>
                                    <TextBox x:Name="SignInTenant" Width="280" Padding="3" ToolTip="Optional tenant GUID. Leave blank to use your home tenant."/>
                                </StackPanel>
                            </StackPanel>
                        </GroupBox>
                        
                        <GroupBox Header="PowerShell Verbose Mode" Padding="10" Margin="0,0,0,20" ToolTip="Troubleshooting: PowerShell verbose output plus full error detail">
                            <StackPanel>
                                <CheckBox x:Name="VerboseMode" Content="PowerShell Verbose mode ON" ToolTip="Sets `$VerbosePreference = Continue and passes -Verbose to every Live cmdlet call. The console then shows each call with timing, the cmdlet's verbose lines, and errors with exception chain and stack trace. Saved in the settings file."/>
                                <TextBlock x:Name="VerboseState" Text="" Margin="0,5,0,0" Foreground="Gray" TextWrapping="Wrap" ToolTip="Current verbose state"/>
                            </StackPanel>
                        </GroupBox>
                        
                        <GroupBox Header="Module Validation" Padding="10" Margin="0,0,0,20" ToolTip="Required PowerShell modules">
                            <StackPanel>
                                <CheckBox x:Name="SkipModuleValidation" Content="Skip Module Validation on Startup" Margin="0,5,0,10" ToolTip="Do not check for the PowerApps modules when loading live data"/>
                                <Button Content="Validate Modules Now" Padding="10" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" x:Name="ValidateModulesBtn" Width="150" HorizontalAlignment="Left" ToolTip="Check that the required modules are installed and load them"/>
                            </StackPanel>
                        </GroupBox>
                        
                        <GroupBox Header="Information" Padding="10" ToolTip="About this tool">
                            <StackPanel>
                                <TextBlock Text="Power Automate Inspector v1.0.0" FontWeight="Bold"/>
                                <TextBlock Text="PowerShell 5.1+" Margin="0,5,0,0"/>
                                <TextBlock Text="Requires: Microsoft.PowerApps.Administration.PowerShell" Margin="0,5,0,0" Foreground="Gray"/>
                            </StackPanel>
                        </GroupBox>
                    </StackPanel>
                    </ScrollViewer>
                </Grid>
            </TabItem>
            
            <!-- Help Tab -->
            <TabItem Header="Help" Tag="How the tool works, in what order things load, and how to troubleshoot" Background="$($ColorPalette.Info)">
                <Grid Background="$($ColorPalette.Neutral)">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10,10,10,0">
                        <Button x:Name="HelpReloadBtn" Content="Reload" Padding="10,3" Margin="0,0,5,0" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Re-read the Help markdown file"/>
                        <Button x:Name="HelpOpenBtn" Content="Open file" Padding="10,3" Margin="0,0,10,0" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Open the Help markdown file in your default editor"/>
                        <TextBlock x:Name="HelpPathText" VerticalAlignment="Center" Foreground="Gray" FontSize="11" ToolTip="Local markdown file shown below"/>
                    </StackPanel>
                    <RichTextBox Grid.Row="1" x:Name="HelpViewer" Margin="10" IsReadOnly="True" IsDocumentEnabled="True" Padding="8"
                                 VerticalScrollBarVisibility="Auto" Background="#FBFAF5" ToolTip="Help rendered from the local markdown file"/>
                </Grid>
            </TabItem>
        </TabControl>
        
        <!-- Shared PowerShell console (common to all tabs) -->
        <GridSplitter Grid.Row="2" x:Name="ConsoleSplitter" Height="5" HorizontalAlignment="Stretch"
                      ResizeBehavior="PreviousAndNext" ResizeDirection="Rows"                       Background="#DCDCD6" ToolTip="Drag to resize the console"/>
        <Border Grid.Row="3" x:Name="ConsolePanel" Margin="10,0,10,0" BorderBrush="#CFCFC8" BorderThickness="1" Background="#FBFAF5">
            <DockPanel>
                <Border DockPanel.Dock="Top" Background="#ECEAE2" Padding="6,3">
                    <DockPanel>
                        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                            <Button Content="Copy" x:Name="ConsoleCopyBtn" Padding="8,1" Margin="4,0,0,0" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Copy the console text to the clipboard"/>
                            <Button Content="Clear" x:Name="ConsoleClearBtn" Padding="8,1" Margin="4,0,0,0" Background="$($ColorPalette.Warning)" Foreground="$($ColorPalette.Text)" ToolTip="Clear the console"/>
                        </StackPanel>
                        <TextBlock Text="PowerShell Console" FontWeight="Bold" VerticalAlignment="Center" Foreground="$($ColorPalette.Text)" ToolTip="Progress, errors and suggested fix commands"/>
                    </DockPanel>
                </Border>
                <RichTextBox x:Name="ConsoleBox" IsReadOnly="True" BorderThickness="0" Padding="4"
                             Background="#FBFAF5" Foreground="$($ColorPalette.Text)"
                             FontFamily="Consolas" FontSize="12"
                             VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                             ToolTip="Output of checks and data loads; select text to copy"/>
            </DockPanel>
        </Border>
        
        <!-- Status Bar with console toggle and zoom -->
        <Border Grid.Row="4" Background="#ECECEC" Padding="10,6" Margin="0,5,0,0">
            <DockPanel>
                <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                    <ToggleButton x:Name="ConsoleToggleBtn" Content="Console" IsChecked="True" Padding="10,2" Margin="0,0,12,0"
                                  Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Show / hide the PowerShell console"/>
                    <TextBlock Text="Zoom:" VerticalAlignment="Center" Margin="0,0,4,0" Foreground="$($ColorPalette.Text)" ToolTip="Zoom is remembered per tab"/>
                    <Button x:Name="ZoomOutBtn" Content="-" Width="28" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Zoom out current tab (Ctrl+-)"/>
                    <Button x:Name="ZoomResetBtn" Content="100%" Width="52" Margin="2,0" Background="$($ColorPalette.Neutral)" Foreground="$($ColorPalette.Text)" ToolTip="Reset zoom for current tab (Ctrl+0)"/>
                    <Button x:Name="ZoomInBtn" Content="+" Width="28" Background="$($ColorPalette.Info)" Foreground="$($ColorPalette.Text)" ToolTip="Zoom in current tab (Ctrl++ or Ctrl+Mouse Wheel)"/>
                </StackPanel>
                <TextBlock x:Name="StatusText" Text="Ready" VerticalAlignment="Center" Foreground="$($ColorPalette.Text)" ToolTip="Result of the last action"/>
            </DockPanel>
        </Border>
    </Grid>
</Window>
"@
    
    return $xaml
}

#endregion

#region Main Execution

Write-ColorOutput "======================================" -Type Info
Write-ColorOutput "Power Automate Failed Runs Inspector" -Type Info
Write-ColorOutput "======================================" -Type Info
Write-ColorOutput ""

Write-ColorOutput "Starting in $($Script:Config.Mode) mode..." -Type Info

# Create and show WPF UI
Write-ColorOutput "Initializing WPF interface..." -Type Info

$xaml = New-PowerAutomateUI
$reader = [xml.xmlnodereader]::new($xaml)
$window = [windows.markup.xamlreader]::Load($reader)
$Script:Window = $window

# Load persisted UI settings
$Script:Settings = Get-InspectorSettings

# Attach the shared console and replay startup messages into it
$Script:ConsoleBox = $window.FindName('ConsoleBox')
$Script:ConsoleBox.Document.Blocks.Clear()
foreach ($entry in $Script:ConsoleBuffer) {
    Write-UiConsole -Message $entry[0] -Type $entry[1]
}
$Script:ConsoleBuffer.Clear()

$workflowsGrid = $window.FindName('WorkflowsGrid')
$runsGrid = $window.FindName('RunsGrid')
$filterEnv = $window.FindName('FilterEnvironment')
$filterEnvSearch = $window.FindName('FilterEnvSearch')
$filterOwner = $window.FindName('FilterOwner')
$statusText = $window.FindName('StatusText')

$Script:Data = @()
$Script:Filtered = @()
$Script:EnvList = @()
$Script:EnvMaxItems = 50
$Script:LastLiveError = $null
$Script:SuppressModeEvents = $false
$columnTips = @{
    'Workflow Name' = 'Display name of the flow'
    'Environment'   = 'Environment the flow lives in'
    'Owner'         = 'User who created the flow'
    'Runs'          = 'Number of runs known (Live: loaded by Run History > Refresh)'
    'Failures'      = 'Number of failed runs known'
    'Active Owner'  = 'Whether the owner account is still active (not checked in Live mode yet)'
    'Error Handling' = 'Whether the flow has error handling (not analyzed in Live mode yet)'
    'Re-entrant'    = 'Whether the flow is safe for overlapping runs (not analyzed in Live mode yet)'
    'Workflow'      = 'Flow the run belongs to'
    'Start Time'    = 'When the run started'
    'End Time'      = 'When the run ended (blank while running)'
    'Status'        = 'Run result'
    'Error Code'    = 'Error code of a failed run'
    'Error Message' = 'Error text of a failed run'
    'Trigger Type'  = 'How the run was started'
}
foreach ($grid in @($workflowsGrid, $runsGrid)) {
    foreach ($col in $grid.Columns) {
        $text = [string]$col.Header
        $tip = if ($columnTips.ContainsKey($text)) { $columnTips[$text] } else { $text }
        $col.Header = [System.Windows.Controls.TextBlock]@{ Text = $text; ToolTip = "$tip (click to sort)" }
    }
}

# Run history defaults to the last week
$Script:DateFrom = $window.FindName('DateFrom')
$Script:DateTo = $window.FindName('DateTo')
$Script:DateFrom.SelectedDate = (Get-Date).Date.AddDays(-7)
$Script:DateTo.SelectedDate = (Get-Date).Date

function Set-RefreshStamp {
    param([string]$ElementName)
    $Script:Window.FindName($ElementName).Text = "Last refreshed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

function Set-LoadStatus {
    <#
    .SYNOPSIS
        Show Environment / Owner load status on its status line and on the matching control's screen tip
    #>
    param(
        [ValidateSet('Env', 'Owner')][string]$Kind,
        [ValidateSet('OK', 'Error', 'Pending')][string]$State,
        [string]$Message
    )
    
    $label = if ($Kind -eq 'Env') { 'Environments' } else { 'Owners' }
    $box = $window.FindName($(if ($Kind -eq 'Env') { 'EnvStatusText' } else { 'OwnerStatusText' }))
    $control = if ($Kind -eq 'Env') { $filterEnv } else { $filterOwner }
    $color = switch ($State) { 'OK' { '#1E7A34' } 'Error' { '#B3261E' } default { '#5A5A5A' } }
    
    $box.Text = "$label`: $Message"
    $box.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($color)
    $tip = "$label`: $Message`nOrder: Environments load first, then the flows of one environment, then Owners."
    if ($State -eq 'Error') { $tip += "`nDetail is in the PowerShell console; turn on PowerShell Verbose mode in Settings for more." }
    foreach ($target in @($box, $control)) {
        $target.ToolTip = $tip
        [System.Windows.Controls.ToolTipService]::SetShowDuration($target, 60000)
    }
    Write-ColorOutput "  [status] $label - $State`: $Message" -Type $(if ($State -eq 'Error') { 'Warning' } else { 'Comment' })
    if (Get-Command Update-SignInState -ErrorAction SilentlyContinue) { Update-SignInState }
}

function Set-EnvironmentList {
    <#
    .SYNOPSIS
        Replace the environment list, refresh the drop-down and report the outcome (including why it is empty)
    #>
    param($List)
    
    $Script:EnvList = if ($List) { @($List) } else { @() }
    $filterEnv.ItemsSource = $null
    Update-EnvironmentCombo
    if ($Script:EnvList.Count -gt 0) {
        Set-LoadStatus -Kind Env -State OK -Message "$($Script:EnvList.Count) environment(s) loaded"
    } else {
        $why = if ($Script:LastLiveError) { $Script:LastLiveError } else { 'unknown - see the PowerShell console' }
        Set-LoadStatus -Kind Env -State Error -Message "NOT loaded - $why"
    }
}

function Update-EnvironmentCombo {
    <#
    .SYNOPSIS
        Fill the environment drop-down with the first matches of the search box (thousands of environments are never all listed)
    #>
    $search = $filterEnvSearch.Text.Trim()
    $selectedName = if ($filterEnv.SelectedItem) { $filterEnv.SelectedItem.Name } else { $Script:Settings.EnvironmentName }
    
    $all = @($Script:EnvList)
    $pinned = @($all | Where-Object { $_.Name -eq '' })
    $hits = @($all | Where-Object {
        $_.Name -ne '' -and ($search -eq '' -or $_.Label.IndexOf($search, [StringComparison]::OrdinalIgnoreCase) -ge 0)
    })
    $shown = @($hits | Select-Object -First $Script:EnvMaxItems)
    
    # Keep the current selection visible even when it does not match the search
    if ($selectedName -and -not ($shown | Where-Object { $_.Name -eq $selectedName })) {
        $current = $all | Where-Object { $_.Name -eq $selectedName } | Select-Object -First 1
        if ($current) { $shown = @($current) + $shown }
    }
    $list = @($pinned) + @($shown)
    $filterEnv.ItemsSource = $list
    
    $pick = $list | Where-Object { $_.Name -eq $selectedName } | Select-Object -First 1
    if (-not $pick) { $pick = $list | Select-Object -First 1 }
    $filterEnv.SelectedItem = $pick
    
    $total = @($all | Where-Object { $_.Name -ne '' }).Count
    $window.FindName('EnvCountText').Text = if ($total -eq 0) { '' } elseif ($hits.Count -gt $shown.Count) {
        "Showing $($shown.Count) of $($hits.Count) matching ($total total) - type to narrow"
    } else { "$($hits.Count) of $total environments" }
}

function Update-OwnerFilter {
    $previous = $filterOwner.SelectedItem
    $filterOwner.Items.Clear()
    $filterOwner.Items.Add('All Owners') | Out-Null
    foreach ($owner in @($Script:Data | Select-Object -ExpandProperty Owner -Unique | Where-Object { $_ } | Sort-Object)) {
        $filterOwner.Items.Add($owner) | Out-Null
    }
    $filterOwner.SelectedItem = if ($previous -is [string] -and $filterOwner.Items.Contains($previous)) { $previous } else { 'All Owners' }
    
    if (@($Script:Data).Count -gt 0) {
        $ownerCount = $filterOwner.Items.Count - 1
        Set-LoadStatus -Kind Owner -State OK -Message "$ownerCount owner(s) from $(@($Script:Data).Count) flow(s)"
    }
}

function Update-RunsGrid {
    $from = if ($Script:DateFrom.SelectedDate) { $Script:DateFrom.SelectedDate.Date } else { [datetime]::MinValue }
    $to = if ($Script:DateTo.SelectedDate) { $Script:DateTo.SelectedDate.Date.AddDays(1) } else { [datetime]::MaxValue }
    $rows = foreach ($workflow in $Script:Filtered) {
        foreach ($run in $workflow.Runs) {
            if ($run.StartTime -and $run.StartTime -ge $from -and $run.StartTime -lt $to) {
                [PSCustomObject]@{
                    WorkflowName = $workflow.DisplayName
                    WorkflowId   = $workflow.WorkflowId
                    StartTime    = $run.StartTime
                    EndTime      = $run.EndTime
                    Status       = $run.Status
                    ErrorCode    = $run.ErrorCode
                    ErrorMessage = $run.ErrorMessage
                    TriggerType  = $run.TriggerType
                }
            }
        }
    }
    $runsGrid.ItemsSource = @($rows | Sort-Object -Property StartTime -Descending)
    Update-RunsScope
}

function Update-RunsScope {
    <#
    .SYNOPSIS
        Show which environment / tenant / date range the Run History grid covers
    #>
    $box = $window.FindName('RunsScopeText')
    $range = "$(if ($Script:DateFrom.SelectedDate) { $Script:DateFrom.SelectedDate.ToString('yyyy-MM-dd') } else { 'any' }) to $(if ($Script:DateTo.SelectedDate) { $Script:DateTo.SelectedDate.ToString('yyyy-MM-dd') } else { 'any' })"
    if ($Script:Config.Mode -eq 'Simulation') {
        $box.Text = "Scope: SAMPLE DATA (Simulation) | $($Script:Filtered.Count) workflows | Runs started $range"
        return
    }
    $first = $Script:Data | Select-Object -First 1
    $envText = if ($first) { "$($first.Environment) ($($first.EnvironmentName))" }
               elseif ($filterEnv.SelectedItem -and $filterEnv.SelectedItem.Name) { $filterEnv.SelectedItem.Label }
               else { '(none selected)' }
    $session = $global:currentSession
    $who = if ($session -and $session.upn) { $session.upn } else { 'unknown' }
    $tenant = if ($session -and $session.tenantId) { $session.tenantId } else { 'unknown' }
    $box.Text = "Scope: ONE environment - $envText | $($Script:Filtered.Count) of $($Script:Data.Count) flows listed | Signed in: $who | Tenant: $tenant | Runs started $range"
}

function Update-WorkflowsGrid {
    <#
    .SYNOPSIS
        Apply the owner/status/environment filters to the loaded workflows and refresh both grids
    #>
    # Static XAML entries are ComboBoxItems; dynamically added ones are strings
    $getSelection = { param($item) if ($null -ne $item -and $item -isnot [string]) { [string]$item.Content } else { $item } }
    # Live mode holds one environment at a time, so the drop-down chooses what to load rather than filtering
    $selectedEnv = if ($Script:Config.Mode -eq 'Simulation' -and $filterEnv.SelectedItem) { $filterEnv.SelectedItem.Name } else { '' }
    $selectedOwner = & $getSelection $filterOwner.SelectedItem
    $selectedStatus = & $getSelection $window.FindName('FilterStatus').SelectedItem
    
    $Script:Filtered = @($Script:Data | Where-Object {
        (-not $selectedEnv -or $_.EnvironmentName -eq $selectedEnv) -and
        (-not $selectedOwner -or $selectedOwner -eq 'All Owners' -or $_.Owner -eq $selectedOwner) -and
        (-not $selectedStatus -or $selectedStatus -eq 'All Status' -or ($_.Runs | Where-Object { $_.Status -eq $selectedStatus }))
    })
    
    $workflowsGrid.ItemsSource = @($Script:Filtered | Select-Object -Property DisplayName, Environment, Owner, RunCount, FailureCount, IsOwnerActive, HasErrorHandling, IsReEntrant)
    Update-RunsGrid
}

function Invoke-WorkflowsRefresh {
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        if ($Script:Config.Mode -eq 'Simulation') {
            Write-ColorOutput "Generating sample data..." -Type Create
            $Script:Data = @(Get-SampleData -WorkflowCount 15 -RunsPerWorkflow 10)
        } else {
            $target = $filterEnv.SelectedItem
            if (-not $target -or -not $target.Name) {
                Write-ColorOutput "No environment selected. Use Refresh after the environment list loads." -Type Warning
                $statusText.Text = "Select an environment first"
                Set-LoadStatus -Kind Owner -State Error -Message 'NOT loaded - no environment selected; Environments must load first (see the Environments line)'
                return
            }
            $statusText.Text = "Loading flows for $($target.DisplayName)..."
            Set-LoadStatus -Kind Owner -State Pending -Message "loading flows of '$($target.DisplayName)'..."
            $live = Get-LiveData -Environment $target
            if ($null -eq $live) {
                $statusText.Text = "Could not load flows - see console"
                Set-LoadStatus -Kind Owner -State Error -Message "NOT loaded - flows of '$($target.DisplayName)' could not be retrieved: $Script:LastLiveError"
                return
            }
            $Script:Data = $live
            $Script:Settings.EnvironmentName = $target.Name
            Save-InspectorSettings -Settings $Script:Settings
        }
        Update-OwnerFilter
        Update-WorkflowsGrid
        Set-RefreshStamp 'WorkflowsRefreshed'
        $statusText.Text = "Loaded $($Script:Data.Count) workflows"
    } finally {
        $window.Cursor = $null
    }
}

function Invoke-RunsRefresh {
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        if ($Script:Config.Mode -eq 'Live') {
            if ($Script:Filtered.Count -eq 0) {
                Write-ColorOutput "No workflows loaded. Press Refresh on the Workflows tab first." -Type Warning
                $statusText.Text = "No workflows to load runs for"
                return
            }
            Write-ColorOutput "Loading run history for $($Script:Filtered.Count) workflow(s)..." -Type Info
            if (-not (Connect-PaSession)) {
                $statusText.Text = "Not signed in - see console"
                return
            }
            $failedCalls = 0
            $done = 0
            foreach ($workflow in $Script:Filtered) {
                $done++
                $statusText.Text = "Loading runs $done / $($Script:Filtered.Count)..."
                $runs = Get-LiveRuns -Workflow $workflow
                if ($null -eq $runs) { $failedCalls++; continue }
                $workflow.Runs = $runs
                $workflow.RunCount = $runs.Count
                $workflow.FailureCount = @($runs | Where-Object { $_.Status -eq 'Failed' }).Count
                if ($done % 10 -eq 0) {
                    $window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
                }
            }
            if ($failedCalls) { Write-ColorOutput "$failedCalls workflow(s) could not be read (see errors above)" -Type Warning }
            Write-ColorOutput "Run history loaded" -Type Create
            Update-WorkflowsGrid
        } else {
            Update-RunsGrid
        }
        Set-RefreshStamp 'RunsRefreshed'
        $statusText.Text = "Showing $(@($runsGrid.ItemsSource).Count) runs"
    } finally {
        $window.Cursor = $null
    }
}

function Set-AppMode {
    param([ValidateSet('Simulation', 'Live')][string]$NewMode)
    
    $Script:Config.Mode = $NewMode
    $indicator = $window.FindName('ModeIndicator')
    $warning = $window.FindName('SimulationWarning')
    $opacity = [System.Windows.UIElement]::OpacityProperty
    $indicator.Text = "Mode: $NewMode"
    $indicator.FontWeight = [System.Windows.FontWeights]::Bold
    
    if ($NewMode -eq 'Simulation') {
        $blink = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 0.15, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(700)))
        $blink.AutoReverse = $true
        $blink.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $indicator.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#3A3A5A')
        $indicator.BeginAnimation($opacity, $blink)
        $warning.BeginAnimation($opacity, $blink)
        $warning.Visibility = 'Visible'
    } else {
        # Stop the pulsing and show a steady, distinct Live indicator
        $indicator.BeginAnimation($opacity, $null)
        $warning.BeginAnimation($opacity, $null)
        $indicator.Opacity = 1.0
        $indicator.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($ColorPalette.CreateText)
        $warning.Visibility = 'Collapsed'
    }
    
    $Script:SuppressModeEvents = $true
    $window.FindName('ModeSimulation').IsChecked = ($NewMode -eq 'Simulation')
    $window.FindName('ModeLive').IsChecked = ($NewMode -eq 'Live')
    $Script:SuppressModeEvents = $false
    
    $Script:Data = @()
    $Script:Filtered = @()
    $window.FindName('WorkflowsRefreshed').Text = 'Last refreshed: never'
    $window.FindName('RunsRefreshed').Text = 'Last refreshed: never'
    Update-RunsScope
    
    if ($NewMode -eq 'Simulation') {
        $sample = @([PSCustomObject]@{ Label = 'All Environments'; DisplayName = 'All Environments'; Name = ''; IsDefault = $false }) +
            @('Production', 'Development', 'Testing', 'Staging' | ForEach-Object { [PSCustomObject]@{ Label = $_; DisplayName = $_; Name = $_; IsDefault = $false } })
        Set-EnvironmentList -List $sample
        Set-LoadStatus -Kind Env -State OK -Message 'sample environments (Simulation mode)'
        Invoke-WorkflowsRefresh
    } else {
        $window.Cursor = [System.Windows.Input.Cursors]::Wait
        Set-LoadStatus -Kind Env -State Pending -Message 'loading...'
        Set-LoadStatus -Kind Owner -State Pending -Message 'waiting for Environments'
        try {
            Write-ColorOutput "Connecting to Power Automate and listing environments..." -Type Create
            $envs = Get-LiveEnvironments
        } finally {
            $window.Cursor = $null
        }
        Set-EnvironmentList -List $envs
        Update-OwnerFilter
        Update-WorkflowsGrid
        if ($Script:EnvList.Count -gt 0) {
            Write-ColorOutput "Found $($Script:EnvList.Count) environment(s)" -Type Create
            Invoke-WorkflowsRefresh
        } else {
            $statusText.Text = "Live mode: no environments loaded - see console"
            Set-LoadStatus -Kind Owner -State Error -Message 'NOT loaded - Environments must load first (see the Environments line above)'
        }
    }
}

# Event Handlers
$filterEnvSearch.Add_TextChanged({ Update-EnvironmentCombo })
$window.FindName('ApplyFiltersBtn').Add_Click({
    Update-WorkflowsGrid
    $statusText.Text = "Filtered to $($Script:Filtered.Count) workflows"
})
$window.FindName('RefreshWorkflowsBtn').Add_Click({
    if ($Script:Config.Mode -eq 'Live') {
        # In Live mode a refresh may also be the first chance to list environments
        if ($Script:EnvList.Count -eq 0) {
            Set-LoadStatus -Kind Env -State Pending -Message 'loading...'
            Set-EnvironmentList -List (Get-LiveEnvironments)
        }
    }
    Invoke-WorkflowsRefresh
})
$window.FindName('RefreshRunsBtn').Add_Click({ Invoke-RunsRefresh })
$window.FindName('ModeSimulation').Add_Checked({ if (-not $Script:SuppressModeEvents -and $Script:Config.Mode -ne 'Simulation') { Set-AppMode 'Simulation' } })
$window.FindName('ModeLive').Add_Checked({ if (-not $Script:SuppressModeEvents -and $Script:Config.Mode -ne 'Live') { Set-AppMode 'Live' } })
$filterEnv.Add_SelectionChanged({
    # Remember the chosen environment (ignore the transient null while the list is rebuilt)
    if ($Script:Config.Mode -eq 'Live' -and $filterEnv.SelectedItem -and $filterEnv.SelectedItem.Name -and $filterEnv.SelectedItem.Name -ne $Script:Settings.EnvironmentName) {
        $Script:Settings.EnvironmentName = $filterEnv.SelectedItem.Name
        Save-InspectorSettings -Settings $Script:Settings
    }
})

# Export button
$exportBtn = $window.FindName('ExportBtn')
if ($exportBtn) {
    $exportBtn.Add_Click({
        $statusText = $window.FindName('StatusText')
        $statusText.Text = "Export feature coming soon..."
        [System.Windows.MessageBox]::Show("Export functionality will be implemented in the next update", "Export", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    })
}

# Verbose mode (Settings tab)
$verboseBox = $window.FindName('VerboseMode')
$verboseBox.IsChecked = $Script:Settings.Verbose
function Update-VerboseState {
    Set-PowerShellVerbose
    $window.FindName('VerboseState').Text = if (Test-VerboseMode) {
        'ON: $VerbosePreference = Continue; Live cmdlets run with -Verbose; errors show full detail in the console.'
    } else { 'OFF: short error messages only.' }
}
Update-VerboseState
$verboseBox.Add_Click({
    $Script:Settings.Verbose = [bool]$verboseBox.IsChecked
    Save-InspectorSettings -Settings $Script:Settings
    Update-VerboseState
    Write-ColorOutput "PowerShell Verbose mode $(if ($Script:Settings.Verbose) { 'ON' } else { 'OFF' })" -Type Info
    Write-Verbose "Verbose output is active (this line only appears when Verbose mode is ON)"
})

#region Sign-in (Settings tab)

$signInState = $window.FindName('SignInState')
$signInEndpoint = $window.FindName('SignInEndpoint')
$signInTenant = $window.FindName('SignInTenant')
$signInEndpoint.Text = [string]$Script:Settings.Endpoint
$signInTenant.Text = [string]$Script:Settings.TenantId

function Update-SignInState {
    $signInState.Text = Get-PaSessionSummary
    $signInState.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(if (Test-PaSignedIn) { '#1E7A34' } else { '#B3261E' }))
}
function Save-SignInOptions {
    $Script:Settings.Endpoint = $signInEndpoint.Text.Trim()
    $Script:Settings.TenantId = $signInTenant.Text.Trim()
    Save-InspectorSettings -Settings $Script:Settings
}
Update-SignInState

$window.FindName('SignInBtn').Add_Click({
    Save-SignInOptions
    $window.FindName('ConsoleToggleBtn').IsChecked = $true
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        if (-not (Test-RequiredModules)) {
            $statusText.Text = 'Sign-in needs the PowerApps modules - see console'
        } else {
            $ok = Connect-PaSession -Force
            $statusText.Text = if ($ok) { 'Signed in' } else { "Sign-in failed: $Script:LastLiveError" }
        }
    } finally {
        $window.Cursor = $null
        Update-SignInState
    }
})
$window.FindName('SignOutBtn').Add_Click({
    try {
        if (Get-Command Remove-PowerAppsAccount -ErrorAction SilentlyContinue) { Remove-PowerAppsAccount -ErrorAction Stop }
        $global:currentSession = $null
        Write-ColorOutput 'Signed out of Power Platform' -Type Info
    } catch {
        Write-ErrorDetail -Context 'Sign-out failed' -ErrorRecord $_
    }
    Update-SignInState
})
$signInEndpoint.Add_LostFocus({ Save-SignInOptions })
$signInTenant.Add_LostFocus({ Save-SignInOptions })

#endregion

#region Code Review tab

$Script:ReviewModulePath = Join-Path (Split-Path -Parent $Script:Config.ScriptPath) 'Modules\WorkflowReview\WorkflowReview.psm1'
$Script:SamplesDir = Join-Path (Split-Path -Parent $Script:Config.ScriptPath) 'WorkflowSamples'
$Script:LastReview = $null
$Script:LastReviewFlow = $null
$crSource = $window.FindName('CRSource')
$crTitle = $window.FindName('CRTitle')
$crBadges = $window.FindName('CRBadges')
$crTree = $window.FindName('CRTree')
$crFindings = $window.FindName('CodeReviewList')

function Initialize-ReviewModule {
    if (Get-Command Invoke-WorkflowReview -ErrorAction SilentlyContinue) { return $true }
    try {
        Import-Module $Script:ReviewModulePath -Force -Global -ErrorAction Stop
        return $true
    } catch {
        Write-ErrorDetail -Context "Cannot load review module $Script:ReviewModulePath" -ErrorRecord $_
        return $false
    }
}

function Update-ReviewSourceList {
    $items = @()
    if (Test-Path $Script:SamplesDir) {
        $items = @(Get-ChildItem -Path $Script:SamplesDir -Include *.json, *.zip -Recurse -File | Sort-Object Name | ForEach-Object {
            [PSCustomObject]@{ Label = $_.Name; Path = $_.FullName }
        })
    }
    $crSource.ItemsSource = $items
    if ($items.Count -gt 0 -and -not $crSource.SelectedItem) { $crSource.SelectedIndex = 0 }
    $statusText.Text = "$($items.Count) sample flow file(s) in WorkflowSamples"
}

function New-ReviewBadge {
    param([string]$Text, [string]$Tip, [string]$Level = 'info')
    $colors = @{ ok = '#DFF5E1'; warn = '#FFF0CC'; bad = '#FDE0E0'; info = '#E8F0FF' }
    $border = New-Object System.Windows.Controls.Border
    $border.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($colors[$Level])
    $border.BorderBrush = [System.Windows.Media.Brushes]::Gray
    $border.BorderThickness = 1
    $border.CornerRadius = 4
    $border.Padding = '6,2,6,2'
    $border.Margin = '0,0,6,4'
    $border.ToolTip = $Tip
    $border.Child = [System.Windows.Controls.TextBlock]@{ Text = $Text; FontSize = 12 }
    $border
}

function Find-ReviewTreeItem {
    param($Items, [string]$Tag)
    foreach ($i in $Items) {
        if ($i.Tag -eq $Tag) { return $i }
        $hit = Find-ReviewTreeItem $i.Items $Tag
        if ($hit) { return $hit }
    }
    $null
}

function Show-WorkflowReview {
    param($Workflow)
    $review = $Workflow | Invoke-WorkflowReview
    $Script:LastReview = $review
    $sm = $review.Summary
    $crTitle.Text = "$($review.Name) - overall risk: $($sm.Overall)"
    $crTitle.ToolTip = "Source: $($review.Source)"
    
    $crBadges.Children.Clear()
    $par = $sm.WorstCaseParallel
    $parLevel = 'ok'
    if ("$par" -match '^\d+$') { if ([int]$par -ge 100) { $parLevel = 'bad' } elseif ([int]$par -ge 50) { $parLevel = 'warn' } } else { $parLevel = 'warn' }
    $reLevel = if ("$($sm.ReEntrantRuns)" -eq '1') { 'ok' } else { 'warn' }
    $waitLevel = if ($sm.WaitSeconds -ge 30 * 86400) { 'bad' } elseif ($sm.WaitSeconds -ge 86400) { 'warn' } else { 'ok' }
    $badges = @(
        @("Trigger: $($sm.Trigger)", 'How the flow starts', 'info'),
        @("Re-entrant runs: $($sm.ReEntrantRuns)", 'Maximum overlapping runs allowed by the trigger concurrency setting (Unlimited = not capped)', $reLevel),
        @("Worst-case parallel: $par", 'Overlapping runs x the largest nested Apply to each parallelism', $parLevel),
        @("Actions: $($sm.Actions)", 'Total actions including nested ones', 'info'),
        @("Loops: $($sm.Loops)", 'Apply to each + Do until actions', $(if ($sm.Loops -gt 1) { 'warn' } else { 'info' })),
        @("Waits: $($sm.Waits) ($($sm.WaitExposure))", 'Delay / Delay until actions and worst-case accumulated waiting (run limit is 30 days)', $waitLevel),
        @("Connector calls: $($sm.ConnectorCalls)", 'Actions that call a connector (each counts toward connector throttling)', 'info'),
        @("HTTP calls: $($sm.HttpCalls)", 'Direct HTTP / webhook actions', 'info'),
        @("Findings: $($sm.High) high / $($sm.Medium) med / $($sm.Low) low", 'Number of review findings by severity', $(if ($sm.High) { 'bad' } elseif ($sm.Medium) { 'warn' } else { 'ok' }))
    )
    foreach ($b in $badges) { [void]$crBadges.Children.Add((New-ReviewBadge -Text $b[0] -Tip $b[1] -Level $b[2])) }
    
    $rank = @{ High = 3; Medium = 2; Low = 1 }
    $worst = @{}; $tips = @{}
    foreach ($f in $review.Findings) {
        if (-not $f.Action) { continue }
        if (-not $worst.ContainsKey($f.Action) -or $rank[$f.Severity] -gt $rank[$worst[$f.Action]]) { $worst[$f.Action] = $f.Severity }
        $tips[$f.Action] = (@($tips[$f.Action]) + "[$($f.Severity)] $($f.Message)") | Where-Object { $_ }
    }
    $brush = New-Object System.Windows.Media.BrushConverter
    $colorFor = @{ High = '#C00000'; Medium = '#C86400'; Low = '#1F5FBF' }
    $struct = $review.Workflow.Structure
    
    $crTree.Items.Clear()
    $add = $null
    $add = {
        param($items, [string]$parentName)
        foreach ($n in ($struct.Nodes | Where-Object { $_.Parent -eq $parentName } | Sort-Object Index)) {
            $extra = switch ($n.Type) {
                'Foreach' { if ($n.Sequential) { ' sequential' } elseif ($null -ne $n.Repetitions) { " x$($n.Repetitions)" } else { ' x20 (default)' } }
                'Wait'    { ' wait' }
                default   { '' }
            }
            $item = New-Object System.Windows.Controls.TreeViewItem
            $item.Header = "$($n.Name)  [$($n.Type)$extra]"
            $item.Tag = $n.Name
            $item.IsExpanded = $true
            if ($worst.ContainsKey($n.Name)) {
                $item.Foreground = $brush.ConvertFromString($colorFor[$worst[$n.Name]])
                $item.FontWeight = 'Bold'
                $item.ToolTip = ($tips[$n.Name] -join "`n")
            } else { $item.ToolTip = "$($n.Type): no findings" }
            [void]$items.Add($item)
            & $add $item.Items $n.Name
        }
    }
    $t = $struct.Trigger
    if ($t) {
        $root = New-Object System.Windows.Controls.TreeViewItem
        $root.Header = "TRIGGER $($t.Name)  [$($t.Type)$(if ($t.Kind) { '/' + $t.Kind })]  runs=$(if ($null -eq $t.Runs) { 'unlimited' } else { $t.Runs })"
        $root.Tag = $t.Name; $root.IsExpanded = $true
        if ($worst.ContainsKey($t.Name)) { $root.Foreground = $brush.ConvertFromString($colorFor[$worst[$t.Name]]); $root.FontWeight = 'Bold'; $root.ToolTip = ($tips[$t.Name] -join "`n") }
        [void]$crTree.Items.Add($root)
        & $add $root.Items ''
    } else { & $add $crTree.Items '' }
    
    $crFindings.ItemsSource = @($review.Findings)
    Write-ColorOutput "Code review '$($review.Name)': $($sm.Overall) - $($sm.High) high, $($sm.Medium) medium, $($sm.Low) low; trigger $($sm.Trigger), re-entrant $($sm.ReEntrantRuns), worst-case parallel $par, loops $($sm.Loops), waits $($sm.Waits) ($($sm.WaitExposure))" -Type $(if ($sm.High) { 'Delete' } elseif ($sm.Medium) { 'Warning' } else { 'Create' })
    $statusText.Text = "Reviewed '$($review.Name)': $($sm.Overall)"
}

function Select-CodeReviewTab {
    $tc = $window.FindName('MainTabs')
    foreach ($tab in $tc.Items) { if ([string]$tab.Header -eq 'Code Review') { $tc.SelectedItem = $tab; break } }
}

function Get-FlowForReview {
    $wf = $workflowsGrid.SelectedItem
    if (-not $wf -and $runsGrid.SelectedItem) {
        $id = $runsGrid.SelectedItem.WorkflowId
        $wf = $Script:Data | Where-Object { $_.WorkflowId -eq $id } | Select-Object -First 1
    }
    $wf
}

function Import-FlowForReview {
    param($Flow)
    if ($Script:Config.Mode -eq 'Simulation') {
        $files = @(Get-ChildItem -Path $Script:SamplesDir -Filter *.json -File -ErrorAction SilentlyContinue | Sort-Object Name)
        if ($files.Count -eq 0) { throw "No sample files in $Script:SamplesDir" }
        $sum = 0; foreach ($ch in ([string]$Flow.DisplayName).ToCharArray()) { $sum += [int]$ch }
        $file = $files[$sum % $files.Count]
        Write-ColorOutput "# Simulation mode has no real definitions - '$($Flow.DisplayName)' is mapped to sample $($file.Name)" -Type Comment
        return Import-WorkflowDefinition -Path $file.FullName
    }
    if (-not (Test-RequiredModules)) { throw 'required PowerShell modules are missing (Settings > Validate Modules Now)' }
    if (-not (Connect-PaSession)) { throw "not signed in: $Script:LastLiveError" }
    $envName = $Flow.EnvironmentName; $flowName = $Flow.WorkflowId
    Write-ColorOutput "Downloading definition of '$($Flow.DisplayName)'..." -Type Info
    $full = Invoke-PaCall -Name "Get-AdminFlow -EnvironmentName $envName -FlowName $flowName" -Action { Get-AdminFlow -EnvironmentName $envName -FlowName $flowName -ErrorAction Stop -Verbose:(Test-VerboseMode) }
    $full = @($full)[0]
    if (-not $full) { throw 'Get-AdminFlow returned nothing' }
    Import-WorkflowDefinition -InputObject $full
}

function Invoke-ReviewSelectedFlow {
    $flow = Get-FlowForReview
    Select-CodeReviewTab
    if (-not $flow) {
        $statusText.Text = 'Select a workflow on the Workflows tab (or a run on Run History) first'
        Write-ColorOutput "# Code Review: select a workflow on the Workflows tab (or a run on Run History) first." -Type Warning
        return
    }
    if (-not (Initialize-ReviewModule)) { return }
    try {
        $Script:LastReviewFlow = $flow
        Show-WorkflowReview (Import-FlowForReview -Flow $flow)
    } catch {
        $Script:LastLiveError = $_.Exception.Message
        Write-ErrorDetail -Context "Code review of '$($flow.DisplayName)' failed" -ErrorRecord $_
        $statusText.Text = "Code review failed: $($_.Exception.Message)"
    }
}

function Invoke-ReviewSourceFile {
    param([string]$Path)
    if (-not $Path) { $statusText.Text = 'Pick a source file first'; return }
    if (-not (Initialize-ReviewModule)) { return }
    try {
        Show-WorkflowReview (Import-WorkflowDefinition -Path $Path)
    } catch {
        Write-ErrorDetail -Context "Code review of '$Path' failed" -ErrorRecord $_
        $statusText.Text = "Code review failed: $($_.Exception.Message)"
    }
}

function Invoke-FlowCheckerProbe {
    # Experimental: the cloud Flow Checker has no documented API. Probe candidate endpoints with the session token and report honestly.
    $flow = Get-FlowForReview
    if (-not $flow) { Write-ColorOutput "# Flow Checker: select a live workflow on the Workflows tab first." -Type Warning; return }
    if ($Script:Config.Mode -ne 'Live') { Write-ColorOutput "# Flow Checker needs Live mode (a real flow in a real environment)." -Type Warning; return }
    if (-not (Connect-PaSession)) { return }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy(); $proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $base = "https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/environments/$($flow.EnvironmentName)/flows/$($flow.WorkflowId)"
    $ok = $false
    foreach ($path in 'checkFlow', 'validate') {
        $uri = "$base/${path}?api-version=2016-11-01"
        foreach ($c in @(Get-SessionTokens | Select-Object -First 3)) {
            $req = [System.Net.HttpWebRequest]::Create($uri)
            $req.Method = 'POST'; $req.ContentType = 'application/json'; $req.Accept = 'application/json'; $req.Timeout = 20000; $req.Proxy = $proxy
            $req.Headers.Add('Authorization', "Bearer $($c.Token)")
            $bytes = [Text.Encoding]::UTF8.GetBytes('{}'); $req.ContentLength = $bytes.Length
            $status = ''; $type = ''; $text = ''; $resp = $null
            try { $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close(); $resp = $req.GetResponse() }
            catch [System.Net.WebException] { $resp = $_.Exception.Response; if (-not $resp) { $status = "no response: $($_.Exception.Status)" } }
            if ($resp) {
                $status = "$([int]$resp.StatusCode) $($resp.StatusDescription)"; $type = $resp.ContentType
                $r = New-Object System.IO.StreamReader($resp.GetResponseStream()); $text = $r.ReadToEnd(); $r.Close(); $resp.Close()
            }
            $short = ($text -replace '\s+', ' '); if ($short.Length -gt 250) { $short = $short.Substring(0, 250) + '...' }
            Write-ColorOutput "  [$path via $($c.Source)] HTTP $status | $type" -Type $(if ($status -like '2*') { 'Create' } else { 'Warning' })
            if ($short) { Write-ColorOutput "    body: $short" -Type Neutral }
            if ($status -like '2*' -and $type -match 'json') {
                $json = $text | ConvertFrom-Json
                $items = @(); foreach ($k in 'errors', 'warnings', 'issues', 'value') { if ($json.PSObject.Properties[$k]) { $items += @($json.$k) } }
                $found = @($items | ForEach-Object { New-ReviewFinding -Severity $(if ($_.severity) { [string]$_.severity } else { 'Medium' }) -Rule 'FlowChecker' -Action ([string]$_.operationName) -Message ([string]($(if ($_.message) { $_.message } else { $_ | ConvertTo-Json -Compress }))) -Recommendation ([string]$_.recommendation) -Source 'FlowChecker' })
                if ($Script:LastReview) { $crFindings.ItemsSource = @($Script:LastReview.Findings) + $found }
                Write-ColorOutput "Flow Checker returned $($found.Count) item(s)." -Type Create
                $ok = $true; break
            }
        }
        if ($ok) { break }
    }
    if (-not $ok) {
        Write-ColorOutput "# Flow Checker is not available through a public API (the cloud designer calls an internal endpoint). The local review rules are the dependable offline equivalent." -Type Comment
        $statusText.Text = 'Flow Checker endpoint not reachable - see console'
    }
}

$window.FindName('CRRescan').Add_Click({ Update-ReviewSourceList })
$window.FindName('CRBrowse').Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Flow definition (*.json;*.zip)|*.json;*.zip|All files (*.*)|*.*'
    $dlg.InitialDirectory = $Script:SamplesDir
    if ($dlg.ShowDialog()) { Invoke-ReviewSourceFile -Path $dlg.FileName }
})
$window.FindName('CRReviewSource').Add_Click({ if ($crSource.SelectedItem) { Invoke-ReviewSourceFile -Path $crSource.SelectedItem.Path } else { $statusText.Text = 'Pick a source file first' } })
$window.FindName('CRReviewSelected').Add_Click({ Invoke-ReviewSelectedFlow })
$window.FindName('CRChecker').Add_Click({ Invoke-FlowCheckerProbe })
$window.FindName('CodeReviewBtn').Add_Click({ Invoke-ReviewSelectedFlow })
$window.FindName('CodeReviewRunsBtn').Add_Click({ Invoke-ReviewSelectedFlow })
$crSource.Add_SelectionChanged({ if ($crSource.SelectedItem) { $crSource.ToolTip = $crSource.SelectedItem.Path } })
$window.FindName('CRExport').Add_Click({
    if (-not $Script:LastReview) { $statusText.Text = 'Nothing to export - run a review first'; return }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = 'Markdown (*.md)|*.md|CSV (*.csv)|*.csv|HTML (*.html)|*.html'
    $dlg.FileName = ('review-' + ($Script:LastReview.Name -replace '[^\w\-]+', '_'))
    if ($dlg.ShowDialog()) {
        $fmt = @('Markdown', 'Csv', 'Html')[$dlg.FilterIndex - 1]
        $file = Export-WorkflowReviewReport -Review $Script:LastReview -Path $dlg.FileName -Format $fmt
        Write-ColorOutput "Review report saved: $($file.FullName)" -Type Create
        $statusText.Text = "Review report saved: $($file.Name)"
    }
})
$crFindings.Add_SelectionChanged({
    $sel = $crFindings.SelectedItem
    if ($sel -and $sel.Action) {
        $hit = Find-ReviewTreeItem $crTree.Items $sel.Action
        if ($hit) { $hit.IsSelected = $true; $hit.BringIntoView() }
    }
})

if (Initialize-ReviewModule) { Update-ReviewSourceList }

#endregion

#region Help tab

$Script:HelpPath = Join-Path (Split-Path -Parent $Script:Config.ScriptPath) 'WpfPowerAutomateFailedRuns.Help.md'

function Add-HelpInlines {
    # Renders **bold** and `code` spans of one markdown line into a paragraph
    param($Paragraph, [string]$Text)
    foreach ($part in [regex]::Split($Text, '(\*\*[^*]+\*\*|`[^`]+`)')) {
        if ($part -eq '') { continue }
        if ($part -match '^\*\*(.+)\*\*$') {
            $run = New-Object System.Windows.Documents.Run($Matches[1]); $run.FontWeight = [System.Windows.FontWeights]::Bold
        } elseif ($part -match '^`(.+)`$') {
            $run = New-Object System.Windows.Documents.Run($Matches[1]); $run.FontFamily = 'Consolas'
            $run.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#ECEAE2')
        } else {
            $run = New-Object System.Windows.Documents.Run($part)
        }
        $Paragraph.Inlines.Add($run)
    }
}

function Show-HelpFile {
    $viewer = $window.FindName('HelpViewer')
    $window.FindName('HelpPathText').Text = $Script:HelpPath
    $doc = New-Object System.Windows.Documents.FlowDocument
    $doc.PagePadding = New-Object System.Windows.Thickness(8)
    
    if (-not (Test-Path $Script:HelpPath)) {
        $p = New-Object System.Windows.Documents.Paragraph(New-Object System.Windows.Documents.Run("Help file not found: $Script:HelpPath"))
        $doc.Blocks.Add($p)
        $viewer.Document = $doc
        return
    }
    
    $inCode = $false
    foreach ($line in (Get-Content -Path $Script:HelpPath -Encoding UTF8)) {
        $p = New-Object System.Windows.Documents.Paragraph
        $p.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)
        if ($line -match '^```') { $inCode = -not $inCode; continue }
        if ($inCode) {
            $p.Inlines.Add((New-Object System.Windows.Documents.Run($line)))
            $p.FontFamily = 'Consolas'; $p.Margin = New-Object System.Windows.Thickness(16, 0, 0, 0)
            $p.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#ECEAE2')
        } elseif ($line -match '^(#{1,3})\s+(.*)$') {
            $size = @{ 1 = 24; 2 = 18; 3 = 15 }[$Matches[1].Length]
            Add-HelpInlines -Paragraph $p -Text $Matches[2]
            $p.FontSize = $size; $p.FontWeight = [System.Windows.FontWeights]::Bold
            $p.Margin = New-Object System.Windows.Thickness(0, 10, 0, 4)
        } elseif ($line -match '^\s*[-*]\s+(.*)$') {
            Add-HelpInlines -Paragraph $p -Text ([string][char]0x2022 + ' ' + $Matches[1])
            $p.Margin = New-Object System.Windows.Thickness(16, 0, 0, 2)
        } elseif ($line -match '^\s*(\d+\.)\s+(.*)$') {
            Add-HelpInlines -Paragraph $p -Text "$($Matches[1]) $($Matches[2])"
            $p.Margin = New-Object System.Windows.Thickness(16, 0, 0, 2)
        } elseif ($line.Trim() -eq '') {
            continue
        } else {
            Add-HelpInlines -Paragraph $p -Text $line
        }
        $doc.Blocks.Add($p)
    }
    $viewer.Document = $doc
}

Show-HelpFile
$window.FindName('HelpReloadBtn').Add_Click({ Show-HelpFile; $statusText.Text = 'Help reloaded' })
$window.FindName('HelpOpenBtn').Add_Click({
    if (Test-Path $Script:HelpPath) { Start-Process $Script:HelpPath } else { $statusText.Text = "Help file not found: $Script:HelpPath" }
})

#endregion

#region Test tab

$testResultsGrid = $window.FindName('TestResultsGrid')
$testSampleGrid = $window.FindName('TestSampleGrid')
$Script:TestResults = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$testResultsGrid.ItemsSource = $Script:TestResults
$Script:TestFlows = @()
$sizeBox = $window.FindName('TestSampleSize')
$sizeBox.SelectedIndex = $Script:Settings.TestSampleSize - 1
$sizeBox.Add_SelectionChanged({
    if ($sizeBox.SelectedItem) {
        $Script:Settings.TestSampleSize = [int]$sizeBox.SelectedItem.Content
        Save-InspectorSettings -Settings $Script:Settings
    }
})

function Get-TestSampleSize { return [int]$sizeBox.SelectedItem.Content }

function Get-SessionTokens {
    # The PowerApps auth module keeps its tokens inside $global:currentSession; the layout varies by version, so look for JWTs
    $found = @()
    $session = $global:currentSession
    if (-not $session) { return $found }
    $jwt = '^eyJ[\w-]+\.[\w-]+\.[\w-]+$'
    foreach ($p in $session.PSObject.Properties) {
        $v = $p.Value
        if ($v -is [string] -and $v -match $jwt) { $found += [PSCustomObject]@{ Source = $p.Name; Token = $v } }
        elseif ($null -ne $v -and $v -isnot [string] -and $v -isnot [ValueType]) {
            foreach ($q in $v.PSObject.Properties) {
                if ($q.Value -is [string] -and $q.Value -match $jwt -and $q.Name -match 'access') {
                    $found += [PSCustomObject]@{ Source = "$($p.Name).$($q.Name)"; Token = $q.Value }
                }
            }
        }
    }
    return $found
}

function Invoke-RawProbe {
    <#
    .SYNOPSIS
        Call the environments REST endpoint directly (system proxy) and report status, content type and start of the body
    #>
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $uri = [Uri]'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2016-11-01&$top=1'
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    
    $candidates = @([PSCustomObject]@{ Source = '(no token)'; Token = $null }) + @(Get-SessionTokens | Select-Object -First 4)
    $lastGood = $false
    foreach ($c in $candidates) {
        $request = [System.Net.HttpWebRequest]::Create($uri)
        $request.Method = 'GET'
        $request.Accept = 'application/json'
        $request.Timeout = 15000
        $request.Proxy = $proxy
        $request.AllowAutoRedirect = $false
        if ($c.Token) { $request.Headers.Add('Authorization', "Bearer $($c.Token)") }
        
        $status = ''; $type = ''; $body = ''; $response = $null
        try {
            $response = $request.GetResponse()
        } catch [System.Net.WebException] {
            $response = $_.Exception.Response
            if (-not $response) { $status = "no response: $($_.Exception.Status) $($_.Exception.Message)" }
        }
        if ($response) {
            $status = "$([int]$response.StatusCode) $($response.StatusDescription)"
            $type = $response.ContentType
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            $text = $reader.ReadToEnd(); $reader.Close(); $response.Close()
            $body = ($text -replace '\s+', ' ')
            if ($body.Length -gt 300) { $body = $body.Substring(0, 300) + '...' }
        }
        $isJson = $type -match 'json'
        Write-ColorOutput "  [$($c.Source)] HTTP $status | Content-Type: $type" -Type $(if ($isJson) { 'Create' } else { 'Warning' })
        if ($body) { Write-ColorOutput "    body: $body" -Type Neutral }
        if ($status -like '200*' -and $isJson) { $lastGood = $true; break }
    }
    if (-not $lastGood) {
        Write-ColorOutput "# No JSON 200 reply. A non-JSON body (HTML, plain text such as 'IRS.') means a proxy / firewall / sign-in page answered instead of the API." -Type Comment
        Write-ColorOutput "# 401 with JSON means the endpoint is reachable but that token was not accepted (re-run Add-PowerAppsAccount)." -Type Comment
    }
    return $lastGood
}

$Script:TestButtons = @{
    'Prerequisites' = 'TestPrereqBtn'; 'Sample Environments' = 'TestEnvsBtn'; 'Sample Flows' = 'TestFlowsBtn'
    'Sample Owners' = 'TestOwnersBtn'; 'Sample Runs' = 'TestRunsBtn'; 'Raw HTTP probe' = 'TestProbeBtn'; 'Run all' = 'TestAllBtn'
}
$Script:TestTips = @{}
foreach ($stepKey in $Script:TestButtons.Keys) {
    $button = $window.FindName($Script:TestButtons[$stepKey])
    $Script:TestTips[$stepKey] = [string]$button.ToolTip
    [System.Windows.Controls.ToolTipService]::SetShowDuration($button, 60000)
}

function Set-TestStatus {
    <#
    .SYNOPSIS
        Show a step's status on its button screen tip and the status line, and echo it to the console
    #>
    param(
        [string]$Step,
        [ValidateSet('Running', 'OK', 'FAIL', 'Info')][string]$State,
        [string]$Message
    )
    
    $line = "$Step - $State$(if ($Message) { ': ' + $Message })  ($(Get-Date -Format 'HH:mm:ss'))"
    $button = $window.FindName($Script:TestButtons[$Step])
    if ($button) {
        $button.ToolTip = "$($Script:TestTips[$Step])`nStatus: $line"
    }
    $box = $window.FindName('TestStatusText')
    $box.Text = "Status: $line"
    $box.ToolTip = $line
    $box.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(
        switch ($State) { 'OK' { '#1E7A34' } 'FAIL' { '#B3261E' } default { '#5A5A5A' } }))
    Write-ColorOutput "  [status] $line" -Type Comment
}

function Invoke-TestStep {
    param(
        [string]$Step,
        [scriptblock]$Action
    )
    
    $window.FindName('ConsoleToggleBtn').IsChecked = $true
    Write-ColorOutput "==== Test: $Step  $(Get-Date -Format 'HH:mm:ss') ====" -Type Info
    Set-TestStatus -Step $Step -State Running
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $ok = $false
    $detail = ''
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        $detail = [string](& $Action)
        $ok = $true
        Write-ColorOutput "[OK] $Step - $detail" -Type Create
    } catch {
        $detail = $_.Exception.Message
        Write-ColorOutput "[X] $Step failed: $detail" -Type Delete
        if (Test-VerboseMode) { Write-ErrorDetail -Context "  $Step detail" -ErrorRecord $_ }
    } finally {
        $window.Cursor = $null
    }
    $Script:TestResults.Insert(0, [PSCustomObject]@{
        Time = Get-Date -Format 'HH:mm:ss'; Step = $Step; Result = $(if ($ok) { 'OK' } else { 'FAIL' }); Ms = $watch.ElapsedMilliseconds; Detail = $detail
    })
    Set-TestStatus -Step $Step -State $(if ($ok) { 'OK' } else { 'FAIL' }) -Message $detail
    $statusText.Text = "Test '$Step': $(if ($ok) { 'OK' } else { 'FAILED - see console' })"
    return $ok
}

function Get-TestEnvironment {
    $sel = $filterEnv.SelectedItem
    if (-not $sel -or -not $sel.Name) { throw "No environment selected - run step 2 (Sample Environments) or load Environments on the Workflows tab first" }
    return $sel
}

$testSteps = [ordered]@{
    'Prerequisites' = {
        $problems = Test-PowerAutomateConnection
        if ($problems -gt 0 -and $Script:Config.Mode -eq 'Live') { throw "$problems problem(s) found - see console for fixes" }
        if ($problems -gt 0) { return "$problems problem(s) (informational in Simulation mode)" }
        return 'All checks passed'
    }
    'Sample Environments' = {
        $n = Get-TestSampleSize
        if ($Script:Config.Mode -eq 'Live') {
            $all = Get-LiveEnvironments
            if ($null -eq $all) { throw "Could not list environments: $Script:LastLiveError" }
            Set-EnvironmentList -List $all
        } else {
            $all = @($Script:EnvList | Where-Object { $_.Name })
        }
        $testSampleGrid.ItemsSource = @($all | Select-Object -First $n | Select-Object DisplayName, Name, IsDefault)
        return "$(@($all).Count) environment(s) visible; showing first $([math]::Min($n, @($all).Count))"
    }
    'Sample Flows' = {
        $n = Get-TestSampleSize
        if ($Script:Config.Mode -eq 'Live') {
            $flows = Get-LiveData -Environment (Get-TestEnvironment)
            if ($null -eq $flows) { throw "Could not retrieve flows: $Script:LastLiveError" }
        } else {
            if ($Script:Data.Count -eq 0) { Invoke-WorkflowsRefresh }
            $flows = @($Script:Data)
        }
        $Script:TestFlows = @($flows)
        if ($Script:Config.Mode -eq 'Live') {
            # Feed the Workflows tab too, so the Owner list and status reflect this step
            $Script:Data = @($flows)
            Update-OwnerFilter
            Update-WorkflowsGrid
            Set-RefreshStamp 'WorkflowsRefreshed'
        }
        $testSampleGrid.ItemsSource = @($flows | Select-Object -First $n | Select-Object DisplayName, Owner, IsPublished, CreatedOn)
        return "$(@($flows).Count) flow(s) in environment; showing first $([math]::Min($n, @($flows).Count))"
    }
    'Sample Owners' = {
        $n = Get-TestSampleSize
        if (@($Script:TestFlows).Count -eq 0) { throw "No flows yet - Environments load first, then Flows, then Owners. Run step 3 (Sample Flows) first." }
        $owners = @($Script:TestFlows | Group-Object -Property Owner | Sort-Object -Property Count -Descending)
        $testSampleGrid.ItemsSource = @($owners | Select-Object -First $n | ForEach-Object { [PSCustomObject]@{ Owner = $(if ($_.Name) { $_.Name } else { '(unknown)' }); Flows = $_.Count } })
        return "$($owners.Count) distinct owner(s); showing top $([math]::Min($n, $owners.Count)) by flow count"
    }
    'Sample Runs' = {
        $n = Get-TestSampleSize
        if (@($Script:TestFlows).Count -eq 0) { throw "No flows yet - run step 3 (Sample Flows) first" }
        $flow = $Script:TestFlows | Select-Object -First 1
        if ($Script:Config.Mode -eq 'Live') {
            if (-not (Connect-PaSession)) { throw "Could not retrieve runs: $Script:LastLiveError" }
            $runs = Get-LiveRuns -Workflow $flow
            if ($null -eq $runs) { throw "Could not retrieve runs for '$($flow.DisplayName)': $Script:LastLiveError" }
        } else {
            $runs = @($flow.Runs)
        }
        $testSampleGrid.ItemsSource = @($runs | Sort-Object StartTime -Descending | Select-Object -First $n | Select-Object StartTime, Status, ErrorCode, ErrorMessage)
        return "$(@($runs).Count) run(s) for '$($flow.DisplayName)'; showing latest $([math]::Min($n, @($runs).Count))"
    }
}

foreach ($pair in @(
    @('TestPrereqBtn', 'Prerequisites'), @('TestEnvsBtn', 'Sample Environments'), @('TestFlowsBtn', 'Sample Flows'),
    @('TestOwnersBtn', 'Sample Owners'), @('TestRunsBtn', 'Sample Runs'))) {
    $stepName = $pair[1]
    $window.FindName($pair[0]).Add_Click({ Invoke-TestStep -Step $stepName -Action $testSteps[$stepName] | Out-Null }.GetNewClosure())
}
$window.FindName('TestProbeBtn').Add_Click({
    Invoke-TestStep -Step 'Raw HTTP probe' -Action {
        if (-not (Invoke-RawProbe)) { throw 'No JSON 200 reply from the environments endpoint - see console' }
        'Endpoint returned JSON'
    } | Out-Null
})
$window.FindName('TestAllBtn').Add_Click({
    foreach ($name in $testSteps.Keys) {
        if (-not (Invoke-TestStep -Step $name -Action $testSteps[$name])) {
            Write-ColorOutput "Run all stopped at step '$name'" -Type Warning
            Set-TestStatus -Step 'Run all' -State FAIL -Message "stopped at step '$name'"
            return
        }
    }
    Write-ColorOutput "Run all: every step passed" -Type Create
    Set-TestStatus -Step 'Run all' -State OK -Message 'every step passed'
})

#endregion

# Test Connection button
$window.FindName('TestConnectionBtn').Add_Click({
    $statusText = $window.FindName('StatusText')
    $statusText.Text = "Testing connection..."
    $window.FindName('ConsoleToggleBtn').IsChecked = $true
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        $problems = Test-PowerAutomateConnection
        $statusText.Text = if ($problems -eq 0) { "Connection test passed" } else { "Connection test: $problems problem(s) - see console for fixes" }
    } finally {
        $window.Cursor = $null
    }
})

# Validate Modules button
$window.FindName('ValidateModulesBtn').Add_Click({
    $statusText = $window.FindName('StatusText')
    $window.FindName('ConsoleToggleBtn').IsChecked = $true
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        Write-ColorOutput "==== Validate Modules  $(Get-Date -Format 'HH:mm:ss') ====" -Type Info
        $ok = Test-RequiredModules
        $statusText.Text = if ($ok) { "All required modules available" } else { "Missing modules - see console for fixes" }
    } finally {
        $window.Cursor = $null
    }
})

# Shared console: Copy / Clear / show-hide
$window.FindName('ConsoleClearBtn').Add_Click({ $Script:ConsoleBox.Document.Blocks.Clear() })
$window.FindName('ConsoleCopyBtn').Add_Click({
    $doc = $Script:ConsoleBox.Document
    $text = (New-Object System.Windows.Documents.TextRange($doc.ContentStart, $doc.ContentEnd)).Text
    if ($text.Trim()) { [System.Windows.Clipboard]::SetText($text) }
    $window.FindName('StatusText').Text = "Console copied to clipboard"
})

$consoleToggle = $window.FindName('ConsoleToggleBtn')
$Script:ConsoleHeight = 170
$setConsoleVisible = {
    param([bool]$Visible)
    $row = $window.FindName('ConsoleRow')
    if ($Visible) {
        $row.Height = New-Object System.Windows.GridLength($Script:ConsoleHeight)
        $window.FindName('ConsolePanel').Visibility = 'Visible'
        $window.FindName('ConsoleSplitter').Visibility = 'Visible'
    } else {
        if ($row.ActualHeight -gt 20) { $Script:ConsoleHeight = $row.ActualHeight }
        $row.Height = New-Object System.Windows.GridLength(0)
        $window.FindName('ConsolePanel').Visibility = 'Collapsed'
        $window.FindName('ConsoleSplitter').Visibility = 'Collapsed'
    }
    $Script:Settings.ConsoleVisible = $Visible
    Save-InspectorSettings -Settings $Script:Settings
}
$consoleToggle.Add_Checked({ & $setConsoleVisible $true })
$consoleToggle.Add_Unchecked({ & $setConsoleVisible $false })
$consoleToggle.IsChecked = $Script:Settings.ConsoleVisible

# Per-tab zoom (persisted by tab header)
$tabControl = $window.FindName('MainTabs')
$zoomResetBtn = $window.FindName('ZoomResetBtn')

$applyTabZoom = {
    param($Tab, [double]$Zoom)
    $Tab.Content.LayoutTransform = New-Object System.Windows.Media.ScaleTransform($Zoom, $Zoom)
}
$updateZoomLabel = {
    $tab = $tabControl.SelectedItem
    $zoom = if ($tab -and $Script:Settings.TabZoom.ContainsKey([string]$tab.Header)) { $Script:Settings.TabZoom[[string]$tab.Header] } else { 1.0 }
    $zoomResetBtn.Content = "$([int][math]::Round($zoom * 100))%"
}
$setCurrentTabZoom = {
    param([double]$Zoom)
    $tab = $tabControl.SelectedItem
    if (-not $tab) { return }
    $Zoom = [math]::Round([math]::Max(0.5, [math]::Min(3.0, $Zoom)), 2)
    & $applyTabZoom $tab $Zoom
    $Script:Settings.TabZoom[[string]$tab.Header] = $Zoom
    Save-InspectorSettings -Settings $Script:Settings
    & $updateZoomLabel
}
$getCurrentTabZoom = {
    $key = [string]$tabControl.SelectedItem.Header
    if ($Script:Settings.TabZoom.ContainsKey($key)) { $Script:Settings.TabZoom[$key] } else { 1.0 }
}

foreach ($tab in $tabControl.Items) {
    $key = [string]$tab.Header
    if ($Script:Settings.TabZoom.ContainsKey($key)) { & $applyTabZoom $tab $Script:Settings.TabZoom[$key] }
}
& $updateZoomLabel

$tabControl.Add_SelectionChanged({
    param($sender, $e)
    # SelectionChanged bubbles up from inner ComboBoxes/DataGrids; only react to tab switches
    if ($e.OriginalSource -eq $tabControl) {
        & $updateZoomLabel
        $Script:Settings.ActiveTab = [string]$tabControl.SelectedItem.Header
        Save-InspectorSettings -Settings $Script:Settings
    }
})
$window.FindName('ZoomInBtn').Add_Click({ & $setCurrentTabZoom ((& $getCurrentTabZoom) + 0.1) })
$window.FindName('ZoomOutBtn').Add_Click({ & $setCurrentTabZoom ((& $getCurrentTabZoom) - 0.1) })
$zoomResetBtn.Add_Click({ & $setCurrentTabZoom 1.0 })

$window.Add_PreviewMouseWheel({
    param($sender, $e)
    if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) {
        $step = if ($e.Delta -gt 0) { 0.1 } else { -0.1 }
        & $setCurrentTabZoom ((& $getCurrentTabZoom) + $step)
        $e.Handled = $true
    }
})
$window.Add_PreviewKeyDown({
    param($sender, $e)
    if (-not ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) { return }
    switch ($e.Key.ToString()) {
        { $_ -in 'OemPlus', 'Add' }       { & $setCurrentTabZoom ((& $getCurrentTabZoom) + 0.1); $e.Handled = $true }
        { $_ -in 'OemMinus', 'Subtract' } { & $setCurrentTabZoom ((& $getCurrentTabZoom) - 0.1); $e.Handled = $true }
        { $_ -in 'D0', 'NumPad0' }        { & $setCurrentTabZoom 1.0; $e.Handled = $true }
    }
})

# Restore the active tab (the zoom label follows the selection)
if ($Script:Settings.ActiveTab) {
    $savedTab = $tabControl.Items | Where-Object { [string]$_.Header -eq $Script:Settings.ActiveTab } | Select-Object -First 1
    if ($savedTab) { $tabControl.SelectedItem = $savedTab; & $updateZoomLabel }
}

# Restore window bounds, only when they still fit on the current screens
$saved = $Script:Settings.Window
if ($saved.Width -and $saved.Height -and [double]$saved.Width -ge 600 -and [double]$saved.Height -ge 400) {
    $window.Width = [double]$saved.Width
    $window.Height = [double]$saved.Height
    if ($null -ne $saved.Left -and $null -ne $saved.Top) {
        $left = [double]$saved.Left
        $top = [double]$saved.Top
        $screenRight = [System.Windows.SystemParameters]::VirtualScreenLeft + [System.Windows.SystemParameters]::VirtualScreenWidth
        $screenBottom = [System.Windows.SystemParameters]::VirtualScreenTop + [System.Windows.SystemParameters]::VirtualScreenHeight
        if ($left -lt $screenRight - 100 -and $left + $window.Width -gt [System.Windows.SystemParameters]::VirtualScreenLeft + 100 -and
            $top -lt $screenBottom - 100 -and $top -ge [System.Windows.SystemParameters]::VirtualScreenTop) {
            $window.WindowStartupLocation = 'Manual'
            $window.Left = $left
            $window.Top = $top
        }
    }
    if ($saved.State -eq 'Maximized') { $window.WindowState = 'Maximized' }
}

$window.Add_Closing({
    $w = $Script:Window
    $bounds = if ($w.WindowState -eq 'Normal') {
        New-Object System.Windows.Rect($w.Left, $w.Top, $w.ActualWidth, $w.ActualHeight)
    } else { $w.RestoreBounds }
    $Script:Settings.Window = @{
        Left = [math]::Round($bounds.Left); Top = [math]::Round($bounds.Top)
        Width = [math]::Round($bounds.Width); Height = [math]::Round($bounds.Height)
        State = if ($w.WindowState -eq 'Maximized') { 'Maximized' } else { 'Normal' }
    }
    Save-InspectorSettings -Settings $Script:Settings
})

# Load data after the window is on screen so Live-mode network calls do not delay it
$Script:StartupDone = $false
$window.Add_ContentRendered({
    if ($Script:StartupDone) { return }
    $Script:StartupDone = $true
    Set-AppMode $Script:Config.Mode
})

# Show window
$window.ShowDialog() | Out-Null

Write-ColorOutput "Application closed" -Type Info

#endregion
