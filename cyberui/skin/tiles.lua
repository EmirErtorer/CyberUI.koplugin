-- Actions drawn as icon tiles (the icon over a short name), in rows: the look
-- of the highlight menu's toolbar, shared by every skin that offers actions
-- this way. A tile is made from a button KOReader described and what a skin
-- knows about it (`sem`: { icon, label, danger }).

local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Specs = require("cyberui/skin/specs")
local Theme = require("cyberui/theme")

local Tiles = {}

-- One action as a tile. A tile that cannot be used is drawn plain and takes no
-- taps; one that is dangerous (delete) is outlined in the accent colour.
function Tiles.tile(b, sem)
    local th = Theme.get()
    local s = Specs.read(b)
    local usable = s.enabled and s.callback ~= nil
    local danger = usable and sem.danger
    return Panel:new({
        shape = (usable and not danger) and "chamfer" or "frame", corners = "r", cut = "cut_small",
        fill = (usable and not danger) and "soft" or nil, line = danger and "accent" or (usable and "soft" or "line"),
        pad = { th.space.m, th.space.xs }, grow = true,
        on_tap = usable and s.callback or nil, on_hold = s.enabled and s.hold_callback or nil,
        child = Layout.Column:new({ gap = th.space.xs, align = "center", children = {
            Icon:new({ name = sem.icon, size = 26, color = danger and "accent" or (usable and "ink" or "muted"), width = Theme.px(40) }),
            Label:new({ text = sem.label or s.label, kind = "micro", color = danger and "accent" or (usable and "ink" or "muted"), align = "center", lines = 2 }),
        } }),
    })
end

-- One action as a slim tile showing a symbol KOReader itself draws for it (the
-- arrows and hatching that show a highlight growing or shrinking), which says
-- what the action does better than a word could.
function Tiles.symbol(b, sem)
    local th = Theme.get()
    local s = Specs.read(b)
    local usable = s.enabled and s.callback ~= nil
    return Panel:new({
        shape = usable and "chamfer" or "frame", corners = "r", cut = "cut_small", fill = usable and "soft" or nil, line = usable and "soft" or "line",
        pad = { th.space.s, th.space.xs }, grow = true,
        on_tap = usable and s.callback or nil, on_hold = s.enabled and s.hold_callback or nil,
        child = Label:new({ text = sem.symbol, kind = "label", color = usable and "ink" or "muted", align = "center" }),
    })
end

-- Tiles of a list of { button, sem } pairs side by side, sharing the width.
function Tiles.row(pairs_)
    local tiles = {}
    for _i, p in ipairs(pairs_) do tiles[#tiles + 1] = Tiles.tile(p[1], p[2]) end
    return Layout.Row:new({ gap = Theme.get().space.s, children = tiles })
end

return Tiles
