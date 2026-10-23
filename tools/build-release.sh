#!/usr/bin/env bash
# Build dist/CyberUI.koplugin.zip: the plugin folder as KOReader needs it,
# without tests, tools or git files.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
stage="$(mktemp -d)"
rsync -a --exclude '.git*' --exclude 'tests' --exclude 'tools' --exclude 'dist' --exclude '.DS_Store' \
    "$repo/" "$stage/CyberUI.koplugin/"
mkdir -p "$repo/dist"
rm -f "$repo/dist/CyberUI.koplugin.zip"
(cd "$stage" && zip -qr "$repo/dist/CyberUI.koplugin.zip" CyberUI.koplugin)
rm -rf "$stage"
echo "built dist/CyberUI.koplugin.zip ($(du -h "$repo/dist/CyberUI.koplugin.zip" | cut -f1))"
