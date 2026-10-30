-- The README's screenshots, in the Neon scheme, dark: run with
--   tools/readme/shots.sh  (into assets/screenshots; montage.py makes the four collages)
local H = ...
local S = 1.5
local Settings = require("cyberui/settings")
local UIManager = require("ui/uimanager")
local OUT = os.getenv("CYBERUI_DRIVE_OUT")

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

-- the look the README shows, a book well under way, a few gigs and shop styles
H.step(1, function()
    asOnAKindle()
    for k, v in pairs({ scheme = "neon", mode = "dark", cover_style = "ascii", ascii_set = "braille",
            progress_style = "heartbeat", fontset = "oxanium", banner_title = "online", banner_top = "device",
            handle = "NOVA_7", park_reader = false }) do
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
    -- highlights for the data shard on home
    local Library, Shards = require("cyberui/data/library"), require("cyberui/data/shards")
    local DocSettings = require("docsettings")
    local function find(pattern)
        for _i, b in ipairs(Library.all()) do if b:find(pattern, 1, true) then return b end end
    end
    for _i, pattern in ipairs({ "Neuromancer", "Synners" }) do
        local b = find(pattern)
        if b then
            local ds = DocSettings:open(b)
            ds:saveSetting("annotations", { { text = "Read it slowly: the best parts hide between the lines.", chapter = "One",
                datetime = "2026-10-20 21:10:00", page = 12 } })
            ds:flush()
            Shards.refresh(b)
        end
    end
    -- gigs: three open, one half read, one finished; then eddies and four styles worn
    local Gigs, Ledger, Shop = require("cyberui/data/gigs"), require("cyberui/data/ledger"), require("cyberui/data/shop")
    local lfs = require("libs/libkoreader-lfs")
    local now = os.time()
    for pattern, days in pairs({ ["Ready Player"] = 120, ["Do Androids"] = 210, ["Synners"] = 64, ["Altered Carbon"] = 80, ["Gravity"] = 95 }) do
        local b = find(pattern)
        if b then lfs.touch(b, now - days * 86400, now - days * 86400) end
    end
    Settings.set("gigs", nil)
    Gigs.reload()
    for _i, b in ipairs(Library.all()) do require("cyberui/data/books").forget(b) end
    local altered, gravity = find("Altered Carbon"), find("Gravity")
    for _i, job in ipairs({ { altered, 45 }, { gravity, 100 } }) do
        if job[1] then
            Gigs.accept(job[1])
            Gigs.follow(job[1])
            for p = 1, job[2] do Gigs.page(p, 100) end
            Gigs.settle()
        end
    end
    Gigs.takeReceipt()
    Ledger.add("g", "earlier", 0, 3000)   -- eddies from earlier gigs, so the shop has something to show
    Ledger.save()
    for _i, id in ipairs({ "frame.hazard", "background.skyline", "flair.bolt", "jackin.scanner" }) do
        local style = Shop.style(id)
        if Shop.buy(style) then Shop.wear(style) end
    end
    H.app().go("home")
end)

-- CYBERUI_SHOTS_ONLY="08-diagnostics,18-idtab" takes only the sections that make those
-- shots (the seeding above always runs); without it every section runs.
local only_list = os.getenv("CYBERUI_SHOTS_ONLY")
local add_step, active = H.step, true
H.step = function(delay, fn) if active then add_step(delay, fn) end end
local function section(...)
    if not only_list then return end
    active = false
    for _i, name in ipairs({ ... }) do
        if only_list:find(name, 1, true) then active = true end
    end
end

section("01-home", "02-gigs", "03-card", "04-library")
H.step(4, function() H.app().render("full"); shot("01-home") end)
H.step(S, function() H.app().push("gigs") end)
H.step(3, function() shot("02-gigs") end)
H.step(S, function() H.app().go("home"); require("cyberui/profileflow").card() end)
H.step(S, function() shot("03-card"); H.app().closeDialog() end)
H.step(S, function() covers("ascii"); H.app().go("library") end)
H.step(4, function() shot("04-library"); covers("image") end)
section("05-menu", "18-idtab")
H.step(S, function()
    H.app().go("home")
    H.app().koreaderMenu()
    local m = require("cyberui/menu").current()
    for i, t in ipairs(m.tabs) do if t.deck then m:switchTab(i) end end
    m:turnDeck(1)   -- the controls page
end)
H.step(S, function() shot("05-menu") end)
-- the operator ID page, in the default card (the free frame, backdrop and flair), then the styles are put back
local worn_before = {}
H.step(S, function()
    local Shop = require("cyberui/data/shop")
    for _i, cat in ipairs({ "frame", "background", "flair" }) do
        worn_before[cat] = Shop.worn(cat)
        Shop.wear(Shop.category(cat).styles[1])
    end
    require("cyberui/menu").current():turnDeck(-1)
end)
H.step(S, function()
    shot("18-idtab")
    require("cyberui/menu").current():close()
    local Shop = require("cyberui/data/shop")
    for _cat, style in pairs(worn_before) do Shop.wear(style) end
end)
section("06-collections")
H.step(S, function() H.app().go("collections") end)
H.step(3, function() shot("06-collections") end)
section("07-log")
H.step(S, function()
    Settings.save("cal_view", "skyline")
    H.app().go("history")
    H.app().current().tab = "calendar"
    H.app().update()
end)
H.step(S, function() shot("07-log") end)
section("08-diagnostics")
H.step(S, function() H.app().go("home"); H.app().push("diagnostics") end)
H.step(S, function() shot("08-diagnostics") end)
section("09-look", "10-covers", "11-sleep")
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
section("12-shards")
H.step(S, function() H.app().go("home"); H.app().push("shards") end)
H.step(S, function() shot("12-shards") end)

-- the shop: the frames tab alone, then every tab for the styles collage
section("13-shop", "14a-styles")
H.step(S, function() H.app().go("home"); H.app().push("shop") end)
H.step(S, function() shot("13-shop"); shot("14a-styles") end)
for i, cat in ipairs({ "background", "flair", "jackin" }) do
    H.step(S, function() local s = H.app().current(); s.cat, s.page = cat, 1; H.app().update() end)
    H.step(S, function() shot("14" .. string.char(97 + i) .. "-styles") end)
end

-- four jack-in cards, each drawn alone for the collage
section("15a-jackin")
H.step(S, function()
    local Shop, Library = require("cyberui/data/shop"), require("cyberui/data/library")
    local Blitbuffer = require("ffi/blitbuffer")
    local Paint = require("cyberui/gfx/paint")
    local Theme = require("cyberui/theme")
    local book
    for _i, b in ipairs(Library.all()) do if b:find("Neuromancer", 1, true) then book = b end end
    for i, id in ipairs({ "jackin.terminal", "jackin.poster", "jackin.ticket", "jackin.scanner" }) do
        local el = Shop.style(id).build(book)
        local th = Theme.get()
        local pad = th.space.xl
        local width = require("device").screen:getWidth() - 2 * th.space.xl
        el:layout(math.min(width, Theme.px(560)), nil)
        local bb = Blitbuffer.new(el.w + 2 * pad, el.h + 2 * pad, Blitbuffer.TYPE_BBRGB32)
        Paint.fill(bb, 0, 0, bb:getWidth(), bb:getHeight(), Theme.color("bg"))
        el:paint(bb, pad, pad)
        bb:writePNG(string.format("%s/15%s-jackin.png", OUT, string.char(96 + i)))
        bb:free()
    end
end)

-- the gigs story: the gigs taken, the payouts, the dossier of a gig, a payout on home
section("16a-gigs")
H.step(S, function() H.app().go("home"); H.app().push("gigs") end)
H.step(S, function() H.app().current().tab = "active"; H.app().update() end)
H.step(S, function() shot("16a-gigs") end)
H.step(S, function() H.app().current().tab = "payouts"; H.app().update() end)
H.step(S, function() shot("16b-gigs") end)
H.step(S, function()
    local Gigs = require("cyberui/data/gigs")
    local board = Gigs.board()
    H.app().push("dossier", { path = board[1].path })
end)
H.step(S, function() shot("16c-gigs") end)
H.step(S, function()
    H.app().go("home")
    local Format = require("cyberui/format")
    H.app().toast(string.format(require("gettext")("GIG PAYOUT +%s"), Format.credits(24)))
end)
H.step(1, function() shot("16d-gigs") end)

-- home in four languages
section("17a-languages")
for i, lang in ipairs({ "de", "ru", "tr", "el" }) do
    H.step(S, function()
        require("gettext").changeLang(lang)
        require("cyberui/gettext").use(lang)
        H.app().go("home")
        H.app().update()
    end)
    H.step(2.5, function() shot("17" .. string.char(96 + i) .. "-languages") end)
end
H.step(S, function() require("gettext").changeLang("en"); require("cyberui/gettext").use("en") end)
