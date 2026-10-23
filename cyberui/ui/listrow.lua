-- A list row: an optional small cover, a title over a meta line, and an
-- optional value on the right. Tapping it runs on_tap, holding runs on_hold.

local Cover = require("cyberui/ui/cover")
local Deco = require("cyberui/ui/deco")
local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Theme = require("cyberui/theme")

local ListRow = {}

-- Build a row from { path, icon, title, meta, value, on_tap, on_hold, thumb }:
-- a small cover for a book path, or an icon.
function ListRow.build(o)
    local th = Theme.get()
    local h = o.height or Theme.px(54)
    local kids = {}
    if o.icon then
        kids[#kids + 1] = Icon:new({ name = o.icon, size = 26, width = Theme.px(30) })
    elseif o.thumb ~= false and o.path then
        local cw = Theme.px(30)
        kids[#kids + 1] = Cover:new({ path = o.path, width = cw, height = math.min(h - th.space.s, Theme.px(44)) })
    end
    local lines = { Label:new({ text = o.title, kind = o.title_kind or "heading" }) }
    if o.meta then lines[#lines + 1] = Label:new({ text = o.meta, kind = "mono_small", color = "muted" }) end
    kids[#kids + 1] = Layout.Column:new({ grow = true, children = lines })
    if o.value then kids[#kids + 1] = Label:new({ text = o.value, kind = "mono_small", color = o.value_color or "ink" }) end
    local row = Layout.Row:new({ gap = th.space.m, height = h - th.size.hair, children = kids })
    local col = Layout.Column:new({ children = { row, Deco.Divider:new({}) }, on_tap = o.on_tap, on_hold = o.on_hold })
    return col
end

return ListRow
