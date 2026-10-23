-- Test kit: boots KOReader without a window (run with the emulator's luajit
-- from its koreader folder), puts the plugin on the module path and gives
-- small helpers for checks, timing and saving screens as PNG.
-- Usage inside a suite:  local Kit = dofile(REPO .. "/tests/kit.lua").boot(REPO)

local Kit = {}

-- Start KOReader's environment with throwaway settings.
function Kit.boot(repo)
    Kit.repo = repo
    require("setupkoenv")
    _G.G_defaults = require("luadefaults"):open()
    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-settings.lua"
    os.remove(tmp)
    _G.G_reader_settings = require("luasettings"):open(tmp)
    package.path = repo .. "/?.lua;plugins/coverbrowser.koplugin/?.lua;" .. package.path
    Kit.Device = require("device")
    Kit.Screen = Kit.Device.screen
    require("document/canvascontext"):init(Kit.Device)
    local Settings = require("cyberui/settings")
    -- keep the plugin's own settings out of the real ones too
    local LuaSettings = require("luasettings")
    local ctmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-plugin.lua"
    os.remove(ctmp)
    local store = LuaSettings:open(ctmp)
    Settings.get = function(k, d) local v = store:readSetting(k); if v == nil then return d end; return v end
    Settings.set = function(k, v) store:saveSetting(k, v) end
    Settings.flush = function() end
    Kit.checks, Kit.failures = 0, 0
    return Kit
end

-- Record a check.
function Kit.ok(cond, what)
    Kit.checks = Kit.checks + 1
    if not cond then
        Kit.failures = Kit.failures + 1
        print("FAIL: " .. what)
    end
end

-- Average milliseconds of fn() over n runs.
function Kit.time(fn, n)
    n = n or 20
    local time = require("ui/time")
    local t0 = time.now()
    for _ = 1, n do fn() end
    return time.to_ms(time.since(t0)) / n
end

-- A blank screen-sized buffer of the screen's type.
function Kit.canvas(w, h)
    local BB = require("ffi/blitbuffer")
    return BB.new(w or Kit.Screen:getWidth(), h or Kit.Screen:getHeight(), BB.TYPE_BBRGB32)
end

-- Save a buffer as PNG.
function Kit.png(bb, path)
    bb:writePNG(path)
end

-- Print the result and exit with the right code.
function Kit.finish(name)
    print(string.format("%s: %d checks, %d failures", name, Kit.checks, Kit.failures))
    os.exit(Kit.failures == 0 and 0 or 1)
end

return Kit
