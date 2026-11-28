# Report renderers. JSON is the master format; HTML / Markdown / CSV are derived. Excel / Word / PDF are registered stubs.
# Add a format with: Register-ReportRenderer -Format Xlsx -Extension .xlsx -Script { param($Report, $Path) ... }

function ConvertTo-HtmlText { param($Text) [System.Net.WebUtility]::HtmlEncode([string]$Text) }
function ConvertTo-MdCell { param($Text) ([string]$Text -replace '\|', '/' -replace "\r?\n", ' ') }

Register-ReportRenderer -Format Json -Extension '.json' -Script {
    param($Report, $Path)
    Write-TextFile -Path $Path -Text ($Report | ConvertTo-Json -Depth 30)
}

Register-ReportRenderer -Format Csv -Extension '.csv' -Script {
    param($Report, $Path)
    $rows = foreach ($f in $Report.findings) {
        [pscustomobject]@{
            ReportId = $Report.reportId; Workflow = $Report.workflow.name; Editor = $Report.workflow.editor; FindingId = $f.findingId; RuleId = $f.ruleId; Severity = $f.severity
            RiskScore = $f.riskScore; RiskGrade = $f.riskGrade; Categories = ($f.categories -join '; '); Action = $f.action; Message = $f.message; Evidence = $f.evidence
            Remediation = ($f.remediation -join ' | ')
        }
    }
    if (-not $rows) { $rows = [pscustomobject]@{ ReportId = $Report.reportId; Workflow = $Report.workflow.name; Editor = $Report.workflow.editor; FindingId = ''; RuleId = ''; Severity = ''; RiskScore = ''; RiskGrade = ''; Categories = ''; Action = ''; Message = 'No findings'; Evidence = ''; Remediation = '' } }
    $rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

Register-ReportRenderer -Format Markdown -Extension '.md' -Script {
    param($Report, $Path)
    $w = $Report.workflow; $s = $Report.summary
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Workflow Rules Report $($Report.reportId)"); [void]$sb.AppendLine()
    [void]$sb.AppendLine("| | |"); [void]$sb.AppendLine("|---|---|")
    [void]$sb.AppendLine("| Workflow | $(ConvertTo-MdCell $w.name) |")
    [void]$sb.AppendLine("| Flow ID | $(ConvertTo-MdCell $w.id) |")
    [void]$sb.AppendLine("| Editor | $($w.editor) |")
    [void]$sb.AppendLine("| Source | $(ConvertTo-MdCell $w.source) |")
    [void]$sb.AppendLine("| Definition hash | ``$($w.definitionHash)`` |")
    [void]$sb.AppendLine("| Trigger | $(ConvertTo-MdCell $w.trigger) |")
    [void]$sb.AppendLine("| Generated | $($Report.generated) |")
    [void]$sb.AppendLine("| Catalog | v$($Report.catalog.version) - $($Report.catalog.evaluated) of $($Report.catalog.ruleCount) rules evaluated |")
    [void]$sb.AppendLine("| Overall risk | **$($s.overallRisk)** (health $($s.healthScore)/100) |")
    [void]$sb.AppendLine("| Findings | $($s.bySeverity.Critical) critical, $($s.bySeverity.High) high, $($s.bySeverity.Warning) warning, $($s.bySeverity.Info) info |")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Findings'); [void]$sb.AppendLine()
    if (-not $Report.findings.Count) { [void]$sb.AppendLine('No findings.') }
    else {
        [void]$sb.AppendLine('| Severity | Rule | Action | Message | Remediation |'); [void]$sb.AppendLine('|---|---|---|---|---|')
        foreach ($f in $Report.findings) { [void]$sb.AppendLine("| $($f.severity) | $($f.ruleId) | $(ConvertTo-MdCell $f.action) | $(ConvertTo-MdCell $f.message) | $(ConvertTo-MdCell ($f.remediation -join ' ')) |") }
    }
    [void]$sb.AppendLine(); [void]$sb.AppendLine('## Category scores'); [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Category | Findings | Health |'); [void]$sb.AppendLine('|---|---|---|')
    foreach ($c in $s.byCategory.PSObject.Properties) { [void]$sb.AppendLine("| $($c.Name) | $($c.Value.findings) | $($c.Value.healthScore) |") }
    if ($Report.suppressions.Count) {
        [void]$sb.AppendLine(); [void]$sb.AppendLine('## Suppressions'); [void]$sb.AppendLine()
        foreach ($x in $Report.suppressions) { [void]$sb.AppendLine("- $($x.ruleId) on $($x.action): $($x.reason)") }
    }
    [void]$sb.AppendLine(); [void]$sb.AppendLine('## Rules not evaluated'); [void]$sb.AppendLine()
    foreach ($x in $Report.notEvaluated) { [void]$sb.AppendLine("- $($x.ruleId) $($x.name) - $($x.reason)") }
    Write-TextFile -Path $Path -Text $sb.ToString()
}

Register-ReportRenderer -Format Html -Extension '.html' -Script {
    param($Report, $Path)
    $w = $Report.workflow; $s = $Report.summary
    $e = { param($t) ConvertTo-HtmlText $t }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!DOCTYPE html><html><head><meta charset="utf-8"><title>' + (& $e $Report.reportId) + '</title><style>')
    [void]$sb.AppendLine('body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#222}h1{font-size:22px}h2{font-size:17px;border-bottom:1px solid #ccc;padding-bottom:4px;margin-top:28px}')
    [void]$sb.AppendLine('table{border-collapse:collapse;width:100%}td,th{border:1px solid #d0d0d0;padding:5px 8px;vertical-align:top;font-size:13px}th{background:#eef1f6;text-align:left}')
    [void]$sb.AppendLine('tr:nth-child(even) td{background:#fafbfd}.Critical{background:#f8c9c9!important}.High{background:#fde0e0!important}.Warning{background:#fff0cc!important}.Info{background:#e8f0ff!important}')
    [void]$sb.AppendLine('.meta td:first-child{width:170px;font-weight:600;background:#f4f4f4}.bar{display:inline-block;height:10px;background:#4a90d9}code{background:#f0f0f0;padding:1px 4px}.chip{display:inline-block;background:#e8eef9;border-radius:9px;padding:0 7px;margin:1px;font-size:11px}')
    [void]$sb.AppendLine('</style></head><body>')
    [void]$sb.AppendLine("<h1>Workflow Rules Report <code>$(& $e $Report.reportId)</code></h1>")
    [void]$sb.AppendLine('<table class="meta">')
    foreach ($row in @(
            @('Workflow', $w.name), @('Flow ID', $w.id), @('Editor', $w.editor), @('Source', $w.source), @('Definition hash', $w.definitionHash), @('Trigger', $w.trigger),
            @('Generated', $Report.generated), @('Catalog', "v$($Report.catalog.version) - $($Report.catalog.evaluated) of $($Report.catalog.ruleCount) rules evaluated"),
            @('Overall risk', "$($s.overallRisk) (health $($s.healthScore)/100)"),
            @('Findings', "$($s.bySeverity.Critical) critical, $($s.bySeverity.High) high, $($s.bySeverity.Warning) warning, $($s.bySeverity.Info) info"))) {
        [void]$sb.AppendLine("<tr><td>$(& $e $row[0])</td><td>$(& $e $row[1])</td></tr>")
    }
    [void]$sb.AppendLine('</table><h2>Findings</h2>')
    if (-not $Report.findings.Count) { [void]$sb.AppendLine('<p>No findings.</p>') }
    else {
        [void]$sb.AppendLine('<table><tr><th>Severity</th><th>Rule</th><th>Risk</th><th>Action</th><th>Message</th><th>Categories</th><th>Remediation</th></tr>')
        foreach ($f in $Report.findings) {
            $chips = ($f.categories | ForEach-Object { "<span class='chip'>$(& $e $_)</span>" }) -join ''
            $rem = '<ul>' + (($f.remediation | ForEach-Object { "<li>$(& $e $_)</li>" }) -join '') + '</ul>'
            $ev = if ($f.evidence) { "<br><small>Evidence: <code>$(& $e $f.evidence)</code></small>" } else { '' }
            [void]$sb.AppendLine("<tr><td class='$($f.severity)'>$($f.severity)</td><td><b>$(& $e $f.ruleId)</b><br>$(& $e $f.name)</td><td>$($f.riskScore) $(& $e $f.riskGrade)</td><td>$(& $e $f.action)</td><td>$(& $e $f.message)$ev</td><td>$chips</td><td>$rem</td></tr>")
        }
        [void]$sb.AppendLine('</table>')
    }
    [void]$sb.AppendLine('<h2>Category scores</h2><table><tr><th>Category</th><th>Findings</th><th>Health</th></tr>')
    foreach ($c in $s.byCategory.PSObject.Properties) { [void]$sb.AppendLine("<tr><td>$(& $e $c.Name)</td><td>$($c.Value.findings)</td><td><span class='bar' style='width:$([int]$c.Value.healthScore)px'></span> $($c.Value.healthScore)</td></tr>") }
    [void]$sb.AppendLine('</table>')
    if ($Report.suppressions.Count) {
        [void]$sb.AppendLine('<h2>Suppressions</h2><ul>')
        foreach ($x in $Report.suppressions) { [void]$sb.AppendLine("<li>$(& $e $x.ruleId) on $(& $e $x.action): $(& $e $x.reason)</li>") }
        [void]$sb.AppendLine('</ul>')
    }
    [void]$sb.AppendLine('<h2>Rules not evaluated</h2><ul>')
    foreach ($x in $Report.notEvaluated) { [void]$sb.AppendLine("<li><b>$(& $e $x.ruleId)</b> $(& $e $x.name) - $(& $e $x.reason)</li>") }
    [void]$sb.AppendLine('</ul></body></html>')
    Write-TextFile -Path $Path -Text $sb.ToString()
}

foreach ($stub in @(@('Excel', '.xlsx'), @('Word', '.docx'), @('Pdf', '.pdf'))) {
    $fmt = $stub[0]
    Register-ReportRenderer -Format $fmt -Extension $stub[1] -Implemented $false -Script ({ param($Report, $Path) throw "The $fmt renderer is not implemented yet. Export Json or Html and convert, or register a renderer with Register-ReportRenderer." }.GetNewClosure())
}
