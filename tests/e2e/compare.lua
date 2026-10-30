-- Time opening a book and coming back home with the home-screen plugin named
-- by CYBERUI_COMPARE (cyberui, cyberui_home, cyberui_park, cyberui_park_home, bookshelf or simpleui), each through its own
-- open and go-home actions: the same book three times, then two books in
-- turn, then one return followed by 45 s idle (Bookshelf closes a parked book
-- after 30 s idle). Also timed: every KOReader book close, wherever it falls,
-- and the plugin's own painting of its home screen on each return.
local H = ...
local UIManager = require("ui/uimanager")
local time = require("ui/time")
local which = os.getenv("CYBERUI_COMPARE") or "cyberui"

local function topName() local t = H.top(); return t and t.name end
local function stackWidget(name)
    for _i, e in ipairs(UIManager._window_stack) do if e.widget.name == name then return e.widget end end
end
local P = {
    cyberui = {
        home = "cyberui",
        open = function(book) require("cyberui/app").openBook(book) end,
        back = function() H.event("CyberUIHome") end,
    },
    -- CyberUI again, going home through KOReader's own Home action
    cyberui_home = {
        home = "cyberui",
        open = function(book) require("cyberui/app").openBook(book) end,
        back = function() H.event("Home") end,
    },
    -- CyberUI with "keep the book open on Home" on, going home by its action or KOReader's own
    cyberui_park = {
        home = "cyberui",
        open = function(book) require("cyberui/app").openBook(book) end,
        back = function() H.event("CyberUIHome") end,
    },
    cyberui_park_home = {
        home = "cyberui",
        open = function(book) require("cyberui/app").openBook(book) end,
        back = function() H.event("Home") end,
    },
    bookshelf = {
        home = "bookshelf",
        open = function(book) stackWidget("bookshelf"):_openBook({ filepath = book }) end,
        back = function() H.event("BookshelfGoHome") end,
    },
    simpleui = {
        home = "homescreen",
        open = function(book) require("apps/reader/readerui"):showReader(book) end,
        back = function() H.event("SimpleUIGoHomescreen") end,
    },
}
local p = P[which]
if which:match("^cyberui_park") then require("cyberui/settings").set("park_reader", true) end
local results = {}
local phase = "boot"
local closes = {}       -- { phase, ms } for every ReaderUI close
local paint_ms = 0      -- home screen painting during the current measure

-- Time every book close, whichever plugin triggers it and whenever.
local ReaderUI = require("apps/reader/readerui")
local orig_close = ReaderUI.onClose
ReaderUI.onClose = function(self, ...)
    local t0 = time.now()
    local a, b = orig_close(self, ...)
    closes[#closes + 1] = { phase = phase, ms = time.to_ms(time.since(t0)) }
    return a, b
end

-- And every rebuild of the file browser that follows a close.
local rebuilds = {}
local orig_show_fm = ReaderUI.showFileManager
ReaderUI.showFileManager = function(self, ...)
    local t0 = time.now()
    local a, b = orig_show_fm(self, ...)
    rebuilds[#rebuilds + 1] = { phase = phase, ms = time.to_ms(time.since(t0)) }
    return a, b
end

-- Time the home widget's painting (wrapped once per widget instance).
local function timePaint()
    local w = stackWidget(p.home)
    if not w or rawget(w, "_cmp_wrapped") then return end
    w._cmp_wrapped = true
    local orig = w.paintTo
    w.paintTo = function(self, ...)
        local t0 = time.now()
        orig(self, ...)
        paint_ms = paint_ms + time.to_ms(time.since(t0))
    end
end

-- Time from now until cond() holds and the screen is painted. Also the
-- longest stall of the main loop (the gap between polls that are meant to
-- run every 10 ms) from the start to the end; after a return home the watch
-- goes on for a second, to catch the work that follows the painted home.
local TAIL_S = 1
local function measure(label, start_fn, cond)
    phase = label
    paint_ms = 0
    timePaint()
    local t0 = time.now()
    local last, worst = t0, 0
    local met_at, total
    start_fn()
    local function finish()
        local close = 0
        for _i, c in ipairs(closes) do if c.phase == label then close = close + c.ms end end
        results[#results + 1] = string.format("%-24s %5d ms   (book close inside %4d ms, home paint %3d ms, longest stall %4d ms)",
            label, total, close, paint_ms, worst)
        phase = label .. " (after)"
    end
    local function poll()
        local gap = time.to_ms(time.since(last))
        last = time.now()
        worst = math.max(worst, gap - 10)
        if not met_at and cond() then
            UIManager:forceRePaint()
            total = time.to_ms(time.since(t0))
            met_at = time.now()
            if not label:match("back home") then return finish() end
        end
        if met_at and time.to_s(time.since(met_at)) >= TAIL_S then return finish() end
        if time.to_ms(time.since(t0)) > 20000 then results[#results + 1] = label .. " TIMEOUT"; return end
        UIManager:scheduleIn(0.01, poll)
    end
    poll()
end
local function inReader() local t = H.top(); return t and t.document ~= nil and t.view ~= nil end
local function atHome()
    if topName() == p.home then timePaint(); return true end
    return false
end

-- Two EPUBs from the library, the same for every plugin.
local A, B
H.step(4, function()
    local lfs = require("libs/libkoreader-lfs")
    local dir = G_reader_settings:readSetting("home_dir")
    local books = {}
    for f in lfs.dir(dir) do if f:match("%.epub$") then books[#books + 1] = dir .. "/" .. f end end
    table.sort(books)
    A, B = books[1], books[2]
    H.say("plugin " .. which .. "; home shown: " .. tostring(atHome()) .. " (top " .. tostring(topName()) .. ")")
end)
local function round(label, book, idle)
    H.step(3, function() measure(label .. " open", function() p.open(book()) end, inReader) end)
    H.step(3, function() measure(label .. " back home", p.back, atHome) end)
    if idle then H.step(idle, function() end) end
end
for i = 1, 3 do round("same book #" .. i, function() return A end) end
for i = 1, 4 do round("two books #" .. i, function() return i % 2 == 1 and B or A end) end
round("before idle", function() return B end, 45)
H.step(1, function()
    for _i, r in ipairs(results) do H.say(r) end
    for _i, c in ipairs(closes) do
        if c.phase:match("%(after%)$") then H.say(string.format("book close later, %s: %d ms", c.phase, c.ms)) end
    end
    for _i, r in ipairs(rebuilds) do H.say(string.format("file browser rebuild, %s: %d ms", r.phase, r.ms)) end
    H.check(#results == 16, "all rounds measured")
end)
