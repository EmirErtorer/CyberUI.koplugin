-- The windows that need a book open (the book status page): shown once and photographed; run with
-- CYBERUI_SKINMODE=old for KOReader's own look and with new to see the styled one. In new mode the page must be CyberUI's,
-- the rating, the status and the review must go through KOReader's own methods, and the page must close.
local H = ...
local UIManager = require("ui/uimanager")
local mode = os.getenv("CYBERUI_SKINMODE") or "new"
require("cyberui/settings").set("styled_widgets", mode == "new")
G_reader_settings:saveSetting("virtual_keyboard_enabled", true)

local status
local function ui() return require("apps/reader/readerui").instance end
local function gone(w) for _i, e in ipairs(UIManager._window_stack) do if e.widget == w or e.widget == w._cyber_popup then return false end end return true end

H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(3, function()
    ui().status:onShowBookStatus()
    local top = UIManager._window_stack[#UIManager._window_stack].widget
    -- the page (or its popup, above it)
    for i = #UIManager._window_stack, 1, -1 do
        local w = UIManager._window_stack[i].widget
        if w.summary then status = w; break end
    end
end)
H.step(1.5, function()
    H.shot("01-book-status")
    if mode ~= "new" then return end
    H.check(status and status._cyber_popup ~= nil, "the book status page is in CyberUI's style")
    local stars, seen = {}, {}
    H.findWhere(function(el)
        if (el.label == "\u{2606}" or el.label == "\u{2605}") and not seen[el] then seen[el] = true; stars[#stars + 1] = el end
        return false
    end)
    H.check(#stars == 5, "five stars are drawn: " .. #stars)
    table.sort(stars, function(a, b) return a.x < b.x end)
    if stars[4] then H.tapAt(stars[4].x + stars[4].w / 2, stars[4].y + stars[4].h / 2) end
end)
H.step(1, function()
    if mode ~= "new" then return end
    H.check(status.summary.rating == 4, "a tap on the fourth star gives KOReader's summary the rating 4: " .. tostring(status.summary.rating))
    H.tap(require("gettext")("Finished"))
end)
H.step(1, function()
    if mode ~= "new" then return end
    H.check(status.summary.status == "complete", "Finished sets KOReader's status: " .. tostring(status.summary.status))
    H.shot("02-book-status-rated")
    H.tap(nil, "back")
end)
H.step(1.5, function()
    if mode ~= "new" then return end
    H.check(gone(status), "the back button closes the page and its popup")
end)
