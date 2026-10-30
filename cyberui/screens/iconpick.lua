-- Choosing an icon: the set's icons (and the reader's own, from the
-- cyberui-icons folder in KOReader's settings), the ones in KOReader's data
-- icons folder and KOReader's stock icons, one source at a time in a paged grid.

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

-- Start on the first page of the source the current icon is from; params:
-- { current, on_pick(name) }.
function IconPick:init(params)
    self.page = 1
    self.sources = Icons.sources()
    self.source = Icons.sourceOf(params.current)
end

-- The icons of the chosen source (the first one when it has none).
function IconPick:names()
    for _i, src in ipairs(self.sources) do
        if src.id == self.source then return src.names end
    end
    return self.sources[1].names
end

-- The row of sources to switch between, none when there is only one.
function IconPick:sourceRow()
    if #self.sources < 2 then return nil end
    local row = Layout.Row:new({ gap = Theme.get().space.s, children = {} })
    for _i, src in ipairs(self.sources) do
        row.children[#row.children + 1] = Button:new({ label = src.label, grow = true,
            variant = src.id == self.source and "chip_on" or "chip",
            on_tap = function() self.source, self.page = src.id, 1; App.render("ui") end })
    end
    return row
end

-- Build the grid.
function IconPick:build()
    local th = Theme.get()
    local params = self.params
    local grid = Grid:new({
        grow = true, items = self:names(), page = self.page, min_cell_w = Theme.px(72), ratio = 1, row_gap = th.space.s, gap = th.space.s,
        make = function(name, w, h)
            return Button:new({ icon = name, icon_size = 30, width = w, height = h, variant = name == params.current and "chip_on" or "chip",
                on_tap = function() App.pop(); params.on_pick(name) end })
        end,
        on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
    })
    local body = { grid,
        Label:new({ text = _("Add your own SVGs to the cyberui-icons folder in KOReader's settings folder."), kind = "micro", color = "muted", lines = 2 }),
        Frame.pager(self, _("GLYPHS"), function(p) self:setPage(p) end) }
    table.insert(body, 1, self:sourceRow())
    return Frame.page({ screen = self, title = _("Icon"), path = _("PICK // GLYPH"), tab = "settings",
        body = Layout.Column:new({ gap = th.space.m, children = body }) })
end

return IconPick
