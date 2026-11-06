-- KOReader's own frontlight window is drawn by CyberUI, and its slider sets the light.
local H = ...
local Device = require("device")
local fl
H.step(2, function()
    fl = require("ui/widget/frontlightwidget"):new({})
    require("ui/uimanager"):show(fl)
end)
H.step(1.5, function()
    H.shot("frontlight")
    H.check(fl._cyber_popup ~= nil, "the window is CyberUI's")
    local function find(e)
        if e.min and e.max and e.on_change then return e end
        for _i, c in ipairs(e.children or { e.child }) do
            local f = c and find(c)
            if f then return f end
        end
    end
    local s = find(fl._cyber_popup.element)
    H.check(s ~= nil, "it has a slider")
    H.tapAt(s.x + s:trackWidth() * 0.5, s.y + s.h / 2)
end)
H.step(1, function()
    local v = Device:getPowerDevice():frontlightIntensity()
    H.check(math.abs(v - 50) <= 5, "a tap in the middle sets the light to about half (" .. tostring(v) .. ")")
    H.tapAt(5, 5)
end)
H.step(1, function()
    H.check(not require("ui/uimanager"):isWidgetShown(fl), "a tap outside closes it")
end)
