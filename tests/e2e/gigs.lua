-- A gig used for real: an old unread book is taken from the board, read page
-- by page in the reader, the home action pays it out, and the eddies show on
-- the ID card and the Gigs screen. Needs setup_home.py (the EPUBs of compare.lua).
local H = ...
local Gigs = require("cyberui/data/gigs")
local Ledger = require("cyberui/data/ledger")
local Settings = require("cyberui/settings")
local lfs = require("libs/libkoreader-lfs")

local A
local function app() return H.app() end
local function screen() return H.app().current() end

H.step(2, function()
    local dir = G_reader_settings:readSetting("home_dir")
    local books = {}
    for f in lfs.dir(dir) do if f:match("%.epub$") then books[#books + 1] = dir .. "/" .. f end end
    table.sort(books)
    A = books[1]
    local old = os.time() - 90 * 86400
    lfs.touch(A, old, old)
    Settings.set("park_reader", false)
    Settings.set("gigs", nil)
    Gigs.reload()
    require("cyberui/data/books").forget(A)
    app().push("gigs")
end)
H.step(1, function()
    H.check(screen().id == "gigs", "the Gigs screen opens")
    H.check(H.find("HOW_GIGS_WORK") ~= nil, "it explains how gigs pay")
    H.shot("gigs1-open")
    H.check(Ledger.balance() == 0, "the balance starts at zero")
    app().openBook(A)
end)
H.step(4, function()
    local ReaderUI = require("apps/reader/readerui")
    local ui = ReaderUI.instance
    H.check(ui ~= nil and Gigs.quote(A) ~= nil, "opening the book took the gig and fixed its price")
    local total = ui.document:getPageCount()
    local Event = require("ui/event")
    for p = 1, total do ui:handleEvent(Event:new("GotoPage", p)) end
    H.event("CyberUIHome")
end)
H.step(3, function()
    local earned, done = Ledger.totals()
    H.check(Ledger.balance() == Gigs.quote(A).price and done == 1, "reading every page and leaving pays the whole price: " .. Ledger.balance())
    H.shot("gigs2-paid")
    app().push("gigs")
end)
H.step(1, function()
    H.tap("Payouts")
end)
H.step(1, function()
    H.check(H.find("GIG FINISHED") ~= nil, "the payouts tab lists the finished gig")
    H.shot("gigs3-payouts")
    app().go("home")
    require("cyberui/profileflow").card()
end)
H.step(1, function()
    H.check(H.find("EDDIES") ~= nil, "the ID card shows the eddies")
    H.shot("gigs4-idcard")
end)
