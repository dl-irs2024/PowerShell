# Error-handling detectors: failure paths, scope handlers, swallowed failures, terminal state.

function Get-FailureHandlers {
    # Nodes whose runAfter reacts to Failed/TimedOut (and not Succeeded) of another node - i.e. real error handlers, not "finally" steps.
    param($Model)
    foreach ($n in $Model.Nodes) {
        foreach ($k in $n.RunAfter.Keys) {
            $st = @($n.RunAfter[$k])
            if (($st -contains 'Failed' -or $st -contains 'TimedOut') -and ($st -notcontains 'Succeeded')) { [pscustomobject]@{ Handler = $n; Watches = $k } }
        }
    }
}

function Get-WatchedNames {
    param($Model)
    $set = @{}
    foreach ($n in $Model.Nodes) {
        foreach ($k in $n.RunAfter.Keys) {
            $st = @($n.RunAfter[$k])
            if ($st -contains 'Failed' -or $st -contains 'TimedOut' -or $st -contains 'Skipped') { $set[$k] = $true }
        }
    }
    $set
}

Register-RuleLogic -Name 'CriticalActionNoFailurePath' -Description 'Write/HTTP action not covered by any failure handler' -Script {
    param($Rule, $Model, $D)
    $watched = Get-WatchedNames $Model
    foreach ($n in ($Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and (Test-WriteNode $_) })) {
        $chain = @($n.Name) + @($n.Loops) + @(); $p = $n.Parent
        while ($p) { $chain += $p; $p = $Model.ByName[$p].Parent }
        $inHandler = $chain | Where-Object { $nd = $Model.ByName[$_]; $nd -and ($nd.RunAfter.Keys | Where-Object { @($nd.RunAfter[$_]) -match '^(Failed|TimedOut)$' }) }
        if ($inHandler) { continue }   # actions that are themselves part of an error handler
        if (-not ($chain | Where-Object { $watched.ContainsKey($_) })) {
            New-RuleHit -Node $n -Message "'$($n.Name)' changes data or calls a service but no action or scope reacts to its failure (no run-after Failed/TimedOut path)." -Evidence "$($n.Type) $($n.Operation)"
        }
    }
}

Register-RuleLogic -Name 'ScopeWithoutFailureBranch' -Description 'Scope with no failure handler' -Script {
    param($Rule, $Model, $D)
    $watched = Get-WatchedNames $Model
    foreach ($n in ($Model.Nodes | Where-Object { $_.Type -eq 'Scope' })) {
        if ($watched.ContainsKey($n.Name)) { continue }
        # A scope that is itself the handler (runs after a failure) is not required to have its own handler.
        $isHandler = $false
        foreach ($k in $n.RunAfter.Keys) { if (@($n.RunAfter[$k]) -contains 'Failed') { $isHandler = $true } }
        $inHandler = $false; $p = $n.Parent
        while ($p) { foreach ($k in $Model.ByName[$p].RunAfter.Keys) { if (@($Model.ByName[$p].RunAfter[$k]) -contains 'Failed') { $inHandler = $true } }; $p = $Model.ByName[$p].Parent }
        if (-not $isHandler -and -not $inHandler) { New-RuleHit -Node $n -Message "Scope '$($n.Name)' has no run-after Failed/TimedOut branch; failures inside it are not caught (try/catch pattern)." -Evidence "scope=$($n.Name)" }
    }
}

Register-RuleLogic -Name 'FailureSwallowed' -Description 'Failure handler does not log, notify or terminate' -Script {
    param($Rule, $Model, $D)
    $seen = @{}
    foreach ($h in (Get-FailureHandlers $Model)) {
        $n = $h.Handler
        if ($seen.ContainsKey($n.Name)) { continue }
        $seen[$n.Name] = $true
        $all = @($n) + @(Get-DescendantNodes $Model $n)
        $acts = $all | Where-Object { (Test-ConnectorNode $_) -or (Test-HttpNode $_) -or $_.Type -eq 'Workflow' -or ($_.Type -eq 'Terminate' -and [string]$_.Def.inputs.runStatus -ne 'Succeeded') }
        $term = $all | Where-Object { $_.Type -eq 'Terminate' -and [string]$_.Def.inputs.runStatus -eq 'Succeeded' }
        if (-not $acts -or $term) { New-RuleHit -Node $n -Message "Failure handler '$($n.Name)' (watching '$($h.Watches)') neither notifies, logs, nor terminates the run as failed, so the error is silently swallowed." -Evidence "watches=$($h.Watches)" }
    }
}

Register-RuleLogic -Name 'NoTerminalErrorState' -Description 'Flow can never end as Failed on purpose' -Script {
    param($Rule, $Model, $D)
    $risky = $Model.Nodes | Where-Object { $_.Kind -eq 'Action' -and (Test-WriteNode $_) }
    if (-not $risky) { return }
    $term = $Model.Nodes | Where-Object { $_.Type -eq 'Terminate' -and [string]$_.Def.inputs.runStatus -in 'Failed', 'Cancelled' }
    if (-not $term) { New-RuleHit -Node $null -Path $Model.Name -Message 'The flow changes data but has no Terminate (Failed/Cancelled) action, so a handled error still shows the run as Succeeded and hides the failure from monitoring.' -Evidence "writers=$(@($risky).Count)" }
}
