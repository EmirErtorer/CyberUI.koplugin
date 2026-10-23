#!/usr/bin/env bash
# Run CyberUI's tests: lint, widgets and screens (headless, on KOReader's real
# drawing code), and with --e2e also the walkthroughs in the visible emulator.
# KO_DIR points at the KOReader checkout with the emulator built (default ~/koreader-emulator).
set -uo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
ko="${KO_DIR:-$HOME/koreader-emulator}"
emu="$(ls -d "$ko"/koreader-emulator-*/koreader 2>/dev/null | head -1)"
fail=0
run() { echo "== $1"; shift; "$@" || fail=$((fail + 1)); }
filter() { grep -v -e '^ffi\.' -e '^lib_' -e 'monolibtic' -e 'DEBUG' -e 'INFO' -e 'Started SDL' -e '^  [hw] =' -e '^}'; }
run lint bash -c "cd '$repo' && luajit tests/lint.lua"
if command -v luacheck >/dev/null; then
    run luacheck bash -c "cd '$repo' && luacheck -q cyberui main.lua _meta.lua"
fi
if [ -x "$emu/luajit" ]; then
    for suite in widgets screens; do
        run "$suite" bash -c "cd '$emu' && SDL_VIDEODRIVER=offscreen ./luajit '$repo/tests/$suite.lua' '$repo' 2>&1 | { $(declare -f filter); filter; }; exit \${PIPESTATUS[0]}"
    done
else
    echo "(no emulator in $ko: widgets and screens skipped)"
fi
if [ "${1:-}" = "--e2e" ]; then
    out="$(mktemp -d)"
    for scen in walkthrough flows menus; do
        run "$scen" bash -c "'$repo/tests/e2e/run.sh' '$repo/tests/e2e/$scen.lua' '$out/$scen' | tail -1 | grep -q ' 0 failed'"
    done
    echo "e2e screenshots in $out"
fi
echo "$([ $fail -eq 0 ] && echo 'all passed' || echo "$fail suite(s) failed")"
exit $fail
