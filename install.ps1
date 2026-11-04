#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the VoIPShark Wireshark plugins into the current user's plugin
    directory.

.DESCRIPTION
    Copies the contents of .\plugins (including lockbox and init.lua) into
    %APPDATA%\Wireshark\plugins, backing up any file it is about to overwrite.

.PARAMETER Destination
    Target plugin directory. Defaults to %APPDATA%\Wireshark\plugins.

.PARAMETER NoBackup
    Do not create a backup of files that already exist in the destination.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    .\install.ps1 -Destination "D:\tools\wireshark\plugins"
#>
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path $env:APPDATA 'Wireshark\plugins'),
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$source   = Join-Path $repoRoot 'plugins'

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Cannot find '$source'. Run this script from the repository root."
}

Write-Host 'VoIPShark installer' -ForegroundColor Cyan
Write-Host "  source : $source"
Write-Host "  target : $Destination"

if (Get-Process -Name wireshark, tshark -ErrorAction SilentlyContinue) {
    Write-Warning 'Wireshark/tshark is running. Restart it after the installation.'
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

$files = @(Get-ChildItem -LiteralPath $source -Recurse -File)
$conflicts = @()
foreach ($file in $files) {
    $relative = $file.FullName.Substring($source.Length).TrimStart('\')
    if (Test-Path -LiteralPath (Join-Path $Destination $relative)) {
        $conflicts += $relative
    }
}

if ($conflicts.Count -gt 0 -and -not $NoBackup) {
    $backup = Join-Path $Destination ('_voipshark-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    foreach ($relative in $conflicts) {
        $targetFile = Join-Path $Destination $relative
        $backupFile = Join-Path $backup $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupFile) | Out-Null
        Copy-Item -LiteralPath $targetFile -Destination $backupFile -Force
    }
    Write-Host "  backup : $backup" -ForegroundColor DarkGray
}

Copy-Item -Path (Join-Path $source '*') -Destination $Destination -Recurse -Force

Write-Host ''
Write-Host ("Installed {0} file(s)." -f $files.Count) -ForegroundColor Green
Write-Host 'Next steps:'
Write-Host '  1. Start Wireshark.'
Write-Host '  2. Check that Tools > VOIP is present.'
Write-Host '  3. For SRTP: Edit > Preferences > Protocols > VoIPShark > Decrypt SRTP Automatically.'
