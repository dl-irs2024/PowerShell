# Expression / Dynamic Content inspector: tokenizer + parser for the Workflow Definition Language (WDL) expression language,
# plus analysis that feeds the EXP-* rules.  Public helpers: ConvertFrom-WdlExpression, Get-WdlExpressionMap.

# name:minArgs:maxArgs (-1 = unbounded). Source: WDL functions reference (Azure Logic Apps / Power Automate).
$Script:WdlFunctions = @{}
@'
add:2:2 addDays:2:3 addHours:2:3 addMinutes:2:3 addProperty:3:3 addSeconds:2:3 addToTime:3:4 and:2:-1 array:1:1 base64:1:1 base64ToBinary:1:1
base64ToString:1:1 binary:1:1 body:1:1 bool:1:1 chunk:2:2 coalesce:1:-1 concat:1:-1 contains:2:2 convertFromUtc:2:3 convertTimeZone:3:4 convertToUtc:3:4
createArray:1:-1 dataUri:1:1 dataUriToBinary:1:1 dataUriToString:1:1 dateDifference:2:2 dayOfMonth:1:1 dayOfWeek:1:1 dayOfYear:1:1 decimal:1:1
decodeBase64:1:1 decodeDataUri:1:1 decodeUriComponent:1:1 div:2:2 encodeUriComponent:1:1 empty:1:1 endsWith:2:2 equals:2:2 first:1:1 float:1:2
formatDateTime:1:3 formatNumber:2:3 formDataMultiValues:2:2 formDataValue:2:2 getFutureTime:2:3 getPastTime:2:3 greater:2:2 greaterOrEquals:2:2 guid:0:1
if:3:3 indexOf:2:2 int:1:1 intersect:2:-1 isFloat:1:2 isInt:1:1 item:0:0 items:1:1 iterationIndexes:1:1 join:2:2 json:1:1 last:1:1 lastIndexOf:2:2
length:1:1 less:2:2 lessOrEquals:2:2 listCallbackUrl:0:0 max:1:-1 min:1:-1 mod:2:2 mul:2:2 multipartBody:2:2 not:1:1 nthIndexOf:3:3 or:2:-1 outputs:1:1
parameters:1:1 parseDateTime:1:3 rand:2:2 range:2:2 removeProperty:2:2 replace:3:3 result:1:1 setProperty:3:3 skip:2:2 slice:2:3 sort:1:2 split:2:2
startOfDay:1:3 startOfHour:1:3 startOfMonth:1:3 startsWith:2:2 string:1:1 sub:2:2 substring:2:3 subtractFromTime:3:4 sum:1:1 take:2:2 ticks:1:1
toLower:1:2 toUpper:1:2 trigger:0:0 triggerBody:0:0 triggerFormDataMultiValues:1:1 triggerFormDataValue:1:1 triggerMultipartBody:1:1 triggerOutputs:0:0
trim:1:1 union:2:-1 uriComponent:1:1 uriComponentToBinary:1:1 uriComponentToString:1:1 uriHost:1:1 uriPath:1:1 uriPathAndQuery:1:1 uriPort:1:1
uriQuery:1:1 uriScheme:1:1 utcNow:0:1 variables:1:1 workflow:0:0 xml:1:1 xpath:2:2 actions:1:1 action:0:0 actionBody:1:1 actionOutputs:1:1
'@ -split '\s+' | Where-Object { $_ } | ForEach-Object { $p = $_ -split ':'; $Script:WdlFunctions[$p[0]] = @([int]$p[1], [int]$p[2]) }

function Get-WdlFunctionTable { $Script:WdlFunctions }

function Get-WdlTokens {
    param([string]$Text)
    $tokens = New-Object System.Collections.ArrayList
    $i = 0; $n = $Text.Length
    while ($i -lt $n) {
        $c = $Text[$i]
        if ([char]::IsWhiteSpace($c)) { $i++; continue }
        if ($c -eq "'") {
            $sb = New-Object System.Text.StringBuilder
            $j = $i + 1; $closed = $false
            while ($j -lt $n) {
                if ($Text[$j] -eq "'") {
                    if ($j + 1 -lt $n -and $Text[$j + 1] -eq "'") { [void]$sb.Append("'"); $j += 2; continue }
                    $closed = $true; break
                }
                [void]$sb.Append($Text[$j]); $j++
            }
            if (-not $closed) { throw "Unterminated string literal starting at position $i" }
            [void]$tokens.Add(@{ T = 'str'; V = $sb.ToString(); P = $i }); $i = $j + 1; continue
        }
        $prev = if ($tokens.Count) { $tokens[$tokens.Count - 1].T } else { '' }
        if ([char]::IsDigit($c) -or ($c -eq '-' -and $i + 1 -lt $n -and [char]::IsDigit($Text[$i + 1]) -and $prev -in @('', '(', ',', '['))) {
            $m = [regex]::Match($Text.Substring($i), '^-?\d+(\.\d+)?')
            [void]$tokens.Add(@{ T = 'num'; V = $m.Value; P = $i }); $i += $m.Length; continue
        }
        if ([char]::IsLetter($c) -or $c -eq '_') {
            $m = [regex]::Match($Text.Substring($i), '^[A-Za-z_][A-Za-z0-9_]*')
            [void]$tokens.Add(@{ T = 'id'; V = $m.Value; P = $i }); $i += $m.Length; continue
        }
        if ($c -eq '?' -and $i + 1 -lt $n -and ($Text[$i + 1] -eq '[' -or $Text[$i + 1] -eq '.')) {
            [void]$tokens.Add(@{ T = "?$($Text[$i + 1])"; V = "?$($Text[$i + 1])"; P = $i }); $i += 2; continue
        }
        if ('()[],.'.Contains([string]$c)) { [void]$tokens.Add(@{ T = [string]$c; V = [string]$c; P = $i }); $i++; continue }
        throw "Unexpected character '$c' at position $i"
    }
    , $tokens
}

function ConvertFrom-WdlExpression {
<#
.SYNOPSIS Parses one WDL expression (without the leading @) into an AST. Returns @{ Ast; Error }.
#>
    param([Parameter(Mandatory)][string]$Text)
    $st = @{ Tokens = $null; Pos = 0 }
    try { $st.Tokens = Get-WdlTokens $Text } catch { return [pscustomobject]@{ Ast = $null; Error = $_.Exception.Message } }
    if ($st.Tokens.Count -eq 0) { return [pscustomobject]@{ Ast = $null; Error = 'Empty expression' } }
    try {
        $ast = Read-WdlPostfix $st
        if ($st.Pos -lt $st.Tokens.Count) { $t = $st.Tokens[$st.Pos]; throw "Unexpected token '$($t.V)' at position $($t.P)" }
        [pscustomobject]@{ Ast = $ast; Error = $null }
    } catch { [pscustomobject]@{ Ast = $null; Error = $_.Exception.Message } }
}

function Read-WdlPostfix {
    param($S)
    $node = Read-WdlPrimary $S
    while ($S.Pos -lt $S.Tokens.Count) {
        $t = $S.Tokens[$S.Pos]
        if ($t.T -eq '[' -or $t.T -eq '?[') {
            $S.Pos++
            $idx = Read-WdlPostfix $S
            if ($S.Pos -ge $S.Tokens.Count -or $S.Tokens[$S.Pos].T -ne ']') { throw "Missing ']' for the index opened at position $($t.P)" }
            $S.Pos++
            $node = [pscustomobject]@{ T = 'Index'; Target = $node; Index = $idx; Safe = ($t.T -eq '?['); Pos = $t.P }
        } elseif ($t.T -eq '.' -or $t.T -eq '?.') {
            $S.Pos++
            if ($S.Pos -ge $S.Tokens.Count -or $S.Tokens[$S.Pos].T -ne 'id') { throw "Expected a property name after '$($t.V)' at position $($t.P)" }
            $node = [pscustomobject]@{ T = 'Member'; Target = $node; Name = $S.Tokens[$S.Pos].V; Safe = ($t.T -eq '?.'); Pos = $t.P }
            $S.Pos++
        } else { break }
    }
    $node
}

function Read-WdlPrimary {
    param($S)
    if ($S.Pos -ge $S.Tokens.Count) { throw 'Expression ended unexpectedly' }
    $t = $S.Tokens[$S.Pos]
    switch ($t.T) {
        'str' { $S.Pos++; return [pscustomobject]@{ T = 'Str'; Value = $t.V; Pos = $t.P } }
        'num' { $S.Pos++; return [pscustomobject]@{ T = 'Num'; Value = $t.V; Pos = $t.P } }
        'id' {
            $S.Pos++
            if ($S.Pos -lt $S.Tokens.Count -and $S.Tokens[$S.Pos].T -eq '(') {
                $S.Pos++
                $args_ = @()
                if ($S.Pos -lt $S.Tokens.Count -and $S.Tokens[$S.Pos].T -eq ')') { $S.Pos++ }
                else {
                    while ($true) {
                        $args_ += , (Read-WdlPostfix $S)
                        if ($S.Pos -ge $S.Tokens.Count) { throw "Missing ')' for call to $($t.V)( opened at position $($t.P)" }
                        $nx = $S.Tokens[$S.Pos]
                        if ($nx.T -eq ',') { $S.Pos++; continue }
                        if ($nx.T -eq ')') { $S.Pos++; break }
                        throw "Expected ',' or ')' but found '$($nx.V)' at position $($nx.P) in call to $($t.V)"
                    }
                }
                return [pscustomobject]@{ T = 'Call'; Name = $t.V; Args = $args_; Pos = $t.P }
            }
            if ($t.V -in 'true', 'false', 'null') { return [pscustomobject]@{ T = 'Lit'; Value = $t.V; Pos = $t.P } }
            throw "Unknown identifier '$($t.V)' at position $($t.P) (functions need parentheses; text needs single quotes)"
        }
        default { throw "Unexpected token '$($t.V)' at position $($t.P)" }
    }
}

function Get-WdlAstNodes {
    param($Ast, [System.Collections.ArrayList]$Into)
    if ($null -eq $Into) { $Into = New-Object System.Collections.ArrayList }
    if ($null -eq $Ast) { return $Into }
    [void]$Into.Add($Ast)
    switch ($Ast.T) {
        'Call' { foreach ($a in $Ast.Args) { [void](Get-WdlAstNodes $a $Into) } }
        'Member' { [void](Get-WdlAstNodes $Ast.Target $Into) }
        'Index' { [void](Get-WdlAstNodes $Ast.Target $Into); [void](Get-WdlAstNodes $Ast.Index $Into) }
    }
    , $Into
}

function Get-WdlAstDepth {
    param($Ast)
    if ($null -eq $Ast) { return 0 }
    switch ($Ast.T) {
        'Call' { $m = 0; foreach ($a in $Ast.Args) { $d = Get-WdlAstDepth $a; if ($d -gt $m) { $m = $d } }; return 1 + $m }
        'Member' { return 1 + (Get-WdlAstDepth $Ast.Target) }
        'Index' { return 1 + [Math]::Max((Get-WdlAstDepth $Ast.Target), (Get-WdlAstDepth $Ast.Index)) }
        default { return 1 }
    }
}

function Get-WdlExpressionsFromString {
    # Finds @expr (whole value) and @{expr} (interpolation) segments. '@@' is an escaped literal '@'.
    param([string]$Text)
    $res = @()
    if (-not $Text -or -not $Text.Contains('@')) { return $res }
    if ($Text[0] -eq '@' -and $Text.Length -gt 1 -and $Text[1] -ne '{' -and $Text[1] -ne '@') {
        return @([pscustomobject]@{ Text = $Text.Substring(1); Whole = $true; Error = $null })
    }
    $i = 0; $n = $Text.Length
    while ($i -lt $n) {
        if ($Text[$i] -ne '@') { $i++; continue }
        if ($i + 1 -ge $n) { break }
        if ($Text[$i + 1] -eq '@') { $i += 2; continue }
        if ($Text[$i + 1] -ne '{') { $i++; continue }
        $j = $i + 2; $depth = 0; $inStr = $false; $end = -1
        while ($j -lt $n) {
            $c = $Text[$j]
            if ($inStr) {
                if ($c -eq "'") { if ($j + 1 -lt $n -and $Text[$j + 1] -eq "'") { $j += 2; continue } else { $inStr = $false } }
            } else {
                if ($c -eq "'") { $inStr = $true }
                elseif ($c -eq '{') { $depth++ }
                elseif ($c -eq '}') { if ($depth -eq 0) { $end = $j; break } else { $depth-- } }
            }
            $j++
        }
        if ($end -lt 0) { $res += [pscustomobject]@{ Text = $Text.Substring($i + 2); Whole = $false; Error = "Unterminated @{ interpolation starting at position $i" }; break }
        $res += [pscustomobject]@{ Text = $Text.Substring($i + 2, $end - $i - 2); Whole = $false; Error = $null }
        $i = $end + 1
    }
    $res
}

function Get-NodeExpressionStrings {
    param($Node)
    $skip = @('actions', 'else', 'cases', 'default', 'runAfter', 'metadata')
    Get-JsonStrings -Value $Node.Def -SkipKeys $skip | Where-Object { $_.Value -and $_.Value.Contains('@') }
}

$Script:RefFunctions = @('body', 'outputs', 'actions', 'result', 'actionbody', 'actionoutputs')

function Get-ModelExpressionIssues {
    # Runs every expression check once per model (cached) and returns issue objects tagged with a Code (EXP-001..).
    param($Model)
    if ($Model.ExprCache) { return $Model.ExprCache.Issues }
    $issues = New-Object System.Collections.ArrayList
    $map = New-Object System.Collections.ArrayList
    foreach ($node in $Model.Nodes) {
        foreach ($s in @(Get-NodeExpressionStrings $node)) {
            foreach ($e in @(Get-WdlExpressionsFromString $s.Value)) {
                $entry = [pscustomobject]@{ Action = $node.Name; Type = $node.Type; Path = "$($node.Path) :: $($s.Path)"; Property = $s.Path; Expression = $e.Text; Whole = $e.Whole; Issues = @() }
                $found = New-Object System.Collections.ArrayList
                $add = {
                    param($Code, $Msg)
                    $iss = [pscustomobject]@{ Code = $Code; Node = $node; Path = $entry.Path; Property = $s.Path; Expression = $e.Text; Message = $Msg }
                    [void]$issues.Add($iss); [void]$found.Add($iss)
                }
                if ($e.Error) { & $add 'EXP-001' $e.Error; $entry.Issues = @($found); [void]$map.Add($entry); continue }
                $p = ConvertFrom-WdlExpression $e.Text
                if ($p.Error) { & $add 'EXP-001' $p.Error; $entry.Issues = @($found); [void]$map.Add($entry); continue }
                $nodes = Get-WdlAstNodes $p.Ast
                $upstream = Get-NodeUpstream $Model $node
                foreach ($a in $nodes) {
                    if ($a.T -ne 'Call') { continue }
                    $fn = $a.Name
                    $key = @($Script:WdlFunctions.Keys | Where-Object { $_ -ieq $fn })[0]
                    if (-not $key) { & $add 'EXP-002' "Unknown function '$fn' (check spelling; WDL function names are case-insensitive)."; continue }
                    $min = $Script:WdlFunctions[$key][0]; $max = $Script:WdlFunctions[$key][1]; $cnt = @($a.Args).Count
                    if ($cnt -lt $min -or ($max -ge 0 -and $cnt -gt $max)) {
                        $want = if ($max -lt 0) { "at least $min" } elseif ($min -eq $max) { "$min" } else { "$min-$max" }
                        & $add 'EXP-003' "$key() takes $want argument(s) but has $cnt."
                    }
                    $lk = $fn.ToLower()
                    $arg0 = if ($cnt -ge 1) { $a.Args[0] } else { $null }
                    $lit = if ($arg0 -and $arg0.T -eq 'Str') { $arg0.Value } else { $null }
                    if ($lk -in $Script:RefFunctions -and $null -ne $lit) {
                        if (-not $Model.ByName.ContainsKey($lit)) { & $add 'EXP-004' "$fn('$lit') refers to an action that does not exist." }
                        elseif ($lit -eq $node.Name) { & $add 'EXP-005' "$fn('$lit') refers to the action it is used in." }
                        elseif (-not $upstream.ContainsKey($lit) -and -not (Get-DescendantNodes $Model $node | Where-Object { $_.Name -eq $lit })) { & $add 'EXP-005' "$fn('$lit') refers to an action that is not guaranteed to run before '$($node.Name)' (not upstream via runAfter or an enclosing scope)." }
                    }
                    if ($lk -eq 'parameters' -and $null -ne $lit -and $Model.Parameters.Count -and ($Model.Parameters -notcontains $lit)) { & $add 'EXP-004' "parameters('$lit') is not declared in the workflow definition." }
                    if ($lk -eq 'variables' -and $null -ne $lit) {
                        if (-not $Model.Variables.ContainsKey($lit)) { & $add 'EXP-008' "variables('$lit') is never initialized (no Initialize variable action)." }
                        elseif (-not $upstream.ContainsKey($Model.Variables[$lit]) -and $Model.Variables[$lit] -ne $node.Name) { & $add 'EXP-008' "variables('$lit') is used before its Initialize variable action '$($Model.Variables[$lit])' has run." }
                    }
                    if ($lk -eq 'item' -and $cnt -eq 0) {
                        $inForeach = $false
                        foreach ($l in $node.Loops) { if ($Model.ByName[$l].Type -eq 'Foreach') { $inForeach = $true } }
                        if (-not $inForeach -and $node.Type -notin 'Query', 'Select', 'Table', 'Join') { & $add 'EXP-007' "item() is only valid inside Apply to each or a Filter/Select action; '$($node.Name)' is neither." }
                    }
                    if ($lk -eq 'items' -and $null -ne $lit) {
                        $enclosing = @($node.Loops | Where-Object { $Model.ByName[$_].Type -eq 'Foreach' })
                        if ($enclosing -notcontains $lit) { & $add 'EXP-007' "items('$lit') is not an enclosing Apply to each of '$($node.Name)'." }
                    }
                }
                # null-unsafe: non-safe access on the result of body()/outputs()/actions()...
                foreach ($a in $nodes) {
                    if (($a.T -eq 'Index' -or $a.T -eq 'Member') -and -not $a.Safe) {
                        $t = $a.Target; $viaDynamic = $false
                        while ($t) {
                            if ($t.T -eq 'Call') { if ($t.Name.ToLower() -in $Script:RefFunctions) { $viaDynamic = $true }; break }
                            if ($t.T -in 'Index', 'Member') { $t = $t.Target } else { break }
                        }
                        if ($viaDynamic) { & $add 'EXP-006' 'Property access is not null-safe; use ?[ ] (or coalesce) so a missing property does not fail the action.'; break }
                    }
                }
                $depth = Get-WdlAstDepth $p.Ast
                if ($depth -gt 8 -or $e.Text.Length -gt 500) { & $add 'EXP-009' "Expression is hard to read (nesting depth $depth, $($e.Text.Length) characters); split it into Compose steps." }
                $entry.Issues = @($found)
                [void]$map.Add($entry)
            }
        }
    }
    $Model.ExprCache = [pscustomobject]@{ Issues = @($issues); Map = @($map) }
    $Model.ExprCache.Issues
}

function Get-WdlExpressionMap {
<#
.SYNOPSIS Lists every expression / dynamic-content string in a workflow with its action, property path and any issues - the Code Inspector view.
#>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)]$Workflow)
    process {
        $Workflow.ExprCache = $null
        [void](Get-ModelExpressionIssues $Workflow)
        foreach ($e in $Workflow.ExprCache.Map) {
            [pscustomobject]@{ Action = $e.Action; Type = $e.Type; Property = $e.Property; Expression = $e.Expression; IssueCount = @($e.Issues).Count; Issues = (@($e.Issues | ForEach-Object { "$($_.Code): $($_.Message)" }) -join '; ') }
        }
    }
}

function New-ExpressionLogic {
    param([string]$Code, [string]$Description)
    $c = $Code
    Register-RuleLogic -Name ('Expr_' + $Code) -Description $Description -Script ({
            param($Rule, $Model, $D)
            Get-ModelExpressionIssues $Model | Where-Object { $_.Code -eq $c } | ForEach-Object { New-RuleHit -Node $_.Node -Message $_.Message -Evidence $_.Expression -Path $_.Path }
        }.GetNewClosure())
}

foreach ($code in 'EXP-001', 'EXP-002', 'EXP-003', 'EXP-004', 'EXP-005', 'EXP-006', 'EXP-007', 'EXP-008', 'EXP-009') { New-ExpressionLogic -Code $code -Description "Expression analysis $code" }

# COND-002: null-unsafe access inside condition expressions only.
Register-RuleLogic -Name 'ConditionNullUnsafe' -Description 'Null-unsafe property access inside If/Until/Switch/Filter conditions' -Script {
    param($Rule, $Model, $D)
    Get-ModelExpressionIssues $Model | Where-Object { $_.Code -eq 'EXP-006' -and $_.Node.Type -in 'If', 'Until', 'Switch', 'Query' -and $_.Property -match '^(expression|where)' } |
        ForEach-Object { New-RuleHit -Node $_.Node -Message "Condition reads a value without null protection: $($_.Message)" -Evidence $_.Expression -Path $_.Path }
}
