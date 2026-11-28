# Test Tab Enhancements - Execution Guide

## Quick Start

### Option 1: Run from Windows PowerShell 5.1 (Recommended)

The PowerApps administrative cmdlets **only work in Windows PowerShell 5.1**, not PowerShell Core (7.x).

#### Steps:

1. **Open Windows PowerShell 5.1** (not PowerShell Core)
   - Press `Win+R`
   - Type: `powershell.exe` (not `pwsh.exe`)
   - Press Enter
   - Should show version 5.1.x

2. **Install PowerApps Module** (if not already installed)
   ```powershell
   Install-Module -Name Microsoft.PowerApps.Administration.PowerShell `
     -AllowClobber -Force -Scope CurrentUser
   ```

3. **Navigate to the test directory**
   ```powershell
   cd C:\Davis\vibe\Power-Automate
   ```

4. **Run the test script**
   ```powershell
   # Run with interactive prompts
   .\TestTabEnhancements.ps1 -RunAllTests
   
   # Or load functions only
   . .\TestTabEnhancements.ps1
   Test-AdminEnvironments
   ```

5. **Sign in when prompted**
   - Window will open for Microsoft 365 login
   - Complete authentication with admin account
   - Return to PowerShell window

---

### Option 2: Integrate into WPF Application

The test functions are designed to integrate into the WPF tab:

```powershell
# In the WPF script (after line 2213)

# Load test functions
. "$PSScriptRoot\TestTabEnhancements.ps1"

# Wire test buttons
$window.FindName('TestEnvsBtn').Add_Click({
    Invoke-TestStep -Step 'Sample Environments' -Action {
        $result = Test-AdminEnvironments
        if ($result.Success) {
            # Update WPF grid with results
            $testSampleGrid.ItemsSource = $result.Environments | Select-Object DisplayName, Name, IsDefault
            return "$($result.Count) environment(s)"
        }
        throw $result.Error
    } | Out-Null
})
```

---

## Detailed Test Execution

### Test 1: Prerequisites

**What it checks**:
- PowerShell 5.1 edition ✓
- Required PowerApps module loaded ✓
- Network connectivity to Power Platform ✓
- Current sign-in status ✓

**Run**:
```powershell
# Automated check (part of -RunAllTests)
# Or manually:
Assert-ModuleLoaded
Test-PowerPlatformSignIn
```

**Expected Output**:
```
[✓] Module Microsoft.PowerApps.Administration.PowerShell already loaded (v2.2.142)
[✓] PowerApps admin API is accessible
```

**If it fails**:
- Module not installed → Run: `Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -AllowClobber -Force`
- Not signed in → Run: `Add-PowerAppsAccount`

---

### Test 2: Sample Environments

**What it does**:
- Lists all Power Platform environments you have access to
- Shows environment name, type, and default indicator
- Prompts for interactive selection

**Run**:
```powershell
Test-AdminEnvironments
# Then select from numbered list
Get-AdminEnvironmentInteractive
```

**Expected Output**:
```
[✓] Retrieved 3 environment(s) in 1234ms
Default environment: Production

Environments:
  • Production (ID: default) (Sandbox) [DEFAULT]
  • Dev (ID: dev-123) (Sandbox)
  • Test (ID: test-456) (Sandbox)

[1] Production (default)
[2] Dev (dev-123)
[3] Test (test-456)

Select environment number (1-3): 1
[✓] Selected: Production
```

**Troubleshooting**:
- No environments found → You may not have Environment Admin role
- Takes >10 seconds → Network latency, try again

---

### Test 3: Sample Flows

**What it does**:
- Lists all Power Automate flows in the selected environment
- Shows enabled/disabled count
- Displays up to 10 sample flows with status

**Run**:
```powershell
$env = Get-AdminEnvironmentInteractive
Test-AdminFlows -Environment $env
```

**Expected Output**:
```
[✓] Retrieved 42 flow(s) in 2156ms
[✓] Enabled: 38, Disabled: 4

Sample flows (first 10):
  • Process Orders (ID: flow-123, Status: Enabled)
  • Generate Reports (ID: flow-456, Status: Enabled)
  • Alert Handler (ID: flow-789, Status: Disabled)
```

**Troubleshooting**:
- No flows → Environment exists but has no flows (normal)
- Error: Access Denied → You need Dataverse access in that environment

---

### Test 4: Sample Owners

**What it does**:
- Lists the users who own flows in the selected environment
- Shows top owners by number of flows owned
- Displays count of distinct owners

**Run**:
```powershell
$env = Get-AdminEnvironmentInteractive
Test-AdminFlows -Environment $env  # Must run first to populate $testFlows
# Then: (Shows owners automatically with Test-AdminFlows)
```

**Expected Output**:
```
16 distinct owner(s); showing top 5 by flow count
  • john.doe@contoso.com - 8 flows
  • jane.smith@contoso.com - 5 flows
  • app-service@contoso.com - 3 flows
  • admin@contoso.com - 2 flows
  • (unknown) - 1 flow
```

**Troubleshooting**:
- Unknown owner → Service principal or deleted user
- No owners → Flows are unowned (should not happen)

---

### Test 5: Sample Runs

**What it does**:
- Lists the recent execution history of a sample flow
- Shows run status, start time, and any error codes
- Displays up to 10 most recent runs

**Run**:
```powershell
$env = Get-AdminEnvironmentInteractive
# First get flows for the environment
$flows = Get-AdminFlow -EnvironmentName $env.EnvironmentName
$flow = $flows | Select-Object -First 1
# Then get runs
$runs = Get-FlowRun -EnvironmentName $env.EnvironmentName -FlowName $flow.Name
```

**Expected Output**:
```
[✓] Retrieved 42 run(s) for 'Process Orders'; showing latest 5
  • 2026-11-24 10:30:15 - Succeeded
  • 2026-11-24 10:15:30 - Succeeded
  • 2026-11-24 10:00:45 - Failed (TimeoutException)
  • 2026-11-23 23:45:12 - Succeeded
  • 2026-11-23 23:30:00 - Succeeded
```

**Troubleshooting**:
- No runs → Flow has never executed
- Runs with errors → Investigate flow logic

---

### Test 6: Raw HTTP Probe

**What it does**:
- Makes a direct HTTP request to the Power Platform REST API
- Useful for diagnosing network or authentication issues
- Shows HTTP status code and response content type

**Run**:
```powershell
Invoke-RawProbe
```

**Expected Output**:
```
[✓] Endpoint returned JSON
  Status: 200
  Content-Type: application/json
  Response: [{"name":"default","displayName":"Production",...
```

**Troubleshooting**:
- 401 Unauthorized → Not signed in, run `Add-PowerAppsAccount`
- 403 Forbidden → Insufficient permissions
- 407 Proxy Required → Network proxy issue (requires network setup)
- Timeout → Network connectivity issue

---

### Test 7: Connections

**What it does**:
- Lists all configured connections in the selected environment
- Shows connection status (Connected, Authenticated, etc.)
- Displays connector type (SharePoint, SQL, Office 365, etc.)

**Run**:
```powershell
$env = Get-AdminEnvironmentInteractive
Test-PowerAppConnections -Environment $env
```

**Expected Output**:
```
[✓] Retrieved 15 connection(s) in 892ms

Sample connections (first 10):
  • My SharePoint (Connector: SharePoint, Status: Connected)
  • Office 365 Users (Connector: Office365Users, Status: Connected)
  • SQL Database (Connector: SQL, Status: Connected)
```

**Troubleshooting**:
- No connections → Environment has no configured connections
- Broken connections → May be expired authentication

---

### Test 8: Connectors

**What it does**:
- Lists all available connectors in your tenant
- Groups by tier (Standard, Premium, Business)
- Shows sample of 15 connectors

**Run**:
```powershell
Test-PowerAppConnectors
```

**Expected Output**:
```
[✓] Retrieved 456 connector(s) in 1234ms

Sample connectors (first 15):
  • Azure Blob Storage [Premium]
  • Azure Service Bus [Premium]
  • Common Data Service [Standard]

Connector summary:
  • Standard: 125 connector(s)
  • Premium: 234 connector(s)
  • Business: 97 connector(s)
```

**Notes**:
- Very large list (200+ connectors typical)
- Same for all environments in your tenant

---

## Automated Test Run (All Tests)

**Run everything in sequence**:
```powershell
.\TestTabEnhancements.ps1 -RunAllTests
```

This will execute in order:
1. ✓ Check prerequisites (module, PowerShell, network, sign-in)
2. ✓ List all environments
3. ✓ Prompt for environment selection
4. ✓ Get flows for selected environment
5. ✓ Show flow owners
6. ✓ List connections
7. ✓ List connectors
8. ✓ Show flow management capabilities

**Typical time**: 2-5 minutes

**Stops at first failure** (critical path dependency):
- If module missing → Cannot continue
- If not signed in → Cannot continue
- If no environments → Cannot continue
- If no flows → Skips owner/run tests

---

## Integrating with WPF Test Tab

The WPF application's Test Tab will use these functions. Here's what happens:

### Test Tab Button Map

| Button | Function | WPF Handler |
|--------|----------|-------------|
| Prerequisites | Check module, auth, network | `Test-PowerAutomateConnection` |
| Sample Environments | List environments | `Test-AdminEnvironments` |
| Sample Flows | Get flows for selected environment | `Test-AdminFlows` |
| Sample Owners | Show top flow owners | Automatic from flows |
| Sample Runs | Get runs of first flow | `Get-LiveRuns` |
| Run All | Execute tests 1-5 in order | Loop through buttons |

### Sample WPF Integration Code

```powershell
# Load test module
. "$PSScriptRoot\TestTabEnhancements.ps1"

# Wire up "Sample Environments" button
$window.FindName('TestEnvsBtn').Add_Click({
    try {
        $result = Test-AdminEnvironments
        if ($result.Success -and $result.Environments) {
            # Update the environment filter dropdown
            $filterEnv.ItemsSource = $result.Environments
            
            # Display in test grid
            $testSampleGrid.ItemsSource = $result.Environments | 
                Select-Object DisplayName, Name, IsDefault
            
            Set-TestStatus -Step 'Sample Environments' -State OK
        }
    } catch {
        Set-TestStatus -Step 'Sample Environments' -State FAIL -Message $_.Exception.Message
    }
} | Out-Null)
```

---

## Troubleshooting Guide

### "Module not found" Error

**Cause**: PowerApps admin module not installed

**Fix**:
```powershell
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell `
  -AllowClobber -Force -Scope CurrentUser
```

Requires internet connection and admin PowerShell.

### "Not signed in" Error

**Cause**: No active Power Platform session

**Fix**:
```powershell
Add-PowerAppsAccount
```

Complete Microsoft login in the browser window that appears.

### "Access Denied" or "Insufficient Permissions"

**Cause**: User account lacks Environment Admin or Power Platform Admin role

**Fix**:
1. Contact your Power Platform admin
2. Request "Environment Admin" role for the target environment
3. Wait 15-30 minutes for role to propagate
4. Run `Add-PowerAppsAccount` again to refresh

### "Timeout" or "Network Error"

**Cause**: Network connectivity or firewall issue

**Check**:
```powershell
# Test basic connectivity
Test-NetConnection -ComputerName graph.microsoft.com -Port 443

# Try again after waiting
.\TestTabEnhancements.ps1 -RunAllTests
```

**Network Config** (may be needed):
- Firewall rules: Allow HTTPS (port 443) to *.microsoft.com
- Proxy: May need to configure for PowerShell

### "Invalid JSON primitive" Error

**Cause**: REST API returned unexpected response

**Diagnostic**:
```powershell
Invoke-RawProbe
```

If that shows an error, the issue is at the REST API level.

---

## Performance Tips

| Issue | Solution |
|-------|----------|
| Tests taking >5 minutes | Check network speed, try again later |
| Memory growing | PowerShell reuses memory, restart to reset |
| Partial results | May be paginating, test smaller samples first |
| Rate limiting (429) | Wait 1-2 minutes, retry |

---

## Next Steps

1. ✓ Run `.\TestTabEnhancements.ps1 -RunAllTests` to validate setup
2. ✓ Review test output and note any issues
3. ✓ Integrate test functions into WPF application
4. ✓ Wire test buttons to test functions
5. ✓ Update WPF UI with live results from test cmdlets
6. ✓ Deploy and test with real environments

---

**For more information**: See `TEST_PLAN.md` for detailed test cases and expected results.
