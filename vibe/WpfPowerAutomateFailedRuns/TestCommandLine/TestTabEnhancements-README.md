# Power Automate WPF Inspector - Test Tab Enhancements

## Overview

This project provides comprehensive Test Tab enhancements for the Power Automate WPF Inspector, enabling users to test administrative PowerShell cmdlets against real Power Platform environments with an interactive experience.

## Key Features

✅ **Interactive Environment Selection**  
- Discover and select from available Power Platform environments
- Lists environment metadata (type, default indicator, ID)
- Supports multi-tenant sign-in

✅ **Flow Discovery & Analysis**  
- Retrieve flows from selected environment
- Shows enabled/disabled status and counts
- Displays sample flows with metadata

✅ **Owner Analysis**  
- Identify flow owners and ownership distribution
- Groups by owner with flow count
- Detects service principals and unowned flows

✅ **Connection & Connector Testing**  
- List all connections in environment
- Browse all available connectors by tier
- Shows connector details and metadata

✅ **Flow Management Testing**  
- Dry-run testing for enable/disable operations
- Shows exact PowerShell cmdlets that would execute
- Safe testing without modifications

✅ **Comprehensive Error Handling**  
- Validates prerequisites (PowerShell 5.1, modules, sign-in)
- Clear guidance for common issues
- Detailed error messages with remediation steps

✅ **Performance Monitoring**  
- Tracks execution time for each test
- Provides performance benchmarks
- Displays timing for diagnostics

## Files Included

### Scripts

| File | Purpose |
|------|---------|
| `TestTabEnhancements.ps1` | Main test script with all cmdlet functions |
| `WpfPowerAutomateFailedRuns.ps1` | WPF application (can be enhanced) |

### Documentation

| File | Purpose |
|------|---------|
| `TEST_PLAN.md` | Detailed test cases, expected results, and scenarios |
| `EXECUTION_GUIDE.md` | Step-by-step instructions for running tests |
| `TestTabEnhancements-README.md` | This file - overview and quick start |

## Prerequisites

### Required

- **PowerShell 5.1** (Windows PowerShell, NOT PowerShell Core/7.x)
  - Check: `$PSVersionTable.PSVersion` should show 5.1.x
  - Download: Windows 10/11 includes PowerShell 5.1

- **PowerApps Admin Module**
  ```powershell
  Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -AllowClobber -Force
  ```

- **Power Platform Admin Role** or equivalent
  - User account must have Environment Admin or Power Platform Admin role
  - Contact tenant admin if needed

### Optional

- Administrator PowerShell for module installation
- HTTPS (port 443) network access to Power Platform

## Quick Start

### 1. Install Module (One Time)

```powershell
# Open Windows PowerShell 5.1 as Administrator
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell `
  -AllowClobber -Force -Scope CurrentUser
```

### 2. Sign In

```powershell
Add-PowerAppsAccount
# Complete login in the browser window
```

### 3. Run Tests

```powershell
cd C:\Davis\vibe\Power-Automate
.\TestTabEnhancements.ps1 -RunAllTests
```

### 4. Follow Prompts

- Select from available environments
- Observe test execution and results
- Review sample data returned

## Test Functions

All functions are available for individual use:

### Environment Functions
```powershell
Test-AdminEnvironments                    # List all environments
Get-AdminEnvironmentInteractive           # Interactive environment picker
```

### Flow Functions
```powershell
Test-AdminFlows -Environment $env        # Get flows for environment
Test-FlowOwnerRoles -Environment $env -Flow $flow  # Get flow owners
Test-FlowManagement -Environment $env -Flow $flow  # Test enable/disable
```

### Connection Functions
```powershell
Test-PowerAppConnections -Environment $env  # List connections
Test-PowerAppConnectors                     # List all available connectors
```

### Validation Functions
```powershell
Assert-ModuleLoaded                      # Check/load PowerApps module
Test-PowerPlatformSignIn                 # Verify authentication status
```

## Examples

### List All Environments

```powershell
. .\TestTabEnhancements.ps1
Test-AdminEnvironments
```

Output:
```
[✓] Retrieved 3 environment(s) in 1234ms
Default environment: Production

Environments:
  • Production (ID: default) (Sandbox) [DEFAULT]
  • Dev (ID: dev-123) (Sandbox)
  • Test (ID: test-456) (Sandbox)
```

### Get Flows for Selected Environment

```powershell
$env = Get-AdminEnvironmentInteractive
Test-AdminFlows -Environment $env
```

Output:
```
[✓] Retrieved 42 flow(s) in 2156ms
[✓] Enabled: 38, Disabled: 4

Sample flows (first 10):
  • Process Orders (ID: flow-123, Status: Enabled)
  • Generate Reports (ID: flow-456, Status: Enabled)
  ...
```

### Test All (Integrated Flow)

```powershell
.\TestTabEnhancements.ps1 -RunAllTests
```

Executes in order:
1. Prerequisites check
2. List environments
3. Interactive selection
4. Get flows
5. Get owners
6. List connections
7. List connectors
8. Test flow management

## WPF Integration

The Test Tab in the WPF application can use these functions:

### Button Mapping

| WPF Button | Calls | Returns to |
|-----------|-------|-----------|
| Prerequisites | `Test-PowerAutomateConnection` | `TestStatusText` |
| Sample Environments | `Test-AdminEnvironments` | `testSampleGrid` |
| Sample Flows | `Test-AdminFlows` | `testSampleGrid`, populates environment dropdown |
| Sample Owners | Shows data from flows | `testSampleGrid` |
| Sample Runs | `Get-LiveRuns` | `testSampleGrid` |
| Run All | Execute all above in order | Console + grids |

### Integration Pattern

```powershell
# Load module
. "$PSScriptRoot\TestTabEnhancements.ps1"

# Wire button to function
$button = $window.FindName('TestEnvsBtn')
$button.Add_Click({
    Invoke-TestStep -Step 'Sample Environments' -Action {
        $result = Test-AdminEnvironments
        if ($result.Success) {
            # Update WPF controls
            $testSampleGrid.ItemsSource = $result.Environments | 
                Select-Object DisplayName, Name, IsDefault
            return "$($result.Count) environment(s) found"
        }
        throw $result.Error
    }
})
```

## Troubleshooting

### Module Not Found

```powershell
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -AllowClobber -Force
```

### Not Signed In

```powershell
Add-PowerAppsAccount
```

### No Environments

- Verify user account has Power Platform Admin role
- Wait 15-30 minutes after role assignment
- Run `Add-PowerAppsAccount` again to refresh

### Network Issues

- Check firewall allows HTTPS to *.microsoft.com
- Test: `Test-NetConnection -ComputerName graph.microsoft.com -Port 443`
- Run `Invoke-RawProbe` for diagnostics

### Performance Slow

- Check network speed
- Try again later (may be service latency)
- Test on smaller sample with `-Verbose` for details

## Performance Benchmarks

| Operation | Expected Time |
|-----------|----------------|
| Module load | <1 second |
| List environments | 1-3 seconds |
| List flows (1-50) | 2-5 seconds |
| List flows (50-100) | 5-10 seconds |
| Get owners | <1 second |
| List connections | 1-3 seconds |
| List connectors | 2-4 seconds |
| **Total (all tests)** | **2-5 minutes** |

## Cmdlets Tested

The following Microsoft administrative cmdlets are tested:

- `Get-AdminPowerAppEnvironment` - List environments
- `Get-AdminFlow` - List flows in environment
- `Get-AdminFlowOwnerRole` - Get flow owner information
- `Get-AdminPowerAppConnection` - List connections
- `Get-AdminPowerAppConnector` - List connectors
- `Enable-AdminFlow` / `Disable-AdminFlow` - Flow management (dry-run)

## Documentation

For detailed information see:

- **[EXECUTION_GUIDE.md](EXECUTION_GUIDE.md)** - Step-by-step execution instructions
- **[TEST_PLAN.md](TEST_PLAN.md)** - Comprehensive test cases and expected results

## Known Limitations

⚠️ **PowerShell Core Not Supported**  
- PowerApps modules only work in Windows PowerShell 5.1
- Use `powershell.exe`, not `pwsh.exe`

⚠️ **Dry-Run Mode for Flow Management**  
- Flow enable/disable tests show what would happen
- No actual changes are made
- Production deployment would require additional controls

⚠️ **Network/Proxy Issues**  
- 407 Proxy Required error indicates firewall/proxy blocking
- Requires network configuration (outside scope of this tool)

⚠️ **Large Environments**  
- 100+ flows may take 10+ seconds
- 500+ flows may require pagination
- Performance degrades with large datasets

## Support & Issues

For issues or questions:

1. Check [EXECUTION_GUIDE.md](EXECUTION_GUIDE.md) for troubleshooting
2. Review [TEST_PLAN.md](TEST_PLAN.md) for expected behavior
3. Run with `-Verbose` flag for detailed output
4. Check PowerShell version: `$PSVersionTable.PSVersion`
5. Verify sign-in: `Add-PowerAppsAccount`

## Contributing

To enhance or extend:

1. Test changes with real environments (small sample first)
2. Update test documentation
3. Verify backward compatibility
4. Add new functions following existing pattern

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-11-24 | Initial release - 9 test functions |

## License

Copilot-generated code for Power Automate testing.

## References

- [Get-AdminPowerAppEnvironment](https://docs.microsoft.com/powershell/module/microsoft.powerapps.administration.powershell/get-adminpowerappenv)
- [Get-AdminFlow](https://docs.microsoft.com/powershell/module/microsoft.powerapps.administration.powershell/get-adminflow)
- [Power Platform Admin Center](https://admin.powerplatform.microsoft.com)
- [PowerApps Module Documentation](https://docs.microsoft.com/powershell/module/microsoft.powerapps.administration.powershell)

---

**Ready to test?** Start with [EXECUTION_GUIDE.md](EXECUTION_GUIDE.md) →
