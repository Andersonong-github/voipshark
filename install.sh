#!/usr/bin/env bash
#
# Installs the VoIPShark Wireshark plugins into the current user's plugin
# directory (Linux / macOS).
#
# Usage:
#   ./install.sh
#   WIRESHARK_PLUGIN_DIR=/path/to/plugins ./install.sh
#
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$repo_root/plugins"
destination="${WIRESHARK_PLUGIN_DIR:-$HOME/.local/lib/wireshark/plugins}"

if [ ! -d "$source_dir" ]; then
    echo "error: cannot find '$source_dir'; run this script from the repository root" >&2
    exit 1
fi

echo "VoIPShark installer"
echo "  source : $source_dir"
echo "  target : $destination"

mkdir -p "$destination"

backup="$destination/_voipshark-backup-$(date +%Y%m%d-%H%M%S)"
made_backup=0
while IFS= read -r -d '' file; do
    relative="${file#"$source_dir"/}"
    if [ -e "$destination/$relative" ]; then
        mkdir -p "$backup/$(dirname "$relative")"
        cp -p "$destination/$relative" "$backup/$relative"
        made_backup=1
    fi
done < <(find "$source_dir" -type f -print0)

if [ "$made_backup" -eq 1 ]; then
    echo "  backup : $backup"
fi

cp -R "$source_dir"/. "$destination"/

count="$(find "$source_dir" -type f | wc -l | tr -d ' ')"
echo
echo "Installed $count file(s)."
echo "Next steps:"
echo "  1. Restart Wireshark."
echo "  2. Check that Tools > VOIP is present."
echo "  3. For SRTP: Edit > Preferences > Protocols > VoIPShark > Decrypt SRTP Automatically."
