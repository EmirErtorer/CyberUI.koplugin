-- The header of a screen: a back button, a small path line over the title,
-- and optional action buttons on the right.

local Button = require("cyberui/ui/button")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Theme = require("cyberui/theme")

local Header = {}

-- Build a header from { title, path, on_back, actions = { buttons } }.
function Header.build(o)
    local th = Theme.get()
    local kids = {}
    if o.on_back then
        kids[#kids + 1] = Button:new({ icon = "back", variant = "primary", corners = "t", width = th.size.touch,
            on_tap = o.on_back })
    end
    local titles = { Label:new({ text = o.title, kind = "display" }) }
    if o.path then table.insert(titles, 1, Label:new({ text = o.path, kind = "micro", color = "muted" })) end
    kids[#kids + 1] = Layout.Column:new({ grow = true, children = titles })
    for _i, b in ipairs(o.actions or {}) do kids[#kids + 1] = b end
    return Layout.Row:new({ gap = th.space.m, children = kids })
end

return Header
