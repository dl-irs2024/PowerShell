# Create-TrackSessionsWordDoc.ps1
# Converts TrackSessions.SettingsMultiUser.Explain.md to formatted Word document

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

Write-Host "Script directory: $scriptDir" -ForegroundColor Cyan
Write-Host "Markdown path: $MarkdownPath" -ForegroundColor Cyan
Write-Host "Output folder: $OutputFolder" -ForegroundColor Cyan

# Verify markdown file exists
if (-not (Test-Path -LiteralPath $MarkdownPath)) {
    throw "Markdown file not found: $MarkdownPath"
}

# Get current date with day of week
$now = Get-Date
$dayOfWeek = $now.ToString('ddd')  # e.g., "Thu"
$dateStamp = $now.ToString('yyyy-MM-dd')  # e.g., "2026-09-17"
$dateWithDay = "$dayOfWeek $dateStamp"

# Output filename
$outputFileName = "TrackSessions_MultiUser_Architecture_Claude_$($now.ToString('yyyy-MM-dd')).docx"
$outputPath = Join-Path -Path $OutputFolder -ChildPath $outputFileName

Write-Host "Creating Word document: $outputFileName" -ForegroundColor Cyan

# Read markdown content
$markdownContent = Get-Content -Path $MarkdownPath -Raw

# Create Word application
$word = New-Object -ComObject Word.Application
$word.Visible = $false

try {
    # Create new document
    $doc = $word.Documents.Add()
    $selection = $word.Selection

    # Define styles and colors
    $maroonColor = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Maroon)
    $lightBlueColor = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(224, 235, 255))
    $lightGreenColor = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(230, 247, 236))
    $codeBackgroundColor = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(246, 248, 250))

    # Set document properties
    $doc.BuiltInDocumentProperties.Item("Title").Value = "TrackSessions Multi-User Architecture & Technical Explanation"
    $doc.BuiltInDocumentProperties.Item("Author").Value = "Claude (Anthropic)"
    $doc.BuiltInDocumentProperties.Item("Subject").Value = "PowerShell Session Tracking Multi-User Architecture"

    # Add bookmark at top of document for "Top" links
    $topRange = $selection.Range
    $doc.Bookmarks.Add("DocumentTop", $topRange) | Out-Null

    # ===== TITLE PAGE =====
    $selection.Font.Name = "Calibri"
    $selection.Font.Size = 24
    $selection.Font.Bold = $true
    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(31, 90, 138))
    $selection.TypeText("TrackSessions Multi-User Architecture")
    $selection.TypeParagraph()

    $selection.Font.Size = 16
    $selection.Font.Bold = $false
    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::DarkGray)
    $selection.TypeText("Technical Explanation & Performance Analysis")
    $selection.TypeParagraph()
    $selection.TypeParagraph()

    # Add date
    $selection.Font.Size = 12
    $selection.Font.Italic = $true
    $selection.TypeText("Document Generated: $dateWithDay")
    $selection.TypeParagraph()
    $selection.TypeParagraph()

    # ===== ORIGINAL PROMPT =====
    $selection.Font.Size = 14
    $selection.Font.Bold = $true
    $selection.Font.Italic = $false
    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Black)
    $selection.TypeText("Original Prompt")
    $selection.TypeParagraph()

    # Create bordered box for prompt
    $promptRange = $selection.Range
    $selection.Font.Size = 11
    $selection.Font.Bold = $false
    $selection.Font.Color = $maroonColor
    $selection.TypeText("update Sessions\PAWS-Candidates\TrackSessions.SettingsMultiUser.Explain.md to explain executive summary of Sessions\PAWS-Candidates\TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1")
    $selection.TypeParagraph()
    $selection.TypeText("mention how shared settings work. the shared json and access contention.")
    $selection.TypeParagraph()
    $selection.TypeText("Then move onto technical details - the chat output mentioned debounce - elaborate on that. and also deduplication. Plus add suggestions for improvement and performance area.")
    $selection.TypeParagraph()
    $selection.TypeText("Plus why did the filtering and other lock up errors occur.")
    $selection.TypeParagraph()

    # Add border to prompt
    $promptRange.End = $selection.Range.End
    $promptRange.Borders.Enable = $true
    $promptRange.Borders.OutsideLineStyle = 1  # wdLineStyleSingle
    $promptRange.Borders.OutsideColor = $maroonColor
    $promptRange.Borders.OutsideLineWidth = 4  # wdLineWidth150pt
    $promptRange.Shading.BackgroundPatternColor = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(255, 245, 245))

    $selection.TypeParagraph()
    $selection.TypeParagraph()

    # ===== SUMMARY CAPTION =====
    $selection.Font.Size = 12
    $selection.Font.Bold = $true
    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Black)
    $selection.TypeText("Summary Caption")
    $selection.TypeParagraph()

    $selection.Font.Bold = $false
    $selection.Font.Size = 11
    $selection.TypeText("This document provides a comprehensive technical explanation of the TrackSessions multi-user architecture, including:")
    $selection.TypeParagraph()
    $selection.TypeText("• Executive summary of functionality and user workflow")
    $selection.TypeParagraph()
    $selection.TypeText("• Shared settings architecture and file coordination mechanisms")
    $selection.TypeParagraph()
    $selection.TypeText("• Technical deep dive into debouncing, deduplication, and auto-refresh")
    $selection.TypeParagraph()
    $selection.TypeText("• Root cause analysis of filtering errors and application crashes")
    $selection.TypeParagraph()
    $selection.TypeText("• Performance characteristics and scaling limits")
    $selection.TypeParagraph()
    $selection.TypeText("• 10 prioritized suggestions for improvement with implementation examples")
    $selection.TypeParagraph()
    $selection.TypeParagraph()

    # Insert page break after title page
    $selection.InsertBreak(7)  # wdPageBreak

    # ===== TABLE OF CONTENTS =====
    $selection.Font.Size = 16
    $selection.Font.Bold = $true
    $selection.TypeText("Table of Contents")
    $selection.TypeParagraph()
    $selection.TypeParagraph()

    # Insert TOC field
    $tocRange = $selection.Range
    $doc.TablesOfContents.Add($tocRange, $true, 1, 3) | Out-Null
    $selection.TypeParagraph()
    $selection.InsertBreak(7)  # wdPageBreak

    # ===== PARSE AND FORMAT MARKDOWN CONTENT =====
    Write-Host "Parsing markdown content..." -ForegroundColor Yellow

    $lines = $markdownContent -split "`r?`n"
    $inCodeBlock = $false
    $codeLanguage = ""
    $codeLines = @()
    $inTable = $false
    $tableHeaders = @()
    $tableRows = @()

    function Add-TopLink {
        param($Selection)
        $Selection.Font.Size = 9
        $Selection.Font.Italic = $true
        $Selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Blue)
        $Selection.TypeText("[Back to Top]")
        $linkRange = $Selection.Range
        $linkRange.MoveStart(1, -13)  # wdCharacter, move back 13 characters
        $doc.Hyperlinks.Add($linkRange, "", "DocumentTop") | Out-Null
        $Selection.TypeParagraph()
        $Selection.TypeParagraph()
    }

    function Format-CodeBlock {
        param($Lines, $Language, $Selection, $Doc)

        $codeText = $Lines -join "`r`n"
        $codeRange = $Selection.Range
        $Selection.Font.Name = "Consolas"
        $Selection.Font.Size = 9
        $Selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Black)
        $Selection.TypeText($codeText)
        $Selection.TypeParagraph()

        # Format the code block
        $codeRange.End = $Selection.Range.End - 1
        $codeRange.Font.Name = "Consolas"
        $codeRange.Font.Size = 9
        $codeRange.Shading.BackgroundPatternColor = $script:codeBackgroundColor
        $codeRange.Borders.Enable = $true
        $codeRange.Borders.OutsideLineStyle = 1
        $codeRange.Borders.OutsideColor = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::LightGray)

        # Basic syntax highlighting for PowerShell
        if ($Language -eq "powershell") {
            $keywords = @('param', 'function', 'if', 'else', 'foreach', 'while', 'try', 'catch', 'return', '$script:', '$window', '$null', '-eq', '-lt', '-gt', '-and', '-or')
            foreach ($keyword in $keywords) {
                $findRange = $codeRange.Duplicate()
                $findRange.Find.Text = $keyword
                $findRange.Find.Forward = $true
                $findRange.Find.MatchWholeWord = $true

                while ($findRange.Find.Execute()) {
                    $findRange.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Blue)
                    $findRange.Font.Bold = $true
                }
            }

            # Highlight comments
            $commentRange = $codeRange.Duplicate()
            $commentRange.Find.Text = "#*"
            $commentRange.Find.MatchWildcards = $true
            while ($commentRange.Find.Execute()) {
                $commentRange.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Green)
                $commentRange.Font.Italic = $true
            }
        }

        $Selection.TypeParagraph()
    }

    function Format-Table {
        param($Headers, $Rows, $Selection, $Doc)

        if ($Headers.Count -eq 0 -or $Rows.Count -eq 0) { return }

        $numCols = $Headers.Count
        $numRows = $Rows.Count + 1  # +1 for header row

        # Create table
        $tableRange = $Selection.Range
        $table = $Doc.Tables.Add($tableRange, $numRows, $numCols)
        $table.Borders.Enable = $true
        $table.Borders.InsideLineStyle = 1
        $table.Borders.OutsideLineStyle = 1

        # Format header row
        for ($col = 1; $col -le $numCols; $col++) {
            $cell = $table.Cell(1, $col)
            $cell.Range.Text = $Headers[$col - 1]
            $cell.Range.Font.Bold = $true
            $cell.Range.Font.Size = 10
            $cell.Shading.BackgroundPatternColor = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(68, 114, 196))
            $cell.Range.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::White)
            $cell.Range.ParagraphFormat.Alignment = 1  # wdAlignParagraphCenter
        }

        # Format data rows with alternating pastel colors
        for ($row = 2; $row -le $numRows; $row++) {
            $rowData = $Rows[$row - 2] -split '\|' | ForEach-Object { $_.Trim() }

            for ($col = 1; $col -le $numCols; $col++) {
                $cell = $table.Cell($row, $col)
                if ($col -le $rowData.Count) {
                    $cell.Range.Text = $rowData[$col - 1]
                }
                $cell.Range.Font.Size = 10

                # Alternating row colors
                if ($row % 2 -eq 0) {
                    $cell.Shading.BackgroundPatternColor = $script:lightBlueColor
                } else {
                    $cell.Shading.BackgroundPatternColor = $script:lightGreenColor
                }
            }

            # Repeat header every 25 rows for long tables
            if (($row % 25 -eq 0) -and ($row -lt $numRows)) {
                $row++
                for ($col = 1; $col -le $numCols; $col++) {
                    $cell = $table.Cell($row, $col)
                    $cell.Range.Text = $Headers[$col - 1]
                    $cell.Range.Font.Bold = $true
                    $cell.Range.Font.Size = 10
                    $cell.Shading.BackgroundPatternColor = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(68, 114, 196))
                    $cell.Range.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::White)
                    $cell.Range.ParagraphFormat.Alignment = 1
                }
            }
        }

        $table.AutoFitBehavior(2)  # wdAutoFitWindow
        $Selection.EndOf(15) | Out-Null  # wdTable
        $Selection.MoveDown() | Out-Null
        $Selection.TypeParagraph()
    }

    # Process each line
    $lineIndex = 0
    foreach ($line in $lines) {
        $lineIndex++

        # Skip first 5 lines (already in title page)
        if ($lineIndex -le 5) { continue }

        # Handle code blocks
        if ($line -match '^```(\w*)') {
            if ($inCodeBlock) {
                # End of code block
                Format-CodeBlock -Lines $codeLines -Language $codeLanguage -Selection $selection -Doc $doc
                $inCodeBlock = $false
                $codeLines = @()
                $codeLanguage = ""
            } else {
                # Start of code block
                $inCodeBlock = $true
                $codeLanguage = $matches[1]
                $codeLines = @()
            }
            continue
        }

        if ($inCodeBlock) {
            $codeLines += $line
            continue
        }

        # Handle tables
        if ($line -match '^\|') {
            if (-not $inTable) {
                $inTable = $true
                $tableRows = @()
            }

            # Parse table row
            $cells = $line -split '\|' | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }

            # Check if this is separator row
            if ($cells[0] -match '^-+$') {
                continue
            }

            if ($tableHeaders.Count -eq 0) {
                $tableHeaders = $cells
            } else {
                $tableRows += $line
            }
            continue
        } elseif ($inTable) {
            # End of table
            Format-Table -Headers $tableHeaders -Rows $tableRows -Selection $selection -Doc $doc
            $inTable = $false
            $tableHeaders = @()
            $tableRows = @()
        }

        # Handle headings
        if ($line -match '^(#{1,3})\s+(.+)$') {
            $level = $matches[1].Length
            $text = $matches[2]

            $selection.Font.Bold = $true
            $selection.Font.Name = "Calibri"

            switch ($level) {
                1 {
                    $selection.Style = -2  # wdStyleHeading1
                    $selection.Font.Size = 18
                    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(31, 90, 138))
                }
                2 {
                    $selection.Style = -3  # wdStyleHeading2
                    $selection.Font.Size = 14
                    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(68, 114, 196))
                }
                3 {
                    $selection.Style = -4  # wdStyleHeading3
                    $selection.Font.Size = 12
                    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(79, 129, 189))
                }
            }

            $selection.TypeText($text)
            $selection.TypeParagraph()

            # Add "Top" link after headings
            Add-TopLink -Selection $selection

            continue
        }

        # Handle horizontal rules
        if ($line -match '^---+$') {
            $selection.TypeParagraph()
            continue
        }

        # Handle bullet lists
        if ($line -match '^\s*[-*]\s+(.+)$') {
            $text = $matches[1]
            $selection.Font.Bold = $false
            $selection.Font.Size = 11
            $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Black)
            $selection.TypeText("• $text")
            $selection.TypeParagraph()
            continue
        }

        # Handle numbered lists
        if ($line -match '^\s*\d+\.\s+(.+)$') {
            $text = $matches[1]
            $selection.Font.Bold = $false
            $selection.Font.Size = 11
            $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Black)
            $selection.TypeText($line)
            $selection.TypeParagraph()
            continue
        }

        # Handle bold text
        $line = $line -replace '\*\*(.+?)\*\*', '<<<BOLD>>>$1<<<ENDBOLD>>>'

        # Handle inline code
        $line = $line -replace '`(.+?)`', '<<<CODE>>>$1<<<ENDCODE>>>'

        # Handle links (preserve for later processing)
        $line = $line -replace '\[(.+?)\]\((.+?)\)', '<<<LINK>>>$1<<<URL>>>$2<<<ENDLINK>>>'

        # Regular paragraph
        if ($line.Trim() -ne '') {
            $selection.Font.Bold = $false
            $selection.Font.Size = 11
            $selection.Font.Name = "Calibri"
            $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Black)

            # Process inline formatting
            $parts = $line -split '(<<<(?:BOLD|CODE|LINK)>>>.*?<<<END(?:BOLD|CODE|LINK)>>>)'

            foreach ($part in $parts) {
                if ($part -match '<<<BOLD>>>(.+?)<<<ENDBOLD>>>') {
                    $selection.Font.Bold = $true
                    $selection.TypeText($matches[1])
                    $selection.Font.Bold = $false
                }
                elseif ($part -match '<<<CODE>>>(.+?)<<<ENDCODE>>>') {
                    $selection.Font.Name = "Consolas"
                    $selection.Font.Size = 10
                    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::DarkRed)
                    $selection.TypeText($matches[1])
                    $selection.Font.Name = "Calibri"
                    $selection.Font.Size = 11
                    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Black)
                }
                elseif ($part -match '<<<LINK>>>(.+?)<<<URL>>>(.+?)<<<ENDLINK>>>') {
                    $linkText = $matches[1]
                    $linkUrl = $matches[2]

                    $linkRange = $selection.Range
                    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Blue)
                    $selection.Font.Underline = 1  # wdUnderlineSingle
                    $selection.TypeText($linkText)
                    $linkRange.End = $selection.Range.End

                    # Add hyperlink
                    try {
                        $doc.Hyperlinks.Add($linkRange, $linkUrl) | Out-Null
                    } catch {
                        # If URL is invalid, just leave as underlined text
                    }

                    $selection.Font.Color = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Black)
                    $selection.Font.Underline = 0  # wdUnderlineNone
                }
                else {
                    $selection.TypeText($part)
                }
            }

            $selection.TypeParagraph()
        } else {
            $selection.TypeParagraph()
        }
    }

    Write-Host "Updating Table of Contents..." -ForegroundColor Yellow
    $doc.TablesOfContents.Item(1).Update()

    # Save document
    Write-Host "Saving document to: $outputPath" -ForegroundColor Green
    $doc.SaveAs([ref]$outputPath)
    $doc.Close()

    Write-Host "Document created successfully!" -ForegroundColor Green
    Write-Host "Location: $outputPath" -ForegroundColor Cyan

} catch {
    Write-Error "Error creating Word document: $_"
    Write-Error $_.ScriptStackTrace
} finally {
    # Clean up
    if ($doc) {
        $doc.Close($false)
    }
    $word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# Open the document
if (Test-Path -Path $outputPath) {
    Write-Host "`nOpening document..." -ForegroundColor Yellow
    Start-Process -FilePath $outputPath
}
