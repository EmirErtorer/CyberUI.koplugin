-- luacheck settings for CyberUI: LuaJIT, KOReader's settings global, and
-- names starting with "_" (or self) may go unused on purpose.
std = "luajit"
globals = { "G_reader_settings" }
max_line_length = false
ignore = { "21./_.*", "212/self" }
exclude_files = { "tests/e2e/drive.koplugin/*" }
