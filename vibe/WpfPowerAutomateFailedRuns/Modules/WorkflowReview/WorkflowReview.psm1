# WorkflowReview - offline static review of Power Automate flow definitions (WDL JSON).
# Works without the GUI:  Import-WorkflowDefinition x.json | Invoke-WorkflowReview | Format-Table
Set-StrictMode -Off

# ---- Tunable thresholds (single table) ----------------------------------------------------
$Script:Thresholds = [ordered]@{
    DefaultForeachRepetitions = 20        # platform default when no concurrency is configured
    ParallelCallsMedium       = 50        # runs x loop repetitions reaching one connector action
    ParallelCallsHigh         = 100
    MaxRunDays                = 30        # flow run duration limit
    LongRunDaysWarn           = 1
    UntilDefaultCount         = 60
    UntilDefaultTimeoutSec    = 3600      # PT1H
    NestedLoopDepthWarn       = 2
    SyncResponseLimitSec      = 120       # HTTP request trigger waits ~2 minutes for a Response
    ActionCountWarn           = 250
}

$Script:KnownFunctions = @'
add addDays addHours addMinutes addProperty addSeconds addToTime and array base64 base64ToBinary base64ToString binary body bool coalesce concat contains convertFromUtc convertTimeZone convertToUtc createArray dataUri dataUriToBinary dataUriToString date dateDifference dayOfMonth dayOfWeek dayOfYear decimal decodeDataUri decodeUriComponent div encodeUriComponent empty endsWith equals first float formDataMultiValues formDataValue formatDateTime formatNumber getFutureTime getPastTime greater greaterOrEquals guid if indexOf int intersect isFloat isInt item items join json last lastIndexOf length less lessOrEquals max min mod mul not nthIndexOf or outputs parameters parseDateTime rand range removeProperty replace result setProperty skip slice sort split startOfDay startOfHour startOfMonth startsWith string sub subtractFromTime substring sum take ticks toLower toUpper trigger triggerBody triggerFormDataMultiValues triggerFormDataValue triggerMultipartBody triggerOutputs trim union uriComponent uriComponentToBinary uriComponentToString uriHost uriPath uriPathAndQuery uriPort uriQuery uriScheme utcNow variables workflow xml xpath actions action
'@ -split '\s+' | Where-Object { $_ }

function Get-Prop {
    param($Object, [string]$Name)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    $null
}

function New-ReviewFinding {
    param([string]$Severity, [string]$Rule, [string]$Action, [string]$Message, [string]$Recommendation, [string]$Source = 'Local')
    [pscustomobject]@{ Severity = $Severity; Rule = $Rule; Action = $Action; Message = $Message; Recommendation = $Recommendation; Source = $Source }
}

function ConvertTo-Seconds {
    param([int]$Count, [string]$Unit)
    switch -Regex ($Unit) {
        '^Second' { return $Count }
        '^Minute' { return $Count * 60 }
        '^Hour'   { return $Count * 3600 }
        '^Day'    { return $Count * 86400 }
        '^Week'   { return $Count * 604800 }
        '^Month'  { return $Count * 2592000 }
        default   { return $Count }
    }
}

function ConvertFrom-IsoDuration {
    param([string]$Duration)
    if ($Duration -match '^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$') {
        $d = [int]('0' + $Matches[1]); $h = [int]('0' + $Matches[2]); $m = [int]('0' + $Matches[3]); $s = [int]('0' + $Matches[4])
        return ($d * 86400 + $h * 3600 + $m * 60 + $s)
    }
    $null
}

function Format-Seconds {
    param([double]$Seconds)
    if ($Seconds -ge 86400) { return ('{0:N1} days' -f ($Seconds / 86400)) }
    if ($Seconds -ge 3600)  { return ('{0:N1} hours' -f ($Seconds / 3600)) }
    if ($Seconds -ge 60)    { return ('{0:N0} min' -f ($Seconds / 60)) }
    '{0:N0} sec' -f $Seconds
}

# ---- Import -------------------------------------------------------------------------------
function Import-WorkflowDefinition {
<#
.SYNOPSIS Loads a flow definition from an export .json, bare WDL, definition.json, a portal export .zip, or an in-memory object (e.g. Get-AdminFlow output).
#>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ParameterSetName = 'Path', Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)][Alias('FullName')][string]$Path,
        [Parameter(ParameterSetName = 'Object', Mandatory)]$InputObject,
        [string]$Name
    )
    process {
        $root = $null; $source = $Name
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
            $file = $Path
            if ($Path -match '\.zip$') {
                $tmp = Join-Path ([IO.Path]::GetTempPath()) ('wfreview_' + [guid]::NewGuid().ToString('N'))
                Expand-Archive -LiteralPath $Path -DestinationPath $tmp -Force
                $def = Get-ChildItem $tmp -Recurse -Filter 'definition.json' | Select-Object -First 1
                if (-not $def) { throw "No definition.json inside $Path" }
                $file = $def.FullName
            }
            $root = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $source) { $source = $Path }
        } else {
            $root = $InputObject
            if ($root -is [string]) { $root = $root | ConvertFrom-Json }
            if (-not $source) { $source = 'object' }
        }

        # Locate the WDL: export {properties.definition}, Get-AdminFlow {Internal.properties.definition}, or bare {triggers,actions}
        $props = Get-Prop $root 'properties'
        if (-not $props) { $props = Get-Prop (Get-Prop $root 'Internal') 'properties' }
        $wdl = Get-Prop $props 'definition'
        if (-not $wdl) { $wdl = Get-Prop $root 'definition' }
        if (-not $wdl -and ((Get-Prop $root 'actions') -or (Get-Prop $root 'triggers'))) { $wdl = $root }
        if (-not $wdl) { throw "No workflow definition (triggers/actions) found in $source" }

        $display = Get-Prop $props 'displayName'
        if (-not $display) { $display = Get-Prop $root 'DisplayName' }
        if (-not $display) { $display = Get-Prop $root 'displayName' }
        if (-not $display) { $display = [IO.Path]::GetFileNameWithoutExtension($source) }
        $flowId = Get-Prop $root 'name'; if (-not $flowId) { $flowId = Get-Prop $root 'FlowName' }

        $wf = [pscustomobject]@{
            Name        = $flowId
            DisplayName = [string]$display
            Source      = $source
            State       = Get-Prop $props 'state'
            Definition  = $wdl
            Structure   = $null
        }
        $wf.Structure = Get-WorkflowStructure -Workflow $wf
        $wf
    }
}

# ---- Structure ----------------------------------------------------------------------------
function Get-WorkflowStructure {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)]$Workflow)
    process {
        if ($Workflow.Structure) { return $Workflow.Structure }
        $nodes = New-Object System.Collections.ArrayList
        $index = 0

        $walk = $null
        $walk = {
            param($actions, [string]$parent, [int]$depth)
            if (-not $actions) { return }
            foreach ($p in $actions.PSObject.Properties) {
                $a = $p.Value
                $ra = @(); $raStat = @{}
                $runAfter = Get-Prop $a 'runAfter'
                if ($runAfter) { foreach ($r in $runAfter.PSObject.Properties) { $ra += $r.Name; $raStat[$r.Name] = @($r.Value) } }
                $conc = Get-Prop (Get-Prop $a 'runtimeConfiguration') 'concurrency'
                $node = [pscustomobject]@{
                    Name = $p.Name; Type = [string](Get-Prop $a 'type'); Parent = $parent; Depth = $depth; Index = $script:__idx
                    RunAfter = $ra; RunAfterStatus = $raStat; Raw = $a
                    Repetitions = Get-Prop $conc 'repetitions'
                    Sequential = ([string](Get-Prop $a 'operationOptions') -match 'Sequential')
                }
                $script:__idx++
                [void]$nodes.Add($node)
                foreach ($child in @('actions')) { & $walk (Get-Prop $a $child) $p.Name ($depth + 1) }
                & $walk (Get-Prop (Get-Prop $a 'else') 'actions') $p.Name ($depth + 1)
                $cases = Get-Prop $a 'cases'
                if ($cases) { foreach ($c in $cases.PSObject.Properties) { & $walk (Get-Prop $c.Value 'actions') $p.Name ($depth + 1) } }
                & $walk (Get-Prop (Get-Prop $a 'default') 'actions') $p.Name ($depth + 1)
            }
        }
        $script:__idx = 0
        & $walk (Get-Prop $Workflow.Definition 'actions') '' 0

        $trigger = $null
        $tr = Get-Prop $Workflow.Definition 'triggers'
        if ($tr) {
            $first = $tr.PSObject.Properties | Select-Object -First 1
            if ($first) {
                $t = $first.Value
                $conc = Get-Prop (Get-Prop $t 'runtimeConfiguration') 'concurrency'
                $trigger = [pscustomobject]@{
                    Name = $first.Name; Type = [string](Get-Prop $t 'type'); Kind = [string](Get-Prop $t 'kind')
                    Runs = Get-Prop $conc 'runs'; SplitOn = Get-Prop $t 'splitOn'; Recurrence = Get-Prop $t 'recurrence'; Raw = $t
                }
            }
        }
        [pscustomobject]@{ Trigger = $trigger; Nodes = @($nodes) }
    }
}

function Get-NodeLoopFactor {
    param($Structure, $Node)
    $factor = 1; $depthLoops = 0; $cur = $Node
    while ($cur -and $cur.Parent) {
        $cur = $Structure.Nodes | Where-Object { $_.Name -eq $cur.Parent } | Select-Object -First 1
        if ($cur -and $cur.Type -eq 'Foreach') {
            $depthLoops++
            $factor *= (Get-ForeachReps $cur)
        } elseif ($cur -and $cur.Type -eq 'Until') { $depthLoops++ }
    }
    [pscustomobject]@{ Factor = $factor; LoopDepth = $depthLoops }
}

function Get-ForeachReps {
    param($Node)
    if ($Node.Sequential) { return 1 }
    if ($null -ne $Node.Repetitions) { return [int]$Node.Repetitions }
    [int]$Script:Thresholds.DefaultForeachRepetitions
}

function Get-TriggerRuns {
    param($Structure)
    $t = $Structure.Trigger
    if (-not $t) { return $null }
    if ($null -ne $t.Runs) { return [int]$t.Runs }
    if ($t.Type -eq 'Recurrence') { return 1 }   # recurrence/polling triggers do not overlap runs by default unless concurrency is raised
    $null                                         # unlimited (platform default)
}

function Test-IsConnectorAction { param($Node) $Node.Type -in @('OpenApiConnection', 'ApiConnection', 'OpenApiConnectionWebhook', 'ApiConnectionWebhook', 'ApiConnectionNotification') }
function Test-IsHttpAction { param($Node) $Node.Type -in @('Http', 'HttpWebhook') }

# ---- Rules --------------------------------------------------------------------------------
function Test-WorkflowConcurrency {
    [CmdletBinding()] param([Parameter(Mandatory, ValueFromPipeline)]$Workflow)
    process {
        $s = Get-WorkflowStructure $Workflow; $t = $s.Trigger; $out = @()
        if (-not $t) { return (New-ReviewFinding 'Medium' 'NoTrigger' '' 'No trigger found in definition.' 'Verify the export contains the triggers section.') }
        $runs = Get-TriggerRuns $s
        $isRequest = $t.Type -eq 'Request'
        if ($null -eq $runs) {
            $sev = if ($isRequest) { 'Medium' } else { 'Low' }
            $out += New-ReviewFinding $sev 'Reentrancy-Unbounded' $t.Name "Trigger '$($t.Name)' ($($t.Type)/$($t.Kind)) has no concurrency limit: any number of runs can overlap (re-entrant)." 'Set trigger concurrency (Settings > Concurrency control) to cap parallel runs, or 1 if the flow must not re-enter.'
        } elseif ($runs -gt 1) {
            $out += New-ReviewFinding 'Medium' 'Reentrancy-Parallel' $t.Name "Trigger allows up to $runs overlapping runs." 'Make sure shared state (variables are per-run, but lists/files/rows are shared) tolerates concurrent runs.'
        }
        $vars = $s.Nodes | Where-Object { $_.Type -in 'IncrementVariable', 'SetVariable', 'AppendToArrayVariable', 'AppendToStringVariable', 'DecrementVariable' }
        foreach ($v in $vars) {
            $f = Get-NodeLoopFactor $s $v
            $loopParent = $s.Nodes | Where-Object { $_.Name -eq $v.Parent -and $_.Type -eq 'Foreach' }
            if ($loopParent -and (Get-ForeachReps $loopParent) -gt 1) {
                $out += New-ReviewFinding 'High' 'Loop-VariableRace' $v.Name "Variable '$($v.Name)' is modified inside parallel Apply to each '$($loopParent.Name)' ($(Get-ForeachReps $loopParent) concurrent iterations): results are non-deterministic." 'Set the loop to Sequential (concurrency 1) or use Select/Filter array / a Compose-based aggregation instead.'
            }
        }
        $out
    }
}

function Test-WorkflowLooping {
    [CmdletBinding()] param([Parameter(Mandatory, ValueFromPipeline)]$Workflow)
    process {
        $s = Get-WorkflowStructure $Workflow; $out = @()
        foreach ($n in ($s.Nodes | Where-Object { $_.Type -in 'Foreach', 'Until' })) {
            $f = Get-NodeLoopFactor $s $n
            $depth = $f.LoopDepth + 1
            if ($depth -ge $Script:Thresholds.NestedLoopDepthWarn) {
                $out += New-ReviewFinding 'Medium' 'Loop-Nested' $n.Name "'$($n.Name)' is a loop nested $depth levels deep; iterations multiply." 'Flatten with Filter array / Select, or move the inner loop into a child flow.'
            }
            if ($n.Type -eq 'Until') {
                $lim = Get-Prop $n.Raw 'limit'
                if (-not $lim) {
                    $out += New-ReviewFinding 'Medium' 'Loop-UntilDefaultLimit' $n.Name "Until '$($n.Name)' uses default limits ($($Script:Thresholds.UntilDefaultCount) iterations / PT1H)." 'Set explicit count and timeout so the loop cannot spin or run out unexpectedly.'
                } elseif ([int](Get-Prop $lim 'count') -ge 60) {
                    $out += New-ReviewFinding 'Low' 'Loop-UntilHighCount' $n.Name "Until '$($n.Name)' may iterate up to $((Get-Prop $lim 'count')) times (timeout $((Get-Prop $lim 'timeout')))." 'Confirm the exit condition is reachable; a never-true condition burns API calls until the limit.'
                }
            }
            if ($n.Type -eq 'Foreach' -and -not $n.Sequential -and $null -eq $n.Repetitions) {
                $out += New-ReviewFinding 'Low' 'Loop-DefaultConcurrency' $n.Name "Apply to each '$($n.Name)' runs with platform default concurrency ($($Script:Thresholds.DefaultForeachRepetitions))." 'Set degree of parallelism explicitly (1 for ordered/safe, higher only if idempotent).'
            }
        }
        $out
    }
}

function Test-WorkflowThrottling {
    [CmdletBinding()] param([Parameter(Mandatory, ValueFromPipeline)]$Workflow)
    process {
        $s = Get-WorkflowStructure $Workflow; $out = @()
        $runs = Get-TriggerRuns $s; if ($null -eq $runs) { $runsEff = 1 } else { $runsEff = $runs }
        foreach ($n in ($s.Nodes | Where-Object { (Test-IsConnectorAction $_) -or (Test-IsHttpAction $_) })) {
            $f = Get-NodeLoopFactor $s $n
            if ($f.LoopDepth -eq 0) { continue }
            $worst = $runsEff * $f.Factor
            $retry = Get-Prop (Get-Prop $n.Raw 'inputs') 'retryPolicy'
            if ($worst -ge $Script:Thresholds.ParallelCallsHigh) { $sev = 'High' } elseif ($worst -ge $Script:Thresholds.ParallelCallsMedium) { $sev = 'Medium' } else { $sev = 'Low' }
            if ($sev -ne 'Low') {
                $out += New-ReviewFinding $sev 'Throttle-ParallelCalls' $n.Name "'$($n.Name)' ($($n.Type)) can issue up to $worst concurrent calls (runs $runsEff x loop parallelism $($f.Factor))." 'Lower loop concurrency / trigger runs, add delays, or batch the operation to avoid 429 throttling.'
            }
            if ($f.LoopDepth -ge 1 -and -not $retry) {
                $out += New-ReviewFinding 'Low' 'Throttle-NoRetryPolicy' $n.Name "'$($n.Name)' runs inside a loop with the default retry policy." 'Configure an exponential retry policy so throttled (429) calls back off.'
            }
        }
        $t = $s.Trigger
        if ($t -and $t.Recurrence -and $t.Recurrence.frequency -eq 'Second') {
            $out += New-ReviewFinding 'Medium' 'Throttle-FastPolling' $t.Name "Trigger polls every $($t.Recurrence.interval) second(s)." 'Increase the polling interval; use push (webhook) triggers where available.'
        }
        $count = @($s.Nodes).Count
        if ($count -ge $Script:Thresholds.ActionCountWarn) {
            $out += New-ReviewFinding 'Low' 'Size-ManyActions' '' "Flow has $count actions (warn at $($Script:Thresholds.ActionCountWarn))." 'Split into child flows.'
        }
        $out
    }
}

function Get-WaitSeconds {
    param($Structure, [string]$Parent)
    $total = 0.0
    foreach ($n in ($Structure.Nodes | Where-Object { $_.Parent -eq $Parent })) {
        switch ($n.Type) {
            'Wait' { $total += (Get-WaitNodeSeconds $n) }
            'Until' {
                $lim = Get-Prop $n.Raw 'limit'
                $cnt = if ($lim -and (Get-Prop $lim 'count')) { [int]$lim.count } else { [int]$Script:Thresholds.UntilDefaultCount }
                $tmo = if ($lim -and (Get-Prop $lim 'timeout')) { ConvertFrom-IsoDuration $lim.timeout } else { $null }
                if ($null -eq $tmo) { $tmo = $Script:Thresholds.UntilDefaultTimeoutSec }
                $inner = Get-WaitSeconds $Structure $n.Name
                $total += [math]::Min($cnt * $inner, $tmo)
            }
            default { $total += (Get-WaitSeconds $Structure $n.Name) }
        }
    }
    $total
}

function Get-WaitNodeSeconds {
    param($Node)
    $in = Get-Prop $Node.Raw 'inputs'
    $iv = Get-Prop $in 'interval'
    if ($iv) { return (ConvertTo-Seconds ([int]$iv.count) ([string]$iv.unit)) }
    $until = Get-Prop (Get-Prop $in 'until') 'timestamp'
    if ($until -is [string]) {
        if ($until -match 'addDays\([^,]+,\s*(\d+)\)') { return [int]$Matches[1] * 86400 }
        if ($until -match 'addHours\([^,]+,\s*(\d+)\)') { return [int]$Matches[1] * 3600 }
        if ($until -match 'addMinutes\([^,]+,\s*(\d+)\)') { return [int]$Matches[1] * 60 }
    }
    86400   # unknown timestamp: assume a day
}

function Test-WorkflowTimeouts {
    [CmdletBinding()] param([Parameter(Mandatory, ValueFromPipeline)]$Workflow)
    process {
        $s = Get-WorkflowStructure $Workflow; $out = @()
        $waits = @($s.Nodes | Where-Object { $_.Type -eq 'Wait' })
        $total = Get-WaitSeconds $s ''
        $maxSec = $Script:Thresholds.MaxRunDays * 86400
        if ($total -ge $maxSec) {
            $out += New-ReviewFinding 'High' 'Timeout-RunLimit' '' "Worst-case accumulated waiting is $(Format-Seconds $total), at or over the $($Script:Thresholds.MaxRunDays)-day run limit." 'Split the process into separate flows or use a scheduled/polling design.'
        } elseif ($total -ge $Script:Thresholds.LongRunDaysWarn * 86400) {
            $out += New-ReviewFinding 'Medium' 'Timeout-LongRunning' '' "Worst-case accumulated waiting is $(Format-Seconds $total) across $($waits.Count) wait action(s) (limit $($Script:Thresholds.MaxRunDays) days)." 'Verify long waits are intended; keep the flow state small.'
        }
        foreach ($w in $waits) {
            $sec = Get-WaitNodeSeconds $w
            if ($sec -ge 86400) {
                $out += New-ReviewFinding 'Medium' 'Timeout-LongWait' $w.Name "Wait '$($w.Name)' pauses for about $(Format-Seconds $sec)." 'Prefer a recurrence trigger or a status column + scheduled flow for multi-day waits.'
            }
        }
        if ($s.Trigger -and $s.Trigger.Type -eq 'Request') {
            $resp = $s.Nodes | Where-Object { $_.Type -eq 'Response' } | Select-Object -First 1
            if ($resp -and $total -ge $Script:Thresholds.SyncResponseLimitSec) {
                $out += New-ReviewFinding 'High' 'Timeout-SyncResponse' $resp.Name "Request trigger returns a synchronous Response after ~$(Format-Seconds $total) of waiting; callers typically time out after ~$($Script:Thresholds.SyncResponseLimitSec) sec." 'Respond early (202 Accepted) and finish the work after the Response, or use an async pattern.'
            }
        }
        foreach ($n in ($s.Nodes | Where-Object { $_.Type -in 'OpenApiConnectionWebhook', 'ApiConnectionWebhook', 'HttpWebhook' })) {
            $out += New-ReviewFinding 'Medium' 'Timeout-Webhook' $n.Name "'$($n.Name)' waits for an external callback (approval/webhook); it times out after 30 days by default." 'Set the action timeout (Settings > Timeout) and handle the TimedOut branch.'
        }
        foreach ($n in ($s.Nodes | Where-Object { $_.Type -eq 'Until' })) {
            $lim = Get-Prop $n.Raw 'limit'
            $tmo = if ($lim) { ConvertFrom-IsoDuration (Get-Prop $lim 'timeout') } else { $null }
            if ($tmo -and $tmo -ge 86400) {
                $out += New-ReviewFinding 'Medium' 'Timeout-UntilLong' $n.Name "Until '$($n.Name)' may run up to $(Format-Seconds $tmo)." 'Reduce the timeout or iterate less often.'
            }
        }
        $out
    }
}

function Test-WorkflowErrorHandling {
    [CmdletBinding()] param([Parameter(Mandatory, ValueFromPipeline)]$Workflow)
    process {
        $s = Get-WorkflowStructure $Workflow; $out = @()
        $handlers = @($s.Nodes | Where-Object { ($_.RunAfterStatus.Values | ForEach-Object { $_ }) -match 'Failed|TimedOut|Skipped' })
        $scopes = @($s.Nodes | Where-Object { $_.Type -eq 'Scope' })
        if (-not $handlers) {
            $out += New-ReviewFinding 'Medium' 'Error-NoHandler' '' 'No action is configured to run after a failure/timeout (runAfter Failed/TimedOut).' 'Add a Try scope and a Catch scope (run after Failed, TimedOut) that notifies the owner and terminates as Failed.'
        } elseif (-not $scopes) {
            $out += New-ReviewFinding 'Low' 'Error-NoScope' '' 'Failure handlers exist but no Scope groups the protected actions.' 'Group actions in a Try scope so one Catch covers them all.'
        }
        if (-not ($s.Nodes | Where-Object { $_.Type -eq 'Terminate' }) -and $handlers) {
            $out += New-ReviewFinding 'Low' 'Error-NoTerminate' '' 'Failure handler does not Terminate the run as Failed; the run may show Succeeded after an error.' 'End the Catch scope with a Terminate action (status Failed).'
        }
        $out
    }
}

# ---- Expressions (dynamic content / WDL function calls) -----------------------------------
function Get-NodeExpressions {
    param($Node)
    $res = New-Object System.Collections.ArrayList
    $visit = $null
    $visit = {
        param($v, [string]$where)
        if ($null -eq $v) { return }
        if ($v -is [string]) {
            if ($v.Length -gt 1 -and $v[0] -eq '@' -and $v[1] -ne '{' -and $v[1] -ne '@') { [void]$res.Add([pscustomobject]@{ Where = $where; Text = $v.Substring(1); Raw = $v }) }
            else { foreach ($m in [regex]::Matches($v, '@\{([^}]*)\}')) { [void]$res.Add([pscustomobject]@{ Where = $where; Text = $m.Groups[1].Value; Raw = $v }) } }
        } elseif ($v -is [System.Management.Automation.PSCustomObject]) {
            foreach ($p in $v.PSObject.Properties) {
                if ($p.Name -in 'actions', 'else', 'cases', 'default', 'runAfter') { continue }
                & $visit $p.Value "$where.$($p.Name)"
            }
        } elseif ($v -is [System.Collections.IEnumerable]) {
            foreach ($i in $v) { & $visit $i $where }
        }
    }
    & $visit $Node.Raw ''
    @($res)
}

function Get-NodePredecessors {
    param($Structure, $Node, [hashtable]$Seen)
    if (-not $Seen) { $Seen = @{} }
    foreach ($ra in $Node.RunAfter) {
        if ($Seen.ContainsKey($ra)) { continue }
        $Seen[$ra] = $true
        $sib = $Structure.Nodes | Where-Object { $_.Name -eq $ra } | Select-Object -First 1
        if ($sib) { [void](Get-NodePredecessors $Structure $sib $Seen) }
    }
    if ($Node.Parent) {
        $par = $Structure.Nodes | Where-Object { $_.Name -eq $Node.Parent } | Select-Object -First 1
        if ($par) { $Seen[$par.Name] = $true; [void](Get-NodePredecessors $Structure $par $Seen) }
    }
    $Seen
}

function Test-IsDescendant {
    param($Structure, $Node, [string]$AncestorName)
    $cur = $Node
    while ($cur -and $cur.Parent) {
        if ($cur.Parent -eq $AncestorName) { return $true }
        $cur = $Structure.Nodes | Where-Object { $_.Name -eq $cur.Parent } | Select-Object -First 1
    }
    $false
}

function Test-WorkflowExpressions {
    [CmdletBinding()] param([Parameter(Mandatory, ValueFromPipeline)]$Workflow)
    process {
        $s = Get-WorkflowStructure $Workflow; $out = @()
        $names = @{}; foreach ($n in $s.Nodes) { $names[$n.Name] = $n }
        $varNames = @{}
        foreach ($n in ($s.Nodes | Where-Object { $_.Type -eq 'InitializeVariable' })) {
            foreach ($v in @((Get-Prop $n.Raw 'inputs').variables)) { if ($v.name) { $varNames[$v.name] = $n } }
        }
        $known = @{}; foreach ($k in $Script:KnownFunctions) { $known[$k.ToLower()] = $true }

        foreach ($n in $s.Nodes) {
            $preds = $null
            foreach ($e in (Get-NodeExpressions $n)) {
                $text = $e.Text
                $stripped = [regex]::Replace($text, "'(?:[^']|'')*'", "''")
                if (([regex]::Matches($stripped, '\(')).Count -ne ([regex]::Matches($stripped, '\)')).Count -or ([regex]::Matches($stripped, '\[')).Count -ne ([regex]::Matches($stripped, '\]')).Count) {
                    $out += New-ReviewFinding 'High' 'Expr-Unbalanced' $n.Name "Unbalanced parentheses/brackets in expression: $text" 'Fix the expression; the flow will fail to save or run.'
                }
                if ((([regex]::Matches($text, "'")).Count % 2) -ne 0) {
                    $out += New-ReviewFinding 'High' 'Expr-UnbalancedQuote' $n.Name "Unbalanced single quote in expression: $text" 'Escape quotes by doubling them (it''s -> it''''s).'
                }
                foreach ($m in [regex]::Matches($stripped, '(?<![\w.])([A-Za-z_][A-Za-z0-9_]*)\s*\(')) {
                    $fn = $m.Groups[1].Value
                    if (-not $known.ContainsKey($fn.ToLower())) {
                        $out += New-ReviewFinding 'High' 'Expr-UnknownFunction' $n.Name "Unknown workflow function '$fn()' in: $text" 'Check the function name against the Workflow Definition Language reference (e.g. toUpper, not toUpperCase).'
                    }
                }
                if ($stripped -match '\)\s*\[') {
                    $out += New-ReviewFinding 'Medium' 'Expr-NullUnsafe' $n.Name "Property/index access on a function result without '?' (fails if null/missing): $text" "Use the null-safe form, e.g. body('x')?['value']?[0]."
                }
                elseif ($stripped -match '\]\s*\[') {
                    $out += New-ReviewFinding 'Low' 'Expr-ChainedIndex' $n.Name "Chained index access without '?': $text" 'Use ?[...] between segments, or check length() first.'
                }
                if ($text -match '\b(first|last)\(') {
                    $out += New-ReviewFinding 'Low' 'Expr-FirstLast' $n.Name "first()/last() on a possibly empty array: $text" 'Guard with empty()/length() or use coalesce().'
                }
                foreach ($m in [regex]::Matches($text, "\b(?:outputs|body|actions|result)\(\s*'([^']+)'\s*\)")) {
                    $ref = $m.Groups[1].Value
                    if (-not $names.ContainsKey($ref)) {
                        $out += New-ReviewFinding 'High' 'Expr-MissingAction' $n.Name "References action '$ref' which does not exist." 'Fix the name (renamed/deleted action).'
                    } elseif ($ref -ne $n.Name) {
                        if ($null -eq $preds) { $preds = Get-NodePredecessors $s $n }
                        $inPredScope = $false; $c = $names[$ref]
                        while ($c -and $c.Parent) { if ($preds.ContainsKey($c.Parent)) { $inPredScope = $true; break }; $c = $names[$c.Parent] }
                        if (-not $preds.ContainsKey($ref) -and -not $inPredScope -and -not (Test-IsDescendant $s $names[$ref] $n.Name)) {
                            $out += New-ReviewFinding 'Medium' 'Expr-NotPrior' $n.Name "References '$ref' which is not guaranteed to run before '$($n.Name)'." 'Reference only actions in the runAfter chain, or restructure the flow.'
                        }
                    }
                }
                foreach ($m in [regex]::Matches($text, "\bvariables\(\s*'([^']+)'\s*\)")) {
                    if (-not $varNames.ContainsKey($m.Groups[1].Value)) {
                        $out += New-ReviewFinding 'High' 'Expr-UndefinedVariable' $n.Name "Variable '$($m.Groups[1].Value)' is never initialized." 'Add an Initialize variable action at the top level.'
                    }
                }
                foreach ($m in [regex]::Matches($text, "\bitems\(\s*'([^']+)'\s*\)")) {
                    $loop = $m.Groups[1].Value
                    if (-not $names.ContainsKey($loop) -or ($names[$loop].Type -ne 'Foreach')) {
                        $out += New-ReviewFinding 'High' 'Expr-BadLoopRef' $n.Name "items('$loop') refers to an unknown Apply to each." 'Use the name of an enclosing Apply to each.'
                    } elseif ($n.Name -ne $loop -and -not (Test-IsDescendant $s $n $loop)) {
                        $out += New-ReviewFinding 'High' 'Expr-LoopOutOfScope' $n.Name "items('$loop') is used outside that loop." 'Move the action inside the loop or capture the data first.'
                    }
                }
                if ($text -match '\bitem\(\s*\)') {
                    $inLoop = $false; $cur = $n
                    while ($cur) {
                        if ($cur.Type -eq 'Foreach' -and $e.Where -eq '.foreach') { }
                        $p = $s.Nodes | Where-Object { $_.Name -eq $cur.Parent } | Select-Object -First 1
                        if ($p -and $p.Type -in 'Foreach', 'Until') { $inLoop = $true; break }
                        $cur = $p
                    }
                    if (-not $inLoop) {
                        $out += New-ReviewFinding 'High' 'Expr-ItemOutsideLoop' $n.Name "item() is used outside a loop/array function: $text" 'item() is only valid inside Filter/Select/loop contexts; use items(''Apply_to_each'').'
                    }
                }
                if ($e.Raw -match '(?i)bearer\s+[A-Za-z0-9\-_\.]{15,}') { }
            }
            # literals anywhere in the action (not only expressions)
            $json = ($n.Raw | Select-Object * -ExcludeProperty actions, else, cases, default | ConvertTo-Json -Depth 12 -Compress)
            if ($json -match '(?i)bearer\s+[A-Za-z0-9\-_\.]{15,}') {
                $out += New-ReviewFinding 'High' 'Secret-HardCodedToken' $n.Name 'A bearer token/secret appears hard-coded in the action.' 'Move secrets to Azure Key Vault / secure inputs or a connection; rotate the exposed token.'
            }
            if ($json -match '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') {
                $out += New-ReviewFinding 'Low' 'Hardcoded-Guid' $n.Name 'Hard-coded GUID (site/list/environment id).' 'Use environment variables / parameters so the flow is portable between environments.'
            }
            if ((Test-IsHttpAction $n) -and ((Get-Prop (Get-Prop $n.Raw 'inputs') 'uri') -match '^https?://[^@]')) {
                $out += New-ReviewFinding 'Low' 'Hardcoded-Url' $n.Name "HTTP action uses a hard-coded URL: $((Get-Prop (Get-Prop $n.Raw 'inputs') 'uri'))" 'Use an environment variable or parameter for the endpoint.'
            }
        }
        $out
    }
}

# ---- Orchestration ------------------------------------------------------------------------
function Invoke-WorkflowReview {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)]$Workflow)
    process {
        $s = Get-WorkflowStructure $Workflow
        $findings = @()
        foreach ($rule in 'Test-WorkflowConcurrency', 'Test-WorkflowLooping', 'Test-WorkflowThrottling', 'Test-WorkflowTimeouts', 'Test-WorkflowErrorHandling', 'Test-WorkflowExpressions') {
            $findings += @(& $rule -Workflow $Workflow)
        }
        $order = @{ High = 0; Medium = 1; Low = 2; Info = 3 }
        $findings = @($findings | Sort-Object { $order[$_.Severity] }, Action)

        $runs = Get-TriggerRuns $s
        $t = $s.Trigger
        $runsEff = if ($null -eq $runs) { 1 } else { $runs }
        $maxFactor = 1
        foreach ($n in $s.Nodes) { $f = Get-NodeLoopFactor $s $n; if ($f.Factor -gt $maxFactor) { $maxFactor = $f.Factor } }
        $waitSec = Get-WaitSeconds $s ''
        $score = 0
        foreach ($f in $findings) { switch ($f.Severity) { 'High' { $score += 10 } 'Medium' { $score += 4 } 'Low' { $score += 1 } } }
        $overall = if (($findings | Where-Object Severity -eq 'High')) { 'High' } elseif (($findings | Where-Object Severity -eq 'Medium')) { 'Medium' } elseif ($findings) { 'Low' } else { 'Clean' }

        $summary = [pscustomobject]@{
            Trigger            = if ($t) { (@($t.Type, $t.Kind) | Where-Object { $_ }) -join '/' } else { 'none' }
            ReEntrantRuns      = if ($null -eq $runs) { 'Unlimited' } else { $runs }
            WorstCaseParallel  = if ($null -eq $runs) { "Unlimited x $maxFactor" } else { $runsEff * $maxFactor }
            Actions            = @($s.Nodes).Count
            Loops              = @($s.Nodes | Where-Object { $_.Type -in 'Foreach', 'Until' }).Count
            Waits              = @($s.Nodes | Where-Object { $_.Type -eq 'Wait' }).Count
            ConnectorCalls     = @($s.Nodes | Where-Object { Test-IsConnectorAction $_ }).Count
            HttpCalls          = @($s.Nodes | Where-Object { Test-IsHttpAction $_ }).Count
            WaitExposure       = Format-Seconds $waitSec
            WaitSeconds        = $waitSec
            High               = @($findings | Where-Object Severity -eq 'High').Count
            Medium             = @($findings | Where-Object Severity -eq 'Medium').Count
            Low                = @($findings | Where-Object Severity -eq 'Low').Count
            Score              = $score
            Overall            = $overall
        }
        [pscustomobject]@{ Workflow = $Workflow; Name = $Workflow.DisplayName; Source = $Workflow.Source; Summary = $summary; Findings = $findings }
    }
}

function Export-WorkflowReviewReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]$Review,
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Markdown', 'Csv', 'Html')][string]$Format = 'Markdown'
    )
    begin { $all = @() }
    process { $all += $Review }
    end {
        switch ($Format) {
            'Csv' {
                $all | ForEach-Object { $r = $_; $r.Findings | ForEach-Object { [pscustomobject]@{ Workflow = $r.Name; Severity = $_.Severity; Rule = $_.Rule; Action = $_.Action; Message = $_.Message; Recommendation = $_.Recommendation; Source = $_.Source } } } |
                    Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
            }
            'Markdown' {
                $sb = New-Object System.Text.StringBuilder
                foreach ($r in $all) {
                    $sm = $r.Summary
                    [void]$sb.AppendLine("# $($r.Name)"); [void]$sb.AppendLine()
                    [void]$sb.AppendLine("Source: $($r.Source)  "); [void]$sb.AppendLine("Overall: **$($sm.Overall)** (score $($sm.Score)) - trigger $($sm.Trigger), re-entrant runs $($sm.ReEntrantRuns), worst-case parallel $($sm.WorstCaseParallel), loops $($sm.Loops), waits $($sm.Waits) ($($sm.WaitExposure)), connector calls $($sm.ConnectorCalls), HTTP calls $($sm.HttpCalls)")
                    [void]$sb.AppendLine()
                    [void]$sb.AppendLine('| Severity | Rule | Action | Message | Recommendation |'); [void]$sb.AppendLine('|---|---|---|---|---|')
                    foreach ($f in $r.Findings) { [void]$sb.AppendLine("| $($f.Severity) | $($f.Rule) | $($f.Action) | $(($f.Message) -replace '\|','/') | $(($f.Recommendation) -replace '\|','/') |") }
                    [void]$sb.AppendLine()
                }
                Set-Content -LiteralPath $Path -Value $sb.ToString() -Encoding UTF8
            }
            'Html' {
                $sb = New-Object System.Text.StringBuilder
                [void]$sb.AppendLine('<html><head><meta charset="utf-8"><style>body{font-family:Segoe UI}td,th{border:1px solid #ccc;padding:4px}table{border-collapse:collapse}.High{background:#fdd}.Medium{background:#ffe9b3}.Low{background:#eef}</style></head><body>')
                foreach ($r in $all) {
                    $sm = $r.Summary
                    [void]$sb.AppendLine("<h2>$([System.Net.WebUtility]::HtmlEncode($r.Name))</h2><p>Overall <b>$($sm.Overall)</b>, trigger $($sm.Trigger), re-entrant $($sm.ReEntrantRuns), worst-case parallel $($sm.WorstCaseParallel), loops $($sm.Loops), waits $($sm.Waits) ($($sm.WaitExposure))</p><table><tr><th>Severity</th><th>Rule</th><th>Action</th><th>Message</th><th>Recommendation</th></tr>")
                    foreach ($f in $r.Findings) { [void]$sb.AppendLine("<tr class='$($f.Severity)'><td>$($f.Severity)</td><td>$($f.Rule)</td><td>$([System.Net.WebUtility]::HtmlEncode($f.Action))</td><td>$([System.Net.WebUtility]::HtmlEncode($f.Message))</td><td>$([System.Net.WebUtility]::HtmlEncode($f.Recommendation))</td></tr>") }
                    [void]$sb.AppendLine('</table>')
                }
                [void]$sb.AppendLine('</body></html>')
                Set-Content -LiteralPath $Path -Value $sb.ToString() -Encoding UTF8
            }
        }
        Get-Item -LiteralPath $Path
    }
}

Export-ModuleMember -Function Import-WorkflowDefinition, Get-WorkflowStructure, Test-WorkflowConcurrency, Test-WorkflowLooping, Test-WorkflowThrottling, Test-WorkflowTimeouts, Test-WorkflowErrorHandling, Test-WorkflowExpressions, Invoke-WorkflowReview, Export-WorkflowReviewReport
