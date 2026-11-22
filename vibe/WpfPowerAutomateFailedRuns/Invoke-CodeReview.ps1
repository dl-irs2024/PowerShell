<#
.SYNOPSIS
    Code review and analysis tools for Power Automate workflows
    
.DESCRIPTION
    Analyzes workflows for best practices, re-entrancy, error handling,
    and potential issues that could cause failures.
    
.NOTES
    Author: Copilot
    Version: 1.0.0
#>

function Test-WorkflowReEntrancy {
    <#
    .SYNOPSIS
        Analyze workflow for re-entrancy issues
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Workflow
    )
    
    $findings = @()
    
    if ($Workflow.IsReEntrant) {
        $findings += [PSCustomObject]@{
            Severity = 'Info'
            Issue = 'Workflow is marked as re-entrant'
            Details = 'This workflow can be triggered while another instance is running'
            Recommendation = 'Ensure proper state management and avoid conflicts between concurrent runs'
        }
    } else {
        $findings += [PSCustomObject]@{
            Severity = 'Info'
            Issue = 'Workflow is not re-entrant'
            Details = 'Only one instance can run at a time'
            Recommendation = 'Consider enabling re-entrancy if parallel execution is required'
        }
    }
    
    return $findings
}

function Test-WorkflowErrorHandling {
    <#
    .SYNOPSIS
        Analyze workflow for error handling coverage
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Workflow
    )
    
    $findings = @()
    
    if ($Workflow.HasErrorHandling) {
        $findings += [PSCustomObject]@{
            Severity = 'Success'
            Issue = 'Error handling is implemented'
            Details = 'Workflow includes try-catch or error handling logic'
            Recommendation = 'Review error messages to ensure they are descriptive and actionable'
        }
    } else {
        $findings += [PSCustomObject]@{
            Severity = 'Warning'
            Issue = 'No error handling detected'
            Details = 'Workflow lacks explicit error handling logic'
            Recommendation = 'Add error handling steps to gracefully handle exceptions and provide meaningful feedback'
        }
    }
    
    return $findings
}

function Test-WorkflowOwnerStatus {
    <#
    .SYNOPSIS
        Check if workflow owner is still active
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Workflow
    )
    
    $findings = @()
    
    if ($Workflow.IsOwnerActive) {
        $findings += [PSCustomObject]@{
            Severity = 'Success'
            Issue = 'Owner is active'
            Details = "Owner: $($Workflow.Owner)"
            Recommendation = 'Owner is active and can support the workflow'
        }
    } else {
        $findings += [PSCustomObject]@{
            Severity = 'Error'
            Issue = 'Owner is no longer active'
            Details = "Owner: $($Workflow.Owner) is inactive or unavailable"
            Recommendation = 'Reassign workflow to an active owner or identify backup owner for maintenance'
        }
    }
    
    return $findings
}

function Test-WorkflowFailureRate {
    <#
    .SYNOPSIS
        Analyze workflow failure rate and trends
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Workflow
    )
    
    $findings = @()
    
    if ($Workflow.RunCount -eq 0) {
        $findings += [PSCustomObject]@{
            Severity = 'Info'
            Issue = 'Workflow has no runs'
            Details = 'Workflow has never been executed'
            Recommendation = 'Monitor the workflow on its first run to identify any issues'
        }
        return $findings
    }
    
    $failureRate = ($Workflow.FailureCount / $Workflow.RunCount) * 100
    
    if ($failureRate -eq 0) {
        $findings += [PSCustomObject]@{
            Severity = 'Success'
            Issue = 'Zero failure rate'
            Details = "$($Workflow.RunCount) runs with $($Workflow.FailureCount) failures"
            Recommendation = 'Workflow is performing well'
        }
    } elseif ($failureRate -lt 5) {
        $findings += [PSCustomObject]@{
            Severity = 'Info'
            Issue = 'Low failure rate'
            Details = "$failureRate% failure rate ($($Workflow.FailureCount) failures in $($Workflow.RunCount) runs)"
            Recommendation = 'Monitor for patterns in failures and address root causes'
        }
    } elseif ($failureRate -lt 20) {
        $findings += [PSCustomObject]@{
            Severity = 'Warning'
            Issue = 'Moderate failure rate'
            Details = "$failureRate% failure rate ($($Workflow.FailureCount) failures in $($Workflow.RunCount) runs)"
            Recommendation = 'Investigate recent failures and implement improvements'
        }
    } else {
        $findings += [PSCustomObject]@{
            Severity = 'Error'
            Issue = 'High failure rate'
            Details = "$failureRate% failure rate ($($Workflow.FailureCount) failures in $($Workflow.RunCount) runs)"
            Recommendation = 'Urgent: Review workflow logic and troubleshoot recurring issues'
        }
    }
    
    return $findings
}

function Test-WorkflowAging {
    <#
    .SYNOPSIS
        Check if workflow is becoming outdated
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Workflow
    )
    
    $findings = @()
    
    $daysSinceModified = (Get-Date) - $Workflow.LastModified
    
    if ($daysSinceModified.Days -lt 30) {
        $findings += [PSCustomObject]@{
            Severity = 'Info'
            Issue = 'Workflow is recently updated'
            Details = "Last modified: $($Workflow.LastModified)"
            Recommendation = 'Monitor for any new issues introduced by recent changes'
        }
    } elseif ($daysSinceModified.Days -lt 90) {
        $findings += [PSCustomObject]@{
            Severity = 'Info'
            Issue = 'Workflow is moderately aged'
            Details = "Last modified $($daysSinceModified.Days) days ago"
            Recommendation = 'Review for compatibility with current service versions'
        }
    } elseif ($daysSinceModified.Days -lt 180) {
        $findings += [PSCustomObject]@{
            Severity = 'Warning'
            Issue = 'Workflow is becoming aged'
            Details = "Last modified $($daysSinceModified.Days) days ago"
            Recommendation = 'Consider reviewing and updating the workflow to current standards'
        }
    } else {
        $findings += [PSCustomObject]@{
            Severity = 'Warning'
            Issue = 'Workflow is significantly aged'
            Details = "Last modified $($daysSinceModified.Days) days ago on $($Workflow.LastModified)"
            Recommendation = 'Schedule a review and update to current connector versions and best practices'
        }
    }
    
    return $findings
}

function Invoke-WorkflowCodeReview {
    <#
    .SYNOPSIS
        Perform comprehensive code review of a workflow
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Workflows,
        
        [ValidateSet('Full', 'Quick', 'OnFailures')]
        [string]$ReviewType = 'Full'
    )
    
    $allFindings = @()
    
    foreach ($workflow in $Workflows) {
        Write-Host "Reviewing workflow: $($workflow.DisplayName)" -ForegroundColor Cyan
        
        # Always run these checks
        $findings = @()
        $findings += Test-WorkflowOwnerStatus -Workflow $workflow
        $findings += Test-WorkflowErrorHandling -Workflow $workflow
        $findings += Test-WorkflowReEntrancy -Workflow $workflow
        $findings += Test-WorkflowFailureRate -Workflow $workflow
        
        if ($ReviewType -eq 'Full') {
            $findings += Test-WorkflowAging -Workflow $workflow
        } elseif ($ReviewType -eq 'OnFailures') {
            $findings = $findings | Where-Object { $_.Severity -eq 'Error' -or $_.Severity -eq 'Warning' }
        }
        
        foreach ($finding in $findings) {
            $allFindings += [PSCustomObject]@{
                WorkflowName = $workflow.DisplayName
                WorkflowId = $workflow.WorkflowId
                Severity = $finding.Severity
                Issue = $finding.Issue
                Details = $finding.Details
                Recommendation = $finding.Recommendation
            }
        }
    }
    
    return $allFindings
}

function Export-CodeReviewReport {
    <#
    .SYNOPSIS
        Export code review findings to various formats
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Findings,
        
        [ValidateSet('CSV', 'HTML', 'Markdown')]
        [string]$Format = 'HTML',
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportPath = $OutputPath -replace '\.[^.]*$', "_$timestamp.$Format"
    
    switch ($Format) {
        'CSV' {
            $Findings | Export-Csv -Path $reportPath -NoTypeInformation
        }
        'HTML' {
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Power Automate Code Review Report</title>
    <style>
        body { font-family: Segoe UI, sans-serif; margin: 20px; background-color: #f8f9fa; }
        h1 { color: #230FAB; border-bottom: 3px solid #230FAB; }
        .summary { background: white; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .finding { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .severity-error { border-left: 5px solid #FF6B6B; background: #fff5f5; }
        .severity-warning { border-left: 5px solid #FFD93D; background: #fffbf0; }
        .severity-info { border-left: 5px solid #74C0FC; background: #f0f8ff; }
        .severity-success { border-left: 5px solid #51CF66; background: #f0fdf4; }
        .label { font-weight: bold; margin-top: 10px; }
        .workflow { font-size: 14px; font-weight: bold; color: #230FAB; margin: 20px 0 10px 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #230FAB; color: white; padding: 10px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
    </style>
</head>
<body>
    <h1>Power Automate Code Review Report</h1>
    <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
"@
            
            # Summary statistics
            $errorCount = $Findings | Where-Object { $_.Severity -eq 'Error' } | Measure-Object | Select-Object -ExpandProperty Count
            $warningCount = $Findings | Where-Object { $_.Severity -eq 'Warning' } | Measure-Object | Select-Object -ExpandProperty Count
            $infoCount = $Findings | Where-Object { $_.Severity -eq 'Info' } | Measure-Object | Select-Object -ExpandProperty Count
            $successCount = $Findings | Where-Object { $_.Severity -eq 'Success' } | Measure-Object | Select-Object -ExpandProperty Count
            
            $html += @"
    <div class="summary">
        <h2>Summary</h2>
        <table>
            <tr>
                <td><strong>Critical Issues:</strong></td><td style="color: #FF6B6B;">$errorCount</td>
                <td><strong>Warnings:</strong></td><td style="color: #FFD93D;">$warningCount</td>
                <td><strong>Info:</strong></td><td style="color: #74C0FC;">$infoCount</td>
                <td><strong>Success:</strong></td><td style="color: #51CF66;">$successCount</td>
            </tr>
        </table>
    </div>
"@
            
            # Group findings by workflow
            $groupedFindings = $Findings | Group-Object -Property WorkflowName
            
            foreach ($group in $groupedFindings) {
                $html += "<div class='workflow'>$($group.Name)</div>"
                
                foreach ($finding in $group.Group) {
                    $severityClass = "severity-$($finding.Severity.ToLower())"
                    $html += @"
                    <div class="finding $severityClass">
                        <strong>$($finding.Severity.ToUpper())</strong>: $($finding.Issue)<br>
                        <div class="label">Details:</div>
                        $($finding.Details)<br>
                        <div class="label">Recommendation:</div>
                        $($finding.Recommendation)
                    </div>
"@
                }
            }
            
            $html += @"
    <hr>
    <p style="color: #666; font-size: 12px;">Report generated by Power Automate Inspector</p>
</body>
</html>
"@
            
            Set-Content -Path $reportPath -Value $html -Encoding UTF8
        }
        'Markdown' {
            $markdown = "# Power Automate Code Review Report`n`n"
            $markdown += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
            
            # Summary
            $errorCount = $Findings | Where-Object { $_.Severity -eq 'Error' } | Measure-Object | Select-Object -ExpandProperty Count
            $warningCount = $Findings | Where-Object { $_.Severity -eq 'Warning' } | Measure-Object | Select-Object -ExpandProperty Count
            
            $markdown += "## Summary`n"
            $markdown += "- **Critical Issues:** $errorCount`n"
            $markdown += "- **Warnings:** $warningCount`n`n"
            
            # Group findings by workflow
            $groupedFindings = $Findings | Group-Object -Property WorkflowName
            
            foreach ($group in $groupedFindings) {
                $markdown += "## $($group.Name)`n`n"
                
                foreach ($finding in $group.Group) {
                    $markdown += "### $($finding.Severity): $($finding.Issue)`n`n"
                    $markdown += "**Details:** $($finding.Details)`n`n"
                    $markdown += "**Recommendation:** $($finding.Recommendation)`n`n"
                }
            }
            
            Set-Content -Path $reportPath -Value $markdown -Encoding UTF8
        }
    }
    
    Write-Host "✓ Code review report saved: $reportPath" -ForegroundColor Green
    return $reportPath
}

Export-ModuleMember -Function @(
    'Test-WorkflowReEntrancy',
    'Test-WorkflowErrorHandling',
    'Test-WorkflowOwnerStatus',
    'Test-WorkflowFailureRate',
    'Test-WorkflowAging',
    'Invoke-WorkflowCodeReview',
    'Export-CodeReviewReport'
)
