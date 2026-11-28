# Test Tab Enhancements - Developer Reference Card

## Quick Reference

### Module Functions

```powershell
# Check/load PowerApps module
Assert-ModuleLoaded
# Returns: $true if loaded, $false if error

# Check if signed in
Test-PowerPlatformSignIn
# Returns: $true if authenticated, $false otherwise
```

### Environment Functions

```powershell
# Get all environments
Test-AdminEnvironments
# Returns: @{ Success=$bool; Count=$int; Time=$ms; Environments=$array }

# Pick environment interactively
Get-AdminEnvironmentInteractive
# Returns: $environment object or $null
# Shows numbered menu, prompts for selection
```

### Flow Functions

```powershell
# Get flows for an environment
Test-AdminFlows -Environment $env
# Parameters: $env (from Get-AdminEnvironmentInteractive)
# Returns: @{ Success=$bool; Count=$int; Flows=$array; Time=$ms }

# Get flow owner information
Test-FlowOwnerRoles -Environment $env -Flow $flow
# Parameters: $env, $flow
# Returns: @{ Success=$bool; Count=$int; Roles=$array; Time=$ms }

# Test flow enable/disable (dry-run)
Test-FlowManagement -Environment $env -Flow $flow
# Parameters: $env, $flow
# Returns: @{ Success=$bool; FlowName=$string; CurrentStatus=$string; DryRun=$bool }
```

### Connection Functions

```powershell
# Get connections in environment
Test-PowerAppConnections -Environment $env
# Parameters: $env (optional - omit for all environments)
# Returns: @{ Success=$bool; Count=$int; Connections=$array; Time=$ms }

# Get all available connectors
Test-PowerAppConnectors
# Returns: @{ Success=$bool; Count=$int; Time=$ms }
```

### UI Helper Functions

```powershell
# Write colored status message
Write-TestStatus -Message "text" -Status Pass|Fail|Info|Warning -Target Host|Verbose|Debug
# Examples:
Write-TestStatus "Module loaded" -Status Pass
Write-TestStatus "No environments found" -Status Warning
```

---

## Integration Pattern for WPF

### Load Module
```powershell
# At start of WPF script (after GUI definition, before showing window)
. "$PSScriptRoot\TestTabEnhancements.ps1"
```

### Wire Test Button
```powershell
$button = $window.FindName('TestEnvsBtn')
$button.Add_Click({
    Invoke-TestStep -Step 'Sample Environments' -Action {
        $result = Test-AdminEnvironments
        if ($result.Success) {
            # Update WPF grid
            $testSampleGrid.ItemsSource = $result.Environments | 
                Select-Object DisplayName, Name, IsDefault
            return "$($result.Count) environment(s)"
        }
        throw $result.Error
    } | Out-Null
})
```

### Update Environment Dropdown
```powershell
# After getting environments, populate the Workflows tab dropdown
function Set-EnvironmentList {
    param([object[]]$List)
    $filterEnv = $window.FindName('FilterEnvironment')  # WPF ComboBox
    $filterEnv.ItemsSource = $List
    if ($List.Count -gt 0) {
        $filterEnv.SelectedIndex = 0
    }
}
```

### Display Results in Grid
```powershell
# Generic pattern for displaying results
$testSampleGrid.ItemsSource = $results | 
    Select-Object @(
        @{ Name='Column1'; Expression={ $_.Property1 } }
        @{ Name='Column2'; Expression={ $_.Property2 } }
    )
```

---

## Error Handling

```powershell
# All test functions return structured results
$result = Test-AdminFlows -Environment $env

if ($result.Success) {
    # Use $result.Count, $result.Flows, $result.Time
    Write-Host "Found $($result.Count) flows"
} else {
    # Use $result.Error
    Write-Error $result.Error
}
```

### Common Error Patterns

```powershell
# Module error
catch { if ($_.Exception.Message -match 'module.*not found') { ... } }

# Auth error
catch { if ($_.Exception.Message -match 'sign.?in|authenticate|unauthorized|401|403') { ... } }

# Access error
catch { if ($_.Exception.Message -match 'access.*denied|insufficient|forbidden') { ... } }

# Network error
catch { if ($_.Exception.Message -match 'timeout|connection|network') { ... } }
```

---

## cmdlet Reference

### Get-AdminPowerAppEnvironment
```powershell
# Lists all Power Platform environments
Get-AdminPowerAppEnvironment
# Returns: Environment objects with EnvironmentName, DisplayName, IsDefault, etc.

# Useful properties:
# - EnvironmentName: GUID (unique ID)
# - DisplayName: User-friendly name
# - IsDefault: $true if default environment
# - EnvironmentType: Sandbox, Production, Trial
# - CreatedOn: Datetime
# - EnvironmentRegion: Region code
```

### Get-AdminFlow
```powershell
# Lists flows in an environment
Get-AdminFlow -EnvironmentName "default"
# Returns: Flow objects with DisplayName, FlowName, Enabled, CreatedOn, Owner, etc.

# Get specific flow details
Get-AdminFlow -EnvironmentName "default" -FlowName "flow-guid"
# Returns: Detailed flow object

# Useful properties:
# - FlowName: GUID (unique ID)
# - DisplayName: User-friendly name
# - Enabled: $true if enabled
# - CreatedOn: Datetime
# - Owner: Creator/owner info
# - IsPublished: $true if published
```

### Get-AdminFlowOwnerRole
```powershell
# Lists owners of a specific flow
Get-AdminFlowOwnerRole -EnvironmentName "default" -FlowName "flow-guid"
# Returns: Owner role objects with DisplayName, PrincipalEmail, PrincipalType, RoleType

# Useful properties:
# - DisplayName: Owner display name
# - PrincipalEmail: Owner email
# - PrincipalType: User, Application, Group, etc.
# - RoleType: Owner, SharedUser, etc.
```

### Get-AdminPowerAppConnection
```powershell
# Lists connections in environment
Get-AdminPowerAppConnection -EnvironmentName "default"
# Lists all connections in environment

Get-AdminPowerAppConnection
# Lists all connections in all environments

# Useful properties:
# - DisplayName: Connection display name
# - ConnectorName: Connector type (SharePoint, SQL, Office365Users, etc.)
# - Status: Connected, Authenticated, etc.
# - CreatedTime: Datetime
```

### Get-AdminPowerAppConnector
```powershell
# Lists all available connectors in tenant
Get-AdminPowerAppConnector
# Returns: Connector objects with DisplayName, ConnectorName, Tier, etc.

# Useful properties:
# - ConnectorName: Unique identifier
# - DisplayName: User-friendly name
# - Tier: Standard, Premium, Business, etc.
# - ConnectorType: Managed, Custom, etc.
```

### Enable-AdminFlow / Disable-AdminFlow
```powershell
# Enable a flow
Enable-AdminFlow -EnvironmentName "default" -FlowName "flow-guid"

# Disable a flow
Disable-AdminFlow -EnvironmentName "default" -FlowName "flow-guid"

# Note: These make permanent changes - only used in production mode
# Test Tab uses dry-run pattern to show what would happen
```

---

## Verbose Output

Enable detailed output:

```powershell
# Method 1: Script flag
.\TestTabEnhancements.ps1 -Verbose

# Method 2: Global variable
$VerbosePreference = 'Continue'

# Method 3: Cmdlet parameter
Get-AdminFlow -Verbose

# Shows:
# - Each cmdlet being called
# - Timing for each operation
# - Full error details with stack trace
# - Input/output objects
```

---

## Testing Checklist

### Pre-Test
- [ ] PowerShell 5.1 running (not Core)
- [ ] PowerApps module installed
- [ ] User signed in with Add-PowerAppsAccount
- [ ] User has Power Platform admin role

### During Test
- [ ] All buttons working
- [ ] Results display in grids
- [ ] Error messages clear and actionable
- [ ] Timing information recorded
- [ ] No unintended changes (dry-run mode)

### Post-Test
- [ ] All test results captured
- [ ] Any failures investigated
- [ ] Environment unchanged (read-only tests)
- [ ] Performance acceptable

---

## Performance Tips

| Slow Step | Cause | Fix |
|-----------|-------|-----|
| Environment list slow | Network latency | Try again, check internet |
| Flow list slow | Large environment (100+) | Filter to specific flow |
| Owner lookup slow | Dataverse access | Ensure admin access |
| Connector list slow | First-time load | Caches after first call |
| All tests slow | Background processes | Close other apps, restart |

---

## Debugging Tips

```powershell
# See all cmdlet calls
$DebugPreference = 'Continue'

# See all parameters
$VerbosePreference = 'Continue'

# Measure individual steps
$watch = Measure-Command { Get-AdminFlow -EnvironmentName "default" }
$watch.TotalMilliseconds

# Check sign-in status
Get-AdminFlow -EnvironmentName "default" -ErrorAction SilentlyContinue
# If this works, auth is good

# Test raw HTTP probe
Invoke-RawProbe
# Shows status code, content type, response preview
```

---

## Common Patterns

### Conditional Execution
```powershell
# Check environment is selected
if (-not $selectedEnv) {
    Write-TestStatus "No environment selected" -Status Warning
    return
}

# Check flows exist
if ($result.Count -eq 0) {
    Write-TestStatus "No flows in environment" -Status Info
    return
}
```

### Loop Through Results
```powershell
# Display results
foreach ($flow in $result.Flows) {
    $status = if ($flow.Enabled) { "Enabled" } else { "Disabled" }
    Write-Host "• $($flow.DisplayName) ($status)"
}

# Count by property
$byOwner = $flows | Group-Object -Property Owner
foreach ($group in $byOwner) {
    Write-Host "$($group.Name): $($group.Count) flows"
}
```

### Error Recovery
```powershell
try {
    $result = Test-AdminFlows -Environment $env
    if (-not $result.Success) {
        Write-TestStatus $result.Error -Status Fail
        # Optional: try alternative approach
    }
} catch {
    Write-TestStatus "Unexpected error: $($_.Exception.Message)" -Status Fail
}
```

---

## Resources

| Resource | Link |
|----------|------|
| PowerApps Cmdlet Docs | https://docs.microsoft.com/powershell/module/microsoft.powerapps.administration.powershell |
| Power Platform Admin | https://admin.powerplatform.microsoft.com |
| Flow Docs | https://docs.microsoft.com/power-automate |
| Power Platform Governance | https://docs.microsoft.com/power-platform/admin |

---

**Version**: 1.0.0  
**Last Updated**: 2026-11-24  
**Author**: Copilot
