-- A row to step through periods: back arrow, a centred caption, forward
-- arrow. An arrow with nothing beyond it is greyed out.

local Button = require("cyberui/ui/button")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Theme = require("cyberui/theme")

-- o: { label, on_prev, on_next, can_prev, can_next } (can_* default true).
return function(o)
    local th = Theme.get()
    local w = Theme.px(46)
    local function arrow(icon, on_tap, can)
        return Button:new({ icon = icon, variant = "icon", width = w, disabled = can == false, on_tap = can ~= false and on_tap or nil })
    end
    return Layout.Row:new({ gap = th.space.s, children = {
        arrow("back", o.on_prev, o.can_prev),
        Label:new({ text = o.label, kind = "mono", align = "center", grow = true }),
        arrow("forward", o.on_next, o.can_next),
    } })
end
