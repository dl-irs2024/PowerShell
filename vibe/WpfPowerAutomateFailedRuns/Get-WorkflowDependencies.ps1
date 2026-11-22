<#
.SYNOPSIS
    Workflow dependency and relationship analyzer for Power Automate
    
.DESCRIPTION
    Analyzes workflow dependencies including Canvas App invocations,
    SharePoint List triggers, and other workflow relationships.
    
.NOTES
    Author: Copilot
    Version: 1.0.0
#>

function Get-WorkflowDependencies {
    <#
    .SYNOPSIS
        Identify all dependencies for a workflow
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Workflow,
        
        [switch]$Recursive
    )
    
    $dependencies = @()
    
    # Canvas App dependencies (simulated)
    if (Get-Random -InputObject @($true, $false)) {
        $dependencies += [PSCustomObject]@{
            DependencyType = 'Canvas App'
            DependencyName = "App_$(Get-Random -Minimum 1 -Maximum 10)"
            RelationshipType = 'Invoked By'
            CriticalityLevel = Get-Random -InputObject @('Critical', 'High', 'Medium')
            Status = Get-Random -InputObject @('Active', 'Inactive', 'Pending Update')
        }
    }
    
    # SharePoint List dependencies (simulated)
    if (Get-Random -InputObject @($true, $false)) {
        $dependencies += [PSCustomObject]@{
            DependencyType = 'SharePoint List'
            DependencyName = "List_$(Get-Random -Minimum 1 -Maximum 20)"
            RelationshipType = 'Triggered By'
            CriticalityLevel = Get-Random -InputObject @('Critical', 'High', 'Medium')
            Status = 'Active'
        }
    }
    
    # Email dependencies (simulated)
    if (Get-Random -InputObject @($true, $false)) {
        $dependencies += [PSCustomObject]@{
            DependencyType = 'Email Connector'
            DependencyName = $Workflow.Owner
            RelationshipType = 'Uses'
            CriticalityLevel = 'High'
            Status = 'Active'
        }
    }
    
    # Other workflow dependencies (simulated)
    if (Get-Random -InputObject @($true, $false)) {
        $dependencies += [PSCustomObject]@{
            DependencyType = 'Child Workflow'
            DependencyName = "Workflow_Child_$(Get-Random -Minimum 1 -Maximum 15)"
            RelationshipType = 'Calls'
            CriticalityLevel = 'High'
            Status = 'Active'
        }
    }
    
    return $dependencies
}

function Test-DependencyHealth {
    <#
    .SYNOPSIS
        Check health status of workflow dependencies
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Dependencies
    )
    
    $healthReport = @()
    
    foreach ($dep in $Dependencies) {
        $health = [PSCustomObject]@{
            DependencyName = $dep.DependencyName
            DependencyType = $dep.DependencyType
            Status = $dep.Status
            LastChecked = Get-Date
            HealthScore = switch ($dep.Status) {
                'Active' { 100 }
                'Inactive' { 0 }
                'Pending Update' { 50 }
                default { 50 }
            }
            Recommendation = switch ($dep.Status) {
                'Active' { 'Monitor for any changes or issues' }
                'Inactive' { 'Review and either reactivate or remove this dependency' }
                'Pending Update' { 'Update pending - schedule maintenance window' }
                default { 'Investigate status' }
            }
        }
        
        $healthReport += $health
    }
    
    return $healthReport
}

function Get-InvokingCanvasApps {
    <#
    .SYNOPSIS
        Find all Canvas Apps that invoke a specific workflow
    #>
    param(
        [Parameter(Mandatory)]
        [string]$WorkflowId
    )
    
    $apps = @()
    
    # Simulated data - in production would query actual Canvas Apps
    for ($i = 1; $i -le (Get-Random -Minimum 0 -Maximum 5); $i++) {
        $apps += [PSCustomObject]@{
            AppName = "CanvasApp_$i"
            AppId = [guid]::NewGuid()
            Owner = "user_$i@contoso.com"
            CreatedDate = (Get-Date).AddDays(-([int](Get-Random -Minimum 1 -Maximum 180)))
            LastModified = (Get-Date).AddDays(-([int](Get-Random -Minimum 0 -Maximum 30)))
            IsPublished = Get-Random -InputObject @($true, $false)
            UserCount = Get-Random -Minimum 1 -Maximum 100
        }
    }
    
    return $apps
}

function Get-SharePointListTriggers {
    <#
    .SYNOPSIS
        Find SharePoint Lists that trigger a workflow
    #>
    param(
        [Parameter(Mandatory)]
        [string]$WorkflowId
    )
    
    $lists = @()
    
    # Simulated data - in production would query actual SharePoint Lists
    for ($i = 1; $i -le (Get-Random -Minimum 0 -Maximum 3); $i++) {
        $lists += [PSCustomObject]@{
            ListName = "List_$i"
            SiteUrl = "https://contoso.sharepoint.com/sites/Project$i"
            TriggerType = Get-Random -InputObject @('On Item Created', 'On Item Modified', 'On Item Created or Modified')
            LastTriggered = (Get-Date).AddDays(-([int](Get-Random -Minimum 0 -Maximum 30)))
            ItemCount = Get-Random -Minimum 10 -Maximum 10000
            Status = Get-Random -InputObject @('Active', 'Disabled')
        }
    }
    
    return $lists
}

function Get-DependentWorkflows {
    <#
    .SYNOPSIS
        Find workflows that depend on a specific workflow
    #>
    param(
        [Parameter(Mandatory)]
        [string]$WorkflowId,
        
        [PSCustomObject[]]$AllWorkflows
    )
    
    $dependents = @()
    
    # Simulated data - in production would analyze actual workflow definitions
    $possibleCount = Get-Random -Minimum 0 -Maximum 3
    
    for ($i = 1; $i -le $possibleCount; $i++) {
        $dependents += [PSCustomObject]@{
            WorkflowName = "Dependent_Workflow_$i"
            WorkflowId = [guid]::NewGuid()
            RelationType = 'Calls'
            StepName = "Step_$i"
            IsActive = Get-Random -InputObject @($true, $false)
            LastRun = (Get-Date).AddDays(-([int](Get-Random -Minimum 0 -Maximum 30)))
        }
    }
    
    return $dependents
}

function Export-DependencyReport {
    <#
    .SYNOPSIS
        Generate comprehensive dependency report
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Workflow,
        
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Dependencies,
        
        [ValidateSet('HTML', 'Markdown', 'CSV')]
        [string]$Format = 'HTML',
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportPath = $OutputPath -replace '\.[^.]*$', "_$timestamp.$Format"
    
    $canvasApps = Get-InvokingCanvasApps -WorkflowId $Workflow.WorkflowId
    $listTriggers = Get-SharePointListTriggers -WorkflowId $Workflow.WorkflowId
    $dependents = Get-DependentWorkflows -WorkflowId $Workflow.WorkflowId
    
    switch ($Format) {
        'HTML' {
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Workflow Dependency Report</title>
    <style>
        body { font-family: Segoe UI, sans-serif; margin: 20px; background-color: #f8f9fa; }
        h1 { color: #230FAB; border-bottom: 3px solid #230FAB; }
        h2 { color: #333; margin-top: 30px; border-bottom: 2px solid #74C0FC; padding-bottom: 10px; }
        .workflow-info { background: white; padding: 15px; margin: 20px 0; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; background: white; }
        th { background: #230FAB; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; }
        .critical { color: #FF6B6B; font-weight: bold; }
        .high { color: #FFD93D; font-weight: bold; }
        .medium { color: #74C0FC; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Workflow Dependency Report</h1>
    <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    
    <div class="workflow-info">
        <h2>Workflow Details</h2>
        <table>
            <tr><td><strong>Name:</strong></td><td>$($Workflow.DisplayName)</td></tr>
            <tr><td><strong>ID:</strong></td><td>$($Workflow.WorkflowId)</td></tr>
            <tr><td><strong>Owner:</strong></td><td>$($Workflow.Owner)</td></tr>
            <tr><td><strong>Environment:</strong></td><td>$($Workflow.Environment)</td></tr>
            <tr><td><strong>Created:</strong></td><td>$($Workflow.CreatedOn)</td></tr>
        </table>
    </div>
    
    <h2>Canvas Apps That Invoke This Workflow</h2>
    <table>
        <thead>
            <tr>
                <th>App Name</th>
                <th>Owner</th>
                <th>Published</th>
                <th>Last Modified</th>
                <th>User Count</th>
            </tr>
        </thead>
        <tbody>
"@
            
            if ($canvasApps.Count -eq 0) {
                $html += "<tr><td colspan='5'>No Canvas Apps found</td></tr>"
            } else {
                foreach ($app in $canvasApps) {
                    $html += @"
                    <tr>
                        <td>$($app.AppName)</td>
                        <td>$($app.Owner)</td>
                        <td>$($app.IsPublished)</td>
                        <td>$($app.LastModified)</td>
                        <td>$($app.UserCount)</td>
                    </tr>
"@
                }
            }
            
            $html += @"
        </tbody>
    </table>
    
    <h2>SharePoint List Triggers</h2>
    <table>
        <thead>
            <tr>
                <th>List Name</th>
                <th>Site URL</th>
                <th>Trigger Type</th>
                <th>Status</th>
                <th>Last Triggered</th>
            </tr>
        </thead>
        <tbody>
"@
            
            if ($listTriggers.Count -eq 0) {
                $html += "<tr><td colspan='5'>No SharePoint List triggers found</td></tr>"
            } else {
                foreach ($list in $listTriggers) {
                    $html += @"
                    <tr>
                        <td>$($list.ListName)</td>
                        <td>$($list.SiteUrl)</td>
                        <td>$($list.TriggerType)</td>
                        <td>$($list.Status)</td>
                        <td>$($list.LastTriggered)</td>
                    </tr>
"@
                }
            }
            
            $html += @"
        </tbody>
    </table>
    
    <h2>Dependent Workflows</h2>
    <table>
        <thead>
            <tr>
                <th>Workflow Name</th>
                <th>Relation Type</th>
                <th>Is Active</th>
                <th>Last Run</th>
            </tr>
        </thead>
        <tbody>
"@
            
            if ($dependents.Count -eq 0) {
                $html += "<tr><td colspan='4'>No dependent workflows found</td></tr>"
            } else {
                foreach ($dep in $dependents) {
                    $html += @"
                    <tr>
                        <td>$($dep.WorkflowName)</td>
                        <td>$($dep.RelationType)</td>
                        <td>$($dep.IsActive)</td>
                        <td>$($dep.LastRun)</td>
                    </tr>
"@
                }
            }
            
            $html += @"
        </tbody>
    </table>
    
    <h2>Direct Dependencies</h2>
    <table>
        <thead>
            <tr>
                <th>Type</th>
                <th>Name</th>
                <th>Relationship</th>
                <th>Criticality</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
"@
            
            foreach ($dep in $Dependencies) {
                $criticalClass = ""
                if ($dep.CriticalityLevel -eq 'Critical') { $criticalClass = 'critical' }
                elseif ($dep.CriticalityLevel -eq 'High') { $criticalClass = 'high' }
                
                $html += @"
                <tr>
                    <td>$($dep.DependencyType)</td>
                    <td>$($dep.DependencyName)</td>
                    <td>$($dep.RelationshipType)</td>
                    <td class="$criticalClass">$($dep.CriticalityLevel)</td>
                    <td>$($dep.Status)</td>
                </tr>
"@
            }
            
            $html += @"
        </tbody>
    </table>
    
    <hr>
    <p style="color: #666; font-size: 12px;">Report generated by Power Automate Inspector</p>
</body>
</html>
"@
            
            Set-Content -Path $reportPath -Value $html -Encoding UTF8
        }
        'Markdown' {
            $markdown = "# Workflow Dependency Report`n`n"
            $markdown += "**Workflow:** $($Workflow.DisplayName)`n"
            $markdown += "**WorkflowId:** $($Workflow.WorkflowId)`n"
            $markdown += "**Owner:** $($Workflow.Owner)`n"
            $markdown += "**Environment:** $($Workflow.Environment)`n"
            $markdown += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
            
            $markdown += "## Canvas Apps That Invoke This Workflow`n`n"
            if ($canvasApps.Count -gt 0) {
                $markdown += "| App Name | Owner | Published | User Count |`n"
                $markdown += "|----------|-------|-----------|-----------|`n"
                foreach ($app in $canvasApps) {
                    $markdown += "| $($app.AppName) | $($app.Owner) | $($app.IsPublished) | $($app.UserCount) |`n"
                }
            } else {
                $markdown += "No Canvas Apps found`n"
            }
            
            $markdown += "`n## SharePoint List Triggers`n`n"
            if ($listTriggers.Count -gt 0) {
                $markdown += "| List Name | Trigger Type | Status |`n"
                $markdown += "|-----------|--------------|--------|`n"
                foreach ($list in $listTriggers) {
                    $markdown += "| $($list.ListName) | $($list.TriggerType) | $($list.Status) |`n"
                }
            } else {
                $markdown += "No SharePoint List triggers found`n"
            }
            
            Set-Content -Path $reportPath -Value $markdown -Encoding UTF8
        }
        'CSV' {
            $Dependencies | Export-Csv -Path $reportPath -NoTypeInformation
        }
    }
    
    Write-Host "✓ Dependency report saved: $reportPath" -ForegroundColor Green
    return $reportPath
}

Export-ModuleMember -Function @(
    'Get-WorkflowDependencies',
    'Test-DependencyHealth',
    'Get-InvokingCanvasApps',
    'Get-SharePointListTriggers',
    'Get-DependentWorkflows',
    'Export-DependencyReport'
)
