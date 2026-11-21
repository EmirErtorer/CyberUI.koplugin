-- A plugin's full-screen list made with KOReader's Menu (Rakuyomi's chapter
-- list is one), in CyberUI's style: the page turn keys turn its pages, a long
-- press on < or > goes to the first or last page, and a swipe down closes it.
local H = ...
local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local Key = require("device/key")
local list

-- The "page / pages" the pager shows, as two numbers (nil when there is no pager).
local function pageNow()
    local el = H.findWhere(function(e) return type(e.text) == "string" and e.text:match("^%d+ / %d+$") ~= nil end)
    if not el then return nil end
    local p, n = el.text:match("^(%d+) / (%d+)$")
    return tonumber(p), tonumber(n)
end

-- Press a page turn key as the device would.
local function press(name)
    UIManager:sendEvent(Event:new("KeyPress", Key:new(name, {})))
    UIManager:forceRePaint()
end

H.step(1, function()
    local items = {}
    for i = 1, 60 do items[i] = { text = "Chapter " .. i, callback = function() end } end
    list = require("ui/widget/menu"):new({ title = "A manga's chapters", item_table = items, is_popout = false,
        covers_fullscreen = true, is_borderless = true })
    UIManager:show(list)
end)
H.step(1, function()
    local p, n = pageNow()
    H.check(p == 1 and n and n > 2, "the list opens on its first page of several (" .. tostring(p) .. " / " .. tostring(n) .. ")")
    press("RPgFwd")
end)
H.step(1, function()
    H.check(pageNow() == 2, "the next page key turns to page 2")
    press("LPgBack")
end)
H.step(1, function()
    H.check(pageNow() == 1, "the previous page key turns back to page 1")
    press("LPgBack")
end)
H.step(1, function()
    H.check(pageNow() == 1, "the previous page key on page 1 stays there")
    H.hold(">")
end)
H.step(1, function()
    local p, n = pageNow()
    H.check(p == n, "a long press on > goes to the last page (" .. tostring(p) .. " / " .. tostring(n) .. ")")
    H.shot("l01-last")
    press("RPgFwd")
end)
H.step(1, function()
    local p, n = pageNow()
    H.check(p == n, "the next page key on the last page stays there")
    H.hold("<")
end)
H.step(1, function()
    H.check(pageNow() == 1, "a long press on < goes to the first page")
    local s = require("device").screen
    H.swipe("south", s:getWidth() / 2, s:getHeight() / 3)
end)
H.step(1, function()
    H.check(not UIManager:isWidgetShown(list) and pageNow() == nil, "a swipe down closes the list")
end)
