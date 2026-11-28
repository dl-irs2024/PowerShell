# RulesEngine - command-line rules engine for Power Automate / Agent Flow / Azure Logic Apps workflow JSON.
# Rules are data (Rules\*.json, schema from the Workflow Inspector Word document); detectors are code (Detectors\*.ps1).
# Works on Windows PowerShell 5.1 and PowerShell 7.
#   Import-Module .\RulesEngine.psm1
#   Import-Workflow .\flow.json | Invoke-WorkflowRules | Export-RulesReport -Format Html,Json -OutDir .\Reports
Set-StrictMode -Off

$Script:EngineRoot = $PSScriptRoot
$Script:EngineVersion = '1.0.0'
$Script:LogicTable = @{}
$Script:Renderers = @{}
$Script:SeverityRank = @{ Info = 0; Warning = 1; High = 2; Critical = 3 }
$Script:DefaultImpact = @{ Info = @(2, 1); Warning = @(3, 3); High = @(4, 3); Critical = @(4, 5) }   # likelihood, impact
$Script:AppliesToTaxonomy = @('Flow', 'Trigger', 'Action', 'Condition', 'Loop', 'Scope', 'Connector', 'Connection', 'Expression', 'ErrorHandling', 'Run', 'Runtime', 'Environment', 'Solution', 'DataSource')
$Script:InspectionModes = @('Static', 'Hybrid', 'Runtime', 'Metadata')

#region Extensibility registries
function Register-RuleLogic {
<#
.SYNOPSIS Registers a detector implementation. A rule selects it with detector.logic = <Name>.
 The scriptblock receives ($Rule, $Model, $Detector) and returns hits made with New-RuleHit.
#>
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Script, [string]$Description = '')
    $Script:LogicTable[$Name] = [pscustomobject]@{ Name = $Name; Script = $Script; Description = $Description }
}

function Get-RuleLogic { param([string]$Name) if ($Name) { $Script:LogicTable[$Name] } else { $Script:LogicTable.Values | Sort-Object Name } }

function Register-ReportRenderer {
    param([Parameter(Mandatory)][string]$Format, [Parameter(Mandatory)][string]$Extension, [Parameter(Mandatory)][scriptblock]$Script, [bool]$Implemented = $true)
    $Script:Renderers[$Format] = [pscustomobject]@{ Format = $Format; Extension = $Extension; Script = $Script; Implemented = $Implemented }
}

function Get-ReportRenderer { param([string]$Format) if ($Format) { $Script:Renderers[$Format] } else { $Script:Renderers.Values | Sort-Object Format } }

function New-RuleHit {
    param($Node, [string]$Message, [string]$Evidence, [string]$Path)
    $p = $Path
    if (-not $p -and $Node) { $p = $Node.Path }
    [pscustomobject]@{ Action = $(if ($Node) { $Node.Name } else { '' }); Path = $p; Message = $Message; Evidence = $Evidence }
}

function Get-DetectorParam {
    param($Detector, [string]$Name, $Default)
    if ($Detector -and $Detector.PSObject.Properties['params'] -and $Detector.params -and $Detector.params.PSObject.Properties[$Name]) { return $Detector.params.$Name }
    $Default
}
#endregion

#region JSON helpers
function Get-Prop {
    param($Object, [string]$Name)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    $null
}

function Get-JsonStrings {
    # Flattens every string value with its JSON path. $SkipKeys are not descended (child action containers).
    param($Value, [string]$Path = '', [string[]]$SkipKeys = @(), [System.Collections.ArrayList]$Into)
    if ($null -eq $Into) { $Into = New-Object System.Collections.ArrayList }
    if ($Value -is [string]) { [void]$Into.Add([pscustomobject]@{ Path = $Path; Value = $Value }) }
    elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $i = 0
        foreach ($v in $Value) { [void](Get-JsonStrings -Value $v -Path "$Path[$i]" -SkipKeys $SkipKeys -Into $Into); $i++ }
    } elseif ($Value -is [pscustomobject]) {
        foreach ($p in $Value.PSObject.Properties) {
            if ($SkipKeys -contains $p.Name) { continue }
            $child = if ($Path) { "$Path.$($p.Name)" } else { $p.Name }
            [void](Get-JsonStrings -Value $p.Value -Path $child -SkipKeys $SkipKeys -Into $Into)
        }
    }
    $Into
}

function ConvertTo-JsonText { param($Object, [int]$Depth = 50) $Object | ConvertTo-Json -Depth $Depth }

function ConvertTo-Seconds {
    param([double]$Count, [string]$Unit)
    switch -Regex ($Unit) {
        '^Second' { return $Count }
        '^Minute' { return $Count * 60 }
        '^Hour' { return $Count * 3600 }
        '^Day' { return $Count * 86400 }
        '^Week' { return $Count * 604800 }
        '^Month' { return $Count * 2592000 }
        default { return $Count }
    }
}

function ConvertFrom-IsoDuration {
    param([string]$Duration)
    if ($Duration -match '^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$') {
        return ([int]('0' + $Matches[1]) * 86400 + [int]('0' + $Matches[2]) * 3600 + [int]('0' + $Matches[3]) * 60 + [int]('0' + $Matches[4]))
    }
    $null
}

function Format-Seconds {
    param([double]$Seconds)
    if ($Seconds -ge 86400) { return ('{0:N1} days' -f ($Seconds / 86400)) }
    if ($Seconds -ge 3600) { return ('{0:N1} hours' -f ($Seconds / 3600)) }
    if ($Seconds -ge 60) { return ('{0:N0} min' -f ($Seconds / 60)) }
    '{0:N0} sec' -f $Seconds
}
#endregion

#region Import (path / URL / raw JSON / stream / object / zip)
function Read-WorkflowText {
    param([string]$Text)
    $Text = $Text.TrimStart([char]0xFEFF)
    try { $Text | ConvertFrom-Json } catch { throw "Input is not valid JSON: $($_.Exception.Message)" }
}

function Get-WorkflowRoots {
    # Returns one or more @{ Root; Source } from a path (json/zip), URL, JSON text, stream or object.
    param([string]$Path, [string]$Url, [string]$Token, [string]$Json, [System.IO.Stream]$Stream, $InputObject, [string]$Name, [int]$MaxBytes)
    $out = @()
    if ($Url) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $headers = @{}
        if ($Token) { $headers['Authorization'] = "Bearer $Token" }
        $resp = Invoke-WebRequest -Uri $Url -Headers $headers -UseBasicParsing -ErrorAction Stop
        $content = $resp.Content
        if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
        if ($content.Length -gt $MaxBytes) { throw "Remote content exceeds the $MaxBytes byte limit." }
        return @(@{ Root = (Read-WorkflowText $content); Source = $Url })
    }
    if ($Stream) {
        $reader = New-Object System.IO.StreamReader($Stream, [Text.Encoding]::UTF8)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        return @(@{ Root = (Read-WorkflowText $text); Source = $(if ($Name) { $Name } else { 'stream' }) })
    }
    if ($Json) { return @(@{ Root = (Read-WorkflowText $Json); Source = $(if ($Name) { $Name } else { 'json-text' }) }) }
    if ($null -ne $InputObject) {
        $o = $InputObject
        if ($o -is [string]) { $o = Read-WorkflowText $o }
        return @(@{ Root = $o; Source = $(if ($Name) { $Name } else { 'object' }) })
    }
    if ($Path -match '^(?i)https?://') { return Get-WorkflowRoots -Url $Path -Token $Token -MaxBytes $MaxBytes }
    if ($Path -match '^\s*[\{\[]') { return Get-WorkflowRoots -Json $Path -Name $Name -MaxBytes $MaxBytes }
    if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -gt $MaxBytes) { throw "File exceeds the $MaxBytes byte limit: $Path" }
    if ($file.Extension -eq '.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($file.FullName)
        try {
            $entries = @($zip.Entries | Where-Object { $_.FullName -match '(?i)(^|/)definition\.json$' })
            if (-not $entries) { $entries = @($zip.Entries | Where-Object { $_.FullName -match '(?i)(^|/)workflows/[^/]+(\.json)?$' -and $_.Length -gt 0 }) }
            if (-not $entries) { throw "No definition.json or Workflows\*.json found inside $Path" }
            foreach ($e in $entries) {
                $sr = New-Object System.IO.StreamReader($e.Open(), [Text.Encoding]::UTF8)
                try { $t = $sr.ReadToEnd() } finally { $sr.Dispose() }
                $out += @{ Root = (Read-WorkflowText $t); Source = "$($file.FullName)!$($e.FullName)" }
            }
        } finally { $zip.Dispose() }
        return $out
    }
    @(@{ Root = (Read-WorkflowText (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)); Source = $file.FullName })
}

function Import-Workflow {
<#
.SYNOPSIS Loads a workflow from a local path (.json/.zip), http(s) URL, raw JSON text, a stream, or an in-memory object and normalizes it.
.EXAMPLE Import-Workflow .\flow.json
.EXAMPLE Import-Workflow -Url https://raw.githubusercontent.com/org/repo/main/flow.json
.EXAMPLE Get-Content flow.json -Raw | Import-Workflow -Json { $_ }
#>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ParameterSetName = 'Path', Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('FullName')][string]$Path,
        [Parameter(ParameterSetName = 'Url', Mandatory)][string]$Url,
        [Parameter(ParameterSetName = 'Url')][string]$Token,
        [Parameter(ParameterSetName = 'Json', Mandatory)][string]$Json,
        [Parameter(ParameterSetName = 'Stream', Mandatory)][System.IO.Stream]$Stream,
        [Parameter(ParameterSetName = 'Object', Mandatory)]$InputObject,
        [string]$Name,
        [string]$Editor,
        [int]$MaxBytes = 20MB
    )
    process {
        $roots = Get-WorkflowRoots -Path $Path -Url $Url -Token $Token -Json $Json -Stream $Stream -InputObject $InputObject -Name $Name -MaxBytes $MaxBytes
        foreach ($r in $roots) { ConvertTo-WorkflowModel -Root $r.Root -Source $r.Source -Editor $Editor }
    }
}

function Get-WorkflowEditor {
    param($Root, $Definition, $Props, [object[]]$Nodes)
    $arm = $Root -and ($Root.PSObject.Properties['resources'])
    if ($arm) { return 'LogicApps' }
    $kind = [string](Get-Prop $Root 'kind')
    if ($kind -match '^(Stateful|Stateless|Agent)$') { if ($kind -eq 'Agent') { return 'AgentFlows' } return 'LogicApps' }
    foreach ($n in $Nodes) {
        if ($n.Kind -eq 'Trigger' -and ([string]$n.Def.kind -match '^(Skills|Agent|Copilot)')) { return 'AgentFlows' }
    }
    if ([string](Get-Prop $Props 'flowType') -match 'agent') { return 'AgentFlows' }
    if ((Get-Prop $Props 'connectionReferences') -or ([string](Get-Prop $Props 'apiId') -match 'logicflows') -or ($Nodes | Where-Object { $_.Type -like 'OpenApiConnection*' })) { return 'PowerAutomate' }
    if ($Nodes | Where-Object { $_.Type -like 'ApiConnection*' -or $_.Type -eq 'ServiceProvider' }) { return 'LogicApps' }
    'Unknown'
}

function ConvertTo-WorkflowModel {
    [CmdletBinding()]
    param($Root, [string]$Source, [string]$Editor)
    $props = Get-Prop $Root 'properties'
    if (-not $props) { $props = Get-Prop (Get-Prop $Root 'Internal') 'properties' }
    $wdl = $null; $armName = $null
    $res = Get-Prop $Root 'resources'
    if ($res) {
        $wf = @($res) | Where-Object { [string]$_.type -match 'Microsoft\.Logic/workflows' } | Select-Object -First 1
        if ($wf) { $wdl = $wf.properties.definition; $props = $wf.properties; $armName = [string]$wf.name }
    }
    if (-not $wdl) { $wdl = Get-Prop $props 'definition' }
    if (-not $wdl) { $wdl = Get-Prop $Root 'definition' }
    if (-not $wdl -and ((Get-Prop $Root 'actions') -or (Get-Prop $Root 'triggers'))) { $wdl = $Root }
    if (-not $wdl) { throw "No workflow definition (triggers/actions) found in $Source" }

    $display = Get-Prop $props 'displayName'
    if (-not $display) { $display = Get-Prop $Root 'DisplayName' }
    if (-not $display) { $display = Get-Prop $Root 'displayName' }
    if (-not $display) { $display = $armName }
    if (-not $display) { $display = [IO.Path]::GetFileNameWithoutExtension(($Source -split '!')[-1]) }
    $flowId = Get-Prop $Root 'name'; if (-not $flowId) { $flowId = Get-Prop $Root 'FlowName' }; if (-not $flowId) { $flowId = $armName }

    $nodes = New-Object System.Collections.ArrayList
    $order = 0
    $trig = Get-Prop $wdl 'triggers'
    if ($trig) {
        foreach ($p in $trig.PSObject.Properties) { [void]$nodes.Add((New-WorkflowNode -Name $p.Name -Def $p.Value -Kind 'Trigger' -Parent '' -Branch '' -Depth 0 -Loops @() -Order ([ref]$order) -ParentPath '')) }
    }
    Add-WorkflowNodes -Actions (Get-Prop $wdl 'actions') -Parent '' -Branch 'actions' -Depth 0 -Loops @() -ParentPath '' -Nodes $nodes -Order ([ref]$order)

    $byName = @{}; $byScope = @{}; $children = @{}
    foreach ($n in $nodes) {
        $byName[$n.Name] = $n
        $byScope["$($n.ScopeKey)|$($n.Name)"] = $n
        if ($n.Parent) { if (-not $children.ContainsKey($n.Parent)) { $children[$n.Parent] = New-Object System.Collections.ArrayList }; [void]$children[$n.Parent].Add($n.Name) }
    }
    $vars = @{}
    foreach ($n in $nodes) {
        if ($n.Type -eq 'InitializeVariable') { foreach ($v in @($n.Def.inputs.variables)) { if ($v.name) { $vars[[string]$v.name] = $n.Name } } }
    }
    $defJson = $wdl | ConvertTo-Json -Depth 100 -Compress
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($defJson))) -replace '-', '').ToLower()
    $editorName = if ($Editor) { $Editor } else { Get-WorkflowEditor -Root $Root -Definition $wdl -Props $props -Nodes @($nodes) }

    [pscustomobject]@{
        Id          = [string]$flowId
        Name        = [string]$display
        Source      = $Source
        Editor      = $editorName
        State       = [string](Get-Prop $props 'state')
        Hash        = $hash
        Definition  = $wdl
        Raw         = $Root
        Nodes       = @($nodes)
        Trigger     = ($nodes | Where-Object { $_.Kind -eq 'Trigger' } | Select-Object -First 1)
        ByName      = $byName
        ByScope     = $byScope
        Children    = $children
        Variables   = $vars
        Parameters  = @($(if ($wdl.PSObject.Properties['parameters'] -and $wdl.parameters) { $wdl.parameters.PSObject.Properties.Name }))
        ExprCache   = $null
    }
}

function Get-ConnectorInfo {
    param($Def)
    $inputs = Get-Prop $Def 'inputs'
    $host_ = Get-Prop $inputs 'host'
    $connector = ''; $op = ''; $method = ''
    $api = [string](Get-Prop $host_ 'apiId')
    if ($api) { $connector = ($api -split '/')[-1] -replace '^shared_', '' }
    if (-not $connector) { $cn = [string](Get-Prop $host_ 'connectionName'); if ($cn) { $connector = $cn -replace '^shared_', '' } }
    if (-not $connector) {
        $conn = Get-Prop $host_ 'connection'
        $ref = [string](Get-Prop $conn 'name')
        if ($ref -match "\['([^']+)'\]") { $connector = $Matches[1] -replace '^shared_', '' }
        $sp = Get-Prop $host_ 'serviceProviderConfiguration'
        if ($sp) { $connector = [string](Get-Prop $sp 'serviceProviderId') -replace '^/serviceProviders/', '' }
    }
    $op = [string](Get-Prop $host_ 'operationId')
    if (-not $op) { $op = [string](Get-Prop (Get-Prop $host_ 'serviceProviderConfiguration') 'operationId') }
    $method = [string](Get-Prop $inputs 'method')
    if (-not $op -and $method) { $op = "$method $([string](Get-Prop $inputs 'path'))" }
    [pscustomobject]@{ Connector = $connector.ToLower(); Operation = $op; Method = $method.ToUpper() }
}

function New-WorkflowNode {
    param([string]$Name, $Def, [string]$Kind, [string]$Parent, [string]$Branch, [int]$Depth, [string[]]$Loops, [ref]$Order, [string]$ParentPath)
    $ra = @{}
    $raObj = Get-Prop $Def 'runAfter'
    if ($raObj) { foreach ($p in $raObj.PSObject.Properties) { $ra[$p.Name] = @($p.Value | ForEach-Object { [string]$_ }) } }
    $ci = Get-ConnectorInfo $Def
    $path = if ($ParentPath) { "$ParentPath > $Name" } else { $Name }
    $Order.Value++
    [pscustomobject]@{
        Name = $Name; Type = [string](Get-Prop $Def 'type'); Kind = $Kind; Def = $Def
        Parent = $Parent; Branch = $Branch; ScopeKey = "$Parent|$Branch"; Depth = $Depth; Loops = @($Loops)
        RunAfter = $ra; Connector = $ci.Connector; Operation = $ci.Operation; Method = $ci.Method
        Path = $path; Order = $Order.Value; Upstream = $null
    }
}

function Add-WorkflowNodes {
    param($Actions, [string]$Parent, [string]$Branch, [int]$Depth, [string[]]$Loops, [string]$ParentPath, $Nodes, [ref]$Order)
    if (-not $Actions) { return }
    foreach ($p in $Actions.PSObject.Properties) {
        $n = New-WorkflowNode -Name $p.Name -Def $p.Value -Kind 'Action' -Parent $Parent -Branch $Branch -Depth $Depth -Loops $Loops -Order $Order -ParentPath $ParentPath
        [void]$Nodes.Add($n)
        $childLoops = @($Loops)
        if ($n.Type -in 'Foreach', 'Until') { $childLoops += $n.Name }
        $d = $Depth + 1
        $def = $p.Value
        if ($def.PSObject.Properties['actions']) { Add-WorkflowNodes -Actions $def.actions -Parent $n.Name -Branch 'actions' -Depth $d -Loops $childLoops -ParentPath $n.Path -Nodes $Nodes -Order $Order }
        if ($def.PSObject.Properties['else'] -and $def.else -and $def.else.PSObject.Properties['actions']) { Add-WorkflowNodes -Actions $def.else.actions -Parent $n.Name -Branch 'else' -Depth $d -Loops $childLoops -ParentPath $n.Path -Nodes $Nodes -Order $Order }
        if ($def.PSObject.Properties['cases'] -and $def.cases) {
            foreach ($c in $def.cases.PSObject.Properties) { if ($c.Value.PSObject.Properties['actions']) { Add-WorkflowNodes -Actions $c.Value.actions -Parent $n.Name -Branch "case:$($c.Name)" -Depth $d -Loops $childLoops -ParentPath $n.Path -Nodes $Nodes -Order $Order } }
        }
        if ($def.PSObject.Properties['default'] -and $def.default -and $def.default.PSObject.Properties['actions']) { Add-WorkflowNodes -Actions $def.default.actions -Parent $n.Name -Branch 'default' -Depth $d -Loops $childLoops -ParentPath $n.Path -Nodes $Nodes -Order $Order }
    }
}

function Get-NodeUpstream {
    # Names of actions that are guaranteed to have been evaluated before $Node (runAfter closure, enclosing scopes, and descendants of those).
    param($Model, $Node)
    if ($Node.Upstream) { return $Node.Upstream }
    $set = @{}
    $stack = New-Object System.Collections.Stack
    foreach ($k in $Node.RunAfter.Keys) { $stack.Push($k) }
    while ($stack.Count) {
        $n = $stack.Pop()
        if ($set.ContainsKey($n)) { continue }
        $set[$n] = $true
        $sib = $Model.ByScope["$($Node.ScopeKey)|$n"]
        if ($sib) { foreach ($k in $sib.RunAfter.Keys) { $stack.Push($k) } }
    }
    if ($Node.Parent -and $Model.ByName.ContainsKey($Node.Parent)) {
        foreach ($k in (Get-NodeUpstream $Model $Model.ByName[$Node.Parent]).Keys) { $set[$k] = $true }
    }
    $desc = New-Object System.Collections.Stack
    foreach ($k in @($set.Keys)) { $desc.Push($k) }
    while ($desc.Count) {
        $n = $desc.Pop()
        if ($Model.Children.ContainsKey($n)) { foreach ($c in $Model.Children[$n]) { if (-not $set.ContainsKey($c)) { $set[$c] = $true; $desc.Push($c) } } }
    }
    $Node.Upstream = $set
    $set
}
#endregion

#region Node classification helpers (used by detectors)
function Test-ConnectorNode { param($Node) $Node.Type -in @('OpenApiConnection', 'ApiConnection', 'OpenApiConnectionWebhook', 'ApiConnectionWebhook', 'OpenApiConnectionNotification', 'ApiConnectionNotification', 'ServiceProvider') }
function Test-HttpNode { param($Node) $Node.Type -in @('Http', 'HttpWebhook') }
function Test-WriteNode {
    param($Node)
    if (Test-HttpNode $Node) { return [bool]($Node.Method -and $Node.Method -notmatch '^(GET|HEAD|OPTIONS)$') }
    if (Test-ConnectorNode $Node) {
        if ($Node.Method) { return ($Node.Method -notmatch '^(GET|HEAD|OPTIONS)$') }
        return [bool]($Node.Operation -match '(?i)^(create|update|patch|delete|post|add|insert|send|set|upsert|append|remove|put|move|copy|upload|approve|start|run|reply|forward|resolve|cancel)')
    }
    if ($Node.Type -eq 'Workflow') { return $true }
    $false
}
function Test-ReadListOperation { param($Node) (Test-ConnectorNode $Node) -and ($Node.Operation -match '(?i)^(GetItems|GetFileItems|ListRecords|ListRows|ListRowsPresentInTable|GetRecords|ListFolder|ListRootFolder|GetEntities|GetTableItems|GetRows|Query)') }
function Test-LoopAncestor { param($Node, [string]$Type, $Model) foreach ($l in $Node.Loops) { if ($Model.ByName[$l].Type -eq $Type) { return $true } }; $false }
function Get-ForeachParallelism {
    param($Node)
    $d = $Node.Def
    if ([string](Get-Prop $d 'operationOptions') -match 'Sequential') { return 1 }
    $rep = Get-Prop (Get-Prop (Get-Prop $d 'runtimeConfiguration') 'concurrency') 'repetitions'
    if ($null -ne $rep) { return [int]$rep }
    20
}
function Get-TriggerRuns {
    param($Model)
    $t = $Model.Trigger
    if (-not $t) { return $null }
    $r = Get-Prop (Get-Prop (Get-Prop $t.Def 'runtimeConfiguration') 'concurrency') 'runs'
    if ($null -ne $r) { return [int]$r }
    $null
}
function Get-NodeJson { param($Node) ($Node.Def | ConvertTo-Json -Depth 50 -Compress).Replace('\u0027', "'") }
function Get-DescendantNodes {
    param($Model, $Node)
    $res = New-Object System.Collections.ArrayList
    $stack = New-Object System.Collections.Stack; $stack.Push($Node.Name)
    while ($stack.Count) {
        $n = $stack.Pop()
        if ($Model.Children.ContainsKey($n)) { foreach ($c in $Model.Children[$n]) { [void]$res.Add($Model.ByName[$c]); $stack.Push($c) } }
    }
    @($res)
}
#endregion

#region Rule catalog (JSON store)
function Get-RulesFolder { param([string]$RulesPath) if ($RulesPath) { $RulesPath } else { Join-Path $Script:EngineRoot 'Rules' } }

function Read-JsonFile { param([string]$Path) Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }

function Get-RuleRegistry {
<#
.SYNOPSIS Reads editors.json / categories.json / sources.json from the rules folder.
#>
    param([Parameter(Mandatory)][ValidateSet('editors', 'categories', 'sources')][string]$Name, [string]$RulesPath)
    $f = Join-Path (Get-RulesFolder $RulesPath) "$Name.json"
    if (-not (Test-Path -LiteralPath $f)) { return @() }
    @((Read-JsonFile $f).$Name)
}

function Get-RuleCatalog {
<#
.SYNOPSIS Loads Rules\catalog.json plus every Rules\packs\*.json (rule packs for a connector, category or editor). Each rule gets a _file note property.
#>
    [CmdletBinding()]
    param([string]$RulesPath)
    $folder = Get-RulesFolder $RulesPath
    $files = @(Join-Path $folder 'catalog.json')
    $packs = Join-Path $folder 'packs'
    if (Test-Path -LiteralPath $packs) { $files += @(Get-ChildItem -LiteralPath $packs -Filter *.json -File | Sort-Object Name | ForEach-Object FullName) }
    $rules = New-Object System.Collections.ArrayList
    $version = ''
    foreach ($f in $files) {
        if (-not (Test-Path -LiteralPath $f)) { continue }
        $doc = Read-JsonFile $f
        if ($f -like '*catalog.json' -and $doc.catalogVersion) { $version = [string]$doc.catalogVersion }
        foreach ($r in @($doc.rules)) {
            Add-Member -InputObject $r -NotePropertyName _file -NotePropertyValue $f -Force
            [void]$rules.Add($r)
        }
    }
    [pscustomobject]@{ Version = $version; Folder = $folder; Files = $files; Rules = @($rules) }
}

function Get-RuleRisk {
    param($Rule)
    $def = $Script:DefaultImpact[[string]$Rule.severity]
    if (-not $def) { $def = @(3, 3) }
    $l = if ($Rule.PSObject.Properties['likelihood'] -and $Rule.likelihood) { [int]$Rule.likelihood } else { $def[0] }
    $i = if ($Rule.PSObject.Properties['impact'] -and $Rule.impact) { [int]$Rule.impact } else { $def[1] }
    $score = $l * $i
    $grade = if ($score -ge 20) { 'Critical' } elseif ($score -ge 15) { 'Very High' } elseif ($score -ge 10) { 'High' } elseif ($score -ge 5) { 'Moderate' } else { 'Low' }
    [pscustomobject]@{ Likelihood = $l; Impact = $i; Score = $score; Grade = $grade }
}

function Get-RuleImplementation {
    # Implemented | Planned (no detector logic registered or needs runtime/metadata data)
    param($Rule)
    $d = Get-Prop $Rule 'detector'
    $type = [string](Get-Prop $d 'type')
    if ($type -in 'Runtime', 'Metadata') { return 'Planned' }
    $logic = [string](Get-Prop $d 'logic')
    if ($logic -and $Script:LogicTable.ContainsKey($logic)) { return 'Implemented' }
    'Planned'
}

function Test-RuleDefinition {
<#
.SYNOPSIS Validates a rule against the catalog rule schema. Returns a list of error strings (empty = valid).
#>
    param([Parameter(Mandatory)]$Rule)
    $e = New-Object System.Collections.ArrayList
    foreach ($f in 'ruleId', 'ruleKey', 'ruleVersion', 'name', 'severity', 'categories', 'appliesTo', 'inspectionMode', 'detector', 'message', 'remediation', 'editors') {
        if (-not $Rule.PSObject.Properties[$f] -or $null -eq $Rule.$f -or ($Rule.$f -is [string] -and -not $Rule.$f.Trim())) { [void]$e.Add("Missing required field '$f'") }
    }
    if ($Rule.ruleId -and [string]$Rule.ruleId -notmatch '^[A-Z]{2,5}(-[A-Z]{2,8})?-\d{3}$') { [void]$e.Add("ruleId '$($Rule.ruleId)' must look like PA-LOOP-001") }
    if ($Rule.ruleVersion -and [string]$Rule.ruleVersion -notmatch '^\d+\.\d+\.\d+$') { [void]$e.Add('ruleVersion must be major.minor.patch') }
    if ($Rule.severity -and -not $Script:SeverityRank.ContainsKey([string]$Rule.severity)) { [void]$e.Add("severity '$($Rule.severity)' must be Info, Warning, High or Critical") }
    if ($Rule.inspectionMode -and $Script:InspectionModes -notcontains [string]$Rule.inspectionMode) { [void]$e.Add("inspectionMode must be one of $($Script:InspectionModes -join ', ')") }
    foreach ($a in @($Rule.appliesTo)) { if ($a -and $Script:AppliesToTaxonomy -notcontains [string]$a) { [void]$e.Add("appliesTo '$a' is not in the taxonomy") } }
    if ($Rule.categories -and @($Rule.categories).Count -eq 0) { [void]$e.Add('At least one category is required') }
    if ($Rule.editors -and @($Rule.editors).Count -eq 0) { [void]$e.Add('At least one editor is required (or "All")') }
    if ($Rule.detector -and -not $Rule.detector.type) { [void]$e.Add('detector.type is required') }
    foreach ($f in 'likelihood', 'impact') { if ($Rule.PSObject.Properties[$f] -and $Rule.$f -and ([int]$Rule.$f -lt 1 -or [int]$Rule.$f -gt 5)) { [void]$e.Add("$f must be 1-5") } }
    @($e)
}

function Save-RuleCatalog {
<#
.SYNOPSIS Writes rules back to the JSON file each was loaded from (a .bak copy is made first). Rules without _file go to catalog.json.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)]$Catalog, [switch]$BumpVersion)
    $default = Join-Path $Catalog.Folder 'catalog.json'
    $groups = $Catalog.Rules | Group-Object { if ($_.PSObject.Properties['_file'] -and $_._file) { $_._file } else { $default } }
    foreach ($g in $groups) {
        $file = $g.Name
        $existing = $null
        if (Test-Path -LiteralPath $file) { $existing = Read-JsonFile $file; Copy-Item -LiteralPath $file -Destination "$file.bak" -Force }
        $clean = foreach ($r in ($g.Group | Sort-Object ruleId)) {
            $copy = [ordered]@{}
            foreach ($p in $r.PSObject.Properties) { if ($p.Name -ne '_file') { $copy[$p.Name] = $p.Value } }
            [pscustomobject]$copy
        }
        $doc = [ordered]@{}
        if ($existing) { foreach ($p in $existing.PSObject.Properties) { if ($p.Name -ne 'rules') { $doc[$p.Name] = $p.Value } } }
        if ($file -eq $default) {
            $ver = if ($existing.catalogVersion) { [string]$existing.catalogVersion } else { '1.0.0' }
            if ($BumpVersion -and $ver -match '^(\d+)\.(\d+)\.(\d+)$') { $ver = "$($Matches[1]).$($Matches[2]).$([int]$Matches[3] + 1)" }
            $doc['catalogVersion'] = $ver
            $doc['updated'] = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
        }
        $doc['rules'] = @($clean)
        if ($PSCmdlet.ShouldProcess($file, 'Write rules')) { ([pscustomobject]$doc | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $file -Encoding UTF8 }
    }
}
#endregion

#region Evaluation
function Test-RuleApplies {
    param($Rule, $Model, [string]$Editor)
    $eds = @($Rule.editors)
    $target = if ($Editor) { $Editor } else { $Model.Editor }
    if ($eds -contains 'All' -or $target -eq 'Unknown' -or -not $eds) { return $true }
    $eds -contains $target
}

function Invoke-WorkflowRules {
<#
.SYNOPSIS Evaluates the rule catalog against a workflow model and returns a report object (JSON-serializable).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]$Workflow,
        [string]$RulesPath,
        $Catalog,
        [string]$Editor,
        [string[]]$Category,
        [string[]]$RuleId,
        [ValidateSet('Info', 'Warning', 'High', 'Critical')][string]$MinSeverity = 'Info',
        [string[]]$Suppress = @()
    )
    process {
        if (-not $Catalog) { $Catalog = Get-RuleCatalog -RulesPath $RulesPath }
        $stamp = Get-Date
        $reportId = 'RPT-{0}-{1}' -f $stamp.ToString('yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 6).ToUpper())
        $findings = New-Object System.Collections.ArrayList
        $notEval = New-Object System.Collections.ArrayList
        $suppressed = New-Object System.Collections.ArrayList
        $Workflow.ExprCache = $null
        $seq = 0
        foreach ($rule in $Catalog.Rules) {
            $skip = $null
            if (-not $rule.enabled) { $skip = 'Disabled' }
            elseif ($RuleId -and ($RuleId -notcontains $rule.ruleId)) { continue }
            elseif ($Category -and -not (@($rule.categories) | Where-Object { $Category -contains $_ })) { continue }
            elseif ($Script:SeverityRank[[string]$rule.severity] -lt $Script:SeverityRank[$MinSeverity]) { continue }
            elseif (-not (Test-RuleApplies $rule $Workflow $Editor)) { $skip = "NotApplicable to editor $($Workflow.Editor)" }
            elseif ((Get-RuleImplementation $rule) -ne 'Implemented') {
                $dt = [string]$rule.detector.type
                $skip = if ($dt -in 'Runtime', 'Metadata') { "Planned - needs $($dt.ToLower()) data" } else { 'Planned - no detector implemented yet' }
            }
            if ($skip) { [void]$notEval.Add([pscustomobject]@{ ruleId = $rule.ruleId; name = $rule.name; reason = $skip }); continue }

            try {
                $logic = $Script:LogicTable[[string]$rule.detector.logic]
                $hits = @(& $logic.Script $rule $Workflow $rule.detector)
            } catch {
                [void]$notEval.Add([pscustomobject]@{ ruleId = $rule.ruleId; name = $rule.name; reason = "DetectorError: $($_.Exception.Message)" })
                continue
            }
            $risk = Get-RuleRisk $rule
            foreach ($h in $hits) {
                if (-not $h) { continue }
                if ($Suppress -contains $rule.ruleId) { [void]$suppressed.Add([pscustomobject]@{ ruleId = $rule.ruleId; action = $h.Action; reason = 'Suppressed by caller' }); continue }
                $seq++
                [void]$findings.Add([pscustomobject]@{
                        findingId = ('{0}-F{1:000}' -f $reportId, $seq)
                        ruleId = $rule.ruleId; ruleKey = $rule.ruleKey; ruleVersion = $rule.ruleVersion
                        name = $rule.name; severity = [string]$rule.severity
                        riskScore = $risk.Score; riskGrade = $risk.Grade; likelihood = $risk.Likelihood; impact = $risk.Impact
                        categories = @($rule.categories); action = $h.Action; path = $h.Path
                        message = $(if ($h.Message) { $h.Message } else { [string]$rule.message })
                        evidence = $h.Evidence; risk = [string]$rule.risk; remediation = @($rule.remediation)
                        source = $(if ($rule.PSObject.Properties['source']) { $rule.source } else { $null })
                        status = 'Open'
                    })
            }
        }
        $sorted = @($findings | Sort-Object @{ e = { -$Script:SeverityRank[$_.severity] } }, @{ e = { -$_.riskScore } }, ruleId, action)
        $report = New-RulesReport -Id $reportId -Stamp $stamp -Workflow $Workflow -Catalog $Catalog -Findings $sorted -NotEvaluated @($notEval) -Suppressed @($suppressed)
        $report
    }
}

function Get-HealthScore {
    param([object[]]$Findings)
    $w = @{ Critical = 25; High = 10; Warning = 4; Info = 1 }
    $penalty = 0
    foreach ($f in $Findings) { $penalty += $w[[string]$f.severity] }
    [Math]::Max(0, 100 - $penalty)
}

function New-RulesReport {
    param($Id, $Stamp, $Workflow, $Catalog, [object[]]$Findings, [object[]]$NotEvaluated, [object[]]$Suppressed)
    $counts = [ordered]@{ Critical = 0; High = 0; Warning = 0; Info = 0 }
    foreach ($f in $Findings) { $counts[[string]$f.severity]++ }
    $overall = 'Clean'
    if ($Findings.Count) {
        $max = ($Findings | Measure-Object riskScore -Maximum).Maximum
        $overall = if ($max -ge 20) { 'Critical' } elseif ($max -ge 15) { 'Very High' } elseif ($max -ge 10) { 'High' } elseif ($max -ge 5) { 'Moderate' } else { 'Low' }
    }
    $byCat = [ordered]@{}
    foreach ($f in $Findings) {
        foreach ($c in $f.categories) {
            if (-not $byCat.Contains($c)) { $byCat[$c] = New-Object System.Collections.ArrayList }
            [void]$byCat[$c].Add($f)
        }
    }
    $catScores = [ordered]@{}
    foreach ($k in ($byCat.Keys | Sort-Object)) { $catScores[$k] = [pscustomobject]@{ findings = $byCat[$k].Count; healthScore = (Get-HealthScore @($byCat[$k])); maxRisk = (($byCat[$k] | Measure-Object riskScore -Maximum).Maximum) } }
    $t = $Workflow.Trigger
    $evaluated = @($Catalog.Rules).Count - @($NotEvaluated).Count
    [pscustomobject][ordered]@{
        reportId = $Id
        generated = $Stamp.ToString('yyyy-MM-ddTHH:mm:sszzz')
        engine = [pscustomobject]@{ name = 'WorkflowRulesEngine'; version = $Script:EngineVersion }
        catalog = [pscustomobject]@{ version = $Catalog.Version; ruleCount = @($Catalog.Rules).Count; evaluated = $evaluated; notEvaluated = @($NotEvaluated).Count }
        workflow = [pscustomobject]@{
            id = $Workflow.Id; name = $Workflow.Name; editor = $Workflow.Editor; source = $Workflow.Source; state = $Workflow.State
            definitionHash = $Workflow.Hash
            trigger = $(if ($t) { (@($t.Type, [string]$t.Def.kind) | Where-Object { $_ }) -join '/' } else { 'none' })
            triggerName = $(if ($t) { $t.Name } else { '' })
            actionCount = @($Workflow.Nodes | Where-Object { $_.Kind -eq 'Action' }).Count
            connectors = @($Workflow.Nodes | Where-Object { $_.Connector } | ForEach-Object Connector | Sort-Object -Unique)
        }
        summary = [pscustomobject]@{ overallRisk = $overall; healthScore = (Get-HealthScore $Findings); findingCount = $Findings.Count; bySeverity = [pscustomobject]$counts; byCategory = [pscustomobject]$catScores }
        findings = @($Findings)
        suppressions = @($Suppressed)
        notEvaluated = @($NotEvaluated)
    }
}
#endregion

#region Report rendering
function Export-RulesReport {
<#
.SYNOPSIS Writes one or more report files. JSON is the master format; HTML, Markdown and CSV are implemented, Excel/Word/Pdf are registered stubs.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]$Report,
        [string[]]$Format = @('Json'),
        [string]$OutDir = (Join-Path $Script:EngineRoot 'Reports'),
        [string]$BaseName
    )
    process {
        if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
        $base = if ($BaseName) { $BaseName } else { $Report.reportId }
        foreach ($f in $Format) {
            $r = $Script:Renderers[$f]
            if (-not $r) { Write-Error "Unknown report format '$f'. Available: $(($Script:Renderers.Keys | Sort-Object) -join ', ')"; continue }
            $path = Join-Path $OutDir ($base + $r.Extension)
            & $r.Script $Report $path
            Get-Item -LiteralPath $path
        }
    }
}

function Write-TextFile { param([string]$Path, [string]$Text) [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($true))) }
#endregion

# Detectors and renderers register themselves when dot-sourced.
foreach ($dir in 'Detectors', 'Renderers', 'Simulation') {
    $p = Join-Path $Script:EngineRoot $dir
    if (Test-Path -LiteralPath $p) {
        foreach ($file in (Get-ChildItem -LiteralPath $p -Filter *.ps1 -File | Sort-Object Name)) { . $file.FullName }
    }
}

Export-ModuleMember -Function *-*
