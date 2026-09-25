## Update Log - 2026-07-25 Saturday 19:33:27


### Appended Chat Output (Preserved Formatting)

Updated Animations/HtmlTocSample1.html with substantially more scroll content and many more headers so you can test limits better.

What I changed:
1. Expanded the TOC from 4 links to a full vertical nav covering:
- Preamble
- Articles I through VII
- Individual section anchors (for Articles I-IV)
- Extra stress-test note section

2. Replaced placeholder body content with long Constitution-based text:
- Added large sections for each article and section
- Kept many distinct headings so scrollspy has frequent active-link transitions
- Added source note that this is adapted from the U.S. Constitution transcript (public domain)

3. Kept your existing behavior unchanged:
- Sticky TOC
- Smooth scrolling
- IntersectionObserver active-highlight logic

If you want literal full verbatim transcript (including all signer blocks and all original phrasing exactly as transcribed), I can do a second pass and paste the complete text end-to-end into this same file.

### Change Summary

1. Added long-form content to test deep scrolling and TOC behavior.
2. Increased heading density to trigger more active-link updates while scrolling.
3. Preserved original layout and JavaScript behavior.

### Key File Size and Line Summary

| File | Size (KB) | Lines |
|---|---:|---:|
| HtmlTocSample1.html | 18.65 | 429 |
| HtmlToc.md | 1.62 | 30 |

### Notes

1. Metrics above were refreshed after writing this update entry.
2. For each future update in this file, include an updated timestamp and refreshed size/line metrics for key files.

---

## Reusable Update Template

Copy from here for each new update:

## Update Log - YYYY-MM-DD DayOfWeek HH:mm:ss

### Appended Chat Output (Preserved Formatting)

Paste the prior chat output exactly as shown in chat.

### Change Summary

1. <Change 1>
2. <Change 2>
3. <Change 3>

### Key File Size and Line Summary

| File | Size (KB) | Lines |
|---|---:|---:|
| HtmlTocSample1.html | <KB> | <Lines> |
| HtmlToc.md | <KB> | <Lines> |

### Notes

1. Metrics above were refreshed after writing this update entry.
2. Timestamp includes day of week.
3. Add additional key files as needed for this update.

### Tiny PowerShell Helper

Run this from the repo root to generate a timestamp and Markdown table rows:

```powershell
$files = @(
	'Animations/HtmlTocSample1.html',
	'Animations/HtmlToc.md'
)

$timestamp = Get-Date -Format 'yyyy-MM-dd dddd HH:mm:ss'
"## Update Log - $timestamp"
""
"| File | Size (KB) | Lines |"
"|---|---:|---:|"

foreach ($f in $files) {
	if (Test-Path $f) {
		$item = Get-Item $f
		$kb = [math]::Round($item.Length / 1KB, 2)
		$lines = (Get-Content $f | Measure-Object -Line).Lines
		"| $f | $kb | $lines |"
	}
}
```

### Tiny PowerShell Helper (Clipboard Scaffold)

Run this from the repo root to build the full update scaffold and copy it to clipboard:

```powershell
$files = @(
	'Animations/HtmlTocSample1.html',
	'Animations/HtmlToc.md'
)

$timestamp = Get-Date -Format 'yyyy-MM-dd dddd HH:mm:ss'

$rows = foreach ($f in $files) {
	if (Test-Path $f) {
		$item = Get-Item $f
		$kb = [math]::Round($item.Length / 1KB, 2)
		$lines = (Get-Content $f | Measure-Object -Line).Lines
		"| $f | $kb | $lines |"
	}
}

$scaffold = @"
## Update Log - $timestamp

### Appended Chat Output (Preserved Formatting)

<Paste prior chat output here>

### Change Summary

1. <Change 1>
2. <Change 2>
3. <Change 3>

### Key File Size and Line Summary

| File | Size (KB) | Lines |
|---|---:|---:|
$(($rows -join [Environment]::NewLine))

### Notes

1. Metrics above were refreshed after writing this update entry.
2. Timestamp includes day of week.
3. Add additional key files as needed for this update.
"@

$scaffold | Set-Clipboard
"Scaffold copied to clipboard."
```

## Update Log - 2026-07-25 Saturday 20:48:23

### Appended Chat Output (Preserved Formatting)

Done. Added both companion files and validated them end-to-end.

Created:
1. [Animations/HtmlToc.Sections.Example.json](Animations/HtmlToc.Sections.Example.json)
- Structured sample sections for `-SectionsPath`
- Includes:
	- paragraphs
	- bullet/numbered lists
	- code block
	- table
	- custom HTML block
	- multi-level `Level` values

2. [Animations/RunHtmlTocFromJson.cmd](Animations/RunHtmlTocFromJson.cmd)
- One-line launcher command:
- Runs [Animations/HtmlToc.ps1](Animations/HtmlToc.ps1) with the JSON file
- Outputs [Animations/HtmlToc.FromJson.html](Animations/HtmlToc.FromJson.html)
- Enables:
	- section nav links
	- multi-level TOC
	- collapsible TOC
	- collapsible sections
	- open sections by default

Validation:
- Executed the CMD successfully.
- Output generated: [Animations/HtmlToc.FromJson.html](Animations/HtmlToc.FromJson.html)

If you want, I can also add a second `.cmd` variant that takes a JSON path argument (`RunHtmlTocFromJson.cmd "MySections.json"`).

### Change Summary

1. Added a JSON-based companion input file for the HtmlToc framework.
2. Added a one-line CMD launcher for JSON-driven generation.
3. Validated generation by running the launcher and confirming output HTML creation.

### Key File Size and Line Summary

| File | Size (KB) | Lines |
|---|---:|---:|
| Animations/HtmlToc.ps1 | 20.55 | 610 |
| Animations/HtmlToc.Sections.Example.json | 1.80 | 63 |
| Animations/RunHtmlTocFromJson.cmd | 0.32 | 2 |
| Animations/HtmlToc.FromJson.html | 10.78 | 328 |
| Animations/HtmlTocSample1.html | 18.65 | 429 |
| Animations/HtmlToc.md | 5.74 | 150 |

### Notes

1. Timestamp includes day of week.
2. Metrics above were refreshed after appending this entry.
3. Keep this same structure for each future update block.

## Update Log - Monday 2026-07-27 01:39:24

### Appended Chat Output (Preserved Formatting)

User:
the up Triangle or arrow to collape should have green background removed.
The down Triangle has no visible animation, maybe make it blink.

Assistant:
Updated as requested in [ToC.DL/HtmlToc.ps1](ToC.DL/HtmlToc.ps1).

What changed
1. Up triangle (expanded state) no longer green
- `aria-expanded="true"` now uses neutral styling (white background, normal border/text).
- Hover also stays neutral.

2. Down triangle (collapsed state) now visibly blinks
- `aria-expanded="false"` now uses a stronger blink/pulse animation:
- opacity pulse
- brightness bump
- subtle ring/shadow pulse
- Faster cycle (~1.15s) so it is clearly noticeable.

Validation
- No errors after update.

### Change Summary

1. Updated collapse button CSS states so expanded (up-arrow) is neutral and collapsed (down-arrow) uses a clear blink cue.
2. Previously added styling remained in place: light blue backgrounds for section number badge and small Top link, plus right-docked responsive search panel controls.
3. Expanded PowerShell 7.x stress sample with repeated appendix command catalog sections per release, pushing sample size past 60 sections.

### Key File Size and Line Summary

| File | Size (KB) | Lines |
|---|---:|---:|
| ToC.DL/HtmlToc.ps1 | 49.65 | 1369 |
| ToC.DL/HtmlToc.Test.ps1 | 63.13 | 1195 |
| ToC.DL/HtmlToc.md | 7.33 | 183 |

### Notes

1. Timestamp includes day of week.
2. Metrics above were refreshed after appending this entry.
3. Continue appending future updates using this same section structure.
