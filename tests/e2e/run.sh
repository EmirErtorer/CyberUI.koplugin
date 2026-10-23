#!/usr/bin/env bash
# Run a CyberUI scenario in the visible emulator with copies of its settings:
#   tests/e2e/run.sh tests/e2e/walkthrough.lua <out_dir> [width height dpi]
# Results: <out_dir>/drive.log and screenshots; the emulator log is emulator.log.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
scen="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; out="$2"; shift 2
w="${1:-600}"; h="${2:-800}"; dpi="${3:-167}"
ko="${KO_DIR:-$HOME/koreader-emulator}"
emu="$(ls -d "$ko"/koreader-emulator-*/koreader | head -1)"
rm -rf "$out"; mkdir -p "$out/home/plugins"
out="$(cd "$out" && pwd)"; home="$out/home"
rsync -a --delete --exclude '.git' --exclude 'tests' --exclude 'tools' "$repo/" "$ko/plugins/CyberUI.koplugin/"
cp -R "$repo/tests/e2e/drive.koplugin" "$home/plugins/"
cp "$emu/settings.reader.lua" "$home/settings.reader.lua"
cp -R "$emu/settings" "$home/settings"
[ -f "$emu/history.lua" ] && cp "$emu/history.lua" "$home/history.lua"
# the books too (copy-on-write clones on APFS, plain copies elsewhere), with the
# copied settings pointing at them, so a run never writes into the real library
lib="$(grep -o '"home_dir"\] = "[^"]*"' "$emu/settings.reader.lua" | sed 's/.*= "//; s/"$//')"
if [ -n "$lib" ] && [ -d "$lib" ]; then
    cp -cR "$lib" "$home/Books" 2>/dev/null || cp -R "$lib" "$home/Books"
    for f in "$home/settings.reader.lua" "$home/history.lua" "$home/settings/collection.lua"; do
        [ -f "$f" ] && LC_ALL=C sed -i '' "s#$lib#$home/Books#g" "$f"
    done
fi
# KOReader finds the driver in <KO_HOME>/plugins on its own
# an optional setup step gets the copied home folder (compare.sh uses it)
[ -n "${HOME_SETUP:-}" ] && "$HOME_SETUP" "$home"
# KOReader opens the folder given on its command line; E2E_NO_DIR=1 starts it
# without one, so the start screen setting decides (restart.lua uses it)
start_dir="$ko/sandbox"
[ -n "${E2E_NO_DIR:-}" ] && start_dir=""
cd "$emu"
set +e
KO_HOME="$home" CYBERUI_DRIVE_SCRIPT="$scen" CYBERUI_DRIVE_OUT="$out" \
    EMULATE_READER_W="$w" EMULATE_READER_H="$h" EMULATE_READER_DPI="$dpi" \
    KOREADER_WINDOW_POS_X="${KOEMU_WIN_X:-420}" KOREADER_WINDOW_POS_Y="${KOEMU_WIN_Y:-28}" \
    gtimeout "${TIMEOUT:-300}" ./luajit reader.lua ${start_dir:+"$start_dir"} > "$out/emulator.log" 2>&1
echo "emulator exit: $?"
set -e
cat "$out/drive.log" 2>/dev/null || echo "(no drive.log)"
