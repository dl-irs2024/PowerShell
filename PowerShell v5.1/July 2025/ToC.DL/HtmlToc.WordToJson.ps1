<#
.SYNOPSIS
Converts a Word .docx document into HtmlToc JSON section format.

.DESCRIPTION
Reads a .docx file using Word COM automation and generates a JSON array of
section objects compatible with HtmlToc.ps1.

Heading styles (Heading 1..Heading 6) become section boundaries with matching
Level values. Non-heading paragraphs are collected into the active section's
Paragraphs array.

.PARAMETER InputPath
Path to the source .docx file.

.PARAMETER OutputPath
Path to the target .json file.

.PARAMETER DefaultTitle
Fallback section title used when content appears before the first heading.

.PARAMETER DefaultLevel
Fallback section level used when content appears before first heading.

.PARAMETER Force
Overwrite OutputPath if it already exists.

.PARAMETER PassThru
Returns the generated section objects.

.EXAMPLE
.\HtmlToc.WordToJson.ps1 -InputPath .\MyDoc.docx -OutputPath .\MyDoc.json -Force

.EXAMPLE
.\HtmlToc.WordToJson.ps1 -InputPath .\Guide.docx -OutputPath .\Guide.json -DefaultTitle 'Introduction' -PassThru
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$DefaultTitle = 'Introduction',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 6)]
    [int]$DefaultLevel = 1,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

function ConvertTo-Slug {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][hashtable]$Seen
    )

    $slug = $Text.ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '-')
    $slug = $slug.Trim('-')

    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = 'section'
    }

    $base = $slug
    $n = 2
    while ($Seen.ContainsKey($slug)) {
        $slug = '{0}-{1}' -f $base, $n
        $n++
    }

    $Seen[$slug] = $true
    return $slug
}

function Get-HeadingLevelFromStyle {
    param([Parameter(Mandatory = $true)][string]$StyleName)

    $match = [regex]::Match($StyleName, '^Heading\s+([1-6])$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($match.Success) {
        return [int]$match.Groups[1].Value
    }

    return 0
}

function New-SectionObject {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][int]$Level
    )

    return [ordered]@{
        Id = $Id
        Title = $Title
        Level = $Level
        Paragraphs = @()
    }
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

if ([System.IO.Path]::GetExtension($InputPath).ToLowerInvariant() -ne '.docx') {
    throw 'InputPath must be a .docx file.'
}

if ((Test-Path -LiteralPath $OutputPath) -and (-not $Force)) {
    throw "Output file already exists: $OutputPath (use -Force to overwrite)"
}

$inputFullPath = [System.IO.Path]::GetFullPath($InputPath)
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDir = [System.IO.Path]::GetDirectoryName($outputFullPath)
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$word = $null
$document = $null
$sections = New-Object System.Collections.ArrayList
$seenIds = @{}
$current = $null

try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0

    $document = $word.Documents.Open($inputFullPath, $false, $true)

    foreach ($paragraph in $document.Paragraphs) {
        $text = [string]$paragraph.Range.Text
        if ($null -eq $text) { continue }

        # Word paragraphs contain end-of-paragraph markers; trim and normalize.
        $clean = $text -replace '[\r\a]', ''
        $clean = $clean.Trim()
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }

        $styleName = ''
        try {
            $styleName = [string]$paragraph.Range.Style.NameLocal
        }
        catch {
            $styleName = ''
        }

        $headingLevel = Get-HeadingLevelFromStyle -StyleName $styleName

        if ($headingLevel -gt 0) {
            $id = ConvertTo-Slug -Text $clean -Seen $seenIds
            $current = New-SectionObject -Id $id -Title $clean -Level $headingLevel
            [void]$sections.Add($current)
            continue
        }

        if ($null -eq $current) {
            $fallbackId = ConvertTo-Slug -Text $DefaultTitle -Seen $seenIds
            $current = New-SectionObject -Id $fallbackId -Title $DefaultTitle -Level $DefaultLevel
            [void]$sections.Add($current)
        }

        $current.Paragraphs += $clean
    }
} 
finally {
    if ($document -ne $null) {
        try { $document.Close($false) | Out-Null } catch {}
        try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($document) } catch {}
    }

    if ($word -ne $null) {
        try { $word.Quit() } catch {}
        try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) } catch {}
    }

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

if ($sections.Count -eq 0) {
    $fallbackId = ConvertTo-Slug -Text $DefaultTitle -Seen $seenIds
    $emptySection = New-SectionObject -Id $fallbackId -Title $DefaultTitle -Level $DefaultLevel
    $emptySection.Paragraphs += '(No readable paragraph content found in source document.)'
    [void]$sections.Add($emptySection)
}

# Remove empty arrays where possible for cleaner output.
$final = @()
foreach ($section in $sections) {
    $obj = [ordered]@{
        Id = $section.Id
        Title = $section.Title
        Level = $section.Level
    }

    if ($section.Paragraphs -and @($section.Paragraphs).Count -gt 0) {
        $obj.Paragraphs = @($section.Paragraphs)
    }

    $final += [pscustomobject]$obj
}

$json = $final | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($outputFullPath, $json, [System.Text.Encoding]::UTF8)

Write-Host "Generated JSON: $outputFullPath"

if ($PassThru) {
    $final
}
