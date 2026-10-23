#!/usr/bin/env bash
# Time opening and closing books with CyberUI, Bookshelf and SimpleUI in the
# same emulator, library and books:  tests/e2e/compare.sh <out_dir>
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$1"; mkdir -p "$out"; out="$(cd "$out" && pwd)"
for plugin in cyberui bookshelf simpleui; do
    echo "== $plugin"
    CYBERUI_COMPARE="$plugin" HOME_SETUP="$here/setup_home.py" TIMEOUT=240 \
        "$here/run.sh" "$here/compare.lua" "$out/$plugin" | grep -v -e '^emulator exit' -e '^PASS' -e '^DONE'
done
