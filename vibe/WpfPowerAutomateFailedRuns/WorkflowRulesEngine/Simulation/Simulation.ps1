#region Simulation: problem/model sample pairs and generated defects
function Get-SamplePairs {
<#
.SYNOPSIS Pairs Samples\Problem\NN-*.json with Samples\Model\NN-*.json by their numeric prefix.
#>
    [CmdletBinding()]
    param([string]$SamplesPath = (Join-Path $Script:EngineRoot 'Samples'))
    $model = @{}
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $SamplesPath 'Model') -Filter '*.json' -ErrorAction SilentlyContinue) { $model[($f.Name -split '-')[0]] = $f }
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $SamplesPath 'Problem') -Filter '*.json' -ErrorAction SilentlyContinue | Sort-Object Name) {
        $k = ($f.Name -split '-')[0]
        [pscustomobject]@{ Id = $k; Title = ($f.BaseName -replace '^\d+-', ''); ProblemPath = $f.FullName; ModelPath = $(if ($model[$k]) { $model[$k].FullName } else { $null }) }
    }
}

function Compare-SamplePair {
<#
.SYNOPSIS Runs the rules on the problem and model workflow of a pair and returns both reports plus the rule IDs the model fixed.
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Pair, $Catalog, [string]$RulesPath)
    if (-not $Catalog) { $Catalog = Get-RuleCatalog -RulesPath $RulesPath }
    $bad = Invoke-WorkflowRules -Workflow (Import-Workflow -Path $Pair.ProblemPath) -Catalog $Catalog
    $good = if ($Pair.ModelPath) { Invoke-WorkflowRules -Workflow (Import-Workflow -Path $Pair.ModelPath) -Catalog $Catalog }
    $badIds = @($bad.findings | ForEach-Object ruleId | Sort-Object -Unique)
    $goodIds = if ($good) { @($good.findings | ForEach-Object ruleId | Sort-Object -Unique) } else { @() }
    [pscustomobject]@{ Pair = $Pair; Problem = $bad; Model = $good; Fixed = @($badIds | Where-Object { $goodIds -notcontains $_ }); Remaining = $goodIds }
}

$Script:SimulationDefects = @(
    @{ Id = 'NoErrorHandling'; Description = 'Remove Try/Catch scopes and Terminate actions' }
    @{ Id = 'DelayInLoop'; Description = 'Add an Apply to each that waits and calls an API per item' }
    @{ Id = 'NestedLoop'; Description = 'Add nested Apply to each loops with connector calls' }
    @{ Id = 'UnlimitedConcurrency'; Description = 'Remove trigger concurrency limit and add a write action' }
    @{ Id = 'BadExpression'; Description = 'Add actions with unknown function, bad syntax, null-unsafe access and missing references' }
    @{ Id = 'HardcodedSecret'; Description = 'Add an HTTP action with a hard-coded bearer token and environment URL' }
    @{ Id = 'ExcessiveRetry'; Description = 'Add a POST with a very high retry count and no idempotency key' }
)
function Get-SimulationDefects { $Script:SimulationDefects | ForEach-Object { [pscustomobject]$_ } }

function Get-DefinitionObject {
    param($Root)
    if ($Root.properties -and $Root.properties.definition) { return $Root.properties.definition }
    if ($Root.resources) { foreach ($r in $Root.resources) { if ($r.properties.definition) { return $r.properties.definition } } }
    if ($Root.definition) { return $Root.definition }
    $Root
}

function Add-DefinitionAction {
    param($Definition, [string]$Name, $Body)
    if (-not $Definition.PSObject.Properties['actions']) { $Definition | Add-Member -NotePropertyName actions -NotePropertyValue ([pscustomobject]@{}) }
    $Definition.actions | Add-Member -NotePropertyName $Name -NotePropertyValue $Body -Force
}

function New-SimulatedWorkflow {
<#
.SYNOPSIS Takes a workflow (usually a Model sample) and injects well-known defects, returning a new workflow object ready for Invoke-WorkflowRules.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('NoErrorHandling', 'DelayInLoop', 'NestedLoop', 'UnlimitedConcurrency', 'BadExpression', 'HardcodedSecret', 'ExcessiveRetry')][string[]]$Defect,
        [switch]$AsJson
    )
    $root = (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Json
    $def = Get-DefinitionObject $root
    $http = { param($m, $u, $extra) $o = [ordered]@{ method = $m; uri = $u }; foreach ($k in $extra.Keys) { $o[$k] = $extra[$k] }; [pscustomobject]@{ runAfter = [pscustomobject]@{}; type = 'Http'; inputs = [pscustomobject]$o } }
    foreach ($d in $Defect) {
        switch ($d) {
            'NoErrorHandling' {
                foreach ($p in @($def.actions.PSObject.Properties)) {
                    $ra = $p.Value.runAfter
                    $failed = $ra -and (@($ra.PSObject.Properties | ForEach-Object { $_.Value }) -match 'Failed|TimedOut')
                    if ($failed -or $p.Value.type -eq 'Terminate') { $def.actions.PSObject.Properties.Remove($p.Name) }
                }
            }
            'DelayInLoop' {
                Add-DefinitionAction $def 'Sim_Loop_With_Delay' ([pscustomobject]@{
                        runAfter = [pscustomobject]@{}; type = 'Foreach'; foreach = '@createArray(1,2,3)'
                        actions = [pscustomobject]@{
                            Sim_Pause = [pscustomobject]@{ runAfter = [pscustomobject]@{}; type = 'Wait'; inputs = [pscustomobject]@{ interval = [pscustomobject]@{ count = 30; unit = 'Second' } } }
                            Sim_Lookup = (& $http 'GET' 'https://api.contoso.com/lookup' @{ })
                        }
                    })
            }
            'NestedLoop' {
                Add-DefinitionAction $def 'Sim_Outer_Loop' ([pscustomobject]@{
                        runAfter = [pscustomobject]@{}; type = 'Foreach'; foreach = '@createArray(1,2,3)'
                        actions = [pscustomobject]@{
                            Sim_Inner_Loop = [pscustomobject]@{
                                runAfter = [pscustomobject]@{}; type = 'Foreach'; foreach = '@createArray(4,5,6)'
                                actions = [pscustomobject]@{ Sim_Mail = [pscustomobject]@{ runAfter = [pscustomobject]@{}; type = 'OpenApiConnection'
                                        inputs = [pscustomobject]@{ host = [pscustomobject]@{ connectionName = 'shared_office365'; operationId = 'SendEmailV2'; apiId = '/providers/Microsoft.PowerApps/apis/shared_office365' }
                                            parameters = [pscustomobject]@{ 'emailMessage/To' = 'a@contoso.com'; 'emailMessage/Subject' = "@{items('Sim_Inner_Loop')}" } } } }
                            }
                        }
                    })
            }
            'UnlimitedConcurrency' {
                foreach ($t in @($def.triggers.PSObject.Properties)) { if ($t.Value.PSObject.Properties['runtimeConfiguration']) { $t.Value.PSObject.Properties.Remove('runtimeConfiguration') } }
                Add-DefinitionAction $def 'Sim_Write' (& $http 'POST' 'https://api.contoso.com/records' @{ body = 'x'; retryPolicy = [pscustomobject]@{ type = 'none' } })
            }
            'BadExpression' {
                $c = { param($e) [pscustomobject]@{ runAfter = [pscustomobject]@{}; type = 'Compose'; inputs = $e } }
                Add-DefinitionAction $def 'Sim_Unknown_Function' (& $c '@toUpperCase(triggerBody()?[''name''])')
                Add-DefinitionAction $def 'Sim_Bad_Syntax' (& $c "@formatDateTime(utcNow(), 'yyyy-MM-dd'")
                Add-DefinitionAction $def 'Sim_Unsafe_Access' (& $c "@body('Sim_Unknown_Function')['name']")
                Add-DefinitionAction $def 'Sim_Missing_Reference' (& $c "@outputs('Does_Not_Exist')")
            }
            'HardcodedSecret' {
                Add-DefinitionAction $def 'Sim_Secret_Call' (& $http 'GET' 'https://org9f8e7d.crm.dynamics.com/api/data/v9.2/accounts' @{ headers = [pscustomobject]@{ Authorization = 'Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dummysignaturevalue1234567890' }; retryPolicy = [pscustomobject]@{ type = 'none' } })
            }
            'ExcessiveRetry' {
                Add-DefinitionAction $def 'Sim_Retry_Storm' (& $http 'POST' 'https://api.contoso.com/payments' @{ body = 'x'; retryPolicy = [pscustomobject]@{ type = 'fixed'; count = 90; interval = 'PT1S' } })
            }
        }
    }
    $text = $root | ConvertTo-Json -Depth 60
    if ($AsJson) { return $text }
    Import-Workflow -Json $text
}
#endregion
