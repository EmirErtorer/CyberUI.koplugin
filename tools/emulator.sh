#!/usr/bin/env bash
# Copy CyberUI into a KOReader emulator build and start it with its window.
# Usage: tools/emulator.sh [width height dpi]   (default 600 800 167)
# KO_DIR points at the KOReader checkout (default ~/koreader-emulator).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ko="${KO_DIR:-$HOME/koreader-emulator}"
w="${1:-600}"; h="${2:-800}"; dpi="${3:-167}"
rsync -a --delete --exclude '.git' --exclude 'tests' --exclude 'tools' --exclude '.DS_Store' \
    "$here/" "$ko/plugins/CyberUI.koplugin/"
export PATH="/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/opt/make/libexec/gnubin:$PATH"
cd "$ko"
mkdir -p sandbox
exec env XDG_DOCUMENTS_DIR="$ko/sandbox" KOREADER_WINDOW_POS_X="${KOEMU_WIN_X:-420}" KOREADER_WINDOW_POS_Y="${KOEMU_WIN_Y:-28}" \
    ./kodev run -W "$w" -H "$h" -D "$dpi" "$ko/sandbox"
