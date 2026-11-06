-- KOReader's settings panel in a book is drawn by CyberUI and still works:
-- a tap on a choice changes the real setting, a tab switches the panel, and a
-- tap outside closes it.
local H = ...
local ui
local function snapshot()
    local t = {}
    for k, v in pairs(ui.config.configurable) do t[k] = v end
    return t
end
local before

H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(4, function()
    ui = require("apps/reader/readerui").instance
    before = snapshot()
    ui.config:onShowConfigMenu()
end)
H.step(2, function()
    H.shot("panel")
    local cd = ui.config.config_dialog
    H.check(cd._cyber == true and cd._cyber_popup ~= nil, "the panel is drawn by CyberUI")
    -- tap the ON choice of the Two Columns toggle
    local function find(e)
        if e.label == "ON" then return e end
        for _i, c in ipairs(e.children or { e.child }) do
            local f = c and find(c)
            if f then return f end
        end
    end
    local on = find(cd._cyber_popup.element)
    H.check(on ~= nil, "an ON choice is in the panel")
    if on then H.tapAt(on.x + on.w / 2, on.y + on.h / 2) end
end)
H.step(2, function()
    local after = snapshot()
    local changed = 0
    for k, v in pairs(after) do if before[k] ~= v then changed = changed + 1 end end
    H.check(changed >= 1, "tapping a choice changed a real setting")
    H.shot("panel-after")
    local cd = ui.config.config_dialog
    ui.config.config_dialog:onShowConfigPanel(3)
end)
H.step(2, function() H.shot("panel-tab") end)
H.step(1, function() H.tapAt(require("device").screen:getWidth() / 2, 60) end)
H.step(2, function()
    H.check(not ui.config.config_dialog or not require("ui/uimanager"):isWidgetShown(ui.config.config_dialog), "a tap outside closes the panel")
end)
