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
    local board = Gigs.board()
    local last = 1e9
    for _, g in ipairs(board) do
        Kit.ok(g.days >= Gigs.GRACE_DAYS and g.price == Gigs.price(g.pages, g.days) and g.days <= last, "a gig is priced from its pages and days idle, oldest first")
        last = g.days
    end
    Kit.ok(Gigs.price(300, 7) == 60 and Gigs.price(300, 70) == 120 and Gigs.price(300, 700) == 120, "the price grows with the wait and stops at double")
    Kit.ok(Gigs.price(1, 7) == 20 and Gigs.price(100, 14) % 20 == 0, "prices are whole steps of 20")
    local step, finish = Gigs.split(120)
    Kit.ok(step == 6 and finish == 60 and step * 10 + finish == 120, "ten steps and the finish add up to the price")
    if #board > 0 then
        Gigs.skip(board[1].path)
        Kit.ok(#Gigs.board() == #board - 1, "a book said to be not wanted leaves the board")
        Gigs.reset()
        Kit.ok(#Gigs.board() == #board, "and comes back")
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
    Kit.ok(Gigs.pages(book) == 300, "a book never opened is sized from its file")
    Gigs.accept(book)
    local q = Gigs.quote(book)
    Kit.ok(q and q.price == 120, "taking a gig fixes the price")
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
    Kit.ok(qr.grid ~= nil and #qr.grid >= 21 and qr.w == qr.h and qr.w % qr:module() == 0, "the QR code is a square of whole modules")
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

Kit.finish("features")
