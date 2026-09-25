<#
.SYNOPSIS
Builds a standalone HTML document from structured sections with a left TOC.

.DESCRIPTION
HtmlToc.ps1 is a small framework for generating long-form standalone HTML pages.
It accepts structured section objects and supports:

1. Per-section content blocks (paragraphs, lists, code blocks, tables, custom HTML).
2. Top/Previous/Next intralinks for each section header.
3. Multi-level headers with nested TOC.
4. Collapsible left TOC.
5. Collapsible section content.
6. Optional small Top link after each section.

.PARAMETER Sections
Array of section objects. See "SECTION OBJECT SHAPE" below.

.PARAMETER SectionsPath
Optional JSON file path containing an array of section objects.

.PARAMETER Title
Page title.

.PARAMETER OutputPath
Output HTML file path.

.PARAMETER EnableSectionNavLinks
Adds Top / Previous / Next intralinks to each section header.

.PARAMETER SectionNavMode
Display mode for section intralinks.
text  = Top | Previous | Next labels
icons = arrows/icons (&uarr;, &larr;, &rarr;)

.PARAMETER SectionNavIconNumberPlacement
Controls number placement for icon-mode Previous/Next links.
arrow-before-number = &larr; 1.2 and &rarr; 1.2
number-before-arrow = 1.2 &larr; and 1.2 &rarr;

.PARAMETER EnableMultiLevelToc
Uses each section Level (1-6) to build nested TOC lists.

.PARAMETER EnableCollapsibleToc
Adds a left-rail toggle button to collapse or expand the TOC.

.PARAMETER EnableCollapsibleSections
Makes each section header clickable to collapse or expand its content.

.PARAMETER EnableTopLinkAfterSection
Adds a small Top link after each section body.

.PARAMETER EnableSectionHeadingNumbering
Adds hierarchical numbering to section headings based on heading level.
Examples: 1, 1.1, 1.1.1

.PARAMETER TocPlacement
Controls TOC placement:
left = left column TOC
top  = top TOC above content

.PARAMETER EnableFloatingToc
When true, TOC uses sticky/floating positioning.

.PARAMETER KeepLeftTocOnNarrowScreens
Keeps the TOC in the left column on narrow screens instead of stacking on top.

.PARAMETER OpenSectionsByDefault
When collapsible sections are enabled, content starts expanded.

.PARAMETER DocumentDescription
Optional subtitle shown below the title.

.PARAMETER AdditionalCss
Optional extra CSS appended at the end of the style block.

.PARAMETER PassThru
Returns the output file info object.

.EXAMPLE
$sections = @(
    [pscustomobject]@{
        Id         = 'intro'
        Title      = 'Introduction'
        Level      = 1
        Paragraphs = @('This is a generated page.', 'It supports long content.')
    },
    [pscustomobject]@{
        Id      = 'sample-table'
        Title   = 'Table Example'
        Level   = 2
        Table   = [pscustomobject]@{
            Columns = @('Name', 'Value')
            Rows    = @(
                @{ Name = 'Alpha'; Value = '10' },
                @{ Name = 'Beta';  Value = '20' }
            )
        }
    }
)

.
\HtmlToc.ps1 -Sections $sections -Title 'Demo' -OutputPath '.\HtmlTocDemo.html' -EnableSectionNavLinks -EnableMultiLevelToc -EnableCollapsibleToc -EnableCollapsibleSections -OpenSectionsByDefault

.EXAMPLE
.
\HtmlToc.ps1 -SectionsPath '.\sections.json' -OutputPath '.\FromJson.html' -EnableSectionNavLinks -SectionNavMode icons

SECTION OBJECT SHAPE
--------------------
Each section object may include:

Id           : string  (required unique anchor id)
Title        : string  (required)
Level        : int     (optional; default 1; range 1..6)
Paragraphs   : string[]
Bullets      : string[]
Numbered     : string[]
CodeBlocks   : string[]
Table        : object  (optional)
              Table.Columns = string[]
              Table.Rows    = array of hashtables or arrays
Html         : string  (optional raw HTML block)

NOTES
-----
1. For SectionNavMode icons, HTML entities are used for broad compatibility.
2. This script is PowerShell 5.1 compatible.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [object[]]$Sections,

    [Parameter(Mandatory = $false)]
    [string]$SectionsPath,

    [Parameter(Mandatory = $false)]
    [string]$Title = 'HTML TOC Document',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = '.\HtmlToc.Output.html',

    [Parameter(Mandatory = $false)]
    [switch]$EnableSectionNavLinks,

    [Parameter(Mandatory = $false)]
    [ValidateSet('text', 'icons')]
    [string]$SectionNavMode = 'icons',

    [Parameter(Mandatory = $false)]
    [ValidateSet('arrow-before-number', 'number-before-arrow')]
    [string]$SectionNavIconNumberPlacement = 'arrow-before-number',

    [Parameter(Mandatory = $false)]
    [switch]$EnableMultiLevelToc,

    [Parameter(Mandatory = $false)]
    [switch]$EnableCollapsibleToc,

    [Parameter(Mandatory = $false)]
    [switch]$EnableCollapsibleSections,

    [Parameter(Mandatory = $false)]
    [switch]$EnableTopLinkAfterSection,

    [Parameter(Mandatory = $false)]
    [switch]$EnableSectionHeadingNumbering,

    [Parameter(Mandatory = $false)]
    [ValidateSet('left', 'top')]
    [string]$TocPlacement = 'left',

    [Parameter(Mandatory = $false)]
    [bool]$EnableFloatingToc = $true,

    [Parameter(Mandatory = $false)]
    [switch]$KeepLeftTocOnNarrowScreens,

    [Parameter(Mandatory = $false)]
    [switch]$OpenSectionsByDefault,

    [Parameter(Mandatory = $false)]
    [string]$DocumentDescription,

    [Parameter(Mandatory = $false)]
    [string]$AdditionalCss,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru
)

Set-StrictMode -Version 2

function ConvertTo-HtmlSafe {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Get-ObjectValue {
  param(
    [Parameter(Mandatory = $true)][object]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if ($null -eq $Object) { return $null }
  $prop = $Object.PSObject.Properties[$Name]
  if ($prop) { return $prop.Value }
  return $null
}

function Get-HeadingTag {
    param([int]$Level)
    $safe = [Math]::Min([Math]::Max($Level, 1), 6)
    return "h$safe"
}

function New-SectionNavHtml {
    param(
        [int]$Index,
        [object[]]$AllSections,
    [ValidateSet('text', 'icons')][string]$Mode,
    [ValidateSet('arrow-before-number', 'number-before-arrow')][string]$IconNumberPlacement = 'arrow-before-number'
    )

    $top = '<a href="#page-top" class="section-nav-link" title="Back to top">Top</a>'
    $prev = ''
    $next = ''

    function Get-DisplayTitle {
      param([Parameter(Mandatory = $true)][object]$Section)

      $numberLabel = [string](Get-ObjectValue -Object $Section -Name 'NumberLabel')
      $title = [string]$Section.Title
      if ([string]::IsNullOrWhiteSpace($numberLabel)) {
        return $title
      }

      return ('{0} {1}' -f $numberLabel, $title)
    }

    if ($Index -gt 0) {
        $prevNumber = [string](Get-ObjectValue -Object $AllSections[$Index - 1] -Name 'NumberLabel')
        $prevId = ConvertTo-HtmlSafe -Text ([string]$AllSections[$Index - 1].Id)
      $prevTitle = ConvertTo-HtmlSafe -Text (Get-DisplayTitle -Section $AllSections[$Index - 1])
        $prevTooltip = 'Previous: {0}' -f $prevTitle
      $prev = '<a href="#{0}" class="section-nav-link" title="{1}">Previous</a>' -f $prevId, $prevTooltip
    }

    if ($Index -lt ($AllSections.Count - 1)) {
        $nextNumber = [string](Get-ObjectValue -Object $AllSections[$Index + 1] -Name 'NumberLabel')
        $nextId = ConvertTo-HtmlSafe -Text ([string]$AllSections[$Index + 1].Id)
      $nextTitle = ConvertTo-HtmlSafe -Text (Get-DisplayTitle -Section $AllSections[$Index + 1])
        $nextTooltip = 'Next: {0}' -f $nextTitle
      $next = '<a href="#{0}" class="section-nav-link" title="{1}">Next</a>' -f $nextId, $nextTooltip
    }
  
    if ($Mode -eq 'icons') {
        $top = '<a href="#page-top" class="section-nav-link" title="Back to top">&uarr;</a>'
      if ($prev) {
        $prevNumberHtml = ''
        if (-not [string]::IsNullOrWhiteSpace($prevNumber)) {
          $prevNumberHtml = '<span class="section-nav-number">{0}</span>' -f (ConvertTo-HtmlSafe $prevNumber)
        }
        if ([string]::IsNullOrWhiteSpace($prevNumberHtml)) {
            $prev = '<a href="#{0}" class="section-nav-link" title="{1}">&larr;</a>' -f $prevId, $prevTooltip
        }
        elseif ($IconNumberPlacement -eq 'number-before-arrow') {
            $prev = '<a href="#{0}" class="section-nav-link" title="{1}">{2} &larr;</a>' -f $prevId, $prevTooltip, $prevNumberHtml
        }
        else {
            $prev = '<a href="#{0}" class="section-nav-link" title="{1}">&larr; {2}</a>' -f $prevId, $prevTooltip, $prevNumberHtml
        }
      }
      if ($next) {
        $nextNumberHtml = ''
        if (-not [string]::IsNullOrWhiteSpace($nextNumber)) {
          $nextNumberHtml = '<span class="section-nav-number">{0}</span>' -f (ConvertTo-HtmlSafe $nextNumber)
        }
        if ([string]::IsNullOrWhiteSpace($nextNumberHtml)) {
            $next = '<a href="#{0}" class="section-nav-link" title="{1}">&rarr;</a>' -f $nextId, $nextTooltip
        }
        elseif ($IconNumberPlacement -eq 'number-before-arrow') {
            $next = '<a href="#{0}" class="section-nav-link" title="{1}">{2} &rarr;</a>' -f $nextId, $nextTooltip, $nextNumberHtml
        }
        else {
            $next = '<a href="#{0}" class="section-nav-link" title="{1}">&rarr; {2}</a>' -f $nextId, $nextTooltip, $nextNumberHtml
        }
      }
    }

    return '<span class="section-nav">{0} {1} {2}</span>' -f $top, $prev, $next
}

  function New-SectionTopLinkHtml {
    return '<div class="section-top-link-wrap"><a href="#page-top" class="section-top-link" title="Back to top">Top</a></div>'
  }

function ConvertTo-SectionTableHtml {
    param([object]$Table)

    if ($null -eq $Table) { return '' }
    if (-not $Table.Columns -or -not $Table.Rows) { return '' }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<div class="table-wrap">')
    [void]$sb.AppendLine('<table>')
    [void]$sb.AppendLine('<thead><tr>')

    foreach ($col in $Table.Columns) {
        [void]$sb.AppendLine("<th>$(ConvertTo-HtmlSafe $col)</th>")
    }

    [void]$sb.AppendLine('</tr></thead>')
    [void]$sb.AppendLine('<tbody>')

    foreach ($row in $Table.Rows) {
        [void]$sb.AppendLine('<tr>')
        foreach ($col in $Table.Columns) {
            $val = ''
            if ($row -is [hashtable] -or $row -is [pscustomobject]) {
                $prop = $row.PSObject.Properties[$col]
                if ($prop) { $val = [string]$prop.Value }
            }
            elseif ($row -is [System.Array]) {
                $idx = [Array]::IndexOf($Table.Columns, $col)
                if ($idx -ge 0 -and $idx -lt $row.Count) { $val = [string]$row[$idx] }
            }
            [void]$sb.AppendLine("<td>$(ConvertTo-HtmlSafe $val)</td>")
        }
        [void]$sb.AppendLine('</tr>')
    }

    [void]$sb.AppendLine('</tbody>')
    [void]$sb.AppendLine('</table>')
    [void]$sb.AppendLine('</div>')
    return $sb.ToString()
}

function ConvertTo-SectionBodyHtml {
    param([object]$Section)

    $sb = New-Object System.Text.StringBuilder

    if ($Section.Paragraphs) {
        foreach ($p in $Section.Paragraphs) {
            [void]$sb.AppendLine("<p>$(ConvertTo-HtmlSafe $p)</p>")
        }
    }

    if ($Section.Bullets) {
        [void]$sb.AppendLine('<ul>')
        foreach ($item in $Section.Bullets) {
            [void]$sb.AppendLine("<li>$(ConvertTo-HtmlSafe $item)</li>")
        }
        [void]$sb.AppendLine('</ul>')
    }

    if ($Section.Numbered) {
        [void]$sb.AppendLine('<ol>')
        foreach ($item in $Section.Numbered) {
            [void]$sb.AppendLine("<li>$(ConvertTo-HtmlSafe $item)</li>")
        }
        [void]$sb.AppendLine('</ol>')
    }

    if ($Section.CodeBlocks) {
        foreach ($code in $Section.CodeBlocks) {
            [void]$sb.AppendLine("<pre><code>$(ConvertTo-HtmlSafe $code)</code></pre>")
        }
    }

    if ($Section.Table) {
        [void]$sb.AppendLine((ConvertTo-SectionTableHtml -Table $Section.Table))
    }

    if ($Section.Html) {
        [void]$sb.AppendLine([string]$Section.Html)
    }

    return $sb.ToString()
}

function Build-TocHtml {
    param(
        [object[]]$AllSections,
        [switch]$UseMultiLevel
    )

    $sb = New-Object System.Text.StringBuilder
    $prevLevel = 1
    [void]$sb.AppendLine('<ul class="toc-list">')

    for ($i = 0; $i -lt $AllSections.Count; $i++) {
        $s = $AllSections[$i]
        $level = 1
        if ($UseMultiLevel -and $s.Level) {
            $level = [Math]::Min([Math]::Max([int]$s.Level, 1), 6)
        }

        if ($UseMultiLevel) {
            while ($level -gt $prevLevel) {
                [void]$sb.AppendLine('<ul>')
                $prevLevel++
            }
            while ($level -lt $prevLevel) {
                [void]$sb.AppendLine('</ul>')
                $prevLevel--
            }
        }

        $id = ConvertTo-HtmlSafe ([string]$s.Id)
        $title = ConvertTo-HtmlSafe ([string]$s.Title)
        $numberLabel = [string](Get-ObjectValue -Object $s -Name 'NumberLabel')

        if ([string]::IsNullOrWhiteSpace($numberLabel)) {
          [void]$sb.AppendLine(('<li><a href="#{0}" class="toc-link">{1}</a></li>' -f $id, $title))
        }
        else {
          $numberHtml = ConvertTo-HtmlSafe $numberLabel
          [void]$sb.AppendLine(('<li><a href="#{0}" class="toc-link"><span class="toc-number">{1}</span> {2}</a></li>' -f $id, $numberHtml, $title))
        }
    }

    while ($prevLevel -gt 1) {
        [void]$sb.AppendLine('</ul>')
        $prevLevel--
    }

    [void]$sb.AppendLine('</ul>')
    return $sb.ToString()
}

  function Get-SectionNumberLabel {
    param(
      [Parameter(Mandatory = $true)][int[]]$Counters,
      [Parameter(Mandatory = $true)][int]$Level
    )

    $parts = @()
    for ($i = 1; $i -le $Level; $i++) {
      if ($Counters[$i] -gt 0) {
        $parts += [string]$Counters[$i]
      }
    }

    if ($parts.Count -eq 0) {
      return ''
    }

    return ($parts -join '.')
  }

if (-not $Sections -and $SectionsPath) {
    if (-not (Test-Path -LiteralPath $SectionsPath)) {
        throw "SectionsPath not found: $SectionsPath"
    }
    $json = Get-Content -LiteralPath $SectionsPath -Raw
    $Sections = ConvertFrom-Json -InputObject $json
}

if (-not $Sections -and -not $SectionsPath) {
  $defaultSectionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'HtmlToc.Sections.Example.json'
  if (Test-Path -LiteralPath $defaultSectionsPath) {
    $json = Get-Content -LiteralPath $defaultSectionsPath -Raw
    $Sections = ConvertFrom-Json -InputObject $json
    Write-Host "No sections were supplied. Using default sample: $defaultSectionsPath"
  }
}

if (-not $Sections -or $Sections.Count -eq 0) {
  throw 'No sections provided. Use -Sections or -SectionsPath, or place HtmlToc.Sections.Example.json next to HtmlToc.ps1 for default input.'
}

# Normalize and validate sections.
$normalized = @()
$seenIds = @{}

foreach ($s in $Sections) {
  $rawId = Get-ObjectValue -Object $s -Name 'Id'
  $rawTitle = Get-ObjectValue -Object $s -Name 'Title'
  $rawLevel = Get-ObjectValue -Object $s -Name 'Level'

  if (-not $rawId) { throw 'Each section must include Id.' }
  if (-not $rawTitle) { throw "Section '$rawId' is missing Title." }

  $id = [string]$rawId
    if ($seenIds.ContainsKey($id)) {
        throw "Duplicate section Id detected: $id"
    }
    $seenIds[$id] = $true

    $lvl = 1
  if ($null -ne $rawLevel -and "$rawLevel" -ne '') { $lvl = [Math]::Min([Math]::Max([int]$rawLevel, 1), 6) }

    $normalized += [pscustomobject]@{
        Id         = $id
    Title      = [string]$rawTitle
        Level      = $lvl
    NumberLabel = ''
    Paragraphs = Get-ObjectValue -Object $s -Name 'Paragraphs'
    Bullets    = Get-ObjectValue -Object $s -Name 'Bullets'
    Numbered   = Get-ObjectValue -Object $s -Name 'Numbered'
    CodeBlocks = Get-ObjectValue -Object $s -Name 'CodeBlocks'
    Table      = Get-ObjectValue -Object $s -Name 'Table'
    Html       = Get-ObjectValue -Object $s -Name 'Html'
    }
}

if ($EnableSectionHeadingNumbering) {
  $numberingCounters = @(0, 0, 0, 0, 0, 0, 0)

  for ($i = 0; $i -lt $normalized.Count; $i++) {
    $lvl = [Math]::Min([Math]::Max([int]$normalized[$i].Level, 1), 6)
    $numberingCounters[$lvl]++

    for ($reset = $lvl + 1; $reset -le 6; $reset++) {
      $numberingCounters[$reset] = 0
    }

    $normalized[$i].NumberLabel = Get-SectionNumberLabel -Counters $numberingCounters -Level $lvl
  }
}

$tocHtml = Build-TocHtml -AllSections $normalized -UseMultiLevel:$EnableMultiLevelToc

$sectionSb = New-Object System.Text.StringBuilder

for ($i = 0; $i -lt $normalized.Count; $i++) {
    $section = $normalized[$i]
    $id = ConvertTo-HtmlSafe $section.Id
    $title = ConvertTo-HtmlSafe $section.Title
    $headingTag = Get-HeadingTag -Level $section.Level
    $bodyHtml = ConvertTo-SectionBodyHtml -Section $section

    $headingPrefixHtml = ''
    if ($EnableSectionHeadingNumbering -and -not [string]::IsNullOrWhiteSpace($section.NumberLabel)) {
        $headingPrefixHtml = '<span class="section-number">{0}</span> ' -f (ConvertTo-HtmlSafe $section.NumberLabel)
    }

    $navHtml = ''
    if ($EnableSectionNavLinks) {
      $navHtml = New-SectionNavHtml -Index $i -AllSections $normalized -Mode $SectionNavMode -IconNumberPlacement $SectionNavIconNumberPlacement
    }

    $collapseButton = ''
    $bodyClass = 'section-body'
    if ($EnableCollapsibleSections) {
        $isExpanded = $OpenSectionsByDefault.IsPresent
        $collapseGlyph = if ($isExpanded) { '&#9650;' } else { '&#9660;' }
        $collapseTitle = if ($isExpanded) { 'Collapse section' } else { 'Expand section' }
      $collapseButton = '<button type="button" class="section-collapse-btn" data-target="section-body-{0}" aria-expanded="{1}" title="{2}" aria-label="{2}">{3}</button>' -f $id, $isExpanded.ToString().ToLower(), $collapseTitle, $collapseGlyph
        if (-not $OpenSectionsByDefault) {
            $bodyClass += ' is-collapsed'
        }
    }

    [void]$sectionSb.AppendLine(('<section id="{0}" class="content-section">' -f $id))
    [void]$sectionSb.AppendLine(('  <{0} class="section-heading">{1}{2} {3} {4}</{0}>' -f $headingTag, $headingPrefixHtml, $title, $navHtml, $collapseButton))
    [void]$sectionSb.AppendLine(('  <div id="section-body-{0}" class="{1}">' -f $id, $bodyClass))
    [void]$sectionSb.AppendLine($bodyHtml)
    [void]$sectionSb.AppendLine('  </div>')

    if ($EnableTopLinkAfterSection) {
      [void]$sectionSb.AppendLine((New-SectionTopLinkHtml))
    }

    [void]$sectionSb.AppendLine('</section>')
}

$descHtml = ''
if ($DocumentDescription) {
  $descHtml = '<p class="page-description">{0}</p>' -f (ConvertTo-HtmlSafe $DocumentDescription)
}

$extraCss = ''
if ($AdditionalCss) {
    $extraCss = [string]$AdditionalCss
}

$tocCollapsedClass = ''
if ($EnableCollapsibleToc) { $tocCollapsedClass = 'toc-collapsible' }

$tocPlacementClass = if ($TocPlacement -eq 'top') { 'toc-top' } else { 'toc-left' }
$tocFloatingClass = if ($EnableFloatingToc) { 'toc-floating' } else { 'toc-not-floating' }
$tocNarrowClass = if ($KeepLeftTocOnNarrowScreens) { 'toc-force-left' } else { '' }
$bodyClassList = @($tocPlacementClass, $tocFloatingClass)
if ($tocNarrowClass) {
  $bodyClassList += $tocNarrowClass
}
$bodyClasses = $bodyClassList -join ' '

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>$(ConvertTo-HtmlSafe $Title)</title>
  <style>
    :root {
      --toc-width: 300px;
      --gap: 24px;
      --line: #d8d8d8;
      --paper: #ffffff;
      --ink: #1a1a1a;
      --muted: #555;
      --accent: #005a9c;
      --accent-soft: #eaf3fb;
      --search-hit: #fff3b0;
    }

    html { scroll-behavior: smooth; }
    @media (prefers-reduced-motion: reduce) {
      html { scroll-behavior: auto; }
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      color: var(--ink);
      background: linear-gradient(180deg, #f4f8fb 0%, #ffffff 160px);
      font: 16px/1.55 "Segoe UI", Tahoma, Arial, sans-serif;
    }

    .page {
      max-width: 1400px;
      margin: 0 auto;
      padding: 24px;
    }

    .title-wrap h1 {
      margin: 0 0 6px;
      font-size: 2rem;
      letter-spacing: 0.02em;
    }

    .page-description {
      margin: 0 0 18px;
      color: var(--muted);
    }

    .layout {
      display: grid;
      grid-template-columns: var(--toc-width) minmax(0, 1fr);
      gap: var(--gap);
      align-items: start;
    }

    .toc-wrap {
      position: sticky;
      top: 12px;
      align-self: start;
      max-height: calc(100vh - 24px);
      overflow: auto;
      border: 1px solid var(--line);
      border-radius: 12px;
      background: var(--paper);
      box-shadow: 0 2px 16px rgba(0,0,0,0.06);
      padding: 12px;
    }

    .toc-not-floating .toc-wrap {
      position: static;
      top: auto;
      max-height: none;
    }

    .toc-top .layout {
      grid-template-columns: 1fr;
    }

    .toc-top .toc-wrap {
      position: static;
      top: auto;
      max-height: none;
      margin-bottom: 12px;
    }

    .toc-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;
      font-weight: 700;
    }

    .toc-toggle {
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #fff;
      color: #333;
      padding: 4px 8px;
      cursor: pointer;
      display: none;
    }

    .toc-collapsible .toc-toggle { display: inline-block; }

    .toc-body.is-collapsed { display: none; }

    .doc-search-wrap {
      display: flex;
      gap: 8px;
      margin: 0 0 12px;
      align-items: center;
    }

    .doc-search-options {
      display: flex;
      align-items: center;
      gap: 8px;
      margin: 0 0 8px;
      color: var(--muted);
      font-size: 0.86rem;
    }

    .doc-search-input {
      flex: 1;
      min-width: 0;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 6px 8px;
      font-size: 0.92rem;
    }

    .doc-search-btn {
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #fff;
      color: #333;
      padding: 6px 10px;
      cursor: pointer;
      white-space: nowrap;
    }

    .doc-search-btn:hover {
      background: var(--accent-soft);
      color: var(--accent);
    }

    .doc-search-meta {
      margin: 0 0 12px;
      color: var(--muted);
      font-size: 0.82rem;
      min-height: 1.1rem;
    }

    .toc-list,
    .toc-list ul {
      list-style: none;
      margin: 0;
      padding-left: 10px;
    }

    .toc-list > li,
    .toc-list ul > li { margin: 3px 0; }

    .toc-link {
      color: #2a2a2a;
      text-decoration: none;
      display: inline-block;
      padding: 4px 6px;
      border-radius: 6px;
    }

    .toc-number {
      color: var(--muted);
      font-weight: 700;
      white-space: nowrap;
    }

    .toc-link:hover,
    .toc-link.active {
      background: var(--accent-soft);
      color: var(--accent);
    }

    main {
      min-width: 0;
      background: #fff;
      border: 1px solid var(--line);
      border-radius: 12px;
      box-shadow: 0 2px 16px rgba(0,0,0,0.04);
      padding: 20px;
    }

    .content-section {
      border-bottom: 1px dashed #dcdcdc;
      padding: 8px 0 16px;
      margin-bottom: 8px;
    }

    .content-section:last-child {
      border-bottom: 0;
      margin-bottom: 0;
      padding-bottom: 0;
    }

    .section-heading {
      margin: 0 0 8px;
      scroll-margin-top: 14px;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 8px;
    }

    .section-number {
      color: var(--muted);
      font-weight: 700;
      margin-right: 2px;
      white-space: nowrap;
    }

    .section-nav {
      display: inline-flex;
      gap: 6px;
      margin-left: auto;
    }

    .section-nav-link {
      border: 1px solid var(--line);
      border-radius: 6px;
      text-decoration: none;
      color: #333;
      padding: 2px 8px;
      background: #fff;
      font-size: 0.9rem;
    }

    .section-nav-link:hover {
      background: var(--accent-soft);
      color: var(--accent);
    }

    .section-nav-number {
      font-weight: 700;
      color: var(--muted);
      white-space: nowrap;
      font-size: 0.86rem;
      background: #e7f2ff;
      border: 1px solid #c5ddfb;
      border-radius: 999px;
      padding: 1px 8px;
    }

    .section-top-link-wrap {
      margin-top: 8px;
      text-align: right;
    }

    .section-top-link {
      display: inline-block;
      padding: 2px 6px;
      font-size: 0.78rem;
      color: var(--accent);
      text-decoration: none;
      background: #e7f2ff;
      border: 1px solid #c5ddfb;
      border-radius: 6px;
      border-bottom: 1px solid transparent;
    }

    .section-top-link:hover {
      border-bottom-color: var(--accent);
      background: #d7ebff;
    }

    .section-collapse-btn {
      border: 1px solid var(--line);
      border-radius: 6px;
      background: #fff;
      color: #333;
      padding: 2px 8px;
      cursor: pointer;
      font-size: 0.86rem;
    }

    .section-collapse-btn[aria-expanded="false"] {
      background: linear-gradient(135deg, #5f3ea8 0%, #4f2d95 45%, #6b46be 100%);
      border-color: #3f2279;
      color: #f8f2ff;
      animation: collapse-hint-blink 1.15s ease-in-out infinite;
    }

    .section-collapse-btn[aria-expanded="true"] {
      background: #ffffff;
      border-color: var(--line);
      color: #333;
    }

    .section-collapse-btn:hover { background: #f3f7fb; }

    .section-collapse-btn[aria-expanded="true"]:hover {
      background: #f3f7fb;
    }

    .section-collapse-btn[aria-expanded="false"]:hover {
      background: linear-gradient(135deg, #6946b5 0%, #5635a1 50%, #7353c4 100%);
    }

    @keyframes collapse-hint-blink {
      0% {
        box-shadow: inset 0 0 0 0 rgba(255,255,255,0.0), 0 0 0 0 rgba(113, 74, 194, 0.0);
        filter: brightness(1);
        opacity: 1;
      }
      50% {
        box-shadow: inset 0 0 0 999px rgba(255,255,255,0.14), 0 0 0 2px rgba(168, 131, 245, 0.34);
        filter: brightness(1.08);
        opacity: 0.62;
      }
      100% {
        box-shadow: inset 0 0 0 0 rgba(255,255,255,0.0), 0 0 0 0 rgba(113, 74, 194, 0.0);
        filter: brightness(1);
        opacity: 1;
      }
    }

    .section-body.is-collapsed {
      display: none;
    }

    .search-target-flash {
      animation: search-target-flash 1.15s ease-out;
    }

    @keyframes search-target-flash {
      0% { background: var(--search-hit); }
      100% { background: transparent; }
    }

    .search-modal-backdrop {
      position: fixed;
      inset: 0;
      background: linear-gradient(90deg, rgba(0, 0, 0, 0.08) 0%, rgba(0, 0, 0, 0.34) 100%);
      display: flex;
      align-items: stretch;
      justify-content: flex-end;
      z-index: 1400;
      padding: 12px;
    }

    .search-modal-backdrop[hidden] {
      display: none !important;
    }

    .search-modal {
      width: min(640px, 48vw);
      min-width: 360px;
      max-width: 48vw;
      height: calc(100vh - 24px);
      max-height: calc(100vh - 24px);
      background: #fff;
      border: 1px solid var(--line);
      border-radius: 12px;
      display: flex;
      flex-direction: column;
      box-shadow: 0 12px 30px rgba(0,0,0,0.2);
      margin-left: auto;
    }

    .search-modal-backdrop.dock-right-quarter .search-modal {
      width: min(520px, 28vw);
      max-width: 28vw;
      min-width: 320px;
    }

    .search-modal-backdrop.dock-right-half .search-modal {
      width: min(840px, 50vw);
      max-width: 50vw;
      min-width: 360px;
    }

    .search-modal-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 1px solid var(--line);
      padding: 12px;
      gap: 12px;
    }

    .search-modal-title {
      margin: 0;
      font-size: 1.05rem;
    }

    .search-modal-controls {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    .search-modal-body {
      padding: 10px 12px 12px;
      overflow: auto;
    }

    @media (max-width: 980px) {
      .search-modal-backdrop {
        padding: 8px;
      }

      .search-modal {
        width: min(640px, 100%);
        max-width: 100%;
        min-width: 0;
        height: calc(100vh - 16px);
        max-height: calc(100vh - 16px);
      }

      .search-modal-backdrop.dock-right-quarter .search-modal,
      .search-modal-backdrop.dock-right-half .search-modal {
        width: min(640px, 100%);
        max-width: 100%;
        min-width: 0;
      }
    }

    @media (max-width: 700px) {
      .search-modal-backdrop {
        padding: 0;
      }

      .search-modal {
        width: 100%;
        height: 100vh;
        max-height: 100vh;
        border-radius: 0;
      }

      .search-modal-header {
        align-items: flex-start;
      }

      .search-modal-controls {
        width: 100%;
        justify-content: flex-start;
      }
    }

    .search-results-list {
      list-style: none;
      margin: 0;
      padding: 0;
      display: grid;
      gap: 8px;
    }

    .search-result-item {
      border: 1px solid #e5e5e5;
      border-radius: 8px;
      background: #fbfdff;
    }

    .search-result-btn {
      width: 100%;
      border: 0;
      background: transparent;
      text-align: left;
      padding: 10px;
      cursor: pointer;
    }

    .search-result-item.is-active {
      border-color: var(--accent);
      box-shadow: inset 0 0 0 1px rgba(0, 90, 156, 0.22);
      background: #f5faff;
    }

    .search-result-title {
      display: block;
      font-weight: 700;
      color: #202020;
      margin-bottom: 4px;
    }

    .search-result-snippet {
      color: #424242;
      font-size: 0.9rem;
      line-height: 1.45;
    }

    p { margin: 0 0 12px; }
    ul, ol { margin-top: 0; margin-bottom: 12px; }

    pre {
      border: 1px solid #e3e3e3;
      border-radius: 8px;
      padding: 10px;
      overflow: auto;
      background: #f8fbfe;
    }

    .table-wrap { overflow: auto; margin-bottom: 12px; }
    table {
      border-collapse: collapse;
      width: 100%;
      min-width: 420px;
    }
    th, td {
      border: 1px solid #e1e1e1;
      text-align: left;
      padding: 8px;
      vertical-align: top;
    }
    th {
      background: #f3f7fb;
      font-weight: 700;
    }

    @media (max-width: 980px) {
      body:not(.toc-force-left) .layout {
        grid-template-columns: 1fr;
      }

      body:not(.toc-force-left) .toc-wrap {
        position: static;
        max-height: none;
      }

      .section-nav {
        margin-left: 0;
      }
    }

$extraCss
  </style>
</head>
<body id="page-top" class="$bodyClasses">
  <div class="page">
    <div class="title-wrap">
      <h1>$(ConvertTo-HtmlSafe $Title)</h1>
      $descHtml
    </div>

    <div class="layout">
      <nav class="toc-wrap $tocCollapsedClass" aria-label="Table of contents">
        <div class="toc-header">
          <span>Contents</span>
          <button type="button" class="toc-toggle" id="toc-toggle" aria-expanded="true" title="Collapse TOC" aria-label="Collapse TOC">&#9650;</button>
        </div>
        <div class="toc-body" id="toc-body">
$tocHtml
        </div>
      </nav>

      <main>
        <div class="doc-search-wrap">
          <input type="search" class="doc-search-input" id="doc-search-input" placeholder="Search headings and content" aria-label="Search headings and content" />
          <button type="button" class="doc-search-btn" id="doc-search-open" title="Open search results" aria-label="Open search results">Search</button>
        </div>
        <label class="doc-search-options" for="doc-search-heading-only">
          <input type="checkbox" id="doc-search-heading-only" />
          Search headings only (faster)
        </label>
        <div class="doc-search-meta" id="doc-search-meta">Enter search text, then click Search.</div>
$($sectionSb.ToString())
      </main>
    </div>
  </div>

  <div class="search-modal-backdrop" id="search-modal-backdrop" hidden>
    <div class="search-modal" role="dialog" aria-modal="true" aria-labelledby="search-modal-title">
      <div class="search-modal-header">
        <h2 class="search-modal-title" id="search-modal-title">Search results</h2>
        <div class="search-modal-controls">
          <span class="doc-search-meta" id="search-modal-meta">No search yet.</span>
          <button type="button" class="doc-search-btn" id="search-dock-half" aria-label="Dock search panel to right half" title="Dock search panel to the right half of the page">Right Half</button>
          <button type="button" class="doc-search-btn" id="search-dock-quarter" aria-label="Dock search panel to right quarter" title="Dock search panel to a right-side quarter width">Right Quarter</button>
          <button type="button" class="doc-search-btn" id="search-prev" aria-label="Previous result" title="Go to previous search result">Previous</button>
          <button type="button" class="doc-search-btn" id="search-next" aria-label="Next result" title="Go to next search result">Next</button>
          <button type="button" class="doc-search-btn" id="search-close" aria-label="Close search" title="Close search results panel">Close</button>
        </div>
      </div>
      <div class="search-modal-body">
        <ul class="search-results-list" id="search-results-list"></ul>
      </div>
    </div>
  </div>

  <script>
    (function () {
      var links = Array.prototype.slice.call(document.querySelectorAll('.toc-link'));
      var byId = {};
      for (var i = 0; i < links.length; i++) {
        var href = links[i].getAttribute('href') || '';
        if (href.indexOf('#') === 0) {
          byId[href.substring(1)] = links[i];
        }
      }

      var sections = Array.prototype.slice.call(document.querySelectorAll('main section[id]'));
      var searchInput = document.getElementById('doc-search-input');
      var searchOpen = document.getElementById('doc-search-open');
      var searchHeadingOnly = document.getElementById('doc-search-heading-only');
      var searchMeta = document.getElementById('doc-search-meta');
      var searchModalBackdrop = document.getElementById('search-modal-backdrop');
      var searchModalMeta = document.getElementById('search-modal-meta');
      var searchResultsList = document.getElementById('search-results-list');
      var searchDockHalf = document.getElementById('search-dock-half');
      var searchDockQuarter = document.getElementById('search-dock-quarter');
      var searchPrev = document.getElementById('search-prev');
      var searchNext = document.getElementById('search-next');
      var searchClose = document.getElementById('search-close');
      var searchDockMode = 'right-half';

      function normalizeText(value) {
        return (value || '').replace(/\s+/g, ' ').trim();
      }

      function getSectionTitle(section) {
        var heading = section.querySelector('.section-heading');
        if (!heading) return section.id || '';
        var clone = heading.cloneNode(true);
        var chrome = clone.querySelectorAll('.section-nav, .section-collapse-btn');
        for (var i = 0; i < chrome.length; i++) {
          var el = chrome[i];
          if (el && el.parentNode) el.parentNode.removeChild(el);
        }
        return normalizeText(clone.textContent) || section.id || '';
      }

      function createSnippet(rawText, queryLower) {
        if (!rawText) return '';
        var compact = normalizeText(rawText);
        if (!compact) return '';
        if (!queryLower) {
          return compact.length > 170 ? (compact.substring(0, 170) + '...') : compact;
        }

        var lower = compact.toLowerCase();
        var at = lower.indexOf(queryLower);
        if (at < 0) {
          return compact.length > 170 ? (compact.substring(0, 170) + '...') : compact;
        }

        var start = Math.max(0, at - 65);
        var end = Math.min(compact.length, at + queryLower.length + 95);
        var snippet = compact.substring(start, end);
        if (start > 0) snippet = '...' + snippet;
        if (end < compact.length) snippet = snippet + '...';
        return snippet;
      }

      function expandSectionForSearch(section) {
        if (!section) return;
        var body = section.querySelector('.section-body');
        if (body && body.classList.contains('is-collapsed')) {
          body.classList.remove('is-collapsed');
          var btn = section.querySelector('.section-collapse-btn');
          if (btn) {
            btn.setAttribute('aria-expanded', 'true');
            btn.innerHTML = '&#9650;';
            btn.setAttribute('title', 'Collapse section');
            btn.setAttribute('aria-label', 'Collapse section');
          }
        }
      }

      function flashSection(section) {
        if (!section) return;
        section.classList.remove('search-target-flash');
        section.offsetWidth;
        section.classList.add('search-target-flash');
        setTimeout(function () {
          section.classList.remove('search-target-flash');
        }, 1200);
      }

      var searchIndex = sections.map(function (section) {
        var titleText = getSectionTitle(section);
        var bodyNode = section.querySelector('.section-body');
        var bodyText = normalizeText(bodyNode ? bodyNode.textContent : section.textContent);
        var combinedText = normalizeText(titleText + ' ' + bodyText);
        return {
          id: section.id,
          title: titleText,
          searchableText: combinedText,
          searchableLower: combinedText.toLowerCase(),
          headingLower: normalizeText(titleText).toLowerCase()
        };
      });

      var searchState = {
        query: '',
        queryLower: '',
        hits: [],
        activeIndex: -1
      };

      function setSearchMeta(message) {
        if (searchMeta) searchMeta.textContent = message;
        if (searchModalMeta) searchModalMeta.textContent = message;
      }

      function applySearchDockMode(mode) {
        if (!searchModalBackdrop) return;

        searchDockMode = (mode === 'right-quarter') ? 'right-quarter' : 'right-half';
        searchModalBackdrop.classList.remove('dock-right-half', 'dock-right-quarter');
        if (searchDockMode === 'right-quarter') {
          searchModalBackdrop.classList.add('dock-right-quarter');
        } else {
          searchModalBackdrop.classList.add('dock-right-half');
        }

        if (searchDockHalf) {
          searchDockHalf.setAttribute('aria-pressed', searchDockMode === 'right-half' ? 'true' : 'false');
        }
        if (searchDockQuarter) {
          searchDockQuarter.setAttribute('aria-pressed', searchDockMode === 'right-quarter' ? 'true' : 'false');
        }

        if (!searchModalBackdrop.hidden) {
          renderResults();
          updateResultSelection();
        }
      }

      function executeSearch() {
        var query = searchInput ? searchInput.value : '';
        query = normalizeText(query);
        if (!query) {
          closeSearchModal();
          setSearchMeta('Enter search text, then click Search.');
          if (searchInput) {
            searchInput.focus();
          }
          return;
        }

        runSearch(query);
        openSearchModal();
      }

      function runSearch(query) {
        var raw = normalizeText(query);
        var qLower = raw.toLowerCase();
        var headingOnlyMode = !!(searchHeadingOnly && searchHeadingOnly.checked);

        searchState.query = raw;
        searchState.queryLower = qLower;
        searchState.hits = [];
        searchState.activeIndex = -1;

        if (qLower) {
          for (var i = 0; i < searchIndex.length; i++) {
            var target = headingOnlyMode ? searchIndex[i].headingLower : searchIndex[i].searchableLower;
            if (target.indexOf(qLower) !== -1) {
              searchState.hits.push(searchIndex[i]);
            }
          }
        }

        if (!qLower) {
          setSearchMeta('Enter search text, then click Search.');
        } else if (searchState.hits.length === 0) {
          setSearchMeta('No matches for "' + raw + '" (' + (headingOnlyMode ? 'headings only' : 'all content') + ').');
        } else {
          setSearchMeta(searchState.hits.length + ' result(s) for "' + raw + '" (' + (headingOnlyMode ? 'headings only' : 'all content') + ').');
        }
      }

      function renderResults() {
        if (!searchResultsList) return;
        searchResultsList.innerHTML = '';

        if (!searchState.queryLower) {
          var liEmpty = document.createElement('li');
          liEmpty.className = 'search-result-item';
          liEmpty.innerHTML = '<div class="search-result-btn"><span class="search-result-title">No query</span><span class="search-result-snippet">Enter text in the search box to find headings and section content.</span></div>';
          searchResultsList.appendChild(liEmpty);
          return;
        }

        if (searchState.hits.length === 0) {
          var liNone = document.createElement('li');
          liNone.className = 'search-result-item';
          liNone.innerHTML = '<div class="search-result-btn"><span class="search-result-title">No results</span><span class="search-result-snippet">Try a broader phrase or fewer words.</span></div>';
          searchResultsList.appendChild(liNone);
          return;
        }

        for (var i = 0; i < searchState.hits.length; i++) {
          var hit = searchState.hits[i];
          var li = document.createElement('li');
          li.className = 'search-result-item';
          li.setAttribute('data-index', String(i));

          var btn = document.createElement('button');
          btn.type = 'button';
          btn.className = 'search-result-btn';
          btn.title = 'Open section: ' + (hit.title || hit.id);

          var title = document.createElement('span');
          title.className = 'search-result-title';
          title.textContent = hit.title || hit.id;

          var snippet = document.createElement('span');
          snippet.className = 'search-result-snippet';
          snippet.textContent = createSnippet(hit.searchableText, searchState.queryLower);

          btn.appendChild(title);
          btn.appendChild(snippet);

          btn.addEventListener('click', (function (idx) {
            return function () {
              navigateToHit(idx);
            };
          })(i));

          li.appendChild(btn);
          searchResultsList.appendChild(li);
        }
      }

      function updateResultSelection() {
        if (!searchResultsList) return;
        var items = Array.prototype.slice.call(searchResultsList.querySelectorAll('.search-result-item'));
        for (var i = 0; i < items.length; i++) {
          if (i === searchState.activeIndex) {
            items[i].classList.add('is-active');
          } else {
            items[i].classList.remove('is-active');
          }
        }
      }

      function navigateToHit(index) {
        if (searchState.hits.length === 0) return;

        var size = searchState.hits.length;
        var idx = index;
        if (idx < 0) idx = size - 1;
        if (idx >= size) idx = 0;

        searchState.activeIndex = idx;
        updateResultSelection();

        var hit = searchState.hits[idx];
        var section = document.getElementById(hit.id);
        if (!section) return;

        expandSectionForSearch(section);
        section.scrollIntoView({ behavior: 'smooth', block: 'start' });
        flashSection(section);

        if (byId[hit.id]) {
          links.forEach(function (a) { a.classList.remove('active'); });
          byId[hit.id].classList.add('active');
        }
      }

      function openSearchModal() {
        if (!searchModalBackdrop) return;
        if (!searchState.queryLower) return;
        applySearchDockMode(searchDockMode);
        searchModalBackdrop.hidden = false;
        renderResults();
        if (searchState.hits.length > 0) {
          if (searchState.activeIndex < 0) {
            navigateToHit(0);
          } else {
            updateResultSelection();
          }
        }
      }

      function closeSearchModal() {
        if (!searchModalBackdrop) return;
        searchModalBackdrop.hidden = true;
      }

      if (searchOpen) {
        searchOpen.addEventListener('click', function () {
          executeSearch();
        });
      }

      if (searchInput) {
        searchInput.addEventListener('keydown', function (event) {
          if (event.key === 'Enter') {
            event.preventDefault();
            executeSearch();
          }
        });
      }

      if (searchDockHalf) {
        searchDockHalf.addEventListener('click', function () {
          applySearchDockMode('right-half');
        });
      }

      if (searchDockQuarter) {
        searchDockQuarter.addEventListener('click', function () {
          applySearchDockMode('right-quarter');
        });
      }

      if (searchPrev) {
        searchPrev.addEventListener('click', function () {
          navigateToHit(searchState.activeIndex - 1);
        });
      }

      if (searchNext) {
        searchNext.addEventListener('click', function () {
          navigateToHit(searchState.activeIndex + 1);
        });
      }

      if (searchClose) {
        searchClose.addEventListener('click', function () {
          closeSearchModal();
        });
      }

      if (searchModalBackdrop) {
        searchModalBackdrop.addEventListener('click', function (event) {
          if (event.target === searchModalBackdrop) {
            closeSearchModal();
          }
        });
      }

      document.addEventListener('keydown', function (event) {
        if (!searchModalBackdrop || searchModalBackdrop.hidden) return;
        if (event.key === 'Escape') {
          closeSearchModal();
          return;
        }
        if (event.key === 'ArrowDown') {
          event.preventDefault();
          navigateToHit(searchState.activeIndex + 1);
          return;
        }
        if (event.key === 'ArrowUp') {
          event.preventDefault();
          navigateToHit(searchState.activeIndex - 1);
        }
      });

      applySearchDockMode(searchDockMode);
      runSearch('');

      if ('IntersectionObserver' in window) {
        var io = new IntersectionObserver(function (entries) {
          entries.forEach(function (entry) {
            if (!entry.isIntersecting) return;
            links.forEach(function (a) { a.classList.remove('active'); });
            var active = byId[entry.target.id];
            if (active) active.classList.add('active');
          });
        }, { rootMargin: '-35% 0px -55% 0px', threshold: 0.01 });

        sections.forEach(function (s) { io.observe(s); });
      }

      var tocToggle = document.getElementById('toc-toggle');
      var tocBody = document.getElementById('toc-body');
      if (tocToggle && tocBody) {
        tocToggle.addEventListener('click', function () {
          var collapsed = tocBody.classList.toggle('is-collapsed');
          tocToggle.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
          if (collapsed) {
            tocToggle.innerHTML = '&#9660;';
            tocToggle.setAttribute('title', 'Expand TOC');
            tocToggle.setAttribute('aria-label', 'Expand TOC');
          } else {
            tocToggle.innerHTML = '&#9650;';
            tocToggle.setAttribute('title', 'Collapse TOC');
            tocToggle.setAttribute('aria-label', 'Collapse TOC');
          }
        });
      }

      var collapseButtons = Array.prototype.slice.call(document.querySelectorAll('.section-collapse-btn'));
      collapseButtons.forEach(function (btn) {
        btn.addEventListener('click', function () {
          var targetId = btn.getAttribute('data-target');
          var target = document.getElementById(targetId);
          if (!target) return;
          var collapsed = target.classList.toggle('is-collapsed');
          btn.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
          if (collapsed) {
            btn.innerHTML = '&#9660;';
            btn.setAttribute('title', 'Expand section');
            btn.setAttribute('aria-label', 'Expand section');
          } else {
            btn.innerHTML = '&#9650;';
            btn.setAttribute('title', 'Collapse section');
            btn.setAttribute('aria-label', 'Collapse section');
          }
        });
      });
    })();
  </script>
</body>
</html>
"@

$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$outDir = [System.IO.Path]::GetDirectoryName($outputFullPath)

if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

[System.IO.File]::WriteAllText($outputFullPath, $html, [System.Text.Encoding]::UTF8)

Write-Host "Generated HTML: $outputFullPath"

if ($PassThru) {
    Get-Item -LiteralPath $outputFullPath
}
