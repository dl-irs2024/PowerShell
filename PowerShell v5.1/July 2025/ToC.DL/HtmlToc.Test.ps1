<#
.SYNOPSIS
Interactive WPF test harness for HtmlToc.ps1.

.DESCRIPTION
HtmlToc.Test.ps1 provides a small Windows Presentation Foundation (WPF) interface
for selecting sample input files, choosing HtmlToc options, auto-generating an
output file name, and running the HtmlToc framework.

Features:
1. GridView selection of sample input files.
2. Auto-created sample JSON files for quick testing.
3. Test button that runs HtmlToc.ps1.
4. Auto-generated output file name.
5. Optional open-generated-file checkbox.
6. Toggles for section intralinks, collapsible headings, collapsible TOC, and
   a small Top link after each section.

HOW TO USE
----------
1. Run this script in Windows PowerShell 5.1.
2. Pick a sample input file in the left GridView.
3. Choose HtmlToc options on the right.
4. Click Test.
5. Optionally open the generated HTML file automatically.

The script creates example input files in a local sample folder if they do not
already exist.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version 2

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$htmlTocScript = Join-Path $scriptRoot 'HtmlToc.ps1'
$samplesRoot = Join-Path $scriptRoot 'HtmlToc.Test.Samples'
$settingsPath = Join-Path $scriptRoot 'HtmlToc.Test.Settings.json'

if (-not (Test-Path -LiteralPath $htmlTocScript)) {
    throw "HtmlToc.ps1 was not found next to this script: $htmlTocScript"
}

function Get-DefaultSettings {
    return [ordered]@{
        SelectedSamplePath             = ''
        OpenGeneratedFile              = $true
        EnableSectionNavLinks          = $true
        EnableTopLinkAfterSection      = $true
        EnableSectionHeadingNumbering  = $false
        EnableMultiLevelToc            = $true
        EnableCollapsibleToc           = $true
        EnableFloatingToc              = $true
        KeepLeftTocOnNarrowScreens     = $false
        EnableCollapsibleSections      = $true
        OpenSectionsByDefault          = $true
        SectionNavMode                 = 'icons'
        SectionNavIconNumberPlacement  = 'arrow-before-number'
        TocPlacement                   = 'left'
        WindowLeft                     = $null
        WindowTop                      = $null
        WindowWidth                    = 1380
        WindowHeight                   = 860
        UiZoom                         = 1.0
        LeftPanelStarWidth             = 2.1
        RightPanelStarWidth            = 3.2
    }
}

function Read-Settings {
    $defaults = Get-DefaultSettings

    if (-not (Test-Path -LiteralPath $settingsPath)) {
        return [pscustomobject]$defaults
    }

    try {
        $raw = Get-Content -LiteralPath $settingsPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return [pscustomobject]$defaults
        }

        $fromFile = ConvertFrom-Json -InputObject $raw
        foreach ($k in $defaults.Keys) {
            if ($null -eq $fromFile.PSObject.Properties[$k]) {
                $fromFile | Add-Member -NotePropertyName $k -NotePropertyValue $defaults[$k]
            }
        }
        return $fromFile
    }
    catch {
        return [pscustomobject]$defaults
    }
}

function Write-Settings {
    param([Parameter(Mandatory = $true)][hashtable]$Settings)

    $json = $Settings | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($settingsPath, $json, [System.Text.Encoding]::UTF8)
}

function Get-SectionCountFromJsonFile {
    param([Parameter(Mandatory = $true)][string]$JsonPath)

    try {
        $doc = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
        return @($doc).Count
    }
    catch {
        return 0
    }
}

function ConvertTo-SafeJson {
    param([Parameter(Mandatory = $true)]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 12)
}

function Get-PowerShell7xComparisonSections {
    $sections = New-Object System.Collections.ArrayList

    $null = $sections.Add([pscustomobject]@{
        Id         = 'ps7x-overview'
        Title      = 'PowerShell 7.x Overview'
        Level      = 1
        Paragraphs = @(
            'This sample is intentionally large to stress-test TOC generation, intralinks, and search behavior.',
            'It summarizes PowerShell 7.0 through 7.5 with practical migration and operations notes.'
        )
        Bullets    = @(
            'Cross-platform shell and automation engine',
            'Frequent quality and performance improvements',
            'Useful for validating long-document navigation'
        )
    })

    $null = $sections.Add([pscustomobject]@{
        Id    = 'ps7x-release-timeline'
        Title = 'Release Timeline Snapshot'
        Level = 1
        Table = [pscustomobject]@{
            Columns = @('Version', 'Approx. Period', 'Support Focus')
            Rows    = @(
                @{ Version = '7.0'; Period = 'Initial major release'; Support = 'Foundation and cross-platform baseline' },
                @{ Version = '7.1'; Period = 'Early iteration'; Support = 'Language and usability refinements' },
                @{ Version = '7.2'; Period = 'LTS era'; Support = 'Stability, compatibility, enterprise adoption' },
                @{ Version = '7.3'; Period = 'Feature wave'; Support = 'Pipeline and scripting quality improvements' },
                @{ Version = '7.4'; Period = 'LTS refresh'; Support = 'Performance and operational hardening' },
                @{ Version = '7.5'; Period = 'Recent release'; Support = 'Further polish and incremental enhancements' }
            )
        }
    })

    $null = $sections.Add([pscustomobject]@{
        Id         = 'ps7x-testing-goals'
        Title      = 'How to Use This Large Sample'
        Level      = 1
        Paragraphs = @(
            'Use this file to validate search result navigation, sticky/floating TOC behavior, and section collapse interactions.',
            'Because it includes many headings, it is ideal for checking multi-level TOC readability and responsiveness.'
        )
        Numbered   = @(
            'Generate HTML with section links and collapsible sections enabled.',
            'Run broad and narrow searches (for example: remoting, pipeline, migration).',
            'Switch TOC placement between left and top to compare long-page usability.'
        )
    })

    $null = $sections.Add([pscustomobject]@{
        Id         = 'ps7x-migration-strategy'
        Title      = 'Migration Strategy at a Glance'
        Level      = 1
        Bullets    = @(
            'Inventory module dependencies and runtime prerequisites.',
            'Use test automation to compare output and behavior between versions.',
            'Roll out in phases with clear rollback checkpoints.'
        )
        CodeBlocks = @(
            '$PSVersionTable',
            'Get-Module -ListAvailable | Sort-Object Name, Version',
            'Get-Command -Module Microsoft.PowerShell.Management | Measure-Object'
        )
    })

    $versionTopics = @(
        [pscustomobject]@{ Version = '7.0'; Previous = 'Windows PowerShell 5.1'; Focus = 'cross-platform baseline and compatibility' },
        [pscustomobject]@{ Version = '7.1'; Previous = '7.0'; Focus = 'iteration on scripting ergonomics' },
        [pscustomobject]@{ Version = '7.2'; Previous = '7.1'; Focus = 'LTS stability and enterprise readiness' },
        [pscustomobject]@{ Version = '7.3'; Previous = '7.2'; Focus = 'quality-of-life and language refinements' },
        [pscustomobject]@{ Version = '7.4'; Previous = '7.3'; Focus = 'LTS performance and operations improvements' },
        [pscustomobject]@{ Version = '7.5'; Previous = '7.4'; Focus = 'recent incremental platform polish' }
    )

    foreach ($topic in $versionTopics) {
        $safeVersionId = ($topic.Version -replace '\.', '-')

        $null = $sections.Add([pscustomobject]@{
            Id         = "ps$safeVersionId-overview"
            Title      = "PowerShell $($topic.Version) Overview"
            Level      = 1
            Paragraphs = @(
                "PowerShell $($topic.Version) emphasizes $($topic.Focus).",
                "Compared with $($topic.Previous), this release continues to improve developer and operator workflows."
            )
        })

        $null = $sections.Add([pscustomobject]@{
            Id      = "ps$safeVersionId-highlights"
            Title   = "PowerShell $($topic.Version) Key Highlights"
            Level   = 2
            Bullets = @(
                "Improved consistency for day-to-day scripting compared with $($topic.Previous).",
                'Better diagnostics and reduced troubleshooting friction.',
                'Incremental quality updates to core engine behavior.'
            )
            Table   = [pscustomobject]@{
                Columns = @('Theme', 'Why It Matters', 'Version Contrast')
                Rows    = @(
                    @{ Theme = 'Compatibility'; Why = 'Reduces migration surprises'; Contrast = "$($topic.Previous) -> $($topic.Version)" },
                    @{ Theme = 'Developer Flow'; Why = 'Improves script author productivity'; Contrast = 'Cleaner authoring and troubleshooting loops' },
                    @{ Theme = 'Operations'; Why = 'Lowers support overhead'; Contrast = 'More predictable run-time behavior' }
                )
            }
            CodeBlocks = @(
                '# Quick environment snapshot',
                '$PSVersionTable | Format-List *',
                'Get-Host',
                'Get-ExecutionPolicy -List'
            )
        })

        $null = $sections.Add([pscustomobject]@{
            Id         = "ps$safeVersionId-language-engine"
            Title      = "PowerShell $($topic.Version) Language and Engine Notes"
            Level      = 2
            Paragraphs = @(
                'Language and engine refinements focus on predictable behavior and clearer script intent.',
                "When comparing to $($topic.Previous), review parsing edge cases and preference variable usage in automation."
            )
            CodeBlocks = @(
                "`$PSVersionTable.PSVersion  # Verify running version $($topic.Version)",
                'Set-StrictMode -Version Latest',
                "Get-Command ForEach-Object | Select-Object Name, Version",
                "Get-Variable PSStyle -ErrorAction SilentlyContinue",
                "Get-Command -Type Cmdlet | Where-Object { `$_.Name -like 'Get-*' } | Select-Object -First 10 Name"
            )
            Table = [pscustomobject]@{
                Columns = @('Language Area', 'Test Focus', 'Example Check')
                Rows    = @(
                    @{ 'Language Area' = 'Parsing'; 'Test Focus' = 'Tokenization and quoting'; 'Example Check' = 'Run scripts with nested quotes and subexpressions' },
                    @{ 'Language Area' = 'Pipeline'; 'Test Focus' = 'Object flow and null handling'; 'Example Check' = 'Compare filtering behavior on mixed objects' },
                    @{ 'Language Area' = 'Error Model'; 'Test Focus' = 'Terminating vs non-terminating errors'; 'Example Check' = 'Validate try/catch and $ErrorActionPreference paths' }
                )
            }
        })

        $null = $sections.Add([pscustomobject]@{
            Id         = "ps$safeVersionId-remoting-security"
            Title      = "PowerShell $($topic.Version) Remoting and Security"
            Level      = 2
            Paragraphs = @(
                'Review endpoint configuration, authentication expectations, and constrained execution patterns.',
                "Validate remoting behavior differences versus $($topic.Previous) in your target environments."
            )
            Bullets    = @(
                'Test remote command execution in isolated environments first.',
                'Reconfirm logging, transcript, and auditing requirements.',
                'Document any policy updates required for deployment.'
            )
            Table = [pscustomobject]@{
                Columns = @('Security Area', 'Checklist Item', 'Verification Command')
                Rows    = @(
                    @{ 'Security Area' = 'Authentication'; 'Checklist Item' = 'Validate mechanism and fallback path'; 'Verification Command' = 'Get-PSSessionConfiguration' },
                    @{ 'Security Area' = 'Transcription'; 'Checklist Item' = 'Confirm transcript capture and retention'; 'Verification Command' = 'Get-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -ErrorAction SilentlyContinue' },
                    @{ 'Security Area' = 'Policy'; 'Checklist Item' = 'Confirm execution policy expectations'; 'Verification Command' = 'Get-ExecutionPolicy -List' }
                )
            }
            CodeBlocks = @(
                'Test-WSMan -ComputerName localhost',
                'Get-PSSessionConfiguration | Select-Object Name, Permission',
                'Get-ExecutionPolicy -List'
            )
        })

        $null = $sections.Add([pscustomobject]@{
            Id    = "ps$safeVersionId-performance-ops"
            Title = "PowerShell $($topic.Version) Performance and Operations"
            Level = 2
            Table = [pscustomobject]@{
                Columns = @('Area', 'What to Compare', 'Validation Idea')
                Rows    = @(
                    @{ Area = 'Startup'; Compare = "$($topic.Previous) vs $($topic.Version)"; Validation = 'Measure launch and module import patterns' },
                    @{ Area = 'Pipeline'; Compare = 'Object-heavy scripts'; Validation = 'Benchmark representative automation runs' },
                    @{ Area = 'Reliability'; Compare = 'Error handling behavior'; Validation = 'Replay failure scenarios with test data' }
                )
            }
            CodeBlocks = @(
                '$sw = [System.Diagnostics.Stopwatch]::StartNew(); 1..1000 | ForEach-Object { $_ * 2 } | Out-Null; $sw.Stop(); $sw.ElapsedMilliseconds',
                'Measure-Command { Get-ChildItem -Path . -Recurse -ErrorAction SilentlyContinue | Select-Object -First 200 | Out-Null }',
                "Get-Process -Name pwsh -ErrorAction SilentlyContinue | Select-Object Name, CPU, PM"
            )
        })

        $null = $sections.Add([pscustomobject]@{
            Id       = "ps$safeVersionId-migration-checklist"
            Title    = "PowerShell $($topic.Version) Migration Checklist"
            Level    = 2
            Numbered = @(
                'Run Pester or equivalent regression tests for critical scripts.',
                'Verify module compatibility and update pinned dependencies.',
                'Compare output formatting and serialization behavior.',
                'Update runbook documentation and operational notes.'
            )
            Table = [pscustomobject]@{
                Columns = @('Step', 'Owner', 'Done Criteria')
                Rows    = @(
                    @{ Step = 'Baseline'; Owner = 'Engineering'; 'Done Criteria' = 'Existing script behavior documented and reproducible' },
                    @{ Step = 'Validate'; Owner = 'QA'; 'Done Criteria' = 'Regression pass completed with expected outputs' },
                    @{ Step = 'Deploy'; Owner = 'Operations'; 'Done Criteria' = 'Runbooks updated and rollout approved' }
                )
            }
            CodeBlocks = @(
                "# Example migration checks for version $($topic.Version)",
                'Get-Module -ListAvailable | Sort-Object Name, Version | Select-Object -First 20',
                'Get-Command -All *-PSSession | Select-Object Name, Source',
                'Get-Help about_Preference_Variables -ErrorAction SilentlyContinue | Out-Null'
            )
        })

        $appendixSets = @(
            [pscustomobject]@{
                IdSuffix = 'appendix-catalog-core'
                Title = "Version Command Catalog Core ($($topic.Version))"
                Keywords = @('Get-Help', 'Get-Command', 'Get-Module', 'Import-Module')
            },
            [pscustomobject]@{
                IdSuffix = 'appendix-catalog-ops'
                Title = "Version Command Catalog Ops ($($topic.Version))"
                Keywords = @('Measure-Command', 'Start-Job', 'Receive-Job', 'Stop-Job')
            },
            [pscustomobject]@{
                IdSuffix = 'appendix-catalog-remoting'
                Title = "Version Command Catalog Remoting ($($topic.Version))"
                Keywords = @('New-PSSession', 'Invoke-Command', 'Enter-PSSession', 'Remove-PSSession')
            },
            [pscustomobject]@{
                IdSuffix = 'appendix-catalog-security'
                Title = "Version Command Catalog Security ($($topic.Version))"
                Keywords = @('Get-ExecutionPolicy', 'Set-ExecutionPolicy', 'Set-StrictMode', 'Get-AuthenticodeSignature')
            }
        )

        foreach ($appendix in $appendixSets) {
            $null = $sections.Add([pscustomobject]@{
                Id         = "ps$safeVersionId-$($appendix.IdSuffix)"
                Title      = $appendix.Title
                Level      = 3
                Paragraphs = @(
                    "Appendix section for PowerShell $($topic.Version) command discovery and comparison.",
                    "Use this catalog to expand search scope and increase long-page navigation load."
                )
                Table      = [pscustomobject]@{
                    Columns = @('Command', 'Category', 'Comparison Note')
                    Rows    = @(
                        @{ Command = $appendix.Keywords[0]; Category = 'Discovery'; 'Comparison Note' = "Check behavior in $($topic.Previous) vs $($topic.Version)" },
                        @{ Command = $appendix.Keywords[1]; Category = 'Discovery'; 'Comparison Note' = 'Validate output shape and parameter sets' },
                        @{ Command = $appendix.Keywords[2]; Category = 'Operations'; 'Comparison Note' = 'Confirm module loading and compatibility' },
                        @{ Command = $appendix.Keywords[3]; Category = 'Operations'; 'Comparison Note' = 'Test in automation scenarios' }
                    )
                }
                CodeBlocks = @(
                    "# Command catalog spot-check for version $($topic.Version)",
                    "Get-Command $($appendix.Keywords[0]) -ErrorAction SilentlyContinue | Format-List Name, Source",
                    "Get-Command $($appendix.Keywords[1]) -ErrorAction SilentlyContinue | Select-Object Name, Version",
                    "Get-Command $($appendix.Keywords[2]) -ErrorAction SilentlyContinue | Select-Object Name, Source",
                    "Get-Command $($appendix.Keywords[3]) -ErrorAction SilentlyContinue | Select-Object Name, Source"
                )
            })
        }
    }

    return @($sections)
}

function Get-SampleDefinitions {
    return @(
        [pscustomobject]@{
            FileName    = 'HtmlToc.Sample.Basic.json'
            Title       = 'Basic Sections'
            Description = 'Short sample with paragraphs, bullets, and a table.'
            Notes       = 'Good for a quick smoke test.'
            Sections    = @(
                [pscustomobject]@{
                    Id         = 'intro'
                    Title      = 'Introduction'
                    Level      = 1
                    Paragraphs = @(
                        'This sample demonstrates the HtmlToc framework with a simple structure.',
                        'Use it to verify the GridView selector, output generation, and open-file option.'
                    )
                    Bullets    = @(
                        'Structured sections',
                        'Top / Previous / Next intralinks',
                        'Small Top link after each section'
                    )
                },
                [pscustomobject]@{
                    Id         = 'table-demo'
                    Title      = 'Simple Table'
                    Level      = 2
                    Paragraphs = @('This section includes a table and a short code block.')
                    Table      = [pscustomobject]@{
                        Columns = @('Name', 'Value')
                        Rows    = @(
                            @{ Name = 'Alpha'; Value = '10' },
                            @{ Name = 'Beta';  Value = '20' }
                        )
                    }
                    CodeBlocks = @(
                        '.\HtmlToc.ps1 -SectionsPath .\HtmlToc.Test.Samples\HtmlToc.Sample.Basic.json -EnableSectionNavLinks -EnableCollapsibleToc -EnableCollapsibleSections -EnableTopLinkAfterSection'
                    )
                },
                [pscustomobject]@{
                    Id    = 'end'
                    Title = 'End'
                    Level = 1
                    Html  = '<p><strong>Tip:</strong> This is a compact sample for fast verification.</p>'
                }
            )
        },
        [pscustomobject]@{
            FileName    = 'HtmlToc.Sample.Tables.json'
            Title       = 'Tables and Formatting'
            Description = 'Focuses on tables, numbered lists, and mixed formatting.'
            Notes       = 'Good for formatting and table rendering checks.'
            Sections    = @(
                [pscustomobject]@{
                    Id         = 'overview'
                    Title      = 'Overview'
                    Level      = 1
                    Paragraphs = @(
                        'This sample emphasizes table rendering and section-level navigation.',
                        'It also includes multiple blocks of formatted content.'
                    )
                },
                [pscustomobject]@{
                    Id        = 'features'
                    Title     = 'Feature Matrix'
                    Level     = 2
                    Numbered  = @(
                        'Multiple section content types',
                        'WPF GridView sample selection',
                        'Auto-generated output names'
                    )
                    Table     = [pscustomobject]@{
                        Columns = @('Feature', 'Status', 'Notes')
                        Rows    = @(
                            @{ Feature = 'Section nav'; Status = 'On';  Notes = 'Top/Previous/Next available' },
                            @{ Feature = 'Top link';    Status = 'On';  Notes = 'Small link after each section' },
                            @{ Feature = 'Collapsible';  Status = 'On';  Notes = 'Sections and TOC can collapse' }
                        )
                    }
                },
                [pscustomobject]@{
                    Id         = 'notes'
                    Title      = 'Notes'
                    Level      = 2
                    Paragraphs = @('This sample is handy when you want to confirm table styling and link spacing.')
                }
            )
        },
        [pscustomobject]@{
            FileName    = 'HtmlToc.Sample.Deep.json'
            Title       = 'Deep Nested Outline'
            Description = 'Multi-level headings for nested TOC and intralink stress testing.'
            Notes       = 'Good for long pages and scrollspy behavior.'
            Sections    = @(
                [pscustomobject]@{ Id = 'part-1'; Title = 'Part I'; Level = 1; Paragraphs = @('A root-level section to start the outline.') },
                [pscustomobject]@{ Id = 'part-1-a'; Title = 'Part I.A'; Level = 2; Paragraphs = @('Nested section A.') },
                [pscustomobject]@{ Id = 'part-1-b'; Title = 'Part I.B'; Level = 2; Paragraphs = @('Nested section B.') },
                [pscustomobject]@{ Id = 'part-1-b-1'; Title = 'Part I.B.1'; Level = 3; Paragraphs = @('Deeper nesting for TOC indentation and section navigation.') },
                [pscustomobject]@{ Id = 'part-2'; Title = 'Part II'; Level = 1; Paragraphs = @('A second root-level section.') },
                [pscustomobject]@{ Id = 'part-2-a'; Title = 'Part II.A'; Level = 2; Paragraphs = @('Another nested section.') },
                [pscustomobject]@{
                    Id    = 'part-2-a-table'
                    Title = 'Part II.A Table'
                    Level = 3
                    Table = [pscustomobject]@{
                        Columns = @('Item', 'Detail')
                        Rows    = @(
                            @{ Item = 'Scroll'; Detail = 'Long document behavior' },
                            @{ Item = 'TOC'; Detail = 'Nested anchors' }
                        )
                    }
                }
            )
        },
        [pscustomobject]@{
            FileName    = 'HtmlToc.Sample.PowerShell7x.40Sections.json'
            Title       = 'PowerShell 7.x Comparison (40 Sections)'
            Description = 'Large sample with 40 sections covering PowerShell 7.0-7.5 highlights and comparisons.'
            Notes       = 'Stress test for search, multi-level TOC, and long-page navigation.'
            Sections    = Get-PowerShell7xComparisonSections
        }
    )
}

function Ensure-SampleFiles {
    param([switch]$Force)

    if (-not (Test-Path -LiteralPath $samplesRoot)) {
        New-Item -ItemType Directory -Path $samplesRoot -Force | Out-Null
    }

    $sampleDefinitions = Get-SampleDefinitions
    $definitionMap = @{}

    foreach ($sample in $sampleDefinitions) {
        $path = Join-Path $samplesRoot $sample.FileName
        $json = ConvertTo-SafeJson -InputObject $sample.Sections

        if ($Force -or -not (Test-Path -LiteralPath $path)) {
            [System.IO.File]::WriteAllText($path, $json, [System.Text.Encoding]::UTF8)
        }

        $definitionMap[$sample.FileName] = [pscustomobject]@{
            Title       = $sample.Title
            Description = $sample.Description
            Notes       = $sample.Notes
            Sections    = @($sample.Sections).Count
        }
    }

    $result = @()
    $allJsonFiles = Get-ChildItem -LiteralPath $samplesRoot -Filter '*.json' -File | Sort-Object Name

    foreach ($item in $allJsonFiles) {
        $fileName = $item.Name
        $meta = $definitionMap[$fileName]
        $title = ''
        $description = ''
        $notes = ''
        $sections = 0

        if ($meta) {
            $title = [string]$meta.Title
            $description = [string]$meta.Description
            $notes = [string]$meta.Notes
            $sections = [int]$meta.Sections
        }
        else {
            $sections = Get-SectionCountFromJsonFile -JsonPath $item.FullName
            $title = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $description = 'External JSON sample discovered in sample folder.'
            $notes = 'Auto-discovered sample file.'
        }

        $result += [pscustomobject]@{
            FileName    = $fileName
            Path        = $item.FullName
            Sections    = $sections
            Title       = $title
            Description = $description
            Notes       = $notes
        }
    }

    return $result | Sort-Object FileName
}

function Get-AutoOutputPath {
    param([Parameter(Mandatory = $true)][string]$InputPath)

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    $directory = [System.IO.Path]::GetDirectoryName($InputPath)
    return Join-Path $directory ("{0}.{1}.html" -f $baseName, $stamp)
}

function Invoke-HtmlTocBuild {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $false)][string]$Description,
        [Parameter(Mandatory = $false)][string]$SectionNavMode = 'icons',
        [Parameter(Mandatory = $false)][string]$SectionNavIconNumberPlacement = 'arrow-before-number',
        [Parameter(Mandatory = $false)][bool]$EnableSectionNavLinks = $true,
        [Parameter(Mandatory = $false)][bool]$EnableMultiLevelToc = $true,
        [Parameter(Mandatory = $false)][bool]$EnableCollapsibleToc = $true,
        [Parameter(Mandatory = $false)][bool]$EnableCollapsibleSections = $true,
        [Parameter(Mandatory = $false)][bool]$EnableTopLinkAfterSection = $true,
        [Parameter(Mandatory = $false)][bool]$EnableSectionHeadingNumbering = $false,
        [Parameter(Mandatory = $false)][string]$TocPlacement = 'left',
        [Parameter(Mandatory = $false)][bool]$EnableFloatingToc = $true,
        [Parameter(Mandatory = $false)][bool]$KeepLeftTocOnNarrowScreens = $false,
        [Parameter(Mandatory = $false)][bool]$OpenSectionsByDefault = $true,
        [Parameter(Mandatory = $false)][bool]$OpenGeneratedFile = $false
    )

    $normalizedNavMode = 'icons'
    if (-not [string]::IsNullOrWhiteSpace($SectionNavMode)) {
        $candidate = $SectionNavMode.Trim().ToLowerInvariant()
        if ($candidate -in @('icons', 'text')) {
            $normalizedNavMode = $candidate
        }
    }

    $invokeParams = @{
        SectionsPath    = $InputPath
        Title           = $Title
        OutputPath      = $OutputPath
        SectionNavMode  = $normalizedNavMode
        SectionNavIconNumberPlacement = $SectionNavIconNumberPlacement
        TocPlacement    = $TocPlacement
        EnableFloatingToc = $EnableFloatingToc
    }

    if ($Description) { $invokeParams.DocumentDescription = $Description }
    if ($EnableSectionNavLinks) { $invokeParams.EnableSectionNavLinks = $true }
    if ($EnableMultiLevelToc) { $invokeParams.EnableMultiLevelToc = $true }
    if ($EnableCollapsibleToc) { $invokeParams.EnableCollapsibleToc = $true }
    if ($EnableCollapsibleSections) { $invokeParams.EnableCollapsibleSections = $true }
    if ($EnableTopLinkAfterSection) { $invokeParams.EnableTopLinkAfterSection = $true }
    if ($EnableSectionHeadingNumbering) { $invokeParams.EnableSectionHeadingNumbering = $true }
    if ($KeepLeftTocOnNarrowScreens) { $invokeParams.KeepLeftTocOnNarrowScreens = $true }
    if ($OpenSectionsByDefault) { $invokeParams.OpenSectionsByDefault = $true }

    $null = & $htmlTocScript @invokeParams

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        throw "HtmlToc.ps1 did not produce the expected output file: $OutputPath"
    }

    if ($OpenGeneratedFile -and (Test-Path -LiteralPath $OutputPath)) {
        Invoke-Item -LiteralPath $OutputPath
    }
}

$sampleItems = Ensure-SampleFiles

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HtmlToc Test Harness NC - July 2026🏖️"
        Height="860"
        Width="1380"
        WindowStartupLocation="CenterScreen"
        Background="#F4F8FB"
        FontFamily="Segoe UI">
    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <Border Background="#FFFFFF" BorderBrush="#D7E0E8" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,12">
            <StackPanel>
                <TextBlock Text="HtmlToc Test Harness NC - July 2026🏖️" FontSize="22" FontWeight="Bold" Foreground="#12344D" />
                <TextBlock Margin="0,6,0,0" TextWrapping="Wrap" Foreground="#52606D">
                    Pick a sample input file, choose the HtmlToc options, and click Test to generate the HTML output.
                </TextBlock>
            </StackPanel>
        </Border>

        <Grid x:Name="MainPanelsGrid" Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition x:Name="LeftPanelColumn" Width="2.1*" />
                <ColumnDefinition x:Name="RightPanelColumn" Width="3.2*" />
            </Grid.ColumnDefinitions>

            <GroupBox x:Name="LeftSampleGroupBox" Header="Sample Input Files" Margin="0,0,10,0" Padding="10">
                <DockPanel>
                    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,8">
                        <Button x:Name="RefreshSamplesButton" Content="Refresh / Recreate Samples" Padding="12,5" Margin="0,0,8,0" ToolTip="Rebuild and reload all sample JSON files" />
                        <Button x:Name="OpenSamplesFolderButton" Content="Open Samples Folder" Padding="12,5" ToolTip="Open the folder that contains sample input files" />
                    </StackPanel>
                    <ListView x:Name="SampleListView" SelectionMode="Single" BorderThickness="1" BorderBrush="#D7E0E8" ToolTip="Select a sample file to test HtmlToc output generation">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="File" DisplayMemberBinding="{Binding FileName}" Width="180" />
                                <GridViewColumn Header="Sections" DisplayMemberBinding="{Binding Sections}" Width="70" />
                                <GridViewColumn Header="Title" DisplayMemberBinding="{Binding Title}" Width="160" />
                                <GridViewColumn Header="Notes" DisplayMemberBinding="{Binding Notes}" Width="240" />
                            </GridView>
                        </ListView.View>
                    </ListView>
                </DockPanel>
            </GroupBox>

            <GroupBox Grid.Column="1" Header="Test Options" Padding="12">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*" />
                        <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <StackPanel x:Name="OptionsContentStackPanel">
                        <TextBlock Text="Selected input file" FontWeight="Bold" Margin="0,0,0,4" />
                        <TextBox x:Name="SelectedFileTextBox" IsReadOnly="True" Background="#F7FAFC" Margin="0,0,0,10" ToolTip="Full path of the currently selected sample file" />
                        <TextBlock x:Name="SelectedFileNameTextBlock" Margin="0,-6,0,10" Foreground="#52606D" TextWrapping="Wrap" ToolTip="Selected input filename" />

                        <TextBlock Text="HTML title" FontWeight="Bold" Margin="0,0,0,4" />
                        <TextBox x:Name="TitleTextBox" Margin="0,0,0,10" ToolTip="Document title to use in the generated HTML" />

                        <TextBlock Text="Document description" FontWeight="Bold" Margin="0,0,0,4" />
                        <TextBox x:Name="DescriptionTextBox" Height="70" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Margin="0,0,0,10" ToolTip="Optional description shown near the top of the generated page" />

                        <TextBlock Text="Output file" FontWeight="Bold" Margin="0,0,0,4" />
                        <DockPanel Margin="0,0,0,10">
                            <TextBox x:Name="OutputPathTextBox" Margin="0,0,8,0" ToolTip="Output HTML file path" />
                            <Button x:Name="AutoNameButton" Content="Auto Name" Padding="12,5" DockPanel.Dock="Right" ToolTip="Generate a timestamped output file name" />
                        </DockPanel>
                        <TextBlock x:Name="OutputFileNameTextBlock" Margin="0,-6,0,10" Foreground="#52606D" TextWrapping="Wrap" ToolTip="Output filename" />

                        <StackPanel Margin="0,0,0,10">
                            <CheckBox x:Name="OpenGeneratedFileCheckBox" Content="Open generated file after build" IsChecked="True" Margin="0,0,0,6" ToolTip="Automatically open the generated HTML when build completes" />
                            <CheckBox x:Name="EnableSectionNavLinksCheckBox" Content="Enable section intralinks (Top / Previous / Next)" IsChecked="True" Margin="0,0,0,6" ToolTip="Add Top, Previous, and Next links for section navigation" />
                            <CheckBox x:Name="EnableTopLinkAfterSectionCheckBox" Content="Add a small Top link after each section" IsChecked="True" Margin="0,0,0,6" ToolTip="Add a compact Top link after each section" />
                            <CheckBox x:Name="EnableSectionHeadingNumberingCheckBox" Content="Enable section heading numbering (1, 1.1, 1.1.1)" IsChecked="False" Margin="0,0,0,6" ToolTip="Prefix headings with hierarchical numbers" />
                            <CheckBox x:Name="EnableMultiLevelTocCheckBox" Content="Enable multi-level TOC" IsChecked="True" Margin="0,0,0,6" ToolTip="Show nested headings in the table of contents" />
                            <CheckBox x:Name="EnableCollapsibleTocCheckBox" Content="Enable collapsible TOC" IsChecked="True" Margin="0,0,0,6" ToolTip="Allow the table of contents to collapse/expand" />
                            <CheckBox x:Name="EnableFloatingTocCheckBox" Content="Keep TOC floating (sticky)" IsChecked="True" Margin="0,0,0,6" ToolTip="Keep the table of contents visible while scrolling" />
                            <CheckBox x:Name="KeepLeftTocOnNarrowScreensCheckBox" Content="Keep left TOC on narrow screens" IsChecked="False" Margin="0,0,0,6" ToolTip="Keep left-side TOC layout on smaller screens" />
                            <CheckBox x:Name="EnableCollapsibleSectionsCheckBox" Content="Enable collapsible section headings" IsChecked="True" Margin="0,0,0,6" ToolTip="Allow each section body to collapse or expand" />
                            <CheckBox x:Name="OpenSectionsByDefaultCheckBox" Content="Open sections by default" IsChecked="True" Margin="0,0,0,6" ToolTip="Start with section content expanded" />
                        </StackPanel>

                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <StackPanel Width="220" Margin="0,0,16,0">
                                <TextBlock Text="Section nav mode" FontWeight="Bold" Margin="0,0,0,4" />
                                <ComboBox x:Name="SectionNavModeComboBox" SelectedIndex="0" ToolTip="Choose whether section navigation shows icons or text labels">
                                    <ComboBoxItem Content="icons" />
                                    <ComboBoxItem Content="text" />
                                </ComboBox>

                                <TextBlock Text="Icon nav number placement" FontWeight="Bold" Margin="0,10,0,4" />
                                <ComboBox x:Name="SectionNavIconNumberPlacementComboBox" SelectedIndex="0" ToolTip="Set icon-number order for icon mode section navigation">
                                    <ComboBoxItem Content="arrow-before-number" />
                                    <ComboBoxItem Content="number-before-arrow" />
                                </ComboBox>
                            </StackPanel>
                            <StackPanel Width="220" Margin="0,0,16,0">
                                <TextBlock Text="TOC placement" FontWeight="Bold" Margin="0,0,0,4" />
                                <ComboBox x:Name="TocPlacementComboBox" SelectedIndex="0" ToolTip="Choose where the table of contents appears in the page layout">
                                    <ComboBoxItem Content="left" />
                                    <ComboBoxItem Content="top" />
                                </ComboBox>
                            </StackPanel>
                            <StackPanel Width="220">
                                <TextBlock Text="Selected sample summary" FontWeight="Bold" Margin="0,0,0,4" />
                                <TextBlock x:Name="SummaryTextBlock" TextWrapping="Wrap" Foreground="#52606D" />
                            </StackPanel>
                        </StackPanel>

                        </StackPanel>
                    </ScrollViewer>

                    <StackPanel Grid.Row="1" Margin="0,8,0,0">
                        <Separator Margin="0,0,0,12" />
                        <StackPanel Orientation="Horizontal">
                            <Button x:Name="TestButton" Content="Test" Padding="18,7" Margin="0,0,10,0" Background="#0A66C2" Foreground="White" ToolTip="Run HtmlToc with current options and generate output" />
                            <Button x:Name="ZoomLeftPanelButton" Content="+" Padding="12,7" Margin="0,0,6,0" ToolTip="Zoom in" />
                            <Button x:Name="ZoomRightPanelButton" Content="-" Padding="12,7" Margin="0,0,10,0" ToolTip="Zoom out" />
                            <Button x:Name="OpenOutputFolderButton" Content="Open Output Folder" Padding="14,7" Margin="0,0,10,0" ToolTip="Open the folder that contains the output HTML file" />
                            <TextBlock x:Name="StatusTextBlock" VerticalAlignment="Center" Foreground="#52606D" ToolTip="Latest status message for test actions" />
                        </StackPanel>
                    </StackPanel>
                </Grid>
            </GroupBox>
        </Grid>

        <Border Grid.Row="2" Background="#FFFFFF" BorderBrush="#D7E0E8" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,12,0,0">
            <TextBlock x:Name="HintTextBlock" TextWrapping="Wrap" Foreground="#52606D">
                Sample files are created in the HtmlToc.Test.Samples folder the first time you run the harness.
            </TextBlock>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$SampleListView = $window.FindName('SampleListView')
$RefreshSamplesButton = $window.FindName('RefreshSamplesButton')
$OpenSamplesFolderButton = $window.FindName('OpenSamplesFolderButton')
$SelectedFileTextBox = $window.FindName('SelectedFileTextBox')
$SelectedFileNameTextBlock = $window.FindName('SelectedFileNameTextBlock')
$TitleTextBox = $window.FindName('TitleTextBox')
$DescriptionTextBox = $window.FindName('DescriptionTextBox')
$OutputPathTextBox = $window.FindName('OutputPathTextBox')
$OutputFileNameTextBlock = $window.FindName('OutputFileNameTextBlock')
$AutoNameButton = $window.FindName('AutoNameButton')
$OpenGeneratedFileCheckBox = $window.FindName('OpenGeneratedFileCheckBox')
$EnableSectionNavLinksCheckBox = $window.FindName('EnableSectionNavLinksCheckBox')
$EnableTopLinkAfterSectionCheckBox = $window.FindName('EnableTopLinkAfterSectionCheckBox')
$EnableSectionHeadingNumberingCheckBox = $window.FindName('EnableSectionHeadingNumberingCheckBox')
$EnableMultiLevelTocCheckBox = $window.FindName('EnableMultiLevelTocCheckBox')
$EnableCollapsibleTocCheckBox = $window.FindName('EnableCollapsibleTocCheckBox')
$EnableFloatingTocCheckBox = $window.FindName('EnableFloatingTocCheckBox')
$KeepLeftTocOnNarrowScreensCheckBox = $window.FindName('KeepLeftTocOnNarrowScreensCheckBox')
$EnableCollapsibleSectionsCheckBox = $window.FindName('EnableCollapsibleSectionsCheckBox')
$OpenSectionsByDefaultCheckBox = $window.FindName('OpenSectionsByDefaultCheckBox')
$SectionNavModeComboBox = $window.FindName('SectionNavModeComboBox')
$SectionNavIconNumberPlacementComboBox = $window.FindName('SectionNavIconNumberPlacementComboBox')
$TocPlacementComboBox = $window.FindName('TocPlacementComboBox')
$SummaryTextBlock = $window.FindName('SummaryTextBlock')
$TestButton = $window.FindName('TestButton')
$ZoomLeftPanelButton = $window.FindName('ZoomLeftPanelButton')
$ZoomRightPanelButton = $window.FindName('ZoomRightPanelButton')
$OpenOutputFolderButton = $window.FindName('OpenOutputFolderButton')
$StatusTextBlock = $window.FindName('StatusTextBlock')
$MainPanelsGrid = $window.FindName('MainPanelsGrid')
$LeftSampleGroupBox = $window.FindName('LeftSampleGroupBox')
$OptionsContentStackPanel = $window.FindName('OptionsContentStackPanel')

$script:AppSettings = Read-Settings
$script:ContentZoom = 1.0

function Set-ComboByValue {
    param(
        [Parameter(Mandatory = $true)]$Combo,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $target = $Value.Trim().ToLowerInvariant()
    foreach ($item in $Combo.Items) {
        $content = ''
        if ($item -is [System.Windows.Controls.ComboBoxItem] -and $item.Content) {
            $content = [string]$item.Content
        }
        else {
            $content = [string]$item
        }

        if ($content.Trim().ToLowerInvariant() -eq $target) {
            $Combo.SelectedItem = $item
            return
        }
    }
}

function Get-ComboValue {
    param([Parameter(Mandatory = $true)]$Combo)

    $item = $Combo.SelectedItem
    if ($null -eq $item) { return '' }

    if ($item -is [System.Windows.Controls.ComboBoxItem] -and $item.Content) {
        return [string]$item.Content
    }
    return [string]$item
}

function Get-UiSettings {
    $selectedPath = ''
    if ($SampleListView.SelectedItem) {
        $selectedPath = [string]$SampleListView.SelectedItem.Path
    }

    $windowLeft = $window.Left
    $windowTop = $window.Top
    $windowWidth = $window.Width
    $windowHeight = $window.Height

    if ($window.WindowState -ne [System.Windows.WindowState]::Normal) {
        $bounds = $window.RestoreBounds
        if ($bounds.Width -gt 0 -and $bounds.Height -gt 0) {
            $windowLeft = $bounds.Left
            $windowTop = $bounds.Top
            $windowWidth = $bounds.Width
            $windowHeight = $bounds.Height
        }
    }

    $leftPanelStarWidth = 2.1
    $rightPanelStarWidth = 3.2
    if ($MainPanelsGrid -and $MainPanelsGrid.ColumnDefinitions.Count -ge 2) {
        if ($MainPanelsGrid.ColumnDefinitions[0].Width.IsStar) {
            $leftPanelStarWidth = [double]$MainPanelsGrid.ColumnDefinitions[0].Width.Value
        }
        if ($MainPanelsGrid.ColumnDefinitions[1].Width.IsStar) {
            $rightPanelStarWidth = [double]$MainPanelsGrid.ColumnDefinitions[1].Width.Value
        }
    }

    return @{
        SelectedSamplePath             = $selectedPath
        OpenGeneratedFile              = [bool]$OpenGeneratedFileCheckBox.IsChecked
        EnableSectionNavLinks          = [bool]$EnableSectionNavLinksCheckBox.IsChecked
        EnableTopLinkAfterSection      = [bool]$EnableTopLinkAfterSectionCheckBox.IsChecked
        EnableSectionHeadingNumbering  = [bool]$EnableSectionHeadingNumberingCheckBox.IsChecked
        EnableMultiLevelToc            = [bool]$EnableMultiLevelTocCheckBox.IsChecked
        EnableCollapsibleToc           = [bool]$EnableCollapsibleTocCheckBox.IsChecked
        EnableFloatingToc              = [bool]$EnableFloatingTocCheckBox.IsChecked
        KeepLeftTocOnNarrowScreens     = [bool]$KeepLeftTocOnNarrowScreensCheckBox.IsChecked
        EnableCollapsibleSections      = [bool]$EnableCollapsibleSectionsCheckBox.IsChecked
        OpenSectionsByDefault          = [bool]$OpenSectionsByDefaultCheckBox.IsChecked
        SectionNavMode                 = (Get-ComboValue -Combo $SectionNavModeComboBox)
        SectionNavIconNumberPlacement  = (Get-ComboValue -Combo $SectionNavIconNumberPlacementComboBox)
        TocPlacement                   = (Get-ComboValue -Combo $TocPlacementComboBox)
        WindowLeft                     = $windowLeft
        WindowTop                      = $windowTop
        WindowWidth                    = $windowWidth
        WindowHeight                   = $windowHeight
        UiZoom                         = [double]$script:ContentZoom
        LeftPanelStarWidth             = $leftPanelStarWidth
        RightPanelStarWidth            = $rightPanelStarWidth
    }
}

function Save-UiSettings {
    try {
        Write-Settings -Settings (Get-UiSettings)
    }
    catch {
        # Non-fatal: settings persistence should not block test usage.
    }
}

function Apply-SettingsToUi {
    param([Parameter(Mandatory = $true)]$Settings)

    $OpenGeneratedFileCheckBox.IsChecked = [bool]$Settings.OpenGeneratedFile
    $EnableSectionNavLinksCheckBox.IsChecked = [bool]$Settings.EnableSectionNavLinks
    $EnableTopLinkAfterSectionCheckBox.IsChecked = [bool]$Settings.EnableTopLinkAfterSection
    $EnableSectionHeadingNumberingCheckBox.IsChecked = [bool]$Settings.EnableSectionHeadingNumbering
    $EnableMultiLevelTocCheckBox.IsChecked = [bool]$Settings.EnableMultiLevelToc
    $EnableCollapsibleTocCheckBox.IsChecked = [bool]$Settings.EnableCollapsibleToc
    $EnableFloatingTocCheckBox.IsChecked = [bool]$Settings.EnableFloatingToc
    $KeepLeftTocOnNarrowScreensCheckBox.IsChecked = [bool]$Settings.KeepLeftTocOnNarrowScreens
    $EnableCollapsibleSectionsCheckBox.IsChecked = [bool]$Settings.EnableCollapsibleSections
    $OpenSectionsByDefaultCheckBox.IsChecked = [bool]$Settings.OpenSectionsByDefault

    Set-ComboByValue -Combo $SectionNavModeComboBox -Value ([string]$Settings.SectionNavMode)
    Set-ComboByValue -Combo $SectionNavIconNumberPlacementComboBox -Value ([string]$Settings.SectionNavIconNumberPlacement)
    Set-ComboByValue -Combo $TocPlacementComboBox -Value ([string]$Settings.TocPlacement)
}

function Apply-WindowSettings {
    param([Parameter(Mandatory = $true)]$Settings)

    $width = 0.0
    $height = 0.0
    $left = 0.0
    $top = 0.0

    $hasWidth = [double]::TryParse([string]$Settings.WindowWidth, [ref]$width) -and $width -gt 300
    $hasHeight = [double]::TryParse([string]$Settings.WindowHeight, [ref]$height) -and $height -gt 300
    $hasLeft = [double]::TryParse([string]$Settings.WindowLeft, [ref]$left)
    $hasTop = [double]::TryParse([string]$Settings.WindowTop, [ref]$top)

    $virtualLeft = [double][System.Windows.SystemParameters]::VirtualScreenLeft
    $virtualTop = [double][System.Windows.SystemParameters]::VirtualScreenTop
    $virtualWidth = [double][System.Windows.SystemParameters]::VirtualScreenWidth
    $virtualHeight = [double][System.Windows.SystemParameters]::VirtualScreenHeight

    if ($virtualWidth -lt 800) { $virtualWidth = 800 }
    if ($virtualHeight -lt 600) { $virtualHeight = 600 }

    $minWidth = 900.0
    $minHeight = 650.0
    $maxWidth = [Math]::Max($minWidth, $virtualWidth - 20)
    $maxHeight = [Math]::Max($minHeight, $virtualHeight - 20)

    if ($hasWidth) {
        $window.Width = [Math]::Min([Math]::Max($width, $minWidth), $maxWidth)
    }

    if ($hasHeight) {
        $window.Height = [Math]::Min([Math]::Max($height, $minHeight), $maxHeight)
    }

    if (-not $hasWidth -and $window.Width -gt $maxWidth) {
        $window.Width = $maxWidth
    }

    if (-not $hasHeight -and $window.Height -gt $maxHeight) {
        $window.Height = $maxHeight
    }

    if ($hasLeft -and $hasTop) {
        $safeLeftMin = $virtualLeft + 10
        $safeTopMin = $virtualTop + 10
        $safeLeftMax = ($virtualLeft + $virtualWidth) - $window.Width - 10
        $safeTopMax = ($virtualTop + $virtualHeight) - $window.Height - 10

        if ($safeLeftMax -lt $safeLeftMin) { $safeLeftMax = $safeLeftMin }
        if ($safeTopMax -lt $safeTopMin) { $safeTopMax = $safeTopMin }

        $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
        $window.Left = [Math]::Min([Math]::Max($left, $safeLeftMin), $safeLeftMax)
        $window.Top = [Math]::Min([Math]::Max($top, $safeTopMin), $safeTopMax)
    }
    else {
        $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    }
}

function Update-SelectionUi {
    param([Parameter(Mandatory = $true)]$SelectedSample)

    if ($null -eq $SelectedSample) { return }

    $SelectedFileTextBox.Text = $SelectedSample.Path
    $TitleTextBox.Text = $SelectedSample.Title
    $DescriptionTextBox.Text = $SelectedSample.Description
    $OutputPathTextBox.Text = Get-AutoOutputPath -InputPath $SelectedSample.Path
    $SummaryTextBlock.Text = "Sections: $($SelectedSample.Sections) | $($SelectedSample.Notes)"
    Update-PathFileNameLabels
}

function Get-LeafNameOrPlaceholder {
    param(
        [Parameter(Mandatory = $false)][string]$PathValue,
        [Parameter(Mandatory = $true)][string]$EmptyLabel
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $EmptyLabel
    }

    try {
        $leaf = [System.IO.Path]::GetFileName($PathValue)
        if ([string]::IsNullOrWhiteSpace($leaf)) {
            return $PathValue
        }
        return $leaf
    }
    catch {
        return $PathValue
    }
}

function Update-PathFileNameLabels {
    $selectedLeaf = Get-LeafNameOrPlaceholder -PathValue ([string]$SelectedFileTextBox.Text) -EmptyLabel '(no selected input file)'
    $outputLeaf = Get-LeafNameOrPlaceholder -PathValue ([string]$OutputPathTextBox.Text) -EmptyLabel '(no output file path yet)'

    $SelectedFileNameTextBlock.Text = "File: $selectedLeaf"
    $OutputFileNameTextBlock.Text = "File: $outputLeaf"
}

function Load-SamplesIntoGrid {
    $script:CurrentSamples = Ensure-SampleFiles
    $SampleListView.ItemsSource = $script:CurrentSamples

    if ($SampleListView.Items.Count -eq 0) { return }

    $savedPath = [string]$script:AppSettings.SelectedSamplePath
    if (-not [string]::IsNullOrWhiteSpace($savedPath)) {
        $match = $script:CurrentSamples | Where-Object { $_.Path -eq $savedPath } | Select-Object -First 1
        if ($match) {
            $SampleListView.SelectedItem = $match
            return
        }
    }

    $SampleListView.SelectedIndex = 0
}

function Set-PanelSplit {
    param(
        [Parameter(Mandatory = $true)][double]$DeltaLeftStar
    )

    if ($null -eq $MainPanelsGrid -or $MainPanelsGrid.ColumnDefinitions.Count -lt 2) {
        return
    }

    $leftColumn = $MainPanelsGrid.ColumnDefinitions[0]
    $rightColumn = $MainPanelsGrid.ColumnDefinitions[1]

    $leftValue = if ($leftColumn.Width.IsStar) { [double]$leftColumn.Width.Value } else { 2.1 }
    $rightValue = if ($rightColumn.Width.IsStar) { [double]$rightColumn.Width.Value } else { 3.2 }

    $newLeft = $leftValue + $DeltaLeftStar
    $newRight = $rightValue - $DeltaLeftStar

    $minStar = 1.0
    if ($newLeft -lt $minStar -or $newRight -lt $minStar) {
        return
    }

    $leftColumn.Width = New-Object System.Windows.GridLength($newLeft, [System.Windows.GridUnitType]::Star)
    $rightColumn.Width = New-Object System.Windows.GridLength($newRight, [System.Windows.GridUnitType]::Star)
}

function Apply-PanelSplitSettings {
    param([Parameter(Mandatory = $true)]$Settings)

    if ($null -eq $MainPanelsGrid -or $MainPanelsGrid.ColumnDefinitions.Count -lt 2) {
        return
    }

    $left = 0.0
    $right = 0.0
    $hasLeft = [double]::TryParse([string]$Settings.LeftPanelStarWidth, [ref]$left)
    $hasRight = [double]::TryParse([string]$Settings.RightPanelStarWidth, [ref]$right)

    if (-not $hasLeft -or -not $hasRight) {
        return
    }

    $minStar = 1.0
    if ($left -lt $minStar -or $right -lt $minStar) {
        return
    }

    $MainPanelsGrid.ColumnDefinitions[0].Width = New-Object System.Windows.GridLength($left, [System.Windows.GridUnitType]::Star)
    $MainPanelsGrid.ColumnDefinitions[1].Width = New-Object System.Windows.GridLength($right, [System.Windows.GridUnitType]::Star)
}

function Set-ContentZoom {
    param(
        [Parameter(Mandatory = $true)][double]$Zoom,
        [switch]$SkipSave,
        [switch]$SkipStatus
    )

    $minZoom = 0.75
    $maxZoom = 1.8
    $normalizedZoom = [Math]::Round([Math]::Min([Math]::Max($Zoom, $minZoom), $maxZoom), 2)

    if ($LeftSampleGroupBox) {
        $LeftSampleGroupBox.LayoutTransform = New-Object System.Windows.Media.ScaleTransform($normalizedZoom, $normalizedZoom)
    }

    if ($OptionsContentStackPanel) {
        $OptionsContentStackPanel.LayoutTransform = New-Object System.Windows.Media.ScaleTransform($normalizedZoom, $normalizedZoom)
    }

    $script:ContentZoom = $normalizedZoom

    if (-not $SkipStatus) {
        $StatusTextBlock.Text = "Zoom: $([int]($normalizedZoom * 100))%"
    }

    if (-not $SkipSave) {
        Save-UiSettings
    }
}

function Apply-ZoomSettings {
    param([Parameter(Mandatory = $true)]$Settings)

    $zoom = 1.0
    if ($Settings -and [double]::TryParse([string]$Settings.UiZoom, [ref]$zoom)) {
        Set-ContentZoom -Zoom $zoom -SkipSave -SkipStatus
        return
    }

    Set-ContentZoom -Zoom 1.0 -SkipSave -SkipStatus
}

$SampleListView.Add_SelectionChanged({
    $selected = $SampleListView.SelectedItem
    if ($selected) {
        Update-SelectionUi -SelectedSample $selected
        Save-UiSettings
    }
})

$OutputPathTextBox.Add_TextChanged({
    Update-PathFileNameLabels
})

$AutoNameButton.Add_Click({
    $selected = $SampleListView.SelectedItem
    if ($selected) {
        $OutputPathTextBox.Text = Get-AutoOutputPath -InputPath $selected.Path
        $StatusTextBlock.Text = 'Output file name regenerated.'
        Save-UiSettings
    }
})

$RefreshSamplesButton.Add_Click({
    try {
        $StatusTextBlock.Text = 'Refreshing sample files...'
        $script:CurrentSamples = Ensure-SampleFiles -Force
        $SampleListView.ItemsSource = $null
        $SampleListView.ItemsSource = $script:CurrentSamples
        if ($SampleListView.Items.Count -gt 0) {
            $SampleListView.SelectedIndex = 0
        }
        $StatusTextBlock.Text = "Loaded $($script:CurrentSamples.Count) sample files."
        Save-UiSettings
    }
    catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Refresh failed', 'OK', 'Error') | Out-Null
        $StatusTextBlock.Text = 'Refresh failed.'
    }
})

$OpenSamplesFolderButton.Add_Click({
    if (Test-Path -LiteralPath $samplesRoot) {
        Invoke-Item -LiteralPath $samplesRoot
    }
})

$OpenOutputFolderButton.Add_Click({
    try {
        $outputPath = [string]$OutputPathTextBox.Text
        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            $StatusTextBlock.Text = 'No output path is set yet.'
            return
        }

        $outputDir = [System.IO.Path]::GetDirectoryName($outputPath)
        if ([string]::IsNullOrWhiteSpace($outputDir)) {
            $StatusTextBlock.Text = 'Output folder could not be determined.'
            return
        }

        if (-not (Test-Path -LiteralPath $outputDir)) {
            [System.IO.Directory]::CreateDirectory($outputDir) | Out-Null
        }

        Start-Process -FilePath 'explorer.exe' -ArgumentList @("`"$outputDir`"") -ErrorAction Stop | Out-Null
        $StatusTextBlock.Text = "Opened output folder: $outputDir"
    }
    catch {
        $StatusTextBlock.Text = 'Could not open output folder.'
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Open Output Folder failed', 'OK', 'Error') | Out-Null
    }
})

$ZoomLeftPanelButton.Add_Click({
    Set-ContentZoom -Zoom ($script:ContentZoom + 0.1)
})

$ZoomRightPanelButton.Add_Click({
    Set-ContentZoom -Zoom ($script:ContentZoom - 0.1)
})

$TestButton.Add_Click({
    $selected = $SampleListView.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show('Select a sample input file first.', 'Missing selection', 'OK', 'Warning') | Out-Null
        return
    }

    if (-not (Test-Path -LiteralPath $htmlTocScript)) {
        [System.Windows.MessageBox]::Show("HtmlToc.ps1 was not found: $htmlTocScript", 'Missing script', 'OK', 'Error') | Out-Null
        return
    }

    $navModeItem = $SectionNavModeComboBox.SelectedItem
    $navMode = 'icons'
    if ($navModeItem) {
        if ($navModeItem -is [System.Windows.Controls.ComboBoxItem] -and $navModeItem.Content) {
            $navMode = [string]$navModeItem.Content
        }
        else {
            $navMode = [string]$navModeItem
        }
    }

    $navMode = $navMode.Trim().ToLowerInvariant()
    if ($navMode -notin @('icons', 'text')) {
        $navMode = 'icons'
    }

    $iconPlacementItem = $SectionNavIconNumberPlacementComboBox.SelectedItem
    $iconNumberPlacement = 'arrow-before-number'
    if ($iconPlacementItem) {
        if ($iconPlacementItem -is [System.Windows.Controls.ComboBoxItem] -and $iconPlacementItem.Content) {
            $iconNumberPlacement = [string]$iconPlacementItem.Content
        }
        else {
            $iconNumberPlacement = [string]$iconPlacementItem
        }
    }
    $iconNumberPlacement = $iconNumberPlacement.Trim().ToLowerInvariant()
    if ($iconNumberPlacement -notin @('arrow-before-number', 'number-before-arrow')) {
        $iconNumberPlacement = 'arrow-before-number'
    }

    $tocPlacementItem = $TocPlacementComboBox.SelectedItem
    $tocPlacement = 'left'
    if ($tocPlacementItem) {
        if ($tocPlacementItem -is [System.Windows.Controls.ComboBoxItem] -and $tocPlacementItem.Content) {
            $tocPlacement = [string]$tocPlacementItem.Content
        }
        else {
            $tocPlacement = [string]$tocPlacementItem
        }
    }
    $tocPlacement = $tocPlacement.Trim().ToLowerInvariant()
    if ($tocPlacement -notin @('left', 'top')) {
        $tocPlacement = 'left'
    }

    if ([string]::IsNullOrWhiteSpace($OutputPathTextBox.Text)) {
        $OutputPathTextBox.Text = Get-AutoOutputPath -InputPath $selected.Path
    }
 
    Save-UiSettings

    $StatusTextBlock.Text = 'Generating HTML...'
    try {
        Invoke-HtmlTocBuild `
            -InputPath $selected.Path `
            -OutputPath $OutputPathTextBox.Text `
            -Title $TitleTextBox.Text `
            -Description $DescriptionTextBox.Text `
            -SectionNavMode $navMode `
            -SectionNavIconNumberPlacement $iconNumberPlacement `
            -EnableSectionNavLinks ([bool]$EnableSectionNavLinksCheckBox.IsChecked) `
            -EnableMultiLevelToc ([bool]$EnableMultiLevelTocCheckBox.IsChecked) `
            -EnableCollapsibleToc ([bool]$EnableCollapsibleTocCheckBox.IsChecked) `
            -EnableFloatingToc ([bool]$EnableFloatingTocCheckBox.IsChecked) `
            -KeepLeftTocOnNarrowScreens ([bool]$KeepLeftTocOnNarrowScreensCheckBox.IsChecked) `
            -EnableCollapsibleSections ([bool]$EnableCollapsibleSectionsCheckBox.IsChecked) `
            -EnableTopLinkAfterSection ([bool]$EnableTopLinkAfterSectionCheckBox.IsChecked) `
            -EnableSectionHeadingNumbering ([bool]$EnableSectionHeadingNumberingCheckBox.IsChecked) `
            -TocPlacement $tocPlacement `
            -OpenSectionsByDefault ([bool]$OpenSectionsByDefaultCheckBox.IsChecked) `
            -OpenGeneratedFile ([bool]$OpenGeneratedFileCheckBox.IsChecked)

        $StatusTextBlock.Text = "Generated: $($OutputPathTextBox.Text)"
        Save-UiSettings
    }
    catch {
        $StatusTextBlock.Text = 'Generation failed.'
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Generation failed', 'OK', 'Error') | Out-Null
    }
})

$window.Add_Closing({
    Save-UiSettings
})

$window.Add_ContentRendered({
    Apply-WindowSettings -Settings $script:AppSettings
    Apply-SettingsToUi -Settings $script:AppSettings
    Apply-ZoomSettings -Settings $script:AppSettings
    Load-SamplesIntoGrid
    Update-PathFileNameLabels
    if ($window.WindowState -eq [System.Windows.WindowState]::Minimized) {
        $window.WindowState = [System.Windows.WindowState]::Normal
    }
    $window.Activate() | Out-Null
    $window.Topmost = $true
    $window.Topmost = $false
    $window.Focus() | Out-Null
    Save-UiSettings
})

$null = $window.ShowDialog()
