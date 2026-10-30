-- Screens on KOReader's real blitter with the emulator's library: each screen
-- builds, lays out and paints in every scheme and mode, within a time budget,
-- and is saved as out/<screen>-<scheme>-<mode>.png for a look.
-- Run: cd <emulator>/koreader && ./luajit <repo>/tests/screens.lua <repo> [out_dir] [screen ...]

local REPO, OUT = arg[1] or ".", arg[2]
local Kit = dofile(REPO .. "/tests/kit.lua").boot(REPO)
-- the real library and history of the emulator, read only
G_reader_settings:saveSetting("home_dir", require("datastorage"):getDataDir() .. "/Books")

local Theme = require("cyberui/theme")
local Settings = require("cyberui/settings")
local Paint = require("cyberui/gfx/paint")
local Library = require("cyberui/data/library")

local only = {}
for i = 3, #arg do only[arg[i]] = true end
local SCREENS = { "home", "library", "dossier", "collections", "history", "search", "settings", "trash", "fonts", "diagnostics", "topbar", "launcher", "launchedit", "iconpick", "card", "filepick", "bounty", "shards", "shard", "colourpick" }
local PARAMS = {
    dossier = function() return { path = Library.all()[1] } end,
    launchedit = function() return { id = "library" } end,
    iconpick = function() return { current = "pen", on_pick = function() end } end,
    shard = function() return { shard = { id = "3F2A91C0", text = "A test highlight that wraps over a few lines so the card can show its words.", path = Library.all()[1] }, number = 1, of = 1 } end,
    colourpick = function() return { title = "Accent", current = "#2457D6", on_pick = function() end } end,
    filepick = function() return { dir = Library.home(), exts = { png = true }, on_pick = function() end } end,
}

Library.all()
local W, H = Kit.Screen:getWidth(), Kit.Screen:getHeight()
for _, id in ipairs(SCREENS) do
    if next(only) == nil or only[id] then
        local ok_mod, Mod = pcall(require, "cyberui/screens/" .. id)
        if not ok_mod then
            Kit.ok(false, id .. " loads: " .. tostring(Mod))
        else
            for _, scheme in ipairs({ "mono", "neon" }) do
                for _, mode in ipairs({ "light", "dark" }) do
                    Settings.set("scheme", scheme)
                    Settings.set("mode", mode)
                    Theme.refresh()
                    local bb = Kit.canvas()
                    local ok, err = pcall(function()
                        local s = Mod:new(PARAMS[id] and PARAMS[id]() or {})
                        local root = s:build({ w = W, h = H })
                        root:layout(W, H)
                        Paint.fill(bb, 0, 0, W, H, Theme.get().c.bg)
                        root:paint(bb, 0, 0)
                        if scheme == "mono" and mode == "light" then
                            local ms = Kit.time(function()
                                local r = Mod:new(PARAMS[id] and PARAMS[id]() or {}):build({ w = W, h = H })
                                r:layout(W, H)
                                r:paint(bb, 0, 0)
                            end, 10)
                            print(string.format("%-12s build+layout+paint %.2f ms", id, ms))
                            Kit.ok(ms < 60, id .. " draws in under 60 ms")
                        end
                    end)
                    Kit.ok(ok, id .. " " .. scheme .. "/" .. mode .. ": " .. tostring(err))
                    if OUT and ok then Kit.png(bb, string.format("%s/%s-%s-%s.png", OUT, id, scheme, mode)) end
                    bb:free()
                end
            end
        end
    end
end

-- the tabs of the reading log each build and paint
if next(only) == nil or only.history then
    local History = require("cyberui/screens/history")
    for _, tab in ipairs({ "stats", "streaks", "calendar", "goal" }) do
        for _, mode in ipairs({ "light", "dark" }) do
            Settings.set("scheme", "neon")
            Settings.set("mode", mode)
            Theme.refresh()
            local bb = Kit.canvas()
            local ok, err = pcall(function()
                local s = History:new({})
                s.tab = tab
                local root = s:build({ w = W, h = H })
                root:layout(W, H)
                Paint.fill(bb, 0, 0, W, H, Theme.get().c.bg)
                root:paint(bb, 0, 0)
            end)
            Kit.ok(ok, "history/" .. tab .. " " .. mode .. ": " .. tostring(err))
            if OUT and ok then Kit.png(bb, string.format("%s/history-%s-%s.png", OUT, tab, mode)) end
            bb:free()
        end
    end
end

Kit.finish("screens")
