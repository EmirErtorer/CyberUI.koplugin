-- Collections ("caches"): Favorites pinned as a large card over a paged grid
-- of every other collection, each showing a few of its covers. Tap one to
-- browse it; "+ New" makes a new collection.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Collections = require("cyberui/data/collections")
local Cover = require("cyberui/ui/cover")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Screen = require("cyberui/screens/screen")
local Theme = require("cyberui/theme")
local util = require("util")
local _ = require("gettext")

local CollectionsScreen = Screen:extend()

-- Start on the first page.
function CollectionsScreen:init()
    self.page = 1
end

-- A 2 x 2 mosaic of the collection's first covers.
local function mosaic(books, w, h)
    local gap = Theme.px(3)
    local cw, ch = math.floor((w - gap) / 2), math.floor((h - gap) / 2)
    local function tile(i) return Cover:new({ path = books[i], width = cw, height = ch }) end
    return Layout.Column:new({ gap = gap, width = w, children = {
        Layout.Row:new({ gap = gap, children = { tile(1), tile(2) } }),
        Layout.Row:new({ gap = gap, children = { tile(3), tile(4) } }),
    } })
end

-- Open a collection in the browser.
local function open(c)
    return function() App.push("library", { collection = c.name }) end
end

-- One collection card.
local function card(c, _w, h)
    local th = Theme.get()
    local inner_h = h - 2 * th.space.s
    return Panel:new({ shape = "frame", pad = th.space.s, on_tap = open(c), child = Layout.Row:new({ gap = th.space.m, children = {
        mosaic(c.books, math.floor(inner_h * 0.75), inner_h),
        Layout.Column:new({ grow = true, gap = th.space.xs, children = {
            Label:new({ text = c.title, kind = "heading" }),
            Label:new({ text = string.format(_("%d FILES"), #c.books), kind = "mono_small" }),
        } }),
    } }) })
end

-- The large pinned card for Favorites.
local function pinned(c)
    local th = Theme.get()
    local fan = {}
    for i = 1, 4 do
        fan[i] = Cover:new({ path = c.books[i], width = Theme.px(70), height = Theme.px(100),
            place = "tl", dx = (i - 1) * Theme.px(22), dy = (i - 1) * Theme.px(3) })
    end
    return Panel:new({ shape = "chamfer", corners = "tb", pad = th.space.l, on_tap = open(c), child = Layout.Row:new({ gap = th.space.l, children = {
        Layout.Overlay:new({ width = Theme.px(140), height = Theme.px(112), children = fan }),
        Layout.Column:new({ grow = true, gap = th.space.xs, children = {
            Label:new({ text = _("PINNED // QUEUE"), kind = "micro", color = "muted" }),
            Label:new({ text = c.title, kind = "display" }),
            Label:new({ text = string.format(_("%d FILES"), #c.books), kind = "mono" }),
        } }),
    } }) })
end

-- Make a new collection from a name typed in.
local function create()
    App.input(_("New collection"), "", function(name)
        name = util.trim(name or "")
        if name == "" then return end
        Collections.create(name)
        App.toast(_("Collection created"))
        App.update()
    end, _("Create"))
end

-- Build the screen.
function CollectionsScreen:build()
    local th = Theme.get()
    local all = Collections.list()
    local fav, rest = nil, {}
    for _i, c in ipairs(all) do
        if not fav and c.name == require("readcollection").default_collection_name then fav = c else rest[#rest + 1] = c end
    end
    local kids = {}
    if fav then kids[#kids + 1] = pinned(fav) end
    if #rest == 0 then
        kids[#kids + 1] = Label:new({ grow = true, text = _("No other collections yet. Make one with + New."),
            kind = "body", color = "muted", align = "center" })
    else
        kids[#kids + 1] = Grid:new({ grow = true, items = rest, page = self.page, cols = 2, cell_h = Theme.px(112),
            make = card, on_layout = function(_c, pages, page) self.pages, self.page = pages, page end })
    end
    kids[#kids + 1] = Frame.pager(self, _("CACHE"), function(p) self:setPage(p) end)
    return Frame.page({
        screen = self, title = _("Collections"), path = "/SYS/CACHES/", tab = "collections",
        actions = { Button:new({ label = _("+ New"), variant = "primary", corners = "r", on_tap = create }) },
        body = Layout.Column:new({ gap = th.space.l, children = kids }),
    })
end

return CollectionsScreen
