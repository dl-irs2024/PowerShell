# RulesEngine.Chat.md

Verbatim chat log for the Workflow Rules Engine work. Newest entries are appended at the bottom.

---

## Prompt — 12:42 AM 11/28/2026 SAT

[[PLAN]] Work in this path or sub-folders C:\Davis\vibe\Power-Automate\WpfPowerAutomateFailedRuns\WorkflowRulesEngine
Don't change the parent or sibling folders.
using the Code Review tab from
C:\Davis\vibe\Power-Automate\WpfPowerAutomateFailedRuns\WpfPowerAutomateFailedRuns.ps1
....
and considering the Microsoft Word document
WpfPowerAutomateFailedRuns\WorkflowRulesEngine\Workflow_Inspector_Rules_Engine_ChatGPT_2026-11-24.v1.docx

Extract a new Commandline Rules engine that checks a JSON Power Automate workflow.
The JSON file can be on local disk or streamed or referenced via a URL.

There should be a new WPF Rules Tester - that can eventually be a tab or part of a WPF UI.  The Rules Tester should have a drag and drop area - that allows local Workflow JSON files to be dropped.
A similar Simulation mode should show or generate a rich range of workflows that have common issues plus a complementary set of model / refined workflows that shows how to correctly write workflows.

There should be new WPF Rules Editor.
Rules can be stored in JSON format - locally and eventually part of a database.
The Word document mentions rules and categories. And that there should be Report IDs as well. Reports can just be JSON as well with options for output to HTML, Excel or Word and PDF formats.
The Rules Editor should be extensible - for specific rules and categories of rules.
The Rule should indicate what workflow editor is belongs to - Power Automate, Agent Flows, Azure Logic Apps or any future workflow editor.


Rules should have format specified in the Word document.
There should be also some rule source - that is, if already defined at Microsoft.com sites or Power Automate or Azure Logic Apps.

Separately - is it possible to have a Code Inspector for the Expressions in Workflows? and also the WDL Workflow Definition Language?
The Expressions and Dynamic Content are unwieldy and hard to see issues.

### Clarifications chosen in the planning questionnaire

- Implementation stack: PowerShell 5.1-compatible module + CLI script + WPF (matches existing app)
- Report output formats: JSON + HTML + Markdown now; Excel/Word/PDF as stubs for later
- Expression / WDL Code Inspector: answer + design in plan; build a first-cut CLI expression linter (tokenizer, function/arity checks, null-safety, unbalanced quotes) as a rule detector type
- Initial rule catalog: seed all ~50 rules from the Word doc as JSON (implement detectors for rules mappable to existing checks; rest 'Planned')
