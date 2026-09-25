<#
.SYNOPSIS
Creates safe ZIP archives and restores them.

.DESCRIPTION
Mode Compress:
Builds a zip archive from a folder. Files ending in .ps1, .cmd, .vbs, or .vmbs
are copied to staging with an extra .txt suffix inside the archive.
Example: script.ps1 -> script.ps1.txt

Mode Expand:
Extracts a safe archive and restores script extensions by removing the trailing
.txt from .ps1.txt, .cmd.txt, .vbs.txt, and .vmbs.txt.
Example: script.ps1.txt -> script.ps1

This script targets Windows PowerShell 5.1.

.PARAMETER SourcePath
Folder to package (Compress mode).
Default: current location.
Aliases: FolderPath, Folder, Path.

.PARAMETER OutputZipPath
Output zip file path (Compress mode).
Default: <SourceFolderName>.<yyyyMMdd-HHmmss>.safe.zip in source parent.

.PARAMETER Recurse
Include files in subfolders (Compress mode).

.PARAMETER ZipPath
Safe zip file to extract (Expand mode).
Alias: InputZip.

.PARAMETER DestinationPath
Folder to write extracted and restored files (Expand mode).
Default: <ZipBaseName>.restored.<yyyyMMdd-HHmmss> in zip parent.
Alias: OutputFolder.

.PARAMETER WhatIf
Shows what would happen without writing files.

.EXAMPLE
.
\CompressSafeZip.ps1

.EXAMPLE
.
\CompressSafeZip.ps1 -FolderPath . -OutputZipPath .\ToC.safe.zip -Recurse

.EXAMPLE
.
\CompressSafeZip.ps1 -ZipPath .\ToC.safe.zip -DestinationPath .\ToC.Restored
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Compress')]
param(
    [Parameter(Mandatory = $false, ParameterSetName = 'Compress')]
    [Alias('FolderPath', 'Folder', 'Path')]
    [string]$SourcePath = (Get-Location).Path,

    [Parameter(Mandatory = $false, ParameterSetName = 'Compress')]
    [string]$OutputZipPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'Compress')]
    [switch]$Recurse,

    [Parameter(Mandatory = $true, ParameterSetName = 'Expand')]
    [Alias('InputZip')]
    [string]$ZipPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'Expand')]
    [Alias('OutputFolder')]
    [string]$DestinationPath
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$script:SafeScriptExtensions = @('.ps1', '.cmd', '.vbs', '.vmbs')

function Get-SafeArchiveName {
    param([Parameter(Mandatory = $true)][string]$FolderPath)

    $folderName = [System.IO.Path]::GetFileName($FolderPath.TrimEnd('\', '/'))
    if ([string]::IsNullOrWhiteSpace($folderName)) {
        $folderName = 'Archive'
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return ('{0}.{1}.safe.zip' -f $folderName, $stamp)
}

function Get-RestoreFolderName {
    param([Parameter(Mandatory = $true)][string]$ZipFilePath)

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($ZipFilePath)
    if ([string]::IsNullOrWhiteSpace($baseName)) {
        $baseName = 'Archive'
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return ('{0}.restored.{1}' -f $baseName, $stamp)
}

function Copy-SafeItemToStaging {
    param(
        [Parameter(Mandatory = $true)][string]$FullPath,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$StagingRoot
    )

    $targetRelative = $RelativePath
    $ext = [System.IO.Path]::GetExtension($RelativePath)
    if ($ext) {
        $lowerExt = $ext.ToLowerInvariant()
        if ($script:SafeScriptExtensions -contains $lowerExt) {
            $targetRelative = $RelativePath + '.txt'
        }
    }

    $targetPath = Join-Path -Path $StagingRoot -ChildPath $targetRelative
    $targetDir = [System.IO.Path]::GetDirectoryName($targetPath)
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $FullPath -Destination $targetPath -Force
}

function Get-RestoredRelativePath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $fileName = [System.IO.Path]::GetFileName($RelativePath)
    $finalExt = [System.IO.Path]::GetExtension($fileName)

    if ([string]::IsNullOrWhiteSpace($finalExt) -or $finalExt.ToLowerInvariant() -ne '.txt') {
        return $RelativePath
    }

    $withoutTxt = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $innerExt = [System.IO.Path]::GetExtension($withoutTxt)
    if ([string]::IsNullOrWhiteSpace($innerExt) -or -not ($script:SafeScriptExtensions -contains $innerExt.ToLowerInvariant())) {
        return $RelativePath
    }

    $dir = [System.IO.Path]::GetDirectoryName($RelativePath)
    if ([string]::IsNullOrWhiteSpace($dir)) {
        return $withoutTxt
    }

    return (Join-Path -Path $dir -ChildPath $withoutTxt)
}

function New-DirectoryIfMissing {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Invoke-SafeCompress {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$InputSourcePath,
        [Parameter(Mandatory = $false)][string]$InputOutputZipPath,
        [Parameter(Mandatory = $false)][switch]$InputRecurse
    )

    $resolvedSource = [System.IO.Path]::GetFullPath($InputSourcePath)
    if (-not (Test-Path -LiteralPath $resolvedSource -PathType Container)) {
        throw "SourcePath folder not found: $resolvedSource"
    }

    $resolvedZip = ''
    if ([string]::IsNullOrWhiteSpace($InputOutputZipPath)) {
        $parent = [System.IO.Path]::GetDirectoryName($resolvedSource)
        if ([string]::IsNullOrWhiteSpace($parent)) {
            $parent = $resolvedSource
        }
        $resolvedZip = Join-Path -Path $parent -ChildPath (Get-SafeArchiveName -FolderPath $resolvedSource)
    }
    else {
        $resolvedZip = [System.IO.Path]::GetFullPath($InputOutputZipPath)
    }

    if (-not $PSCmdlet.ShouldProcess($resolvedSource, ("Create safe archive '{0}'" -f $resolvedZip))) {
        return
    }

    $skipNames = @(
        [System.IO.Path]::GetFileName($resolvedZip),
        'desktop.ini'
    )

    $stagingRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('CompressSafeZip_' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

    try {
        if ($InputRecurse) {
            $files = Get-ChildItem -LiteralPath $resolvedSource -File -Recurse
        }
        else {
            $files = Get-ChildItem -LiteralPath $resolvedSource -File
        }

        foreach ($file in $files) {
            if ($skipNames -contains $file.Name) {
                continue
            }

            $relative = $file.FullName.Substring($resolvedSource.Length).TrimStart('\', '/')
            if ([string]::IsNullOrWhiteSpace($relative)) {
                continue
            }

            Copy-SafeItemToStaging -FullPath $file.FullName -RelativePath $relative -StagingRoot $stagingRoot
        }

        if (Test-Path -LiteralPath $resolvedZip) {
            if ($PSCmdlet.ShouldProcess($resolvedZip, 'Remove existing archive')) {
                Remove-Item -LiteralPath $resolvedZip -Force
            }
        }

        if ($PSCmdlet.ShouldProcess($resolvedZip, 'Compress staged files into archive')) {
            Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $resolvedZip -CompressionLevel Optimal
            Write-Host "Created safe archive: $resolvedZip"
        }
    }
    finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            if ($PSCmdlet.ShouldProcess($stagingRoot, 'Remove temporary staging folder')) {
                Remove-Item -LiteralPath $stagingRoot -Recurse -Force
            }
        }
    }
}

function Invoke-SafeExpand {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$InputZipPath,
        [Parameter(Mandatory = $false)][string]$InputDestinationPath
    )

    $resolvedZip = [System.IO.Path]::GetFullPath($InputZipPath)
    if (-not (Test-Path -LiteralPath $resolvedZip -PathType Leaf)) {
        throw "ZipPath file not found: $resolvedZip"
    }

    $resolvedDestination = ''
    if ([string]::IsNullOrWhiteSpace($InputDestinationPath)) {
        $zipParent = [System.IO.Path]::GetDirectoryName($resolvedZip)
        if ([string]::IsNullOrWhiteSpace($zipParent)) {
            $zipParent = (Get-Location).Path
        }
        $resolvedDestination = Join-Path -Path $zipParent -ChildPath (Get-RestoreFolderName -ZipFilePath $resolvedZip)
    }
    else {
        $resolvedDestination = [System.IO.Path]::GetFullPath($InputDestinationPath)
    }

    if (-not $PSCmdlet.ShouldProcess($resolvedZip, ("Extract and restore files into '{0}'" -f $resolvedDestination))) {
        return
    }

    $stagingRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('ExpandSafeZip_' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

    try {
        if ($PSCmdlet.ShouldProcess($resolvedZip, ("Expand archive to temporary folder '{0}'" -f $stagingRoot))) {
            Expand-Archive -LiteralPath $resolvedZip -DestinationPath $stagingRoot -Force
        }

        New-DirectoryIfMissing -Path $resolvedDestination

        $files = Get-ChildItem -LiteralPath $stagingRoot -File -Recurse
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($stagingRoot.Length).TrimStart('\', '/')
            if ([string]::IsNullOrWhiteSpace($relative)) {
                continue
            }

            $restoredRelative = Get-RestoredRelativePath -RelativePath $relative
            $targetPath = Join-Path -Path $resolvedDestination -ChildPath $restoredRelative
            $targetDir = [System.IO.Path]::GetDirectoryName($targetPath)
            New-DirectoryIfMissing -Path $targetDir

            if ($PSCmdlet.ShouldProcess($targetPath, 'Write restored file')) {
                Copy-Item -LiteralPath $file.FullName -Destination $targetPath -Force
            }

            if ($PSCmdlet.ShouldProcess($targetPath, 'Unblock restored file')) {
                Unblock-File -LiteralPath $targetPath
            }
        }

        Write-Host "Expanded and restored archive to: $resolvedDestination"
    }
    finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            if ($PSCmdlet.ShouldProcess($stagingRoot, 'Remove temporary extraction folder')) {
                Remove-Item -LiteralPath $stagingRoot -Recurse -Force
            }
        }
    }
}

switch ($PSCmdlet.ParameterSetName) {
    'Compress' {
        Invoke-SafeCompress -InputSourcePath $SourcePath -InputOutputZipPath $OutputZipPath -InputRecurse:$Recurse
    }
    'Expand' {
        Invoke-SafeExpand -InputZipPath $ZipPath -InputDestinationPath $DestinationPath
    }
    default {
        throw "Unsupported parameter set: $($PSCmdlet.ParameterSetName)"
    }
}
