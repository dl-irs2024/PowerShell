# Workflow Rules Engine

A self-contained rules engine for Power Automate, Agent Flow and Azure Logic Apps workflow JSON, derived from the Code Review tab of `WpfPowerAutomateFailedRuns.ps1` and `Workflow_Inspector_Rules_Engine_ChatGPT_2026-11-24.v1.docx`. PowerShell 5.1 and 7 compatible. Nothing outside this folder is used or changed.

| Piece | File |
|---|---|
| Engine module (import, normalise, evaluate, report) | `RulesEngine.psm1` (+ `Detectors\`, `Renderers\`, `Simulation\`) |
| Command line | `Invoke-WorkflowRules.ps1` |
| Expression / WDL code inspector (CLI) | `Invoke-ExpressionInspector.ps1` |
| WPF Rules Tester (drop zone + Simulation mode) | `Show-RulesTester.ps1` (`New-RulesTesterView` = embeddable Grid) |
| WPF Rules Editor | `Show-RulesEditor.ps1` (`New-RulesEditorView` = embeddable TabControl) |
| Rules | `Rules\catalog.json`, `Rules\packs\*.json` |
| Registries (editors, categories, sources) | `Rules\editors.json`, `categories.json`, `sources.json` |
| JSON schemas | `Schemas\rule.schema.json`, `report.schema.json` |
| Samples (problem / model pairs) | `Samples\Problem`, `Samples\Model` |

## Command line

```powershell
.\Invoke-WorkflowRules.ps1 -Path .\Samples\Problem\01-connector-in-loop.json
.\Invoke-WorkflowRules.ps1 -Path flow.zip -Format Json,Html,Markdown,Csv -OutDir .\Reports
.\Invoke-WorkflowRules.ps1 -Url https://host/flow.json -Token $t -FailOn High   # exit code 1 if High+ found
Get-Content flow.json -Raw | .\Invoke-WorkflowRules.ps1 -Stdin
.\Invoke-WorkflowRules.ps1 -Path flow.json -Editor LogicApps -Category Looping -MinSeverity High -Suppress PA-ERR-004
.\Invoke-WorkflowRules.ps1 -ListRules -Editor AgentFlows
.\Invoke-WorkflowRules.ps1 -ValidateCatalog
```

Inputs: file, folder, `.zip` (Power Automate export), URL, raw JSON text or stdin. Accepted shapes: flow export (`properties.definition`), ARM template (Logic Apps), bare WDL definition.
In code: `Import-Workflow`, `Invoke-WorkflowRules`, `Export-RulesReport`.

## Rules

Format follows the Word document section 7 (`ruleId`, `ruleKey`, `ruleVersion`, `name`, `enabled`, `severity`, `categories`, `appliesTo`, `inspectionMode`, `detector`, `message`, `risk`, `remediation`, `documentation`) plus:

* `editors[]` - workflow editors the rule belongs to: `PowerAutomate`, `AgentFlows`, `LogicApps`, or any id added to `Rules\editors.json`. Empty = all.
* `source{sourceId,type,name,url}` - where the rule comes from (Microsoft Learn page, Internal, Community...). Ids come from `Rules\sources.json`.
* optional `likelihood` / `impact` (1-5). Risk score = L x I: Low 1-4, Moderate 5-9, High 10-14, Very High 15-19, Critical 20-25.

The catalog seeds the 42 rules of the document plus `SEC-001` and `EXP-001..009`. Rules whose `detector.logic` is registered run (`Implemented`); the others (runtime telemetry, connection health, solution membership) are reported under `notEvaluated` as `Planned`.

**Extending**
* New rules / categories: add a pack file `Rules\packs\<name>.json` (`{ "rules": [ ... ] }`) or use the Rules Editor; add categories to `categories.json`.
* New workflow editor: add an entry to `editors.json`, then tag rules with its id.
* New detector: `Register-RuleLogic -Name 'MyLogic' -Script { param($Rule,$Model,$D) ... New-RuleHit -Node $n -Message '...' }` in a new `Detectors\*.ps1`, then reference `"logic": "MyLogic"` in a rule.
* New output format: `Register-ReportRenderer`. Excel, Word and PDF are stubs that say so (export Json/Html and convert, or register a renderer).

## Reports

`Invoke-WorkflowRules` returns a report object (`Schemas\report.schema.json`): `reportId` (`RPT-yyyyMMdd-HHmmss-XXXXXX`), engine and catalog versions, workflow identity and SHA-256, summary (health score, per-category scores, risk), findings (`<reportId>-Fnnn`), suppressions and `notEvaluated`. Formats: Json, Html, Markdown, Csv.

## Rules Tester (WPF)

`.\Show-RulesTester.ps1` - drag-drop JSON/ZIP, Browse, URL (+ bearer token), paste JSON, filters (editor / severity / category), findings with detail, expression grid, export. **Simulation mode** lists the problem/model pairs, runs either side, compares them (rules fixed by the model) and generates new defective workflows by injecting defects (no error handling, delay in loop, nested loop, unlimited concurrency, bad expression, hard-coded secret, retry storm) into a model sample. CLI equivalents: `Get-SamplePairs`, `Compare-SamplePair`, `New-SimulatedWorkflow`.

## Rules Editor (WPF)

`.\Show-RulesEditor.ps1 [-RulesPath dir]` - search/filter, edit every rule field, multi-select editors, categories and appliesTo, pick or type a rule source, detector logic and JSON params, live risk score, validation (`Test-RuleDefinition`), New / Clone / Delete, "Test rule on sample", Save (writes each rule back to its own file, `.bak` backup, catalog patch version bump) and a Registries tab for editors / categories / sources.

## Expression and WDL Code Inspector

Yes - it is possible, and a first cut is included. `Detectors\Expression.ps1` contains a real tokenizer/parser for WDL expressions (`@expr`, `@{interpolation}`, `@@` escapes, member / index / `?[ ]` access). `Invoke-ExpressionInspector.ps1 -Path flow.json [-IssuesOnly]` lists every expression with its action and property path and its issues:

| Id | Check |
|---|---|
| EXP-001 | syntax error (quotes, parentheses, brackets) |
| EXP-002 / 003 | unknown function / wrong argument count |
| EXP-004 / 005 | reference to a missing action or parameter / to an action that is not upstream |
| EXP-006 | null-unsafe property access (suggest `?[ ]` / `coalesce`) |
| EXP-007 | `item()` / `items()` outside its loop |
| EXP-008 | variable used but never initialised |
| EXP-009 | expression too complex / deeply nested |

Roadmap: JSON-schema validation of the whole WDL document (`$schema` 2016-06-01), runAfter cycle / orphan checks, type inference for function arguments, a "friendly view" that renders dynamic content as `Action > Field` with highlighting in the Tester, Power Fx support for Power Apps / Agent Flows, and a Monaco-style editor with squiggles using the same issue list.

## Verified

Run on Windows PowerShell 5.1 and pwsh 7: all samples, the CLI (all formats, `-FailOn`, `-ValidateCatalog`), and the Tester and Editor views driven headlessly. Model samples produce 0 findings; problem samples trigger their intended rules.
