-- The board of gigs on screen: a few books from the library, the note and the
-- days to the next draw, and rolling one for eddies from the hold sheet.
-- Run: E2E_NO_DIR=1 HOME_SETUP=tests/e2e/setup_home.py tests/e2e/run.sh tests/e2e/board.lua <out>
local H = ...
local Gigs = require("cyberui/data/gigs")
local Ledger = require("cyberui/data/ledger")
local Settings = require("cyberui/settings")
local lfs = require("libs/libkoreader-lfs")

local first
H.step(3, function()
    local dir = G_reader_settings:readSetting("home_dir")
    local old = os.time() - 30 * 86400
    local n = 0
    for f in lfs.dir(dir) do
        if f:match("%.epub$") then lfs.touch(dir .. "/" .. f, old, old); n = n + 1 end
    end
    H.check(n >= 4, "the library has books to draw from: " .. n)
    Settings.set("gigs", nil)
    Settings.set("gig_slots", 3)
    Gigs.reload()
    require("cyberui/data/library").reset()
    Ledger.reload()
    Ledger.add("m", "/earned", 1, 100)
    Ledger.save()
    H.app().push("gigs")
end)
H.step(2, function()
    local board = Gigs.board()
    H.check(#board == 3, "three slots are filled")
    first = board[1].path
    H.check(H.find("NEW BOARD IN 7 DAYS") ~= nil, "the screen says when the board is drawn anew")
    H.shot("board-1")
    local top = H.find("TAKE GIG")
    H.check(top ~= nil, "the top gig has its button")
    H.holdAt(top.x - 120, top.y)
end)
H.step(2, function()
    H.check(H.find("Roll") ~= nil, "holding a gig offers a roll")
    H.shot("board-2-sheet")
    H.tap("Roll")
end)
H.step(2, function()
    H.check(Ledger.balance() == 80, "the roll cost 20 eddies: " .. Ledger.balance())
    H.check(not Gigs.offer(first) and #Gigs.board() == 3, "the book was swapped for another")
    H.shot("board-3-rolled")
    Settings.set("gigs", nil)
    Settings.set("gig_slots", nil)
end)
