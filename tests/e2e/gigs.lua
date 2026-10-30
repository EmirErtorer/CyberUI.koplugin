-- A gig used for real, with reading parked under home (the default): an old
-- unread book is taken from the dossier, read a third of the way, home pays the
-- first milestones with a notice, the book is read to the end and home pays the
-- rest and the finish, and the eddies are spent in the shop. Needs setup_home.py.
local H = ...
local Gigs = require("cyberui/data/gigs")
local Ledger = require("cyberui/data/ledger")
local Settings = require("cyberui/settings")
local Shop = require("cyberui/data/shop")
local lfs = require("libs/libkoreader-lfs")

local A, price
local function app() return H.app() end
local function screen() return H.app().current() end

-- Show pages `from` to `to` of the open book, one by one, as a reader turning them.
local function read(from, to)
    local ui = require("apps/reader/readerui").instance
    local Event = require("ui/event")
    for p = from, to do ui:handleEvent(Event:new("GotoPage", p)) end
    return ui.document:getPageCount()
end

H.step(2, function()
    local dir = G_reader_settings:readSetting("home_dir")
    local books = {}
    for f in lfs.dir(dir) do if f:match("%.epub$") then books[#books + 1] = dir .. "/" .. f end end
    table.sort(books)
    A = books[1]
    local old = os.time() - 90 * 86400
    lfs.touch(A, old, old)
    Settings.set("gigs", nil)
    Gigs.reload()
    require("cyberui/data/books").forget(A)
    H.check(require("cyberui/park").enabled(), "keeping the book open is on by default")
    app().push("dossier", { path = A })
end)
H.step(1.5, function()
    H.check(screen().id == "dossier" and H.find("TAKE GIG") ~= nil, "the dossier of a gig has a Take gig button")
    H.shot("gigs1-dossier")
    H.tap("TAKE GIG")
end)
H.step(5, function()
    local ReaderUI = require("apps/reader/readerui")
    H.check(ReaderUI.instance ~= nil and Gigs.quote(A) ~= nil, "the gig was taken and its price fixed")
    price = Gigs.quote(A).price
    local total = read(1, 1)
    read(1, math.floor(total * 0.35))
    H.event("CyberUIHome")
end)
H.step(1, function()
    local step = price / 20
    H.check(Ledger.balance() == step * 3, "a third of the way paid three milestones: " .. Ledger.balance() .. " of " .. price)
    H.check(Gigs.takeReceipt() == nil, "the notice for it was shown")
    app().go("home")
end)
H.step(0.6, function()
    H.shot("gigs2-home-notice-milestones")
    app().openBook(A)
end)
H.step(2, function()
    local total = require("apps/reader/readerui").instance.document:getPageCount()
    read(math.floor(total * 0.35), total)
    H.event("CyberUIHome")
end)
H.step(1, function()
    local _earned, done = Ledger.totals()
    H.check(Ledger.balance() == price and done == 1, "finishing paid the rest: " .. Ledger.balance())
    H.check(Gigs.takeReceipt() == nil, "the notice for the finish was shown")
    app().go("home")
end)
H.step(0.6, function()
    H.shot("gigs3-home-notice-finished")
    app().push("gigs")
end)
H.step(1, function()
    H.tap("Payouts")
end)
H.step(1, function()
    H.check(H.find("GIG FINISHED") ~= nil, "the payouts tab lists the finish")
    H.shot("gigs4-payouts")
    Ledger.add("m", "/more", 1, 300)   -- enough for a style in the shop
    Ledger.save()
    app().push("shop")
end)
H.step(1, function()
    H.tap("€$100")
end)
H.step(1, function()
    H.tap("BUY €$100")
end)
H.step(1, function()
    H.check(Shop.owned(Shop.style("frame.notch")), "the eddies bought a style")
    H.check(Ledger.balance() == price + 300 - 100, "and the price was taken: " .. Ledger.balance())
    H.shot("gigs5-shop-spent")
end)
