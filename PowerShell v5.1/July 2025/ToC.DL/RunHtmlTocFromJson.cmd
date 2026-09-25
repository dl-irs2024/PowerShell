@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0HtmlToc.ps1" -SectionsPath "%~dp0HtmlToc.Sections.Example.json" -Title "HTML TOC From JSON" -OutputPath "%~dp0HtmlToc.FromJson.html" -EnableSectionNavLinks -EnableMultiLevelToc -EnableCollapsibleToc -EnableCollapsibleSections -OpenSectionsByDefault
 