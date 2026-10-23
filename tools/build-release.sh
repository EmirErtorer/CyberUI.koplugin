#!/usr/bin/env bash
# Build dist/CyberUI.koplugin.zip: the plugin folder as KOReader needs it,
# without tests, tools or git files. The unpacked folder stays next to it in
# dist/CyberUI.koplugin for copying straight onto a device.
# --test names the zip after the version and commit instead, for device tests:
# dist/CyberUI.koplugin-v<version>-test-<commit>.zip
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
name="CyberUI.koplugin.zip"
if [ "${1:-}" = "--test" ]; then
    version="$(sed -n 's/^return "\(.*\)"/\1/p' "$repo/cyberui/version.lua")"
    name="CyberUI.koplugin-v$version-test-$(git -C "$repo" rev-parse --short HEAD).zip"
fi
mkdir -p "$repo/dist"
rm -rf "$repo/dist/CyberUI.koplugin" "$repo/dist/$name"
rsync -a --exclude '.git*' --exclude 'tests' --exclude 'tools' --exclude 'dist' --exclude 'docs' --exclude '.DS_Store' \
    "$repo/" "$repo/dist/CyberUI.koplugin/"
(cd "$repo/dist" && zip -qr "$name" CyberUI.koplugin)
echo "built dist/$name ($(du -h "$repo/dist/$name" | cut -f1))"
