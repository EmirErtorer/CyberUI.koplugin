-- README animation "Home on a gesture": open a book from home (the jack-in
-- card), set a long press on the bottom right corner to CyberUI home in the
-- reader's menu, use it, then open the same book again, which is near instant
-- because the book was only put away.
--
--     CYBERUI_SHOT_BOOKS=<folder of the epubs> tools/readme/gif.sh gesture <out.gif>
--
-- The frames come from tools/readme/gif/gifkit.lua; gif.py draws the touches.
local H = ...
local repo = os.getenv("CYBERUI_REPO")
local G = dofile(repo .. "/tools/readme/gif/gifkit.lua")(H, "gesture")
local UIManager = require("ui/uimanager")

-- Where things are on the 1200 x 1600 screen (a point on the element).
local TAB_SETTINGS = { 527, 162 }
local NEXT_PAGE = { 1012, 730 }
local FIRST_ROW, FOURTH_ROW = { 600, 256 }, { 600, 532 }
local CORNER = { 1150, 1560 }
local PAGE_WITH_TEXT = 80

local function bookPath()
    for _i, b in ipairs(require("cyberui/data/library").all()) do
        if b:find("Altered Carbon", 1, true) then return b end
    end
end

local function reader() return require("apps/reader/readerui").instance end

G.run(function()
    -- the starting point, not recorded: the book closed on a page of text
    G:mute(true)
    local Settings = require("cyberui/settings")
    Settings.save("park_reader", false)
    H.app().openBook(bookPath())
    G:wait(4)
    reader():handleEvent(require("ui/event"):new("GotoPage", PAGE_WITH_TEXT))
    G:wait(1)
    H.app().homeFromBook(reader())
    G:wait(2)
    Settings.save("park_reader", true)
    G:mute(false)

    -- 1. open the book from home: the jack-in card, then the page
    -- the jack-in card is up only while the tap is handled: take it as it is painted
    local App = H.app()
    local flash = App.flash
    App.flash = function(card)
        flash(card)
        G:frame(900)
    end
    G:say("Open a book from home")
    G:hold(1500)
    local open = H.find("RESUME", nil, true)
    G:tap(open and open.x + open.w / 2 or 460, open and open.y + open.h / 2 or 775, 100)
    G:wait(1.5)
    G:hold(1500)

    -- 2. the toolbar, down to the corner gesture, slowly enough to follow
    local function step(pt, wait, ms)
        G:tap(pt[1], pt[2], ms or 750)
        G:wait(wait or 0.8)
        G:hold(ms and ms - 200 or 600)
    end
    G:say("Open the toolbar")
    step({ 600, 20 }, 1.2)
    G:say("Settings tab")
    step(TAB_SETTINGS)
    G:say("Next page")
    step(NEXT_PAGE)
    G:say("Taps and gestures")
    step(FIRST_ROW)
    G:say("Gesture manager")
    step(FIRST_ROW)
    G:say("Next page")
    step(NEXT_PAGE)
    G:say("Long-press on corner")
    step(FIRST_ROW)
    G:say("Bottom right")
    step(FOURTH_ROW)
    G:say("General")
    step(FOURTH_ROW)
    G:say("Next pages, to CyberUI home")
    for _i = 1, 5 do step(NEXT_PAGE, 0.4, 450) end
    G:say("Pick CyberUI home")
    step({ 400, FIRST_ROW[2] }, 1)
    G:hold(1200)

    -- close the toolbar, back to the book
    G:say("Close the toolbar")
    local close = { 1119, 64 }
    G:tap(close[1], close[2]); G:wait(1)
    -- KOReader's bottom bar goes with a tap on the page
    G:tap(600, 1000, 200); G:wait(0.8)
    G:hold(800)

    -- 3. use it: hold the corner, home is there at once
    G:say("Hold the bottom right corner")
    G:hold(900)
    G:press(CORNER[1], CORNER[2], 300)
    G:wait(0.5)
    G:say("Home, at once")
    G:hold(1800)

    -- 4. the same book again: near instant
    G:say("Open the same book again")
    open = H.find("RESUME", nil, true)
    G:tap(open and open.x + open.w / 2 or 460, open and open.y + open.h / 2 or 775, 100)
    G:wait(0.3)
    G:frame(300)
    G:say("Back in the book")
    G:hold(2200)
end)
