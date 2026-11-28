# Structural detectors: loops, waits, performance, concurrency, data, re-entrancy, retries, triggers, conditions, connectors, ALM, security.
# Each Register-RuleLogic scriptblock receives ($Rule, $Model, $Detector) and returns hits (New-RuleHit).

function Get-RetryPolicy {
    param($Node)
    $rp = Get-Prop (Get-Prop $Node.Def 'inputs') 'retryPolicy'
    if (-not $rp) { $rp = Get-Prop $Node.Def 'retryPolicy' }
    $rp
}

function Get-WaitSecondsOfNode {
    param($Node)
    $i = Get-Prop $Node.Def 'inputs'
    $iv = Get-Prop $i 'interval'
    if ($iv -and $null -ne $iv.count) { return (ConvertTo-Seconds -Count ([double]$iv.count) -Unit ([string]$iv.unit)) }
    $until = Get-Prop $i 'until'
    if ($until) { return 86400 }   # a Delay until timestamp is unbounded statically; assume a day
    0
}

function Get-UntilLimits {
    param($Node)
    $lim = Get-Prop $Node.Def 'limit'
    $count = if ($lim -and $null -ne $lim.count) { [int]$lim.count } else { 60 }
    $sec = 3600
    if ($lim -and $lim.timeout) { $x = ConvertFrom-IsoDuration ([string]$lim.timeout); if ($null -ne $x) { $sec = $x } }
    @($count, $sec)
}

#region Looping
Register-RuleLogic -Name 'ConnectorInForeach' -Description 'Connector action nested in Apply to each' -Script {
    param($Rule, $Model, $D)
    foreach ($n in $Model.Nodes) {
        if ((Test-ConnectorNode $n) -and (Test-LoopAncestor $n 'Foreach' $Model)) {
            $loop = $n.Loops | Where-Object { $Model.ByName[$_].Type -eq 'Foreach' } | Select-Object -Last 1
            New-RuleHit -Node $n -Message "Connector action '$($n.Name)' ($($n.Connector)/$($n.Operation)) runs once per item of Apply to each '$loop'." -Evidence "loop=$loop"
        }
    }
}

Register-RuleLogic -Name 'NestedForeach' -Description 'Apply to each inside Apply to each' -Script {
    param($Rule, $Model, $D)
    foreach ($n in $Model.Nodes) { if ($n.Type -eq 'Foreach' -and (Test-LoopAncestor $n 'Foreach' $Model)) { New-RuleHit -Node $n -Message "Apply to each '$($n.Name)' is nested inside '$($n.Loops[0])'; cost multiplies (outer x inner items)." } }
}

Register-RuleLogic -Name 'LoopNestingDepth' -Description 'Three or more nested loops, or very deep nesting' -Script {
    param($Rule, $Model, $D)
    $maxLoops = [int](Get-DetectorParam $D 'maxLoops' 3); $maxDepth = [int](Get-DetectorParam $D 'maxDepth' 6)
    foreach ($n in $Model.Nodes) {
        $lc = @($n.Loops).Count + $(if ($n.Type -in 'Foreach', 'Until') { 1 } else { 0 })
        if ($n.Type -in 'Foreach', 'Until' -and $lc -ge $maxLoops) { New-RuleHit -Node $n -Message "Loop '$($n.Name)' is nested $lc loops deep (limit $maxLoops)." -Evidence "loopDepth=$lc" }
        elseif ($n.Depth -ge $maxDepth -and $n.Type -notin 'Foreach', 'Until') { New-RuleHit -Node $n -Message "Action '$($n.Name)' is nested $($n.Depth) containers deep (limit $maxDepth); flatten with child flows or Compose steps." -Evidence "depth=$($n.Depth)" }
    }
}

Register-RuleLogic -Name 'SequentialLoopCouldBeParallel' -Description 'Sequential loop with no shared state' -Script {
    param($Rule, $Model, $D)
    foreach ($n in ($Model.Nodes | Where-Object { $_.Type -eq 'Foreach' })) {
        if ((Get-ForeachParallelism $n) -ne 1) { continue }
        $d = Get-DescendantNodes $Model $n
        if ($d.Count -and -not ($d | Where-Object { $_.Type -match 'Variable$' })) {
            New-RuleHit -Node $n -Message "Apply to each '$($n.Name)' runs sequentially but its iterations do not share variables; a higher degree of parallelism may be safe." -Evidence 'concurrency=1'
        }
    }
}

Register-RuleLogic -Name 'ParallelLoopWritesSharedTarget' -Description 'Concurrent loop writing the same target each iteration' -Script {
    param($Rule, $Model, $D)
    foreach ($n in ($Model.Nodes | Where-Object { $_.Type -eq 'Foreach' })) {
        if ((Get-ForeachParallelism $n) -le 1) { continue }
        foreach ($c in (Get-DescendantNodes $Model $n)) {
            if (-not (Test-WriteNode $c)) { continue }
            $json = Get-NodeJson $c
            if ($json -notmatch "items\('" -and $json -notmatch 'item\(\)') {
                New-RuleHit -Node $c -Message "'$($c.Name)' writes inside concurrent loop '$($n.Name)' but its inputs do not depend on the current item, so parallel iterations write the same target." -Evidence "parallelism=$(Get-ForeachParallelism $n)"
            }
        }
    }
}
#endregion

#region Waits
Register-RuleLogic -Name 'LongDelay' -Description 'Delay / Delay until at or above a threshold' -Script {
    param($Rule, $Model, $D)
    $min = [double](Get-DetectorParam $D 'minSeconds' 3600)
    foreach ($n in ($Model.Nodes | Where-Object { $_.Type -eq 'Wait' })) {
        $s = Get-WaitSecondsOfNode $n
        if ($s -ge $min) { New-RuleHit -Node $n -Message "Delay '$($n.Name)' waits $(Format-Seconds $s); the run stays open (limit 30 days) and ties up capacity." -Evidence (Format-Seconds $s) }
    }
}

Register-RuleLogic -Name 'DelayInLoop' -Description 'Delay inside a loop' -Script {
    param($Rule, $Model, $D)
    foreach ($n in ($Model.Nodes | Where-Object { $_.Type -eq 'Wait' -and (Test-LoopAncestor $_ 'Foreach' $Model) })) {
        New-RuleHit -Node $n -Message "Delay '$($n.Name)' runs on every iteration of '$($n.Loops[-1])'; total wait grows with the item count." -Evidence (Format-Seconds (Get-WaitSecondsOfNode $n))
    }
}

Register-RuleLogic -Name 'UntilPolling' -Description 'Do until with a long limit' -Script {
    param($Rule, $Model, $D)
    $minTimeout = [int](Get-DetectorParam $D 'minTimeoutSeconds' 3600)
    foreach ($n in ($Model.Nodes | Where-Object { $_.Type -eq 'Until' })) {
        $l = Get-UntilLimits $n
        if ($l[1] -ge $minTimeout -or $l[0] -ge 60) { New-RuleHit -Node $n -Message "Do until '$($n.Name)' can poll for up to $($l[0]) iterations / $(Format-Seconds $l[1]); keep polling short or use a webhook/approval wait." -Evidence "count=$($l[0]) timeout=$(Format-Seconds $l[1])" }
    }
}
#endregion

#region Performance
Register-RuleLogic -Name 'GetItemsWithoutFilter' -Description 'List/Get items without a server-side filter' -Script {
    param($Rule, $Model, $D)
    foreach ($n in $Model.Nodes) {
        if (-not (Test-ReadListOperation $n)) { continue }
        $p = Get-Prop (Get-Prop $n.Def 'inputs') 'parameters'
        $keys = if ($p) { @($p.PSObject.Properties.Name) } else { @() }
        $hasFilter = [bool]($keys | Where-Object { $_ -match '(?i)filter|\$search|query' })
        $top = $null; foreach ($k in $keys) { if ($k -match '(?i)^\$?top$') { $top = $p.$k } }
        if (-not $hasFilter -and -not ($null -ne $top -and "$top" -match '^\d+$' -and [int]$top -le 10)) {
            New-RuleHit -Node $n -Message "'$($n.Name)' ($($n.Operation)) has no server-side filter, so every row is retrieved and filtered in the flow." -Evidence "parameters: $($keys -join ', ')"
        }
    }
}

Register-RuleLogic -Name 'FilterArrayAfterGet' -Description 'Filter array applied to a connector list result' -Script {
    param($Rule, $Model, $D)
    foreach ($n in ($Model.Nodes | Where-Object { $_.Type -eq 'Query' })) {
        $from = [string](Get-Prop (Get-Prop $n.Def 'inputs') 'from')
        if ($from -match "(?i)(body|outputs)\('([^']+)'\)") {
            $src = $Model.ByName[$Matches[2]]
            if ($src -and (Test-ReadListOperation $src)) { New-RuleHit -Node $n -Message "Filter array '$($n.Name)' filters the result of '$($src.Name)' in the flow; push the condition into the connector's filter query." -Evidence "from=$from" }
        }
    }
}

Register-RuleLogic -Name 'RepeatedIdenticalQuery' -Description 'Same connector read repeated' -Script {
    param($Rule, $Model, $D)
    $seen = @{}
    foreach ($n in $Model.Nodes) {
        if (-not (Test-ConnectorNode $n) -or (Test-WriteNode $n) -or -not $n.Operation) { continue }
        $key = "$($n.Connector)|$($n.Operation)|" + (($n.Def.inputs.parameters | ConvertTo-Json -Depth 20 -Compress))
        if ($seen.ContainsKey($key)) { New-RuleHit -Node $n -Message "'$($n.Name)' repeats the identical call already made by '$($seen[$key])'; reuse the first result." -Evidence $n.Operation }
        else { $seen[$key] = $n.Name }
    }
}

Register-RuleLogic -Name 'ExpensiveCallInLoop' -Description 'HTTP, child flow or connector read repeated inside a loop' -Script {
    param($Rule, $Model, $D)
    foreach ($n in ($Model.Nodes | Where-Object { Test-LoopAncestor $_ 'Foreach' $Model })) {
        $isRead = ((Test-HttpNode $n) -or (Test-ConnectorNode $n)) -and -not (Test-WriteNode $n)
        if ($isRead -or $n.Type -eq 'Workflow') {
            New-RuleHit -Node $n -Message "'$($n.Name)' ($($n.Type)) is called on every iteration of '$($n.Loops[-1])'; fetch once before the loop or batch the request." -Evidence "loop=$($n.Loops[-1])"
        }
    }
}
#endregion

#region Concurrency / data / re-entrancy
Register-RuleLogic -Name 'TriggerUnlimitedOverlap' -Description 'Trigger allows unlimited overlapping runs while the flow writes' -Script {
    param($Rule, $Model, $D)
    $t = $Model.Trigger
    if (-not $t) { return }
    if ($null -ne (Get-TriggerRuns $Model)) { return }
    $writes = @($Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and (Test-WriteNode $_) })
    if ($writes.Count) { New-RuleHit -Node $t -Message "Trigger '$($t.Name)' has no concurrency limit (runs overlap) while the flow writes data in $($writes.Count) action(s)." -Evidence "writes: $(($writes | Select-Object -First 3 -ExpandProperty Name) -join ', ')" }
}

Register-RuleLogic -Name 'ConcurrencyLimitedReadOnly' -Description 'Concurrency of one on a read-only event flow' -Script {
    param($Rule, $Model, $D)
    $t = $Model.Trigger
    if (-not $t -or $t.Type -eq 'Recurrence') { return }
    if ((Get-TriggerRuns $Model) -eq 1 -and -not ($Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and (Test-WriteNode $_) })) {
        New-RuleHit -Node $t -Message "Trigger '$($t.Name)' serializes runs (concurrency 1) but the flow does not write shared data; consider allowing parallel runs for throughput." -Evidence 'runs=1'
    }
}

Register-RuleLogic -Name 'ParallelBranchesSameResource' -Description 'Parallel branches with the same connector write' -Script {
    param($Rule, $Model, $D)
    $groups = $Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and (Test-WriteNode $_) -and $_.Connector } |
        Group-Object { "$($_.ScopeKey)|" + ((@($_.RunAfter.Keys) | Sort-Object) -join ',') + "|$($_.Connector)|$($_.Operation)" }
    foreach ($g in ($groups | Where-Object { $_.Count -gt 1 })) {
        $names = ($g.Group | ForEach-Object Name) -join ', '
        foreach ($n in ($g.Group | Select-Object -Skip 1)) { New-RuleHit -Node $n -Message "'$($n.Name)' runs in parallel with other $($n.Connector)/$($n.Operation) writes ($names); concurrent updates can overwrite each other." -Evidence $names }
    }
}

Register-RuleLogic -Name 'ParallelLoopWritesVariable' -Description 'Concurrent loop modifying variables' -Script {
    param($Rule, $Model, $D)
    foreach ($n in ($Model.Nodes | Where-Object { $_.Type -eq 'Foreach' })) {
        if ((Get-ForeachParallelism $n) -le 1) { continue }
        foreach ($c in (Get-DescendantNodes $Model $n | Where-Object { $_.Type -match '^(Set|Increment|Decrement|Append).*Variable$' })) {
            New-RuleHit -Node $c -Message "$($c.Type) '$($c.Name)' runs inside Apply to each '$($n.Name)' with parallelism $(Get-ForeachParallelism $n); variables are shared across parallel iterations." -Evidence "parallelism=$(Get-ForeachParallelism $n)"
        }
    }
}

Register-RuleLogic -Name 'ReadModifyWrite' -Description 'Read then update the same connector without serialized runs' -Script {
    param($Rule, $Model, $D)
    if ((Get-TriggerRuns $Model) -eq 1) { return }
    foreach ($w in ($Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and (Test-ConnectorNode $_) -and $_.Operation -match '(?i)^(update|patch|set|upsert)' })) {
        $up = Get-NodeUpstream $Model $w
        $r = $Model.Nodes | Where-Object { $up.ContainsKey($_.Name) -and (Test-ConnectorNode $_) -and $_.Connector -eq $w.Connector -and $_.Operation -match '(?i)^(get|list)' } | Select-Object -First 1
        if ($r) { New-RuleHit -Node $w -Message "'$($w.Name)' updates data that '$($r.Name)' read earlier; overlapping runs can overwrite each other's changes (read-modify-write)." -Evidence "read=$($r.Name) write=$($w.Name)" }
    }
}

Register-RuleLogic -Name 'ExcelAsDatabase' -Description 'Excel Online used for concurrent writes' -Script {
    param($Rule, $Model, $D)
    $unlimited = $null -eq (Get-TriggerRuns $Model) -or (Get-TriggerRuns $Model) -gt 1
    foreach ($n in $Model.Nodes) {
        if ($n.Connector -match '^excelonline' -and (Test-WriteNode $n) -and ($unlimited -or @($n.Loops).Count)) {
            New-RuleHit -Node $n -Message "'$($n.Name)' writes to an Excel workbook ($($n.Operation)) from a flow that can run concurrently or in a loop; Excel files lock and are not a transactional store." -Evidence $n.Operation
        }
    }
}

Register-RuleLogic -Name 'NoIdempotencyCheck' -Description 'Event flow that creates records with no existence check' -Script {
    param($Rule, $Model, $D)
    $t = $Model.Trigger
    if (-not $t -or $t.Type -eq 'Recurrence' -or [string]$t.Def.kind -eq 'Button') { return }
    $creates = @($Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and (Test-WriteNode $_) -and ($_.Operation -match '(?i)^(create|add|insert|post|send)' -or $_.Method -eq 'POST') })
    if (-not $creates.Count) { return }
    $hasCheck = [bool]($Model.Nodes | Where-Object { $_.Type -in 'If', 'Switch' }) -or [bool](Get-Prop $t.Def 'conditions') -or [bool]($creates | Where-Object { (Get-NodeJson $_) -match '(?i)idempot' })
    if (-not $hasCheck) { New-RuleHit -Node $t -Message "The flow creates records ($(($creates | Select-Object -First 3 -ExpandProperty Name) -join ', ')) with no condition or trigger condition to detect a duplicate trigger event." -Evidence "creates=$($creates.Count)" }
}

Register-RuleLogic -Name 'SelfTrigger' -Description 'Flow updates the data source that triggers it' -Script {
    param($Rule, $Model, $D)
    $t = $Model.Trigger
    if (-not $t -or -not $t.Connector -or $t.Type -eq 'Recurrence') { return }
    if ($t.Operation -notmatch '(?i)(modified|updated|changed|OnUpdated|OnNew|OnChanged|OnItem)') { return }
    if (Get-Prop $t.Def 'conditions') { return }
    $tp = Get-Prop (Get-Prop $t.Def 'inputs') 'parameters'
    foreach ($n in ($Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and $_.Connector -eq $t.Connector -and (Test-WriteNode $_) -and $_.Operation -match '(?i)(update|patch|create|put)' })) {
        $ap = Get-Prop (Get-Prop $n.Def 'inputs') 'parameters'
        $same = $true
        foreach ($k in 'dataset', 'table', 'entityName', 'drive') {
            $a = Get-Prop $tp $k; $b = Get-Prop $ap $k
            if ($null -ne $a -and $null -ne $b -and [string]$a -ne [string]$b) { $same = $false }
        }
        if ($same) { New-RuleHit -Node $n -Message "'$($n.Name)' ($($n.Operation)) writes to the same $($t.Connector) source that triggers '$($t.Name)'; the update can start another run (recursion)." -Evidence "trigger=$($t.Operation) action=$($n.Operation)" }
    }
}
#endregion

#region Connectors / governance
Register-RuleLogic -Name 'ConnectorAllowList' -Description 'Connector not in an approved list (detector.params.allowed)' -Script {
    param($Rule, $Model, $D)
    $allowed = @(Get-DetectorParam $D 'allowed' @() | ForEach-Object { "$_".ToLower() })
    if (-not $allowed.Count) { return }
    foreach ($n in ($Model.Nodes | Where-Object { $_.Connector -and ($allowed -notcontains $_.Connector) })) { New-RuleHit -Node $n -Message "Connector '$($n.Connector)' used by '$($n.Name)' is not in the approved list." -Evidence $n.Connector }
}

Register-RuleLogic -Name 'ConnectorBlockList' -Description 'Connector in a blocked list (detector.params.blocked)' -Script {
    param($Rule, $Model, $D)
    $blocked = @(Get-DetectorParam $D 'blocked' @() | ForEach-Object { "$_".ToLower() })
    if (-not $blocked.Count) { return }
    foreach ($n in ($Model.Nodes | Where-Object { $_.Connector -and ($blocked -contains $_.Connector) })) { New-RuleHit -Node $n -Message "Connector '$($n.Connector)' used by '$($n.Name)' is blocked by the connector catalog." -Evidence $n.Connector }
}

Register-RuleLogic -Name 'HardcodedEnvironmentIdentifier' -Description 'Environment-specific GUIDs / hostnames typed into actions' -Script {
    param($Rule, $Model, $D)
    $guid = '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b'
    $hostRx = '(?i)https?://[a-z0-9-]+(\.[a-z0-9-]+)*\.(sharepoint\.com|dynamics\.com|crm\d*\.dynamics\.com)|https?://[^/\s]*\b(prod|dev|test|uat|stg|staging)\b[^/\s]*\.'
    foreach ($n in $Model.Nodes) {
        foreach ($s in (Get-JsonStrings -Value $n.Def -SkipKeys @('actions', 'else', 'cases', 'default', 'runAfter', 'host', 'schema', 'metadata', 'runtimeConfiguration'))) {
            if ($s.Value.StartsWith('@') -or $s.Value.Contains('@{')) { continue }
            if ($s.Value -match $guid -or $s.Value -match $hostRx) {
                New-RuleHit -Node $n -Message "'$($n.Name)' hard-codes an environment-specific value in $($s.Path); use an environment variable, parameter or connection reference." -Evidence $s.Value -Path "$($n.Path) :: $($s.Path)"
            }
        }
    }
}

Register-RuleLogic -Name 'HardcodedSecret' -Description 'Secrets, tokens or keys typed into actions' -Script {
    param($Rule, $Model, $D)
    $rx = '(?i)(Bearer\s+[A-Za-z0-9._~+/=-]{20,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}|[?&](sig|apikey|api_key|key|token|code|access_token)=[^&\s@]{8,}|-----BEGIN [A-Z ]*PRIVATE KEY)'
    foreach ($n in $Model.Nodes) {
        foreach ($s in (Get-JsonStrings -Value $n.Def -SkipKeys @('actions', 'else', 'cases', 'default', 'runAfter', 'host', 'schema', 'metadata'))) {
            if ($s.Value.StartsWith('@') -or $s.Value.Contains('@{')) { continue }
            $secretProp = $s.Path -match '(?i)(authentication\.(value|password|secret|pfx)|\.(password|clientSecret|secret|apiKey)$|headers\.(authorization|x-api-key|api-key|ocp-apim-subscription-key)$)'
            if ($secretProp -or $s.Value -match $rx) {
                $shown = if ($s.Value.Length -gt 8) { $s.Value.Substring(0, 4) + '****' } else { '****' }
                New-RuleHit -Node $n -Message "'$($n.Name)' contains a hard-coded secret or token in $($s.Path); store it in Key Vault / an environment variable (secure input) instead." -Evidence $shown -Path "$($n.Path) :: $($s.Path)"
            }
        }
    }
}
#endregion

#region Retry / trigger / condition
Register-RuleLogic -Name 'ExcessiveRetries' -Description 'Retry count above a threshold' -Script {
    param($Rule, $Model, $D)
    $max = [int](Get-DetectorParam $D 'maxCount' 4)
    foreach ($n in $Model.Nodes) {
        $rp = Get-RetryPolicy $n
        if ($rp -and [string]$rp.type -ne 'none' -and $null -ne $rp.count -and [int]$rp.count -gt $max) { New-RuleHit -Node $n -Message "'$($n.Name)' retries up to $($rp.count) times (limit $max); retries multiply load on a failing service." -Evidence "retryPolicy=$($rp.type) x$($rp.count)" }
    }
}

Register-RuleLogic -Name 'NonIdempotentRetry' -Description 'Create/POST action that is retried by default' -Script {
    param($Rule, $Model, $D)
    foreach ($n in ($Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and (Test-WriteNode $_) })) {
        $isCreate = ($n.Method -in 'POST', 'PATCH') -or ($n.Operation -match '(?i)^(create|add|insert|post|send|append)')
        if (-not $isCreate) { continue }
        $rp = Get-RetryPolicy $n
        if ($rp -and [string]$rp.type -eq 'none') { continue }
        $hdr = Get-Prop (Get-Prop $n.Def 'inputs') 'headers'
        if ($hdr -and (($hdr.PSObject.Properties.Name -join ' ') -match '(?i)idempot|request-id|client-request')) { continue }
        $how = if ($rp) { "retryPolicy=$($rp.type) x$($rp.count)" } else { 'default retry policy (exponential, 4 retries)' }
        New-RuleHit -Node $n -Message "'$($n.Name)' creates data but is retried ($how); a retry after a timeout can create a duplicate. Set the retry policy to None, add an idempotency key, or check for an existing record first." -Evidence $how
    }
}

Register-RuleLogic -Name 'TriggerConditionMissing' -Description 'First action filters on trigger data' -Script {
    param($Rule, $Model, $D)
    $t = $Model.Trigger
    if (-not $t -or $t.Type -eq 'Recurrence' -or [string]$t.Def.kind -eq 'Button') { return }
    if (Get-Prop $t.Def 'conditions') { return }
    $first = $Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and $_.Type -eq 'If' -and -not $_.Parent -and $_.RunAfter.Count -eq 0 } | Select-Object -First 1
    if ($first -and ((Get-NodeJson $first) -match 'trigger(Body|Outputs)')) { New-RuleHit -Node $first -Message "'$($first.Name)' immediately filters on trigger data; a trigger condition would avoid starting (and billing) runs that exit straight away." -Evidence $first.Name }
}

Register-RuleLogic -Name 'RecurrenceTooFrequent' -Description 'Recurrence / polling interval below threshold' -Script {
    param($Rule, $Model, $D)
    $min = [int](Get-DetectorParam $D 'minSeconds' 300)
    $t = $Model.Trigger
    if (-not $t) { return }
    $rec = Get-Prop $t.Def 'recurrence'
    if ($rec -and $rec.interval) {
        $s = ConvertTo-Seconds -Count ([double]$rec.interval) -Unit ([string]$rec.frequency)
        if ($s -lt $min) { New-RuleHit -Node $t -Message "Trigger '$($t.Name)' fires every $(Format-Seconds $s) (minimum recommended $(Format-Seconds $min)); frequent triggers consume capacity and API quota." -Evidence "every $(Format-Seconds $s)" }
    }
}

function Get-ConditionComplexity {
    param($Expr)
    $depth = 0; $ops = 0
    if ($Expr -is [pscustomobject]) {
        foreach ($p in $Expr.PSObject.Properties) {
            if ($p.Name -in 'and', 'or', 'not') { $ops++; $m = 0; foreach ($c in @($p.Value)) { $r = Get-ConditionComplexity $c; if ($r[0] -gt $m) { $m = $r[0] }; $ops += $r[1] }; $depth = [Math]::Max($depth, 1 + $m) }
            else { $ops++ }
        }
    }
    @($depth, $ops)
}

Register-RuleLogic -Name 'ComplexCondition' -Description 'Large or deeply nested condition' -Script {
    param($Rule, $Model, $D)
    $maxLen = [int](Get-DetectorParam $D 'maxLength' 300); $maxDepth = [int](Get-DetectorParam $D 'maxDepth' 3); $maxOps = [int](Get-DetectorParam $D 'maxOperators' 6)
    foreach ($n in ($Model.Nodes | Where-Object { $_.Type -in 'If', 'Until' })) {
        $expr = Get-Prop $n.Def 'expression'
        if (-not $expr) { continue }
        $text = if ($expr -is [string]) { $expr } else { $expr | ConvertTo-Json -Depth 30 -Compress }
        $c = Get-ConditionComplexity $expr
        if ($text.Length -gt $maxLen -or $c[0] -gt $maxDepth -or $c[1] -gt $maxOps) { New-RuleHit -Node $n -Message "Condition of '$($n.Name)' is hard to maintain ($($text.Length) characters, nesting $($c[0]), $($c[1]) operators); split it or compute parts in Compose actions." -Evidence "len=$($text.Length) depth=$($c[0]) ops=$($c[1])" }
    }
}
#endregion
