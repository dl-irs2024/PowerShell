# Create-TrackSessionsWordDoc-Simple.ps1
# Simplified Word document generator with robust error handling

[CmdletBinding()]
param(
    [string]$MarkdownPath,
    [string]$OutputFolder
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load required assemblies
Add-Type -AssemblyName System.Drawing

# Determine script directory
if ($PSScriptRoot) {
    $scriptDir = $PSScriptRoot
} else {
    $scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
}

if (-not $MarkdownPath) {
    $MarkdownPath = Join-Path -Path $scriptDir -ChildPath "TrackSessions.SettingsMultiUser.Explain.md"
}

if (-not $OutputFolder) {
    $OutputFolder = $scriptDir
}

Write-Host "Markdown path: $MarkdownPath" -ForegroundColor Cyan

# Verify markdown file exists
if (-not (Test-Path -LiteralPath $MarkdownPath)) {
    throw "Markdown file not found: $MarkdownPath"
}

# Get current date
$now = Get-Date
$dayOfWeek = $now.ToString('ddd')
$dateStamp = $now.ToString('yyyy-MM-dd')
$dateWithDay = "$dayOfWeek $dateStamp"

# Output filename
$outputFileName = "TrackSessions_MultiUser_Architecture_Claude_$($now.ToString('yyyy-MM-dd')).docx"
$outputPath = Join-Path -Path $OutputFolder -ChildPath $outputFileName

Write-Host "Creating Word document: $outputFileName" -ForegroundColor Cyan
Write-Host "Output path: $outputPath" -ForegroundColor Cyan

# Read markdown content
$markdownContent = Get-Content -Path $MarkdownPath -Raw

# Create Word application
$word = $null
$doc = $null

try {
    Write-Host "Creating Word COM object..." -ForegroundColor Yellow
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false

    Write-Host "Creating new document..." -ForegroundColor Yellow
    $doc = $word.Documents.Add()
    $selection = $word.Selection

    # Define color helper function
    function Get-OleColor {
        param([int]$R, [int]$G, [int]$B)
        return $R + ($G * 256) + ($B * 65536)
    }

    # Define colors
    $maroonColor = Get-OleColor -R 128 -G 0 -B 0
    $darkBlueColor = Get-OleColor -R 31 -G 90 -B 138
    $mediumBlueColor = Get-OleColor -R 68 -G 114 -B 196
    $lightBlueColor = Get-OleColor -R 224 -G 235 -B 255
    $lightGreenColor = Get-OleColor -R 230 -G 247 -B 236
    $codeBackgroundColor = Get-OleColor -R 246 -G 248 -B 250
    $lightPinkColor = Get-OleColor -R 255 -G 245 -B 245

    Write-Host "Setting document properties..." -ForegroundColor Yellow
    # Set document properties
    $doc.BuiltInDocumentProperties.Item("Title").Value = "TrackSessions Multi-User Architecture & Technical Explanation"
    $doc.BuiltInDocumentProperties.Item("Author").Value = "Claude (Anthropic)"
    $doc.BuiltInDocumentProperties.Item("Subject").Value = "PowerShell Session Tracking Multi-User Architecture"

    Write-Host "Creating title page..." -ForegroundColor Yellow
    # ===== TITLE PAGE =====
    $selection.Font.Name = "Calibri"
    $selection.Font.Size = 24
    $selection.Font.Bold = $true
    $selection.Font.Color = $darkBlueColor
    $selection.TypeText("TrackSessions Multi-User Architecture")
    $selection.TypeParagraph()

    $selection.Font.Size = 16
    $selection.Font.Bold = $false
    $selection.Font.Color = Get-OleColor -R 128 -G 128 -B 128
    $selection.TypeText("Technical Explanation & Performance Analysis")
    $selection.TypeParagraph()
    $selection.TypeParagraph()

    # Add date
    $selection.Font.Size = 12
    $selection.Font.Italic = $true
    $selection.Font.Color = Get-OleColor -R 0 -G 0 -B 0
    $selection.TypeText("Document Generated: $dateWithDay")
    $selection.TypeParagraph()
    $selection.TypeParagraph()

    Write-Host "Adding original prompt..." -ForegroundColor Yellow
    # ===== ORIGINAL PROMPT =====
    $selection.Font.Size = 14
    $selection.Font.Bold = $true
    $selection.Font.Italic = $false
    $selection.TypeText("Original Prompt")
    $selection.TypeParagraph()

    # Create prompt box
    $promptStart = $selection.Range.Start
    $selection.Font.Size = 11
    $selection.Font.Bold = $false
    $selection.Font.Color = $maroonColor

    $promptText = @"
update Sessions\PAWS-Candidates\TrackSessions.SettingsMultiUser.Explain.md to explain executive summary of Sessions\PAWS-Candidates\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1

mention how shared settings work. the shared json and access contention.

Then move onto technical details - the chat output mentioned debounce - elaborate on that. and also deduplication. Plus add suggestions for improvement and performance area.

Plus why did the filtering and other lock up errors occur.
"@

    $selection.TypeText($promptText)
    $selection.TypeParagraph()
    $promptEnd = $selection.Range.End

    # Format prompt box
    $promptRange = $doc.Range($promptStart, $promptEnd)
    $promptRange.Borders.Enable = $true
    $promptRange.Borders.OutsideLineStyle = 1
    $promptRange.Borders.OutsideColor = $maroonColor
    $promptRange.Borders.OutsideLineWidth = 4
    $promptRange.Shading.BackgroundPatternColor = $lightPinkColor

    $selection.TypeParagraph()

    Write-Host "Adding summary..." -ForegroundColor Yellow
    # ===== SUMMARY =====
    $selection.Font.Size = 12
    $selection.Font.Bold = $true
    $selection.Font.Color = Get-OleColor -R 0 -G 0 -B 0
    $selection.TypeText("Summary Caption")
    $selection.TypeParagraph()

    $selection.Font.Bold = $false
    $selection.Font.Size = 11
    $summaryItems = @(
        "Executive summary of functionality and user workflow",
        "Shared settings architecture and file coordination mechanisms",
        "Technical deep dive into debouncing, deduplication, and auto-refresh",
        "Root cause analysis of filtering errors and application crashes",
        "Performance characteristics and scaling limits",
        "10 prioritized suggestions for improvement with implementation examples"
    )

    foreach ($item in $summaryItems) {
        $selection.TypeText("• $item")
        $selection.TypeParagraph()
    }

    $selection.TypeParagraph()
    $selection.InsertBreak(7)  # Page break

    Write-Host "Adding Table of Contents..." -ForegroundColor Yellow
    # ===== TABLE OF CONTENTS =====
    $selection.Font.Size = 16
    $selection.Font.Bold = $true
    $selection.Font.Color = Get-OleColor -R 0 -G 0 -B 0
    $selection.TypeText("Table of Contents")
    $selection.TypeParagraph()
    $selection.TypeParagraph()

    # Insert TOC
    $tocRange = $selection.Range
    $toc = $doc.TablesOfContents.Add($tocRange, $true, 1, 3)
    $selection.TypeParagraph()
    $selection.InsertBreak(7)  # Page break

    Write-Host "Processing markdown content..." -ForegroundColor Yellow
    # ===== PROCESS MARKDOWN =====
    $lines = $markdownContent -split "`r?`n"
    $inCodeBlock = $false
    $codeLines = @()
    $lineCount = 0

    foreach ($line in $lines) {
        $lineCount++

        # Skip first 5 lines (already processed)
        if ($lineCount -le 5) { continue }

        # Handle code blocks
        if ($line -match '^```') {
            if ($inCodeBlock) {
                # End code block - output collected lines
                if ($codeLines.Count -gt 0) {
                    $codeText = $codeLines -join "`r`n"
                    $codeStart = $selection.Range.Start
                    $selection.Font.Name = "Consolas"
                    $selection.Font.Size = 9
                    $selection.Font.Color = Get-OleColor -R 0 -G 0 -B 0
                    $selection.TypeText($codeText)
                    $selection.TypeParagraph()
                    $codeEnd = $selection.Range.End

                    $codeRange = $doc.Range($codeStart, $codeEnd)
                    $codeRange.Shading.BackgroundPatternColor = $codeBackgroundColor
                    $codeRange.Borders.Enable = $true
                    $codeRange.Borders.OutsideLineStyle = 1
                    $codeRange.Borders.OutsideColor = Get-OleColor -R 211 -G 211 -B 211

                    $selection.TypeParagraph()
                }
                $inCodeBlock = $false
                $codeLines = @()
            } else {
                $inCodeBlock = $true
                $codeLines = @()
            }
            continue
        }

        if ($inCodeBlock) {
            $codeLines += $line
            continue
        }

        # Handle headings
        if ($line -match '^(#{1,3})\s+(.+)$') {
            $level = $matches[1].Length
            $text = $matches[2]

            $selection.Font.Bold = $true
            $selection.Font.Name = "Calibri"

            switch ($level) {
                1 {
                    $selection.Font.Size = 18
                    $selection.Font.Color = $darkBlueColor
                    $selection.Style = -2  # Heading 1
                }
                2 {
                    $selection.Font.Size = 14
                    $selection.Font.Color = $mediumBlueColor
                    $selection.Style = -3  # Heading 2
                }
                3 {
                    $selection.Font.Size = 12
                    $selection.Font.Color = $mediumBlueColor
                    $selection.Style = -4  # Heading 3
                }
            }

            $selection.TypeText($text)
            $selection.TypeParagraph()
            $selection.TypeParagraph()
            continue
        }

        # Handle horizontal rules
        if ($line -match '^---+$') {
            $selection.TypeParagraph()
            continue
        }

        # Handle bullets
        if ($line -match '^\s*[-*]\s+(.+)$') {
            $text = $matches[1]
            $selection.Font.Bold = $false
            $selection.Font.Size = 11
            $selection.Font.Color = Get-OleColor -R 0 -G 0 -B 0
            $selection.TypeText("• $text")
            $selection.TypeParagraph()
            continue
        }

        # Handle numbered lists
        if ($line -match '^\s*(\d+)\.\s+(.+)$') {
            $number = $matches[1]
            $text = $matches[2]
            $selection.Font.Bold = $false
            $selection.Font.Size = 11
            $selection.Font.Color = Get-OleColor -R 0 -G 0 -B 0
            $selection.TypeText("$number. $text")
            $selection.TypeParagraph()
            continue
        }

        # Regular paragraphs
        if ($line.Trim() -ne '') {
            $selection.Font.Bold = $false
            $selection.Font.Size = 11
            $selection.Font.Name = "Calibri"
            $selection.Font.Color = Get-OleColor -R 0 -G 0 -B 0

            # Simple bold handling
            $processedLine = $line
            while ($processedLine -match '\*\*(.+?)\*\*') {
                $beforeBold = $processedLine.Substring(0, $matches.Index)
                $boldText = $matches[1]
                $afterBold = $processedLine.Substring($matches.Index + $matches[0].Length)

                if ($beforeBold) {
                    $selection.TypeText($beforeBold)
                }
                $selection.Font.Bold = $true
                $selection.TypeText($boldText)
                $selection.Font.Bold = $false

                $processedLine = $afterBold
            }

            if ($processedLine) {
                $selection.TypeText($processedLine)
            }

            $selection.TypeParagraph()
        } else {
            $selection.TypeParagraph()
        }

        # Progress indicator every 100 lines
        if ($lineCount % 100 -eq 0) {
            Write-Host "Processed $lineCount lines..." -ForegroundColor Gray
        }
    }

    Write-Host "Updating Table of Contents..." -ForegroundColor Yellow
    $toc.Update()

    Write-Host "Saving document..." -ForegroundColor Green
    $doc.SaveAs([ref]$outputPath)

    Write-Host "`nDocument created successfully!" -ForegroundColor Green
    Write-Host "Location: $outputPath" -ForegroundColor Cyan

} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    Write-Host "`nCleaning up COM objects..." -ForegroundColor Yellow

    if ($doc) {
        try {
            $doc.Close($false)
        } catch {
            Write-Host "Error closing document: $_" -ForegroundColor Yellow
        }
    }

    if ($word) {
        try {
            $word.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
        } catch {
            Write-Host "Error quitting Word: $_" -ForegroundColor Yellow
        }
    }

    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-Host "Cleanup complete." -ForegroundColor Yellow
}

# Open document if it exists
if (Test-Path -Path $outputPath) {
    Write-Host "`nOpening document..." -ForegroundColor Cyan
    Start-Process -FilePath $outputPath
} else {
    Write-Host "`nDocument was not created successfully." -ForegroundColor Red
}
