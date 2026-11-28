<#
.SYNOPSIS  Command-line Workflow Rules Engine for Power Automate / Agent Flows / Logic Apps JSON.
.EXAMPLE   .\Invoke-WorkflowRules.ps1 -Path .\Samples\Problem\01-nested-loops.json -Format Html,Json -OutDir .\Reports
.EXAMPLE   .\Invoke-WorkflowRules.ps1 -Url https://example.com/flow.json -FailOn High
.EXAMPLE   Get-Content flow.json -Raw | .\Invoke-WorkflowRules.ps1 -Stdin
.EXAMPLE   .\Invoke-WorkflowRules.ps1 -ListRules -Editor LogicApps
#>
[CmdletBinding()]
param(
    [string]$Path,                 # file, folder, URL or raw JSON text
    [string]$Url,
    [string]$Token,                # bearer token for -Url
    [string]$Json,
    [switch]$Stdin,
    [string]$RulesPath,
    [string]$Editor,
    [string[]]$Category,
    [string[]]$RuleId,
    [ValidateSet('Info', 'Warning', 'High', 'Critical')][string]$MinSeverity,
    [string[]]$Suppress,
    [ValidateSet('Json', 'Csv', 'Markdown', 'Html', 'Excel', 'Word', 'Pdf')][string[]]$Format,
    [string]$OutDir,
    [ValidateSet('None', 'Info', 'Warning', 'High', 'Critical')][string]$FailOn = 'None',
    [switch]$ListRules,
    [switch]$ValidateCatalog,
    [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RulesEngine.psm1') -Force

$catalog = Get-RuleCatalog -RulesPath $RulesPath

if ($ListRules) {
    $rules = @($catalog.Rules)
    if ($Editor) { $rules = @($rules | Where-Object { $_.editors -contains $Editor }) }
    if ($Category) { $rules = @($rules | Where-Object { @($_.categories | Where-Object { $Category -contains $_ }).Count }) }
    $rules | ForEach-Object {
        [pscustomobject]@{ RuleId = $_.ruleId; Severity = $_.severity; Enabled = $_.enabled
            Editors = ($_.editors -join ','); Categories = ($_.categories -join ','); Impl = (Get-RuleImplementation -Rule $_); Name = $_.name }
    } | Format-Table -AutoSize | Out-String -Width 250 | Write-Host
    return
}
if ($ValidateCatalog) {
    $bad = 0
    foreach ($r in $catalog.Rules) {
        $e = @(Test-RuleDefinition -Rule $r)
        if ($e.Count) { $bad++; Write-Host "$($r.ruleId): $($e -join '; ')" -ForegroundColor Red }
    }
    Write-Host ("{0} rules, {1} invalid" -f @($catalog.Rules).Count, $bad)
    if ($bad) { exit 2 } else { return }
}

$imp = @{}
if ($Stdin) { $imp.Json = ([Console]::In.ReadToEnd()) }
elseif ($Json) { $imp.Json = $Json }
elseif ($Url) { $imp.Url = $Url; if ($Token) { $imp.Token = $Token } }
elseif ($Path) { $imp.Path = $Path }
else { throw 'Specify -Path, -Url, -Json or -Stdin (or -ListRules / -ValidateCatalog).' }

$wf = Import-Workflow @imp
$eval = @{ Workflow = $wf; Catalog = $catalog }
foreach ($k in 'Editor', 'Category', 'RuleId', 'MinSeverity', 'Suppress') { if ((Get-Variable $k).Value) { $eval[$k] = (Get-Variable $k).Value } }
$report = Invoke-WorkflowRules @eval

$s = $report.summary
Write-Host ("{0}  {1}  editor={2}" -f $report.reportId, $report.workflow.name, $report.workflow.editor)
Write-Host ("Health {0}/100  Risk {1}  Findings {2} (Critical {3}, High {4}, Warning {5}, Info {6})  Not evaluated {7}" -f `
        $s.healthScore, $s.overallRisk, $s.findingCount, $s.bySeverity.Critical, $s.bySeverity.High, $s.bySeverity.Warning, $s.bySeverity.Info, @($report.notEvaluated).Count)
foreach ($f in $report.findings) {
    $c = switch ($f.severity) { 'Critical' { 'Red' } 'High' { 'Yellow' } 'Warning' { 'DarkYellow' } default { 'Gray' } }
    Write-Host ("  [{0}] {1} {2} - {3}" -f $f.severity, $f.ruleId, $f.path, $f.message) -ForegroundColor $c
}
if ($Format) {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot 'Reports' }
    foreach ($fmt in $Format) {
        try { Write-Host ('Wrote ' + (Export-RulesReport -Report $report -Format $fmt -OutDir $OutDir)) }
        catch { Write-Warning "$fmt : $($_.Exception.Message)" }
    }
}
if ($PassThru) { $report }
if ($FailOn -ne 'None') {
    $order = @{ Info = 1; Warning = 2; High = 3; Critical = 4 }
    if (@($report.findings | Where-Object { $order[$_.severity] -ge $order[$FailOn] }).Count) { exit 1 }
}
