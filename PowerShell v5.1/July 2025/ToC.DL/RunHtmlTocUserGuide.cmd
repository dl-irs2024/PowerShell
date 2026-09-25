@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0HtmlToc.ps1" -SectionsPath "%~dp0HtmlToc.Test.Samples\HtmlToc.Sample.UserGuide.json" -Title "HtmlToc User Guide" -DocumentDescription "Comprehensive guide for HtmlToc.ps1 and HtmlToc.Test.ps1 with JSON schema, parameters, and examples." -OutputPath "%~dp0HtmlToc.UserGuide.html" -EnableSectionNavLinks -SectionNavMode icons -EnableMultiLevelToc -EnableCollapsibleToc -EnableCollapsibleSections -EnableTopLinkAfterSection -TocPlacement left -KeepLeftTocOnNarrowScreens -OpenSectionsByDefault

