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
    Kit.ok(Settings.get("library_count") == #all and Library.shownCount() == #all, "the library's size is kept for the next start")
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

    -- turning a page does not sort again; a book opened since does
    local History = require("cyberui/data/history")
    local ReadHistory = require("readhistory")
    local kept = Library.sort(all, "recent")
    Kit.ok(Library.sort(all, "recent") == kept, "the same sort with nothing changed gives the kept answer")
    local saved_hist = ReadHistory.hist
    local last = kept[#kept]
    ReadHistory.hist = { { file = last, time = os.time() + 100 } }
    local resorted = Library.sort(all, "recent")
    Kit.ok(resorted ~= kept and resorted[1] == last, "a book opened since moves to the front")
    Kit.ok(History.lastOpened(last) == ReadHistory.hist[1].time and History.lastOpened(kept[1] .. "-gone") == nil,
        "the history says when a book was opened, and nothing for one never opened")
    ReadHistory.hist = saved_hist

    -- sort keys kept between sorts give the same order as keys read afresh,
    -- and a change to a book is seen at the next sort
    local Books = require("cyberui/data/books")
    for _, order in ipairs(Library.SORTS) do Library.sort(all, order) end
    local cached = {}
    for _, order in ipairs({ "recent", "title", "recent", "author", "size" }) do
        cached[#cached + 1] = { order, Library.sortNow(all, order) }
    end
    Library.reset()
    local same = true
    for _, c in ipairs(cached) do
        local fresh = Library.sortNow(all, c[1])
        for i = 1, #fresh do if fresh[i] ~= c[2][i] then same = false end end
    end
    Kit.ok(same, "sorting with kept keys gives the order of keys read afresh")
    local by_title = Library.sortNow(all, "title")
    local last = by_title[#by_title]
    Books.forget(last)
    Books.info(last).title = "\001 first of all"
    local after = Library.sortNow(all, "title")
    Kit.ok(after[1] == last, "a book whose title changed is sorted by its new title")
    Books.forget(last)
    local status_ok = true
    for _, p in ipairs(all) do if Books.status(p) ~= Books.state(p).status then status_ok = false end end
    Kit.ok(status_ok, "a book's status alone matches its full reading state")

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
    Settings.set("library_group", "all")

    -- a page turn keeps the items; a book's status changing shows at once
    local Actions = require("cyberui/actions")
    local s = Lib:new({})
    s:build({ w = W, h = H })
    local items = s.items
    s.page = 2
    s:build({ w = W, h = H })
    Kit.ok(s.items == items, "turning a page keeps the list of items")
    local p = all[1]
    local was = Books.state(p).status
    local done = s.kept_items.counts.done
    Actions.writeStatus(p, was == "complete" and "reading" or "complete")
    s:build({ w = W, h = H })
    Kit.ok(s.items ~= items and s.kept_items.counts.done == done + (was == "complete" and -1 or 1),
        "a book marked finished is counted at the next build")
    Actions.writeStatus(p, was)
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
    -- an icon drawn again in a later start comes from its kept mask, the same to the pixel
    local function pixels(name)
        local bb = Kit.canvas()
        Icons.draw(bb, name, 0, 0, 30, require("ffi/blitbuffer").COLOR_BLACK)
        local t = {}
        for y = 0, 29 do for x = 0, 29 do t[#t + 1] = bb:getPixel(x, y):getColor8().a end end
        bb:free()
        return table.concat(t, ",")
    end
    local fresh = pixels("settings")
    Icons.free()
    local kept = pixels("settings")
    local blank = select(2, kept:gsub("255", "")) == 900
    Kit.ok(fresh == kept and not blank, "an icon read back from its kept mask draws the same")
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
    local Masthead = require("cyberui/ui/masthead")
    local W, H = Kit.Screen:getWidth(), Kit.Screen:getHeight()
    for _, build in ipairs({ function() return IdCard.full({}) end, function() return Masthead.build({ operator = true }) end, function() return Masthead.build({}) end }) do
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
    -- into a folder the reader chose: made absolute, a trailing slash and a relative path are fine
    local lfs = require("libs/libkoreader-lfs")
    local base = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-card"
    os.execute("rm -rf '" .. base .. "'; mkdir -p '" .. base .. "/pics'")
    local there = ProfileFlow.export(IdCard.full({}), base .. "/pics/")
    Kit.ok(there and there:sub(1, 1) == "/" and not there:find("//", 1, true) and lfs.attributes(there, "size") > 1000,
        "the card is saved in the chosen folder, whatever its trailing slash")
    local cwd = lfs.currentdir()
    lfs.chdir(base)
    local rel = ProfileFlow.export(IdCard.full({}), "pics")
    lfs.chdir(cwd)
    Kit.ok(rel and rel:sub(1, 1) == "/", "a relative folder gives a full path")
    local bad, why = ProfileFlow.export(IdCard.full({}), "/proc/no/such/folder")
    Kit.ok(bad == nil and why ~= nil, "a folder that can't be written to is reported, not lost")
    os.execute("rm -rf '" .. base .. "'")
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
    local card = ShardCard.build({ shard = list[1], number = 1, of = 2 })
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

    local Gigs = require("cyberui/data/gigs")
    -- reading goes at a steady pace of half a minute a page, unless a test sets another
    local now = 1700000000
    Gigs.clock = function() now = now + 30; return now end
    local board = Gigs.board()
    local last = 1e9
    for _, g in ipairs(board) do
        Kit.ok(g.days >= Gigs.GRACE_DAYS and g.price == Gigs.price(g.pages, g.days) and g.days <= last, "a gig is priced from its pages and days idle, oldest first")
        last = g.days
    end
    Kit.ok(Gigs.price(300, 7) == 75 and Gigs.price(300, 28) == 120 and Gigs.price(300, 700) == 120, "a gig's price grows by a quarter a week and stops at double after four weeks")
    Kit.ok(Gigs.price(1, 7) == 1 and Gigs.price(100, 14) == 30, "prices are whole eddies, not rounded up to a step")
    Kit.ok(Gigs.basePrice(300) == 30 and Gigs.basePrice(10) == 1, "any other book pays half the gig rate")
    local total = 0
    for k = 1, 10 do total = total + Gigs.milestone(120, k) end
    Kit.ok(Gigs.milestone(120, 1) == 6 and Gigs.finish(120) == 60 and total + Gigs.finish(120) == 120, "ten steps and the finish add up to the price")
    total = 0
    for k = 1, 10 do total = total + Gigs.milestone(75, k) end
    Kit.ok(total == 37 and Gigs.finish(75) == 38 and Gigs.milestone(75, 10) > 0, "a price that does not divide still adds up, and the last tenth pays")
    total = 0
    for k = 1, 10 do total = total + Gigs.milestone(5, k) end
    Kit.ok(total == 2 and Gigs.finish(5) == 3 and Gigs.milestone(5, 10) > 0, "even a tiny price pays out in full")
    Kit.ok(not Gigs.eligible("/x/picture.png") and not Gigs.eligible("/x/scan.JPG"), "pictures never pay")
    Kit.ok(#board <= Gigs.slots(), "the board never holds more than its slots")
    if #board > 0 then
        Gigs.skip(board[1].path)
        Kit.ok(#Gigs.board() == #board - 1 or #Gigs.board() == math.min(Gigs.slots(), #board), "a book said to be not wanted leaves the board")
        Settings.set("bounty_skipped", nil)
    end
end

-- gigs: taking one, reading it, the payouts and the signed ledger
do
    local Gigs = require("cyberui/data/gigs")
    local Ledger = require("cyberui/data/ledger")
    local Settings = require("cyberui/settings")
    local lfs = require("libs/libkoreader-lfs")
    local saved = Settings.get("gigs")
    Settings.set("gigs", nil)
    Gigs.reload()
    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-gigs"
    os.execute("rm -rf '" .. tmp .. "'; mkdir -p '" .. tmp .. "'")
    local book = tmp .. "/Long.epub"
    local f = io.open(book, "w")
    f:write(string.rep("x", 600 * 1024))
    f:close()
    local old = os.time() - 80 * 86400
    lfs.touch(book, old, old)
    local Library = require("cyberui/data/library")
    local home = G_reader_settings:readSetting("home_dir")
    G_reader_settings:saveSetting("home_dir", tmp)
    Library.reset()
    Settings.set("gig_slots", nil)
    Kit.ok(Gigs.pages(book) == 300, "a book never opened is sized from its file")
    Gigs.board()   -- (the reader sees the board before taking a gig from it)
    Gigs.accept(book)
    local q = Gigs.quote(book)
    Kit.ok(q and q.price == 120, "taking a gig fixes the price")
    Gigs.accept(tmp .. "/Not on the board.epub")
    Kit.ok(Gigs.quote(tmp .. "/Not on the board.epub") == nil, "a book that was not on the board is not taken")
    Gigs.follow(book)
    for p = 1, 100 do Gigs.page(p, 300) end
    local paid_now = Gigs.settle()
    Kit.ok(paid_now == 18 and Ledger.balance() == 18, "a third of the book pays three steps")
    Kit.ok(Gigs.settle() == 0, "and nothing twice")
    Gigs.follow(book)
    Kit.ok(Gigs.active()[1].milestones == 3 and Gigs.active()[1].price == 120, "the gig is active with its payouts so far")
    for p = 101, 300 do Gigs.page(p, 300) end
    Kit.ok(Gigs.settle() == 102 and Ledger.balance() == 120, "reading to the end pays the rest and the finish")
    local earned, done = Ledger.totals()
    Kit.ok(earned == 120 and done == 1 and #Gigs.active() == 0, "the gig is done")
    Kit.ok(Gigs.recent(1)[1].kind == "f" and Gigs.takeReceipt().finished, "the finish is the latest payout and a notice is waiting")
    -- skipping to the end pays nothing
    local skim = tmp .. "/Skim.epub"
    f = io.open(skim, "w"); f:write(string.rep("x", 600 * 1024)); f:close()
    lfs.touch(skim, old, old)
    Library.reset()
    Gigs.reload()
    Gigs.accept(skim)
    Gigs.follow(skim)
    Gigs.page(300, 300)
    Kit.ok(Gigs.settle() == 0, "jumping to the last page pays nothing")
    -- the settings file edited by hand
    local d = Settings.get("gigs")
    d.ledger[1].a = 999
    d.quotes[skim].price = 9000
    Gigs.reload()
    Kit.ok(Ledger.balance() == 120 - 6 and Ledger.rejected() == 1, "an edited ledger entry stops counting")
    Kit.ok(Gigs.quote(skim) == nil, "an edited price is not trusted")
    Settings.set("gigs", saved)
    G_reader_settings:saveSetting("home_dir", home)
    Library.reset()
    Gigs.reload()
    os.execute("rm -rf '" .. tmp .. "'")
end

-- the board: slots, the draw, the weekly redraw, rolling, turning a book down, the plain rate
do
    local Gigs = require("cyberui/data/gigs")
    local Ledger = require("cyberui/data/ledger")
    local Library = require("cyberui/data/library")
    local Settings = require("cyberui/settings")
    local lfs = require("libs/libkoreader-lfs")
    local saved = { Settings.get("gigs"), Settings.get("gig_slots"), Settings.get("gig_rotation"), Settings.get("bounty_skipped") }
    local home = G_reader_settings:readSetting("home_dir")
    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-board"
    os.execute("rm -rf '" .. tmp .. "'; mkdir -p '" .. tmp .. "'")
    local old = os.time() - 10 * 86400
    for i = 1, 12 do
        local f = io.open(string.format("%s/Book%02d.epub", tmp, i), "w")
        f:write(string.rep("x", 200 * 1024))
        f:close()
        lfs.touch(string.format("%s/Book%02d.epub", tmp, i), old, old)
    end
    local fresh = tmp .. "/Fresh.epub"
    local f = io.open(fresh, "w"); f:write(string.rep("x", 200 * 1024)); f:close()
    G_reader_settings:saveSetting("home_dir", tmp)
    Library.reset()
    Settings.set("gigs", nil); Settings.set("gig_slots", nil); Settings.set("gig_rotation", nil); Settings.set("bounty_skipped", nil)
    Gigs.reload()
    local function paths(list) local t = {} for _, g in ipairs(list) do t[#t + 1] = g.path end table.sort(t) return table.concat(t, ",") end
    local board = Gigs.board()
    local seen, dup = {}, false
    for _, g in ipairs(board) do dup = dup or seen[g.path]; seen[g.path] = true end
    Kit.ok(#board == 5 and not dup, "the board holds five different books by default")
    Kit.ok(not seen[fresh], "a book added today is not offered yet")
    Kit.ok(paths(Gigs.board()) == paths(board) and Gigs.rotatesIn() == 7, "the board stays as it is until it is drawn anew")
    Settings.set("gig_slots", 10)
    Gigs.reload()
    Kit.ok(#Gigs.board() == 5, "a bigger board waits for the next draw, so settings cannot be used to get fresh picks")
    Gigs.skip(board[1].path)
    Kit.ok(#Gigs.board() == 4 and not Gigs.offer(board[1].path), "a book turned down leaves its slot empty")
    Ledger.add("m", "/earned", 1, 30)
    Ledger.save()
    local victim = Gigs.board()[1].path
    local ok, pick = Gigs.roll(victim)
    Kit.ok(ok and pick ~= victim and Ledger.balance() == 10 and #Gigs.board() == 4 and Gigs.offer(pick), "a roll swaps the book for another and costs 20 eddies")
    Kit.ok(not Gigs.offer(victim), "the book that was rolled away is off the board")
    Kit.ok(select(2, Gigs.roll(pick)) == "short" and Ledger.balance() == 10, "a roll needs the eddies")
    Kit.ok(select(2, Gigs.roll("/not/on/board.epub")) == "slot", "only a gig on the board can be rolled")
    Ledger.add("m", "/earned", 2, 100)
    Ledger.save()
    Kit.ok(Gigs.roll(pick) and Ledger.balance() == 90, "every roll is a separate signed purchase")
    -- the draw comes again after the days are up (and a bigger board is filled then)
    local d = Settings.get("gigs")
    d.board.t = os.time() - 8 * 86400
    Gigs.reload()
    Kit.ok(#Gigs.board() == 10 and Gigs.rotatesIn() == 7, "after a week the board is drawn anew, with the new slot count")
    -- taking a gig is only possible on a book the board offers
    local on, off = Gigs.board()[1].path, nil
    for i = 1, 12 do
        local path = string.format("%s/Book%02d.epub", tmp, i)
        if not Gigs.offer(path) then off = path end
    end
    Gigs.accept(on)
    Kit.ok(Gigs.quote(on) and Gigs.quote(on).days >= 10 and Gigs.quote(on).price == Gigs.price(Gigs.pages(on), Gigs.quote(on).days), "taking a gig fixes the board's price")
    Gigs.accept(fresh)
    Kit.ok(Gigs.quote(fresh) == nil, "a book that is not on the board cannot be taken as a gig")
    -- any other book pays at the plain rate
    local before = Ledger.balance()
    Gigs.follow(fresh)
    Kit.ok(Gigs.quote(fresh) and Gigs.quote(fresh).days == 0 and Gigs.quote(fresh).price == Gigs.basePrice(Gigs.pages(fresh)), "a book read off the board is followed at the plain rate")
    local pages = Gigs.pages(fresh)
    for p = 1, pages do Gigs.page(p, pages) end
    local paid = Gigs.settle()
    Kit.ok(paid == Gigs.basePrice(pages) and Ledger.balance() == before + paid and Gigs.takeReceipt().gig == false, "reading it to the end pays the plain price, with a notice that is not a gig's")
    Kit.ok(#Gigs.active() == 1 and Gigs.active()[1].path == on, "a finished plain book leaves the active list")
    local earned, done = Ledger.totals()
    Kit.ok(done == 0, "a plain book does not count as a gig done")
    -- pictures and tiny files do not pay, at the plain rate or as gigs
    local tiny, pic, steady = tmp .. "/Tiny.pdf", tmp .. "/Photo.png", tmp .. "/Steady.epub"
    for _, path in ipairs({ tiny, pic }) do local h = io.open(path, "w"); h:write(string.rep("x", 20 * 1024)); h:close() end
    local h = io.open(steady, "w"); h:write(string.rep("x", 600 * 1024)); h:close()
    local before2 = Ledger.balance()
    for _, path in ipairs({ tiny, pic }) do
        Gigs.follow(path)
        Gigs.page(1, 1)
        Kit.ok(Gigs.quote(path) == nil and Gigs.settle() == 0, "a tiny file or a picture pays nothing: " .. path:match("[^/]+$"))
    end
    Kit.ok(Ledger.balance() == before2, "and no eddies appear")
    -- turning pages without reading pays nothing: a page must stay on screen
    -- long enough for its words to be read (see Pace), whatever the font size,
    -- the reading speed or the kind of book
    local Pace = require("cyberui/data/pace")
    local real = Gigs.clock
    local t0 = 1800000000
    Gigs.clock = function() return t0 end
    -- a book like an EPUB (text from one page's top to the next), like a PDF
    -- with a text layer, and like a comic or a scan (no text at all)
    local function creDoc(path, total, per_page)
        local text = string.rep("word ", per_page)
        return { file = path, getPageCount = function() return total end,
            getPageXPointer = function(_, p) return "/body/p[" .. p .. "]" end,
            getTextFromXPointers = function() return text end }
    end
    local function pdfDoc(path, total, per_page)
        local line = {}
        for i = 1, per_page do line[i] = { word = "w" } end
        return { file = path, getPageCount = function() return total end, getPageTextBoxes = function() return { line } end }
    end
    local function picDoc(path, total)
        return { file = path, getPageCount = function() return total end, getPageTextBoxes = function() return {} end }
    end
    local n_books = 0
    -- a fresh book of `kb` kilobytes (its size sets its price, 2 KB a page for text)
    local function book(ext, kb)
        n_books = n_books + 1
        local path = tmp .. "/Speed" .. n_books .. "." .. ext
        local h2 = io.open(path, "w"); h2:write(string.rep("x", kb * 1024)); h2:close()
        return path
    end
    -- Read `path` from page 1 to `total`, each page staying `secs` seconds (a
    -- number, or a function of the page), measured first from `doc`. Returns what was paid.
    local function readThrough(path, doc, total, secs)
        Gigs.follow(path)
        if doc then Gigs.measure(doc) end
        for p = 1, total do
            Gigs.page(p, total)
            t0 = t0 + (type(secs) == "function" and secs(p) or secs)
        end
        return Gigs.settle()
    end
    local function full(path) return Gigs.quote(path).price end

    -- nothing measured yet (a book opened a moment ago): every page at once pays nothing
    local steady0 = book("epub", 600)
    Gigs.follow(steady0)
    for p = 1, 300 do Gigs.page(p, 300) end
    Kit.ok(Gigs.quote(steady0) ~= nil and Gigs.settle() == 0, "turning every page at once pays nothing")

    -- an EPUB at a normal font: 300 words a page, so a page needs 12 seconds
    local doc_words = 300
    local cases = {
        { 72, true, "250 words a minute (72 s a page) is reading" },
        { 30, true, "600 words a minute (30 s a page) is reading" },
        { 13, true, "1400 words a minute (13 s a page), a very fast reader, still counts" },
        { 10, false, "1800 words a minute (10 s a page) is skimming" },
        { 3, false, "3 s a page on a full page is flipping" },
    }
    for _, c in ipairs(cases) do
        local b = book("epub", 600)
        local got = readThrough(b, creDoc(b, 300, doc_words), 300, c[1])
        Kit.ok((got == full(b)) == c[2] and (c[2] or got == 0), "EPUB, normal font: " .. c[3] .. " (paid " .. got .. " of " .. full(b) .. ")")
    end
    -- the same book in an enormous font: 2250 pages of 40 words, a page needs 1.6 seconds
    do
        local b = book("epub", 600)
        Gigs.follow(b)
        Kit.ok(Gigs.measure(creDoc(b, 300, doc_words)) == 90000, "the book is measured once: 90000 words")
        local e0 = Gigs.earnings(b)
        Kit.ok(e0.mode == "words" and e0.state == "paying" and e0.earned == 0 and e0.left == e0.price, "its earnings start at nothing, the whole price to come")
        local got = readThrough(b, nil, 2250, 4)
        local e = Gigs.earnings(b)
        Kit.ok(got == full(b) and e.finish_paid and e.earned == e.price and e.left == 0, "enormous font, 4 s a page (a fast reader): the whole price, finish included (paid " .. got .. ")")
        Kit.ok(e.counted == 2250 and e.quick == 0, "every page counted, none too quick: " .. tostring(e.counted) .. " / " .. tostring(e.quick))
    end
    do
        local b = book("epub", 600)
        Gigs.follow(b)
        Gigs.measure(creDoc(b, 300, doc_words))
        -- (the last page is still on screen: not judged yet)
        Kit.ok(readThrough(b, nil, 2250, 1) == 0 and Gigs.earnings(b).quick == 2249, "enormous font, 1 s a page: flipping, nothing paid, every turned page told as too quick")
    end
    -- the font changes halfway: the words in the book stay, so the pages' need follows the new count
    do
        local b = book("epub", 600)
        Gigs.follow(b)
        Gigs.measure(creDoc(b, 300, doc_words))
        for p = 1, 150 do Gigs.page(p, 300); t0 = t0 + 14 end      -- normal font, 14 s (needs 12)
        for p = 451, 900 do Gigs.page(p, 900); t0 = t0 + 5 end     -- three times the font: needs 4 s
        Kit.ok(Gigs.settle() == full(b), "a font change halfway keeps paying at the new size")
    end
    -- right after a change of font KOReader keeps the old page count until the book is laid out
    -- again: those pages are judged by the floor, so a big font read fast still counts meanwhile
    do
        local b = book("epub", 600)
        Gigs.follow(b)
        Gigs.measure(creDoc(b, 300, doc_words))
        for p = 1, 120 do Gigs.page(p, 300, true); t0 = t0 + 4 end     -- stale count of 300 (needs 12 s when settled)
        Gigs.page(121, 300, true)
        Gigs.settle()
        local e = Gigs.earnings(b)
        Kit.ok(e.counted == 120 and e.milestones >= 3, "while the book is laid out anew, 4 s a page counts: " .. e.counted)
        for p = 122, 200 do Gigs.page(p, 300, true); t0 = t0 + 1 end
        Gigs.settle()
        Kit.ok(Gigs.earnings(b).quick >= 78, "and 1 s a page is still too quick then")
    end
    -- a PDF with a text layer: 350 words a page, a page needs 14 seconds
    do
        local b = book("pdf", 18000)
        Kit.ok(readThrough(b, pdfDoc(b, 300, 350), 300, 25) == full(b), "PDF with text, 25 s a page: the whole price")
        local b2 = book("pdf", 18000)
        Kit.ok(readThrough(b2, pdfDoc(b2, 300, 350), 300, 6) == 0, "PDF with text, 6 s a page: skimming, nothing")
        Kit.ok(Gigs.earnings(b2).mode == "words", "a PDF with text is judged by its words")
    end
    -- a comic or a scan has no text: judged by the reader's own pace in it
    do
        local b = book("pdf", 18000)
        Gigs.follow(b)
        Kit.ok(Gigs.measure(picDoc(b, 300)) == 0 and Gigs.earnings(b).mode == "pace", "a PDF without text is measured as a picture book")
        -- eight seconds a page, now and then a page flicked back past in a second
        local got = readThrough(b, nil, 300, function(p) return p % 10 == 0 and 1 or 8 end)
        Kit.ok(got == full(b), "pictures at 8 s a page pay the whole price (paid " .. got .. ")")
        local e = Gigs.earnings(b)
        Kit.ok(e.quick == 29 and e.counted == 270, "the flicked pages (the last one still on screen) are too quick, the rest counted: " .. e.counted .. " / " .. e.quick)
        local b2 = book("pdf", 18000)
        Kit.ok(readThrough(b2, picDoc(b2, 300), 300, 1) == 0, "pictures flicked at 1 s a page pay nothing")
        local b3 = book("cbz", 90000)
        Kit.ok(readThrough(b3, { file = b3, getPageCount = function() return 300 end }, 300, 5) == full(b3), "a comic KOReader gives no text for, 5 s a page, pays by pace")
    end
    -- a book that cannot be read for its words (or not yet) uses the pace rule with its floor
    do
        local b = book("epub", 600)
        Kit.ok(readThrough(b, nil, 300, 2.5) == full(b), "not measured yet: 2.5 s a page passes the 2 s floor")
        Kit.ok(Pace.need(Pace.new(nil), 300) == Pace.PACE_FLOOR, "the floor is the need with no pace known")
    end
    -- the Active tab: gigs first, however little read, then the many plain books
    do
        local gig = book("epub", 600)
        local d = Ledger.data()
        local q = { price = 99, days = 21, t = os.time() }
        q.sig = Ledger.sign(table.concat({ "q", gig, q.price, q.days, q.t }, "|"))
        d.quotes[gig] = q
        local list = Gigs.active()
        local first_plain
        for i, a in ipairs(list) do if not a.gig then first_plain = first_plain or i end end
        local plain_ahead = false
        for i, a in ipairs(list) do if a.gig and first_plain and i > first_plain then plain_ahead = true end end
        local at
        for i, x in ipairs(list) do if x.path == gig then at = i end end
        Kit.ok(at and first_plain and at < first_plain and list[at].milestones == 0, "a gig not yet read comes before every plain book in the Active list (" .. tostring(at) .. " < " .. tostring(first_plain) .. ")")
        Kit.ok(first_plain and list[first_plain].milestones >= 3 and not plain_ahead, "plain books, even ones further along, all come after the gigs")
    end
    -- words are counted in every script
    Kit.ok(Pace.countWords("one two  three\nfour") == 4, "words are runs of non-spaces")
    Kit.ok(Pace.countWords("日本語の本 and two") == 7, "each Chinese or Japanese character is a word")
    -- a page passed on the way (a jump, a re-render) and a page left for an hour are not reading times
    local p0 = Pace.new(0)
    Kit.ok(not Pace.note(p0, 0.2) and not Pace.note(p0, 3600) and Pace.note(p0, 9) and #p0.times == 1, "only reading times make the usual pace")
    Gigs.clock = real
    Settings.set("gigs", saved[1]); Settings.set("gig_slots", saved[2]); Settings.set("gig_rotation", saved[3]); Settings.set("bounty_skipped", saved[4])
    G_reader_settings:saveSetting("home_dir", home)
    Library.reset()
    Gigs.reload()
    os.execute("rm -rf '" .. tmp .. "'")
end

-- the shop: the catalogue, signed purchases, wearing
do
    local Ledger = require("cyberui/data/ledger")
    local Settings = require("cyberui/settings")
    local Shop = require("cyberui/data/shop")
    local ids = {}
    for _, cat in ipairs(Shop.categories) do
        local free, top = 0, 0
        for _, st in ipairs(cat.styles) do
            Kit.ok(not ids[st.id] and st.id:find("^" .. cat.id .. "%.") ~= nil, st.id .. " has an id of its own")
            ids[st.id] = true
            Kit.ok(st.price % 10 == 0 and st.price >= 0 and (st.draw or st.build or st.price == 0), st.id .. " has a price and a look")
            if st.price == 0 then free = free + 1 end
            top = math.max(top, st.price)
        end
        Kit.ok(#cat.styles >= 4 and #cat.styles <= 5, cat.id .. " has four or five styles")
        Kit.ok(free == 1 and cat.styles[1].price == 0, cat.id .. " has one free style, the first")
        Kit.ok(top >= 800 and top <= 1000, cat.id .. " tops out at 8 to 10 typical gigs")
        Kit.ok(cat.styles[2].price <= 150, cat.id .. " starts at about one gig")
    end
    local saved = Settings.get("gigs")
    Settings.set("gigs", nil)
    Settings.set("style_frame", nil)
    Ledger.reload()
    local notch, circuit = Shop.style("frame.notch"), Shop.style("frame.circuit")
    Kit.ok(not Shop.owned(notch) and Shop.worn("frame").id == "frame.standard", "nothing is owned but the free styles")
    Kit.ok(select(2, Shop.buy(notch)) == "short" and Ledger.balance() == 0, "a purchase with no eddies is refused")
    Ledger.add("m", "/book", 1, 150)
    Ledger.save()
    Kit.ok(Shop.status(circuit) == "short" and select(2, Shop.status(circuit)) == 100, "a style that costs more says how many eddies are missing")
    Kit.ok(Shop.status(notch) == "buy", "an affordable one can be bought")
    Kit.ok(Shop.buy(notch) and Ledger.balance() == 50 and Shop.owned(notch), "buying takes the price and the style is owned")
    Kit.ok(select(2, Shop.buy(notch)) == "owned" and Ledger.balance() == 50, "and cannot be bought twice")
    Kit.ok(select(2, Shop.buy(circuit)) == "short" and Ledger.balance() == 50, "an overspend is refused, the balance is kept")
    Kit.ok(not Shop.wear(circuit) and Shop.wear(notch) and Shop.worn("frame") == notch, "an owned style is worn, an unowned one is not")
    Ledger.reload()
    Kit.ok(Settings.get("style_frame") == "frame.notch" and Shop.worn("frame") == notch and Shop.status(notch) == "worn", "what is worn is kept")
    -- the settings file edited by hand
    local d = Settings.get("gigs")
    local forged = { k = "s", p = "frame.circuit", n = 0, a = -1, t = os.time(), sig = "0000" }
    d.ledger[#d.ledger + 1] = forged
    d.ledger[#d.ledger + 1] = { k = "m", p = "/book", n = 2, a = 99999, t = os.time(), sig = "0000" }
    Ledger.reload()
    Kit.ok(not Shop.owned(circuit) and Ledger.balance() == 50 and Ledger.rejected() == 2, "forged purchases and payouts do not count")
    d.ledger[2].a = -1
    Ledger.reload()
    Kit.ok(not Shop.owned(notch) and Shop.worn("frame").id == "frame.standard", "a tampered purchase is not owned and the free style is worn")
    Settings.set("gigs", saved)
    Settings.set("style_frame", nil)
    Ledger.reload()
end

-- the switch: off lends every look and pays nothing; on again keeps only what was bought
do
    local Economy = require("cyberui/data/economy")
    local Gigs = require("cyberui/data/gigs")
    local Ledger = require("cyberui/data/ledger")
    local Settings = require("cyberui/settings")
    local Shop = require("cyberui/data/shop")
    local lfs = require("libs/libkoreader-lfs")
    local saved, was_on = Settings.get("gigs"), Settings.get("gigs_on")
    Settings.set("gigs", nil)
    Settings.set("gigs_on", nil)
    for _, cat in ipairs(Shop.categories) do Settings.set("style_" .. cat.id, nil) end
    Gigs.reload()
    local notch, circuit = Shop.style("frame.notch"), Shop.style("frame.circuit")
    local top = Shop.category("frame").styles[#Shop.category("frame").styles]
    Ledger.add("m", "/book", 1, 150)
    Ledger.save()
    Shop.buy(notch)
    Kit.ok(Economy.on() and Ledger.balance() == 50 and not Shop.owned(top), "on by default, with a style bought and the top one not owned")
    Economy.set(false)
    Kit.ok(not Economy.on() and Shop.owned(top) and Shop.owned(circuit), "off lends every look")
    Kit.ok(Shop.wear(top) and Shop.worn("frame") == top, "and one can be worn")
    Kit.ok(select(2, Shop.buy(circuit)) == "off" and Ledger.balance() == 50 and #Gigs.board() == 0, "nothing can be bought and the board is empty")
    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-switch"
    os.execute("rm -rf '" .. tmp .. "'; mkdir -p '" .. tmp .. "'")
    local book = tmp .. "/Long.epub"
    local f = io.open(book, "w"); f:write(string.rep("x", 600 * 1024)); f:close()
    local old = os.time() - 80 * 86400
    lfs.touch(book, old, old)
    Gigs.accept(book)
    Gigs.follow(book)
    for p = 1, 300 do Gigs.page(p, 300) end
    Kit.ok(Gigs.quote(book) == nil and Gigs.settle() == 0 and Ledger.balance() == 50, "reading while off takes no gig and pays nothing")
    Shop.wear(notch)
    Economy.set(true)
    Kit.ok(Economy.on() and Shop.worn("frame") == notch and Settings.get("style_frame") == "frame.notch", "back on, a bought look stays worn")
    Economy.set(false)
    Shop.wear(top)
    Economy.set(true)
    Kit.ok(Shop.worn("frame").id == "frame.standard" and Settings.get("style_frame") == nil, "back on, a borrowed look goes back to the free one")
    Ledger.add("m", "/book", 2, 2000)
    Ledger.save()
    Shop.buy(top)
    Kit.ok(Shop.owned(top) and Shop.worn("frame").id == "frame.standard", "buying it later does not bring the old choice back")
    -- the settings file edited by hand: the switch flipped on with a borrowed look still chosen
    Economy.set(false)
    Shop.wear(circuit)
    Settings.set("gigs_on", true)
    Kit.ok(Shop.worn("frame").id == "frame.standard" and not Shop.owned(circuit), "a borrowed look is not worn once the switch is on, however it got there")
    Settings.set("gigs", saved)
    Settings.set("gigs_on", was_on)
    for _, cat in ipairs(Shop.categories) do Settings.set("style_" .. cat.id, nil) end
    Gigs.reload()
    Ledger.reload()
    os.execute("rm -rf '" .. tmp .. "'")
end

-- a drag that arrives after the photo window was closed does nothing (it crashed once)
do
    local BB = require("ffi/blitbuffer")
    local PhotoWindow = require("cyberui/ui/photowindow")
    local win = PhotoWindow:new({ img = BB.new(200, 100, BB.TYPE_BBRGB32), size = 100 })
    win:release()
    local ok = pcall(function()
        win:on_drag(0, 0, "start")
        win:on_drag(5, 5, "move")
        win:on_drag(0, 0, "end")
    end)
    Kit.ok(ok, "a drag on a closed photo window is ignored")
end

-- the board drawn in the diagnostics' empty space: fits several rooms, nothing when too small
do
    local Mainboard = require("cyberui/ui/mainboard")
    local Paint = require("cyberui/gfx/paint")
    local WHITE = require("ffi/blitbuffer").COLOR_WHITE
    for _, size in ipairs({ { 1128, 472 }, { 900, 380 }, { 600, 420 }, { 1100, 300 }, { 1000, 200 }, { 1128, 240 } }) do
        local bb = Kit.canvas(1200, 600)
        Paint.fill(bb, 0, 0, 1200, 600, WHITE)
        local ok = pcall(function()
            local el = Mainboard:new({})
            el:layout(size[1], size[2])
            el:paint(bb, 10, 10)
        end)
        Kit.ok(ok, "the board draws in " .. size[1] .. " x " .. size[2])
        bb:free()
    end
    -- the label font: every glyph is 7 rows of 5 dots
    for ch, rows in pairs(Mainboard.FONT) do
        local ok = #rows == 7
        for _, row in ipairs(rows) do ok = ok and #row == 5 end
        Kit.ok(ok, "the glyph " .. ch .. " is 5 x 7")
    end
    local bb = Kit.canvas(400, 200)
    Paint.fill(bb, 0, 0, 400, 200, WHITE)
    local el = Mainboard:new({})
    el:layout(300, 60)
    el:paint(bb, 0, 0)
    Kit.ok(bb:getPixel(150, 30):getColor8().a == 255, "nothing is drawn where the room is too small")
    bb:free()
end

-- the support QR code: a square of whole modules, white round dark modules
do
    local QRCode = require("cyberui/ui/qrcode")
    local qr = QRCode:new({ text = "https://buymeacoffee.com/emirertorer", size = 150 })
    qr:layout(nil, nil)
    Kit.ok(qr.code ~= nil and qr.code.n >= 21 and qr.w == qr.h and qr.w % qr:module() == 0, "the QR code is a square of whole modules")
    local bb = Kit.canvas(400, 400)
    require("cyberui/gfx/paint").fill(bb, 0, 0, 400, 400, require("ffi/blitbuffer").COLOR_BLACK)
    qr:paint(bb, 10, 10)
    Kit.ok(bb:getPixel(10, 10):getColor8().a == 255 and bb:getPixel(10 + qr:module() * 4, 10 + qr:module() * 4):getColor8().a == 0,
        "white quiet border round a dark finder corner")
    bb:free()
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

-- reader parking: on by default, and nothing to do when nothing is parked
do
    local Park = require("cyberui/park")
    local Settings = require("cyberui/settings")
    Settings.set("park_reader", nil)
    Kit.ok(Park.enabled(), "parking is on until it is switched off")
    Settings.set("park_reader", false)
    Kit.ok(not Park.enabled() and not Park.park({ document = {} }), "a book is not parked while parking is off")
    Kit.ok(not Park.isParked() and Park.file() == nil and not Park.finish() and not Park.unpark("/some/book.epub"),
        "with nothing parked there is nothing to finish or bring back")
    Kit.ok(Park.ui() == nil, "and no file browser stand-in")
    Settings.set("park_reader", true)
    Kit.ok(Park.enabled() and not Park.park({ document = {} }), "switched on, a book from a path home never opened is not parked (home's rotation unknown)")
    Settings.set("park_reader", nil)
end

-- touches queued while a book closed are not pressed on home
do
    local Host = require("cyberui/host")
    local time = require("ui/time")
    local now = time.now()
    local host = { ignore_before = now }
    Kit.ok(Host.stale(host, { time = now - time.s(2) }), "a touch made before the close finished is dropped")
    Kit.ok(not Host.stale(host, { time = now + time.s(2) }), "a touch made after it is kept")
    Kit.ok(not Host.stale({}, { time = now }) and not Host.stale(host, {}), "with no close pending, or no time on the touch, nothing is dropped")
    -- a swipe that starts on the tab bar (which swallows touches but cannot be dragged) must not crash
    local swallower = { swallow = true }
    local pan_host = { stale = function() return false end, target = function() return swallower end }
    local ok_pan, handled = pcall(Host.onPan, pan_host, nil, { pos = { x = 1, y = 1 }, relative = { x = 0, y = -5 } })
    Kit.ok(ok_pan and handled == true and pan_host.dragging == nil, "a pan that starts on something undraggable is swallowed, not a crash")
end

-- the photo window, a see-through picture, paging a long column, the log's metric
do
    local BB = require("ffi/blitbuffer")
    local Profile = require("cyberui/data/profile")
    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-clear.png"
    -- a PNG with an alpha channel, every pixel see-through
    require("ffi/png").encodeToFile(tmp, require("ffi").new("uint8_t[?]", 40 * 20 * 4), 40, 20, 4)
    local flat = Profile.load(tmp, Profile.PHOTO_MAX)
    local c = flat:getPixel(5, 5):getColorRGB32()
    Kit.ok(flat and flat:getWidth() == 40 and c.r == 255 and c.g == 255 and c.b == 255, "a see-through picture is read on white, not black")
    flat:free()
    local small = Profile.load(tmp, 16)
    Kit.ok(small and math.max(small:getWidth(), small:getHeight()) == 16, "a big picture is made smaller, a small one is not made bigger")
    small:free()
    os.remove(tmp)

    local PhotoWindow = require("cyberui/ui/photowindow")
    local win = PhotoWindow:new({ img = BB.new(400, 200, BB.TYPE_BBRGB32), size = 200, width = 200, height = 200 })
    win:layout(200, 200)
    local x, y, side = win:crop()
    Kit.ok(side == 200 and y == 0 and x >= 0 and x <= 200, "the window first fills with the picture's middle")
    win:on_drag(0, 0, "start")
    win:on_drag(-500, 0, "move")
    local x2 = win:crop()
    Kit.ok(x2 == 200, "dragging stops at the picture's edge")
    win:setZoom(1)
    local cx, cy, cside = win:crop()
    Kit.ok(cside == 400 and cx == 0 and cy == -100, "zoomed out the whole picture shows, centred, on white")
    local out = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-crop"
    os.execute("rm -rf '" .. out .. "'; mkdir -p '" .. out .. "'")
    Profile.dir = out
    Kit.ok(Profile.savePhoto(win.img, cx, cy, cside) and Profile.hasPhoto(), "a square that reaches past the picture is kept")
    Profile.clearPhoto()
    Profile.dir = nil
    win:release()

    local Layout = require("cyberui/ui/layout")
    local PagedColumn = require("cyberui/ui/pagedcolumn")
    local items = {}
    for i = 1, 10 do items[i] = Layout.Spacer:new({ height = 50 }) end
    local made_pager = false
    local column = PagedColumn:new({ items = items, gap = 0, make_pager = function()
        made_pager = true
        return Layout.Spacer:new({ height = 40 })
    end })
    column:layout(300, 220)
    Kit.ok(column.pages == 4 and made_pager, "a long column pages, leaving room for the paging row (" .. tostring(column.pages) .. ")")
    Kit.ok(#column.children == 3 + 1, "a page holds the items that fit and the paging row")
    column.page = 4
    column:layout(300, 220)
    Kit.ok(#column.children == 1 + 1, "the last page holds what is left")
    local short = PagedColumn:new({ items = { Layout.Spacer:new({ height = 50 }) }, gap = 0, make_pager = function() error("no pager wanted") end })
    short:layout(300, 220)
    Kit.ok(short.pages == 1, "a short column has no paging row")

    local Metric = require("cyberui/data/metric")
    local Settings = require("cyberui/settings")
    Settings.set("log_metric", nil)
    Kit.ok(not Metric.pages() and Metric.goal(30) == 30 and Metric.text(25.4) == "25 MIN", "minutes are counted at first, against the goal")
    Metric.toggle()
    Kit.ok(Metric.pages() and Metric.goal(30) == nil and Metric.text(12) == "12 PG", "pages have no minutes goal")
    Kit.ok(Metric.level(0, 30, 10) == 0 and Metric.level(10, 30, 10) == 4 and Metric.level(1, 30, 10) == 1, "page shades go by the largest value shown")
    Settings.set("log_metric", nil)
end

-- translations: the .po reader, plural rules, capitals, the wrapper with a made-up language
do
    local Po = require("cyberui/i18n/po")
    local Plural = require("cyberui/i18n/plural")
    local Case = require("cyberui/i18n/case")
    local I18n = require("cyberui/gettext")
    local Format = require("cyberui/format")

    local parsed = Po.parse('msgid ""\nmsgstr ""\n"Plural-Forms: nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);\\n"\n\n'
        .. '#: a.lua\nmsgid "Hello"\nmsgstr "Privet"\n\n#, fuzzy\nmsgid "Maybe"\nmsgstr "Mozhet"\n\n'
        .. 'msgctxt "verb"\nmsgid "Open"\nmsgstr "Otkryt"\n\nmsgid "%d book"\nmsgid_plural "%d books"\nmsgstr[0] "%d kniga"\nmsgstr[1] "%d knigi"\nmsgstr[2] "%d knig"\n\n'
        .. 'msgid "Line"\nmsgstr ""\n"one "\n"two\\n"\n')
    Kit.ok(#parsed.entries == 5 and parsed.entries[1].refs == "a.lua" and parsed.entries[2].flags.fuzzy, "a .po file is read: entries, references, flags")
    Kit.ok(parsed.entries[5].str[1] == "one two\n", "a string split over lines is joined, escapes undone")
    local n, rule = Po.pluralRule(parsed.header)
    Kit.ok(n == 3, "the plural rule's form count is read")
    local ru = Plural.compile(rule)
    Kit.ok(ru(1) == 0 and ru(21) == 0 and ru(2) == 1 and ru(24) == 1 and ru(5) == 2 and ru(11) == 2 and ru(12) == 2 and ru(0) == 2 and ru(100) == 2 and ru(101) == 0,
        "the Russian plural rule picks its forms")
    local pl = Plural.compile("n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2")
    Kit.ok(pl(1) == 0 and pl(3) == 1 and pl(5) == 2 and pl(22) == 1 and pl(12) == 2, "the Polish rule works")
    local fr = Plural.compile("n > 1")
    Kit.ok(fr(0) == 0 and fr(1) == 0 and fr(2) == 1, "the French rule counts 0 and 1 alike")
    Kit.ok(Plural.compile("os.execute('x')")(1) == 0 and Plural.compile("n != 1")(1) == 0, "an expression with anything but arithmetic is not run")

    Kit.ok(Case.upper("istanbul", "tr") == "İSTANBUL" and Case.upper("ığdır", "tr") == "IĞDIR", "Turkish capitals: i becomes İ, ı becomes I")
    Kit.ok(Case.upper("straße") == "STRASSE" and Case.upper("élève") == "ÉLÈVE", "German and French capitals")
    Kit.ok(Case.upper("άνθρωπος", "el") == "ΑΝΘΡΩΠΟΣ" and Case.upper("ΣΤΑΤΙΣΤΙΚΆ", "el") == "ΣΤΑΤΙΣΤΙΚΑ", "Greek capitals carry no accent")
    Kit.ok(Case.upper("привет") == "ПРИВЕТ" and Case.upper("łódź") == "ŁÓDŹ", "Cyrillic and Polish capitals")
    Kit.ok(Format.chars("Мар", 1) == "М" and Format.chars("Ocak", 2) == "Oc", "the first characters are whole characters")

    local dir = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-l10n"
    os.execute("rm -rf '" .. dir .. "'; mkdir -p '" .. dir .. "/zz'")
    local f = io.open(dir .. "/zz/cyberui.po", "w")
    f:write('msgid ""\nmsgstr ""\n"Plural-Forms: nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);\\n"\n\n'
        .. 'msgid "Hello"\nmsgstr "Privet"\n\nmsgctxt "verb"\nmsgid "Open"\nmsgstr "Otkryt"\n\n#, fuzzy\nmsgid "Maybe"\nmsgstr "Mozhet"\n\n'
        .. 'msgid "%d book"\nmsgid_plural "%d books"\nmsgstr[0] "%d kniga"\nmsgstr[1] "%d knigi"\nmsgstr[2] "%d knig"\n')
    f:close()
    I18n.root = dir
    Kit.ok(I18n.use("zz_ZZ") == "zz", "a regional code finds its language's folder")
    Kit.ok(I18n("Hello") == "Privet" and I18n("Nothing here") == "Nothing here", "a translated text, and the English for one that is not")
    Kit.ok(I18n("Maybe") == "Maybe", "a fuzzy translation is not used")
    Kit.ok(I18n.c("verb", "Open") == "Otkryt" and I18n.c("noun", "Open") == "Open", "a context tells two meanings apart")
    Kit.ok(I18n.n("%d book", "%d books", 1) == "%d kniga" and I18n.n("%d book", "%d books", 3) == "%d knigi" and I18n.n("%d book", "%d books", 7) == "%d knig",
        "a count picks its plural form")
    Kit.ok(I18n.n("%d file", "%d files", 1) == "%d file" and I18n.n("%d file", "%d files", 2) == "%d files", "an untranslated count is English")
    local cache = require("datastorage"):getSettingsDir() .. "/cyberui-l10n-zz.lua"
    Kit.ok(io.open(cache, "r") ~= nil, "the language is kept compiled for the next start")
    os.remove(dir .. "/zz/cyberui.po")
    local g = io.open(dir .. "/zz/cyberui.po", "w")
    g:write('msgid ""\nmsgstr ""\n\nmsgid "Hello"\nmsgstr "Zdravo"\n')
    g:close()
    Kit.ok(I18n.use("zz") == "zz" and I18n("Hello") == "Zdravo", "an edited .po is read again, not the old compiled copy")
    local user = require("datastorage"):getSettingsDir() .. "/cyberui-l10n"
    os.execute("mkdir -p '" .. user .. "'")
    local h = io.open(user .. "/zz.po", "w")
    h:write('msgid ""\nmsgstr ""\n\nmsgid "Hello"\nmsgstr "Mine"\n')
    h:close()
    I18n.use("zz")
    Kit.ok(I18n("Hello") == "Mine", "a reader's own .po wins over the shipped one")
    os.remove(user .. "/zz.po")
    os.remove(cache)
    I18n.use("de_XX")
    Kit.ok(I18n.language() == "en" and I18n("Anything") == "Anything", "a language with no file is English")
    I18n.use("en_XA")
    Kit.ok(I18n("Hello %d") == "[Héllô %d~~]" or I18n("Hello %d"):find("^%[") ~= nil, "the pseudo-language marks texts and keeps placeholders")
    Kit.ok(I18n("Hello %d"):find("%%d") ~= nil, "and keeps the placeholder")
    I18n.use(nil)
    I18n.root = nil
    os.execute("rm -rf '" .. dir .. "'")

    -- the shipped languages: each loads, translates and counts the way its language does
    I18n.root = nil
    local lfs = require("libs/libkoreader-lfs")
    local shipped = 0
    for name in lfs.dir(I18n.dir()) do
        if name:match("^%a%a") and lfs.attributes(I18n.dir() .. "/" .. name, "mode") == "directory" then
            shipped = shipped + 1
            I18n.use(name)
            Kit.ok(I18n.language() == name and I18n("Install") ~= "Install" or name == "tr" or name == "de",
                name .. " loads and translates")
        end
    end
    Kit.ok(shipped >= 10, "ten languages are shipped (" .. shipped .. ")")
    I18n.use("ru")
    Kit.ok(I18n.n("%d BOOK", "%d BOOKS", 1) == "%d КНИГА" and I18n.n("%d BOOK", "%d BOOKS", 21) == "%d КНИГА" and I18n.n("%d BOOK", "%d BOOKS", 3) == "%d КНИГИ"
        and I18n.n("%d BOOK", "%d BOOKS", 5) == "%d КНИГ" and I18n.n("%d BOOK", "%d BOOKS", 11) == "%d КНИГ", "Russian counts books in three forms")
    I18n.use("pl")
    Kit.ok(I18n.n("%d BOOK", "%d BOOKS", 1) == "%d KSIĄŻKA" and I18n.n("%d BOOK", "%d BOOKS", 2) == "%d KSIĄŻKI" and I18n.n("%d BOOK", "%d BOOKS", 5) == "%d KSIĄŻEK",
        "Polish counts books in three forms")
    I18n.use("fr")
    Kit.ok(I18n.n("%d BOOK", "%d BOOKS", 0) == "%d LIVRE" and I18n.n("%d BOOK", "%d BOOKS", 2) == "%d LIVRES", "French counts 0 as one")
    I18n.use("pt_BR")
    Kit.ok(I18n.n("%d BOOK", "%d BOOKS", 0) == "%d LIVRO", "Brazilian Portuguese counts 0 as one")
    I18n.use("pt_PT")
    Kit.ok(I18n.n("%d BOOK", "%d BOOKS", 0) == "%d LIVROS", "Portuguese from Portugal counts 0 as many")
    I18n.use("tr")
    local Format = require("cyberui/format")
    Kit.ok(Format.upper("kitaplık") == "KİTAPLIK", "Turkish capitals through the format helper")
    I18n.use(nil)
end

-- the folder picker with nothing being moved (the stats scope, the library start, moving books)
do
    local Library = require("cyberui/screens/library")
    local ok, err = pcall(function()
        local s = Library:new({ dir = require("cyberui/data/library").home(), pick = { title = "Pick", on_pick = function() end } })
        s:build({ w = Kit.Screen:getWidth(), h = Kit.Screen:getHeight() })
    end)
    Kit.ok(ok, "the folder picker builds without a folder being moved: " .. tostring(err))
end

-- a colour cover drawn in night mode onto a screen of another pixel type (the C
-- blitter would end KOReader)
do
    local Blitbuffer = require("ffi/blitbuffer")
    local Covers = require("cyberui/data/covers")
    local Theme = require("cyberui/theme")
    local Cover = require("cyberui/ui/cover")
    local get, night, style = Covers.get, Theme.nightMode, Settings.get("cover_style")
    local img = Blitbuffer.new(40, 60, Blitbuffer.TYPE_BBRGB24)
    img:fill(Blitbuffer.ColorRGB24(200, 40, 40))
    Covers.get = function() return img end
    Theme.nightMode = function() return true end
    Settings.set("cover_style", "image")
    local bb = Blitbuffer.new(100, 100, Blitbuffer.TYPE_BBRGB32)
    local c = Cover:new({ w = 44, h = 64, path = "/x/book.epub" })
    Kit.ok(pcall(c.drawFace, c, bb, 10, 10), "a colour cover is drawn inverted onto a screen of another pixel type")
    bb:free(); img:free()
    Covers.get, Theme.nightMode = get, night
    Settings.set("cover_style", style)
end

-- the library walk skips linked folders and Android's data folder
do
    local Library = require("cyberui/data/library")
    local lfs = require("libs/libkoreader-lfs")
    local root = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-walk"
    os.execute("rm -rf '" .. root .. "'; mkdir -p '" .. root .. "/a' '" .. root .. "/Android/data'")
    for _, f in ipairs({ "/a/one.epub", "/Android/data/hidden.epub" }) do io.open(root .. f, "w"):close() end
    os.execute("ln -s '" .. root .. "' '" .. root .. "/a/loop'")
    local home = G_reader_settings:readSetting("home_dir")
    G_reader_settings:saveSetting("home_dir", root)
    Library.reset()
    local walked = Library.all()
    Kit.ok(#walked == 1 and walked[1] == root .. "/a/one.epub", "a link back up is not followed and Android's data folder is skipped")
    G_reader_settings:saveSetting("home_dir", home)
    Library.reset()
    os.execute("rm -rf '" .. root .. "'")
end

-- the keyboard: accented letters and Shift on both letter layers, a second tap locks it
do
    local Keyboard = require("cyberui/ui/keyboard")
    local TextInput = require("cyberui/ui/textinput")
    Kit.ok(TextInput.nextShift(false) == "once" and TextInput.nextShift("once") == "lock" and TextInput.nextShift("lock") == false,
        "Shift goes off, one letter, locked, off")
    local function labels(o)
        local out = {}
        local function walk(e)
            if e.label then out[e.label] = true end
            for _i, c in ipairs(e.children or {}) do walk(c) end
        end
        walk(Keyboard.build(o))
        return out
    end
    local noop = function() end
    local function with(extra) local o = { on_char = noop, on_back = noop, on_enter = noop, on_layer = noop, on_shift = noop }; for k, v in pairs(extra) do o[k] = v end; return o end
    local acc = labels(with({ layer = "acc" }))
    for _i, ch in ipairs({ "á", "ã", "à", "â", "ê", "õ", "ç", "ñ", "ü", "ł" }) do
        Kit.ok(acc[ch], "the accented layer has " .. ch)
    end
    Kit.ok(acc["⇧"], "the accented layer has a Shift key")
    local caps = labels(with({ layer = "acc", shift = "once" }))
    Kit.ok(caps["Á"] and caps["Ã"] and not caps["á"], "Shift makes the accented letters capitals")
    Kit.ok(labels(with({ layer = "abc", shift = "lock" }))["⇧⇧"], "a locked Shift looks different")
    Kit.ok(not labels(with({ layer = "num" }))["⇧"], "the numbers have no Shift")
end

-- renaming a collection keeps its books and the places that name it
do
    local Collections = require("cyberui/data/collections")
    local ReadCollection = require("readcollection")
    Collections.create("Fantasia")
    Collections.create("Clássicos")
    Settings.set("library_extra", { collection = "Fantasia" })
    Settings.set("library_views", { { name = "v", extra = { collection = "Fantasia" } } })
    local ok = Collections.rename("Fantasia", "  Fantasy  ")
    Kit.ok(ok and ReadCollection.coll["Fantasy"] and not ReadCollection.coll["Fantasia"], "a collection is renamed (the name is trimmed)")
    Kit.ok(Settings.get("library_extra").collection == "Fantasy" and Settings.get("library_views")[1].extra.collection == "Fantasy",
        "the saved filter and views follow the new name")
    local _ok, why = Collections.rename("Fantasy", "Clássicos")
    Kit.ok(not _ok and why == "exists", "a name already used is refused")
    _ok, why = Collections.rename("Fantasy", "   ")
    Kit.ok(not _ok and why == "empty", "an empty name is refused")
    _ok, why = Collections.rename(ReadCollection.default_collection_name, "Mine")
    Kit.ok(not _ok and why == "favorites", "Favorites keeps its name")
    Collections.remove("Fantasy")
    Collections.remove("Clássicos")
    Settings.set("library_extra", nil)
    Settings.set("library_views", nil)
end

-- editing a book's details: written as custom metadata, laid over the book's own, taken back by saving empty
do
    local Books = require("cyberui/data/books")
    local Metadata = require("cyberui/data/metadata")
    local Groups = require("cyberui/data/libgroups")
    local Library = require("cyberui/data/library")
    local root = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-meta"
    os.execute("rm -rf '" .. root .. "'; mkdir -p '" .. root .. "'")
    local a, b, c = root .. "/a.epub", root .. "/b.epub", root .. "/c.pdf"
    for _, f in ipairs({ a, b, c }) do io.open(f, "w"):close() end
    local home = G_reader_settings:readSetting("home_dir")
    G_reader_settings:saveSetting("home_dir", root)
    Library.reset()

    Kit.ok(table.concat(Books.genres("Fantasia\nAventura;  fantasia ;\n"), "|") == "Fantasia|Aventura", "genres split on lines and semicolons, once each")
    Kit.ok(Metadata.parse("keywords", " Fantasia ; Épico\n") == "Fantasia\nÉpico", "several values are kept one per line")
    Kit.ok(Metadata.parse("title", "   ") == nil, "an empty text takes a change back")
    Kit.ok(Metadata.parse("series_index", "4") == "4" and Metadata.parse("series_index", "2,5") == "2.5", "a series number is kept plain")
    local _n, why = Metadata.parse("series_index", "four")
    Kit.ok(_n == nil and why == "number", "a series number that is not a number is refused")
    Kit.ok(Metadata.show("keywords", "Fantasia\nÉpico") == "Fantasia; Épico", "genres read side by side")

    Kit.ok(Metadata.set(a, "title", "O Senhor dos Anéis"), "a title is saved")
    Kit.ok(Books.info(a).title == "O Senhor dos Anéis" and Metadata.changed(a, "title"), "the book shows the new title at once")
    Metadata.set(a, "keywords", "Fantasia\nÉpico")
    Metadata.set(a, "series", "A Roda do Tempo")
    Metadata.set(a, "series_index", "4")
    Metadata.set(a, "authors", "J.R.R. Tolkien\nChristopher Tolkien")
    local info = Books.info(a)
    Kit.ok(info.author == "J.R.R. Tolkien" and info.series == "A Roda do Tempo" and info.series_index == 4, "authors, series and number follow")
    Kit.ok(#info.genres == 2 and info.genres[2] == "Épico", "genres follow")
    local lfs = require("libs/libkoreader-lfs")
    Kit.ok(lfs.attributes(root .. "/a.sdr/custom_metadata.lua", "mode") == "file", "KOReader's own custom metadata file is written")
    Kit.ok(Books.info(b).title == "b" and not Metadata.changed(b), "other books are left alone")

    -- genres group a book under each of its genres, books without one under "No genre"
    Metadata.set(b, "keywords", "fantasia")
    local names = {}
    for _i, g in ipairs(Groups.list("genre")) do names[g.name .. "=" .. g.count] = true end
    Kit.ok(names["Fantasia=2"] and names["Épico=1"] and names["No genre=1"], "the Genre grouping counts each genre (case ignored) and the books with none")
    Kit.ok(#Groups.books("genre", "fantasia") == 2 and #Groups.books("genre", "~") == 1, "and lists the books of one")
    Kit.ok(Groups.KINDS[5] and Groups.KINDS[5][1] == "genre", "Genre is among the groupings")

    -- saving a detail empty brings the book's own back; the file goes when nothing is left
    Metadata.set(a, "title", nil)
    Kit.ok(Books.info(a).title == "a" and not Metadata.changed(a, "title") and Metadata.changed(a, "series"), "one detail goes back to the book's own")
    Metadata.reset(a)
    Kit.ok(not Metadata.changed(a) and lfs.attributes(root .. "/a.sdr/custom_metadata.lua", "mode") == nil, "resetting all removes the file")
    Metadata.set(b, "keywords", nil)
    Kit.ok(lfs.attributes(root .. "/b.sdr", "mode") == nil, "and the empty .sdr folder")

    G_reader_settings:saveSetting("home_dir", home)
    Library.reset()
    os.execute("rm -rf '" .. root .. "'")
end

-- text cut inside a character, stacking of unskinned windows, the highlight menu with no book open
do
    local Utf8Safe = require("cyberui/utf8safe")
    local han = string.rep("\u{6B63}", 300)   -- 900 bytes of 3-byte characters
    for _, n in ipairs({ 399, 400, 401 }) do
        local c = Utf8Safe.clip(han, n, "...")
        local body = c:sub(1, -4)
        Kit.ok(#body <= n and #body % 3 == 0 and Utf8Safe.clean(c) == c, "a cut of " .. n .. " bytes ends on a whole character")
    end
    Kit.ok(Utf8Safe.clean("He doesn\xE2") == "He doesn" and Utf8Safe.clean("ok \u{2019} \u{6B63}") == "ok \u{2019} \u{6B63}", "a stray lead byte is dropped, whole characters stay")
    Kit.ok(Utf8Safe.clip("short", 90, "...") == "short", "short text is not touched")

    local Text = require("cyberui/gfx/text")
    local bb = Kit.canvas()
    Text.draw(bb, 0, 0, "body", "He doesn\xE2")
    Kit.ok(Text.width("body", "He doesn\xE2") == Text.width("body", "He doesn"), "text cut in a character is drawn and measured without it")
    bb:free()

    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-cut"
    os.execute("rm -rf '" .. tmp .. "'; mkdir -p '" .. tmp .. "'")
    local Shards = require("cyberui/data/shards")
    Shards.reset()
    Shards.file = tmp .. "/shards.lua"
    local book = tmp .. "/Han.epub"
    io.open(book, "w"):close()
    local ds = require("docsettings"):open(book)
    ds:saveSetting("annotations", { { text = han, datetime = "2026-11-01 10:00:00", page = 1 } })
    ds:flush()
    local made = Shards.of(book)[1].text
    Kit.ok(Utf8Safe.clean(made) == made and #made <= 403, "a long highlight in Chinese is kept as valid text")
    -- an index an older version saved with a cut character is mended when it is read
    local LuaSettings = require("luasettings")
    local old = LuaSettings:open(Shards.file)
    old:saveSetting("books", { [book] = { stamp = 1, list = { { id = "0000000A", text = "He doesn\xE2...", path = book } } } })
    old:flush()
    Shards.reset()
    Shards.file = tmp .. "/shards.lua"
    Kit.ok(Shards.ofBook(book)[1].text == "He doesn...", "a saved shard with a cut character is mended")
    Shards.reset()
    Shards.file = nil
    os.execute("rm -rf '" .. tmp .. "'")

    -- the highlight menu asks nothing of a reader that is not there
    package.loaded["apps/reader/readerui"] = true
    local HM = require("cyberui/skin/highlightmenu")
    Kit.ok(HM.isHighlightDialog({}) == false, "no book open: no widget is the highlight menu")
    package.loaded["apps/reader/readerui"] = { instance = { highlight = false } }
    Kit.ok(HM.isHighlightDialog({}) == false and HM.selection().text == nil, "a reader with no highlight module is no error")
    package.loaded["apps/reader/readerui"] = nil

    -- a window no skin took still opens in front of a CyberUI popup
    local UIManager = require("ui/uimanager")
    local Core = require("cyberui/skin/core")
    Core.install()
    local Popup = require("cyberui/popup")
    local El = require("cyberui/ui/panel")
    local Label = require("cyberui/ui/label")
    local pop = Popup:new({ element = El:new({ shape = "none", width = 100, child = Label:new({ text = "x", kind = "body" }) }) })
    UIManager:show(pop)
    local plain = require("ui/widget/container/widgetcontainer"):new({ name = "plain_dialog" })
    UIManager:show(plain)
    local order = {}
    for i, w in ipairs(UIManager._window_stack) do order[w.widget] = i end
    Kit.ok(order[plain] and order[pop] and order[plain] > order[pop], "a window shown over a popup is above it")
    UIManager:close(plain)
    UIManager:close(pop)
end

-- shortening text to fit: the one pass gives what measuring each prefix gave
do
    local Text = require("cyberui/gfx/text")
    local ELL = "…"
    local function slow(kind, s, max_w)
        s = Text.shown(kind, s)
        if Text.width(kind, s) <= max_w then return s end
        local cps = Text.codepoints(s)
        local function prefix(n) local c = {} for i = 1, n do c[i] = cps[i] end return Text.fromCodepoints(c) end
        local lo, hi = 0, #cps
        while lo < hi do
            local mid = math.ceil((lo + hi) / 2)
            if Text.width(kind, prefix(mid) .. ELL) <= max_w then lo = mid else hi = mid - 1 end
        end
        return (prefix(lo):gsub("%s+$", "")) .. ELL
    end
    math.randomseed(3)
    local words = { "The", "Brothers", "Karamazov", "Ağaç", "İstanbul", "日本語", "WAVE", "AV", "To", "ë", " " }
    local differ = 0
    for _, kind in ipairs({ "label", "micro", "mono" }) do
        for _t = 1, 80 do
            local parts = {}
            for k = 1, math.random(1, 8) do parts[k] = words[math.random(#words)] end
            local s, w = table.concat(parts, " "), math.random(10, 300)
            if slow(kind, s, w) ~= Text.fit(kind, s, w) then differ = differ + 1 end
        end
    end
    Kit.ok(differ == 0, "text shortened in one pass matches measuring each prefix (" .. differ .. " differ)")

    -- wrapped titles are kept, and match wrapping afresh
    local samples, kept_lines = {}, {}
    for t = 1, 60 do
        local parts = {}
        for k = 1, math.random(1, 12) do parts[k] = words[math.random(#words)] end
        samples[t] = { table.concat(parts, " "), math.random(30, 260), math.random(1, 3) }
        kept_lines[t] = table.concat(Text.wrap("label", samples[t][1], samples[t][2], samples[t][3]), "\n")
    end
    Text.reset()
    local wrap_same = true
    for t, sm in ipairs(samples) do
        if table.concat(Text.wrap("label", sm[1], sm[2], sm[3]), "\n") ~= kept_lines[t] then wrap_same = false end
        if table.concat(Text.wrap("label", sm[1], sm[2], sm[3]), "\n") ~= kept_lines[t] then wrap_same = false end
    end
    Kit.ok(wrap_same, "wrapped text asked again matches wrapping afresh")

    -- shown forms and UTF-8 checks are kept, and stay right
    local Utf8Safe = require("cyberui/utf8safe")
    local broken = "Caf\195"
    Kit.ok(Utf8Safe.clean(broken) == "Caf" and Utf8Safe.clean(broken) == "Caf", "a cut character is dropped, the second time too")
    Kit.ok(Utf8Safe.clean("plain") == "plain" and Utf8Safe.clean(nil) == nil, "plain text and no text pass as they are")
    local I18n = require("cyberui/gettext")
    local caps_kind
    for _, kind in ipairs({ "micro", "label", "title", "display", "mono_small", "body" }) do
        if require("cyberui/theme").text(kind).caps then caps_kind = kind; break end
    end
    if caps_kind then
        local was = I18n.language()
        local en = Text.shown(caps_kind, "istanbul")
        I18n.use("tr")
        local tr = Text.shown(caps_kind, "istanbul")
        I18n.use(was)
        Kit.ok(en == "ISTANBUL" and tr == "\196\176STANBUL" and Text.shown(caps_kind, "istanbul") == en,
            "capitals follow the language even for text shown before: " .. tostring(en) .. " / " .. tostring(tr))
    end
end

-- a page turn paints only the grid, the page number and a pressed button, and
-- the screen comes out exactly as a full paint of the new page
do
    local ffi = require("ffi")
    local Host = require("cyberui/host")
    local Grid = require("cyberui/ui/grid")
    local Cover = require("cyberui/ui/cover")
    local Frame = require("cyberui/screens/frame")
    local Layout = require("cyberui/ui/layout")
    local DeviceInfo = require("cyberui/data/device")
    local clock = DeviceInfo.clock
    DeviceInfo.clock = function() return "12:00" end   -- (the same minute for both paints)
    local state = { page = 1 }
    local items = {}
    for i = 1, 40 do items[i] = { title = "Book number " .. i, author = "Author " .. i } end
    local function tree()
        return Frame.page({ screen = state, title = "PAGES", body = Layout.Column:new({ children = {
            Grid:new({ grow = true, items = items, page = state.page, paged = true, min_cell_w = Theme.px(120), ratio = 1.72,
                make = function(item, w, h) return Cover:new({ title = item.title, author = item.author, width = w, height = h }) end,
                on_layout = function(_cap, pages, page) state.pages, state.page = pages, page end }),
            Frame.pager(state, "SECTOR", function() end),
        } }) })
    end
    local function bytes(bb) return ffi.string(bb.data, bb.stride * bb:getHeight()) end
    local host = Host:new({})
    host:setRoot(tree())
    local turned, full = Kit.canvas(), Kit.canvas()
    host:paintAll(turned, 0, 0)
    local pressed
    for _, el in ipairs(host.root.children[2].children[1].children[2].children) do pressed = pressed or (el.on_tap and el) end
    state.page = 2
    local old = host.root
    host:setRoot(tree())
    local box = { x = pressed.x, y = pressed.y, w = pressed.w, h = pressed.h }
    local parts = Host.carry(old, host.root, box, {})
    Kit.ok(parts and #parts == 3, "a page turn repaints the grid, the page number and the pressed button: " .. tostring(parts and #parts))
    turned:invertRect(box.x, box.y, box.w, box.h)   -- (the press shows the button inverted)
    host.parts = parts
    host:paintAll(turned, 0, 0)
    Kit.ok(host.parts == nil, "the parts are painted once")
    host:paintAll(full, 0, 0)
    Kit.ok(bytes(turned) == bytes(full), "the turned page is pixel for pixel the full paint of it")
    local hit = host.root:hit(box.x + 1, box.y + 1, "on_tap")
    Kit.ok(hit ~= nil, "elements not painted again still answer taps where they are")
    state.page = 3
    local before = host.root
    host:setRoot(tree())
    local wide = Layout.Column:new({ children = {} })
    wide.x, wide.w, wide.h = 0, 1, 1
    Kit.ok(Host.carry(before, wide, nil, {}) == nil, "a tree of another shape is painted whole")
    turned:free(); full:free()
    DeviceInfo.clock = clock
end

-- compiled copies of modules: made at the first load, used while the source
-- stays as it was, made again when it changes (last here: the loader stays in)
do
    local BcCache = require("cyberui/bccache")
    local lfs = require("libs/libkoreader-lfs")
    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-test-bc"
    os.execute("rm -rf '" .. tmp .. "'; mkdir -p '" .. tmp .. "/root/cyberui'")
    local src = tmp .. "/root/cyberui/bctest.lua"
    local function write(v, t)
        local f = io.open(src, "w")
        f:write("return { v = " .. v .. " }\n")
        f:close()
        lfs.touch(src, t, t)
    end
    write(1, 1000000)
    BcCache.install(tmp .. "/root", tmp .. "/cache")
    local m = require("cyberui/bctest")
    Kit.ok(m.v == 1, "a module loads through the cache")
    local copy = tmp .. "/cache/cyberui~bctest.bc"
    Kit.ok(lfs.attributes(copy, "mode") == "file", "its compiled copy is kept")
    local f = io.open(copy, "rb")
    local stamp = f:read("*l")
    f:close()
    f = io.open(copy, "wb")
    f:write(stamp, "\n", string.dump(loadstring("return { v = 2, where = debug.getinfo(1, 'S').source }", "@" .. src)))
    f:close()
    package.loaded["cyberui/bctest"] = nil
    m = require("cyberui/bctest")
    Kit.ok(m.v == 2, "the copy is what loads while the source is unchanged")
    Kit.ok(m.where == "@" .. src, "a module from its copy still knows its source file (paths.lua relies on it)")
    write(33, 2000000)
    package.loaded["cyberui/bctest"] = nil
    Kit.ok(require("cyberui/bctest").v == 33, "a changed source is read again")
    f = io.open(copy, "wb")
    f:write("not bytecode")
    f:close()
    package.loaded["cyberui/bctest"] = nil
    Kit.ok(require("cyberui/bctest").v == 33, "a broken copy falls back to the source")
    package.loaded["cyberui/bctest"] = nil

    -- the start's modules are packed together, and the next start loads them from the pack
    BcCache.packStart()
    local pf = io.open(tmp .. "/cache/start.pack", "rb")
    local packed = pf and pf:read("*a") or ""
    if pf then pf:close() end
    Kit.ok(packed:find("cyberui/bctest", 1, true) ~= nil, "the modules a start loaded are packed")
    local t = lfs.attributes(src, "modification")
    f = io.open(src, "w")
    f:write("return { v = 44 }\n")   -- (same size and age: the stamp still matches)
    f:close()
    lfs.touch(src, t, t)
    f = io.open(copy, "wb")
    f:write("broken")
    f:close()
    local Next = dofile(REPO .. "/cyberui/bccache.lua")   -- the next start
    Next.install(tmp .. "/root", tmp .. "/cache")
    Kit.ok(require("cyberui/bctest").v == 33, "the next start loads the module from the pack")
    package.loaded["cyberui/bctest"] = nil
    write(55, 3000000)
    Kit.ok(require("cyberui/bctest").v == 55, "a module changed since it was packed is read from its source")
    package.loaded["cyberui/bctest"] = nil
    table.remove(package.loaders, 2)
end

-- home asked for again: the same build paints nothing, a changed one does
do
    local Same = require("cyberui/same")
    local Host = require("cyberui/host")
    local Settings = require("cyberui/settings")
    local Home = require("cyberui/screens/home")
    local W, H = Kit.Screen:getWidth(), Kit.Screen:getHeight()
    local home = Home:new({})
    local function built()
        local root = home:build({ w = W, h = H })
        root:layout(W, H)
        return root, Same.state()
    end
    local a, sa = built()
    local bb = Kit.canvas()
    a:paint(bb, 0, 0)
    bb:free()
    local b, sb = built()
    Kit.ok(Same.trees(a, sa, b, sb), "home built again the same paints the same")
    local function firstLabel(el)
        if el.text and el.kind then return el end
        for _, c in ipairs(el.children or {}) do
            local f = firstLabel(c)
            if f then return f end
        end
        return el.child and firstLabel(el.child)
    end
    local la, lb = firstLabel(a), firstLabel(b)
    Kit.ok(la and lb and la ~= lb, "both builds have a label")
    local keep = lb.text
    lb.text = keep .. "!"
    Kit.ok(not Same.trees(a, sa, b, sb), "a changed text does not")
    lb.text = keep
    lb.extra = true
    Kit.ok(not Same.trees(a, sa, b, sb), "nor a value only the new build has")
    lb.extra = nil
    Settings.set("home_test_change", true)
    local c, sc = built()
    Kit.ok(not Same.trees(a, sa, c, sc), "nor a build after a setting changed")
    Settings.set("home_test_change", nil)
    Host.place(a, b)
    Kit.ok(lb.x == la.x and lb.y == la.y and lb.x ~= nil, "the new tree takes the places the old one was painted at")
    local Progress = require("cyberui/ui/progress")
    local p = Progress:new({ value = 0.5 })
    p:layout(100, nil)
    local pb = Kit.canvas(200, 50)
    p:paint(pb, 0, 0)
    pb:free()
    Kit.ok(rawget(p, "v") == nil, "painting a bar leaves nothing on it but its place")
end

Kit.finish("features")
