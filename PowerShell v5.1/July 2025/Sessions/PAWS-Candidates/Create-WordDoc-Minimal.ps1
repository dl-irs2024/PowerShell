# Create-WordDoc-Minimal.ps1
# Minimal Word document generator

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Paths
$scriptDir = $PSScriptRoot
$markdownPath = Join-Path -Path $scriptDir -ChildPath "TrackSessions.SettingsMultiUser.Explain.md"
$outputPath = Join-Path -Path $scriptDir -ChildPath "TrackSessions_MultiUser_Architecture_Claude_2026-09-17.docx"

Write-Host "Reading markdown: $markdownPath"
$content = Get-Content -Path $markdownPath -Raw

Write-Host "Creating Word application..."
$word = New-Object -ComObject Word.Application
$word.Visible = $false

try {
    Write-Host "Creating document..."
    $doc = $word.Documents.Add()
    $sel = $word.Selection

    # Helper for colors
    function Get-Color([int]$R, [int]$G, [int]$B) {
        return $R + ($G * 256) + ($B * 65536)
    }

    $black = Get-Color 0 0 0
    $blue = Get-Color 31 90 138
    $maroon = Get-Color 128 0 0
    $gray = Get-Color 128 128 128

    Write-Host "Adding title..."
    # Title
    $sel.Font.Name = "Calibri"
    $sel.Font.Size = 24
    $sel.Font.Bold = $true
    $sel.Font.Color = $blue
    $sel.TypeText("TrackSessions Multi-User Architecture")
    $sel.TypeParagraph()
    $sel.TypeParagraph()

    # Date
    $sel.Font.Size = 12
    $sel.Font.Bold = $false
    $sel.Font.Italic = $true
    $sel.Font.Color = $gray
    $sel.TypeText("Document Generated: Thu 2026-09-17")
    $sel.TypeParagraph()
    $sel.TypeParagraph()

    Write-Host "Adding prompt..."
    # Original Prompt heading
    $sel.Font.Size = 14
    $sel.Font.Bold = $true
    $sel.Font.Italic = $false
    $sel.Font.Color = $black
    $sel.TypeText("Original Prompt")
    $sel.TypeParagraph()

    # Prompt text in box
    $promptStart = $sel.Range.Start
    $sel.Font.Size = 11
    $sel.Font.Bold = $false
    $sel.Font.Color = $maroon
    $sel.TypeText("update Sessions\PAWS-Candidates\TrackSessions.SettingsMultiUser.Explain.md to explain executive summary")
    $sel.TypeParagraph()
    $sel.TypeText("mention how shared settings work. the shared json and access contention.")
    $sel.TypeParagraph()
    $sel.TypeText("Then move onto technical details - debounce, deduplication, suggestions for improvement.")
    $sel.TypeParagraph()
    $promptEnd = $sel.Range.End

    # Add border
    $promptRange = $doc.Range($promptStart, $promptEnd)
    $promptRange.Borders.Enable = $true
    $promptRange.Borders.OutsideColor = $maroon
    $promptRange.Shading.BackgroundPatternColor = Get-Color 255 245 245

    $sel.TypeParagraph()
    $sel.TypeParagraph()

    # Page break
    $sel.InsertBreak(7)

    Write-Host "Adding TOC..."
    # Table of Contents
    $sel.Font.Size = 16
    $sel.Font.Bold = $true
    $sel.Font.Color = $black
    $sel.TypeText("Table of Contents")
    $sel.TypeParagraph()
    $sel.TypeParagraph()

    $tocRange = $sel.Range
    $doc.TablesOfContents.Add($tocRange, $true, 1, 3) | Out-Null
    $sel.TypeParagraph()
    $sel.InsertBreak(7)

    Write-Host "Processing content (this may take a moment)..."
    # Process markdown
    $lines = $content -split "`r?`n"
    $lineNum = 0
    $inCode = $false
    $codeLines = @()

    foreach ($line in $lines) {
        $lineNum++
        if ($lineNum -le 5) { continue }  # Skip header

        # Code blocks
        if ($line -match '^```') {
            if ($inCode) {
                $codeText = $codeLines -join "`r`n"
                $codeStart = $sel.Range.Start
                $sel.Font.Name = "Consolas"
                $sel.Font.Size = 9
                $sel.Font.Color = $black
                $sel.TypeText($codeText)
                $sel.TypeParagraph()
                $codeEnd = $sel.Range.End
                $codeRange = $doc.Range($codeStart, $codeEnd)
                $codeRange.Shading.BackgroundPatternColor = Get-Color 246 248 250
                $sel.TypeParagraph()
                $inCode = $false
                $codeLines = @()
            } else {
                $inCode = $true
            }
            continue
        }

        if ($inCode) {
            $codeLines += $line
            continue
        }

        # Headings
        if ($line -match '^(#{1,3})\s+(.+)$') {
            $level = $matches[1].Length
            $text = $matches[2]
            $sel.Font.Bold = $true
            $sel.Font.Name = "Calibri"
            switch ($level) {
                1 { $sel.Font.Size = 18; $sel.Font.Color = $blue; $sel.Style = -2 }
                2 { $sel.Font.Size = 14; $sel.Font.Color = $blue; $sel.Style = -3 }
                3 { $sel.Font.Size = 12; $sel.Font.Color = $blue; $sel.Style = -4 }
            }
            $sel.TypeText($text)
            $sel.TypeParagraph()
            $sel.TypeParagraph()
            continue
        }

        # Horizontal rules
        if ($line -match '^---') {
            $sel.TypeParagraph()
            continue
        }

        # Bullets
        if ($line -match '^\s*[-*]\s+(.+)$') {
            $sel.Font.Bold = $false
            $sel.Font.Size = 11
            $sel.Font.Color = $black
            $sel.TypeText("• " + $matches[1])
            $sel.TypeParagraph()
            continue
        }

        # Regular text
        if ($line.Trim()) {
            $sel.Font.Bold = $false
            $sel.Font.Size = 11
            $sel.Font.Name = "Calibri"
            $sel.Font.Color = $black
            # Simple bold handling
            $text = $line -replace '\*\*', ''
            $sel.TypeText($text)
            $sel.TypeParagraph()
        } else {
            $sel.TypeParagraph()
        }

        if ($lineNum % 100 -eq 0) {
            Write-Host "  Processed $lineNum lines..."
        }
    }

    Write-Host "Updating TOC..."
    $doc.TablesOfContents.Item(1).Update()

    Write-Host "Saving document..."
    $doc.SaveAs2($outputPath)

    Write-Host "`nSUCCESS! Document created at:" -ForegroundColor Green
    Write-Host $outputPath -ForegroundColor Cyan

    $doc.Close()

} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
} finally {
    $word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

# Open the document
if (Test-Path $outputPath) {
    Write-Host "`nOpening document..." -ForegroundColor Yellow
    Start-Process $outputPath
}
