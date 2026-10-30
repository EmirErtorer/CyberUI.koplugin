-- Reader parking used for real: a book put away under home and brought back,
-- a different book opened over a parked one, the idle close, the menu closing
-- a parked book, and parking off closing as before. Needs setup_home.py (the
-- same EPUBs as compare.lua).
local H = ...
local UIManager = require("ui/uimanager")
local Park = require("cyberui/park")
local Settings = require("cyberui/settings")
local ReaderUI = require("apps/reader/readerui")

local A, B
local first_instance
local function app() return H.app() end
local function topName() local t = H.top(); return t and t.name end
local function inReader() local t = H.top(); return t ~= nil and t.document ~= nil and t.view ~= nil end
local function fm() return require("apps/filemanager/filemanager").instance end

H.step(4, function()
    local lfs = require("libs/libkoreader-lfs")
    local dir = G_reader_settings:readSetting("home_dir")
    local books = {}
    for f in lfs.dir(dir) do if f:match("%.epub$") then books[#books + 1] = dir .. "/" .. f end end
    table.sort(books)
    A, B = books[1], books[2]
    H.check(not Park.enabled(), "parking is off by default")
    Settings.set("park_reader", true)
    Park.IDLE_S, Park.EVERY_S = 4, 1   -- the idle close, sped up for the test
    app().openBook(A)
end)

H.step(4, function()
    H.check(inReader(), "the book opened")
    first_instance = ReaderUI.instance
    H.event("CyberUIHome")
end)
H.step(1.5, function()
    H.check(topName() == "cyberui", "home is on top at once")
    H.check(Park.isParked() and ReaderUI.instance == first_instance, "the book is parked, still open under home")
    H.check(fm() == nil, "there is no file browser while it is parked")
    H.shot("park1-home")
    app().openBook(A)
end)
H.step(1, function()
    H.check(inReader() and ReaderUI.instance == first_instance, "the same book comes back as it was, not loaded again")
    H.check(not Park.isParked(), "and is no longer parked")
    H.event("CyberUIHome")
end)
H.step(1.5, function()
    H.check(Park.isParked(), "parked again")
    app().openBook(B)
end)
H.step(4, function()
    H.check(inReader() and ReaderUI.instance ~= first_instance and ReaderUI.instance.document.file == B, "a different book opens over a parked one")
    H.check(not Park.isParked(), "the first book was closed for real")
    H.event("CyberUIHome")
end)
H.step(1.5, function()
    H.check(Park.isParked() and Park.file() == B, "the second book is parked")
end)
H.step(7, function()
    H.check(not Park.isParked() and ReaderUI.instance == nil, "left untouched, the book is closed for real")
    H.check(fm() ~= nil and topName() == "cyberui", "the file browser is back under home, which stays on top")
    app().openBook(A)
end)
H.step(4, function()
    H.event("CyberUIHome")
end)
H.step(1.5, function()
    H.check(Park.isParked(), "a book is parked again")
    app().koreaderMenu()
end)
H.step(2, function()
    H.check(not Park.isParked() and fm() ~= nil, "opening KOReader's menu closes a parked book first")
    require("cyberui/menu").current():close()
    Settings.set("park_reader", false)
    app().openBook(A)
end)
H.step(4, function()
    H.event("CyberUIHome")
end)
H.step(3, function()
    H.check(not Park.isParked() and ReaderUI.instance == nil and topName() == "cyberui", "with parking off the book closes as before")
    H.shot("park2-off")
end)
