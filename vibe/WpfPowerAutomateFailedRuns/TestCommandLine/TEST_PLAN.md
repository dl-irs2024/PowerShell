# Power Automate Test Tab Enhancements - Test Plan

## Overview
This test plan covers enhanced Tab testing for the Power Automate WPF Inspector, focusing on administrative PowerShell cmdlets and real environment testing.

## Objectives
- Test administrative cmdlets with real Power Platform environments
- Verify user environment discovery and selection
- Validate flow information retrieval and management capabilities
- Ensure error handling and status reporting

---

## Prerequisites

### System Requirements
- **PowerShell**: 5.1 or higher (Windows PowerShell, not Core)
- **Modules**: Microsoft.PowerApps.Administration.PowerShell
- **Network**: HTTPS access to Power Platform endpoints
- **Permissions**: Power Platform admin role or equivalent

### Installation Steps

1. **Verify PowerShell Version**
   ```powershell
   $PSVersionTable.PSVersion
   # Should show version 5.1 or higher
   ```

2. **Install PowerApps Admin Module**
   ```powershell
   Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -AllowClobber -Force -Scope CurrentUser
   ```

3. **Verify Module Installation**
   ```powershell
   Get-Module -Name Microsoft.PowerApps.Administration.PowerShell -ListAvailable
   ```

---

## Test Cases

### Test Group 1: Module Validation

#### TC1.1 - Module Load Test
**Objective**: Verify that the PowerApps admin module loads correctly

**Steps**:
1. Run test script: `.\TestTabEnhancements.ps1`
2. Observe module validation output
3. Verify status shows "Module loaded" or appropriate installation instructions

**Expected Result**: ✓ Module loads successfully, or ✗ Clear installation instructions displayed

**Notes**:
- If module not found, instructions guide user to install via PowerShell Gallery
- Module version should be displayed

---

### Test Group 2: Authentication

#### TC2.1 - Sign-In Status Check
**Objective**: Verify that the script can detect Power Platform sign-in status

**Steps**:
1. Run test script without prior sign-in
2. Observe authentication check
3. Run `Add-PowerAppsAccount` when prompted
4. Complete Microsoft interactive sign-in
5. Re-run test script

**Expected Result**: ✓ Script detects authentication state and prompts appropriately

**Notes**:
- First run should show "Not signed in" and provide sign-in guidance
- After sign-in, should show authenticated state
- Supports multi-tenant sign-in with optional Tenant ID

---

### Test Group 3: Environment Discovery

#### TC3.1 - List All Environments
**Objective**: Retrieve and display all accessible environments

**Steps**:
1. Run: `Test-AdminEnvironments`
2. Verify environments are listed with:
   - Display name
   - Environment ID
   - Environment type
   - Default environment indicator

**Expected Result**: ✓ All environments listed with metadata

**Sample Output**:
```
[✓] Retrieved 3 environment(s) in 1234ms
Default environment: Production (ID: default)

Environments:
  • Production (ID: default) (Sandbox) [DEFAULT]
  • Dev Environment (ID: dev-guid-123) (Sandbox)
  • Test (ID: test-guid-456) (Sandbox)
```

**Notes**:
- Requires signed-in user with Environment Viewer or Admin role
- Performance: Typically 1-3 seconds for 1-10 environments

---

### Test Group 4: Interactive Environment Selection

#### TC4.1 - Environment Selection Menu
**Objective**: Allow user to interactively select an environment

**Steps**:
1. Run: `Get-AdminEnvironmentInteractive`
2. Review presented environment list
3. Enter selection number
4. Verify selected environment is confirmed

**Expected Result**: ✓ User can select environment from numbered list

**Sample Output**:
```
[i] Retrieving available environments...
[✓] Found 3 environment(s)

[1] Production (default)
[2] Dev Environment (Dev-123)
[3] Test (Test-456)

Select environment number (1-3): 1
[✓] Selected: Production
```

**Notes**:
- Default environment listed first
- Menu accepts numeric input (1-N)
- Validates selection before returning

---

### Test Group 5: Flow Retrieval and Analysis

#### TC5.1 - Get Flows from Environment
**Objective**: Retrieve all flows from selected environment

**Steps**:
1. Select an environment (use TC4.1)
2. Run: `Test-AdminFlows -Environment $selectedEnv`
3. Verify flows are listed with:
   - Display name
   - Flow ID
   - Enabled/Disabled status
   - Sample of up to 10 flows

**Expected Result**: ✓ Flows retrieved with enabled/disabled count

**Sample Output**:
```
[✓] Retrieved 42 flow(s) in 2156ms
[✓] Enabled: 38, Disabled: 4

Sample flows (first 10):
  • Process Orders (ID: flow-123, Status: Enabled)
  • Generate Reports (ID: flow-456, Status: Enabled)
  • Alert Handler (ID: flow-789, Status: Disabled)
```

**Notes**:
- Retrieves only flows in selected environment
- Counts enabled vs. disabled
- Large environment (100+ flows) may take 5-10 seconds
- Dependent on TC3.1 success

---

### Test Group 6: Flow Owner Roles

#### TC6.1 - Get Flow Owner Information
**Objective**: Retrieve owner role information for a flow

**Steps**:
1. Have at least one enabled flow from TC5.1
2. Run: `Test-FlowOwnerRoles -Environment $env -Flow $flow`
3. Verify owner information displayed:
   - Owner display name
   - Owner principal type (User/Application/etc.)
   - Role type (Owner/SharedUser/etc.)

**Expected Result**: ✓ Owner roles retrieved and displayed

**Sample Output**:
```
[✓] Retrieved 2 owner role(s) in 456ms

Owner roles:
  • john.doe@contoso.com (Type: User, Role: Owner)
  • contoso@contoso.onmicrosoft.com (Type: Application, Role: Owner)
```

**Notes**:
- Some flows may have no retrievable owners
- Service principal-owned flows may show minimal information
- Dependent on TC5.1 success

---

### Test Group 7: Connections

#### TC7.1 - List All Connections
**Objective**: Retrieve all connections in an environment

**Steps**:
1. Select environment (TC4.1)
2. Run: `Test-PowerAppConnections -Environment $selectedEnv`
3. Verify connections listed with:
   - Display name
   - Connector name/type
   - Connection status
   - Sample of up to 10 connections

**Expected Result**: ✓ Connections retrieved and displayed

**Sample Output**:
```
[✓] Retrieved 15 connection(s) in 892ms

Sample connections (first 10):
  • My SharePoint (Connector: SharePoint, Status: Connected)
  • Office 365 Users (Connector: Office365Users, Status: Connected)
  • SQL Database (Connector: SQL, Status: Connected)
```

**Notes**:
- Some environments may have no connections
- Requires Environment Viewer or Admin role
- Performance depends on connection count

---

### Test Group 8: Connectors

#### TC8.1 - List Available Connectors
**Objective**: Retrieve all available connectors in the tenant

**Steps**:
1. Run: `Test-PowerAppConnectors`
2. Verify connectors listed with:
   - Display name
   - Connector ID
   - Tier (Standard/Premium/Business/etc.)
   - Sample of 15 connectors and summary by tier

**Expected Result**: ✓ Connectors retrieved and categorized

**Sample Output**:
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
- Large list (200+ connectors typical)
- Categorized by tier
- Shows popular/sample connectors only

---

### Test Group 9: Flow Management

#### TC9.1 - Flow Enable/Disable Dry Run
**Objective**: Test flow management cmdlets in dry-run mode

**Steps**:
1. Have a flow from TC5.1
2. Run: `Test-FlowManagement -Environment $env -Flow $flow`
3. Observe dry-run output showing what would happen
4. Verify correct cmdlet syntax is shown

**Expected Result**: ✓ Dry-run shows Enable-AdminFlow or Disable-AdminFlow cmdlet

**Sample Output**:
```
[i] Current status of 'Process Orders': Enabled
[i] [DRY RUN] Would disable this flow with:
    Disable-AdminFlow -EnvironmentName 'default' -FlowName 'flow-123'
[!] To actually disable, use the production mode
```

**Notes**:
- Always a dry-run to prevent accidental disabling
- Shows exact cmdlet that would be executed
- Production mode would require additional confirmation

---

### Test Group 10: Complete Test Flow

#### TC10.1 - Run All Tests (Integrated)
**Objective**: Execute all tests in correct dependency order

**Steps**:
1. Ensure prerequisites are met (module, sign-in)
2. Run: `.\TestTabEnhancements.ps1 -RunAllTests`
3. Observe each step:
   - Module validation
   - Sign-in check
   - Environment retrieval
   - Interactive environment selection
   - Flow retrieval
   - Owner roles
   - Connections
   - Connectors
   - Flow management
4. Verify completion message

**Expected Result**: ✓ All steps complete successfully

**Sample Output**:
```
╔════════════════════════════════════════════════════════════════╗
║   Power Automate Test Tab Enhancements - Admin Cmdlet Tester   ║
╚════════════════════════════════════════════════════════════════╝

[✓] Module already loaded (v2.2.142)
[✓] PowerApps admin API is accessible

[✓] Retrieved 3 environment(s) in 1234ms

[1] Production (default)
[2] Dev
[3] Test

Select environment number (1-3): 1
[✓] Selected: Production

[✓] Retrieved 42 flow(s) in 2156ms
... (more test output)

╔════════════════════════════════════════════════════════════════╗
║                      ALL TESTS COMPLETED                       ║
╚════════════════════════════════════════════════════════════════╝
```

**Notes**:
- Stops at first failure (critical path)
- Full timing information provided
- Can take 2-5 minutes for complete environment

---

## Error Scenarios

### ES1 - Module Not Found
**Trigger**: PowerApps module not installed

**Expected Handling**:
```
[✗] Failed to load module Microsoft.PowerApps.Administration.PowerShell
Install with: Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -AllowClobber -Force
```

**Resolution**: Follow instructions to install module

### ES2 - Not Signed In
**Trigger**: No active Power Platform session

**Expected Handling**:
```
[✗] Not signed in. Run Add-PowerAppsAccount in PowerShell
```

**Resolution**: Execute `Add-PowerAppsAccount` and complete interactive sign-in

### ES3 - No Admin Access
**Trigger**: User account lacks admin permissions

**Expected Handling**:
```
[✗] Error: insufficient privileges to retrieve environments
# Fix: Ensure your user account has Power Platform admin role
```

**Resolution**: Contact tenant admin to grant Environment Admin role

### ES4 - Network Issue
**Trigger**: Cannot reach Power Platform endpoints

**Expected Handling**:
```
[✗] Error: Unable to contact Power Platform endpoints
# Check: Network connectivity, firewall, proxy settings
```

**Resolution**: Verify network connectivity and firewall rules

### ES5 - Invalid Environment Selection
**Trigger**: User enters invalid menu number

**Expected Handling**:
```
Select environment number (1-3): 5
[✗] Invalid selection
```

**Resolution**: Re-run and select from valid range (1-3)

---

## Performance Benchmarks

| Test Case | Expected Duration | Environment Size |
|-----------|-------------------|------------------|
| Module Load | <1 sec | N/A |
| Auth Check | <1 sec | N/A |
| List Environments | 1-3 sec | 1-10 envs |
| List Flows | 2-5 sec | 1-50 flows |
| List Flows | 5-10 sec | 50-100 flows |
| Flow Owner Roles | <1 sec | Per flow |
| List Connections | 1-3 sec | 1-20 connections |
| List Connectors | 2-4 sec | 200+ connectors |
| **Total (All Tests)** | **2-5 min** | **Medium Org** |

---

## Test Execution Checklist

### Pre-Test
- [ ] PowerShell 5.1+ installed
- [ ] PowerApps Admin module installed
- [ ] User signed in with Power Platform admin role
- [ ] Network connectivity verified
- [ ] Test script located and accessible

### During Test
- [ ] All test cases executed in order
- [ ] Expected output compared with actual
- [ ] Error handling verified
- [ ] Timing recorded
- [ ] Issues documented

### Post-Test
- [ ] All test results recorded
- [ ] Any failures investigated
- [ ] Environment cleaned up (no changes made in dry-run)
- [ ] Test report generated

---

## Integration with WPF Tab

The Test Tab in the WPF application will incorporate these tests with:

1. **Step Buttons**
   - Prerequisites (module, auth, network)
   - Sample Environments (interactive selection)
   - Sample Flows (from selected environment)
   - Sample Owners (from flows)
   - Sample Runs (from first flow)

2. **Status Display**
   - Real-time test execution status
   - Duration in milliseconds
   - Detailed error messages in console

3. **Sample Data Grid**
   - Displays up to 10 sample items from each test
   - Shows relevant properties
   - Allows inspection of PowerShell objects

4. **Console Output**
   - Full cmdlet execution details
   - Verbose mode for troubleshooting
   - Color-coded status messages

---

## Success Criteria

✓ All cmdlets tested successfully against real environments  
✓ User can interactively select from available environments  
✓ Accurate environment, flow, and connection information retrieved  
✓ Error scenarios handled gracefully with guidance  
✓ Performance within acceptable benchmarks  
✓ No unintended changes to environments or resources  

---

## References

- [Get-AdminPowerAppEnvironment](https://docs.microsoft.com/en-us/powershell/module/microsoft.powerapps.administration.powershell/get-adminpowerappenv)
- [Get-AdminFlow](https://docs.microsoft.com/en-us/powershell/module/microsoft.powerapps.administration.powershell/get-adminflow)
- [Get-AdminFlowOwnerRole](https://docs.microsoft.com/en-us/powershell/module/microsoft.powerapps.administration.powershell/get-adminflowownerrole)
- [Get-AdminPowerAppConnection](https://docs.microsoft.com/en-us/powershell/module/microsoft.powerapps.administration.powershell/get-adminpowerappconnection)
- [Get-AdminPowerAppConnector](https://docs.microsoft.com/en-us/powershell/module/microsoft.powerapps.administration.powershell/get-adminpowerappconnector)

---

**Document Version**: 1.0.0  
**Last Updated**: 2026-11-24  
**Author**: Copilot
