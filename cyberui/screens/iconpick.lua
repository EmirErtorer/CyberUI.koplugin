-- Choosing an icon: every icon of the set (and the reader's own, from the
-- cyberui-icons folder in KOReader's settings) in a paged grid.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Icons = require("cyberui/gfx/icons")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Screen = require("cyberui/screens/screen")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local IconPick = Screen:extend()

-- Start on the first page; params: { current, on_pick(name) }.
function IconPick:init()
    self.page = 1
    self.names = Icons.list()
end

-- Build the grid.
function IconPick:build()
    local th = Theme.get()
    local params = self.params
    local grid = Grid:new({
        grow = true, items = self.names, page = self.page, min_cell_w = Theme.px(72), ratio = 1, row_gap = th.space.s, gap = th.space.s,
        make = function(name, w, h)
            return Button:new({ icon = name, icon_size = 30, width = w, height = h, variant = name == params.current and "chip_on" or "chip",
                on_tap = function() App.pop(); params.on_pick(name) end })
        end,
        on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
    })
    return Frame.page({ screen = self, title = _("Icon"), path = _("PICK // GLYPH"), tab = "settings",
        body = Layout.Column:new({ gap = th.space.m, children = {
            grid,
            Label:new({ text = _("Add your own SVGs to the cyberui-icons folder in KOReader's settings folder."), kind = "micro", color = "muted", lines = 2 }),
            Frame.pager(self, _("GLYPHS"), function(p) self:setPage(p) end),
        } }) })
end

return IconPick
