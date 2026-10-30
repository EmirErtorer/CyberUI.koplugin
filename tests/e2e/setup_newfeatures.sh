#!/usr/bin/env bash
# Seed the copied home for newfeatures.lua:  setup_newfeatures.sh <home_dir>
exec python3 "$(dirname "$0")/setup_stats.py" "$1"
