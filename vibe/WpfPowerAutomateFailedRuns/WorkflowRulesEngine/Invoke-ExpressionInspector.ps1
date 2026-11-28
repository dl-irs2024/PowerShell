<#
.SYNOPSIS  Lists every WDL expression / dynamic-content segment in a workflow, with parse issues.
.EXAMPLE   .\Invoke-ExpressionInspector.ps1 -Path .\Samples\Problem\08-expression-defects.json
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path, [switch]$IssuesOnly)
Import-Module (Join-Path $PSScriptRoot 'RulesEngine.psm1') -Force
$wf = Import-Workflow -Path $Path
$map = @(Get-WdlExpressionMap -Workflow $wf)
if ($IssuesOnly) { $map = @($map | Where-Object { $_.IssueCount }) }
$map
