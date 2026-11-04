#!/usr/bin/env bash
#
# Removes the VoIPShark Wireshark plugins from the current user's plugin
# directory (Linux / macOS).
#
set -euo pipefail

destination="${WIRESHARK_PLUGIN_DIR:-$HOME/.local/lib/wireshark/plugins}"

echo "VoIPShark uninstaller"
echo "  target : $destination"

if [ ! -d "$destination" ]; then
    echo "Plugin directory does not exist, nothing to do."
    exit 0
fi

plugins=(
    attack_detection.lua
    exportWav.lua
    info_gather_dtmf.lua
    info_gather_rtp.lua
    info_gather_sip.lua
    info_gather_unique_message.lua
    srtp_decrypt.lua
    util.lua
)

for name in "${plugins[@]}"; do
    if [ -e "$destination/$name" ]; then
        rm -f "$destination/$name"
        echo "  removed $name"
    fi
done

# Only delete init.lua if it is the one shipped by this project.
if [ -e "$destination/init.lua" ] && grep -q "VoIPShark 4.x compatibility bootstrap" "$destination/init.lua"; then
    rm -f "$destination/init.lua"
    echo "  removed init.lua"
fi

if [ -d "$destination/lockbox" ]; then
    rm -rf "$destination/lockbox"
    echo "  removed lockbox/"
fi

echo "Done. Restart Wireshark."
echo "Any files that were overwritten during installation are in _voipshark-backup-* folders."
