-- The README's screenshots, in the Neon scheme, dark: run with
--   tools/readme/shots.sh  (portrait and landscape, into assets/screenshots)
local H = ...
local S = 1.5
local Settings = require("cyberui/settings")
local UIManager = require("ui/uimanager")
local land = os.getenv("CYBERUI_SHOTS_LANDSCAPE") == "1"

local function shot(name)
    UIManager:forceRePaint()
    H.shot(name)
end

-- covers as real pictures or as ASCII art for the next shot
local function covers(style)
    Settings.set("cover_style", style)
    require("cyberui/theme").refresh()
end

-- what a Kindle Paperwhite would read (the Mac emulator has no /proc and
-- calls itself "emulator"), so every screen shows what a reader would
local function asOnAKindle()
    local Sysinfo, Banner, DeviceInfo = require("cyberui/data/sysinfo"), require("cyberui/data/banner"), require("cyberui/data/device")
    local now = os.time()
    Banner.device = function() return "KINDLE" end
    DeviceInfo.name = function() return "KINDLE" end
    DeviceInfo.wifi = function() return true end
    Sysinfo.cpuLoad = function() return 0.12 end
    Sysinfo.memory = function() return 214, 512 end
    Sysinfo.core = function()
        return { load = 0.12, mhz = 996, cores = 2, model = "Freescale i.MX7 Dual", loadavg = "0.42 0.31 0.12",
            mem_used = 214, mem_total = 512, rss = 48, threads = 6 }
    end
    Sysinfo.uptime = function()
        return { device = 218 * 3600 + 26 * 60, total = 14 * 3600 + 12 * 60, asleep = 10 * 3600 + 40 * 60, wakes = 23,
            last_sleep = now - 3 * 3600 }
    end
    Sysinfo.uplink = function() return { on = true, connected = true, ssid = "NIGHT CITY NET", ip = "192.168.1.23", ssh = 2222 } end
    Sysinfo.storage = function()
        return { { name = "INTERNAL", used = 3.1 * 1073741824, total = 7.8 * 1073741824 } }
    end
    local power = Sysinfo.power
    Sysinfo.power = function()
        local p = power() or {}
        p.pct, p.charging, p.charged = 78, false, false
        p.drain, p.left_h, p.cycles, p.last_charge = 2.1, 37, 37, now - 14 * 3600
        return p
    end
    local optics = Sysinfo.optics
    Sysinfo.optics = function()
        local o = optics()
        o.w, o.h, o.dpi = 1072, 1448, 300
        o.light, o.light_max, o.warmth = 12, 24, nil
        o.keys, o.keyboard = false, false
        return o
    end
    -- paths as on a Kindle, not the test copy's
    local fmu = require("apps/filemanager/filemanagerutil")
    local abbreviate = fmu.abbreviate
    fmu.abbreviate = function(p) return (abbreviate(p):gsub("^.*/[Bb]ooks", "/mnt/us/books")) end
    local ident = Sysinfo.ident
    Sysinfo.ident = function()
        local id = ident()
        id.model, id.version, id.kernel = "PW4", "2026.07.1", "4.1.15-lab126"
        return id
    end
end

-- the look the README shows, and a book well under way
H.step(1, function()
    asOnAKindle()
    for k, v in pairs({ scheme = "neon", mode = "dark", cover_style = "ascii", ascii_set = "braille",
            progress_style = "heartbeat", fontset = "oxanium", banner_title = "online", banner_top = "device" }) do
        Settings.set(k, v)
    end
    require("cyberui/theme").refresh()
    local History = require("cyberui/data/history")
    local cur = History.current()
    if cur then
        local ds = require("docsettings"):open(cur.path)
        ds:saveSetting("percent_finished", 0.42)
        local summary = ds:readSetting("summary") or {}
        summary.status = "reading"
        ds:saveSetting("summary", summary)
        ds:flush()
        require("cyberui/data/books").forget(cur.path)
    end
    -- a folder for the library to show as a stack: two books other than the
    -- one being read
    local Files, Library = require("cyberui/data/files"), require("cyberui/data/library")
    local dir = Files.mkdir(Library.home(), "Archive")
    local moved = 0
    for _i, b in ipairs(Library.all()) do
        if dir and moved < 2 and not (cur and b == cur.path) then
            Files.moveInto(b, dir)
            moved = moved + 1
        end
    end
    Library.reset()
    -- a collection of four
    local Collections = require("cyberui/data/collections")
    Collections.create("Cyberpunk Classics")
    for i, b in ipairs(Library.all()) do if i <= 4 then Collections.toggle(b, "Cyberpunk Classics") end end
    -- favourites too
    for i, b in ipairs(Library.all()) do if i >= 3 then Collections.toggle(b, "favorites") end end
    H.app().open()
    H.app().go("library")   -- has KOReader read the books' covers and details
end)
-- once KOReader has read them, forget what was drawn before it had
H.step(25, function()
    for _i, b in ipairs(require("cyberui/data/library").all()) do require("cyberui/data/books").forget(b) end
    require("cyberui/data/covers").forget()
    covers("image")
    H.app().go("home")
end)

if land then
    H.step(3, function() covers("image"); H.app().render("full"); shot("12-landscape") end)
    return
end

H.step(4, function() H.app().render("full"); shot("01-home") end)
H.step(S, function() covers("ascii"); H.app().go("library") end)
H.step(4, function() shot("02-library"); covers("image") end)
H.step(S, function()
    H.app().go("home")
    H.app().koreaderMenu()
    local m = require("cyberui/menu").current()
    for i, t in ipairs(m.tabs) do if t.deck then m:switchTab(i) end end
end)
H.step(S, function() shot("03-menu"); require("cyberui/menu").current():close() end)
H.step(S, function() H.app().push("dossier", { path = require("cyberui/data/history").current().path }) end)
H.step(3, function() shot("04-details") end)
H.step(S, function() H.app().go("library"); H.app().push("search"); H.app().current():setQuery("e") end)
H.step(4, function() H.app().closeDialog(); shot("05-search") end)
H.step(S, function() H.app().go("collections") end)
H.step(3, function() shot("06-collections") end)
H.step(S, function() H.app().go("history") end)
H.step(S, function() shot("07-log") end)
H.step(S, function() H.app().go("home"); H.app().push("diagnostics") end)
H.step(S, function() shot("08-diagnostics") end)
H.step(S, function() H.app().go("settings") end)
H.step(S, function() shot("09-look") end)
H.step(S, function()
    covers("ascii")
    local scr = H.app().current()
    scr.section = "covers"
    H.app().update()
    -- the character sets, as the Characters button shows them
    local Ascii = require("cyberui/gfx/ascii")
    local options = {}
    for _i, set in ipairs(Ascii.SETS) do options[#options + 1] = { label = set.name, checked = set.id == "braille" } end
    H.app().choose({ title = "Characters", cols = 2, options = options })
end)
H.step(2, function() shot("10-covers"); H.app().closeDialog() end)
H.step(S, function()
    H.app().go("home")
    G_reader_settings:saveSetting("screensaver_type", "cover")
    G_reader_settings:makeFalse("screensaver_show_message")
    G_reader_settings:makeFalse("screensaver_hide_cover_in_filemanager")
    G_reader_settings:saveSetting("lastfile", require("cyberui/data/history").current().path)
    Settings.set("ascii_sleep_mode", "covers")
    local Screensaver = require("ui/screensaver")
    Screensaver:setup()
    Screensaver:show()
end)
H.step(3, function() shot("11-sleep"); require("ui/screensaver"):close() end)
