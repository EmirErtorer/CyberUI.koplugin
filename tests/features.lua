-- The data behind the newer features, on KOReader's real code with throwaway
-- settings: the launcher list, the library start folder, the reading status
-- marks and the cover stretch default.
-- Run: cd <emulator>/koreader && ./luajit <repo>/tests/features.lua <repo>

local REPO = arg[1] or "."
local Kit = dofile(REPO .. "/tests/kit.lua").boot(REPO)
local Theme = require("cyberui/theme")
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
    Kit.ok(#Launcher.visible() == #Launcher.BUILTIN - 2, "a hidden button is not shown (the shards button starts hidden)")
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

-- operator profile and ID card
do
    local Profile = require("cyberui/data/profile")
    local r = Profile.rank(0)
    Kit.ok(r.name == "SCRIPT KID" and r.next == "RUNNER" and r.value == 0, "no hours is the first rank")
    r = Profile.rank(62.5)
    Kit.ok(r.name == "RUNNER" and r.next == "FIXER" and math.abs(r.value - 0.5) < 0.01, "62.5 hours is halfway from runner to fixer")
    r = Profile.rank(900)
    Kit.ok(r.name == "LEGEND" and r.next == nil and r.value == 1, "the top rank has nothing after it")
    local h1, id1 = Profile.handle(), Profile.id()
    Kit.ok(h1:match("^%u+_%u+%.%d$") ~= nil, "a handle is made when none was chosen: " .. h1)
    Kit.ok(id1:match("^%x%x%x%x%-%x%x%x%x%-%x%x%x%x$") ~= nil and Profile.id() == id1 and Profile.handle() == h1, "the ID and handle are stable")
    Settings.set("handle", "SPARROW")
    Kit.ok(Profile.handle() == "SPARROW" and Profile.id() == id1, "a chosen handle wins and keeps the ID")
    Settings.set("handle", nil)
    -- a photo from a file: kept square and used by the face
    local BB = require("ffi/blitbuffer")
    local src = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-photo.png"
    local big = BB.new(300, 200, BB.TYPE_BBRGB32)
    big:fill(BB.COLOR_BLACK)
    big:writePNG(src)
    big:free()
    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-profile"
    os.execute("rm -rf '" .. tmp .. "'; mkdir -p '" .. tmp .. "'")
    Profile.dir = tmp
    require("cyberui/profileflow").dir = tmp
    Kit.ok(not Profile.hasPhoto(), "no photo at first")
    Kit.ok(Profile.setPhoto(src) and Profile.hasPhoto(), "a picture becomes the photo")
    local p = Profile.photo(64)
    Kit.ok(p and p:getWidth() == 64 and p:getHeight() == 64, "the photo is square at any size asked")
    Kit.ok(select(2, Profile.setPhoto("/no/such.png")) ~= nil, "a missing file is refused with a reason")
    Profile.clearPhoto()
    Kit.ok(not Profile.hasPhoto() and Profile.photo(64) == nil, "the photo can be removed")
    os.remove(src)
    local IdCard = require("cyberui/ui/idcard")
    local W, H = Kit.Screen:getWidth(), Kit.Screen:getHeight()
    for _, build in ipairs({ function() return IdCard.full({}) end, function() return IdCard.strip({}) end }) do
        local el = build()
        el:layout(W, nil)
        Kit.ok(el.h > 0 and el.h < H, "the card fits the screen")
        local bb = Kit.canvas()
        el:paint(bb, 0, 0)
        bb:free()
    end
    local ProfileFlow = require("cyberui/profileflow")
    local file = ProfileFlow.export(IdCard.full({}))
    Kit.ok(file and require("libs/libkoreader-lfs").attributes(file, "size") > 1000, "the card is saved as a picture")
    if file then os.remove(file) end
end

-- data shards and bounties
do
    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-shards"
    os.execute("rm -rf '" .. tmp .. "'; mkdir -p '" .. tmp .. "'")
    local Shards = require("cyberui/data/shards")
    Shards.reset()
    Shards.file = tmp .. "/shards.lua"
    local book = tmp .. "/Dune.epub"
    io.open(book, "w"):close()
    local DocSettings = require("docsettings")
    local ds = DocSettings:open(book)
    ds:saveSetting("annotations", {
        { text = "  Fear is the   mind-killer. ", note = "litany", chapter = "Ch 1", datetime = "2026-10-01 10:00:00", page = 12 },
        { text = "", page = 3 },
        { text = "A beginning is the time for taking the most delicate care.", datetime = "2026-10-02 09:00:00", page = 40 },
    })
    ds:flush()
    local list = Shards.of(book)
    Kit.ok(#list == 2 and list[1].text == "Fear is the mind-killer." and list[1].note == "litany", "highlights become shards, blanks are left out")
    Kit.ok(list[1].id:match("^%x%x%x%x%x%x%x%x$") ~= nil and list[1].id ~= list[2].id, "a shard has its own id")
    Shards.refresh(book)
    Kit.ok(Shards.count() == 1 + 1 and #Shards.ofBook(book) == 2, "a book read into the index adds its shards")
    Kit.ok(Shards.all()[1].date == "2026-10-02 09:00:00", "the newest shard comes first")
    Kit.ok(Shards.booksWith()[1].path == book and Shards.booksWith()[1].count == 2, "books with shards are listed")
    local pick = Shards.another()
    Kit.ok(pick and pick.of == 2 and pick.shard.path == book, "a random shard says which of how many it is")
    local ShardCard = require("cyberui/ui/shardcard")
    local W = Kit.Screen:getWidth()
    local card = ShardCard:new({ shard = list[1], number = 1, of = 2 })
    card:layout(W - 40, nil)
    local bb = Kit.canvas()
    card:paint(bb, 10, 10)
    bb:free()
    Kit.ok(card.h > 60 and card.h < 140, "a shard card is a few lines tall")
    -- an unchanged book is not read again
    local before = Shards.all()
    Shards.refresh(book)
    Kit.ok(Shards.all() == before, "an unchanged book is skipped")
    Shards.reset()
    Shards.file = nil

    local Bounty = require("cyberui/data/bounty")
    local list_b = Bounty.list()
    local last = 1e9
    for _, b in ipairs(list_b) do
        Kit.ok(b.days >= Bounty.GRACE_DAYS and b.reward == b.days * Bounty.PER_DAY and b.days <= last, "a bounty grows with the days idle, oldest first")
        last = b.days
    end
    Kit.ok(Bounty.total() == (function() local t = 0; for _, b in ipairs(list_b) do t = t + b.reward end; return t end)(), "the total adds the bounties")
    if #list_b > 0 then
        Bounty.skip(list_b[1].path)
        Kit.ok(#Bounty.list() == #list_b - 1, "a book said to be not wanted leaves the board")
        Bounty.reset()
        Kit.ok(#Bounty.list() == #list_b, "and comes back")
    end
end

-- opening a book at a shard
do
    local App = require("cyberui/app")
    local Actions = require("cyberui/actions")
    local real, after = App.openBook, nil
    App.openBook = function(_path, cb) after = cb end
    Actions.openAt("/x/Dune.epub", { page = "/body/DocFragment[2]", pos0 = "/body/DocFragment[2]/p[3]" })
    App.openBook = real
    local got
    after({ handleEvent = function(_, ev) got = ev end })
    Kit.ok(got and got.handler == "onGotoXPointer" and got.args[1] == "/body/DocFragment[2]" and got.args[2] == "/body/DocFragment[2]/p[3]",
        "opening at a shard goes to its place in the book")
    after({ paging = {}, handleEvent = function(_, ev) got = ev end })
    Kit.ok(got.handler == "onGotoPage", "and by page in a paged book")
end

-- the skyline
do
    local Skyline = require("cyberui/ui/skyline")
    local W = Kit.Screen:getWidth()
    local b = {}
    for d = 1, 30 do b[d] = { pages = d % 6 == 0 and 0 or d * 5, minutes = d * 3, current = d == 12, sign = d == 20 } end
    local sk = Skyline:new({ buildings = b, labels = { [1] = "1", [30] = "30" }, height = 190 })
    sk:layout(W - 40, nil)
    Kit.ok(sk.h > 100, "the skyline has its height")
    local bb = Kit.canvas()
    sk:paint(bb, 10, 10)
    Kit.ok(Kit.time(function() sk:paint(bb, 10, 10) end, 5) < 25, "a month's skyline paints in under 25 ms")
    bb:free()
    Skyline:new({ buildings = {}, height = 100 }):layout(W, nil)
    local Settings = require("cyberui/settings")
    local H = Kit.Screen:getHeight()
    for _, view in ipairs({ "grid", "skyline" }) do
        Settings.set("cal_view", view)
        local ok, err = pcall(function()
            local tab = require("cyberui/screens/log/calendar").build({ cal_back = 0 })
            tab:layout(W, H)
            local c = Kit.canvas()
            tab:paint(c, 0, 0)
            c:free()
        end)
        Kit.ok(ok, "the calendar tab builds as " .. view .. ": " .. tostring(err))
    end
    Settings.set("cal_view", nil)
    local ok, err = pcall(function()
        local tab = require("cyberui/screens/log/goal").build({ goal_back = 0, page = 1 })
        tab:layout(W, H)
        local c = Kit.canvas()
        tab:paint(c, 0, 0)
        c:free()
    end)
    Kit.ok(ok, "the goal tab builds with its skyline: " .. tostring(err))
end

-- the colour dial
do
    local Color = require("cyberui/theme/color")
    for _, hex in ipairs({ "#2457D6", "#C62828", "#0F8076", "#FFFFFF", "#000000", "#7BF0A8" }) do
        local h, s_, v = Color.toHSV(Color.parse(hex))
        Kit.ok(Color.hex(Color.fromHSV(h, s_, v)) == hex, "a colour survives hue, saturation and value: " .. hex)
    end
    local Dial = require("cyberui/ui/dial")
    local got
    local dial = Dial:new({ hue = 0, sat = 1, val = 1, size = 300, on_change = function(h, s_, v) got = { h, s_, v } end })
    dial:layout(300, 300)
    local bb = Kit.canvas()
    dial:paint(bb, 20, 30)
    Kit.ok(Kit.time(function() dial:paint(bb, 20, 30) end, 5) < 15, "the dial repaints in under 15 ms")
    bb:free()
    -- a tap on the right of the ring is a hue of about 90 degrees
    local cx, cy = dial.x + dial.w / 2, dial.y + dial.h / 2
    local ring_r = dial.w / 2 - Theme.px(9) - Theme.px(8)
    dial.tap_pos = { x = cx + ring_r, y = cy }
    dial:on_tap()
    Kit.ok(got and math.abs(got[1] - 90) < 3, "a tap on the ring picks its hue: " .. tostring(got and got[1]))
    got = nil
    dial.tap_pos = { x = cx - 10, y = cy + 10 }
    dial:on_tap()
    Kit.ok(got and got[2] > 0 and got[2] < 1 and got[3] < 1, "a tap in the matrix picks saturation and brightness")
    got = nil
    dial.tap_pos = { x = dial.x + 2, y = dial.y + 2 }
    dial:on_tap()
    Kit.ok(got == nil, "a tap outside both changes nothing")
    local Pick = require("cyberui/screens/colourpick")
    local p = Pick:new({ current = "#2457D6", on_pick = function() end })
    p:setHex("not a colour")
    Kit.ok(Color.hex(p:rgb()) == "#2457D6", "a bad colour code leaves the colour as it was")
    p:setHex("#C62828")
    Kit.ok(Color.hex(p:rgb()) == "#C62828", "a typed colour code is taken")
end

-- the jack-in card
do
    local JackIn = require("cyberui/jackin")
    local book = require("cyberui/data/library").all()[1]
    local W, H = Kit.Screen:getWidth(), Kit.Screen:getHeight()
    local card = JackIn.card(book)
    card:layout(W, H)
    local bb = Kit.canvas()
    card:paint(bb, 0, 0)
    bb:free()
    Kit.ok(Kit.time(function() local c = JackIn.card(book); c:layout(W, H) end, 10) < 20, "the jack-in card is made in under 20 ms")
    local UIManager = require("ui/uimanager")
    local seen = {}
    local real = UIManager.show
    UIManager.show = function(_self, w) seen[#seen + 1] = w.tag end
    local abbreviated = require("apps/filemanager/filemanagerutil").abbreviate(book)
    JackIn.silenced(book, function()
        UIManager:show({ tag = "opening", timeout = 0, text = "Opening file '" .. abbreviated .. "'." })
        UIManager:show({ tag = "question", text = "Restore the notes?" })
    end)
    Kit.ok(#seen == 1 and seen[1] == "question", "only KOReader's own opening message is kept off the screen")
    Kit.ok(UIManager.show ~= real and select(2, pcall(function() UIManager:show({ tag = "later" }) end)) == nil and seen[2] == "later",
        "showing works as before afterwards")
    UIManager.show = real
    local Settings = require("cyberui/settings")
    Settings.set("jack_in", false)
    Kit.ok(not JackIn.wanted(book), "the card can be turned off")
    Settings.set("jack_in", nil)
end

Kit.finish("features")
