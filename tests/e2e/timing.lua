-- Time opening a book from CyberUI and coming back home, three times, plus
-- CyberUI's own share (building and painting home) on each return.
local H = ...
local UIManager = require("ui/uimanager")
local time = require("ui/time")

local BOOK
local t0
local results = {}

-- Poll every 20 ms until cond() holds, then call done(ms since t0).
local function waitFor(cond, done, limit)
    local start = t0
    local function poll()
        if cond() then return done(time.to_ms(time.since(start))) end
        if time.to_ms(time.since(start)) > (limit or 15000) then return done(-1) end
        UIManager:scheduleIn(0.02, poll)
    end
    poll()
end

H.step(1, function()
    -- an EPUB from the history, as most books are
    for _i, item in ipairs(require("readhistory").hist) do
        if item.file and item.file:match("%.epub$") then BOOK = item.file break end
    end
    BOOK = BOOK or require("cyberui/data/library").all()[1]
    H.say("book: " .. tostring(BOOK))
end)
for round = 1, 3 do
    H.step(1, function()
        t0 = time.now()
        H.app().openBook(BOOK)
        waitFor(function() local t = H.top(); return t and t.document ~= nil and t.view ~= nil end, function(ms)
            results[#results + 1] = string.format("round %d: open %d ms", round, ms)
        end)
    end)
    H.step(4, function()
        t0 = time.now()
        H.event("CyberUIHome")
        waitFor(function() return H.cyberTop() end, function(ms)
            local p = require("cyberui/perf").last
            results[#results + 1] = string.format("round %d: back home %d ms (CyberUI build %.0f ms, paint %.0f ms)", round, ms, p.build or -1, p.paint or -1)
        end)
    end)
end
H.step(3, function()
    for _i, r in ipairs(results) do H.say(r) end
    H.check(#results == 6, "all rounds finished")
end)
