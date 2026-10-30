-- A seamless reload of the open book (KOReader does it after a layout change):
-- home must not paint while it happens, with the book opened straight over
-- home and with it brought back from parking. Needs setup_home.py.
local H = ...
local Settings = require("cyberui/settings")
local Host = require("cyberui/host")
local ReaderUI = require("apps/reader/readerui")
local lfs = require("libs/libkoreader-lfs")

local A
local painted = 0
local real = Host.paintTo
Host.paintTo = function(self, bb, x, y)
    if not self.invisible then painted = painted + 1 end
    return real(self, bb, x, y)
end
local function app() return H.app() end

local function reload()
    painted = 0
    ReaderUI.instance:reloadDocument(nil, true)
end

H.step(5, function()
    local dir = G_reader_settings:readSetting("home_dir")
    local books = {}
    for f in lfs.dir(dir) do if f:match("%.epub$") then books[#books + 1] = dir .. "/" .. f end end
    table.sort(books)
    A = books[1]
    Settings.set("park_reader", false)
    app().openBook(A)
end)
H.step(6, function()
    H.check(ReaderUI.instance ~= nil, "the book opened over home")
    reload()
end)
H.step(7, function()
    H.check(ReaderUI.instance ~= nil, "the book is open again after the reload")
    H.check(painted == 0, "home did not paint during the reload (no parking): " .. painted .. " paints")
    H.event("CyberUIHome")
end)
H.step(4, function()
    H.check(ReaderUI.instance == nil, "home from the book closed it (parking off)")
    Settings.set("park_reader", true)
    app().openBook(A)
end)
H.step(6, function()
    H.event("CyberUIHome")
end)
H.step(3, function()
    H.check(require("cyberui/park").isParked(), "the book is parked under home")
    app().openBook(A)   -- the same book comes back, nothing loaded
end)
H.step(3, function()
    H.check(ReaderUI.instance ~= nil and not require("cyberui/park").isParked(), "the parked book came back")
    reload()
end)
H.step(7, function()
    H.check(ReaderUI.instance ~= nil, "the book is open again after the second reload")
    H.check(painted == 0, "home did not paint during the reload of a book brought back from parking: " .. painted .. " paints")
end)
