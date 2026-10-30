-- The data behind the newer features, on KOReader's real code with throwaway
-- settings: the launcher list, the library start folder, the reading status
-- marks and the cover stretch default.
-- Run: cd <emulator>/koreader && ./luajit <repo>/tests/features.lua <repo>

local REPO = arg[1] or "."
local Kit = dofile(REPO .. "/tests/kit.lua").boot(REPO)
G_reader_settings:saveSetting("home_dir", require("datastorage"):getDataDir() .. "/Books")

local Settings = require("cyberui/settings")

-- launcher list
do
    local Launcher = require("cyberui/data/launcher")
    local ids = {}
    for _, e in ipairs(Launcher.entries()) do ids[#ids + 1] = e.id end
    Kit.ok(table.concat(ids, ",") == table.concat(Launcher.BUILTIN, ","), "the launcher starts with the built-in buttons in order")
    Launcher.move("library", 1)
    Kit.ok(Launcher.entries()[1].id == "collections" and Launcher.entries()[2].id == "library", "a button moves down")
    Launcher.setHidden("history", true)
    Kit.ok(#Launcher.visible() == #Launcher.BUILTIN - 1, "a hidden button is not shown")
    Launcher.setHidden(Launcher.FIXED, true)
    Kit.ok(Launcher.get(Launcher.FIXED).hidden == nil, "the settings button cannot be hidden")
    local id = Launcher.add()
    local e = Launcher.get(id)
    Kit.ok(e and e.custom and e.custom.name == "NEW BUTTON", "a new button of the reader's own is added")
    Launcher.setCustom(id, { name = "NOTES", icon = "pen", target = { kind = "action", id = "history", title = "History" } })
    Kit.ok(Launcher.get(id).custom.name == "NOTES", "its name, icon and target are kept")
    Launcher.setCustom("inkaway", { name = "STATS", icon = "stats" })
    Kit.ok(Launcher.get("inkaway").custom.name == "STATS", "a built-in button can be replaced")
    Launcher.remove("inkaway")
    Kit.ok(Launcher.get("inkaway") and Launcher.get("inkaway").custom == nil, "and restored")
    Launcher.remove(id)
    Kit.ok(Launcher.get(id) == nil, "a button of the reader's own can be deleted")
    local Targets = require("cyberui/targets")
    Kit.ok(Targets.describe({ kind = "menu", trail = { "Settings" }, text = "Screen" }) == "MENU // Settings > Screen", "a menu target reads as a path")
    Kit.ok(Targets.describe(nil) == "NOTHING YET", "no target says so")
end

-- library start folder
do
    local Library = require("cyberui/data/library")
    local home = Library.home()
    Kit.ok(#Library.startTrail() == 1 and Library.startTrail()[1] == home, "the library opens in the home folder by default")
    local sub
    for _, f in ipairs(Library.list(home).folders) do sub = sub or f.path end
    if sub then
        Settings.set("library_start_dir", sub)
        local trail = Library.startTrail()
        Kit.ok(#trail == 2 and trail[1] == home and trail[2] == sub, "a chosen folder opens with the home above it")
    end
    Settings.set("library_start_dir", "/nonexistent/folder")
    Kit.ok(Library.startTrail()[1] == home and #Library.startTrail() == 1, "a folder that is gone falls back to the home")
    Settings.set("library_start_dir", nil)
    Kit.ok(#Library.trailTo("/elsewhere/else") == 1, "a folder outside the home is a trail of its own")
end

-- cover stretch is off until chosen
do
    local Covers = require("cyberui/data/covers")
    Kit.ok(Covers.stretch() == false, "covers keep their proportions by default")
    Settings.set("cover_stretch", true)
    Kit.ok(Covers.stretch() == true, "and stretch when the setting is on")
    Settings.set("cover_stretch", nil)
end

-- library sorting, grouping and filters
do
    local Library = require("cyberui/data/library")
    local Groups = require("cyberui/data/libgroups")
    local all = Library.all()
    local up = Library.sort(all, "title")
    local down = Library.sort(all, "title", true)
    Kit.ok(#up == #all and up[1] == down[#down], "reversing a sort turns the order round")
    for _, order in ipairs(Library.SORTS) do
        Kit.ok(#Library.sort(all, order) == #all, "sort by " .. order .. " keeps every book")
    end
    for _, kind in ipairs({ "author", "series", "status", "format", "added" }) do
        local total = 0
        for _, g in ipairs(Groups.list(kind)) do
            total = total + g.count
            Kit.ok(#Groups.books(kind, g.key) == g.count, "group " .. kind .. "/" .. g.name .. " holds what it counts")
        end
        Kit.ok(total == #all, "grouping by " .. kind .. " places every book once")
    end
    local fmt = Groups.formats()[1]
    local only = Groups.filter(all, { format = fmt })
    Kit.ok(#only > 0 and #only <= #all, "the format filter keeps that format")
    Kit.ok(Groups.filter(all, {}) == all, "no filter returns the same list")

    -- the screen in every grouping, picking books
    local Lib = require("cyberui/screens/library")
    local W, H = Kit.Screen:getWidth(), Kit.Screen:getHeight()
    for _, kind in ipairs({ "folder", "all", "author", "series", "status", "format", "added" }) do
        Settings.set("library_group", kind)
        local ok, err = pcall(function()
            local s = Lib:new({})
            local root = s:build({ w = W, h = H })
            root:layout(W, H)
            local bb = Kit.canvas()
            root:paint(bb, 0, 0)
            s.selecting = true
            s:build({ w = W, h = H }):layout(W, H)
            bb:free()
        end)
        Kit.ok(ok, "library grouped by " .. kind .. " builds: " .. tostring(err))
    end
    Settings.set("library_group", nil)
end

-- icons from the device
do
    local Icons = require("cyberui/gfx/icons")
    local ids = {}
    for _, src in ipairs(Icons.sources()) do ids[#ids + 1] = src.id end
    Kit.ok(ids[1] == "set" and ids[#ids] == "ko", "the set and KOReader's own icons are offered: " .. table.concat(ids, ","))
    local ko = Icons.list("ko")
    local set = {}
    for _, n in ipairs(ko) do set[n] = true end
    Kit.ok(#ko > 40 and set["ko:appbar.search.svg"], "KOReader's stock icons are listed with a prefix")
    Kit.ok(not set["ko:rotation.A.svg"] and not set["ko:wifi.open.0.svg"], "its state variants are left out")
    Kit.ok(Icons.sourceOf("ko:appbar.search.svg") == "ko" and Icons.sourceOf("pen") == "set" and Icons.sourceOf(nil) == "set",
        "an icon name tells its source")
    local function inked(name)
        local bb = Kit.canvas()
        Icons.draw(bb, name, 0, 0, 30, require("ffi/blitbuffer").COLOR_BLACK)
        local w, n = bb:getWidth(), 0
        for y = 0, 29 do for x = 0, 29 do if bb:getPixel(x, y):getColor8().a < 255 then n = n + 1 end end end
        bb:free()
        return n, w
    end
    Kit.ok(inked("ko:appbar.search.svg") > 20, "a stock icon draws")
    Kit.ok(inked("ko:no-such-icon.svg") == inked("tools"), "a stock icon that is gone draws the tools icon")
    local Pick = require("cyberui/screens/iconpick")
    local picked
    local s = Pick:new({ current = "ko:appbar.search.svg", on_pick = function(n) picked = n end })
    Kit.ok(s.source == "ko" and s:names()[1]:sub(1, 3) == "ko:", "the picker opens on the source of the current icon")
    local W, H = Kit.Screen:getWidth(), Kit.Screen:getHeight()
    local root = s:build({ w = W, h = H })
    root:layout(W, H)
    local bb = Kit.canvas()
    root:paint(bb, 0, 0)
    bb:free()
    Kit.ok(s.pages and s.pages >= 1, "the picker pages the stock icons")
end

Kit.finish("features")
