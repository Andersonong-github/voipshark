#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the VoIPShark plugins from the current user's Wireshark plugin
    directory.

.PARAMETER Destination
    Plugin directory to clean. Defaults to %APPDATA%\Wireshark\plugins.
#>
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path $env:APPDATA 'Wireshark\plugins')
)

$ErrorActionPreference = 'Stop'

Write-Host 'VoIPShark uninstaller' -ForegroundColor Cyan
Write-Host "  target : $Destination"

if (-not (Test-Path -LiteralPath $Destination)) {
    Write-Host 'Plugin directory does not exist, nothing to do.'
    return
}

$plugins = @(
    'attack_detection.lua',
    'exportWav.lua',
    'info_gather_dtmf.lua',
    'info_gather_rtp.lua',
    'info_gather_sip.lua',
    'info_gather_unique_message.lua',
    'srtp_decrypt.lua',
    'util.lua'
)

foreach ($name in $plugins) {
    $path = Join-Path $Destination $name
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
        Write-Host "  removed $name"
    }
}

# Only delete init.lua if it is the one shipped by this project.
$init = Join-Path $Destination 'init.lua'
if ((Test-Path -LiteralPath $init) -and
    (Select-String -LiteralPath $init -Pattern 'VoIPShark 4.x compatibility bootstrap' -Quiet)) {
    Remove-Item -LiteralPath $init -Force
    Write-Host '  removed init.lua'
}

$lockbox = Join-Path $Destination 'lockbox'
if (Test-Path -LiteralPath $lockbox) {
    Remove-Item -LiteralPath $lockbox -Recurse -Force
    Write-Host '  removed lockbox/'
}

Write-Host 'Done. Restart Wireshark.' -ForegroundColor Green
Write-Host 'Any files that were overwritten during installation are in _voipshark-backup-* folders.' -ForegroundColor DarkGray
