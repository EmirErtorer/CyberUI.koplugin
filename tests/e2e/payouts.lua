-- What reading pays, interval by interval, for a gig and for a book at the plain rate:
-- a little reading pays nothing; each tenth of the book pays one milestone once the book is
-- left for home; finishing pays the rest. A screenshot of home after each exit.
-- Run: E2E_NO_DIR=1 HOME_SETUP=tests/e2e/setup_home.py TIMEOUT=1500 tests/e2e/run.sh tests/e2e/payouts.lua <out>
local H = ...
local Gigs = require("cyberui/data/gigs")
local Ledger = require("cyberui/data/ledger")
local Settings = require("cyberui/settings")
local lfs = require("libs/libkoreader-lfs")

local app = H.app
-- pages are read at twenty seconds apiece, as a reader would (a page must stay on screen to count)
local now = os.time()
Gigs.clock = function() now = now + 20; return now end
local books = {}
local pos = {}   -- the last page read of each book

-- Show pages `from` to `to` of the open book one by one, as a reader turning them.
local function read(from, to)
    local ui = require("apps/reader/readerui").instance
    local Event = require("ui/event")
    for p = from, to do ui:handleEvent(Event:new("GotoPage", p)) end
end

-- The toast on home, as the text it was made with (it sits outside the tree the driver walks).
local shown
local Dialog = require("cyberui/ui/dialog")
local toast = Dialog.toast
Dialog.toast = function(text) shown = text; return toast(text) end

H.step(2, function()
    local dir = G_reader_settings:readSetting("home_dir")
    local list = {}
    for f in lfs.dir(dir) do if f:match("%.epub$") then list[#list + 1] = dir .. "/" .. f end end
    table.sort(list)
    books.gig, books.plain = list[1], list[2]
    local old = os.time() - 90 * 86400
    lfs.touch(books.gig, old, old)
    -- the board holds the first book only (it is drawn at random, so it is put there)
    Settings.set("gigs", { quotes = {}, seen = {}, ledger = {}, board = { t = os.time(), slots = { books.gig } } })
    Gigs.reload()
    for _i, p in pairs(books) do require("cyberui/data/books").forget(p) end
    H.check(books.gig and books.plain, "two books to read")
end)

-- One stage of a book: open it, read up to `target` (a share of its pages), leave for home, and look at what home says.
-- k is 0 (a little: pays nothing) or 1-10 (the tenths; the last one reaches the end, so the finish pays with it).
local function stage(kind, k)
    local book = function() return books[kind] end
    local before
    H.step(1, function() before = Ledger.balance(); app().openBook(book()) end)
    H.step(3, function()
        local ui = require("apps/reader/readerui").instance
        H.check(ui ~= nil, kind .. " " .. k .. ": the book is open")
        local total = ui.document:getPageCount()
        local to = k == 0 and math.max(1, math.floor(total * 0.04)) or k <= 10 and math.ceil(total * k / 10) or total
        read((pos[kind] or 0) + 1, to)
        pos[kind] = to
        H.event("CyberUIHome")
    end)
    H.step(1.3, function()
        local q = Gigs.quote(book())
        local paid = Ledger.balance() - before
        local step = q and Gigs.milestone(q.price, k) or -1
        if k == 0 then
            H.check(paid == 0 and shown == nil, kind .. ": a few pages pay nothing (paid " .. paid .. ")")
        else
            local want = k < 10 and step or step + Gigs.finish(q.price)
            H.check(q ~= nil and paid == want, string.format("%s: tenth %d pays %s (paid %s)", kind, k, tostring(want), tostring(paid)))
            H.check(shown ~= nil, kind .. ": the notice says: " .. tostring(shown))
        end
        H.say(string.format("%s step %d: paid %s, balance %s, notice %s", kind, k, paid, Ledger.balance(), tostring(shown)))
        H.shot(string.format("%s-%02d", kind, k))
        shown = nil
    end)
end

for _i, kind in ipairs({ "gig", "plain" }) do
    for k = 0, 10 do stage(kind, k) end
end
