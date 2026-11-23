-- The jack-in card when a book opens from home: painted at once, before
-- KOReader looks the book up, and the book opens after it.
local H = ...
local S = 0.8
local Device = require("device")
local time = require("ui/time")

local log, t0, card_shot = {}, nil, false
local function note(what) log[#log + 1] = { what, time.to_ms(time.now() - t0) } end

H.step(1.5, function()
    -- parking off, so the book is really loaded
    require("cyberui/settings").set("park_reader", false)
    H.app().go("home")
end)
H.step(S, function()
    local Host = require("cyberui/host")
    local paint = Host.paintTo
    Host.paintTo = function(self, ...)
        local r = paint(self, ...)
        if t0 and self.overlay and not card_shot then
            note("card painted")
            card_shot = true
            Device.screen:shot(os.getenv("CYBERUI_DRIVE_OUT") .. "/jackin-card.png")
        end
        return r
    end
    local ReaderUI = require("apps/reader/readerui")
    local show, load = ReaderUI.showReader, ReaderUI.doShowReader
    ReaderUI.showReader = function(...) note("KOReader looks the book up"); return show(...) end
    ReaderUI.doShowReader = function(...) note("book loads"); local r = load(...); note("book loaded"); return r end
    t0 = time.now()
    note("tap")
    H.tap("RESUME")
end)
H.step(3, function()
    local at = {}
    for i, e in ipairs(log) do
        H.say(string.format("%7.1f ms  %s", e[2], e[1]))
        at[e[1]] = at[e[1]] or i
    end
    H.check(at["card painted"] ~= nil, "the card is painted")
    H.check(at["card painted"] and at["KOReader looks the book up"] and at["card painted"] < at["KOReader looks the book up"],
        "before KOReader looks the book up")
    local t = H.top()
    H.check(t and t.document ~= nil, "the book opens")
    H.event("CyberUIHome")
end)
H.step(3, function()
    H.check(H.cyberTop(), "home is back after the book closes")
end)
