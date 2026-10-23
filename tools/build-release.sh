#!/usr/bin/env bash
# Build the release zip, dist/CyberUI.koplugin-v<version>.zip: the plugin
# folder as KOReader needs it and nothing else (code, icons, fonts with their
# licences, LICENSE), the one asset a GitHub release carries and the updater
# looks for. The unpacked folder stays next to it in dist/CyberUI.koplugin
# for copying straight onto a device.
# --test names it after the commit instead, for device tests:
# dist/CyberUI.koplugin-v<version>-test-<commit>.zip
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
version="$(sed -n 's/^return "\(.*\)"/\1/p' "$repo/cyberui/version.lua")"
name="CyberUI.koplugin-v$version.zip"
if [ "${1:-}" = "--test" ]; then
    name="CyberUI.koplugin-v$version-test-$(git -C "$repo" rev-parse --short HEAD).zip"
fi
out="$repo/dist/CyberUI.koplugin"
mkdir -p "$repo/dist"
rm -rf "$out" "$repo/dist/$name"
mkdir -p "$out"
for item in main.lua _meta.lua LICENSE cyberui fonts icons; do
    rsync -a --exclude '.DS_Store' "$repo/$item" "$out/"
done
touch "$out"   # the build time, not the repo folder's
(cd "$repo/dist" && zip -qrX "$name" CyberUI.koplugin)
echo "built dist/$name ($(du -h "$repo/dist/$name" | cut -f1), $(unzip -l "$repo/dist/$name" | tail -1 | awk '{print $2}') files)"
