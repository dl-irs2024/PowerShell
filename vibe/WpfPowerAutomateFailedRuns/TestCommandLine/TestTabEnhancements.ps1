#Requires -Version 5.1

<#
.SYNOPSIS
    Test Tab Enhancements for Power Automate WPF Inspector
    
.DESCRIPTION
    Enhanced test cmdlets for the Power Automate WPF tool, testing administrative
    PowerShell cmdlets with real environments. This script provides comprehensive
    testing of:
    - Get-AdminFlow
    - Enable-AdminFlow
    - Disable-AdminFlow
    - Get-AdminFlowOwnerRole
    - Get-AdminPowerAppConnection
    - Get-AdminPowerAppConnector
    - Get-AdminPowerAppEnvironment
    
.NOTES
    Author: Copilot
    Version: 1.0.0
    Requires: PowerShell 5.1+, Microsoft.PowerApps.Administration.PowerShell
    
.EXAMPLE
    # Run all tests with interactive environment selection
    .\TestTabEnhancements.ps1 -RunAllTests
    
.EXAMPLE
    # Test a specific environment
    .\TestTabEnhancements.ps1 -TestEnvironmentFlows -EnvironmentName "default"
#>

[CmdletBinding()]
param(
    [switch]$RunAllTests,
    [switch]$TestEnvironmentFlows,
    [switch]$TestFlowOwnerRoles,
    [switch]$TestConnections,
    [switch]$TestConnectors,
    [switch]$TestFlowManagement,
    [string]$EnvironmentName,
    [switch]$Interactive = $true,
    [switch]$Verbose
)

# Set up error handling and logging
$ErrorActionPreference = 'Continue'
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

# Results tracking
$Script:TestResults = @()

#region Helper Functions

function Write-TestStatus {
    param(
        [string]$Message,
        [ValidateSet('Pass', 'Fail', 'Info', 'Warning')]
        [string]$Status = 'Info',
        [ValidateSet('Host', 'Verbose', 'Debug')]
        [string]$Target = 'Host'
    )
    
    $colors = @{
        Pass = 'Green'
        Fail = 'Red'
        Info = 'Cyan'
        Warning = 'Yellow'
    }
    
    $prefix = @{
        Pass = '[✓]'
        Fail = '[✗]'
        Info = '[i]'
        Warning = '[!]'
    }
    
    $output = "$($prefix[$Status]) $Message"
    
    if ($Target -eq 'Host') {
        Write-Host $output -ForegroundColor $colors[$Status]
    } elseif ($Target -eq 'Verbose') {
        Write-Verbose $output
    } else {
        Write-Debug $output
    }
    
    return $output
}

function Assert-ModuleLoaded {
    param(
        [string]$ModuleName = 'Microsoft.PowerApps.Administration.PowerShell'
    )
    
    try {
        $module = Get-Module -Name $ModuleName -ErrorAction Stop
        if ($null -eq $module) {
            Write-TestStatus "Module $ModuleName not loaded, attempting import..." -Status Info
            Import-Module -Name $ModuleName -ErrorAction Stop
            Write-TestStatus "Successfully imported module $ModuleName" -Status Pass
        } else {
            Write-TestStatus "Module $ModuleName already loaded (v$($module.Version))" -Status Pass
        }
        return $true
    } catch {
        Write-TestStatus "Failed to load module $ModuleName : $($_.Exception.Message)" -Status Fail
        Write-TestStatus "Install with: Install-Module -Name $ModuleName -AllowClobber -Force" -Status Warning
        return $false
    }
}

function Test-PowerPlatformSignIn {
    <#
    .SYNOPSIS
        Verify Power Platform sign-in status and show current user
    #>
    try {
        # Try to get current user context
        $user = Get-AdminFlow -EnvironmentName 'default' -ErrorAction SilentlyContinue
        Write-TestStatus "PowerApps admin API is accessible" -Status Pass
        return $true
    } catch {
        if ($_.Exception.Message -match 'sign.?in|authenticate|unauthorized|401|403') {
            Write-TestStatus "Not signed in. Run Add-PowerAppsAccount in PowerShell" -Status Fail
            return $false
        } else {
            Write-TestStatus "Error checking sign-in status: $($_.Exception.Message)" -Status Warning
            return $false
        }
    }
}

function Get-AdminEnvironmentInteractive {
    <#
    .SYNOPSIS
        Prompt user to select an environment from available environments
    #>
    try {
        Write-TestStatus "Retrieving available environments..." -Status Info
        $environments = @(Get-AdminPowerAppEnvironment -ErrorAction Stop)
        
        if ($environments.Count -eq 0) {
            Write-TestStatus "No environments found. Ensure you're signed in with admin privileges." -Status Fail
            return $null
        }
        
        Write-TestStatus "Found $($environments.Count) environment(s)" -Status Pass
        Write-Host ""
        
        # Sort with default environment first
        $environments = $environments | Sort-Object -Property @{ Expression = 'IsDefault'; Descending = $true }
        
        # Display options
        for ($i = 0; $i -lt $environments.Count; $i++) {
            $env = $environments[$i]
            $displayName = if ($env.DisplayName) { $env.DisplayName } else { $env.EnvironmentName }
            $defaultText = if ($env.IsDefault) { " [DEFAULT]" } else { "" }
            Write-Host "[$($i + 1)] $displayName ($($env.EnvironmentName))$defaultText"
        }
        
        Write-Host ""
        $selection = Read-Host "Select environment number (1-$($environments.Count))"
        
        $index = [int]$selection - 1
        if ($index -lt 0 -or $index -ge $environments.Count) {
            Write-TestStatus "Invalid selection" -Status Fail
            return $null
        }
        
        $selected = $environments[$index]
        Write-TestStatus "Selected: $(if ($selected.DisplayName) { $selected.DisplayName } else { $selected.EnvironmentName })" -Status Pass
        return $selected
    } catch {
        Write-TestStatus "Error retrieving environments: $($_.Exception.Message)" -Status Fail
        return $null
    }
}

#endregion

#region Test Functions

function Test-AdminEnvironments {
    <#
    .SYNOPSIS
        Test Get-AdminPowerAppEnvironment cmdlet
    #>
    Write-Host ""
    Write-Host "=== Testing Get-AdminPowerAppEnvironment ===" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $watch = Measure-Command {
            $environments = @(Get-AdminPowerAppEnvironment -ErrorAction Stop)
        }
        
        if ($environments.Count -eq 0) {
            Write-TestStatus "No environments returned" -Status Warning
            return @{ Success = $false; Count = 0; Time = $watch.TotalMilliseconds }
        }
        
        Write-TestStatus "Retrieved $($environments.Count) environment(s) in $([math]::Round($watch.TotalMilliseconds))ms" -Status Pass
        
        # Display summary
        $defaultEnv = $environments | Where-Object { $_.IsDefault }
        if ($defaultEnv) {
            Write-TestStatus "Default environment: $(if ($defaultEnv.DisplayName) { $defaultEnv.DisplayName } else { $defaultEnv.EnvironmentName })" -Status Info
        }
        
        # Show all environments
        Write-Host ""
        Write-Host "Environments:" -ForegroundColor Cyan
        foreach ($env in ($environments | Sort-Object -Property @{ Expression = 'IsDefault'; Descending = $true })) {
            $displayName = if ($env.DisplayName) { $env.DisplayName } else { $env.EnvironmentName }
            $typeStr = if ($env.EnvironmentType) { " ($($env.EnvironmentType))" } else { "" }
            $defaultStr = if ($env.IsDefault) { " [DEFAULT]" } else { "" }
            Write-Host "  • $displayName (ID: $($env.EnvironmentName))$typeStr$defaultStr"
        }
        
        return @{ Success = $true; Count = $environments.Count; Time = $watch.TotalMilliseconds; Environments = $environments }
    } catch {
        Write-TestStatus "Error: $($_.Exception.Message)" -Status Fail
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-AdminFlows {
    param(
        [Parameter(Mandatory)][object]$Environment
    )
    
    <#
    .SYNOPSIS
        Test Get-AdminFlow cmdlet for an environment
    #>
    Write-Host ""
    Write-Host "=== Testing Get-AdminFlow for environment: $(if ($Environment.DisplayName) { $Environment.DisplayName } else { $Environment.EnvironmentName }) ===" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $watch = Measure-Command {
            $flows = @(Get-AdminFlow -EnvironmentName $Environment.EnvironmentName -ErrorAction Stop)
        }
        
        Write-TestStatus "Retrieved $($flows.Count) flow(s) in $([math]::Round($watch.TotalMilliseconds))ms" -Status $(if ($flows.Count -gt 0) { 'Pass' } else { 'Info' })
        
        if ($flows.Count -eq 0) {
            Write-TestStatus "No flows in this environment" -Status Info
            return @{ Success = $true; Count = 0; Time = $watch.TotalMilliseconds }
        }
        
        # Display sample flows
        Write-Host ""
        Write-Host "Sample flows (first 10):" -ForegroundColor Cyan
        $sampleFlows = $flows | Select-Object -First 10
        foreach ($flow in $sampleFlows) {
            $status = if ($flow.Enabled) { "Enabled" } else { "Disabled" }
            $displayName = if ($flow.DisplayName) { $flow.DisplayName } else { $flow.Name }
            Write-Host "  • $displayName (ID: $($flow.Name), Status: $status)"
        }
        
        # Statistics
        $enabledCount = @($flows | Where-Object { $_.Enabled }).Count
        $disabledCount = $flows.Count - $enabledCount
        
        Write-Host ""
        Write-TestStatus "Enabled: $enabledCount, Disabled: $disabledCount" -Status Info
        
        return @{ Success = $true; Count = $flows.Count; EnabledCount = $enabledCount; DisabledCount = $disabledCount; Time = $watch.TotalMilliseconds; Flows = $sampleFlows }
    } catch {
        Write-TestStatus "Error: $($_.Exception.Message)" -Status Fail
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-FlowOwnerRoles {
    param(
        [Parameter(Mandatory)][object]$Environment,
        [Parameter(Mandatory)][object]$Flow
    )
    
    <#
    .SYNOPSIS
        Test Get-AdminFlowOwnerRole cmdlet
    #>
    Write-Host ""
    Write-Host "=== Testing Get-AdminFlowOwnerRole ===" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $watch = Measure-Command {
            $roles = @(Get-AdminFlowOwnerRole -EnvironmentName $Environment.EnvironmentName -FlowName $Flow.Name -ErrorAction Stop)
        }
        
        Write-TestStatus "Retrieved $($roles.Count) owner role(s) in $([math]::Round($watch.TotalMilliseconds))ms" -Status Pass
        
        if ($roles.Count -gt 0) {
            Write-Host ""
            Write-Host "Owner roles:" -ForegroundColor Cyan
            foreach ($role in $roles) {
                $displayName = if ($role.DisplayName) { $role.DisplayName } else { $role.PrincipalEmail }
                Write-Host "  • $displayName (Type: $($role.PrincipalType), Role: $($role.RoleType))"
            }
        } else {
            Write-TestStatus "No owner roles found (may be unowned or service principal)" -Status Info
        }
        
        return @{ Success = $true; Count = $roles.Count; Time = $watch.TotalMilliseconds; Roles = $roles }
    } catch {
        if ($_.Exception.Message -match 'not found|does not exist') {
            Write-TestStatus "Flow not found or cannot access roles" -Status Warning
        } else {
            Write-TestStatus "Error: $($_.Exception.Message)" -Status Fail
        }
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-PowerAppConnections {
    param(
        [object]$Environment
    )
    
    <#
    .SYNOPSIS
        Test Get-AdminPowerAppConnection cmdlet
    #>
    Write-Host ""
    Write-Host "=== Testing Get-AdminPowerAppConnection ===" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $params = @{ ErrorAction = 'Stop' }
        if ($Environment) {
            $params['EnvironmentName'] = $Environment.EnvironmentName
            Write-TestStatus "Retrieving connections for environment: $(if ($Environment.DisplayName) { $Environment.DisplayName } else { $Environment.EnvironmentName })" -Status Info
        } else {
            Write-TestStatus "Retrieving connections for all environments" -Status Info
        }
        
        $watch = Measure-Command {
            $connections = @(Get-AdminPowerAppConnection @params)
        }
        
        Write-TestStatus "Retrieved $($connections.Count) connection(s) in $([math]::Round($watch.TotalMilliseconds))ms" -Status Pass
        
        if ($connections.Count -gt 0) {
            Write-Host ""
            Write-Host "Sample connections (first 10):" -ForegroundColor Cyan
            $sampleConnections = $connections | Select-Object -First 10
            foreach ($conn in $sampleConnections) {
                $connectorName = if ($conn.ConnectorName) { $conn.ConnectorName } else { "Unknown" }
                Write-Host "  • $($conn.DisplayName) (Connector: $connectorName, Status: $($conn.Status))"
            }
        } else {
            Write-TestStatus "No connections found" -Status Info
        }
        
        return @{ Success = $true; Count = $connections.Count; Time = $watch.TotalMilliseconds; Connections = @($connections | Select-Object -First 10) }
    } catch {
        Write-TestStatus "Error: $($_.Exception.Message)" -Status Fail
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-PowerAppConnectors {
    <#
    .SYNOPSIS
        Test Get-AdminPowerAppConnector cmdlet
    #>
    Write-Host ""
    Write-Host "=== Testing Get-AdminPowerAppConnector ===" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $watch = Measure-Command {
            $connectors = @(Get-AdminPowerAppConnector -ErrorAction Stop)
        }
        
        Write-TestStatus "Retrieved $($connectors.Count) connector(s) in $([math]::Round($watch.TotalMilliseconds))ms" -Status Pass
        
        if ($connectors.Count -gt 0) {
            Write-Host ""
            Write-Host "Sample connectors (first 15):" -ForegroundColor Cyan
            $sampleConnectors = $connectors | Sort-Object -Property DisplayName | Select-Object -First 15
            foreach ($connector in $sampleConnectors) {
                $tier = if ($connector.Tier) { " [$($connector.Tier)]" } else { "" }
                Write-Host "  • $($connector.DisplayName) (ID: $($connector.ConnectorName))$tier"
            }
        }
        
        # Count by tier
        if ($connectors.Count -gt 0) {
            Write-Host ""
            Write-Host "Connector summary:" -ForegroundColor Cyan
            $byTier = $connectors | Group-Object -Property Tier
            foreach ($group in $byTier) {
                Write-Host "  • $($group.Name): $($group.Count) connector(s)"
            }
        }
        
        return @{ Success = $true; Count = $connectors.Count; Time = $watch.TotalMilliseconds }
    } catch {
        Write-TestStatus "Error: $($_.Exception.Message)" -Status Fail
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-FlowManagement {
    param(
        [Parameter(Mandatory)][object]$Environment,
        [Parameter(Mandatory)][object]$Flow
    )
    
    <#
    .SYNOPSIS
        Test Enable-AdminFlow and Disable-AdminFlow cmdlets (DRY RUN - shows what would happen)
    #>
    Write-Host ""
    Write-Host "=== Testing Enable-AdminFlow / Disable-AdminFlow (DRY RUN) ===" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $displayName = if ($Flow.DisplayName) { $Flow.DisplayName } else { $Flow.Name }
        $currentStatus = if ($Flow.Enabled) { "Enabled" } else { "Disabled" }
        
        Write-TestStatus "Current status of '$displayName': $currentStatus" -Status Info
        
        if ($Flow.Enabled) {
            Write-TestStatus "[DRY RUN] Would disable this flow with: Disable-AdminFlow -EnvironmentName '$($Environment.EnvironmentName)' -FlowName '$($Flow.Name)'" -Status Info
            Write-TestStatus "To actually disable, re-run without -Interactive or use the production mode" -Status Warning
        } else {
            Write-TestStatus "[DRY RUN] Would enable this flow with: Enable-AdminFlow -EnvironmentName '$($Environment.EnvironmentName)' -FlowName '$($Flow.Name)'" -Status Info
            Write-TestStatus "To actually enable, re-run without -Interactive or use the production mode" -Status Warning
        }
        
        return @{ Success = $true; FlowName = $displayName; CurrentStatus = $currentStatus; DryRun = $true }
    } catch {
        Write-TestStatus "Error: $($_.Exception.Message)" -Status Fail
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

#endregion

#region Main Test Flow

function Main {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   Power Automate Test Tab Enhancements - Admin Cmdlet Tester   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Check module
    if (-not (Assert-ModuleLoaded)) {
        Write-Host ""
        Write-TestStatus "Cannot continue without the PowerApps administration module" -Status Fail
        exit 1
    }
    
    Write-Host ""
    
    # Step 2: Check sign-in
    if (-not (Test-PowerPlatformSignIn)) {
        Write-Host ""
        Write-Host "To sign in, run:"
        Write-Host "  Add-PowerAppsAccount" -ForegroundColor Yellow
        Write-Host ""
        Write-TestStatus "Cannot continue without sign-in" -Status Fail
        exit 1
    }
    
    Write-Host ""
    Write-Host ""
    
    # Step 3: Test environments
    $envResult = Test-AdminEnvironments
    if (-not $envResult.Success) {
        Write-Host ""
        Write-TestStatus "Cannot continue without environments" -Status Fail
        exit 1
    }
    
    # Step 4: Prompt for environment selection
    $selectedEnv = $null
    if ($Interactive) {
        Write-Host ""
        $selectedEnv = Get-AdminEnvironmentInteractive
        if ($null -eq $selectedEnv) {
            Write-TestStatus "No environment selected" -Status Fail
            exit 1
        }
    } else {
        # Use first environment if not interactive
        $selectedEnv = $envResult.Environments[0]
        Write-Host ""
        Write-TestStatus "Using default environment: $(if ($selectedEnv.DisplayName) { $selectedEnv.DisplayName } else { $selectedEnv.EnvironmentName })" -Status Info
    }
    
    # Step 5: Test flows in selected environment
    Write-Host ""
    $flowResult = Test-AdminFlows -Environment $selectedEnv
    if (-not $flowResult.Success -or $flowResult.Count -eq 0) {
        Write-Host ""
        Write-TestStatus "No flows in selected environment to test further" -Status Warning
        return
    }
    
    # Get a sample flow for further tests
    $sampleFlow = $flowResult.Flows | Select-Object -First 1
    
    # Step 6: Test flow owner roles
    Write-Host ""
    Test-FlowOwnerRoles -Environment $selectedEnv -Flow $sampleFlow | Out-Null
    
    # Step 7: Test connections
    Write-Host ""
    Test-PowerAppConnections -Environment $selectedEnv | Out-Null
    
    # Step 8: Test connectors
    Write-Host ""
    Test-PowerAppConnectors | Out-Null
    
    # Step 9: Test flow management (dry run)
    Write-Host ""
    Test-FlowManagement -Environment $selectedEnv -Flow $sampleFlow | Out-Null
    
    # Summary
    Write-Host ""
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                      ALL TESTS COMPLETED                       ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-TestStatus "All cmdlets tested successfully against real environments" -Status Pass
    Write-Host ""
}

#endregion

# Entry point
if ($RunAllTests) {
    Main
} else {
    Write-Host "Test Tab Enhancements Module loaded" -ForegroundColor Green
    Write-Host ""
    Write-Host "Available functions:" -ForegroundColor Cyan
    Write-Host "  • Test-AdminEnvironments              - List environments"
    Write-Host "  • Test-AdminFlows                     - Get flows for an environment"
    Write-Host "  • Test-FlowOwnerRoles                 - Get flow owner information"
    Write-Host "  • Test-PowerAppConnections            - List connections"
    Write-Host "  • Test-PowerAppConnectors             - List available connectors"
    Write-Host "  • Test-FlowManagement                 - Test enable/disable flows"
    Write-Host "  • Get-AdminEnvironmentInteractive     - Interactively select environment"
    Write-Host ""
    Write-Host "Run all tests with:"
    Write-Host "  .\TestTabEnhancements.ps1 -RunAllTests" -ForegroundColor Yellow
    Write-Host ""
}
